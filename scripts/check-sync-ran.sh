#!/bin/bash
# Watchdog for the weekly Drive -> website sync.
#
# sync-from-drive.sh notifies you when a run FAILS. It cannot notify you when a
# run never happens at all -- if the Mac is off or asleep through Monday, nothing
# executes and nothing complains, and the site quietly goes stale. That is the
# gap this script closes: it runs a few hours after the sync is due and checks
# that a run actually recorded itself.
#
# Installed alongside the sync job by scripts/install-schedule.sh.

set -uo pipefail

STATUS_FILE="$HOME/Library/Logs/mnfc-website-sync.status"
SYNC_LABEL="com.mnfc.website-sync"
STALE_DAYS=6

notify() {
  local msg="${1//\"/}"
  /usr/bin/osascript -e "display notification \"$msg\" with title \"Nanofab site sync\"" >/dev/null 2>&1 || true
}

# If the sync is running right now, this check is racing it -- most likely both
# jobs were triggered together when the Mac woke from a long sleep. Let it finish.
LISTING=$(launchctl list 2>/dev/null || true)
SYNC_LINE=$(printf '%s\n' "$LISTING" | grep "$SYNC_LABEL" || true)
if [ -n "$SYNC_LINE" ] && ! printf '%s\n' "$SYNC_LINE" | grep -q '^-'; then
  echo "Sync is currently running; skipping watchdog check."
  exit 0
fi

if [ ! -f "$STATUS_FILE" ]; then
  notify "No sync has ever recorded a run. The schedule may not be installed."
  echo "WATCHDOG: no status file at $STATUS_FILE"
  exit 0
fi

STATE=$(cut -f1 "$STATUS_FILE")
WHEN=$(cut -f2 "$STATUS_FILE")
DETAIL=$(cut -f3 "$STATUS_FILE")
MTIME=$(stat -f %m "$STATUS_FILE" 2>/dev/null || echo 0)
NOW=$(date +%s)
AGE_DAYS=$(( (NOW - MTIME) / 86400 ))

if [ "$STATE" = "FAIL" ]; then
  notify "Last sync failed ($DETAIL). The site may be stale."
  echo "WATCHDOG: last run FAILED at $WHEN -- $DETAIL"
elif [ "$AGE_DAYS" -gt "$STALE_DAYS" ]; then
  notify "No sync in $AGE_DAYS days. Was the Mac off? Run scripts/sync-from-drive.sh."
  echo "WATCHDOG: last successful run was $AGE_DAYS days ago ($WHEN)"
else
  echo "WATCHDOG: ok -- last run $STATE at $WHEN ($DETAIL), $AGE_DAYS day(s) ago"
fi
