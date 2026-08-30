# Notifications

Every way the sync tells you what happened: the Actions run log, the job summary, Discord, and
the failure issue. What each channel carries, when each one fires, and how to wire Discord up.
What produces these outcomes in the first place is in
[Anatomy of a Sync Run](sync-run.md), and what to do about the amber `proposed` post is in
[Reviewing a Proposed Update](reviewing-changes.md). **The job is unattended and it publishes
nothing on its own, so a post nobody reads is a change that never reaches the site.**

---

## Contents

- [The four channels](#the-four-channels)
- [What fires on each outcome](#what-fires-on-each-outcome)
- [The run log](#the-run-log)
- [The job summary](#the-job-summary)
- [Discord](#discord)
- [Setting up Discord](#setting-up-discord)
- [The failure issue](#the-failure-issue)
- [What none of these channels covers](#what-none-of-these-channels-covers)

---

## The four channels

| Channel | Where | Fires on | Persistent | Reaches you without looking |
| --- | --- | --- | --- | --- |
| Run log | **Actions → Sync from Drive → the run** | every line of every run | yes, until GitHub's retention expires | no |
| Job summary | the top of the same run page | every run that got past the config check | yes, with the run | no |
| Discord | `scripts/notify-discord.sh` → incoming webhook | every outcome including a quiet one | yes, in the channel's history | yes, anywhere |
| Failure issue | a GitHub issue labelled `drive-sync-failure` | failures only; closes itself on the next success | yes, and it is *stateful* | via GitHub's own notifications |

The four are deliberately not redundant. The log is complete and unreadable; the job summary
is the one-screen version of the same run; Discord is the only channel that reaches a phone;
and the failure issue is the only one that *persists a condition* rather than reporting an
event — it stays open until the problem is fixed, so it cannot be scrolled past.

!!! note "Everything here lives on GitHub or in Discord"
    There is no log file, status file, or desktop notification on anyone's machine. The
    previous design wrote `~/Library/Logs/mnfc-website-sync.log` and `.status` and raised
    macOS banners from a `launchd` job; all of that was deleted with the local machinery in
    commit `a0a76d9`. If a runbook tells you to `tail` a log or run a `status` subcommand,
    it predates that.

---

## What fires on each outcome

| Outcome | Log | Job summary | Discord | Failure issue |
| --- | --- | --- | --- | --- |
| Secrets missing | `::notice::Missing secrets (…)` + setup summary | — (the step is skipped) | **none** | none — the run is green |
| Drive mirror failed | the `fetch_drive.py` error | `status: failure` | `fail` | opened or commented |
| Agent failed or hit `--max-turns` | the action's own error | `status: failure` | `fail` | opened or commented |
| Guard fired | `::error::the agent modified files it must never touch:` | `status: failure` | `fail` | opened or commented |
| No changes | `No commit made — the site already matches Drive.` | `changed: false` | `ok` — `No changes — the site already matches Drive.` | **closed** if one was open |
| Proposal opened | `Opened: <url>` | `changed: true`, commit subject, files | `proposed` — the commit subject plus the PR URL | closed if one was open |
| Proposal updated | `Updated the open proposal: <url>` | same shape | `proposed` — same shape | closed if one was open |
| Dry run with changes | `::notice::dry run …` plus the diff | `published to main: no` | `ok` — `Dry run — changes were computed but not published.` | closed if one was open |
| **No run at all** | *(nothing)* | *(nothing)* | **none** | none |

Two rows deserve care. **A `proposed` post does not mean the site changed** — it means a pull
request is waiting for a human, and nothing will say so a second time; see
[Reviewing a Proposed Update](reviewing-changes.md). And the last row is the gap this design
has no answer for: a run that never starts writes nothing anywhere, because no process ran to
do it.

!!! warning "No channel reports an unmerged proposal a second time"
    A proposal is announced once, on the run that made it. Nothing re-pings and nothing
    escalates. A later run either force-pushes a newer proposal over it — reusing the same PR
    and posting `proposed` again for the *new* diff — or, if Drive now matches the site, posts
    a quiet `ok` and leaves your proposal open and untouched. The single amber ping is the
    whole notice you get.

---

## The run log

Everything both the workflow and the agent print goes to the Actions log for that run. It is
reachable from the Discord post's run URL, from the failure issue, or directly:

```bash
gh run list  --repo Minnesota-Nanofabrication-Club/club_website --workflow "Sync from Drive"
gh run view  --repo Minnesota-Nanofabrication-Club/club_website <run-id> --log
gh run watch --repo Minnesota-Nanofabrication-Club/club_website
```

The workflow uses GitHub's own annotation markers, so the important lines are surfaced without
reading the whole log: `::error::` for the conditions that fail the run, `::warning::` for
discarded agent leftovers, `::notice::` for a missing-secrets skip or a dry run, and
`::group::` around the Drive pull and the committed diff.

**The log is a record, not a notification.** It is complete — the agent's full narration is in
it, which is where an error message actually lives — but nothing about it reaches a human, and
nobody opens a run page to confirm that nothing went wrong. Every other channel on this page
exists because this one requires you to already suspect a problem. The marker-by-marker
reading is in [the log and marker reference](sync-run.md#log-marker-reference).

!!! danger "The agent's narration is not safe to forward"
    The log holds whatever the agent read from the Drive mirror, which includes documents with
    BOM costs, vendor pricing and sponsorship correspondence. The Actions log is visible to
    anyone who can see the repository. Do not paste the tail of a failed run into Discord, an
    issue, or a screenshot — that is precisely why the `fail` embed carries only a run URL.

---

## The job summary

Written with `if: always()`, so it exists for failed runs too:

```
## Sync from Drive

* status: success
* changed: true
* published to main: no
* commit: Add the probe station subpage from Drive
* files: `index.html probe-station.html sitemap.xml`
* site: https://minnesota-nanofabrication-club.github.io/club_website/
```

`published to main` is always `no`, and it is printed anyway. **It is the line that states the
design.** Someone reading a run page for the first time should not have to infer from the
absence of a step that the site was not touched; a run that changed something and published
nothing is exactly the state that gets misread as "done".

---

## Discord

`scripts/notify-discord.sh` posts **one embed per run** to a Discord incoming webhook.

```bash
notify-discord.sh <state> <headline> [detail]
notify-discord.sh --test
```

| Argument | Meaning |
| --- | --- |
| `state` | `ok`, `proposed`, `changed` or `fail` — selects the title, colour and whether to ping |
| `headline` | one short line, the ultra-concise summary |
| `detail` | optional second line: the pull request URL, or the run URL on a failure |

### The four states { #the-four-states }

| State | Embed title | Colour | @mention | Posted when |
| --- | --- | --- | --- | --- |
| `ok` | `✓ Site checked` | `0x95A5A6` grey | yes | the run finished and proposed nothing, or a dry run |
| `proposed` | `📋 Update proposed — review` | `0xE0A100` amber | yes | a commit was pushed to `sync/drive` and a pull request is open |
| `changed` | `↻ Site updated` | `0x7A0019` maroon | yes | **nothing in the sync sends this** — see below |
| `fail` | `✗ Sync failed` | `0xE74C3C` red | yes | any failed job |

The amber sits between grey and red on purpose: a proposal is neither a non-event nor a fault,
it is an item of work. The maroon is `#7a0019`, the same `--maroon` custom property the site's
own `style.css` defines.

!!! note "`changed` is the published-state style, and nothing emits it"
    `notify-discord.sh` still defines `changed`, and it is the only state whose description
    gets `[View the site](https://minnesota-nanofabrication-club.github.io/club_website/)`
    appended — a link that only makes sense once something is actually live. No branch of the
    workflow calls it, because the sync stops at proposing and a human merge is what publishes.
    It stays documented here so that an old `↻ Site updated` post in the channel's history is
    recognisable as one from before the switch to pull requests.

An unrecognised state falls back to the `ok` style. The webhook posts under the username
`Website Sync`, and the description is truncated to 4000 characters before sending.

### Every state pings

**All four states carry the @mention** when a mention is configured. The mention is attached
when the state's `ping` flag is true *and* a mention is set:

```python
if ping and mention:
    payload["content"] = mention
```

`ok` posted silently at first, on the reasoning that a notification firing on a schedule
regardless of whether anything happened becomes one you stop reading — and that the failure
pings would lose their meaning along with it. That reasoning was wrong about what the owner
needed. The value of the quiet ping is **confirmation the job ran at all**: an absent ping is
itself the signal, and it only reads as a signal if a present one is guaranteed. Under the old
policy a silent week was ambiguous — Drive genuinely unchanged, or the job never fired?

That question is now the *only* thing standing in for a watchdog, which makes the guaranteed
ping load-bearing rather than merely nice. The rate is what keeps it safe: two runs a week is
low enough that the pings stay legible. At a daily or hourly cadence the original objection
would hold and the policy should go back.

Changed at Leo's request, 2026-08-20.

### Where the concise summary comes from

**The headline of a `proposed` post is the commit subject, not anything parsed out of the
agent's prose.** The guard step captures it once:

```bash
echo "subject=$(git log -1 --format=%s "$AFTER")"
echo "files=$(git diff-tree --no-commit-id --name-only -r "$AFTER" | tr '\n' ' ')"
```

That one line was written by the agent that actually knew what it changed, and the same string
becomes the pull request's title — so the Discord post and the PR say the same thing by
construction.

**What breaks otherwise:** the agent's output is free prose ending in a one-paragraph summary,
and nothing ever asked it for a parseable format. Extracting a headline from that means
grepping for a heading, a first sentence, or a marker line the agent never promised to keep —
so the first run that phrases its summary differently posts a fragment of a sentence, or the
whole paragraph, or nothing. Git already holds a one-line, agent-authored, machine-readable
statement of what changed. Asking git costs one command and cannot drift.

### Missing config skips silently

```bash
if [ ! -f "$WEBHOOK_FILE" ]; then
  echo "Discord: not configured (no $WEBHOOK_FILE); skipping notification."
  exit 0
fi
```

**An unconfigured or empty webhook file prints one line and exits `0`.** In the workflow the
question rarely arises — the two Discord steps are skipped entirely when the
`DISCORD_WEBHOOK_URL` secret is absent — but the script's own tolerance is what makes it safe
to run by hand from a fresh clone.

**What breaks otherwise:** the caller's actual job is proposing updates to the club's site. If
a missing webhook were an error, a repository without the secret set would report a failed
sync over an announcement channel nobody had configured yet. Publishing the site matters;
announcing it does not.

### The payload is built in Python, not in the shell

The script exports `STATE`, `HEADLINE`, `DETAIL`, `MENTION`, `WEBHOOK` and `SITE_URL` into a
`python3` heredoc which builds the JSON with `json.dumps` and POSTs it with `urllib.request`,
`Content-Type: application/json`, `User-Agent: mnfc-sync/1.0` and a 15-second timeout.

**What breaks otherwise:** the headline is a git commit subject, which is arbitrary text. A
subject containing `"` — `Fix the "last updated" footer date` — interpolated into a
hand-assembled JSON string closes the string early and Discord rejects the body as malformed;
a backslash or a newline does the same in different ways. `json.dumps` escapes all three by
construction, so no commit message can produce an unsendable payload.

Outcomes it prints: `Discord: posted (<status>).` on success, `Discord: HTTP <code> -- <body>`
and exit `1` on an HTTP error, `Discord: send failed -- <error>` and exit `1` on anything else.
All three land in the run log.

---

## Setting up Discord

Do this once, as repository secrets. The workflow copies them onto the runner for
`notify-discord.sh`; nothing persists between runs.

1. **Create the webhook in Discord.** **Server Settings → Integrations → Webhooks → New
   Webhook**, pick the channel the posts should land in, then **Copy Webhook URL**. You need
   Manage Webhooks permission on that server.

2. **Set it as a secret:**

   ```bash
   gh secret set DISCORD_WEBHOOK_URL \
     --repo Minnesota-Nanofabrication-Club/club_website
   ```

3. **Optionally add a mention**, to get an actual ping rather than a silent post:

   ```bash
   gh secret set DISCORD_MENTION \
     --repo Minnesota-Nanofabrication-Club/club_website     # e.g. <@YOUR_DISCORD_USER_ID>
   ```

   The value is used verbatim as the message body, so a role mention (`<@&ROLE_ID>`) works the
   same way. Without it every state still posts — the messages just do not ping. Note that
   `@everyone` also works here and notifies every member of the channel, not just you.

4. **Test it.** Trigger a run — **Actions → Sync from Drive → Run workflow**, dry run ticked —
   and watch for the embed. To test the webhook itself without spending an agent run, write it
   to your own machine and call the script directly:

   ```bash
   mkdir -p ~/.config/mnfc-sync
   printf '%s' 'https://discord.com/api/webhooks/...' > ~/.config/mnfc-sync/discord-webhook
   chmod 600 ~/.config/mnfc-sync/discord-webhook
   ./scripts/notify-discord.sh --test
   ```

   That sends the `ok` style with the headline `Test message`. A `Discord: posted (<status>).`
   line and a grey `✓ Site checked` embed in the channel mean the webhook is live.

!!! danger "The webhook URL is a secret and must never enter the repo"
    Anyone holding the URL can post to that channel as this integration, with no authentication
    beyond the URL itself — there is no token to scope and no per-message check. Committing it
    publishes it to a public GitHub repository and into every clone and every fork, and it
    stays in the history after it is deleted from the working tree, so the only real
    remediation is deleting the webhook in Discord and issuing a new one. As an Actions secret
    it is write-only after being set; as a local file for the `--test` path it belongs in
    `~/.config/mnfc-sync/` at mode `600`, never in a gitignored file inside the repo — a
    gitignored secret is one `git add -f` or one rewritten `.gitignore` away from being
    committed.

### Why a webhook and not a bot

**The notifier only ever sends. It never listens, so nothing has to stay running.**

**What breaks otherwise:** a Discord bot is a long-lived process holding a gateway connection.
It has to be started, kept alive across reboots, and reconnected when the gateway drops it —
and when any of that fails, the bot's symptom is that it stops posting. That is byte-for-byte
the same observable as a healthy sync with nothing to report: no message in the channel. So the
monitoring channel would acquire its own silent failure mode, and the thing these notifications
exist to detect *is* silence. A webhook is a URL: the workflow POSTs to it at the end of a run
and the runner is destroyed. There is nothing to keep alive, so there is nothing whose death
looks like a quiet run.

---

## The failure issue

```
Title:  Drive sync is failing
Label:  drive-sync-failure
```

Opened on the first failing run, **commented on by every subsequent failing run**, and
**closed with a `Recovered:` comment by the next successful run**. The body carries the failed
run's URL, the trigger that started it, and a pointer to this section of the docs.

| Repository state | What it means |
| --- | --- |
| One open `drive-sync-failure` issue | The sync is still broken. The site is as stale as the last good run left it |
| No open issue | The last run was fine |

**What breaks otherwise.** Every other channel reports an *event*: a red check, a red embed,
one line in a log. All three scroll away, and a failure that happened on a Thursday is invisible
by the following week. An issue is a condition — it stays open, it appears in the repo's issue
list, and closing it is something a successful run does rather than something a person has to
remember. That is the difference between "we were told once" and "we can see it is still
broken".

---

## What none of these channels covers

| Gap | Consequence |
| --- | --- |
| **A run that never starts** | Writes to no channel at all. There is no watchdog — the local one was deleted with the rest of the launchd machinery. **An absent Discord post on a Monday or Thursday is the whole signal**, which is why quiet runs ping |
| GitHub disabling the schedule | GitHub disables scheduled workflows in a repository with 60 days of no activity. A club repo that goes quiet over a summer break is a realistic way for this to stop, and it stops the same way: silently |
| A proposal nobody merges | Announced once and never again. Every channel recorded success, so nothing complains while the site stays unchanged. See [Doing nothing](reviewing-changes.md#doing-nothing) |
| A stale proposal after a quiet run | Nothing closes it. The PR stays open and mergeable even though the run that would have superseded it found nothing to say — see [Nothing closes a stale proposal](sync-run.md#nothing-closes-a-stale-proposal) |
| Whether the merge actually published | No channel watches the site. See [Deployment](deployment.md#when-a-push-does-not-appear) |
| A failed Discord post | Fails its own step, so the job goes red and the failure issue opens — but the proposal is already open and unaffected. The `Discord: HTTP <code>` line in the log is the diagnosis |

---

[← The Cloud Sync](cloud-sync.md){ .md-button } [Reviewing a Proposed Update →](reviewing-changes.md){ .md-button .md-button--primary }
