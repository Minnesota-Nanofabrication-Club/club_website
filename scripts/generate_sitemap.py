#!/usr/bin/env python3
"""Generate sitemap.xml for the Minnesota Nanofabrication Club website.

Scans the repository root for `*.html`, and writes one `<url>` entry per page to
`sitemap.xml` at the repository root.

Design constraints, in order of importance:

1.  **Deterministic output.** Pages are emitted in a fixed order and `<lastmod>` is a
    date, not a timestamp. Running this twice with no content change must produce a
    byte-identical file, otherwise the twice-weekly sync job commits a sitemap diff on
    every run and the review queue fills with noise.
2.  **No dependencies.** Standard library only. The repo has no build step and no
    virtualenv; anything more than `python3 scripts/generate_sitemap.py` will not get run.
3.  **No network, no git writes.** Only `git log` is shelled out to, read-only, and its
    absence is not fatal.

Usage:

    python3 scripts/generate_sitemap.py            # write sitemap.xml
    python3 scripts/generate_sitemap.py --check    # exit 1 if sitemap.xml is stale
"""

from __future__ import annotations

import argparse
import datetime as _datetime
import pathlib
import subprocess
import sys
from xml.sax.saxutils import escape

# The GitHub Pages base URL. Project pages are served from a subpath, so the
# trailing slash matters: without it every `<loc>` below would be built against
# the org root and every URL in the sitemap would 404.
BASE_URL = "https://minnesota-nanofabrication-club.github.io/club_website/"

# The site index. Its canonical URL is the bare directory URL, not `.../index.html`;
# both resolve, and listing the `index.html` form would advertise a second URL for a
# page whose own canonical tag points at the directory form.
INDEX_FILENAME = "index.html"

# Files matching `*.html` in the repo root that are not public pages. Empty today;
# add here rather than special-casing in the walk below.
EXCLUDED_FILENAMES: frozenset[str] = frozenset()

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
SITEMAP_PATH = REPO_ROOT / "sitemap.xml"


def git_last_modified(path: pathlib.Path) -> str | None:
    """Return the last-commit date of `path` as `YYYY-MM-DD`, or None.

    Returns None when git is unavailable, when this is not a git checkout, or when the
    file has never been committed (a brand-new page in the working tree). Callers fall
    back to the filesystem mtime.
    """
    try:
        result = subprocess.run(
            ["git", "log", "-1", "--format=%cs", "--", path.name],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    date = result.stdout.strip()
    # `%cs` is the committer date in strict `YYYY-MM-DD` form. Validate rather than
    # trust it, so a surprising git version cannot put garbage into the XML.
    try:
        _datetime.date.fromisoformat(date)
    except ValueError:
        return None
    return date


def filesystem_last_modified(path: pathlib.Path) -> str:
    """Return the file's mtime as `YYYY-MM-DD` in UTC."""
    mtime = _datetime.datetime.fromtimestamp(
        path.stat().st_mtime, tz=_datetime.timezone.utc
    )
    return mtime.date().isoformat()


def last_modified(path: pathlib.Path) -> str:
    return git_last_modified(path) or filesystem_last_modified(path)


def page_url(filename: str) -> str:
    if filename == INDEX_FILENAME:
        return BASE_URL
    return BASE_URL + filename


def discover_pages() -> list[pathlib.Path]:
    """Return the public HTML pages in the repo root, in stable order.

    `index.html` sorts first; everything else sorts alphabetically. Sorting is what
    makes the output reproducible — directory iteration order is not guaranteed, and
    an unsorted sitemap would reshuffle itself between machines.
    """
    pages = [
        p
        for p in REPO_ROOT.glob("*.html")
        if p.is_file() and p.name not in EXCLUDED_FILENAMES
    ]
    return sorted(pages, key=lambda p: (p.name != INDEX_FILENAME, p.name))


def render_sitemap(pages: list[pathlib.Path]) -> str:
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ]
    for page in pages:
        lines.append("  <url>")
        lines.append(f"    <loc>{escape(page_url(page.name))}</loc>")
        lines.append(f"    <lastmod>{last_modified(page)}</lastmod>")
        lines.append("  </url>")
    lines.append("</urlset>")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--check",
        action="store_true",
        help="do not write; exit 1 if sitemap.xml differs from what would be written",
    )
    args = parser.parse_args(argv)

    pages = discover_pages()
    if not pages:
        print("no HTML pages found in the repo root; refusing to write an empty sitemap",
              file=sys.stderr)
        return 1

    rendered = render_sitemap(pages)
    existing = SITEMAP_PATH.read_text(encoding="utf-8") if SITEMAP_PATH.exists() else None

    if args.check:
        if existing == rendered:
            print(f"sitemap.xml is up to date ({len(pages)} pages)")
            return 0
        print("sitemap.xml is stale; run scripts/generate_sitemap.py", file=sys.stderr)
        return 1

    if existing == rendered:
        # Do not rewrite an identical file. Leaving the mtime alone keeps the working
        # tree clean and keeps this script safe to run from the sync job unconditionally.
        print(f"sitemap.xml unchanged ({len(pages)} pages)")
        return 0

    SITEMAP_PATH.write_text(rendered, encoding="utf-8")
    print(f"wrote sitemap.xml ({len(pages)} pages)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
