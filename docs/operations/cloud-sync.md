# The Cloud Sync

The sync running as a GitHub Actions workflow instead of a `launchd` job on one laptop:
why it moved, the secrets it needs and how to mint each one, how to trigger and read a
run, and how it coexists with the local schedule that is still installed. What happens
*inside* a run is still [Anatomy of a Sync Run](sync-run.md); the laptop jobs are still
[The Schedule](schedule.md). **This workflow publishes — it commits straight to `main`
with no pull request and no human approval — and it reads Drive through a Google service
account, not through the claude.ai connector the local job uses.**

---

## Contents

- [Why it moved](#why-it-moved)
- [What the workflow does](#what-the-workflow-does)
- [The Google Drive problem](#the-google-drive-problem)
- [The secrets](#the-secrets)
- [Creating the service account](#creating-the-service-account)
- [Running it by hand](#running-it-by-hand)
- [Reading a failed run](#reading-a-failed-run)
- [The local job is still installed](#the-local-job-is-still-installed)
- [Verified and unverified](#verified-and-unverified)

---

## Why it moved

On **2026-08-27** the scheduled run failed with `Your computer went to sleep
mid-response`, thirty-six minutes in. The mechanism, in order:

1. `com.mnfc.website-sync` is a **per-user agent in the `gui/$(id -u)` domain**. It has to
   be — the run needs the logged-in user's Google Drive connector session, SSH key and
   `gh` login, none of which exist in a system domain. A `gui/` agent only runs while
   that user has an active login session.
2. `StartCalendarInterval` **is not a wake-up alarm.** `launchd` does not wake a sleeping
   Mac; it runs a missed job at whatever wake happens next, and on a sleeping laptop that
   is normally a maintenance DarkWake lasting a few seconds.
3. The job now wraps itself in `caffeinate -i -m -s`, which fixes the *second* half of
   that failure — the machine sleeping out from under a run already in progress. It
   cannot fix the first. `caffeinate` keeps an awake machine awake; it has no power to
   start one.
4. `pmset repeat wake` can schedule a power-on on Intel Macs. **This Apple Silicon machine
   has no scheduled power-on capability**, so there is no way to guarantee the Mac is
   awake at 08:13 on a Monday.

!!! danger "A laptop schedule is best-effort by construction, not by accident"
    Every layer above is working as designed. Nothing is misconfigured and nothing can be
    tuned to fix it. As long as the trigger lives on a machine that can be closed, off, or
    logged out, "did the sync run?" has no reliable answer — and the failure is silent, so
    the only symptom is content that slowly ages. That is the whole reason the schedule
    moved to a hosted runner, which is awake because it does not exist until the cron
    fires.

---

## What the workflow does

`.github/workflows/sync-from-drive.yml`, one job, in order:

| Step | What it does | Fails the run? |
| --- | --- | --- |
| Check the run is configured | Looks for the Claude and Drive secrets | No — logs a `::notice::` and exits green |
| Sanity-check the repo | `CLAUDE.md`, `SYNC.md`, `index.html`, `style.css`, `scripts/fetch_drive.py` all present; the script compiles | Yes |
| Mirror Drive | `scripts/fetch_drive.py` pulls the Drive tree to `$RUNNER_TEMP/drive` | Yes |
| Sync the site | `anthropics/claude-code-action@v1` reads the mirror and edits the HTML | Yes |
| Check the agent stayed inside the site | Refuses to publish if protected paths changed | Yes |
| Publish to main | `git push origin HEAD:main`, rebase-and-retry up to three times | Yes |
| Job summary / Discord / failure issue | Reporting | No |

### The schedule

```yaml
- cron: "13 13 * * 1,4"
```

**GitHub cron is always UTC and does not observe US daylight saving.** A cron written to
land at 08:13 Central in summer therefore lands at 07:13 Central in winter, and there is
no expression that fixes it — the workflow would need two crons and a guard step, which
is more machinery than a thirteen-minute drift deserves.

| Period | `13:13 UTC` is | Note |
| --- | --- | --- |
| CDT, roughly mid-March to early November | 08:13 America/Chicago | Matches the old `launchd` slot exactly |
| CST, roughly early November to mid-March | 07:13 America/Chicago | An hour early, which nobody will notice |

`1,4` is Monday and Thursday — the same two days the `launchd` jobs used, and the same
two days the local watchdog's `STALE_DAYS=4` threshold is calibrated against. Changing
the days here without changing that threshold makes the watchdog either blind or
permanently noisy. GitHub also defers scheduled runs under peak load, so treat the time
as "morning-ish".

### It publishes without review

The local job proposes: it pushes a branch and opens a pull request, and a human merges.
**This one commits straight to `main`, at Leonard's explicit request.** Pages serves
`main` verbatim, so a bad commit is live in about a minute and the only remedy is to
revert it.

Two things stand in for the reviewer, and both are in the workflow rather than in the
prompt:

- **The guard step.** After the agent finishes, `git diff --name-only` against the
  pre-run SHA over `docs/ .github/ scripts/ mkdocs.yml README.md CLAUDE.md SYNC.md`. Any
  hit and the run fails without pushing. The prompt already tells the agent to leave
  those alone; a prompt is a request, and this is the check. Without it, one confused run
  could rewrite the documentation of the sync from inside the sync — exactly the drift
  `CLAUDE.md` warns about — or edit the workflow that is running it.
- **Uncommitted leftovers are discarded, never swept up.** If the agent edited without
  committing, the guard runs `git reset --hard`. Those edits sat on a tree nobody
  reviewed; committing them because they happened to be there is how unreviewed content
  reaches the live site.

!!! warning "The publishing rules are now the only thing between Drive and the public site"
    With the pull request gone, rule 1 of `CLAUDE.md` — never invent content — has no
    backstop. So does rule 3: no budgets, BOM costs, vendor pricing, outreach notes, or
    `[MASTER]` to-do lists. The agent reads documents containing all of that on every
    run. Read the diff of the first few runs even though nothing asks you to.

---

## The Google Drive problem { #the-google-drive-problem }

The local job reads Drive with `mcp__claude_ai_Google_Drive__*` — the **claude.ai Google
Drive connector**, which Claude Code inherits from an interactive claude.ai login. The
obvious question when moving to CI is whether that connector comes along with
`CLAUDE_CODE_OAUTH_TOKEN`.

**It does not, and this is documented rather than inferred.** From
[Claude Code authentication](https://code.claude.com/docs/en/authentication), on the
token `claude setup-token` mints:

> It can only make model requests, so it can't establish Remote Control sessions or fetch
> claude.ai connectors. MCP servers you configure locally still work.

[The MCP page](https://code.claude.com/docs/en/mcp) closes the other door: connectors are
fetched **only** when the active authentication is a claude.ai subscription *login*, and
are skipped outright when `ANTHROPIC_API_KEY` is active. Both secrets this workflow
accepts are therefore excluded. The same page notes that a remote MCP server needing
OAuth cannot complete that flow in a non-interactive run at all — there is no `/mcp`
panel and nobody at a browser to consent.

So the connector is not a path, and the workflow does not attempt it. `scripts/fetch_drive.py`
mirrors Drive to plain files as a **service account** before the agent starts, and the
agent reads files — the one thing it needs no credentials for.

| | claude.ai connector | Service account mirror |
| --- | --- | --- |
| Tools the agent uses | `mcp__claude_ai_Google_Drive__*` | `Read`, `Glob`, `Grep` |
| Auth | Interactive claude.ai login | RS256 JWT, no human |
| Works in Actions | **No** — documented above | Yes |
| Used by | `scripts/sync-from-drive.sh` (local) | `.github/workflows/sync-from-drive.yml` |

!!! note "If you want to re-test the connector question later"
    Add `show_full_output: true` to the action's `with:` block, or `--debug='mcp,startup'`
    to `claude_args`. The stream's first `system/init` event lists `mcp_servers`,
    `mcp_server_errors` and the full `tools` array. Connectors working would show a Google
    Drive server with `status: "connected"` and `mcp__claude_ai_Google_Drive__*` entries in
    `tools`. Today it shows neither — not as an error, just as silent absence, because the
    fetch never happens.

### Why the mirror never lands in the repo

`fetch_drive.py` writes to `$RUNNER_TEMP/drive` and **refuses an `--out` path underneath
the repository root.** The Drive tree contains budgets, BOM costs, vendor pricing and
sponsorship correspondence. Inside the working tree that material is one `git add -A`
away from being in the published history forever, and git history is not something you
can quietly un-publish. Outside the tree there is no such path.

Two smaller behaviours follow the same logic:

- Folders tagged `[LR]` are **not mirrored at all**. `SYNC.md` says they are reference
  material and are never published; not fetching them keeps them out of the agent's
  context entirely rather than relying on it to remember.
- A mirror that fetched **zero files fails the run.** An empty mirror and a healthy one
  are indistinguishable downstream: the agent would read an empty directory, conclude
  Drive says nothing, and propose stripping the site.

---

## The secrets

| Secret | Required | What it is | If missing |
| --- | --- | --- | --- |
| `CLAUDE_CODE_OAUTH_TOKEN` | one of these two | Claude subscription token from `claude setup-token`. Bills against the Max plan. | Falls back to the API key |
| `ANTHROPIC_API_KEY` | one of these two | Console API key. Bills per token. | Falls back to the OAuth token |
| `GDRIVE_SERVICE_ACCOUNT_JSON` | **yes** | The whole service account key file, verbatim | Run exits green, does nothing |
| `DISCORD_WEBHOOK_URL` | no | Channel webhook | No post; run is otherwise normal |

**Prefer the OAuth token.** It bills against the Claude Max plan Leonard already pays for;
an API key bills per token on top of it, for the same work. When both are set the workflow
forces the API key input empty so the OAuth token wins — the precedence is a property of
this repo's workflow file, not of the action's internal resolution order, because if that
order ever changed upstream a run expected to be free could start charging.

```bash
# Claude, preferred. Copy the token it prints, then paste it at the prompt.
claude setup-token
gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo Minnesota-Nanofabrication-Club/club_website

# Claude, fallback.
gh secret set ANTHROPIC_API_KEY --repo Minnesota-Nanofabrication-Club/club_website

# Drive. Redirect the file — do not paste it, it is multi-line JSON.
gh secret set GDRIVE_SERVICE_ACCOUNT_JSON \
  --repo Minnesota-Nanofabrication-Club/club_website < ~/Downloads/mnfc-drive-key.json

# Discord, optional. Reuses the same webhook the local job posts through.
gh secret set DISCORD_WEBHOOK_URL \
  --repo Minnesota-Nanofabrication-Club/club_website \
  --body "$(cat ~/.config/mnfc-sync/discord-webhook)"

gh secret list --repo Minnesota-Nanofabrication-Club/club_website
```

!!! warning "`claude setup-token` mints a credential for the whole Claude account"
    Anyone holding it can spend against the Max plan. It lives in exactly one place — the
    Actions secret — and GitHub will never show it again after you set it, which is fine:
    re-run `claude setup-token` to mint a new one. Never paste it into an issue, a commit,
    or a screenshot. If it leaks, mint a replacement immediately; that is the revocation.

!!! note "Missing secrets are a notice, not a failure"
    A run with nothing configured logs `::notice::`, writes a setup summary, and exits
    **green**. Between this workflow landing on `main` and the secrets being set, every
    cron would otherwise be a red X — and a red X that is always there is one nobody
    reads. Same call `discord.yml` makes in the sibling repo for a missing webhook.

---

## Creating the service account

Once, in the [Google Cloud console](https://console.cloud.google.com/), with the Google
account that owns the Drive folder.

**1. A project.** Reuse one or make a new one — `mnfc-website-sync` is the obvious name.

**2. Enable the Drive API.** *APIs & Services → Library → Google Drive API → Enable*.
Skipping this is the most common setup mistake; the symptom is a `403` from
`fetch_drive.py` naming the project, not the folder.

**3. Create the service account.** *IAM & Admin → Service Accounts → Create service
account*. Name it `website-sync`. **Grant it no project roles** — it needs none. Its
access comes entirely from the Drive folder being shared with it, which is the whole
point: the key cannot reach anything else in the account.

**4. Make a key.** Open the account → *Keys → Add key → Create new key → JSON*. The file
downloads once. It is a credential; treat it like a password.

**5. Copy its email.** On the account's page, `client_email` in the JSON — it looks like
`website-sync@mnfc-website-sync.iam.gserviceaccount.com`.

**6. Share the Drive folder with that email, read-only.** In Drive, right-click **Ultra
Hardcore Chip Codesign** → *Share* → paste the address → set the role to **Viewer** →
uncheck "Notify people" → Share.

!!! danger "Share the root folder, and share it as Viewer"
    **Drive sharing is not inherited from your own access.** The service account is a
    separate principal; it sees exactly what has been shared with it and nothing else.
    Share a subfolder rather than the root and `fetch_drive.py` fails with a `404` on the
    root id — which reads like a wrong folder id and sends you looking in the wrong place.
    Grant **Viewer**, not Editor: the script requests the read-only Drive scope, so an
    Editor grant buys nothing and means a leaked key could modify the club's documents.

**7. Set the secret and test.**

```bash
gh secret set GDRIVE_SERVICE_ACCOUNT_JSON \
  --repo Minnesota-Nanofabrication-Club/club_website < ~/Downloads/mnfc-drive-key.json

# Locally, to see exactly what the runner will see. --dry-run writes nothing.
export GDRIVE_SERVICE_ACCOUNT_JSON="$(cat ~/Downloads/mnfc-drive-key.json)"
python3 scripts/fetch_drive.py --out /tmp/drive --dry-run
```

**8. Delete the downloaded key file.** It is in the Actions secret now. A service account
key sitting in `~/Downloads` is a Drive credential anything on the machine can read.

`fetch_drive.py` needs only the Python standard library and the `openssl` command — the
standard library has no RSA, and the service account's assertion has to be RS256-signed.
`openssl` is present on every GitHub runner and on macOS. There is no `pip install` step,
for the same reason the site has no build step.

---

## Running it by hand

**Actions → Sync from Drive → Run workflow.** The one input is **dry run**.

| Dry run | What happens |
| --- | --- |
| ticked | The mirror is pulled, the agent runs and commits *on the runner*, the full diff is printed, and nothing is pushed. The runner is destroyed with the commit on it. |
| unticked | Identical, then `git push origin HEAD:main`. Live in about a minute. |

**Tick dry run the first time.** It exercises the service account, the agent and the guard
step, and prints exactly what would have gone to the live site, at the cost of one agent
run and no risk. It is also the right way to test a change to the prompt.

Or from a terminal:

```bash
gh workflow run "Sync from Drive" \
  --repo Minnesota-Nanofabrication-Club/club_website -f dry_run=true

gh run watch --repo Minnesota-Nanofabrication-Club/club_website
```

Running the Drive pull alone, without spending an agent run, is step 7 above.

---

## Reading a failed run

A failed run does three things: it fails the checks tab, it posts `✗ Sync failed` to
Discord with the run URL, and it opens or comments on a GitHub issue labelled
`drive-sync-failure`. **The issue is commented on by every subsequent failure and closes
itself on the next success**, so one open issue means "still broken" and no open issue
means "the last run was fine" — a silent cron failure is how the sibling repo went stale
for weeks.

Open the run, find the first red step, and match it:

| Step that failed | Almost always | Fix |
| --- | --- | --- |
| Mirror Drive, `404` on the root id | The folder is not shared with the service account, or only a subfolder is | Re-do step 6 on the **root** folder |
| Mirror Drive, `403` | The Drive API is not enabled on the project | Step 2 |
| Mirror Drive, `invalid_grant` | The key was deleted or disabled in the console | Mint a new key, re-set the secret |
| Mirror Drive, "not valid JSON" | The secret holds part of the key file, not all of it | Re-set it with `< key.json`, never by pasting |
| Mirror Drive, "nothing was fetched" | The account can see the folder id but no files in it | Sharing landed on the wrong address |
| Sync the site | Credit exhausted, a bad token, or the agent hit `--max-turns 200` | Read the step log; the action prints the reason |
| Check the agent stayed inside the site | The agent edited `docs/`, `scripts/` or a workflow | Nothing was pushed. Read the diff in the log, then re-run |
| Publish to main | Three pushes lost the rebase race, or branch protection | Check whether `main` requires reviews — this workflow cannot satisfy that |

!!! tip "A green run that changed nothing is the normal case"
    Most runs find that the site already matches Drive, make no commit, and post
    `✓ Site checked`. That is success, not a stall. The failure worth worrying about is
    the *absent* post — see below.

---

## The local job is still installed

Nothing in this migration uninstalls `com.mnfc.website-sync` or its watchdog. Both are
still bootstrapped in `gui/$(id -u)` on Leonard's Mac and will still fire on Monday and
Thursday whenever it happens to be awake.

**They do different things, and that is why leaving both is tolerable rather than
chaotic:**

| | Local `launchd` job | This workflow |
| --- | --- | --- |
| Reads Drive via | claude.ai connector | Service account mirror |
| Ends at | A pull request on `sync/drive` | A commit on `main` |
| Publishes | No — a human merges | **Yes** |
| Runs when | The Mac is awake and logged in | Always |

The two cannot corrupt each other: the workflow pushes only to `main`, the local job
pushes only to `sync/drive`, and the local job resets that branch from `main` at the start
of every run, so it will simply pick up whatever the cloud already published.

!!! warning "The failure mode is a stale pull request, not a conflict"
    A local run that proposes a change the cloud then publishes leaves an open pull
    request whose diff is already live. Merging it is a no-op; it just looks alarming. The
    local job closes its own stale PR only on a run that finds *no* changes, so one can sit
    there for days. If you are not going to watch for that, uninstall the local schedule:
    `./scripts/install-schedule.sh uninstall`.

!!! note "Keep the local watchdog, or replace what it did"
    `scripts/check-sync-ran.sh` answers "did a run happen at all?", which the run itself
    structurally cannot. In the cloud, the equivalent is that a *scheduled* run always
    posts to Discord — so **an absent Discord post on a Monday or Thursday is the signal**,
    exactly as it was locally. There is nothing that will page you about it. GitHub also
    disables scheduled workflows in repositories with no activity for 60 days; a club repo
    that goes quiet over a summer break is a realistic way for this to stop silently.

---

## Verified and unverified

Being explicit, because this page documents a system whose first real run has not
happened.

**Verified:**

- The workflow file parses as YAML, and every `run:` block parses as bash.
- `scripts/fetch_drive.py` compiles, and its RS256 assertion path works end to end: a
  locally generated key signs a JWT that Google's token endpoint accepts as well-formed
  and rejects only because that account does not exist.
- The claude.ai connector is **not** available under either supported credential. That is
  from Anthropic's own documentation, quoted and linked
  [above](#the-google-drive-problem) — it is not an inference from a failed attempt.

**Unverified until the first real run:**

| Claim | How it gets settled |
| --- | --- |
| The service account can actually read the club's Drive tree | `fetch_drive.py --dry-run` locally, before any workflow run |
| `anthropics/claude-code-action@v1` accepts `claude_code_oauth_token` with an empty `anthropic_api_key` alongside it | The first configured run either authenticates or fails in that step |
| The agent produces sensible per-machine subpages from the mirrored text | Read the dry-run diff |
| **A push made with `GITHUB_TOKEN` rebuilds GitHub Pages** | See below |

!!! danger "Check that Pages actually rebuilt after the first real publish"
    A push made with the built-in `GITHUB_TOKEN` **does not trigger workflow runs** — that
    is a documented GitHub rule, and it is why the sibling repo's daily job calls its Pages
    deploy directly instead of relying on `on: push`. This repo uses classic
    branch-based Pages, which is served by GitHub's own managed
    `pages-build-deployment` rather than by a workflow file in `.github/workflows/`, so it
    is not obviously subject to that rule. **It is genuinely unclear which way this
    falls, so verify it once:** after the first publishing run, check that the commit is on
    `main` *and* that the live site shows it. If the commit lands but the site does not
    change, the remedy is a fine-grained personal access token with `contents: write` set
    as `MNFC_PUSH_TOKEN`, passed to `actions/checkout` as `token:` — a push made with a PAT
    does fire the downstream build.

---

[← The Schedule](schedule.md){ .md-button } [Notifications →](notifications.md){ .md-button .md-button--primary }
