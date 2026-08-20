# Notifications

Every way the sync tells you what happened: the run log, the status file, macOS
notifications, and Discord. What each channel carries, when each one fires, and how to set
Discord up. What produces these outcomes in the first place is in
[Anatomy of a Sync Run](sync-run.md). **The job is unattended, so a failure nobody is told
about is a failure nobody finds until the site is visibly stale.**

---

## Contents

- [The four channels](#the-four-channels)
- [What fires on each outcome](#what-fires-on-each-outcome)
- [The run log](#the-run-log)
- [The status file](#the-status-file)
- [macOS notifications](#macos-notifications)
- [Discord](#discord)
- [Setting up Discord](#setting-up-discord)
- [What none of these channels covers](#what-none-of-these-channels-covers)

---

## The four channels

| Channel | Where | Fires on | Persistent | Reaches you without looking |
| --- | --- | --- | --- | --- |
| Run log | `~/Library/Logs/mnfc-website-sync.log` | every line of every run, both jobs | yes, append-only, unrotated | no |
| Status file | `~/Library/Logs/mnfc-website-sync.status` | every branch, via `record` | yes, one line, overwritten each run | no |
| macOS notification | `osascript display notification`, title `Website sync` | sync failures, and all watchdog alerts | no | on that Mac, if it is awake and not in Do Not Disturb |
| Discord | `scripts/notify-discord.sh` → incoming webhook | every sync outcome including success, plus watchdog alerts | yes, in the channel's history | yes, anywhere |

The four are deliberately not redundant. The log is complete and unreadable; the status file
is one machine-readable line and is what the watchdog polls; the macOS notification is
loud and ephemeral; Discord is the only channel that reaches a phone and the only one that
survives the laptop being off.

!!! note "The watchdog reports on both channels"
    `scripts/check-sync-ran.sh` raises a macOS banner *and* posts a `fail` embed to Discord
    for all three of its alerts — no status file, a `FAIL` state, or a stale mtime. A macOS
    banner alone would put the "the job never ran" alert on the machine whose being off is
    the most likely cause of the missed run, and banners do not persist. Its healthy path
    stays silent on both. See [The Schedule](schedule.md#the-watchdog).

---

## What fires on each outcome

| Outcome | Log line | `record` | macOS | Discord |
| --- | --- | --- | --- | --- |
| Repo not found | `FATAL: repo not found at <path>` | `FAIL  repo not found` | yes | `fail` — `Could not start` |
| Dirty tree | `SKIP: uncommitted local changes present; not syncing over them.` | `FAIL  uncommitted local changes` | yes | `fail` — `Skipped -- uncommitted local changes` |
| Non-fast-forward pull | `FATAL: git pull failed` | `FAIL  git pull failed` | yes | `fail` — `git pull failed` |
| Agent exited non-zero | `RESULT: claude exited N` | `FAIL  claude exited N` | yes | `fail` — `Agent exited N`, with the last 400 bytes of the agent's output |
| No changes | `RESULT: no changes committed.` | `OK  no changes` | **no** | `ok` — `No changes -- the site already matches Drive.` |
| Committed and pushed | `Pushed to origin/main. …` | `OK  committed <sha>` | **no** | `changed` — the commit subject |
| Committed, pushed on retry | `Push succeeded on retry.` | `OK  committed <sha> (pushed on retry)` | **no** | `changed` — the commit subject, detail suffixed `(pushed on retry)` |
| Committed, push failed twice | `ERROR: push failed.` | `FAIL  commit <sha> not pushed` | yes | `fail` — `Committed but could not push` |
| No run at all | *(nothing)* | *unchanged, and ageing* | watchdog only | **none** |

The last row is the whole reason the watchdog exists: a run that never starts writes nothing
to any of the first three channels and posts nothing to Discord, because no process ran to do
it. Only something outside the run can notice, and that something is
[the watchdog](schedule.md#the-watchdog) reading the status file's mtime.

---

## The run log

`sync-from-drive.sh` opens with `exec >>"$LOG" 2>&1`, redirecting stdout and stderr of the
script and every process it spawns into `~/Library/Logs/mnfc-website-sync.log`. Both launchd
jobs also point `StandardOutPath` and `StandardErrorPath` at the same file, which catches
anything written before that `exec` line — a shell syntax error or a missing interpreter that
would otherwise vanish.

```bash
tail -f ~/Library/Logs/mnfc-website-sync.log
grep -n '^Sync started' ~/Library/Logs/mnfc-website-sync.log | tail -5
```

Each run opens with a `═` divider and `Sync started: <date>`; watchdog lines are prefixed
`WATCHDOG:`. The divider is what makes a single run findable in a file with no rotation.

**The log is a record, not a notification.** It is complete — the agent's full narration is in
it, which is where an error message actually lives — but nothing about it reaches a human, and
nobody opens a log file to confirm that nothing went wrong. Every other channel on this page
exists because this one requires you to already suspect a problem. The full marker-by-marker
reading is in [the log marker reference](sync-run.md#log-marker-reference).

---

## The status file

```bash
record() {
  printf '%s\t%s\t%s\n' "$1" "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$2" > "$STATUS_FILE"
}
```

One tab-separated line written to `~/Library/Logs/mnfc-website-sync.status`, truncating the
file each time so it always holds exactly the last outcome:

| Field | Value |
| --- | --- |
| 1 — state | `OK` or `FAIL` |
| 2 — timestamp | `%Y-%m-%d %H:%M:%S %Z`, e.g. `2026-08-19 08:13:04 CDT` |
| 3 — detail | the reason: `no changes`, `committed <sha>`, `uncommitted local changes`, `claude exited 1`, … |

`check-sync-ran.sh` reads it with `cut -f1`, `cut -f2` and `cut -f3`, and reads the file's own
mtime with `stat -f %m`. `install-schedule.sh status` prints it verbatim, or `(none yet)`.

```bash
cat ~/Library/Logs/mnfc-website-sync.status
```

**The mtime is as much of the signal as the contents.** The state field answers *did the last
run succeed?*; the mtime answers *was there a last run?* — the question no channel written
by the run itself can answer, because a run that does not happen writes nothing. That is why
the watchdog compares mtime against `STALE_DAYS=4` rather than reading the log.

!!! note "The dirty-tree skip records `FAIL` but exits `0`"
    The exit code answers *did the script misbehave?* — it did not, it declined on purpose.
    The status file answers *is the site tracking Drive?* — it is not. Recording `FAIL` is
    what keeps the watchdog complaining about a skip that repeats on every following run.

---

## macOS notifications

```bash
notify() {
  local msg="${1//\"/}"
  /usr/bin/osascript -e "display notification \"$msg\" with title \"Website sync\"" >/dev/null 2>&1 || true
}
```

A banner titled `Website sync`. `${1//\"/}` strips double quotes from the message before
it is interpolated into the AppleScript string — an unescaped `"` in a path or a commit
subject would terminate the string and turn the rest of the message into syntax. The trailing
`|| true` means a failed notification can never take down the run: the notifier is
diagnostics, not a dependency.

Both scripts define their own copy of this function. The sync calls it on failure paths only;
the watchdog calls it for a missing status file, a `FAIL` state, or a stale mtime.

### Why success is silent

**Only failure paths call `notify`.** A successful sync — including the common
`RESULT: no changes committed.` — raises nothing at all.

**What breaks otherwise:** the sync fires twice a week, and the overwhelmingly common outcome
is `no changes`, because Drive usually has not moved since the last run. A banner on every
run means roughly a hundred "nothing happened" popups a year against a handful of real
failures, and the popups are indistinguishable at a glance — same title, same shape, same
corner of the screen. The habit that builds is dismissing the banner without reading it, and
the one that says `Committed but could not push. The site is NOT updated` gets dismissed the
same way. Silence on success is what keeps a banner's mere appearance informative: if one
shows up, something is wrong.

Discord carries the successful runs instead, in a channel you read when you choose to rather
than a banner that interrupts.

---

## Discord

`scripts/notify-discord.sh` posts **one embed per sync run** to a Discord incoming webhook.

```bash
notify-discord.sh <state> <headline> [detail]
notify-discord.sh --test
```

| Argument | Meaning |
| --- | --- |
| `state` | `ok`, `changed` or `fail` — selects the title, colour and whether to ping |
| `headline` | one short line, the ultra-concise summary |
| `detail` | optional second line: commit hash and file list, or error text |

### The three states

| State | Embed title | Colour | @mention | Posted when |
| --- | --- | --- | --- | --- |
| `ok` | `✓ Site checked` | `0x95A5A6` grey | yes | the run finished and made no commit |
| `changed` | `↻ Site updated` | `0x7A0019` maroon | yes | a commit was made and pushed |
| `fail` | `✗ Sync failed` | `0xE74C3C` red | yes | any failure path |

The maroon is `#7a0019`, the same `--maroon` custom property the site's own `style.css`
defines. A `changed` embed also appends `[View the site](https://minnesota-nanofabrication-club.github.io/club_website/)`
to its description; `ok` and `fail` do not.

An unrecognised state falls back to the `ok` style. The webhook posts under the username
`Website Sync`, and the description is truncated to 4000 characters before sending.

### Every state pings

**All three states carry the @mention** when `discord-mention` is configured. The mention is
attached when the state's `ping` flag is true *and* a mention is set:

```python
if ping and mention:
    payload["content"] = mention
```

`ok` posted silently at first, on the reasoning that a notification firing on a schedule
regardless of whether anything happened becomes one you stop reading — and that the failure
pings would lose their meaning along with it. That reasoning was wrong about what the owner
needed. The value of the quiet ping is **confirmation the job ran at all**: an absent ping is
itself the signal, and it only reads as a signal if a present one is guaranteed. Under the
old policy a silent week was ambiguous — Drive genuinely unchanged, or the job never fired?

The rate is what makes this safe. Two runs a week is low enough that the pings stay legible;
at a daily or hourly cadence the original objection would hold and the policy should go back.

Changed at Leo's request, 2026-08-20.

### Where the concise summary comes from

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

**The headline of a `changed` post is the commit subject, not anything parsed out of the
agent's prose.** `git log -1 --format=%s` on the new `HEAD` gives one line, written by the
agent that actually knew what it changed, with `Site updated` as the fallback if the lookup
fails. The detail line is the short hash — `${AFTER:0:7}` — and the changed file list from
`git diff-tree --no-commit-id --name-only -r`.

**What breaks otherwise:** the agent's output is free prose ending in a one-paragraph summary,
and the script never asked it for a parseable format. Extracting a headline from that means
grepping for a heading, a first sentence, or a marker line the agent never promised to keep —
so the first run that phrases its summary differently posts a fragment of a sentence, or the
whole paragraph, or nothing. Git already holds a one-line, agent-authored, machine-readable
statement of what changed. Asking git costs one command and cannot drift.

### `PIPESTATUS[0]`, not `$?`

The agent's output is now piped through `tee` so a copy lands in `AGENT_OUT` — a `mktemp -t
mnfc-sync` file removed by `trap 'rm -f "$AGENT_OUT"' EXIT`, including on the early-exit guard
paths. The `fail` embed for a crashed agent sends `tail -c 400 "$AGENT_OUT"` as its detail, so
the error text reaches Discord instead of only the log.

```bash
"$CLAUDE" -p "…" --allowedTools "…" | tee "$AGENT_OUT"

STATUS=${PIPESTATUS[0]}
```

!!! danger "`$?` after the pipe is `tee`'s status, and `tee` always succeeds"
    Adding the pipe changed what `$?` means. `$?` is the exit status of the *last* command in
    the pipeline, which is `tee` — and `tee` returns `0` whether the agent exited `0`, `1` or
    `137`. Reading `$?` here would send every branch to `BEFORE = AFTER`, log
    `RESULT: no changes committed.`, record `OK  no changes`, and post a grey `✓ Site checked`
    embed for a run that crashed. Every crash would report as a clean quiet run, on both
    channels at once, and the watchdog would agree because a run did happen and did record
    `OK`. `${PIPESTATUS[0]}` is the first element of the pipeline's status array — the agent's
    own exit code.

### Missing config skips silently

```bash
if [ ! -f "$WEBHOOK_FILE" ]; then
  echo "Discord: not configured (no $WEBHOOK_FILE); skipping notification."
  exit 0
fi
```

**An unconfigured or empty webhook file prints one line to the log and exits `0`.** The same
holds for a webhook file that exists but contains only whitespace:
`Discord: webhook file is empty; skipping notification.`

**What breaks otherwise:** the caller is a sync whose actual job is publishing the club's
site. If a missing `~/.config/mnfc-sync/discord-webhook` were an error, a fresh checkout on a
new laptop — or the machine migration described in
[Single point of failure](schedule.md#single-point-of-failure) — would turn every run into a
failure over an announcement channel nobody had set up yet, and the site would stop tracking
Drive because Discord was not configured. Publishing the site matters; announcing it does not.
The sync side is belt-and-braces about the same thing: `discord()` returns early unless the
script is executable, and appends `|| true` so a non-zero exit from a real send failure cannot
propagate.

```bash
discord() {
  [ -x "$DISCORD" ] || return 0
  "$DISCORD" "$1" "$2" "${3:-}" || true
}
```

### The payload is built in Python, not in the shell

The script exports `STATE`, `HEADLINE`, `DETAIL`, `MENTION`, `WEBHOOK` and `SITE_URL` into a
`python3` heredoc which builds the JSON with `json.dumps` and POSTs it with
`urllib.request`, `Content-Type: application/json`, `User-Agent: mnfc-sync/1.0` and a
15-second timeout.

**What breaks otherwise:** the headline is a git commit subject, which is arbitrary text.
A subject containing `"` — `Fix the "last updated" footer date` — interpolated into a
hand-assembled JSON string closes the string early and Discord rejects the body as malformed;
a backslash or a newline does the same in different ways. `json.dumps` escapes all three by
construction, so no commit message can produce an unsendable payload.

Outcomes it prints: `Discord: posted (<status>).` on success, `Discord: HTTP <code> -- <body>` and
exit `1` on an HTTP error, `Discord: send failed -- <error>` and exit `1` on anything else.
All three land in the run log.

---

## Setting up Discord

Do this once, on the Mac that runs the sync.

1. **Create the webhook in Discord.** Open **Server Settings → Integrations → Webhooks → New
   Webhook**, pick the channel the posts should land in, then **Copy Webhook URL**. You need
   Manage Webhooks permission on that server.

2. **Write the URL to the config file** — outside the repo, readable only by you:

   ```bash
   mkdir -p ~/.config/mnfc-sync
   echo 'https://discord.com/api/webhooks/...' > ~/.config/mnfc-sync/discord-webhook
   chmod 600 ~/.config/mnfc-sync/discord-webhook
   ```

3. **Optionally add a mention**, to get an actual ping on every run rather than a silent
   post:

   ```bash
   echo '<@YOUR_DISCORD_USER_ID>' > ~/.config/mnfc-sync/discord-mention
   ```

   The file's contents are used verbatim as the message body, so a role mention
   (`<@&ROLE_ID>`) works the same way. Without this file every state still posts — the
   messages just do not ping. Note that `@everyone` also works here and notifies every
   member of the channel, not just you.

4. **Send a test post:**

   ```bash
   ./scripts/notify-discord.sh --test
   ```

   That sends the `ok` style with the headline `Test message`. A `Discord: posted (<status>).`
   line and a grey `✓ Site checked` embed in the channel mean the webhook is wired up.

!!! danger "The webhook URL is a secret and must never enter the repo"
    Anyone holding the URL can post to that channel as this integration, with no
    authentication beyond the URL itself — there is no token to scope and no per-message
    check. Committing it publishes it to a public GitHub repository and into every clone and
    every fork, and it stays in the history after it is deleted from the working tree, so the
    only real remediation is deleting the webhook in Discord and issuing a new one. Keeping it
    in `~/.config/mnfc-sync/` at mode `600` keeps it off GitHub entirely and out of reach of
    other accounts on the machine. This is also why the config lives outside the repo rather
    than in a gitignored file inside it: a gitignored secret is one `git add -f` or one
    rewritten `.gitignore` away from being committed.

### Why a webhook and not a bot

**The notifier only ever sends. It never listens, so nothing has to stay running.**

**What breaks otherwise:** a Discord bot is a long-lived process holding a gateway connection.
It has to be started, kept alive across reboots and sleep, and reconnected when the gateway
drops it — and when any of that fails, the bot's symptom is that it stops posting. That is
byte-for-byte the same observable as a healthy sync with nothing to report: no message in the
channel. So the monitoring channel would acquire its own silent failure mode, and the thing
these notifications exist to detect *is* silence. You would then need something watching the
bot, which is where the watchdog problem starts over. A webhook is a URL: `sync-from-drive.sh`
POSTs to it at the end of a run and the process exits. There is nothing to keep alive, so
there is nothing whose death looks like a quiet run.

---

## What none of these channels covers

| Gap | Consequence |
| --- | --- |
| A run that never starts | Writes to no channel at all. Only the watchdog's mtime check notices — see [The Schedule](schedule.md#the-watchdog). |
| Watchdog alerts do not reach Discord | `check-sync-ran.sh` calls `notify` only. `No sync in N days` is a macOS banner on that Mac and nowhere else. |
| macOS banners are fire-and-forget | `notify` ends in `\|\| true`. An alert raised during Do Not Disturb, or on a locked or sleeping machine, is simply gone and nothing retries it. |
| A failed Discord post is not retried | The `\|\| true` in `discord()` swallows it. The `Discord: HTTP <code>` line in the log is the only trace. |
| Drive auth expiry can present as `ok` | A run that reads nothing finds nothing to change, records `OK  no changes`, and posts a grey `✓ Site checked`. See [Drive auth expired](troubleshooting.md#drive-auth-expired). |
| `notify-discord.sh` not executable | `discord()` returns early and posts nothing, silently. `install-schedule.sh` runs `chmod +x` on the sync and watchdog scripts only. |

The status file is the durable record behind all of them: banners vanish, Discord posts depend
on a configured webhook, but `~/Library/Logs/mnfc-website-sync.status` always holds the last
outcome and its timestamp.

---

[← The Schedule](schedule.md){ .md-button } [Troubleshooting →](troubleshooting.md){ .md-button .md-button--primary }
