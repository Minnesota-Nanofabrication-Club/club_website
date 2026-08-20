#!/bin/bash
# Install (or remove) the weekly website sync schedule on macOS.
#
#   ./scripts/install-schedule.sh            install / reinstall
#   ./scripts/install-schedule.sh uninstall  remove
#   ./scripts/install-schedule.sh status     show whether it's loaded and when it last ran
#
# Installs TWO launchd jobs:
#   com.mnfc.website-sync           Mondays 8:13am -- the sync itself
#   com.mnfc.website-sync-watchdog  Mondays 2:13pm -- checks the sync actually ran
#
# The watchdog exists because the sync cannot report the one failure that matters
# most: not running at all. A job that never fires sends no notification, writes
# no log line, and looks exactly like a quiet week.
#
# If the Mac is asleep at the scheduled time, launchd runs the job when it next wakes.

set -euo pipefail

REPO_DIR="/Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website"
SYNC_LABEL="com.mnfc.website-sync"
WATCH_LABEL="com.mnfc.website-sync-watchdog"
SYNC_SCRIPT="$REPO_DIR/scripts/sync-from-drive.sh"
WATCH_SCRIPT="$REPO_DIR/scripts/check-sync-ran.sh"
SYNC_PLIST="$HOME/Library/LaunchAgents/$SYNC_LABEL.plist"
WATCH_PLIST="$HOME/Library/LaunchAgents/$WATCH_LABEL.plist"
LOG="$HOME/Library/Logs/mnfc-website-sync.log"
STATUS_FILE="$HOME/Library/Logs/mnfc-website-sync.status"

# write_plist <path> <label> <script> <hour> <minute>
write_plist() {
  cat > "$1" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$2</string>
    <key>ProgramArguments</key>
    <array>
        <string>$3</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key><integer>1</integer>
        <key>Hour</key><integer>$4</integer>
        <key>Minute</key><integer>$5</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$LOG</string>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
PLISTEOF
}

# reload <label> <plist>
reload() {
  launchctl bootout "gui/$(id -u)/$1" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$2"
}

# show_loaded <label> <when>
show_loaded() {
  # Note: don't pipe launchctl into `grep -q` -- grep exits on first match, the
  # resulting SIGPIPE trips `pipefail`, and the check reports a false negative.
  LISTING=$(launchctl list 2>/dev/null || true)
  if printf '%s\n' "$LISTING" | grep "$1"; then
    echo "^ $1 loaded. Next run: $2."
  else
    echo "$1 NOT loaded. Run this script with no arguments to install."
  fi
}

case "${1:-install}" in
  uninstall)
    for L in "$SYNC_LABEL" "$WATCH_LABEL"; do
      launchctl bootout "gui/$(id -u)/$L" 2>/dev/null || true
    done
    rm -f "$SYNC_PLIST" "$WATCH_PLIST"
    echo "Removed $SYNC_LABEL and $WATCH_LABEL."
    exit 0
    ;;
  status)
    show_loaded "$SYNC_LABEL" "Monday 8:13am"
    echo ""
    show_loaded "$WATCH_LABEL" "Monday 2:13pm"
    echo ""
    echo "Last recorded outcome:"
    if [ -f "$STATUS_FILE" ]; then
      cat "$STATUS_FILE"
    else
      echo "(none yet)"
    fi
    echo ""
    echo "Last log entries:"
    tail -20 "$LOG" 2>/dev/null || echo "(no log yet)"
    exit 0
    ;;
esac

chmod +x "$SYNC_SCRIPT" "$WATCH_SCRIPT"
mkdir -p "$HOME/Library/LaunchAgents"

write_plist "$SYNC_PLIST"  "$SYNC_LABEL"  "$SYNC_SCRIPT"  8  13
write_plist "$WATCH_PLIST" "$WATCH_LABEL" "$WATCH_SCRIPT" 14 13

reload "$SYNC_LABEL"  "$SYNC_PLIST"
reload "$WATCH_LABEL" "$WATCH_PLIST"

echo "Installed:"
echo "  $SYNC_LABEL   -- Mondays 8:13am"
echo "  $WATCH_LABEL  -- Mondays 2:13pm"
echo ""
echo "Log:    $LOG"
echo "Status: $STATUS_FILE"
echo ""
echo "Run the sync right now to test:  $SYNC_SCRIPT"
echo "Check status:                    ./scripts/install-schedule.sh status"
