# Anatomy of a Sync Run

What `scripts/sync-from-drive.sh` does, step by step, from the log header to the final
timestamp. This page covers a single execution of the script — the schedule that triggers it
is in [The Schedule](schedule.md), how the run reports itself is in
[Notifications](notifications.md), and what to do when a run goes wrong is in
[Troubleshooting](troubleshooting.md). **Every step is a guard: the script decides at each
point whether it is safe to continue, and a run that stops early usually stopped on purpose.**

---

## Contents

- [Preamble and logging](#preamble-and-logging)
- [The reporting channels: `notify`, `record` and `discord`](#the-two-side-channels)
- [Step 1 — locate the repo](#step-1-locate-the-repo)
- [Step 2 — the dirty-tree guard](#step-2-the-dirty-tree-guard)
- [Step 3 — fast-forward pull](#step-3-fast-forward-pull)
- [Step 4 — the headless agent](#step-4-the-headless-agent)
- [Step 5 — the result branch](#step-5-the-result-branch)
- [Step 6 — the push verification](#step-6-the-push-verification)
- [Log marker reference](#log-marker-reference)
- [What the script does not handle](#what-the-script-does-not-handle)

---

## Preamble and logging

The script opens with `set -uo pipefail` — note the deliberate absence of `-e`. It does its
own checks and chooses its own exit codes at every branch; `-e` would abort the run on the
first non-zero status and lose the log line that explains why. `-u` still catches unset
variables and `pipefail` still surfaces failures inside pipelines.

Five constants and one temporary file define the entire environment:

| Constant | Value |
| --- | --- |
| `REPO` | `/Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website` |
| `CLAUDE` | `/Users/leonardjin/.local/bin/claude` |
| `LOG` | `$HOME/Library/Logs/mnfc-website-sync.log` |
| `STATUS_FILE` | `$HOME/Library/Logs/mnfc-website-sync.status` |
| `DISCORD` | `$REPO/scripts/notify-discord.sh` |
| `AGENT_OUT` | `$(mktemp -t mnfc-sync)` — holds a copy of the agent's narration |

`AGENT_OUT` is removed by `trap 'rm -f "$AGENT_OUT"' EXIT`, which covers the early-exit guard
paths as well as a normal finish, so no run leaves a temp file behind.

`exec >>"$LOG" 2>&1` redirects both stdout and stderr of the whole script — and of every
process it spawns — into the log, appending. Everything after that line is invisible on a
terminal even when run by hand; to watch a manual run, tail the log in a second window.

The header is a `═` divider plus `Sync started: <date>` with a `%Y-%m-%d %H:%M:%S %Z`
timestamp. The divider is what makes a single run findable in an append-only file that has
no rotation.

```bash
tail -f ~/Library/Logs/mnfc-website-sync.log
```

!!! note "All `git` calls are absolute"
    The script calls `/usr/bin/git`, never bare `git`. `launchd` runs jobs under a minimal
    environment with a minimal `PATH` — a bare `git` would resolve differently under
    `launchd` than in an interactive shell, or not at all. The same reasoning gives `CLAUDE`
    an absolute path.

---

## The reporting channels { #the-two-side-channels }

The log is append-only, unrotated, and nobody opens it after a run that went fine. Three helper
functions defined before the run give the script a way to reach a human at the machine, a way
to leave a machine-readable trace, and a way to reach a human who is somewhere else. All three
are covered end to end in [Notifications](notifications.md).

### `notify` — reach a human on failure

```bash
notify() {
  local msg="${1//\"/}"
  /usr/bin/osascript -e "display notification \"$msg\" with title \"Website sync\"" >/dev/null 2>&1 || true
}
```

A macOS notification titled `Website sync`. `${1//\"/}` strips double quotes from the
message before it is interpolated into the AppleScript string — an unescaped `"` in a commit
hash or a path would terminate the string and turn the rest of the message into syntax. The
trailing `|| true` means a failed notification can never take down the run: the notifier is
diagnostics, not a dependency.

**Every failure path notifies; success stays silent, on purpose.** The job fires twice a week
and most runs end on `no changes`, so a banner per run is a banner you learn to dismiss
without reading — and the one that says `Committed but could not push` gets dismissed the same
way. Silence on success is what keeps the notification meaningful when it does appear. Discord
carries the successful runs instead; see
[why success is silent](notifications.md#why-success-is-silent).

### `record` — leave a machine-readable trace

```bash
record() {
  printf '%s\t%s\t%s\n' "$1" "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$2" > "$STATUS_FILE"
}
```

One tab-separated line — state, timestamp, detail — truncating `STATUS_FILE` each time, so the
file always holds exactly the last outcome. State is `OK` or `FAIL`. The file's own mtime is
what the watchdog uses to answer the question the log cannot:
*did a run happen at all?* See [The Schedule](schedule.md#the-watchdog).

Every branch of the script records, and every branch also posts to Discord:

| Branch | State | Detail | Notifies | Discord |
| --- | --- | --- | --- | --- |
| `cd "$REPO"` failed | `FAIL` | `repo not found` | yes | `fail` |
| Dirty tree | `FAIL` | `uncommitted local changes` | yes | `fail` |
| Non-ff pull | `FAIL` | `git pull failed` | yes | `fail` |
| Agent exited non-zero | `FAIL` | `claude exited $STATUS` | yes | `fail` |
| No commit made | `OK` | `no changes` | no | `ok` |
| Committed and pushed | `OK` | `committed $AFTER` | no | `changed` |
| Committed, pushed on retry | `OK` | `committed $AFTER (pushed on retry)` | no | `changed` |
| Committed, push failed twice | `FAIL` | `commit $AFTER not pushed` | yes | `fail` |

!!! note "The dirty-tree skip records `FAIL` but exits `0`"
    The two are answering different questions. The exit code answers *did the script
    misbehave?* — it did not, it declined on purpose. `STATUS_FILE` answers *is the site
    tracking Drive?* — it is not. Recording `FAIL` is what makes the watchdog keep complaining
    about a skip that repeats on every following run.

### `discord` — reach a human who is not at the machine

```bash
discord() {
  [ -x "$DISCORD" ] || return 0
  "$DISCORD" "$1" "$2" "${3:-}" || true
}
```

A thin wrapper around `scripts/notify-discord.sh`, called as `discord <state> <headline>
[detail]` with `state` one of `ok`, `changed` or `fail`. Two guards make it unable to fail the
run: it returns early unless the script is executable, and `|| true` swallows a non-zero exit
from the send itself. `notify-discord.sh` adds a third — an absent or empty
`~/.config/mnfc-sync/discord-webhook` prints one line and exits `0`, so an unconfigured
Discord never turns a healthy sync into a failed one.

Unlike `notify`, `discord` is called on **every** outcome including success. The two summary
helpers used by the `changed` posts pull their text from git rather than from the agent's
prose:

```bash
summary_subject() {
  /usr/bin/git log -1 --format=%s "$AFTER" 2>/dev/null || echo "Site updated"
}

summary_detail() {
  local files
  files=$(/usr/bin/git diff-tree --no-commit-id --name-only -r "$AFTER" 2>/dev/null | tr '\n' ' ')
  echo "\`${AFTER:0:7}\` · ${files:-(no files listed)}"
}
```

**The concise summary is the commit subject.** `git log -1 --format=%s` returns one line,
written by the agent that knew what it changed; `summary_detail` adds the short hash and the
changed file list. Parsing a headline out of the agent's free-prose narration instead would
depend on a format the agent never promised to keep — see
[where the concise summary comes from](notifications.md#where-the-concise-summary-comes-from).

---

## Step 1 — locate the repo

```bash
cd "$REPO" || {
  echo "FATAL: repo not found at $REPO"
  record FAIL "repo not found"
  notify "Repo not found at $REPO. Sync could not start."
  discord fail "Could not start" "Repo not found at \`$REPO\`."
  exit 1
}
```

`REPO` is an absolute path baked into the script. If the directory has moved, been renamed,
or lives on a machine that is not Leonard's Mac, the run logs `FATAL: repo not found`,
records `FAIL repo not found`, notifies, posts a `fail` embed to Discord, and exits `1`. This
is the first of several hardcoded paths — see the single-point-of-failure warning in
[The Schedule](schedule.md#single-point-of-failure).

---

## Step 2 — the dirty-tree guard

```bash
if ! /usr/bin/git diff --quiet || ! /usr/bin/git diff --cached --quiet; then
  echo "SKIP: uncommitted local changes present; not syncing over them."
  /usr/bin/git status --short
  record FAIL "uncommitted local changes"
  notify "Skipped: uncommitted changes in the repo. Commit or stash them, or every week from now on will skip too."
  discord fail "Skipped -- uncommitted local changes" "Commit or stash them, or every following run skips too."
  exit 0
fi
```

Two checks, because they cover different things: `git diff --quiet` fails when the working
tree differs from the index, and `git diff --cached --quiet` fails when the index differs
from `HEAD`. Either condition means a human is mid-edit. The guard prints `git status
--short` so the log records *what* was dirty, records `FAIL`, notifies, then exits.

**The exit code is `0`, not `1`, and that is deliberate.** The step after this one is
`git pull --ff-only`, and the step after that hands the repo to an agent with `Edit` and
`Write` permissions and instructions to commit. Running that against a dirty tree risks
committing half-finished work under an automated commit message, or losing it to a checkout.
A skip is the correct outcome, not an error — `0` says so, and keeps the run out of any
exit-code-based alerting that would otherwise page a human about a working-as-designed event.

!!! danger "A dirty tree disables every future run until a human intervenes"
    The guard has no timeout and no escalation. Any run that leaves the tree dirty — a
    manual edit left unstaged, a partially applied patch, a `.orig` file from a conflict —
    turns every subsequent run — Monday and Thursday alike — into an immediate
    `SKIP: ... exit 0`. The exit code is
    a success, the log fills with successful-looking skips, and the site stops tracking Drive
    for as long as the tree stays dirty. The notification and the `FAIL` record exist
    precisely because nothing else about this state looks like a problem. Commit or stash
    before you walk away from the repo, and read the `SKIP:` line as an outage, not a note.

Recovering is a two-line job:

```bash
cd /Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website
git status --short          # decide: keep it or drop it
git stash                   # or: git commit -am "..."
./scripts/sync-from-drive.sh
```

---

## Step 3 — fast-forward pull

```bash
/usr/bin/git pull --ff-only origin main || {
  echo "FATAL: git pull failed"
  record FAIL "git pull failed"
  notify "git pull failed -- history may have diverged from origin/main. Sync aborted."
  discord fail "git pull failed" "History may have diverged from \`origin/main\`."
  exit 1
}
```

`--ff-only` refuses to create a merge commit. If local `main` and `origin/main` have
diverged — someone pushed from another machine while a local commit sat unpushed — the pull
fails and the run stops with `FATAL: git pull failed` and exit `1`.

**Why refuse instead of merging?** A merge here would run unattended and non-interactively.
A conflict in `index.html` would leave conflict markers in a tracked file that the agent then
reads as the current state of the site, and the next successful run could commit `<<<<<<<`
into the published page. Refusing keeps the divergence in front of a human, who can inspect
both sides before either one wins. The fix is in
[Troubleshooting](troubleshooting.md#fatal-git-pull-failed).

`BEFORE=$(/usr/bin/git rev-parse HEAD)` records the commit immediately after the pull. This
is the baseline that the result branch compares against, so a commit made by the pull itself
is never mistaken for a commit made by the agent.

---

## Step 4 — the headless agent

The script invokes `"$CLAUDE" -p "<prompt>"` — headless, single-shot, no interactive session.
The prompt is the whole specification of the job and restates the rules rather than assuming
them:

- Read `CLAUDE.md` **first**, then `SYNC.md`, then `index.html`, `stepper.html` and
  `style.css`.
- Read the Drive folder `Ultra Hardcore Chip Codesign`
  (id `1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP`) and enumerate the subfolders of `Build the Fab` —
  each is a tool project that should appear in Current Projects.
- Never invent content; an empty project folder gets a bare status such as `Planned`.
- Never publish budgets, funding, vendor pricing, BOM costs, outreach notes or to-do lists.
- Publish officers and the faculty advisor by name, never the general member roster.
- On roles, `Engineering Structure` is ground truth and the Constitution is **not**.
- Preserve the existing HTML structure and CSS.
- Update the "last updated" date in the `index.html` footer **only if** something changed.
- If nothing meaningful changed, make no commit and say so. Otherwise commit with a message
  naming what changed and `git push origin main`.
- End with a one-paragraph summary.

!!! note "The prompt duplicates the repo's own rules on purpose"
    Every constraint above is already written in `CLAUDE.md` and `SYNC.md`, which the prompt
    also tells the agent to read. The duplication is cheap insurance: the rules with real
    consequences — no invented content, no member names, no budgets — are the ones that must
    survive even a run where a file read fails or the agent gets distracted mid-task. The
    full precedence table and the Drive→HTML mapping live in
    [Data contracts](../data-contracts.md) and are not restated in the prompt.

### The `--allowedTools` allowlist

```bash
--allowedTools \
"mcp__claude_ai_Google_Drive__search_files,\
mcp__claude_ai_Google_Drive__read_file_content,\
mcp__claude_ai_Google_Drive__get_file_metadata,\
mcp__claude_ai_Google_Drive__list_recent_files,\
Read,Edit,Write,Glob,Grep,Bash(git:*)" | tee "$AGENT_OUT"
```

The trailing `| tee "$AGENT_OUT"` keeps the agent's narration in the log *and* saves a copy to
the temp file, so the `fail` Discord embed can carry `tail -c 400 "$AGENT_OUT"` — the tail of
the actual error — instead of only pointing at a log on a laptop. That pipe is also why the
next step reads `${PIPESTATUS[0]}`.

| Tool | Why it is on the list |
| --- | --- |
| `mcp__claude_ai_Google_Drive__search_files` | Locate the Drive folders `SYNC.md` names |
| `mcp__claude_ai_Google_Drive__read_file_content` | Read the docs that feed each page section |
| `mcp__claude_ai_Google_Drive__get_file_metadata` | Check names, types and folder membership |
| `mcp__claude_ai_Google_Drive__list_recent_files` | Enumerate `Build the Fab` subfolders |
| `Read`, `Glob`, `Grep` | Read the repo and find the sections to edit |
| `Edit`, `Write` | Rewrite `index.html` and `stepper.html` |
| `Bash(git:*)` | `git add`, `git commit`, `git push origin main` — nothing else |

**Why the scope is this narrow.** Everything absent from the list is the point. The four
Drive tools are all read-only: `create_file`, `update_file`, `trash_file` and `share_file`
are not granted, so a confused run cannot write back into the club's Drive — and Drive is
authoritative over the repo, so a bad write there would propagate into the site on every
subsequent sync and have no clean source to be repaired from. `Bash(git:*)` is a prefix
match on `git`, so the agent gets version control and not a shell: no `curl`, no `rm -rf`, no
`ssh`, no package installs, nothing that could reach the network on its own or touch files
outside the repo. The run happens unattended at 8:13 on a Monday or Thursday morning with
nobody watching; the allowlist is what bounds the blast radius of a run that goes wrong.

!!! warning "Adding a tool here widens the unattended blast radius"
    Treat `--allowedTools` as a security boundary, not a convenience list. A tool added to
    make one debugging session easier stays granted for every unattended run afterwards.
    If a run genuinely needs a new capability, add it, and record why in `CLAUDE.md`.

---

## Step 5 — the result branch

```bash
# PIPESTATUS[0], not $? -- $? is tee's exit status, which is 0 even when the
# agent failed. Reading the wrong one reports every crash as a clean run.
STATUS=${PIPESTATUS[0]}
AFTER=$(/usr/bin/git rev-parse HEAD)
```

`STATUS` is the agent's exit code; `AFTER` is `HEAD` once it has finished. Three outcomes,
checked in this order:

| Condition | Log line | Records |
| --- | --- | --- |
| `STATUS -ne 0` | `RESULT: claude exited $STATUS` | `FAIL` + notify |
| `BEFORE = AFTER` | `RESULT: no changes committed.` | `OK no changes` |
| otherwise | `RESULT: committed $BEFORE -> $AFTER` | set by the push check below |

Comparing `BEFORE` against `AFTER` — rather than asking the agent whether it committed —
means the script's record of what happened comes from git, not from a summary. A run that
claims it changed nothing but left a commit is reported as a commit.

!!! danger "`$?` is `tee`'s status, and `tee` always exits `0`"
    **Once the agent's output is piped, `$?` stops meaning what it used to mean.** `$?` is the
    exit status of the *last* command in a pipeline — here `tee`, which returns `0` whether the
    agent exited `0`, `1` or `137`. Reading `$?` would send every failed run down the
    `BEFORE = AFTER` branch: it would log `RESULT: no changes committed.`, record
    `OK  no changes`, and post a grey `✓ Site checked` embed to Discord. Every crash would be
    reported as a clean quiet run on every channel at once, and the watchdog would agree,
    because a run did happen and did record `OK`. `${PIPESTATUS[0]}` is the first element of
    the pipeline's status array — the agent's own exit code, unchanged by the pipe.

!!! tip "`RESULT: no changes committed.` is a success"
    Publishing rule 7 is that a sync which finds no Drive changes makes no commit. Most runs
    end on this line. It is the healthy steady state, not a failure, and any alerting built
    on top of this log must treat it as normal. It still posts a quiet `ok` embed to Discord,
    which is how the channel shows the job is alive without pinging anyone.

The `claude exited N` branch logs the failure, records `FAIL`, notifies, posts a `fail` embed
carrying `tail -c 400 "$AGENT_OUT"` — **and then falls through to the final timestamp and
exits `0`.** The script does not propagate the agent's
exit code, so anything watching exit codes sees a clean run. The notification and
`STATUS_FILE` are the only signals; that gap is called out in
[Troubleshooting](troubleshooting.md#claude-exited-non-zero).

---

## Step 6 — the push verification

Only the committed branch runs this. The agent is told to push, but "told to" is not
"verified":

```bash
if [ -n "$(/usr/bin/git rev-list origin/main..HEAD 2>/dev/null)" ]; then
  echo "WARNING: commit was not pushed. Retrying push..."
  if /usr/bin/git push origin main; then
    echo "Push succeeded on retry."
    record OK "committed $AFTER (pushed on retry)"
    discord changed "$(summary_subject)" "$(summary_detail) (pushed on retry)"
  else
    echo "ERROR: push failed."
    record FAIL "commit $AFTER not pushed"
    notify "Committed but could not push. The site is NOT updated -- run: git push origin main"
    discord fail "Committed but could not push" "The site is NOT updated. Run \`git push origin main\`."
  fi
else
  echo "Pushed to origin/main. GitHub Pages will rebuild in ~1 minute."
  record OK "committed $AFTER"
  discord changed "$(summary_subject)" "$(summary_detail)"
fi
```

`git rev-list origin/main..HEAD` lists commits reachable from `HEAD` but not from the local
`origin/main` ref. A successful push updates that ref, so the range goes empty. A non-empty
range means the commit never left the machine, and the script retries the push exactly once.

### Why `git rev-list` and not `git status -sb | head -1 | grep -q ahead`

**Ask git directly; do not parse porcelain through a pipe.** The obvious version of this
check pipes `git status -sb` into `head -1` or `grep -q`. Both readers exit as soon as they
have what they need — `head` after one line, `grep -q` on the first match — which closes the
pipe under the still-writing `git`, which takes `SIGPIPE`. Under `set -o pipefail` the
pipeline then reports the *writer's* death as the pipeline's status, and the `if` reads that
as "not ahead". The failure mode is the worst possible one for this particular check: the
script logs `Pushed to origin/main. GitHub Pages will rebuild in ~1 minute.` for a commit
that is still sitting on the laptop, the site never updates, the log says everything is fine,
and nobody looks again until someone notices stale content weeks later. Asking `rev-list`
for the range involves no pipeline, no early-exiting reader, and no text parsing, so there is
nothing for `pipefail` to misreport.

!!! warning "The same bug class bit `install-schedule.sh`"
    `install-schedule.sh status` had the identical defect — `launchctl list` piped into
    `grep -q` — and reported the job as not loaded when it was. Both were fixed in commit
    `99e3012`; the `status` subcommand now captures `launchctl list` into a `LISTING`
    variable first. When you add any check to these scripts, capture into a variable and test
    the variable. `pipefail` plus an early-exiting reader is a false-negative generator.

The retry is one attempt. A second failure logs `ERROR: push failed.`, records
`FAIL commit <sha> not pushed`, notifies, and abandons the commit locally — see
[Troubleshooting](troubleshooting.md#push-failed-after-retry).

!!! warning "An unpushed commit leaves a clean tree"
    This is the failure with the longest natural lifetime. The commit exists, so the working
    tree is clean, so nothing trips the dirty-tree guard on the next scheduled run — that run
    pulls, finds Drive already matching the local HTML, and reports
    `RESULT: no changes committed.` while the published site stays behind. Without the
    notification, the Discord `fail` embed and the `FAIL` record, an unpushed commit could sit
    unnoticed indefinitely.

The run closes with `Sync finished: <date>` — unconditionally, on every path that gets this
far.

---

## Log marker reference

| Marker | Meaning | Exit | What to do |
| --- | --- | --- | --- |
| `Sync started: <date>` | A run began. Follows a `═` divider. | — | Nothing — use it to find the run in the log. |
| `FATAL: repo not found at <path>` | `cd "$REPO"` failed. | `1` | The repo moved or this is not the right machine. Fix the path or clone the repo. |
| `SKIP: uncommitted local changes present; not syncing over them.` | Dirty-tree guard fired. Followed by `git status --short`. | `0` | Commit or stash the listed changes, then rerun by hand. Every run skips until you do. |
| `Pulling latest...` | About to `git pull --ff-only origin main`. | — | Nothing. |
| `FATAL: git pull failed` | Non-fast-forward; local and remote have diverged. | `1` | Reconcile the histories by hand. See [Troubleshooting](troubleshooting.md#fatal-git-pull-failed). |
| `RESULT: claude exited N` | The agent exited non-zero. No commit is trusted. | `0` | Read the agent's output above this line in the log. Note the script still exits `0`. |
| `RESULT: no changes committed.` | `HEAD` is unchanged. **Success.** | `0` | Nothing. Drive matched the site. |
| `RESULT: committed A -> B` | The agent committed. Push verification follows. | — | Nothing yet — read the next line. |
| `Pushed to origin/main. GitHub Pages will rebuild in ~1 minute.` | `origin/main..HEAD` is empty; the commit is on GitHub. | `0` | Nothing. See [Deployment](deployment.md). |
| `WARNING: commit was not pushed. Retrying push...` | The commit was still local. One retry follows. | — | Nothing yet — read the next line. |
| `Push succeeded on retry.` | The retry worked. Fully published. | `0` | Nothing. Worth noticing if it recurs — it points at a flaky network or a missing SSH agent. |
| `ERROR: push failed.` | Both attempts failed. The commit is local only. | `0` | Push by hand. See [Troubleshooting](troubleshooting.md#push-failed-after-retry). |
| `Sync finished: <date>` | The script reached the end. | — | Its presence says nothing about success — read the `RESULT:` line. |
| `Discord: posted (<status>).` | The embed reached the webhook. | — | Nothing. |
| `Discord: not configured (no <path>); skipping notification.` | No `~/.config/mnfc-sync/discord-webhook`. | — | Nothing, unless you wanted Discord — see [Setting up Discord](notifications.md#setting-up-discord). |
| `Discord: webhook file is empty; skipping notification.` | The config file exists but holds only whitespace. | — | Write the webhook URL into it. |
| `Discord: HTTP <code> -- <body>` | The webhook rejected the post. | — | `401`/`404` means the webhook was deleted or the URL is wrong. See [Troubleshooting](troubleshooting.md#discord-posts-not-arriving). |

Markers written by the watchdog rather than the sync — `WATCHDOG: ...` — are documented in
[The Schedule](schedule.md#the-watchdog). Both jobs append to the same log file.

---

## What the script does not handle

Stated plainly so nobody assumes a safety net that is not there:

| Condition | Behavior |
| --- | --- |
| Google Drive auth expired | Delegated to the agent. Surfaces as a non-zero exit or as a run that finds nothing to change. |
| A second push failure | Logged as `ERROR: push failed.`, recorded, notified, then abandoned. No third attempt. |
| `claude` binary missing at `CLAUDE` | Not checked. The invocation fails and lands in the `claude exited N` branch. |
| Log rotation | None. `~/Library/Logs/mnfc-website-sync.log` grows without bound. |
| Concurrent runs | No lock file. A manual run started during a scheduled run has both agents editing the same tree. |
| Non-zero exit on agent failure | Never happens. The script exits `0` after logging `RESULT: claude exited N`. |
| Notification not seen | Not tracked. `notify` ends in a `\|\| true` fallback; a `Do Not Disturb` window swallows the alert and nothing retries it. `STATUS_FILE` is the durable record. |
| A failed Discord post | Logged as `Discord: HTTP <code>` or `Discord: send failed`, then swallowed by the `\|\| true` in `discord()`. No retry. |
| Discord unconfigured | Not an error. `notify-discord.sh` prints one line and exits `0`; the run continues normally. |
| `notify-discord.sh` not executable | `discord()` returns early and posts nothing, silently. `install-schedule.sh` runs `chmod +x` on the sync and watchdog scripts only. |

Which Drive doc feeds which part of the page — and what is deliberately never published — is
in [Data contracts](../data-contracts.md). Every channel a run reports through is in
[Notifications](notifications.md). How a pushed commit becomes a live page is in
[Deployment](deployment.md).

---

[← Architecture overview](../architecture/overview.md){ .md-button } [The Schedule →](schedule.md){ .md-button .md-button--primary }
