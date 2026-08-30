#!/bin/bash
# Twice-weekly Google Drive -> website sync (Mon + Thu), run locally by launchd.
#
# This job does NOT publish. It *proposes*: the agent's changes land on the
# branch named below and open a pull request, Discord posts the link, and a
# human merges to publish. Merging into main is what triggers the Pages rebuild.
#
# Runs on Leonard's Mac rather than in Anthropic's cloud, because cloud routines
# cannot push to GitHub without a Team/Enterprise plan. Locally, git already has
# push access via SSH, so the whole loop works.
#
# Install/remove the schedule with scripts/install-schedule.sh.
# Log: ~/Library/Logs/mnfc-website-sync.log

set -uo pipefail

REPO="/Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website"
SELF="$REPO/scripts/sync-from-drive.sh"
CLAUDE="/Users/leonardjin/.local/bin/claude"
GH="/opt/homebrew/bin/gh"
LOG="$HOME/Library/Logs/mnfc-website-sync.log"
STATUS_FILE="$HOME/Library/Logs/mnfc-website-sync.status"
DISCORD="$REPO/scripts/notify-discord.sh"

# One reusable branch, reset from main every run. The pull request therefore
# always shows exactly "what Drive says now" against "what is published now",
# never an accumulation of superseded proposals for a reviewer to untangle.
BRANCH="sync/drive"

# Hold a power assertion for the whole run.
#
# launchd does not wake a sleeping Mac. It runs a missed job at whatever wake
# happens next, and on a sleeping laptop that is usually a maintenance DarkWake
# lasting a few seconds. Nothing here told macOS work was in progress, so the
# machine went back to sleep underneath the agent and killed its API call
# mid-response -- exactly how the 2026-08-27 run died 36 minutes in.
#
# caffeinate re-execs this script as its child and holds the assertion until it
# exits: -i blocks idle sleep, -m keeps the disk awake, -s blocks system sleep
# while on AC. On battery -s is ignored and a low-battery sleep can still cut a
# run short -- that is a power problem, not a scheduling one.
if [ -z "${MNFC_CAFFEINATED:-}" ]; then
  export MNFC_CAFFEINATED=1
  exec /usr/bin/caffeinate -i -m -s "$SELF" "$@"
fi

AGENT_OUT=$(mktemp -t mnfc-sync)

# The repo must be left on main with a clean tree no matter how this exits.
# Anything else trips the dirty-tree guard on the next run, which exits 0 and
# self-perpetuates -- every following run skips and the site quietly drifts.
cleanup() {
  rm -f "$AGENT_OUT"
  /usr/bin/git -C "$REPO" checkout -q main 2>/dev/null || true
}
trap cleanup EXIT

# The ultra-concise summary IS the commit subject: one line, and written by the
# agent that knew what it changed. Parsing it out of the free-prose narration
# instead would depend on formatting the agent never promised to keep.
summary_subject() {
  /usr/bin/git log -1 --format=%s "$AFTER" 2>/dev/null || echo "Site update"
}

changed_files() {
  /usr/bin/git diff-tree --no-commit-id --name-only -r "$AFTER" 2>/dev/null | tr '\n' ' '
}

# discord <state> <headline> [detail] -- never allowed to fail the run.
discord() {
  [ -x "$DISCORD" ] || return 0
  "$DISCORD" "$1" "$2" "${3:-}" || true
}

# This job is unattended, so a failure that lands only in the log is a failure
# nobody sees until the site is visibly stale -- which is how a run gets missed.
notify() {
  local msg="${1//\"/}"
  /usr/bin/osascript -e "display notification \"$msg\" with title \"Website sync\"" >/dev/null 2>&1 || true
}

# One line, tab-separated: state, timestamp, detail. scripts/check-sync-ran.sh
# reads this to detect the one failure this script cannot report -- never running.
record() {
  printf '%s\t%s\t%s\n' "$1" "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$2" > "$STATUS_FILE"
}

open_pr_url() {
  "$GH" pr list --head "$BRANCH" --state open --json url --jq '.[0].url // empty' 2>/dev/null
}

exec >>"$LOG" 2>&1
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Sync started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "═══════════════════════════════════════════════════════════"

cd "$REPO" || {
  echo "FATAL: repo not found at $REPO"
  record FAIL "repo not found"
  notify "Repo not found at $REPO. Sync could not start."
  discord fail "Could not start" "Repo not found at \`$REPO\`."
  exit 1
}

if ! /usr/bin/git diff --quiet || ! /usr/bin/git diff --cached --quiet; then
  echo "SKIP: uncommitted local changes present; not syncing over them."
  /usr/bin/git status --short
  record FAIL "uncommitted local changes"
  # Worth interrupting for: this skip is silent and self-perpetuating. Until the
  # tree is committed or stashed, every following run skips too and the site
  # keeps drifting from Drive with nothing to show that anything is wrong.
  notify "Skipped: uncommitted changes in the repo. Commit or stash them, or every run from now on will skip too."
  discord fail "Skipped -- uncommitted local changes" "Commit or stash them, or every following run skips too."
  exit 0
fi

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

BEFORE=$(/usr/bin/git rev-parse HEAD)

# Reset the proposal branch onto current main before the agent touches anything.
/usr/bin/git checkout -q -B "$BRANCH" || {
  echo "FATAL: could not create branch $BRANCH"
  record FAIL "branch checkout failed"
  discord fail "Could not create the proposal branch" "Branch: $BRANCH"
  exit 1
}
echo "Working on $BRANCH (reset from main at ${BEFORE:0:7})."

AGENT_PROMPT="Sync this club website from the club Google Drive.

Read CLAUDE.md in the repo root FIRST, then SYNC.md. CLAUDE.md records standing decisions
and the source-of-truth precedence between Drive docs; SYNC.md is the procedure and the
publishing rules. Follow both exactly. Then read index.html, stepper.html and style.css.

Read the Drive folder 'Ultra Hardcore Chip Codesign' (id 1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP)
and the subfolders SYNC.md names. Enumerate the subfolders of 'Build the Fab' - each is a
fabrication tool project that should appear in Current Projects.

Update index.html and stepper.html so the site matches Drive. Never invent content: every
claim must trace to a Drive doc, and an empty project folder gets a bare status such as
'Planned' rather than filler. Do not publish budgets, funding, vendor pricing, BOM costs,
outreach notes or to-do lists. Publish only officers and the faculty advisor by name, never
the general member roster. On roles the 'Engineering Structure' doc is ground truth and the
Constitution is NOT. Preserve the existing HTML structure and CSS. Update the 'last updated'
date in the index.html footer only if you change something. Do not touch anything under
docs/ - that directory documents this repo and mirrors nothing in Drive.

You are already on a branch named sync/drive. If nothing meaningful changed, make no commit
and say so. Otherwise commit with a message naming what changed. Do NOT push, do NOT merge,
and do NOT switch branches - a human reviews and merges this.

End with a one-paragraph summary of what changed."

AGENT_TOOLS="mcp__claude_ai_Google_Drive__search_files,mcp__claude_ai_Google_Drive__read_file_content,mcp__claude_ai_Google_Drive__get_file_metadata,mcp__claude_ai_Google_Drive__list_recent_files,Read,Edit,Write,Glob,Grep,Bash(git:*)"

# PIPESTATUS[0], not $? -- $? is tee's exit status, which is 0 even when the
# agent failed. Reading the wrong one reports every crash as a clean run.
run_agent() {
  "$CLAUDE" -p "$AGENT_PROMPT" --allowedTools "$AGENT_TOOLS" | tee -a "$AGENT_OUT"
  return ${PIPESTATUS[0]}
}

run_agent
STATUS=$?

# The dominant failure here is transient -- the machine sleeping mid-response,
# or a dropped connection -- and the old behaviour was to give up and leave the
# site stale until the next scheduled slot three or four days later. Retry once,
# from the same starting commit so the second attempt is not building on a
# half-finished first one.
if [ $STATUS -ne 0 ]; then
  echo "WARNING: agent exited $STATUS. Resetting and retrying once..."
  /usr/bin/git reset -q --hard "$BEFORE"
  run_agent
  STATUS=$?
  [ $STATUS -eq 0 ] && echo "Retry succeeded."
fi

# The agent may have edited without committing. Those edits sit on a throwaway
# branch and were never published, so discarding them loses nothing that was
# going to ship -- and it has to happen, because a dirty tree blocks the
# checkout back to main and would then block every future run.
if ! /usr/bin/git diff --quiet || ! /usr/bin/git diff --cached --quiet; then
  echo "WARNING: agent left uncommitted changes on $BRANCH; discarding them."
  /usr/bin/git reset -q --hard
fi

AFTER=$(/usr/bin/git rev-parse HEAD)

echo ""
if [ $STATUS -ne 0 ]; then
  echo "RESULT: claude exited $STATUS"
  record FAIL "claude exited $STATUS"
  notify "The sync agent exited $STATUS. Check the log; nothing was proposed."
  # Deliberately does NOT forward the agent's output. Its last few hundred
  # characters routinely quote whatever it was reading from Drive, and it reads
  # the docs holding BOM costs, vendor pricing and sponsorship correspondence --
  # the exact material rule 3 says never leaves Drive. A Discord channel is a
  # published surface: members join it, and messages get screenshotted.
  discord fail "Agent exited $STATUS" "Nothing was proposed. Details in the run log."

elif [ "$BEFORE" = "$AFTER" ]; then
  echo "RESULT: no changes proposed."
  record OK "no changes"
  # An open PR from an earlier run is now stale: main already matches Drive, so
  # merging it would republish content the agent has since judged unnecessary.
  # Close it rather than leave a mergeable-looking proposal sitting there.
  STALE=$(open_pr_url)
  if [ -n "$STALE" ]; then
    echo "Closing stale proposal: $STALE"
    "$GH" pr close "$BRANCH" --comment "Superseded: the site now matches Drive, so there is nothing left to publish." >/dev/null 2>&1 \
      && echo "Closed." || echo "WARNING: could not close $STALE"
    discord ok "No changes -- the site already matches Drive." "Closed a stale proposal that is no longer needed."
  else
    discord ok "No changes -- the site already matches Drive."
  fi

else
  SUBJECT=$(summary_subject)
  FILES=$(changed_files)
  echo "RESULT: proposed $BEFORE -> $AFTER on $BRANCH"
  echo "Subject: $SUBJECT"

  if /usr/bin/git push -q --force-with-lease origin "$BRANCH"; then
    PR_URL=$(open_pr_url)
    if [ -z "$PR_URL" ]; then
      PR_BODY="Proposed by the scheduled Drive sync on $(date '+%Y-%m-%d %H:%M %Z').

**Changed:** ${FILES:-(none listed)}

Review the diff below. **Merging publishes to the live site** - GitHub Pages rebuilds from \`main\` in about a minute. Closing this discards the proposal; the next scheduled run re-proposes it if Drive still disagrees with the site.

This branch is reset from \`main\` on every run, so this PR always reflects current Drive rather than a pile-up of older proposals."
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
fi

echo "Sync finished: $(date '+%Y-%m-%d %H:%M:%S %Z')"
