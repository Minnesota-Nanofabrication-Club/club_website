#!/bin/bash
# Install (or remove) the weekly website sync schedule on macOS.
#
#   ./scripts/install-schedule.sh            install / reinstall
#   ./scripts/install-schedule.sh uninstall  remove
#   ./scripts/install-schedule.sh status     show whether it's loaded and when it last ran
#
# Runs Mondays at 8:13am local. If the Mac is asleep at that time, launchd runs
# the job when it next wakes.

set -euo pipefail

LABEL="com.mnfc.website-sync"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SCRIPT="/Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website/scripts/sync-from-drive.sh"
LOG="$HOME/Library/Logs/mnfc-website-sync.log"

case "${1:-install}" in
  uninstall)
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"
    echo "Removed $LABEL."
    exit 0
    ;;
  status)
    # Note: don't pipe launchctl into `grep -q` — grep exits on first match, the
    # resulting SIGPIPE trips `pipefail`, and the check reports a false negative.
    LISTING=$(launchctl list 2>/dev/null || true)
    if printf '%s\n' "$LISTING" | grep "$LABEL"; then
      echo "^ loaded. Next run: Monday 8:13am."
    else
      echo "Not loaded. Run this script with no arguments to install."
    fi
    echo ""
    echo "Last log entries:"
    tail -20 "$LOG" 2>/dev/null || echo "(no log yet)"
    exit 0
    ;;
esac

chmod +x "$SCRIPT"
mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key><integer>1</integer>
        <key>Hour</key><integer>8</integer>
        <key>Minute</key><integer>13</integer>
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

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "Installed $LABEL — runs Mondays at 8:13am."
echo "Plist: $PLIST"
echo "Log:   $LOG"
echo ""
echo "Run it right now to test:  $SCRIPT"
echo "Check status:              ./scripts/install-schedule.sh status"
