#!/bin/bash
# Weekly Google Drive -> website sync, run locally by launchd.
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

exec >>"$LOG" 2>&1
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Sync started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "═══════════════════════════════════════════════════════════"

cd "$REPO" || { echo "FATAL: repo not found at $REPO"; exit 1; }

if ! /usr/bin/git diff --quiet || ! /usr/bin/git diff --cached --quiet; then
  echo "SKIP: uncommitted local changes present; not syncing over them."
  /usr/bin/git status --short
  exit 0
fi

echo "Pulling latest..."
/usr/bin/git pull --ff-only origin main || { echo "FATAL: git pull failed"; exit 1; }

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
Read,Edit,Write,Glob,Grep,Bash(git:*)"

STATUS=$?
AFTER=$(/usr/bin/git rev-parse HEAD)

echo ""
if [ $STATUS -ne 0 ]; then
  echo "RESULT: claude exited $STATUS"
elif [ "$BEFORE" = "$AFTER" ]; then
  echo "RESULT: no changes committed."
else
  echo "RESULT: committed $BEFORE -> $AFTER"
  # Ask git directly for unpushed commits rather than parsing `git status -sb`
  # through a pipe: `head`/`grep -q` exit early, the resulting SIGPIPE trips
  # `pipefail`, and the test silently reports "pushed" when it wasn't.
  # A successful push updates the origin/main ref, so this range goes empty.
  if [ -n "$(/usr/bin/git rev-list origin/main..HEAD 2>/dev/null)" ]; then
    echo "WARNING: commit was not pushed. Retrying push..."
    /usr/bin/git push origin main && echo "Push succeeded on retry." || echo "ERROR: push failed."
  else
    echo "Pushed to origin/main. GitHub Pages will rebuild in ~1 minute."
  fi
fi

echo "Sync finished: $(date '+%Y-%m-%d %H:%M:%S %Z')"
