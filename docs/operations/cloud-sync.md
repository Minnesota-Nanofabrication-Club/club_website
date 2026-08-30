# The Cloud Sync

The sync as a GitHub Actions workflow: the two designs it replaced and why each failed, the
secrets it needs and how to mint each one, how to trigger and read a run, and what is
verified versus assumed. What happens *inside* a run, step by step, is
[Anatomy of a Sync Run](sync-run.md). **This workflow does not publish. It force-pushes one
branch, opens a pull request, and a human merge is what reaches the live site — and it reads
Drive through a Google service account, not through the claude.ai connector.**

---

## Contents

- [Why the sync lives here](#why-the-sync-lives-here)
- [What the workflow does](#what-the-workflow-does)
- [The schedule](#the-schedule)
- [It proposes; a human merges](#it-proposes-a-human-merges)
- [The Google Drive problem](#the-google-drive-problem)
- [The secrets](#the-secrets)
- [Creating the service account](#creating-the-service-account)
- [Running it by hand](#running-it-by-hand)
- [Reading a failed run](#reading-a-failed-run)
- [Verified and unverified](#verified-and-unverified)

---

## Why the sync lives here

Three designs, in order. Each was replaced for a different reason, and neither predecessor
exists any more.

### 1. A Claude Code cloud routine — could not write to the repo

The first design was a scheduled Claude Code cloud routine: wake on a schedule, read the club
Drive through the Google Drive connector, compare Drive against the HTML, edit, commit, push.
Every step worked except the last.

**Cloud routines get a read-only GitHub token on this repository.** `git push` returned `403`,
and the GitHub API returned `403` for the same reason, so committing through REST instead of
over git failed identically. Both are blocked by the same token scope, so there was no
workaround at the routine's level; granting write access requires a Claude Team or Enterprise
plan. Moving to pull requests would not have rescued it either — pushing a branch and calling
`gh pr create` are both writes against the same repo.

**The failure was silent from the outside.** The routine ran on schedule, reported activity,
and the site simply never changed — which looks exactly like the normal, healthy outcome of a
run with no Drive changes to apply. Commit `e1cf67f` is the moment that was written off.

### 2. A `launchd` job on a laptop — could not be relied on to run

The replacement was a per-user `launchd` agent, `com.mnfc.website-sync`, running
`scripts/sync-from-drive.sh` on Monday and Thursday at 08:13, plus a watchdog job that
answered "did a run happen at all?". It worked: git on the laptop already had push access over
SSH, so the whole loop closed at no extra cost, and the write-back path was proved end to end
on 2026-08-18 and again under `launchd` itself on 2026-08-19.

On **2026-08-27** the scheduled run failed thirty-six minutes in with `Your computer went to
sleep mid-response`. The mechanism, in order:

1. The job had to be a **per-user agent in the `gui/$(id -u)` domain** — it needed the
   logged-in user's Drive connector session, SSH key and `gh` login, none of which exist in a
   system domain. A `gui/` agent only runs while that user has an active login session.
2. `StartCalendarInterval` **is not a wake-up alarm.** `launchd` does not wake a sleeping Mac;
   it runs a missed job at whatever wake happens next, and on a sleeping laptop that is
   normally a maintenance DarkWake lasting a few seconds.
3. Wrapping the job in `caffeinate -i -m -s` fixed only the *second* half of that failure —
   the machine sleeping out from under a run already in progress. `caffeinate` keeps an awake
   machine awake; it has no power to start one.
4. `pmset repeat wake` can schedule a power-on on Intel Macs. **That Apple Silicon machine had
   no scheduled power-on capability**, so nothing could guarantee it was awake at 08:13 on a
   Monday.

!!! danger "A laptop schedule is best-effort by construction, not by accident"
    Every layer above was working as designed. Nothing was misconfigured and nothing could be
    tuned to fix it. As long as the trigger lives on a machine that can be closed, off, or
    logged out, "did the sync run?" has no reliable answer — and the failure is silent, so the
    only symptom is content that slowly ages. That is why the schedule moved to a hosted
    runner, which is awake because it does not exist until the cron fires.

### 3. This workflow

`.github/workflows/sync-from-drive.yml` is now the only sync. The local machinery was deleted
in commit `a0a76d9` — `sync-from-drive.sh`, `install-schedule.sh`, `check-sync-ran.sh`, both
launchd jobs and their plists, and the log and status files under `~/Library/Logs`. None of it
exists anywhere.

!!! note "The deletion waited for the cloud pipeline to run green"
    The order mattered. The precondition was met first: the full cloud path — scheduler, Drive
    mirror, agent, guard, pull request, Discord — ran end to end before anything local was
    removed. Keeping a working fallback while its replacement was unproven was right; keeping
    it afterwards would just have been a second thing that can fire. Both schedules pointed at
    Monday 08:13, and two agents rewriting the same repository at the same time would have
    raced — with the local one publishing without the review gate this one enforces.

---

## What the workflow does

One job, in order. The step-by-step reading is [Anatomy of a Sync Run](sync-run.md).

| Step | What it does | Fails the run? |
| --- | --- | --- |
| Check out the repo | `actions/checkout@v5`, full history | Yes |
| Check the run is configured | Looks for the Claude and Drive secrets | No — logs a `::notice::` and exits green |
| Sanity-check the repo | `CLAUDE.md`, `SYNC.md`, `index.html`, `style.css`, `scripts/fetch_drive.py` all present; the script compiles | Yes |
| Mirror Drive | `scripts/fetch_drive.py` pulls the Drive tree to `$RUNNER_TEMP/drive` | Yes |
| Record the tree before the agent runs | `git rev-parse HEAD` — the baseline for the guard | Yes |
| Sync the site | `anthropics/claude-code-action@v1` reads the mirror and edits the HTML | Yes |
| Check the agent stayed inside the site | Refuses to push if protected paths changed | Yes |
| Open a review pull request | Force-pushes `sync/drive`, then opens or comments on the PR | Yes |
| Job summary / Discord / failure issue | Reporting | No |

---

## The schedule

```yaml
- cron: "13 13 * * 1,4"
```

**GitHub cron is always UTC and does not observe US daylight saving.** A cron written to land
at 08:13 Central in summer therefore lands at 07:13 Central in winter, and there is no
expression that fixes it — the workflow would need two crons and a guard step, which is more
machinery than a one-hour drift deserves.

| Period | `13:13 UTC` is | Note |
| --- | --- | --- |
| CDT, roughly mid-March to early November | 08:13 America/Chicago | The hour the club is used to |
| CST, roughly early November to mid-March | 07:13 America/Chicago | An hour early, which nobody will notice |

`1,4` is Monday and Thursday, so the longest gap between runs is four days. The odd minute is
deliberate: away from the top of the hour there is less competition for the runner queue.
GitHub also defers scheduled runs under peak load, so treat the time as "morning-ish", never
as a guaranteed minute.

---

## It proposes; a human merges { #it-proposes-a-human-merges }

The workflow never writes `main`. It force-pushes one reusable branch, `sync/drive`, and
opens or updates a single pull request; merging that pull request is the approval step and the
publishing step at once.

Two things back the reviewer up, and both are in the workflow rather than in the prompt:

- **The guard step.** After the agent finishes, `git diff --name-only` against the pre-run SHA
  over `docs/ .github/ scripts/ mkdocs.yml README.md CLAUDE.md SYNC.md`. Any hit and the run
  fails without pushing. The prompt already tells the agent to leave those alone; a prompt is
  a request, and this is the check. Without it, one confused run could rewrite the
  documentation of the sync from inside the sync — exactly the drift `CLAUDE.md` warns about —
  or edit the workflow that is running it.

  `DRIVE_NOTES.md` is deliberately **not** protected. It is the agent's own working memory and
  it has to be able to prune and extend it; the split is that the agent owns its observations
  and humans own the rules.

- **Uncommitted leftovers are discarded, never swept up.** If the agent edited without
  committing, the guard runs `git reset --hard`. Those edits sat on a tree nobody reviewed;
  committing them because they happened to be there is how unreviewed content reaches a
  proposal.

!!! warning "The review gate is load-bearing, and it has already caught a real failure"
    On 2026-08-30 a run published three people as machine leads inferred purely from Drive file
    ownership — no document said any of it. The pull request is where that was caught, before
    two members' full names reached a public, search-indexed page. The rule now lives in the
    prompt as well as in `SYNC.md`, but the gate is what stopped it. Read the diff; do not
    merge on the strength of a green check.

---

## The Google Drive problem { #the-google-drive-problem }

The deleted local job read Drive with `mcp__claude_ai_Google_Drive__*` — the **claude.ai
Google Drive connector**, which Claude Code inherits from an interactive claude.ai login. The
obvious question when moving to CI is whether that connector comes along with
`CLAUDE_CODE_OAUTH_TOKEN`.

**It does not, and this is documented rather than inferred.** From
[Claude Code authentication](https://code.claude.com/docs/en/authentication), on the token
`claude setup-token` mints:

> It can only make model requests, so it can't establish Remote Control sessions or fetch
> claude.ai connectors. MCP servers you configure locally still work.

[The MCP page](https://code.claude.com/docs/en/mcp) closes the other door: connectors are
fetched **only** when the active authentication is a claude.ai subscription *login*, and are
skipped outright when `ANTHROPIC_API_KEY` is active. Both credentials this workflow accepts are
therefore excluded. The same page notes that a remote MCP server needing OAuth cannot complete
that flow in a non-interactive run at all — there is no `/mcp` panel and nobody at a browser
to consent.

So the connector is not a path, and the workflow does not attempt it. `scripts/fetch_drive.py`
mirrors Drive to plain files as a **service account** before the agent starts, and the agent
reads files — the one thing it needs no credentials for.

| | claude.ai connector | Service account mirror |
| --- | --- | --- |
| Tools the agent uses | `mcp__claude_ai_Google_Drive__*` | `Read`, `Glob`, `Grep` |
| Auth | Interactive claude.ai login | RS256 JWT, no human |
| Works in Actions | **No** — documented above | Yes |
| Used by | the deleted `launchd` job | `.github/workflows/sync-from-drive.yml` |

!!! note "If you want to re-test the connector question later"
    Add `show_full_output: true` to the action's `with:` block, or `--debug='mcp,startup'` to
    `claude_args`. The stream's first `system/init` event lists `mcp_servers`,
    `mcp_server_errors` and the full `tools` array. Connectors working would show a Google
    Drive server with `status: "connected"` and `mcp__claude_ai_Google_Drive__*` entries in
    `tools`. Today it shows neither — not as an error, just as silent absence, because the
    fetch never happens.

### Why the mirror never lands in the repo

`fetch_drive.py` writes to `$RUNNER_TEMP/drive` and **refuses an `--out` path underneath the
repository root.** The Drive tree contains budgets, BOM costs, vendor pricing and sponsorship
correspondence. Inside the working tree that material is one `git add -A` away from being in
the published history forever, and git history is not something you can quietly un-publish.
Outside the tree there is no such path.

Two smaller behaviours follow the same logic:

- Folders tagged `[LR]`, and `[C] Finances`, `[C] Funding` and `[C] Logistics`, are **not
  mirrored at all.** `SYNC.md` says they are never read for content; not fetching them keeps
  them out of the agent's context entirely rather than relying on it to remember.
- A mirror that fetched **zero files fails the run.** An empty mirror and a healthy one are
  indistinguishable downstream: the agent would read an empty directory, conclude Drive says
  nothing, and propose stripping the site.

---

## The secrets

| Secret | Required | What it is | If missing |
| --- | --- | --- | --- |
| `CLAUDE_CODE_OAUTH_TOKEN` | one of these two | Claude subscription token from `claude setup-token`. Bills against the Max plan. **This is the intended credential.** | Falls back to the API key |
| `ANTHROPIC_API_KEY` | one of these two | Console API key. Bills per token. A fallback, not the normal path | Falls back to the OAuth token |
| `GDRIVE_SERVICE_ACCOUNT_JSON` | **yes** | The whole service account key file, verbatim | Run exits green, does nothing |
| `DISCORD_WEBHOOK_URL` | no | Channel webhook. The workflow writes it to the runner's `~/.config/mnfc-sync/discord-webhook` for `notify-discord.sh` | The Discord steps are skipped; the run is otherwise normal |
| `DISCORD_MENTION` | no | e.g. `<@USER_ID>` or `<@&ROLE_ID>`, written alongside the webhook | Posts still arrive, they just do not ping anyone |

**Prefer the OAuth token.** It bills against the Claude Max plan Leonard already pays for; an
API key bills per token on top of it, for the same work. When both are set the workflow forces
the API key input empty so the OAuth token wins — the precedence is a property of this repo's
workflow file, not of the action's internal resolution order, because if that order ever
changed upstream a run expected to be free could start charging.

```bash
# Claude, preferred. Copy the token it prints, then paste it at the prompt.
claude setup-token
gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo Minnesota-Nanofabrication-Club/club_website

# Claude, fallback.
gh secret set ANTHROPIC_API_KEY --repo Minnesota-Nanofabrication-Club/club_website

# Drive. Redirect the file — do not paste it, it is multi-line JSON.
gh secret set GDRIVE_SERVICE_ACCOUNT_JSON \
  --repo Minnesota-Nanofabrication-Club/club_website < ~/Downloads/mnfc-drive-key.json

# Discord, optional.
gh secret set DISCORD_WEBHOOK_URL --repo Minnesota-Nanofabrication-Club/club_website
gh secret set DISCORD_MENTION     --repo Minnesota-Nanofabrication-Club/club_website

gh secret list --repo Minnesota-Nanofabrication-Club/club_website
```

!!! warning "`claude setup-token` mints a credential for the whole Claude account"
    Anyone holding it can spend against the Max plan. It lives in exactly one place — the
    Actions secret — and GitHub will never show it again after you set it, which is fine:
    re-run `claude setup-token` to mint a new one. Never paste it into an issue, a commit, or a
    screenshot. If it leaks, mint a replacement immediately; that is the revocation.

!!! note "Missing secrets are a notice, not a failure"
    A run with nothing configured logs `::notice::`, writes a setup summary, and exits
    **green**. Between this workflow landing on `main` and the secrets being set, every cron
    would otherwise be a red X — and a red X that is always there is one nobody reads.

---

## Creating the service account

Once, in the [Google Cloud console](https://console.cloud.google.com/), with the Google
account that owns the Drive folder.

**1. A project.** Reuse one or make a new one — `mnfc-website-sync` is the obvious name.

**2. Enable the Drive API.** *APIs & Services → Library → Google Drive API → Enable*.
Skipping this is the most common setup mistake; the symptom is a `403` from `fetch_drive.py`
naming the project, not the folder.

**3. Create the service account.** *IAM & Admin → Service Accounts → Create service account*.
Name it `website-sync`. **Grant it no project roles** — it needs none. Its access comes
entirely from the Drive folder being shared with it, which is the whole point: the key cannot
reach anything else in the account.

**4. Make a key.** Open the account → *Keys → Add key → Create new key → JSON*. The file
downloads once. It is a credential; treat it like a password.

**5. Copy its email.** On the account's page, `client_email` in the JSON — it looks like
`website-sync@mnfc-website-sync.iam.gserviceaccount.com`.

**6. Share the Drive root folder with that email, read-only.** In Drive, right-click the club
root folder (**Ultra Hardcore Chip D&F**, id `1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP`) → *Share* →
paste the address → set the role to **Viewer** → uncheck "Notify people" → Share.

!!! danger "Share the root folder, and share it as Viewer"
    **Drive sharing is not inherited from your own access.** The service account is a separate
    principal; it sees exactly what has been shared with it and nothing else. Share a subfolder
    rather than the root and `fetch_drive.py` fails with a `404` on the root id — which reads
    like a wrong folder id and sends you looking in the wrong place. Grant **Viewer**, not
    Editor: the script requests the read-only Drive scope, so an Editor grant buys nothing and
    means a leaked key could modify the club's documents.

**7. Set the secret and test.**

```bash
gh secret set GDRIVE_SERVICE_ACCOUNT_JSON \
  --repo Minnesota-Nanofabrication-Club/club_website < ~/Downloads/mnfc-drive-key.json

# Locally, to see exactly what the runner will see. --dry-run writes nothing.
export GDRIVE_SERVICE_ACCOUNT_JSON="$(cat ~/Downloads/mnfc-drive-key.json)"
python3 scripts/fetch_drive.py --out /tmp/drive --dry-run
```

**8. Delete the downloaded key file.** It is in the Actions secret now. A service account key
sitting in `~/Downloads` is a Drive credential anything on the machine can read.

`fetch_drive.py` needs only the Python standard library and the `openssl` command — the
standard library has no RSA, and the service account's assertion has to be RS256-signed.
`openssl` is present on every GitHub runner and on macOS. There is no `pip install` step, for
the same reason the site has no build step.

---

## Running it by hand

**Actions → Sync from Drive → Run workflow.** The one input is **dry run**.

| Dry run | What happens |
| --- | --- |
| ticked | The mirror is pulled, the agent runs and commits *on the runner*, the full diff is printed, and nothing is pushed. The runner is destroyed with the commit on it |
| unticked | Identical, then the commit is force-pushed to `sync/drive` and a pull request is opened or updated. **Still nothing on the live site** until someone merges |

**Tick dry run when testing a change to the prompt.** It exercises the service account, the
agent and the guard step, and prints exactly what would have been proposed, at the cost of one
agent run and no branch churn.

Or from a terminal:

```bash
gh workflow run "Sync from Drive" \
  --repo Minnesota-Nanofabrication-Club/club_website -f dry_run=true

gh run watch --repo Minnesota-Nanofabrication-Club/club_website
```

Running the Drive pull alone, without spending an agent run, is step 7 above.

---

## Reading a failed run

A failed run does three things: it fails the checks tab, it posts `✗ Sync failed` to Discord
with the run URL, and it opens or comments on a GitHub issue labelled `drive-sync-failure`.
**The issue is commented on by every subsequent failure and closes itself on the next
success**, so one open issue means "still broken" and no open issue means "the last run was
fine" — a silent cron failure is how the sibling repo went stale for weeks.

Open the run, find the first red step, and match it:

| Step that failed | Almost always | Fix |
| --- | --- | --- |
| Mirror Drive, `404` on the root id | The folder is not shared with the service account, or only a subfolder is | Re-do step 6 on the **root** folder |
| Mirror Drive, `403` | The Drive API is not enabled on the project | Step 2 |
| Mirror Drive, `invalid_grant` | The key was deleted or disabled in the console | Mint a new key, re-set the secret |
| Mirror Drive, "not valid JSON" | The secret holds part of the key file, not all of it | Re-set it with `< key.json`, never by pasting |
| Mirror Drive, "nothing was fetched" | The account can see the folder id but no files in it | Sharing landed on the wrong address |
| Sync the site | Credit exhausted, a bad token, or the agent hit `--max-turns 200` | Read the step log; the action prints the reason |
| Check the agent stayed inside the site | The agent edited `docs/`, `scripts/` or a workflow | Nothing was pushed. Read the listed paths in the log, then re-run |
| Open a review pull request | `--force-with-lease` lost a race, or branch protection blocks the push | Check whether someone else pushed `sync/drive`; re-run |

!!! tip "A green run that changed nothing is the normal case"
    Most runs find that the site already matches Drive, make no commit, and post
    `✓ Site checked`. That is success, not a stall. The failure worth worrying about is the
    *absent* post — see [Notifications](notifications.md#what-none-of-these-channels-covers).

---

## Verified and unverified

**Verified:**

- The full cloud path ran green end to end — scheduler, Drive mirror, agent, guard, pull
  request, Discord — before the local machinery was deleted in `a0a76d9`.
- The service account can read the club's Drive tree, and `fetch_drive.py`'s RS256 assertion
  path works against Google's token endpoint.
- The guard is not theoretical: the review gate caught three unsupported machine leads on
  2026-08-30, which is why the metadata-inference ban is now in the prompt as well as in
  `SYNC.md`.
- The claude.ai connector is **not** available under either supported credential. That is from
  Anthropic's own documentation, quoted and linked [above](#the-google-drive-problem) — not an
  inference from a failed attempt.

**Not a concern any more:** a push made with the built-in `GITHUB_TOKEN` does not trigger
workflow runs, which used to matter when the workflow pushed `main` directly. It no longer
does. The only thing this workflow pushes is `sync/drive`, and `main` moves when a **person**
merges the pull request — an ordinary user-authored merge, which rebuilds Pages the same way
any hand-pushed commit does.

**Still worth watching:**

| Claim | How it gets settled |
| --- | --- |
| The agent keeps producing sensible per-machine subpages from the mirrored text | Read the diff on every proposal. That is what the review gate is for |
| `DRIVE_NOTES.md` stays under its 20-entry cap and prunes expired entries | It appears in the proposal diff whenever the agent edits it |
| The schedule keeps firing | GitHub disables scheduled workflows in repositories with 60 days of no activity. An absent Discord post on a Monday or Thursday is the signal |

---

[← Anatomy of a Sync Run](sync-run.md){ .md-button } [Notifications →](notifications.md){ .md-button .md-button--primary }
