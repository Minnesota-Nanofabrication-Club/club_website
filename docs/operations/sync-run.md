# Anatomy of a Sync Run

What `scripts/sync-from-drive.sh` does, step by step, from the log header to the final
timestamp. This page covers a single execution of the script — the schedule that triggers it
is in [The Schedule](schedule.md), how the run reports itself is in
[Notifications](notifications.md), what a reviewer does with the result is in
[Reviewing a Proposed Update](reviewing-changes.md), and what to do when a run goes wrong is
in [Troubleshooting](troubleshooting.md). **The run does not publish. It proposes: the agent
commits to `sync/drive`, the script opens a pull request, and merging that pull request is
what puts anything on the live site.**

---

## Contents

- [Preamble and logging](#preamble-and-logging)
- [The reporting channels: `notify`, `record` and `discord`](#the-two-side-channels)
- [Step 1 — locate the repo](#step-1-locate-the-repo)
- [Step 2 — the dirty-tree guard](#step-2-the-dirty-tree-guard)
- [Step 3 — fetch, check out `main`, fast-forward](#step-3-fast-forward-pull)
- [Step 4 — reset the proposal branch](#step-4-reset-the-proposal-branch)
- [Step 5 — the headless agent](#step-5-the-headless-agent)
- [Step 6 — the result branch](#step-6-the-result-branch)
- [Step 7 — push and open the pull request](#step-7-push-and-open-the-pull-request)
- [Closing a stale proposal](#closing-a-stale-proposal)
- [The `EXIT` trap](#the-exit-trap)
- [Log marker reference](#log-marker-reference)
- [What the script does not handle](#what-the-script-does-not-handle)

---

## Preamble and logging

The script opens with `set -uo pipefail` — note the deliberate absence of `-e`. It does its
own checks and chooses its own exit codes at every branch; `-e` would abort the run on the
first non-zero status and lose the log line that explains why. `-u` still catches unset
variables and `pipefail` still surfaces failures inside pipelines.

Six constants, one branch name and one temporary file define the entire environment:

| Constant | Value |
| --- | --- |
| `REPO` | `/Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website` |
| `CLAUDE` | `/Users/leonardjin/.local/bin/claude` |
| `GH` | `/opt/homebrew/bin/gh` — the GitHub CLI, used to open, find and close the pull request |
| `LOG` | `$HOME/Library/Logs/mnfc-website-sync.log` |
| `STATUS_FILE` | `$HOME/Library/Logs/mnfc-website-sync.status` |
| `DISCORD` | `$REPO/scripts/notify-discord.sh` |
| `BRANCH` | `sync/drive` — one reusable proposal branch, reset from `main` every run |
| `AGENT_OUT` | `$(mktemp -t mnfc-sync)` — holds a copy of the agent's narration |

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
    and `GH` absolute paths, and `GH` is why `/opt/homebrew/bin/gh` is a hard dependency of
    the proposal step rather than something found on `PATH`.

---

## The reporting channels { #the-two-side-channels }

The log is append-only, unrotated, and nobody opens it after a run that went fine. Three helper
functions defined before the run give the script a way to reach a human at the machine, a way
to leave a machine-readable trace, and a way to reach a human who is somewhere else. All three
are covered end to end in [Notifications](notifications.md).

### `notify` — reach a human who has something to do

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

**Every failure path notifies, and so does a successful proposal**
(`Site update proposed and awaiting your review.`). The quiet `no changes` run stays silent.
The banner marks the runs where a human has something to do — fix a failure, or review a
proposal that will otherwise never reach the site. A run that found nothing to propose asks
nothing of anyone; see
[why a quiet run is silent](notifications.md#why-success-is-silent).

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
| `git checkout main` failed | `FAIL` | `checkout main failed` | yes | `fail` |
| Non-ff pull | `FAIL` | `git pull failed` | yes | `fail` |
| `git checkout -B sync/drive` failed | `FAIL` | `branch checkout failed` | no | `fail` |
| Agent exited non-zero | `FAIL` | `claude exited $STATUS` | yes | `fail` |
| No commit made | `OK` | `no changes` | no | `ok` |
| Commit pushed, PR open | `OK` | `proposed $AFTER (awaiting review)` | yes | `proposed` |
| Branch push failed | `FAIL` | `branch push failed` | yes | `fail` |

!!! note "`OK  proposed <sha> (awaiting review)` is not `published`"
    The `OK` says the *run* did its job. It does not say the site changed — nothing reaches
    the live site until a human merges the pull request. A status file reading
    `proposed … (awaiting review)` days after the run means exactly what it says: the
    proposal is still sitting there. See
    [Reviewing a Proposed Update](reviewing-changes.md).

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
[detail]` with `state` one of `ok`, `proposed`, `changed` or `fail`. The sync itself emits
`ok`, `proposed` and `fail`; `changed` is the published-state style and no branch of the sync
sends it, because the sync no longer publishes anything. Two guards make `discord` unable to
fail the run: it returns early unless the script is executable, and `|| true` swallows a
non-zero exit from the send itself. `notify-discord.sh` adds a third — an absent or empty
`~/.config/mnfc-sync/discord-webhook` prints one line and exits `0`, so an unconfigured
Discord never turns a healthy sync into a failed one.

Unlike `notify`, `discord` is called on **every** outcome including a quiet one. The two
summary helpers used by the `proposed` post pull their text from git rather than from the
agent's prose:

```bash
summary_subject() {
  /usr/bin/git log -1 --format=%s "$AFTER" 2>/dev/null || echo "Site update"
}

changed_files() {
  /usr/bin/git diff-tree --no-commit-id --name-only -r "$AFTER" 2>/dev/null | tr '\n' ' '
}
```

**The concise summary is the commit subject**, and it is also the pull request title.
`git log -1 --format=%s` returns one line, written by the agent that knew what it changed;
`changed_files` lists what the commit touched, for the PR body and the Discord detail line.
Parsing a headline out of the agent's free-prose narration instead would depend on a format
the agent never promised to keep — see
[where the concise summary comes from](notifications.md#where-the-concise-summary-comes-from).

### `open_pr_url` — is there already a proposal open?

```bash
open_pr_url() {
  "$GH" pr list --head "$BRANCH" --state open --json url --jq '.[0].url // empty'
}
```

One question, asked twice in the script: on the proposal path, to decide between opening a
new pull request and reporting that the existing one was updated; and on the no-changes path,
to find a proposal that has gone stale. `--json url --jq '.[0].url // empty'` asks `gh` for
structured output and takes the first URL, printing nothing when the list is empty — so the
caller tests one variable for emptiness rather than parsing human-readable output.

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
  notify "Skipped: uncommitted changes in the repo. Commit or stash them, or every run from now on will skip too."
  discord fail "Skipped -- uncommitted local changes" "Commit or stash them, or every following run skips too."
  exit 0
fi
```

Two checks, because they cover different things: `git diff --quiet` fails when the working
tree differs from the index, and `git diff --cached --quiet` fails when the index differs
from `HEAD`. Either condition means a human is mid-edit. The guard prints `git status
--short` so the log records *what* was dirty, records `FAIL`, notifies, then exits.

**The exit code is `0`, not `1`, and that is deliberate.** The steps after this one check out
`main`, fast-forward it, and then reset a branch onto it with `git checkout -B` — every one of
those either loses uncommitted work or refuses to run against it. A skip is the correct
outcome, not an error — `0` says so, and keeps the run out of any exit-code-based alerting
that would otherwise page a human about a working-as-designed event.

!!! danger "A dirty tree disables every future run until a human intervenes"
    The guard has no timeout and no escalation. Any run that leaves the tree dirty — a
    manual edit left unstaged, a partially applied patch, a `.orig` file from a conflict —
    turns every subsequent run — Monday and Thursday alike — into an immediate
    `SKIP: ... exit 0`. The exit code is
    a success, the log fills with successful-looking skips, and the site stops tracking Drive
    for as long as the tree stays dirty. The notification and the `FAIL` record exist
    precisely because nothing else about this state looks like a problem. This guard is also
    why the run cleans up after itself so aggressively — see
    [the `EXIT` trap](#the-exit-trap). Commit or stash before you walk away from the repo,
    and read the `SKIP:` line as an outage, not a note.

Recovering is a two-line job:

```bash
cd /Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website
git status --short          # decide: keep it or drop it
git stash                   # or: git commit -am "..."
./scripts/sync-from-drive.sh
```

---

## Step 3 — fetch, check out `main`, fast-forward { #step-3-fast-forward-pull }

```bash
echo "Fetching and updating main..."
/usr/bin/git fetch -q origin || echo "WARNING: fetch failed; continuing with local refs."
/usr/bin/git checkout -q main || {
  echo "FATAL: could not check out main"
  record FAIL "checkout main failed"
  notify "Could not check out main. Sync aborted."
  discord fail "Could not check out main" "The repo is not in a usable state."
  exit 1
}
/usr/bin/git pull --ff-only origin main || {
  echo "FATAL: git pull failed"
  record FAIL "git pull failed"
  notify "git pull failed -- history may have diverged from origin/main. Sync aborted."
  discord fail "git pull failed" "History may have diverged from \`origin/main\`."
  exit 1
}
```

Three operations, in this order and for three different reasons.

**`git fetch -q origin` is advisory.** A failed fetch logs a warning and the run continues on
local refs — the network may be down, and a stale view of `origin` is still a usable baseline
for a proposal a human will look at before it merges. The fetch matters because the very next
things the script needs are an up-to-date `main` and an accurate answer to "is there already a
PR branch out there?".

**`git checkout -q main` is explicit rather than assumed.** The previous run should have left
the repo on `main` via its `EXIT` trap, but "should have" is not a guarantee — a killed run,
a `SIGKILL` at sleep, or a human left mid-review on `sync/drive` all leave the repo elsewhere.
Without this checkout the script would fast-forward and branch from whatever was checked out,
and a proposal built on top of a previous proposal is exactly the accumulation the reusable
branch exists to prevent.

**`git pull --ff-only` refuses to create a merge commit.** If local `main` and `origin/main`
have diverged — someone pushed from another machine while a local commit sat unpushed — the
pull fails and the run stops with `FATAL: git pull failed` and exit `1`. A merge here would
run unattended and non-interactively; a conflict in `index.html` would leave conflict markers
in a tracked file that the agent then reads as the current state of the site, and the next
proposal would carry `<<<<<<<` into a pull request whose diff looks like an ordinary sync.
Refusing keeps the divergence in front of a human. The fix is in
[Troubleshooting](troubleshooting.md#fatal-git-pull-failed).

`BEFORE=$(/usr/bin/git rev-parse HEAD)` records `main`'s commit immediately after the pull.
**`BEFORE` is "what is published now"** — the baseline the proposal is diffed against, and the
commit the branch is reset onto.

---

## Step 4 — reset the proposal branch { #step-4-reset-the-proposal-branch }

```bash
/usr/bin/git checkout -q -B "$BRANCH" || {
  echo "FATAL: could not create branch $BRANCH"
  record FAIL "branch checkout failed"
  discord fail "Could not create the proposal branch" "Branch: $BRANCH"
  exit 1
}
echo "Working on $BRANCH (reset from main at ${BEFORE:0:7})."
```

`git checkout -B` creates `sync/drive` if it does not exist and **resets it to the current
`HEAD` if it does**. Every run therefore starts from current `main` with no memory of the
previous proposal.

**Why one reusable branch, reset each run, rather than a branch per run.** The pull request
opened from this branch always shows exactly *what Drive says now* against *what is published
now*. The alternative — accumulating proposals — degrades in two ways at once. A long-lived
branch means run N+1's commit sits on top of run N's, so a reviewer opening the PR sees a diff
against `main` that mixes a change Drive made last week with one it made this morning, plus
any intermediate state the agent has since revised; deciding what is actually being asked for
means reading the commits individually. A branch per run means several open pull requests that
overlap, each mergeable, each partially superseded, and merging them in the wrong order
republishes older content over newer. Resetting collapses the whole question: there is at most
one proposal, and it is current by construction.

This branch is disposable by design. Nothing is ever kept on it that is not also either in
`main` or re-derivable from Drive on the next run — which is what makes the discard in
[Step 6](#step-6-the-result-branch) and the reset here safe.

!!! warning "Do not do your own work on `sync/drive`"
    Any commit you make on that branch is destroyed by the next scheduled run's
    `git checkout -B`, without warning and without a reflog entry anyone will look at. If you
    want to amend a proposal, branch off it under a different name, or push the fix to `main`
    through your own pull request. The branch belongs to the script.

---

## Step 5 — the headless agent { #step-5-the-headless-agent }

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
- **Do not touch anything under `docs/`** — that directory documents this repo and mirrors
  nothing in Drive.
- If nothing meaningful changed, make no commit and say so. Otherwise commit with a message
  naming what changed. **Do not push, do not merge, do not switch branches** — a human
  reviews and merges.
- End with a one-paragraph summary.

!!! warning "The agent is told to commit and stop there"
    The prompt does not merely omit the push — it forbids pushing, merging and switching
    branches explicitly. The script owns every one of those: it pushes with
    `--force-with-lease`, it never merges at all, and its `EXIT` trap is what returns the repo
    to `main`. An agent that pushed on its own would race the script's own push; an agent that
    switched branches would leave the repo somewhere the trap's `checkout main` has to undo;
    an agent that merged would publish without review, which is the entire thing this design
    removed.

!!! note "The prompt duplicates the repo's own rules on purpose"
    Every publishing constraint above is already written in `CLAUDE.md` and `SYNC.md`, which
    the prompt also tells the agent to read. The duplication is cheap insurance: the rules
    with real consequences — no invented content, no member names, no budgets — are the ones
    that must survive even a run where a file read fails or the agent gets distracted
    mid-task. The full precedence table and the Drive→HTML mapping live in
    [Data contracts](../data-contracts.md) and are not restated in the prompt.

### Why `docs/` is off limits to the agent

**`docs/` is the one tracked directory with no Drive counterpart.** Everything else the agent
touches is a rendering of a Drive document, so "make the repo match Drive" is a well-defined
instruction for it. These pages describe the machinery instead, and nothing in the club's
Drive says anything about `sync-from-drive.sh`. An agent asked to reconcile them against Drive
has no source to reconcile *from*, and rule 1 — never invent content — has no force here
because there is no folder to be empty. The failure mode is a documentation page rewritten
into plausible prose about a script it did not read, landing in a pull request whose diff a
reviewer is checking against Drive documents that never mentioned it. Excluding the directory
outright is unambiguous in a way "only change it if it is wrong" is not.

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
a temp file. That pipe is also why the next step reads `${PIPESTATUS[0]}`.

| Tool | Why it is on the list |
| --- | --- |
| `mcp__claude_ai_Google_Drive__search_files` | Locate the Drive folders `SYNC.md` names |
| `mcp__claude_ai_Google_Drive__read_file_content` | Read the docs that feed each page section |
| `mcp__claude_ai_Google_Drive__get_file_metadata` | Check names, types and folder membership |
| `mcp__claude_ai_Google_Drive__list_recent_files` | Enumerate `Build the Fab` subfolders |
| `Read`, `Glob`, `Grep` | Read the repo and find the sections to edit |
| `Edit`, `Write` | Rewrite `index.html` and `stepper.html` |
| `Bash(git:*)` | `git add` and `git commit` on `sync/drive` — nothing else |

**Why the scope is this narrow.** Everything absent from the list is the point. The four
Drive tools are all read-only: `create_file`, `update_file`, `trash_file` and `share_file`
are not granted, so a confused run cannot write back into the club's Drive — and Drive is
authoritative over the repo, so a bad write there would propagate into the site on every
subsequent sync and have no clean source to be repaired from. `Bash(git:*)` is a prefix
match on `git`, so the agent gets version control and not a shell: no `curl`, no `rm -rf`, no
`ssh`, no package installs, nothing that could reach the network on its own or touch files
outside the repo. Note that `gh` is **not** on the list — the agent cannot open, comment on or
merge a pull request even though the script it runs under does. The run happens unattended at
8:13 on a Monday or Thursday morning with nobody watching; the allowlist is what bounds the
blast radius of a run that goes wrong.

!!! warning "Adding a tool here widens the unattended blast radius"
    Treat `--allowedTools` as a security boundary, not a convenience list. A tool added to
    make one debugging session easier stays granted for every unattended run afterwards.
    If a run genuinely needs a new capability, add it, and record why in `CLAUDE.md`.

---

## Step 6 — the result branch { #step-6-the-result-branch }

```bash
# PIPESTATUS[0], not $? -- $? is tee's exit status, which is 0 even when the
# agent failed. Reading the wrong one reports every crash as a clean run.
STATUS=${PIPESTATUS[0]}

if ! /usr/bin/git diff --quiet || ! /usr/bin/git diff --cached --quiet; then
  echo "WARNING: agent left uncommitted changes on $BRANCH; discarding them."
  /usr/bin/git reset -q --hard
fi

AFTER=$(/usr/bin/git rev-parse HEAD)
```

`STATUS` is the agent's exit code. Before `AFTER` is read, the script checks the tree again
and **discards anything the agent edited but did not commit**.

**Why discarding is right here.** Those edits sit on a throwaway branch and were never pushed,
so nothing that was going to ship is lost — the next run re-derives them from Drive in a few
minutes. Keeping them, on the other hand, is not an option: a dirty tree blocks the trap's
`git checkout main`, the repo stays on `sync/drive` with modified files, and the next run's
dirty-tree guard fires and exits `0`. That state is self-perpetuating, so one crashed agent
would silently disable the sync until someone noticed the site had stopped tracking Drive.
Half-finished edits are worth less than a working schedule.

`AFTER` is `HEAD` once all of that has settled. Three outcomes, checked in this order:

| Condition | Log line | Records |
| --- | --- | --- |
| `STATUS -ne 0` | `RESULT: claude exited $STATUS` | `FAIL` + notify |
| `BEFORE = AFTER` | `RESULT: no changes proposed.` | `OK no changes` |
| otherwise | `RESULT: proposed $BEFORE -> $AFTER on sync/drive` | set by the push and PR step below |

Comparing `BEFORE` against `AFTER` — rather than asking the agent whether it committed —
means the script's record of what happened comes from git, not from a summary. A run that
claims it changed nothing but left a commit is reported as a proposal.

!!! danger "`$?` is `tee`'s status, and `tee` always exits `0`"
    **Once the agent's output is piped, `$?` stops meaning what it used to mean.** `$?` is the
    exit status of the *last* command in a pipeline — here `tee`, which returns `0` whether the
    agent exited `0`, `1` or `137`. Reading `$?` would send every failed run down the
    `BEFORE = AFTER` branch: it would log `RESULT: no changes proposed.`, record
    `OK  no changes`, post a grey `✓ Site checked` embed to Discord — and, worse under this
    design, **close the open pull request as stale**, throwing away a proposal nobody had
    reviewed. `${PIPESTATUS[0]}` is the first element of the pipeline's status array — the
    agent's own exit code, unchanged by the pipe.

!!! tip "`RESULT: no changes proposed.` is a success"
    Publishing rule 7 is that a sync which finds no Drive changes makes no commit. Most runs
    end on this line. It is the healthy steady state, not a failure, and any alerting built
    on top of this log must treat it as normal. It still posts a quiet `ok` embed to Discord,
    which is how the channel shows the job is alive.

The `claude exited N` branch logs the failure, records `FAIL`, notifies, posts a `fail` embed
— **and then falls through to the final timestamp and exits `0`.** The script does not
propagate the agent's exit code, so anything watching exit codes sees a clean run. The
notification and `STATUS_FILE` are the only signals; that gap is called out in
[Troubleshooting](troubleshooting.md#claude-exited-non-zero).

!!! warning "The `fail` embed deliberately carries no agent output"
    The last few hundred characters of the agent's narration routinely quote whatever it was
    reading from Drive, and the folders it reads hold BOM costs, vendor pricing and
    sponsorship correspondence — the exact material rule 5 says never leaves Drive. Discord is
    a published surface: members join the channel and messages get screenshotted. The embed
    says `Nothing was proposed. Details in the run log.` and the diagnostic detail stays in
    `~/Library/Logs/mnfc-website-sync.log`, on the machine that produced it.

---

## Step 7 — push and open the pull request { #step-7-push-and-open-the-pull-request }

Only the proposal branch runs this.

```bash
SUBJECT=$(summary_subject)
FILES=$(changed_files)
echo "RESULT: proposed $BEFORE -> $AFTER on $BRANCH"
echo "Subject: $SUBJECT"

if /usr/bin/git push -q --force-with-lease origin "$BRANCH"; then
  PR_URL=$(open_pr_url)
  if [ -z "$PR_URL" ]; then
    PR_URL=$("$GH" pr create --base main --head "$BRANCH" --title "$SUBJECT" --body "$PR_BODY" 2>&1 | tail -1)
    echo "Opened PR: $PR_URL"
  else
    echo "Updated existing PR: $PR_URL"
  fi
  record OK "proposed $AFTER (awaiting review)"
  notify "Site update proposed and awaiting your review."
  discord proposed "$SUBJECT" "Review and merge to publish: $PR_URL
Commit ${AFTER:0:7} - ${FILES:-(no files listed)}"
else
  echo "ERROR: could not push $BRANCH."
  record FAIL "branch push failed"
  notify "Could not push the proposal branch. Nothing is awaiting review."
  discord fail "Could not push the proposal branch" "Nothing is awaiting review. See the run log."
fi
```

**`--force-with-lease`, not `--force`.** The branch was reset locally, so the push is not a
fast-forward and a plain `git push` would be rejected. `--force-with-lease` overwrites the
remote branch only if it still points where the local repo last saw it point; if something
else has moved `origin/sync/drive` in the meantime — a second machine, a human pushing a
correction onto the proposal — the push is refused rather than silently discarding that work.
Plain `--force` would overwrite it without asking, which on a branch whose whole purpose is
to be reviewed means destroying the reviewer's own commits.

Then exactly one of two things happens, decided by `open_pr_url`:

| `open_pr_url` | Action | Log line |
| --- | --- | --- |
| empty | `gh pr create --base main --head sync/drive` with the commit subject as the title | `Opened PR: <url>` |
| a URL | nothing — the force-push already updated the open PR's diff | `Updated existing PR: <url>` |

A pull request tracks its head branch, so pushing to `sync/drive` updates the open PR in
place; there is nothing to create and nothing to reopen. The PR body is written by the script,
not the agent: it names the changed files, states that **merging publishes to the live site**,
notes that closing discards the proposal and that the next scheduled run re-proposes it if
Drive still disagrees, and explains that the branch is reset every run so the PR always
reflects current Drive.

Both paths record `OK  proposed <sha> (awaiting review)`, raise a macOS notification, and post
the amber `proposed` embed carrying the PR URL, the short hash and the file list.

!!! danger "Nothing has been published at this point"
    The run ends with the site exactly as it was. `RESULT: proposed …`, `Opened PR: …` and a
    `📋 Update proposed — review` ping all describe work that is **waiting**, and it waits
    indefinitely — nothing merges the pull request on a timer, and the next run will simply
    force-push over it with a newer proposal. A proposal nobody opens is a site that never
    changes, and every channel this run wrote to reports success. Reviewing is the step that
    publishes: see [Reviewing a Proposed Update](reviewing-changes.md).

If the push fails, no pull request is created or updated, the run records
`FAIL  branch push failed`, notifies, and posts a `fail` embed. The commit still exists on the
local `sync/drive` branch, but the next run resets that branch, so there is nothing to
recover by hand and nothing to clean up — fix the push and let the schedule re-propose. See
[Troubleshooting](troubleshooting.md#pr-not-appearing).

The run closes with `Sync finished: <date>` — unconditionally, on every path that gets this
far.

---

## Closing a stale proposal { #closing-a-stale-proposal }

The `BEFORE = AFTER` branch does one thing beyond recording a quiet run:

```bash
STALE=$(open_pr_url)
if [ -n "$STALE" ]; then
  echo "Closing stale proposal: $STALE"
  "$GH" pr close "$BRANCH" --comment "Superseded: the site now matches Drive, so there is nothing left to publish." >/dev/null 2>&1 \
    && echo "Closed." || echo "WARNING: could not close $STALE"
  discord ok "No changes -- the site already matches Drive." "Closed a stale proposal that is no longer needed."
else
  discord ok "No changes -- the site already matches Drive."
fi
```

**A run that proposes nothing closes any pull request still open from an earlier run.**

**What breaks otherwise.** Reaching this branch means the agent compared current Drive against
current `main` and found them already in agreement — there is nothing left to publish. An
older proposal is a diff against a `main` that has since moved, or a change the agent has
since judged unnecessary, and GitHub will still render it as a green mergeable pull request
with a Merge button. A reviewer opening it a week later has no way to tell from the UI that
approving it republishes superseded content; the button says "merge", the checks pass, and the
result is a site that disagrees with Drive in a way the next sync then has to undo. Approval
UI that lies about what approving does is worse than no proposal at all, so the run closes it
and says why in a comment.

A failure to close is soft: `WARNING: could not close <url>` in the log, and the run continues.
The Discord post says a stale proposal was closed only on the branch where one was found.

!!! warning "Do not leave a proposal open expecting to get back to it"
    There is no state in which an unreviewed proposal survives a quiet run. If a run finds no
    differences, your open PR is closed with a `Superseded:` comment; if a run finds
    differences, your open PR's diff is force-pushed over with the new proposal. Either way,
    what you were reading is gone. Review proposals in the days after the ping, not weeks
    later.

---

## The `EXIT` trap { #the-exit-trap }

```bash
cleanup() {
  rm -f "$AGENT_OUT"
  /usr/bin/git -C "$REPO" checkout -q main 2>/dev/null || true
}
trap cleanup EXIT
```

Two jobs, one invariant. `rm -f "$AGENT_OUT"` removes the temp copy of the agent's narration —
the log already holds it, so the file is redundant the moment the run ends. `git checkout -q
main` returns the repo to `main` from whatever branch the run left it on.

**The invariant is that the next run must find a clean tree on `main`.** The trap fires on
every exit path, including the early `exit 1` guards and a `FATAL` that never reached the
branch step, so there is no path that leaves the repo parked on `sync/drive`. Combined with
the `git reset --hard` in [Step 6](#step-6-the-result-branch), which clears the tree before
the checkout can be blocked by it, every run ends in the same state the next one expects.

**What breaks otherwise.** A run that exits on `sync/drive` leaves the repo checked out on a
branch that the *next* run resets with `git checkout -B` — so a human who opens the repo in
between is looking at a proposal, not the published site, and any work they start there is
destroyed on Monday. Worse, if the tree is also dirty, the dirty-tree guard fires on the next
run and exits `0`: the schedule keeps firing, the log fills with clean-looking skips, Discord
posts a `fail` embed once and then goes quiet as far as anyone is watching, and the site stops
tracking Drive until somebody investigates. Two lines of cleanup remove an entire class of
self-perpetuating outage.

`|| true` on the checkout keeps the trap from failing during a failure — if the repo is in a
state where even `checkout main` cannot run, the run's own exit code and log lines are the
signal, and a noisy trap would bury them.

---

## Log marker reference

| Marker | Meaning | Exit | What to do |
| --- | --- | --- | --- |
| `Sync started: <date>` | A run began. Follows a `═` divider. | — | Nothing — use it to find the run in the log. |
| `FATAL: repo not found at <path>` | `cd "$REPO"` failed. | `1` | The repo moved or this is not the right machine. Fix the path or clone the repo. |
| `SKIP: uncommitted local changes present; not syncing over them.` | Dirty-tree guard fired. Followed by `git status --short`. | `0` | Commit or stash the listed changes, then rerun by hand. Every run skips until you do. |
| `Fetching and updating main...` | About to `git fetch`, `git checkout main` and `git pull --ff-only`. | — | Nothing. |
| `WARNING: fetch failed; continuing with local refs.` | `git fetch origin` failed. Advisory only. | — | Nothing unless it repeats — then check the network and SSH access. |
| `FATAL: could not check out main` | `git checkout main` failed; the repo is not in a usable state. | `1` | Inspect by hand: a conflicted or corrupt checkout. |
| `FATAL: git pull failed` | Non-fast-forward; local and remote have diverged. | `1` | Reconcile the histories by hand. See [Troubleshooting](troubleshooting.md#fatal-git-pull-failed). |
| `Working on sync/drive (reset from main at <sha>).` | The proposal branch was reset onto current `main`. | — | Nothing. `<sha>` is what the proposal is diffed against. |
| `FATAL: could not create branch sync/drive` | `git checkout -B` failed. | `1` | Inspect the repo by hand. |
| `RESULT: claude exited N` | The agent exited non-zero. Nothing was proposed. | `0` | Read the agent's output above this line in the log. Note the script still exits `0`. |
| `WARNING: agent left uncommitted changes on sync/drive; discarding them.` | The agent edited without committing; the tree was reset. | — | Nothing. Expect a `claude exited N` line nearby — that is the real fault. |
| `RESULT: no changes proposed.` | `HEAD` is unchanged. **Success.** | `0` | Nothing. Drive matched the site. |
| `Closing stale proposal: <url>` | A quiet run found an open PR from an earlier run. | — | Nothing — the proposal was superseded. |
| `Closed.` | `gh pr close` succeeded. | — | Nothing. |
| `WARNING: could not close <url>` | `gh pr close` failed. The stale PR is still open. | `0` | Close it by hand: `gh pr close sync/drive`. See [Troubleshooting](troubleshooting.md#stale-proposal-closed). |
| `RESULT: proposed A -> B on sync/drive` | The agent committed. Push and PR handling follow. | — | Nothing yet — read the next lines. |
| `Subject: <text>` | The commit subject, which becomes the PR title and the Discord headline. | — | Nothing. |
| `Opened PR: <url>` | A new pull request was created against `main`. | `0` | **Review and merge it** — nothing is published until you do. See [Reviewing a Proposed Update](reviewing-changes.md). |
| `Updated existing PR: <url>` | A PR was already open; the force-push replaced its diff. | `0` | Same — review the *current* diff, not one you read earlier. |
| `ERROR: could not push sync/drive.` | The push failed. No PR was created or updated. | `0` | Nothing is awaiting review. See [Troubleshooting](troubleshooting.md#pr-not-appearing). |
| `Sync finished: <date>` | The script reached the end. | — | Its presence says nothing about success — read the `RESULT:` line. |
| `Discord: posted (<status>).` | The embed reached the webhook. | — | Nothing. |
| `Discord: not configured (no <path>); skipping notification.` | No `~/.config/mnfc-sync/discord-webhook`. | — | Nothing, unless you wanted Discord — see [Setting up Discord](notifications.md#setting-up-discord). |
| `Discord: webhook file is empty; skipping notification.` | The config file exists but holds only whitespace. | — | Write the webhook URL into it. |
| `Discord: HTTP <code> -- <body>` | The webhook rejected the post. | — | `401`/`404` means the webhook was deleted or the URL is wrong. See [Troubleshooting](troubleshooting.md#discord-posts-not-arriving). |

Markers written by the watchdog rather than the sync — `WATCHDOG: ...` — are documented in
[The Schedule](schedule.md#the-watchdog). Both jobs append to the same log file.

!!! note "Markers that no longer exist"
    `RESULT: committed A -> B`, `Pushed to origin/main. GitHub Pages will rebuild in ~1
    minute.`, `WARNING: commit was not pushed. Retrying push...`, `Push succeeded on retry.`
    and `ERROR: push failed.` were written by the version of the script that published
    directly to `main`. Nothing emits them now. A log line matching any of them predates the
    switch to pull requests, and anything still grepping for them is looking for a run that
    cannot happen.

---

## Capture into a variable, do not parse porcelain through a pipe { #capture-into-a-variable }

Both places the script asks a question about state — `open_pr_url` and the dirty-tree
checks — capture into a variable or test a command's own exit status. Neither pipes
human-readable output into `head` or `grep -q`.

**What breaks otherwise.** Both of those readers exit as soon as they have what they need —
`head` after one line, `grep -q` on the first match — which closes the pipe under the
still-writing producer, which takes `SIGPIPE`. Under `set -o pipefail` the pipeline then
reports the *writer's* death as the pipeline's status, and the `if` reads that as a negative
result. Applied to `open_pr_url`, that means a run that cannot see an open pull request opens
a second one, or a quiet run fails to close a stale proposal and leaves the misleading Merge
button in place.

!!! warning "The same bug class bit `install-schedule.sh` and the old push check"
    `install-schedule.sh status` had the identical defect — `launchctl list` piped into
    `grep -q` — and reported the job as not loaded when it was; the old push verification had
    it too, in the form of `git status -sb | head -1`. Both were fixed in commit `99e3012`.
    When you add any check to these scripts, capture into a variable and test the variable.
    `pipefail` plus an early-exiting reader is a false-negative generator.

---

## What the script does not handle

Stated plainly so nobody assumes a safety net that is not there:

| Condition | Behavior |
| --- | --- |
| Nobody reviews the proposal | Nothing. No reminder, no timeout, no escalation. The next run force-pushes over it or closes it. |
| `gh` missing or not authenticated | Not checked. `open_pr_url` prints nothing, `gh pr create` fails, and the URL in the log and the Discord post is whatever `gh` wrote to stderr. See [Troubleshooting](troubleshooting.md#pr-not-appearing). |
| A failed `git push` of the branch | Logged, recorded, notified. No retry. The next scheduled run re-proposes from scratch. |
| A failed `gh pr close` | Logged as `WARNING: could not close <url>`; the run continues and the stale PR stays open. |
| Merge conflicts on the pull request | Cannot normally arise — the branch is reset from current `main` every run — but nothing checks. A PR left open while `main` moves is force-pushed onto the new `main` by the next run. |
| Google Drive auth expired | Delegated to the agent. Surfaces as a non-zero exit or as a run that finds nothing to propose. |
| `claude` binary missing at `CLAUDE` | Not checked. The invocation fails and lands in the `claude exited N` branch. |
| Log rotation | None. `~/Library/Logs/mnfc-website-sync.log` grows without bound. |
| Concurrent runs | No lock file. A manual run started during a scheduled run has both agents editing the same tree, and both resetting the same branch. |
| Non-zero exit on agent failure | Never happens. The script exits `0` after logging `RESULT: claude exited N`. |
| Notification not seen | Not tracked. `notify` ends in a `\|\| true` fallback; a `Do Not Disturb` window swallows the alert and nothing retries it. `STATUS_FILE` is the durable record. |
| A failed Discord post | Logged as `Discord: HTTP <code>` or `Discord: send failed`, then swallowed by the `\|\| true` in `discord()`. No retry. |
| Discord unconfigured | Not an error. `notify-discord.sh` prints one line and exits `0`; the run continues normally. |
| `notify-discord.sh` not executable | `discord()` returns early and posts nothing, silently. `install-schedule.sh` runs `chmod +x` on the sync and watchdog scripts only. |

Which Drive doc feeds which part of the page — and what is deliberately never published — is
in [Data contracts](../data-contracts.md). Every channel a run reports through is in
[Notifications](notifications.md). What to do with the pull request a run leaves behind is in
[Reviewing a Proposed Update](reviewing-changes.md). How a merge becomes a live page is in
[Deployment](deployment.md).

---

[← Architecture overview](../architecture/overview.md){ .md-button } [The Schedule →](schedule.md){ .md-button .md-button--primary }
