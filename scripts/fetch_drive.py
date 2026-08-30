#!/usr/bin/env python3
"""Mirror a Google Drive folder tree to local text files, using a service account.

Why this exists
---------------
The scheduled sync reads the club's **Ultra Hardcore Chip Codesign** Drive. Locally
that works through the claude.ai Google Drive connector, which is bound to Leonard's
Claude account and to an interactive OAuth grant. A GitHub Actions runner has neither
a browser nor a logged-in account, so if the connector turns out not to be reachable
from `anthropics/claude-code-action`, the agent needs the Drive content to already be
sitting on disk as plain files it can `Read`.

That is all this script does: it walks a Drive folder as a **service account**,
exports every Google Doc / Sheet / Slides file to text, and writes the tree to a
local directory plus a `manifest.json`. Claude then never touches Drive at all — it
reads files, which is the one thing it needs no credentials for.

Dependencies
------------
Python standard library, plus the `openssl` command-line tool for the one thing the
standard library cannot do: RS256-sign the service account's JWT assertion. `openssl`
is present on every GitHub-hosted runner and on macOS. There is deliberately no
`pip install` step — the same reason the rest of this repo has no build step.

Credentials
-----------
A Google Cloud **service account** key, as the raw JSON that the Cloud console hands
you. Supply it either way:

    export GDRIVE_SERVICE_ACCOUNT_JSON="$(cat key.json)"   # what CI does
    python3 scripts/fetch_drive.py --out /tmp/drive

    python3 scripts/fetch_drive.py --credentials key.json --out /tmp/drive

See `docs/operations/cloud-sync.md` for how to create the account and share the
folder with it.

Where the output goes
---------------------
**Never into the repository.** The Drive tree contains budgets, BOM costs, vendor
pricing and outreach notes — the exact material `CLAUDE.md` rule 3 says must never
leave Drive. Write it to a scratch directory outside the working tree (CI uses
`$RUNNER_TEMP`) so there is no path by which a `git add` can sweep it into a commit.

Usage
-----
    python3 scripts/fetch_drive.py --out /tmp/drive
    python3 scripts/fetch_drive.py --out /tmp/drive --folder-id <id> --max-depth 4
    python3 scripts/fetch_drive.py --out /tmp/drive --dry-run    # list, download nothing
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

# The club's Drive root. Same id SYNC.md names — keep the two in step.
DEFAULT_FOLDER_ID = "1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP"

TOKEN_URI = "https://oauth2.googleapis.com/token"
DRIVE_FILES = "https://www.googleapis.com/drive/v3/files"

# Read-only, and asserted here rather than assumed: a key minted with write scope
# would still be constrained by this, so a bug in this script cannot modify Drive.
SCOPE = "https://www.googleapis.com/auth/drive.readonly"

FOLDER_MIME = "application/vnd.google-apps.folder"
SHORTCUT_MIME = "application/vnd.google-apps.shortcut"

# Google-native types have no bytes to download; they must be *exported*. Markdown
# is tried first for Docs because it survives headings, lists and tables, which is
# what makes a `[Master]` doc readable to the agent; text/plain flattens all of it.
EXPORTS = {
    "application/vnd.google-apps.document":     [("text/markdown", ".md"), ("text/plain", ".txt")],
    "application/vnd.google-apps.spreadsheet":  [("text/csv", ".csv")],
    "application/vnd.google-apps.presentation": [("text/plain", ".txt")],
    "application/vnd.google-apps.script":       [("application/vnd.google-apps.script+json", ".json")],
}

# Binary files are catalogued in the manifest but not fetched. Nothing on the site
# is sourced from an image or a PDF, and downloading them would turn a two-megabyte
# text pull into a slow one for no gain.
TEXTLIKE_PREFIXES = ("text/",)
TEXTLIKE_TYPES = {"application/json", "application/xml", "application/x-yaml"}

# Folders that are never fetched at all.
#
# The site is public. Not fetching this material keeps it out of the agent's
# context entirely, rather than relying on the agent to remember not to quote it.
# A publishing rule is a request; not having the bytes on the runner is a fact.
#
#   [LR]            learning resources -- reference material, never published
#   [C] Finances    the club budget
#   [C] Funding     grant proposals and expense tables
#   [C] Logistics   lab space, advisor outreach, named staff contacts
#
# Deliberately NOT a blanket rule on the [C] prefix: "[C] Minnesota Nanofabrication
# Club (MNF)" is also [C]-prefixed and holds Engineering Structure and the
# Constitution, which are genuine sources for the Team and About sections. The
# exclusions are named individually so adding a [C] folder does not silently
# remove a site source, and so a new finance-shaped folder has to be added here
# on purpose.
SKIP_FOLDER_PATTERNS = [
    re.compile(r"^\s*\[LR\]", re.IGNORECASE),
    re.compile(r"^\s*\[C\]\s*Finances\s*$", re.IGNORECASE),
    re.compile(r"^\s*\[C\]\s*Funding\s*$", re.IGNORECASE),
    re.compile(r"^\s*\[C\]\s*Logistics\s*$", re.IGNORECASE),
]

MAX_FILE_BYTES = 5 * 1024 * 1024
RETRY_STATUSES = {429, 500, 502, 503, 504}
MAX_RETRIES = 5


class FetchError(Exception):
    """Anything that should end the run with a readable message, not a traceback."""


# --- credentials ------------------------------------------------------------

def load_credentials(path: str | None) -> dict:
    if path:
        try:
            raw = Path(path).read_text()
        except OSError as err:
            raise FetchError(f"could not read the key file {path}: {err}") from err
    else:
        raw = os.environ.get("GDRIVE_SERVICE_ACCOUNT_JSON", "")
        if not raw.strip():
            raise FetchError(
                "no service account credentials. Set GDRIVE_SERVICE_ACCOUNT_JSON to the "
                "contents of the key JSON, or pass --credentials <file>. "
                "See docs/operations/cloud-sync.md.")

    try:
        creds = json.loads(raw)
    except json.JSONDecodeError as err:
        # The overwhelmingly common cause: the secret was pasted with the surrounding
        # quotes stripped, or only the private_key line was copied instead of the file.
        raise FetchError(
            f"the credentials are not valid JSON ({err}). The secret must be the whole "
            "key file, verbatim, starting with '{' and ending with '}'.") from err

    for field in ("client_email", "private_key", "token_uri"):
        if field not in creds:
            raise FetchError(f"the credentials are missing '{field}' — is this a service account key?")
    if creds.get("type") != "service_account":
        raise FetchError(
            f"the credentials are type '{creds.get('type')}', not 'service_account'. "
            "An OAuth client secret will not work here.")
    return creds


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _sign_rs256(message: bytes, private_key_pem: str) -> bytes:
    """RS256-sign with the openssl CLI.

    The standard library has no RSA. Rather than take a dependency on `cryptography`
    — which is not guaranteed to be importable from a runner's system python3 — shell
    out to openssl, which is. The key is written to a private temp file because
    `openssl dgst -sign` takes a path, and that file is removed in `finally` whatever
    happens: a service account key left in the filesystem is a Drive credential
    sitting around for anything else on the machine to read.
    """
    if not shutil.which("openssl"):
        raise FetchError(
            "openssl is not on PATH. This script signs the service account assertion "
            "with it because the Python standard library cannot do RSA.")

    handle, key_path = tempfile.mkstemp(prefix="gdrive-key-", suffix=".pem")
    try:
        os.fchmod(handle, 0o600)
        with os.fdopen(handle, "w") as fh:
            fh.write(private_key_pem)
        result = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", key_path],
            input=message, capture_output=True, check=False,
        )
        if result.returncode != 0:
            detail = result.stderr.decode("utf-8", "replace").strip()[:300]
            raise FetchError(f"openssl could not sign the assertion: {detail}")
        return result.stdout
    finally:
        try:
            os.unlink(key_path)
        except OSError:
            pass


def access_token(creds: dict) -> str:
    """Exchange a self-signed JWT for a read-only Drive access token."""
    now = int(time.time())
    header = {"alg": "RS256", "typ": "JWT"}
    claims = {
        "iss": creds["client_email"],
        "scope": SCOPE,
        "aud": creds.get("token_uri", TOKEN_URI),
        # One hour is Google's maximum. The whole pull finishes in seconds, so this
        # is never refreshed; if it ever needs to be, that is a sign the tree grew
        # far beyond what the site summarizes.
        "exp": now + 3600,
        "iat": now,
    }
    signing_input = f"{_b64url(json.dumps(header).encode())}.{_b64url(json.dumps(claims).encode())}"
    signature = _sign_rs256(signing_input.encode("ascii"), creds["private_key"])
    assertion = f"{signing_input}.{_b64url(signature)}"

    body = urllib.parse.urlencode({
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": assertion,
    }).encode("ascii")
    request = urllib.request.Request(
        creds.get("token_uri", TOKEN_URI), data=body,
        headers={"Content-Type": "application/x-www-form-urlencoded"}, method="POST")

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.loads(response.read())
    except urllib.error.HTTPError as err:
        detail = err.read().decode("utf-8", "replace")[:400]
        if err.code == 400 and "invalid_grant" in detail:
            raise FetchError(
                "Google rejected the assertion (invalid_grant). Usual causes: the key has "
                "been deleted or disabled in the Cloud console, or the runner's clock is "
                f"badly skewed. Raw response: {detail}") from err
        raise FetchError(f"token request failed: HTTP {err.code} — {detail}") from err
    except urllib.error.URLError as err:
        raise FetchError(f"could not reach Google's token endpoint — {err.reason}") from err

    token = payload.get("access_token")
    if not token:
        raise FetchError(f"no access_token in the token response: {payload}")
    return token


# --- Drive API --------------------------------------------------------------

def api_request(url: str, token: str, *, binary: bool = False) -> bytes | dict:
    for attempt in range(1, MAX_RETRIES + 1):
        request = urllib.request.Request(
            url,
            headers={
                "Authorization": f"Bearer {token}",
                "User-Agent": "mnfc-website-sync (+https://github.com/Minnesota-Nanofabrication-Club/club_website)",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                data = response.read()
                return data if binary else json.loads(data)
        except urllib.error.HTTPError as err:
            if err.code in RETRY_STATUSES and attempt < MAX_RETRIES:
                delay = min(2 ** attempt, 30)
                print(f"  HTTP {err.code}; retrying in {delay}s", file=sys.stderr)
                time.sleep(delay)
                continue
            detail = err.read().decode("utf-8", "replace")[:400]
            if err.code == 404:
                raise FetchError(
                    f"Drive returned 404 for {url}. The service account almost certainly "
                    "cannot see this item — share the folder with its client_email "
                    "(Viewer), and remember that sharing is not inherited from your own "
                    f"access. Raw response: {detail}") from err
            if err.code == 403:
                raise FetchError(
                    f"Drive returned 403 for {url}. Either the Drive API is not enabled on "
                    "the project, or the folder is not shared with the service account. "
                    f"Raw response: {detail}") from err
            raise FetchError(f"Drive returned {err.code} for {url} — {detail}") from err
        except urllib.error.URLError as err:
            raise FetchError(f"could not reach Drive — {err.reason}") from err
    raise FetchError(f"gave up on {url} after {MAX_RETRIES} attempts")


def list_children(folder_id: str, token: str) -> list[dict]:
    """Every non-trashed child of a folder, following pagination."""
    children: list[dict] = []
    page_token = None
    while True:
        params = {
            "q": f"'{folder_id}' in parents and trashed = false",
            "fields": "nextPageToken, files(id, name, mimeType, modifiedTime, size, "
                      "webViewLink, shortcutDetails)",
            "pageSize": "200",
            "orderBy": "folder,name",
            # Without both of these a folder living on a shared drive returns an empty
            # list rather than an error — the pull "succeeds" and mirrors nothing.
            "supportsAllDrives": "true",
            "includeItemsFromAllDrives": "true",
        }
        if page_token:
            params["pageToken"] = page_token
        payload = api_request(f"{DRIVE_FILES}?{urllib.parse.urlencode(params)}", token)
        children.extend(payload.get("files", []))
        page_token = payload.get("nextPageToken")
        if not page_token:
            return children


def folder_name(folder_id: str, token: str) -> str:
    params = {"fields": "name", "supportsAllDrives": "true"}
    payload = api_request(f"{DRIVE_FILES}/{folder_id}?{urllib.parse.urlencode(params)}", token)
    return payload.get("name", folder_id)


def fetch_content(item: dict, token: str) -> tuple[bytes, str] | None:
    """Return (bytes, extension) for a file, or None if it is not worth fetching."""
    mime = item["mimeType"]

    for export_mime, extension in EXPORTS.get(mime, []):
        params = {"mimeType": export_mime, "supportsAllDrives": "true"}
        url = f"{DRIVE_FILES}/{item['id']}/export?{urllib.parse.urlencode(params)}"
        try:
            return api_request(url, token, binary=True), extension
        except FetchError:
            # text/markdown is a relatively recent export format; fall through to the
            # next candidate rather than failing the whole run over one document.
            continue

    if mime.startswith(TEXTLIKE_PREFIXES) or mime in TEXTLIKE_TYPES:
        size = int(item.get("size") or 0)
        if size > MAX_FILE_BYTES:
            print(f"  skipping {item['name']}: {size} bytes is over the cap")
            return None
        params = {"alt": "media", "supportsAllDrives": "true"}
        url = f"{DRIVE_FILES}/{item['id']}?{urllib.parse.urlencode(params)}"
        return api_request(url, token, binary=True), ""

    return None


# --- filesystem -------------------------------------------------------------

_UNSAFE = re.compile(r"[/\\\x00-\x1f]")


def safe_name(name: str) -> str:
    """A Drive title is free text; a path component is not.

    Drive happily allows `/` in a filename. Writing that through unchanged would
    silently create a directory level that does not exist in Drive, so the mirror
    would no longer match the tree the agent is told to expect.
    """
    cleaned = _UNSAFE.sub("-", name).strip().strip(".")
    return (cleaned or "untitled")[:120]


def should_skip_folder(name: str, include_restricted: bool = False) -> bool:
    """Whether to walk past this folder.

    `include_restricted` exists for review, not for publishing. Complete coverage
    of Drive is the right default for a human (or an agent) asking "did anything
    change that I should know about" — excluding folders from the *read* means a
    goal, a decision or a constraint recorded in one of them is invisible forever,
    which is a worse failure than the one the exclusion prevents.

    It stays OFF by default because the sync that builds the public site runs on a
    CI runner, and the excluded folders hold budgets, vendor pricing and named
    staff contacts. Not having those bytes on that runner is a fact; a rule telling
    an agent not to publish them is only a request. So: review may read everything,
    the publishing path still cannot.
    """
    if include_restricted:
        return False
    return any(pattern.search(name) for pattern in SKIP_FOLDER_PATTERNS)


# Ids already visited, so a shortcut cycle cannot spin forever.
seen: set[str] = set()


# --- walk -------------------------------------------------------------------

def walk(folder_id: str, out_dir: Path, token: str, *, rel: Path, depth: int,
         max_depth: int, dry_run: bool, manifest: list[dict],
         include_restricted: bool = False) -> None:
    if depth > max_depth:
        print(f"  depth limit reached at {rel}")
        return

    for item in list_children(folder_id, token):
        name = item["name"]
        mime = item["mimeType"]

        if mime == SHORTCUT_MIME:
            details = item.get("shortcutDetails") or {}
            target = details.get("targetId")
            target_mime = details.get("targetMimeType") or ""
            # A shortcut that is never followed is a silent coverage hole: the
            # content exists in the tree as far as anyone browsing Drive is
            # concerned, and simply does not exist as far as this mirror is
            # concerned. Follow it, but only into a folder we would have walked
            # anyway, and only once -- `seen` stops a shortcut loop.
            if target and target not in seen:
                seen.add(target)
                if target_mime == FOLDER_MIME:
                    child_rel = rel / safe_name(name)
                    if not dry_run:
                        (out_dir / child_rel).mkdir(parents=True, exist_ok=True)
                    print(f"  {child_rel}/  (via shortcut -> {target})")
                    manifest.append({"path": str(child_rel), "id": target,
                                     "mimeType": FOLDER_MIME, "fetched": True,
                                     "reason": "shortcut-followed"})
                    walk(target, out_dir, token, rel=child_rel, depth=depth + 1,
                         max_depth=max_depth, dry_run=dry_run, manifest=manifest,
                         include_restricted=include_restricted)
                    continue
                item = dict(item, id=target, mimeType=target_mime)
                mime = target_mime
                print(f"  shortcut {rel / safe_name(name)} -> {target} (following)")
            else:
                print(f"  shortcut {rel / safe_name(name)} -> {target or 'unknown'} (already seen)")
                manifest.append({"path": str(rel / safe_name(name)), "id": item["id"],
                                 "mimeType": mime, "fetched": False,
                                 "reason": "shortcut-duplicate"})
                continue

        if mime == FOLDER_MIME:
            if should_skip_folder(name, include_restricted):
                print(f"  skipping folder {rel / name} ([LR] — reference material, not published)")
                manifest.append({"path": str(rel / safe_name(name)), "id": item["id"],
                                 "mimeType": mime, "fetched": False, "reason": "learning-resource"})
                continue
            child_rel = rel / safe_name(name)
            if not dry_run:
                (out_dir / child_rel).mkdir(parents=True, exist_ok=True)
            print(f"  {child_rel}/")
            manifest.append({"path": str(child_rel), "id": item["id"], "mimeType": mime,
                             "fetched": True, "modifiedTime": item.get("modifiedTime")})
            walk(item["id"], out_dir, token, rel=child_rel, depth=depth + 1,
                 max_depth=max_depth, dry_run=dry_run, manifest=manifest,
                 include_restricted=include_restricted)
            continue

        entry = {
            "path": None, "id": item["id"], "name": name, "mimeType": mime,
            "modifiedTime": item.get("modifiedTime"),
            "webViewLink": item.get("webViewLink"), "fetched": False,
        }

        if dry_run:
            print(f"  {rel / safe_name(name)}  [{mime}]")
            entry["reason"] = "dry-run"
            manifest.append(entry)
            continue

        result = fetch_content(item, token)
        if result is None:
            print(f"  {rel / safe_name(name)}  [{mime}] — catalogued, not fetched")
            entry["reason"] = "binary or unsupported type"
            manifest.append(entry)
            continue

        content, extension = result
        target = out_dir / rel / (safe_name(name) + extension)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        entry["path"] = str(rel / target.name)
        entry["bytes"] = len(content)
        entry["fetched"] = True
        manifest.append(entry)
        print(f"  {entry['path']}  ({len(content)} bytes)")


# --- entry point ------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Mirror a Google Drive folder to local text files (service account).")
    parser.add_argument("--out", required=True,
                        help="output directory. Must be OUTSIDE the repo — the tree holds "
                             "material that must never be committed.")
    parser.add_argument("--folder-id", default=DEFAULT_FOLDER_ID,
                        help=f"Drive folder id to mirror (default: {DEFAULT_FOLDER_ID})")
    parser.add_argument("--credentials",
                        help="path to the service account key JSON "
                             "(default: $GDRIVE_SERVICE_ACCOUNT_JSON)")
    parser.add_argument("--max-depth", type=int, default=6,
                        help="how deep to recurse (default: 6)")
    parser.add_argument("--include-restricted", action="store_true",
                        help="walk [LR] and the [C] Finances/Funding/Logistics folders "
                             "too. For REVIEW ONLY -- never for the public-site build, "
                             "which must not have budgets or contacts on the runner.")
    parser.add_argument("--dry-run", action="store_true",
                        help="list what would be pulled; write nothing")
    args = parser.parse_args()

    try:
        creds = load_credentials(args.credentials)
        print(f"Service account: {creds['client_email']}")
        token = access_token(creds)

        out_dir = Path(args.out).resolve()
        repo_root = Path(__file__).resolve().parent.parent
        if out_dir == repo_root or repo_root in out_dir.parents:
            # Refusing rather than warning. The pulled tree contains budgets, BOM costs
            # and vendor pricing; inside the working tree it is one `git add -A` away
            # from being published forever in the repo's history.
            raise FetchError(
                f"--out {out_dir} is inside the repository at {repo_root}. Drive content "
                "must never land in the working tree. Use a scratch directory such as "
                "$RUNNER_TEMP/drive or /tmp/drive.")

        root = folder_name(args.folder_id, token)
        print(f"Root folder: {root} ({args.folder_id})")
        if not args.dry_run:
            out_dir.mkdir(parents=True, exist_ok=True)

        manifest: list[dict] = []
        walk(args.folder_id, out_dir, token, rel=Path("."), depth=1,
             max_depth=args.max_depth, dry_run=args.dry_run, manifest=manifest,
             include_restricted=args.include_restricted)

        fetched = sum(1 for e in manifest if e.get("fetched") and e["mimeType"] != FOLDER_MIME)
        folders = sum(1 for e in manifest if e["mimeType"] == FOLDER_MIME)

        if not args.dry_run:
            (out_dir / "manifest.json").write_text(json.dumps({
                "root_folder_id": args.folder_id,
                "root_folder_name": root,
                "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "service_account": creds["client_email"],
                "entries": manifest,
            }, indent=2, ensure_ascii=False))

        print(f"\n{fetched} file(s) across {folders} folder(s) -> {out_dir}")

        if fetched == 0:
            # An empty mirror and a successful one are indistinguishable downstream:
            # the agent reads an empty directory, concludes Drive says nothing, and
            # proposes stripping the site. Fail loudly here instead.
            raise FetchError(
                "nothing was fetched. The service account can reach the folder id but "
                "sees no files in it — the usual cause is that the folder was shared "
                "with the wrong address, or only a subfolder was shared.")
        return 0

    except FetchError as err:
        print(f"error: {err}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
