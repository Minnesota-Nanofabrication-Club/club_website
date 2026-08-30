#!/bin/bash
# Watchdog for the twice-weekly Drive -> website sync.
#
# sync-from-drive.sh notifies you when a run FAILS. It cannot notify you when a
# run never happens at all -- if the Mac is off or asleep through a scheduled
# slot, nothing executes and nothing complains, and the site quietly goes stale.
# That is the gap this script closes: it runs a few hours after each sync is due
# and checks that a run actually recorded itself.
#
# STALE_DAYS tracks the run interval. Syncs fire Monday and Thursday, so the
# longest healthy gap is four days (Thursday to Monday); a threshold above that
# would let a missed run pass unreported.
#
# It does not just report. A missed or failed run is recoverable -- the sync is
# idempotent, it reads Drive and rewrites the HTML from scratch every time -- so
# the watchdog re-runs it rather than waiting three or four days for the next
# scheduled slot and leaving the site stale in the meantime. Alerting a human and
# waiting for them to act is exactly the loop this is supposed to close.
#
# Installed alongside the sync job by scripts/install-schedule.sh.

set -uo pipefail

STATUS_FILE="$HOME/Library/Logs/mnfc-website-sync.status"
SYNC_LABEL="com.mnfc.website-sync"
DISCORD="/Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website/scripts/notify-discord.sh"
SYNC="/Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website/scripts/sync-from-drive.sh"
STALE_DAYS=4

# Re-run the sync now. Runs in the foreground under this job's own launchd
# session so it inherits the same environment the scheduled run gets, and so
# the watchdog cannot exit and let the machine sleep underneath it.
catch_up() {
  echo "WATCHDOG: triggering a catch-up run."
  if [ -x "$SYNC" ]; then
    "$SYNC"
  else
    echo "WATCHDOG: $SYNC is not executable; cannot recover."
  fi
}

notify() {
  local msg="${1//\"/}"
  /usr/bin/osascript -e "display notification \"$msg\" with title \"Website sync\"" >/dev/null 2>&1 || true
}

# The watchdog reports the one failure the sync cannot: that it never ran. A
# macOS banner alone puts that alert on the machine whose being off or asleep is
# the most likely cause of the missed run in the first place -- and it is not
# persistent, so a banner raised while nobody is looking is simply gone.
# Discord is the channel that reaches you away from the Mac.
discord() {
  [ -x "$DISCORD" ] || return 0
  "$DISCORD" fail "$1" "${2:-}" || true
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
  notify "No sync has ever recorded a run. Starting one now."
  discord "No sync had ever run" "Starting a catch-up run now."
  catch_up
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
  notify "Last sync failed ($DETAIL). Retrying now."
  discord "Last sync failed -- retrying" "$DETAIL (at $WHEN). Starting a catch-up run."
  catch_up
  echo "WATCHDOG: last run FAILED at $WHEN -- $DETAIL"
elif [ "$AGE_DAYS" -gt "$STALE_DAYS" ]; then
  notify "No sync in $AGE_DAYS days. Running one now."
  discord "No sync in $AGE_DAYS days -- catching up" "Was the Mac off or asleep? Last run: $WHEN. Starting a catch-up run."
  catch_up
  echo "WATCHDOG: last successful run was $AGE_DAYS days ago ($WHEN)"
else
  echo "WATCHDOG: ok -- last run $STATE at $WHEN ($DETAIL), $AGE_DAYS day(s) ago"
fi
