# Troubleshooting

Diagnosing a sync that did not do what you expected. Start with the symptom table, then read
the section for the failure mode it points at. For what each log marker means in isolation,
see the [log marker reference](sync-run.md#log-marker-reference), and for how a run reports
itself see [Notifications](notifications.md). **Before anything else:
`RESULT: no changes committed.` is a success — most runs end on it.**

---

## Contents

- [First: read the three sources](#first-read-the-three-sources)
- [Symptom table](#symptom-table)
- [The site looks stale](#the-site-looks-stale)
- [`SKIP: uncommitted local changes`](#skip-uncommitted-local-changes)
- [`FATAL: git pull failed`](#fatal-git-pull-failed)
- [`RESULT: claude exited N`](#claude-exited-non-zero)
- [`ERROR: push failed.`](#push-failed-after-retry)
- [Drive auth expired](#drive-auth-expired)
- [The Mac was off](#the-mac-was-off)
- [Discord posts not arriving](#discord-posts-not-arriving)
- [Discord returns HTTP 401 or 404](#discord-http-401-404)
- [Known unhandled cases](#known-unhandled-cases)

---

## First: read the three sources

Almost every diagnosis starts here, and one command covers all three:

```bash
cd /Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website
./scripts/install-schedule.sh status
```

It prints whether each job is loaded, the last recorded outcome, and the last 20 log lines.
The three underlying sources, if you want them individually:

| Source | Command | Answers |
| --- | --- | --- |
| The log | `tail -60 ~/Library/Logs/mnfc-website-sync.log` | What the last run did, step by step. |
| The status file | `cat ~/Library/Logs/mnfc-website-sync.status` | `OK` or `FAIL`, when, and why — one line. |
| Discord | the channel the webhook posts to | One embed per run, with the commit subject on `changed`. See [Notifications](notifications.md#discord). |
| Git | `git log --oneline -5 && git status --short` | Whether a commit exists, and whether the tree is clean. |

To see one run in isolation, search backwards for the `═` divider:

```bash
grep -n '^Sync started' ~/Library/Logs/mnfc-website-sync.log | tail -5
```

!!! tip "`no changes committed` is the healthy steady state"
    Publishing rule 7 says a sync that finds no Drive changes makes no commit. A log full of
    `RESULT: no changes committed.` and a status file reading `OK ... no changes` means the
    site matches Drive. Nothing needs doing. Do not "fix" it by forcing a commit.

---

## Symptom table

| Symptom | Likely cause | Go to |
| --- | --- | --- |
| Site missing a Drive change from days ago | Any of the below — start with `install-schedule.sh status` | [The site looks stale](#the-site-looks-stale) |
| Log shows `SKIP: uncommitted local changes present` | Someone left edits in the working tree | [SKIP](#skip-uncommitted-local-changes) |
| Log shows `FATAL: git pull failed` | Local `main` and `origin/main` diverged | [Diverged history](#fatal-git-pull-failed) |
| Log shows `FATAL: repo not found` | The repo moved, or this is not the right machine | [Single point of failure](schedule.md#single-point-of-failure) |
| Log shows `RESULT: claude exited N` | Agent error — auth, model, tool or prompt failure | [claude exited non-zero](#claude-exited-non-zero) |
| Log shows `ERROR: push failed.` | Commit exists locally, never reached GitHub | [Push failed](#push-failed-after-retry) |
| Log shows `WARNING: ... Retrying push...` then `Push succeeded on retry.` | Transient; already resolved | nothing to do — investigate only if recurring |
| Run completes but Drive content is missing from the site | Drive connector not authenticated for that run | [Drive auth expired](#drive-auth-expired) |
| Notification: `No sync in N days. Was the Mac off?` | No run happened | [The Mac was off](#the-mac-was-off) |
| Notification: `No sync has ever recorded a run.` | Schedule not installed, or never yet run | run `./scripts/install-schedule.sh` |
| `status` says `NOT loaded` | Job booted out, or never installed | run `./scripts/install-schedule.sh` |
| Commit is on GitHub but the page is unchanged | Pages build, browser cache, or a Pages settings change | [Deployment](deployment.md#when-a-push-does-not-appear) |
| No Discord messages at all | Webhook not configured, or the script is not executable | [Discord posts not arriving](#discord-posts-not-arriving) |
| Log shows `Discord: HTTP 401` or `Discord: HTTP 404` | Webhook revoked, deleted, or the URL is wrong | [Discord HTTP errors](#discord-http-401-404) |
| `RESULT: no changes committed.` | **Nothing.** Drive matched the site. | not a failure |

---

## The site looks stale

Work outwards from the published page to the source. Each step rules out one link in the
chain described in [Anatomy of a Sync Run](sync-run.md).

```bash
cd /Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website

# 1. Is the change on GitHub at all?
git fetch origin && git log --oneline -5 origin/main

# 2. Is there a local commit that never got pushed?
git rev-list origin/main..HEAD

# 3. Is the tree dirty, blocking every future run?
git status --short

# 4. What did the last run actually record?
cat ~/Library/Logs/mnfc-website-sync.status
tail -40 ~/Library/Logs/mnfc-website-sync.log

# 5. Are both jobs loaded?
./scripts/install-schedule.sh status
```

| Result | Meaning | Next |
| --- | --- | --- |
| Step 1 shows the change | The repo is current — the problem is downstream | [Deployment](deployment.md#when-a-push-does-not-appear) |
| Step 2 prints a SHA | The commit never left the machine | [Push failed](#push-failed-after-retry) |
| Step 3 prints anything | Every run is skipping | [SKIP](#skip-uncommitted-local-changes) |
| Step 4 reads `FAIL` | Read the detail field and jump to that section | this page |
| Step 4 is old or absent | No run happened | [The Mac was off](#the-mac-was-off) |
| All clean, content still missing | Drive itself may not say what you think it says | [Data contracts](../data-contracts.md) |

**If everything checks out, suspect the source before the pipeline.** The agent publishes only
what a Drive doc supports and only from the folders `SYNC.md` names. A change made in a
document the contract does not read — or content that publishing rules exclude, such as
budgets, vendor pricing, or the general-member roster — will never appear on the site no
matter how many times the sync runs. Confirm the Drive location against
[Data contracts](../data-contracts.md) first.

To force a run once the blockage is cleared:

```bash
./scripts/sync-from-drive.sh
tail -f ~/Library/Logs/mnfc-website-sync.log
```

---

## `SKIP: uncommitted local changes` { #skip-uncommitted-local-changes }

**Cause.** The dirty-tree guard found a modified working tree or a non-empty index and exited
`0` without doing anything. See
[the guard](sync-run.md#step-2-the-dirty-tree-guard).

!!! danger "This one repeats until a human fixes it"
    The skip is not self-clearing. Every subsequent run — Monday and Thursday alike — hits the
    same guard and exits the same way, so the site stops tracking Drive indefinitely while the
    exit code stays `0` and the log fills with clean-looking runs. The macOS notification and
    the `fail` Discord embed are the only things that make it visible on the day it starts.

**Fix.** Look at what is dirty, decide whether it is wanted, then clear the tree:

```bash
cd /Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website
git status --short
git diff                      # inspect before discarding anything

# keep the work:
git add -A && git commit -m "..." && git push origin main

# set it aside:
git stash

# discard it (only if you are certain):
git checkout -- . && git clean -fd

./scripts/sync-from-drive.sh
```

!!! warning "Hand edits to project copy get overwritten anyway"
    If the dirty change is edited project text in `index.html` or `stepper.html`, committing
    it is a temporary fix — the next sync rewrites that content from Drive. Put the change in
    the Drive doc instead. Design and structure changes to the HTML and CSS are safe to make
    directly; project *content* is not. See [Data contracts](../data-contracts.md).

---

## `FATAL: git pull failed` { #fatal-git-pull-failed }

**Cause.** `git pull --ff-only origin main` could not fast-forward. Local `main` and
`origin/main` have diverged: there is at least one local commit that is not on the remote and
at least one remote commit that is not local. The usual origin is a commit made by a failed
push earlier (see below) followed by someone pushing from elsewhere — a direct edit in the
GitHub web UI, or a run from another clone.

**Diagnose.**

```bash
cd /Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website
git fetch origin
git log --oneline --graph --all -15
git rev-list --left-right --count origin/main...HEAD   # remote-only <TAB> local-only
```

**Fix**, choosing by what the counts show:

```bash
# Local commits are wanted and remote is ahead: replay yours on top.
git rebase origin/main
git push origin main

# The local commits are junk (a bad automated commit, a stray test):
git reset --hard origin/main

# The remote is wrong and local is right — inspect first, and be sure.
git log origin/main --oneline -5
```

The run stops before touching the agent, so nothing was published and nothing was lost. Once
the histories agree, `./scripts/sync-from-drive.sh` and confirm the log.

**Why the script refuses to merge here.** A merge would run unattended. A conflict in
`index.html` leaves conflict markers in a tracked file, the agent then reads that file as the
current state of the site, and a later successful run can commit `<<<<<<<` into the published
page — a visible defect on a public page, from a failure mode with no obvious symptom in the
log. Stopping keeps both histories intact and puts a human in front of the decision.

---

## `RESULT: claude exited N` { #claude-exited-non-zero }

**Cause.** The headless `claude -p` invocation returned non-zero. Common reasons: the Claude
Code session is not authenticated, the `claude` binary is missing from
`/Users/leonardjin/.local/bin/claude`, the Drive connector failed, or the agent hit an error
mid-task.

!!! danger "This branch does not exit non-zero"
    After logging `RESULT: claude exited N`, recording `FAIL`, and notifying, the script falls
    through to `Sync finished:` and **exits `0`**. The agent's status is never propagated.
    Anything monitoring the job by exit code — `launchctl` job state, a CI wrapper, a shell
    `&&` chain — sees a successful run. Only the notification and
    `~/Library/Logs/mnfc-website-sync.status` — plus the `✗ Sync failed` embed in Discord —
    distinguish this from a healthy run, and the macOS notification is fire-and-forget. Do not
    build alerting on this script's exit code.

**Diagnose.** The agent's own output sits in the log immediately above the `RESULT:` line —
that is where the actual error message is.

```bash
tail -120 ~/Library/Logs/mnfc-website-sync.log

# is the binary there and runnable?
ls -l /Users/leonardjin/.local/bin/claude
/Users/leonardjin/.local/bin/claude --version
```

**Fix.** Reproduce interactively, where errors are visible and fixable:

```bash
cd /Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website
claude          # check auth and connector status in a normal session
```

Then re-run under `launchd`'s environment rather than your shell's — an agent that works in a
terminal and fails under the schedule is almost always an environment difference:

```bash
launchctl kickstart -k "gui/$(id -u)/com.mnfc.website-sync"
tail -f ~/Library/Logs/mnfc-website-sync.log
```

If the binary path changed, update `CLAUDE` in `scripts/sync-from-drive.sh` — nothing verifies
it, and a missing binary surfaces only as this branch.

---

## `ERROR: push failed.` { #push-failed-after-retry }

**Cause.** The agent committed, the push-verification check found the commit unpushed, and
both the agent's push and the script's single retry failed. Typically no network, no SSH agent
under `launchd`, an expired or removed deploy key, or the remote moved ahead in between.

!!! warning "This state hides itself from the next run"
    The commit exists, so the working tree is clean — the dirty-tree guard will not catch it.
    The next scheduled run pulls, finds Drive already matching the local HTML, and logs
    `RESULT: no changes committed.` while the published site is still missing the change. The
    `FAIL commit <sha> not pushed` record, the notification and the `✗ Sync failed` embed are
    the only signals, and a later `OK` record overwrites the status file — within four days at
    most, since the job runs Monday and Thursday. Push it the same day you see it.

**Diagnose and fix.**

```bash
cd /Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website

git rev-list origin/main..HEAD        # non-empty = still unpushed
git log --oneline -3

git push origin main                  # usually just works once the network is back
```

If the push fails again, test authentication the way `launchd` sees it — with no
shell-provided `ssh-agent`:

```bash
env -i /usr/bin/git -C /Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website \
  push --dry-run origin main
ssh -T git@github.com
```

A `403` here is a different problem entirely — that is the read-only-token failure that made
the cloud routine unworkable, and it means the push is being attempted with the wrong
credentials. See [Deployment](deployment.md#why-local-and-not-a-cloud-routine).

If `git push` reports a non-fast-forward, the remote moved: go to
[`FATAL: git pull failed`](#fatal-git-pull-failed) and reconcile first.

---

## Drive auth expired { #drive-auth-expired }

**Cause.** The Google Drive connector session used by the four
`mcp__claude_ai_Google_Drive__*` tools is no longer valid.

**This is the least visible failure mode in the system.** The script has no auth check — auth
is delegated entirely to the agent. Depending on how the connector fails, the run either exits
non-zero (landing in [`claude exited N`](#claude-exited-non-zero)) *or* completes normally
having read nothing, finds no differences it can act on, and logs
`RESULT: no changes committed.` with an `OK` record. The second case is indistinguishable from
a healthy quiet run from the log alone, and the watchdog will not complain because a run did
happen and recorded `OK`. Discord is no help either: that run posts the same grey
`✓ Site checked` embed a genuinely quiet run posts.

**Diagnose.** The tell is a run whose agent output shows no Drive reads, or a stretch of
`no changes` runs spanning a Drive edit you know was made.

```bash
grep -n 'Sync started\|RESULT:' ~/Library/Logs/mnfc-website-sync.log | tail -20
```

Then read the agent output for the most recent run and look for whether it enumerated the
`Build the Fab` subfolders at all.

**Fix.** Re-authenticate the connector in an interactive Claude Code session, then verify
under `launchd` — a connector that works in a terminal has not been shown to work on a
scheduled run:

```bash
launchctl kickstart -k "gui/$(id -u)/com.mnfc.website-sync"
tail -f ~/Library/Logs/mnfc-website-sync.log
```

The 2026-08-19 verification confirmed the connector does authenticate under `launchd`'s
minimal environment, so a failure here is a real auth expiry rather than an environment
problem.

---

## The Mac was off { #the-mac-was-off }

**Cause.** No run happened. `StartCalendarInterval` is not a wake-up alarm — see
[Sleep, wake, and off](schedule.md#sleep-wake-and-off).

| State | Outcome |
| --- | --- |
| Asleep at 08:13 on a scheduled day | Runs on next wake. Nothing to do. |
| Off through the whole slot | That run is skipped; the next slot is at most four days away. |

**This is expected behavior, not a fault, and it is harmless.** The sync is not incremental:
it reads Drive's current state and rewrites the HTML to match. Nothing queues, nothing is
lost, and the next run picks up every change made during the missed slot in one pass.

**Fix**, if you do not want to wait for the next scheduled run:

```bash
cd /Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website
./scripts/sync-from-drive.sh
tail -f ~/Library/Logs/mnfc-website-sync.log
```

The watchdog notifies with `No sync in N days. Was the Mac off?` once the status file is more
than `STALE_DAYS=4` days old — but only when the Mac is on at 14:13 on a Monday or Thursday to
run it. A machine off all day runs neither job and the alert arrives late, whenever it next
wakes. The threshold is `4` because Thursday → Monday is the longest healthy gap; see
[`STALE_DAYS`](schedule.md#the-watchdog).

!!! note "The watchdog never posts to Discord"
    `check-sync-ran.sh` raises macOS notifications only. `No sync in N days` will not appear
    in the channel — an absence of Discord posts is itself the signal that no run happened.
    See [Notifications](notifications.md#what-fires-on-each-outcome).

---

## Discord posts not arriving { #discord-posts-not-arriving }

**Cause.** The sync ran, but nothing appeared in the channel. Discord is designed to fail
silently — `notify-discord.sh` exits `0` when it is not configured — so the absence of posts
is not by itself evidence that the sync failed. Check the log first: a run that happened at
all leaves a `Discord:` line explaining what it did.

```bash
grep -n 'Discord:' ~/Library/Logs/mnfc-website-sync.log | tail -10
```

| Log line | Cause | Fix |
| --- | --- | --- |
| `Discord: not configured (no <path>); skipping notification.` | `~/.config/mnfc-sync/discord-webhook` does not exist | Create it — see [Setting up Discord](notifications.md#setting-up-discord) |
| `Discord: webhook file is empty; skipping notification.` | The file exists but holds only whitespace | Write the webhook URL into it |
| `Discord: send failed -- <error>` | Network failure, DNS, or a timeout past 15 seconds | Retry by hand; there is no automatic retry |
| *no `Discord:` line at all* | `discord()` returned early because `scripts/notify-discord.sh` is not executable, **or** no run happened | `chmod +x scripts/notify-discord.sh`, then check whether a run happened at all |

Confirm the config file exists and is non-empty, then send a test post:

```bash
ls -l ~/.config/mnfc-sync/discord-webhook
wc -c ~/.config/mnfc-sync/discord-webhook     # 0 bytes = empty, same as missing
ls -l /Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website/scripts/notify-discord.sh
./scripts/notify-discord.sh --test
```

`--test` posts the `ok` style with the headline `Test message`. If that arrives and scheduled
runs do not, the problem is upstream: no run is happening. Go to
[The Mac was off](#the-mac-was-off).

!!! warning "`install-schedule.sh` does not `chmod +x` this script"
    It runs `chmod +x` on `sync-from-drive.sh` and `check-sync-ran.sh` only. `discord()` opens
    with `[ -x "$DISCORD" ] || return 0`, so a `notify-discord.sh` that lost its executable bit
    — a fresh clone with odd permissions, a file copied rather than checked out — posts
    nothing and logs nothing about it. The sync itself keeps working perfectly, which is why
    this one is easy to miss for weeks.

---

## Discord returns HTTP 401 or 404 { #discord-http-401-404 }

**Cause.** The webhook URL was accepted by the network but rejected by Discord.

```bash
grep -n 'Discord: HTTP' ~/Library/Logs/mnfc-website-sync.log | tail -5
```

| Code | Meaning | Fix |
| --- | --- | --- |
| `401` | The token half of the URL is wrong or has been regenerated | Re-copy the URL from **Server Settings → Integrations → Webhooks** |
| `404` | The webhook was deleted, or the URL is malformed | Create a new webhook and rewrite the config file |
| `403` | The webhook lacks access to the channel it targets | Recreate it against a channel the integration can post to |
| `429` | Rate-limited | Nothing — one post per run is far under any limit; investigate if a loop is calling it |

Both `401` and `404` mean the same practically: **the URL in
`~/.config/mnfc-sync/discord-webhook` no longer identifies a live webhook.** A webhook URL
carries its own authority, so there is nothing else to check — no account, no token scope, no
permission grant on the sync's side. Issue a new webhook, overwrite the file, re-`chmod 600`,
and test:

```bash
echo 'https://discord.com/api/webhooks/...' > ~/.config/mnfc-sync/discord-webhook
chmod 600 ~/.config/mnfc-sync/discord-webhook
./scripts/notify-discord.sh --test
```

!!! danger "A revoked webhook fails without failing the sync"
    `notify-discord.sh` exits `1` on an HTTP error, but `discord()` in `sync-from-drive.sh`
    ends in `|| true`, so the run continues and reports success. The sync is right to do this
    — publishing the site matters more than announcing it — but it means a dead webhook
    produces a silent channel and a healthy-looking log, and silence in the channel is
    indistinguishable from the sync never running. If Discord goes quiet, `grep 'Discord:'` the
    log before assuming the schedule broke.

---

## Known unhandled cases

Stated so nobody assumes coverage that does not exist:

| Gap | Consequence |
| --- | --- |
| **The `claude` failure branch exits `0`** | Exit-code monitoring cannot detect a failed run. The notification and `STATUS_FILE` are the only signals. |
| **No log rotation** | `~/Library/Logs/mnfc-website-sync.log` grows without bound. Both jobs append to it forever; nothing truncates or archives it. Trim it by hand if it becomes unwieldy. |
| **No lock against overlapping runs** | Nothing stops a manual `./scripts/sync-from-drive.sh` from starting while the scheduled run is mid-flight. Two agents would edit the same working tree and commit over each other. The watchdog checks whether the sync is running before it reports; the sync makes no such check about itself. Look at the log before starting a manual run. |
| **No second push retry** | One retry, then `ERROR: push failed.` and abandonment. |
| **No check that `claude` exists** | A missing or moved binary surfaces only as `RESULT: claude exited N`. |
| **No Drive auth check** | Delegated to the agent; can present as a silent `no changes` run. |
| **Notifications are fire-and-forget** | `notify` ends in a `\|\| true` fallback. An alert raised during Do Not Disturb, or on a locked machine, is simply gone. `STATUS_FILE` is the durable record. |
| **Discord failures are not retried** | `discord()` ends in `\|\| true`. A `Discord: HTTP <code>` line in the log is the only trace, and the run still reports success. |
| **The watchdog does not reach Discord** | `check-sync-ran.sh` calls `notify` only. `No sync in N days` is a macOS banner on one Mac and nowhere else. |
| **One machine only** | Every path is absolute under `/Users/leonardjin`. See [Single point of failure](schedule.md#single-point-of-failure). |
| **Pages settings are outside the repo** | Nothing in version control describes the GitHub Pages configuration. See [Deployment](deployment.md#what-is-not-in-the-repo). |

---

[← Notifications](notifications.md){ .md-button } [Deployment →](deployment.md){ .md-button .md-button--primary }
