# The Schedule

How the sync gets triggered: two `launchd` jobs installed by `scripts/install-schedule.sh`,
what each one does, and how they behave when the Mac is asleep or off. What happens *inside*
a triggered run is in [Anatomy of a Sync Run](sync-run.md), and how a run reports itself is in
[Notifications](notifications.md). **Both jobs fire twice a week — Monday and Thursday — from
exactly one laptop, and every path in them is absolute and hardcoded.**

---

## Contents

- [The two jobs](#the-two-jobs)
- [The plist](#the-plist)
- [The three subcommands](#the-three-subcommands)
- [The watchdog](#the-watchdog)
- [Sleep, wake, and off](#sleep-wake-and-off)
- [Single point of failure](#single-point-of-failure)

---

## The two jobs

`scripts/install-schedule.sh` writes and bootstraps two `launchd` user agents:

| Label | Runs | Program | Purpose |
| --- | --- | --- | --- |
| `com.mnfc.website-sync` | Mon **and** Thu, 08:13 local | `scripts/sync-from-drive.sh` | The sync itself |
| `com.mnfc.website-sync-watchdog` | Mon **and** Thu, 14:13 local | `scripts/check-sync-ran.sh` | Checks that the sync actually ran |

Both are per-user agents in the `gui/$(id -u)` domain, not system daemons. That is required,
not incidental: the run needs the logged-in user's Google Drive connector session and the
user's SSH access to GitHub, neither of which exists in a system domain.

| Path | What it is |
| --- | --- |
| `~/Library/LaunchAgents/com.mnfc.website-sync.plist` | Sync job definition |
| `~/Library/LaunchAgents/com.mnfc.website-sync-watchdog.plist` | Watchdog job definition |
| `~/Library/Logs/mnfc-website-sync.log` | Shared stdout+stderr for both jobs |
| `~/Library/Logs/mnfc-website-sync.status` | Last recorded outcome, one tab-separated line |

---

## The plist

Both plists come from one `write_plist` helper taking `<path> <label> <script> <hour>
<minute>`, so the two jobs differ only in label, program and time. The generated file:

```xml
<key>StartCalendarInterval</key>
<array>
    <dict>
        <key>Weekday</key><integer>1</integer>
        <key>Hour</key><integer>8</integer>
        <key>Minute</key><integer>13</integer>
    </dict>
    <dict>
        <key>Weekday</key><integer>4</integer>
        <key>Hour</key><integer>8</integer>
        <key>Minute</key><integer>13</integer>
    </dict>
</array>
<key>StandardOutPath</key>
<string>/Users/leonardjin/Library/Logs/mnfc-website-sync.log</string>
<key>StandardErrorPath</key>
<string>/Users/leonardjin/Library/Logs/mnfc-website-sync.log</string>
<key>RunAtLoad</key>
<false/>
```

| Key | Value | Why |
| --- | --- | --- |
| `StartCalendarInterval` | an **array** of two `<dict>` entries | A single `<dict>` fires on one weekday only. The array form is how `launchd` expresses a job with more than one slot — both entries carry the same `Hour` and `Minute`, and differ only in `Weekday`. |
| `Weekday` | `1` and `4` | Monday and Thursday. `write_plist` emits both dicts from one `<hour> <minute>` pair, so the two slots cannot drift apart. |
| `Hour` / `Minute` | `8` / `13`, and `14` / `13` for the watchdog | An odd minute rather than `:00` — nothing else on the machine is scheduled there, so the run does not compete with the top-of-hour crowd for the network and CPU it needs. |
| `StandardOutPath` | the log | Catches anything written before `sync-from-drive.sh` sets up its own `exec >>"$LOG"` redirect — a shell syntax error or a missing interpreter would otherwise vanish. |
| `StandardErrorPath` | the log | Same file, so a run reads as one chronological block. |
| `RunAtLoad` | `false` | **Reinstalling must not trigger a run.** With `true`, every `install-schedule.sh` invocation — including a `status` check gone wrong, or a reinstall while debugging — would immediately launch an unattended agent with `Edit`, `Write` and `Bash(git:*)` against the repo you are standing in. Install is a configuration action; running is `./scripts/sync-from-drive.sh`. |

!!! note "Both jobs share one log file"
    Watchdog lines are prefixed `WATCHDOG:` and sync lines by the `═` divider and
    `Sync started:`. Interleaving is not a concern in practice — within a day the two are
    scheduled six hours apart, and the watchdog exits early if it finds the sync still
    running.

---

## The three subcommands

```bash
./scripts/install-schedule.sh            # install / reinstall (the default)
./scripts/install-schedule.sh status     # loaded? what did the last run do?
./scripts/install-schedule.sh uninstall  # remove both jobs
```

| Subcommand | What it does |
| --- | --- |
| `install` (default, no argument) | `chmod +x` on both scripts, `mkdir -p ~/Library/LaunchAgents`, writes both plists via `write_plist`, then for each label `launchctl bootout` (ignoring failure) followed by `launchctl bootstrap`. Prints both labels, the log path and the status path. |
| `status` | For each label, captures `launchctl list` into `LISTING` and greps it, printing `^ <label> loaded. Next run: Monday and Thursday, 8:13am` (or `2:13pm` for the watchdog) or `<label> NOT loaded.` Then prints the contents of `STATUS_FILE` — or `(none yet)` — and `tail -20` of the log. |
| `uninstall` | `launchctl bootout` for both labels, `rm -f` both plists, prints `Removed ...`. Leaves the log and the status file in place. |

The script runs under `set -euo pipefail`, so any unhandled failure aborts rather than
half-installing.

### Why install is bootout-then-bootstrap

`launchctl bootstrap` on an already-loaded label fails. Rewriting a plist under a loaded job
also does nothing — `launchd` holds the parsed job, not the file, so an edited schedule stays
inert until the job is reloaded. Unconditionally booting out first (with `2>/dev/null || true`,
because a not-loaded job is the normal case on first install) makes `install` idempotent: run
it any number of times and the loaded job always matches the plist on disk.

### Why `status` captures `launchctl list` into a variable

**Never pipe `launchctl list` straight into `grep -q`.** `grep -q` exits the moment it
matches, which closes the pipe under the still-writing `launchctl`, which takes `SIGPIPE`.
Under `set -o pipefail` the pipeline reports that death as its own status and the `if` reads
it as "not loaded" — so `status` printed `Not loaded. Run this script with no arguments to
install.` for a job that was loaded and running fine, and the obvious response to that
message is to reinstall a schedule that was never broken. Capturing into `LISTING` first and
testing the variable removes the pipeline and the race with it. Fixed in commit `99e3012`,
alongside the identical bug in the sync script's push check — see
[Anatomy of a Sync Run](sync-run.md#step-6-the-push-verification).

### Triggering a run without waiting

```bash
# run the sync directly — output goes to the log, not your terminal
/Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website/scripts/sync-from-drive.sh
tail -f ~/Library/Logs/mnfc-website-sync.log

# or fire the launchd job exactly as a scheduled slot would, environment and all
launchctl kickstart -k "gui/$(id -u)/com.mnfc.website-sync"
```

!!! tip "`kickstart` tests more than running the script does"
    Running the script from a terminal inherits your interactive environment — `PATH`, a live
    `ssh-agent`, connector sessions. `launchctl kickstart` runs it under `launchd`'s minimal
    environment, which is the environment the scheduled run actually uses. This is how the 2026-08-19
    verification was done: the job fired, the Drive connector authenticated under `launchd`,
    and the run correctly made no commit because Drive already matched the site.

---

## The watchdog

`scripts/check-sync-ran.sh`, fired six hours after each sync is due — so it too runs twice a
week, Monday and Thursday at 14:13.

**Why a second job exists.** `sync-from-drive.sh` notifies on every failure path it has — but
a script that notifies on failure structurally cannot notify you that it never ran. If the
Mac is off or asleep through a scheduled slot, no process starts, no log line is written, no
notification fires, and the outcome is indistinguishable from a quiet run where Drive simply
did not change. That silence is the single most likely way a run gets missed, and it is the
one failure the sync itself can never report. The watchdog closes it by checking, from the
outside, that a run recorded itself.

It reads `~/Library/Logs/mnfc-website-sync.status` — the one-line
`state <TAB> timestamp <TAB> detail` file written by `record()` in the sync script — plus the
file's own mtime. The file's format and the rest of the reporting channels are in
[Notifications](notifications.md#the-status-file). The watchdog raises macOS notifications
only; it never posts to Discord.

| Condition | Log line | Notification |
| --- | --- | --- |
| Sync currently running | `Sync is currently running; skipping watchdog check.` | none — exits `0` |
| No `STATUS_FILE` at all | `WATCHDOG: no status file at <path>` | `No sync has ever recorded a run. The schedule may not be installed.` |
| `STATE` is `FAIL` | `WATCHDOG: last run FAILED at <when> -- <detail>` | `Last sync failed (<detail>). The site may be stale.` |
| mtime older than `STALE_DAYS=4` | `WATCHDOG: last successful run was N days ago (<when>)` | `No sync in N days. Was the Mac off? Run scripts/sync-from-drive.sh.` |
| otherwise | `WATCHDOG: ok -- last run <state> at <when> (<detail>), N day(s) ago` | none |

The race guard comes first, and it reads `launchctl list` the safe way — capture into
`LISTING`, grep for the sync label into `SYNC_LINE`, then test whether that line starts with
`-`. A `launchctl list` row shows `-` in the PID column when the job is not currently
executing and a real PID when it is. A run still in flight means the watchdog was triggered
alongside it — the usual cause is both jobs firing together after the Mac wakes from a long
sleep — so it exits rather than reporting a stale status file that the running job is about
to overwrite.

!!! danger "`STALE_DAYS` tracks the run interval — it is `4`, not `6`"
    **The threshold must sit just above the longest healthy gap between runs.** With slots on
    Monday and Thursday, the longest healthy gap is Thursday → Monday: four days. `STALE_DAYS=4`
    tolerates that, and tolerates a run that slips by a few hours because the Mac woke in the
    afternoon, while still catching a slot that was missed entirely. The old value of `6` was
    correct for a single weekly slot and is wrong now: at `6`, a Monday run that never happened
    would still be inside the threshold when the Thursday watchdog checked, and again when the
    following Monday's did — so a missed run would pass unreported and the alert would arrive
    late or not at all. If the schedule changes again, this number changes with it.

---

## Sleep, wake, and off

`StartCalendarInterval` is not a wake-up alarm. The behavior at the scheduled minute:

| Machine state at 08:13 on a scheduled day | What happens |
| --- | --- |
| Awake | The job runs on time. |
| Asleep | `launchd` runs the job as soon as the Mac next wakes. |
| Off through the whole slot | That run is skipped entirely. |

**A skipped run is harmless, and that is a property of the design rather than luck.** The
sync is not incremental — it reads the current state of Drive and rewrites the HTML to match,
with no queue of pending changes and no per-run diff to lose. Whatever changed in Drive during
a missed slot is simply part of what the next run sees. The only cost of a skipped Monday is
that the published site waits until Thursday; nothing is dropped, and no manual catch-up is
required. Running the script by hand is a convenience, not a repair.

The watchdog is what turns a skipped run from invisible into a notification — but only if the
Mac is on at 14:13 to run it. A machine that is off all day runs neither job, and the alert
arrives whenever it next wakes with the status file more than four days old.

---

## Single point of failure { #single-point-of-failure }

!!! warning "This runs from exactly one laptop"
    `REPO_DIR`, `SYNC_SCRIPT`, `WATCH_SCRIPT` and the sync script's `REPO` and `CLAUDE` are
    absolute paths under `/Users/leonardjin`. The Google Drive connector session and the SSH
    key that authorizes `git push` belong to that user account on that machine. Nothing
    detects or reports the machine being permanently gone — the watchdog needs the same Mac
    to be running in order to complain about it. If that laptop is replaced, lost, or the
    account is renamed, the site stops tracking Drive and the only symptom is content that
    slowly ages.

Moving the schedule to a different machine means, at minimum:

1. Clone the repo and update `REPO_DIR` in `scripts/install-schedule.sh` and `REPO` in
   `scripts/sync-from-drive.sh`.
2. Update `CLAUDE` to the new `claude` binary path — confirm it with `which claude`.
3. Sign the new machine's Claude Code install in to the Google Drive connector, and confirm
   it authenticates under `launchd`'s minimal environment, not just in a terminal.
4. Give the new machine SSH push access to the GitHub repo, then verify it with no
   shell-provided agent:

   ```bash
   env -i /usr/bin/git -C /path/to/club_website push --dry-run origin main
   ```

5. `./scripts/install-schedule.sh` on the new machine, `./scripts/install-schedule.sh
   uninstall` on the old one.
6. Trigger a full run with `launchctl kickstart -k "gui/$(id -u)/com.mnfc.website-sync"` and
   read the log.

Do not solve this by re-enabling the disabled cloud routine — the reason it cannot push is in
[Deployment](deployment.md#why-local-and-not-a-cloud-routine).

---

[← Anatomy of a Sync Run](sync-run.md){ .md-button } [Notifications →](notifications.md){ .md-button .md-button--primary }
