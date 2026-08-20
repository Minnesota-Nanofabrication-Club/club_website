#!/bin/bash
# Twice-weekly Google Drive -> website sync (Mon + Thu), run locally by launchd.
#
# Runs on Leonard's Mac rather than in Anthropic's cloud, because cloud routines
# cannot push to GitHub without a Team/Enterprise plan. Locally, git already has
# push access via SSH, so the whole loop works.
#
# Install/remove the schedule with scripts/install-schedule.sh.
# Log: ~/Library/Logs/mnfc-website-sync.log

set -uo pipefail

REPO="/Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website"
CLAUDE="/Users/leonardjin/.local/bin/claude"
LOG="$HOME/Library/Logs/mnfc-website-sync.log"
STATUS_FILE="$HOME/Library/Logs/mnfc-website-sync.status"
DISCORD="$REPO/scripts/notify-discord.sh"

# Captures the agent's own narration so a one-line summary can be pulled out of
# it. Removed on exit, including the early-exit guard paths.
AGENT_OUT=$(mktemp -t mnfc-sync)
trap 'rm -f "$AGENT_OUT"' EXIT

# The ultra-concise summary IS the commit subject: one line, and written by the
# agent that knew what it changed. Parsing it out of the free-prose narration
# instead would depend on formatting the agent never promised to keep.
summary_subject() {
  /usr/bin/git log -1 --format=%s "$AFTER" 2>/dev/null || echo "Site updated"
}

summary_detail() {
  local files
  files=$(/usr/bin/git diff-tree --no-commit-id --name-only -r "$AFTER" 2>/dev/null | tr '\n' ' ')
  echo "\`${AFTER:0:7}\` · ${files:-(no files listed)}"
}

# discord <state> <headline> [detail] -- never allowed to fail the run.
discord() {
  [ -x "$DISCORD" ] || return 0
  "$DISCORD" "$1" "$2" "${3:-}" || true
}

# This job is unattended, so a failure that lands only in the log is a failure
# nobody sees until the site is visibly stale -- which is how a run gets missed.
# Every failure path below notifies. Success stays silent on purpose: a routine
# "nothing changed" popup trains you to dismiss the notification you need to read.
notify() {
  local msg="${1//\"/}"
  /usr/bin/osascript -e "display notification \"$msg\" with title \"Website sync\"" >/dev/null 2>&1 || true
}

# One line, tab-separated: state, timestamp, detail. scripts/check-sync-ran.sh
# reads this to detect the one failure this script cannot report -- never running.
record() {
  printf '%s\t%s\t%s\n' "$1" "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$2" > "$STATUS_FILE"
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

echo "Pulling latest..."
/usr/bin/git pull --ff-only origin main || {
  echo "FATAL: git pull failed"
  record FAIL "git pull failed"
  notify "git pull failed -- history may have diverged from origin/main. Sync aborted."
  discord fail "git pull failed" "History may have diverged from \`origin/main\`."
  exit 1
}

BEFORE=$(/usr/bin/git rev-parse HEAD)

"$CLAUDE" -p "Sync this club website from the club Google Drive.

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
date in the index.html footer only if you change something.

If nothing meaningful changed, make no commit and say so. Otherwise commit with a message
naming what changed and push to main with 'git push origin main'.

End with a one-paragraph summary of what changed." \
  --allowedTools \
"mcp__claude_ai_Google_Drive__search_files,\
mcp__claude_ai_Google_Drive__read_file_content,\
mcp__claude_ai_Google_Drive__get_file_metadata,\
mcp__claude_ai_Google_Drive__list_recent_files,\
Read,Edit,Write,Glob,Grep,Bash(git:*)" | tee "$AGENT_OUT"

# PIPESTATUS[0], not $? -- $? is tee's exit status, which is 0 even when the
# agent failed. Reading the wrong one reports every crash as a clean run.
STATUS=${PIPESTATUS[0]}
AFTER=$(/usr/bin/git rev-parse HEAD)

echo ""
if [ $STATUS -ne 0 ]; then
  echo "RESULT: claude exited $STATUS"
  record FAIL "claude exited $STATUS"
  notify "The sync agent exited $STATUS. Check the log; the site was not updated."
  # Deliberately does NOT forward the agent's output. Its last few hundred
  # characters routinely quote whatever it was reading from Drive, and it reads
  # the docs holding BOM costs, vendor pricing and sponsorship correspondence --
  # the exact material rule 3 says never leaves Drive. A Discord channel is a
  # published surface: members join it, and messages get screenshotted. The
  # diagnostic detail stays in the log, on the machine that produced it.
  discord fail "Agent exited $STATUS" "The site was not updated. Details in \`~/Library/Logs/mnfc-website-sync.log\`."
elif [ "$BEFORE" = "$AFTER" ]; then
  echo "RESULT: no changes committed."
  # Not a failure. Drive matched the site, so rule 7 says make no commit.
  record OK "no changes"
  discord ok "No changes -- the site already matches Drive."
else
  echo "RESULT: committed $BEFORE -> $AFTER"
  # Ask git directly for unpushed commits rather than parsing `git status -sb`
  # through a pipe: `head`/`grep -q` exit early, the resulting SIGPIPE trips
  # `pipefail`, and the test silently reports "pushed" when it wasn't.
  # A successful push updates the origin/main ref, so this range goes empty.
  if [ -n "$(/usr/bin/git rev-list origin/main..HEAD 2>/dev/null)" ]; then
    echo "WARNING: commit was not pushed. Retrying push..."
    if /usr/bin/git push origin main; then
      echo "Push succeeded on retry."
      record OK "committed $AFTER (pushed on retry)"
      discord changed "$(summary_subject)" "$(summary_detail) (pushed on retry)"
    else
      echo "ERROR: push failed."
      record FAIL "commit $AFTER not pushed"
      # The commit exists locally but the site is unchanged, and the tree is now
      # clean -- so nothing here trips the dirty-tree guard next run and the
      # unpushed commit could sit unnoticed indefinitely.
      notify "Committed but could not push. The site is NOT updated -- run: git push origin main"
      discord fail "Committed but could not push" "The site is NOT updated. Run \`git push origin main\`."
    fi
  else
    echo "Pushed to origin/main. GitHub Pages will rebuild in ~1 minute."
    record OK "committed $AFTER"
    discord changed "$(summary_subject)" "$(summary_detail)"
  fi
fi

echo "Sync finished: $(date '+%Y-%m-%d %H:%M:%S %Z')"
