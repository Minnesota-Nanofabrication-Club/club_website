# Troubleshooting

Diagnosing a sync that did not do what you expected. Start with the symptom table, then read
the section for the failure mode it points at. For what each log marker means in isolation,
see the [log marker reference](sync-run.md#log-marker-reference), and for how a run reports
itself see [Notifications](notifications.md). **Before anything else: two states look like
failures and are not — `RESULT: no changes proposed.` is how most runs end, and a site that
has not changed since the last run is expected whenever nobody has merged the proposal.**

---

## Contents

- [First: read the three sources](#first-read-the-three-sources)
- [Symptom table](#symptom-table)
- [The site looks stale](#the-site-looks-stale)
- [No pull request appeared](#pr-not-appearing)
- [The proposal is sitting unmerged](#proposal-unmerged)
- [A proposal was closed unexpectedly](#stale-proposal-closed)
- [`SKIP: uncommitted local changes`](#skip-uncommitted-local-changes)
- [`FATAL: git pull failed`](#fatal-git-pull-failed)
- [`RESULT: claude exited N`](#claude-exited-non-zero)
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
| Discord | the channel the webhook posts to | One embed per run, with the commit subject and PR link on `proposed`. See [Notifications](notifications.md#discord). |
| The pull request | `gh pr list --head sync/drive --state all --limit 5` | Whether a proposal is open, was merged, or was closed. |
| Git | `git log --oneline -5 && git status --short` | Whether the merge landed on `main`, and whether the tree is clean. |

To see one run in isolation, search backwards for the `═` divider:

```bash
grep -n '^Sync started' ~/Library/Logs/mnfc-website-sync.log | tail -5
```

!!! tip "`no changes proposed` is the healthy steady state"
    Publishing rule 7 says a sync that finds no Drive changes makes no commit. A log full of
    `RESULT: no changes proposed.` and a status file reading `OK ... no changes` means the
    site matches Drive. Nothing needs doing. Do not "fix" it by forcing a commit.

!!! warning "`OK  proposed <sha> (awaiting review)` is not a fault, and not a finished job"
    The run succeeded; the *publishing* did not happen, because publishing is a human merge.
    A status file that still reads `proposed … (awaiting review)` days later means the pull
    request is still open and unmerged. Go to
    [Reviewing a Proposed Update](reviewing-changes.md) rather than debugging the sync.

---

## Symptom table

| Symptom | Likely cause | Go to |
| --- | --- | --- |
| Site missing a Drive change from days ago | Any of the below — start with `install-schedule.sh status` | [The site looks stale](#the-site-looks-stale) |
| Discord posted `📋 Update proposed` but no PR exists | `gh` not authenticated, or the branch push failed | [No pull request appeared](#pr-not-appearing) |
| Log shows `ERROR: could not push sync/drive.` | The branch never reached GitHub; nothing is awaiting review | [No pull request appeared](#pr-not-appearing) |
| A pull request has been open for days and the site is unchanged | Nobody merged it — merging is what publishes | [The proposal is sitting unmerged](#proposal-unmerged) |
| A proposal you were reading was closed, or its diff changed | A later run superseded it | [A proposal was closed unexpectedly](#stale-proposal-closed) |
| Log shows `WARNING: could not close <url>` | `gh pr close` failed; a stale PR is still open and looks mergeable | [A proposal was closed unexpectedly](#stale-proposal-closed) |
| Log shows `SKIP: uncommitted local changes present` | Someone left edits in the working tree | [SKIP](#skip-uncommitted-local-changes) |
| Log shows `WARNING: agent left uncommitted changes on sync/drive` | The agent edited without committing; the edits were discarded | usually alongside [claude exited non-zero](#claude-exited-non-zero) |
| Log shows `FATAL: git pull failed` | Local `main` and `origin/main` diverged | [Diverged history](#fatal-git-pull-failed) |
| Log shows `FATAL: could not check out main` | The checkout is conflicted or otherwise unusable | inspect the repo by hand |
| Log shows `FATAL: repo not found` | The repo moved, or this is not the right machine | [Single point of failure](schedule.md#single-point-of-failure) |
| Log shows `RESULT: claude exited N` | Agent error — auth, model, tool or prompt failure | [claude exited non-zero](#claude-exited-non-zero) |
| Run completes but Drive content is missing from the proposal | Drive connector not authenticated for that run | [Drive auth expired](#drive-auth-expired) |
| Notification: `No sync in N days. Was the Mac off?` | No run happened | [The Mac was off](#the-mac-was-off) |
| Notification: `No sync has ever recorded a run.` | Schedule not installed, or never yet run | run `./scripts/install-schedule.sh` |
| `status` says `NOT loaded` | Job booted out, or never installed | run `./scripts/install-schedule.sh` |
| The PR is merged but the page is unchanged | Pages build, browser cache, or a Pages settings change | [Deployment](deployment.md#when-a-push-does-not-appear) |
| No Discord messages at all | Webhook not configured, or the script is not executable | [Discord posts not arriving](#discord-posts-not-arriving) |
| Log shows `Discord: HTTP 401` or `Discord: HTTP 404` | Webhook revoked, deleted, or the URL is wrong | [Discord HTTP errors](#discord-http-401-404) |
| `RESULT: no changes proposed.` | **Nothing.** Drive matched the site. | not a failure |

---

## The site looks stale

Work outwards from the published page to the source. Each step rules out one link in the
chain described in [Anatomy of a Sync Run](sync-run.md).

**Start with the pull request.** Under the propose-then-approve flow the single most common
cause of a stale site is not a broken run — it is a correct proposal nobody merged.

```bash
cd /Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website

# 1. Is there a proposal waiting for a human?
gh pr list --head sync/drive --state all --limit 5

# 2. Is the change on main at all?
git fetch origin && git log --oneline -5 origin/main

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
| Step 1 shows an **open** PR | The sync did its job; the merge is what is missing | [The proposal is sitting unmerged](#proposal-unmerged) |
| Step 1 shows nothing, but the log says a proposal was made | The push or `gh pr create` failed | [No pull request appeared](#pr-not-appearing) |
| Step 2 shows the change on `main` | The repo is current — the problem is downstream | [Deployment](deployment.md#when-a-push-does-not-appear) |
| Step 3 prints anything | Every run is skipping | [SKIP](#skip-uncommitted-local-changes) |
| Step 4 reads `FAIL` | Read the detail field and jump to that section | this page |
| Step 4 reads `proposed <sha> (awaiting review)` | A proposal is waiting | [The proposal is sitting unmerged](#proposal-unmerged) |
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

## No pull request appeared { #pr-not-appearing }

**Cause.** The run says it proposed something, but there is no pull request to review. Two
distinct failures produce this, and the log distinguishes them in one line.

```bash
grep -n 'RESULT: proposed\|Opened PR\|Updated existing PR\|could not push' \
  ~/Library/Logs/mnfc-website-sync.log | tail -10
gh auth status
gh pr list --head sync/drive --state all --limit 5
```

| Log line | What happened | Fix |
| --- | --- | --- |
| `ERROR: could not push sync/drive.` | `git push --force-with-lease` failed. The branch never reached GitHub, so no PR could exist. | Test SSH access, then rerun the sync |
| `Opened PR: ` followed by something that is not a URL | The push worked; `gh pr create` failed and its error text was captured instead of a URL | `gh auth status`, then open the PR by hand |

**The push failure.** The commit is on the local `sync/drive` branch only. There is nothing to
salvage — the next run resets that branch and re-derives the same change from Drive — so fix
the access and let the schedule catch up, or rerun by hand:

```bash
env -i /usr/bin/git -C /Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website \
  push --dry-run origin sync/drive
ssh -T git@github.com
./scripts/sync-from-drive.sh
```

`env -i` is the point of that first command: it strips the environment down to roughly what
`launchd` gives the job, so an SSH agent that only exists in your interactive shell cannot
make the test pass for a run that would fail.

!!! danger "`gh` is a hard dependency and nothing checks it"
    `GH="/opt/homebrew/bin/gh"` is an absolute path, and the script never verifies that the
    binary exists or that it is authenticated. If `gh` is missing, logged out, or its token
    has lost `repo` scope, `open_pr_url` prints nothing — which the script reads as *no PR is
    open* — and `gh pr create` fails, with `2>&1 | tail -1` capturing its error message into
    `PR_URL`. The run then records `OK  proposed <sha> (awaiting review)`, notifies, and posts
    an amber `proposed` embed whose "Review and merge to publish:" line contains an error
    string instead of a link. **Every channel reports a successful proposal and there is
    nothing to review.** The same broken `open_pr_url` also stops quiet runs from closing
    stale proposals. Re-authenticate with `gh auth login`, then rerun the sync.

Once `gh` works, the branch is already on GitHub, so the pull request can be opened by hand:

```bash
gh pr create --base main --head sync/drive
```

---

## The proposal is sitting unmerged { #proposal-unmerged }

**This is not a fault.** The sync proposes; a human merges; merging is what publishes. A pull
request that has been open for a week means exactly that nobody has merged it, and every
channel will keep reporting healthy runs while it sits there — the run recorded `OK`, so the
watchdog is satisfied too.

```bash
gh pr list --head sync/drive --state open
gh pr diff sync/drive
```

Review it against the checks in
[Reviewing a Proposed Update](reviewing-changes.md#what-to-check-in-the-diff), then merge:

```bash
gh pr merge sync/drive
```

GitHub Pages rebuilds from `main` in about a minute.

!!! warning "Waiting is not free — the proposal expires on its own"
    Nothing keeps a proposal alive. The next run either force-pushes a newer diff over it, or,
    if Drive has come back into agreement with the site, closes it with a `Superseded:`
    comment. There is no state in which an unreviewed proposal survives indefinitely, and no
    channel re-pings about one. Review in the days after the amber Discord post, not weeks
    later.

If the intent is to reject the change rather than delay it, closing the PR does not stop it
coming back — the next run re-derives the same proposal from Drive and opens a new pull
request. Fix the Drive document, or change the rule; see
[Closing it instead](reviewing-changes.md#closing-it-instead).

---

## A proposal was closed unexpectedly { #stale-proposal-closed }

**Cause.** A run found no differences between Drive and the published site, so it closed the
open pull request with the comment `Superseded: the site now matches Drive, so there is
nothing left to publish.`

```bash
grep -n 'Closing stale proposal\|Closed\.\|could not close' \
  ~/Library/Logs/mnfc-website-sync.log | tail -10
gh pr list --head sync/drive --state closed --limit 5
```

Reaching that branch means the agent read Drive and read `main` and found them in agreement,
so the open proposal was a diff against a state that no longer exists. **Merging it would have
republished content the agent had since judged unnecessary** — a green Merge button that does
something other than what the reviewer thinks it does. Closing is the correct outcome, not a
bug.

Two versions of this are worth telling apart:

| What you see | Meaning |
| --- | --- |
| The PR closed and the site already shows the change | Someone merged an earlier proposal, or made the same edit on `main`. Nothing was lost. |
| The PR closed and the site does **not** show the change | The agent found nothing to propose — which is either genuinely correct, or the silent Drive-auth failure below |

The second row is the one to check, because a run that cannot read Drive finds no differences
for exactly the wrong reason and then closes a perfectly good proposal on the strength of it.
Confirm the agent actually enumerated the `Build the Fab` subfolders in that run's output
before accepting the closure — see [Drive auth expired](#drive-auth-expired).

Nothing is destroyed by a closure: reopen it in GitHub if the diff was right, or run
`./scripts/sync-from-drive.sh` and read the fresh proposal.

!!! warning "`WARNING: could not close <url>` leaves a misleading Merge button live"
    The close is best-effort — a failure logs one line and the run continues, reporting `OK`.
    The stale pull request stays open, green and mergeable, and its Discord post is still
    sitting in the channel telling someone to review and merge it. Close it by hand:
    `gh pr close sync/drive --comment "Superseded"`. Then check `gh auth status`, because a
    `gh` that cannot close is usually a `gh` that cannot create either.

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
at least one remote commit that is not local. The sync itself never commits to `main`, so a
local-only commit here was made by a human — the usual origin is a hand commit on `main` that
was never pushed, followed by someone pushing from elsewhere: a pull request merged in the
GitHub web UI, a direct web edit, or a run from another clone.

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
current state of the site, and a later successful run can propose `<<<<<<<` into the published
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

A crashed agent proposes nothing: any edits it made without committing are discarded with
`git reset --hard` — logged as `WARNING: agent left uncommitted changes on sync/drive;
discarding them.` — and an open pull request from an earlier run is left exactly as it was.
Nothing needs cleaning up by hand.

**Diagnose.** The agent's own output sits in the log immediately above the `RESULT:` line —
that is where the actual error message is. It is not forwarded to Discord, deliberately: it
routinely quotes Drive documents holding BOM costs and vendor pricing, and the channel is a
published surface.

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

## Drive auth expired { #drive-auth-expired }

**Cause.** The Google Drive connector session used by the four
`mcp__claude_ai_Google_Drive__*` tools is no longer valid.

**This is the least visible failure mode in the system.** The script has no auth check — auth
is delegated entirely to the agent. Depending on how the connector fails, the run either exits
non-zero (landing in [`claude exited N`](#claude-exited-non-zero)) *or* completes normally
having read nothing, finds no differences it can act on, and logs
`RESULT: no changes proposed.` with an `OK` record. The second case is indistinguishable from
a healthy quiet run from the log alone, and the watchdog will not complain because a run did
happen and recorded `OK`. Discord is no help either: that run posts the same grey
`✓ Site checked` embed a genuinely quiet run posts.

!!! danger "A blind run also closes the open proposal"
    The no-differences branch is the branch that closes a stale pull request. An agent that
    read nothing from Drive reaches it too — so a connector expiry does not merely fail to
    propose anything, it can **close a correct proposal nobody had reviewed yet**, with the
    comment `Superseded: the site now matches Drive`. Nothing about the log line, the status
    file or the grey embed distinguishes that from a genuine agreement between Drive and the
    site. If a proposal disappears in a run you were not expecting to be quiet, check the
    Drive reads before believing the closure.

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
it reads Drive's current state and proposes the HTML that matches it. Nothing queues, nothing
is lost, and the next run proposes every change made during the missed slot in one pull
request.

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

!!! note "The watchdog reports on both channels"
    `check-sync-ran.sh` raises a macOS banner *and* posts a `fail` embed for each of its three
    alerts. Putting the "the job never ran" alert only on the machine whose being off is the
    likeliest cause would be self-defeating. See
    [Notifications](notifications.md#what-fires-on-each-outcome).

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
| **No lock against overlapping runs** | Nothing stops a manual `./scripts/sync-from-drive.sh` from starting while the scheduled run is mid-flight. Two agents would edit the same working tree, and both would reset and force-push the same `sync/drive` branch. The watchdog checks whether the sync is running before it reports; the sync makes no such check about itself. Look at the log before starting a manual run. |
| **Nothing chases an unmerged proposal** | Announced once, then either superseded or closed. No reminder, no timeout, no escalation — see [The proposal is sitting unmerged](#proposal-unmerged). |
| **No push retry** | `ERROR: could not push sync/drive.` and abandonment. The next scheduled run re-proposes from scratch. |
| **No check that `gh` exists or is authenticated** | A broken `gh` produces a `proposed` embed with an error string where the PR link should be — see [No pull request appeared](#pr-not-appearing). |
| **No check that `claude` exists** | A missing or moved binary surfaces only as `RESULT: claude exited N`. |
| **No Drive auth check** | Delegated to the agent; can present as a silent `no changes` run that also closes an open proposal. |
| **Notifications are fire-and-forget** | `notify` ends in a `\|\| true` fallback. An alert raised during Do Not Disturb, or on a locked machine, is simply gone. `STATUS_FILE` is the durable record. |
| **Discord failures are not retried** | `discord()` ends in `\|\| true`. A `Discord: HTTP <code>` line in the log is the only trace, and the run still reports success. |
| **One machine only** | Every path is absolute under `/Users/leonardjin`. See [Single point of failure](schedule.md#single-point-of-failure). |
| **Pages settings are outside the repo** | Nothing in version control describes the GitHub Pages configuration. See [Deployment](deployment.md#what-is-not-in-the-repo). |

---

[← Reviewing a Proposed Update](reviewing-changes.md){ .md-button } [Deployment →](deployment.md){ .md-button .md-button--primary }
