# Architecture Overview

The club website is a static site that proposes its own updates twice a week — Monday and
Thursday — from the club's Google Drive. This page traces one run end to end — Drive, the
scheduled job, the headless agent, the proposal branch, the pull request, a human merge, the
rebuild — and states the dependency rule that keeps the pieces from fighting each other.
**Drive is authoritative over the repo, and the repo is authoritative over the live site.
Nothing flows backwards, and nothing crosses the `main` boundary without a human merging it.**

---

## The pipeline

```mermaid
flowchart TD
    DRIVE["<b>GOOGLE DRIVE</b><br/>──────────────────────────<br/><b>Ultra Hardcore Chip Codesign</b><br/>1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP<br/>──────────────────────────<br/>Build the Fab/* · Engineering Structure<br/>Project and Goals · Constitution"]

    LAUNCHD["<b>LAUNCHD</b><br/>──────────────────────────<br/>com.mnfc.website-sync<br/>Weekday 1 + 4 · 08:13 · RunAtLoad false<br/>──────────────────────────<br/>one Mac · Leonard's laptop"]

    SCRIPT["<b>sync-from-drive.sh</b><br/>──────────────────────────<br/>dirty-tree guard → fetch → checkout main<br/>pull --ff-only · BEFORE=git rev-parse HEAD<br/>──────────────────────────<br/>log → mnfc-website-sync.log<br/>state → mnfc-website-sync.status"]

    WATCH["<b>check-sync-ran.sh</b><br/>──────────────────────────<br/>com.mnfc.website-sync-watchdog<br/>Weekday 1 + 4 · 14:13<br/>──────────────────────────<br/>reads .status · STALE_DAYS=4 · notifies"]

    AGENT["<b>HEADLESS CLAUDE CODE</b><br/>──────────────────────────<br/>claude -p with --allowedTools<br/>4 × mcp__claude_ai_Google_Drive__*<br/>Read · Edit · Write · Glob · Grep · Bash(git:*)<br/>──────────────────────────<br/>commit only · no push · no merge"]

    BRANCH["<b>BRANCH — sync/drive</b><br/>──────────────────────────<br/>git checkout -B, reset from main each run<br/>index.html · stepper.html · style.css<br/>──────────────────────────<br/>git push --force-with-lease"]

    PR["<b>PULL REQUEST</b><br/>──────────────────────────<br/>gh pr create --base main --head sync/drive<br/>at most one open at a time<br/>──────────────────────────<br/>quiet run ⇒ gh pr close (superseded)"]

    HUMAN["<b>HUMAN REVIEW</b><br/>──────────────────────────<br/>checks every claim against Drive<br/>roster · internal material · preserved links<br/>──────────────────────────<br/><b>the merge is the publish</b>"]

    MAIN["<b>REPO — main</b><br/>──────────────────────────<br/>what is published now<br/>──────────────────────────<br/>changes only by merge"]

    DISCORD["<b>notify-discord.sh</b><br/>──────────────────────────<br/>one embed per run<br/>ok · proposed · fail<br/>──────────────────────────<br/>webhook from ~/.config/mnfc-sync"]

    subgraph EXT ["outside this repo"]
        PAGES["<b>GITHUB PAGES</b><br/>──────────<br/>builds from main<br/>no build step · serves files as-is"]
        SITE["<b>LIVE SITE</b><br/>──────────<br/>minnesota-nanofabrication-club<br/>.github.io/club_website/"]
    end

    DRIVE -->|"read-only"| AGENT
    LAUNCHD -->|"Mon + Thu 08:13 local"| SCRIPT
    SCRIPT -->|"claude -p"| AGENT
    AGENT -->|"Edit · Write · commit"| BRANCH
    BRANCH -->|"force-push"| PR
    PR -->|"review"| HUMAN
    HUMAN -->|"merge"| MAIN
    MAIN -->|"Pages rebuilds"| PAGES
    PAGES -->|"~1 minute"| SITE
    MAIN -. "BEFORE — reset the branch onto it" .-> BRANCH
    AGENT -. "no changes ⇒ no commit" .-> SCRIPT
    SCRIPT -. "OK / FAIL + timestamp" .-> WATCH
    SCRIPT -. "every outcome · proposed carries the PR link" .-> DISCORD
    DISCORD -. "📋 review" .-> HUMAN

    style EXT stroke-dasharray:5 5,fill:transparent,stroke:#999,color:#999
    style DRIVE stroke-dasharray:5 5

    click DRIVE href "../data-contracts/"
    click LAUNCHD href "../../operations/schedule/"
    click SCRIPT href "../../operations/sync-run/"
    click AGENT href "../../operations/sync-run/"
    click BRANCH href "../../operations/sync-run/"
    click PR href "../../operations/reviewing-changes/"
    click HUMAN href "../../operations/reviewing-changes/"
    click WATCH href "../../operations/schedule/"
    click DISCORD href "../../operations/notifications/"
```

**Dependency rule:** each stage reads only from the stage above it. Drive never reads the
repo, and the repo never reads the site. The dashed edges carry no content — `main` as the
baseline the proposal branch is reset onto; the no-op, the agent reporting that nothing
changed and suppressing the commit; the run's own outcome, written to a status file the
watchdog reads later; the same outcome posted to Discord; and the Discord ping that is how a
reviewer learns there is anything to review. None of them can fail the run.

**The solid path stops at `HUMAN REVIEW` twice a week and waits.** The automated half of the
pipeline ends at an open pull request; the merge is a manual step with no timer behind it, so
a proposal nobody opens is a change that never ships. See
[Reviewing a Proposed Update](../operations/reviewing-changes.md).

---

## What runs, in order

A single run is twelve steps in `scripts/sync-from-drive.sh`, and every one of them appends to
the same log:

| # | Step | Failure behavior |
| --- | --- | --- |
| 1 | Write a `═` divider and `Sync started: <date>` to the log; install `trap cleanup EXIT` | — |
| 2 | `cd "$REPO"` | `FATAL: repo not found`, `record FAIL`, notify, exit 1 |
| 3 | Dirty-tree guard: `git diff --quiet` and `git diff --cached --quiet` | `SKIP: uncommitted local changes present; not syncing over them.`, prints `git status --short`, `record FAIL`, notify, `discord fail`, **exit 0** |
| 4 | `git fetch -q origin`, then `git checkout -q main` | fetch failure is advisory; `FATAL: could not check out main`, `record FAIL`, notify, `discord fail`, exit 1 |
| 5 | `git pull --ff-only origin main` | `FATAL: git pull failed`, `record FAIL`, notify, `discord fail`, exit 1 |
| 6 | `BEFORE=$(git rev-parse HEAD)` — what is published now | — |
| 7 | `git checkout -q -B sync/drive`, logging `Working on sync/drive (reset from main at <sha>).` | `FATAL: could not create branch sync/drive`, `record FAIL`, `discord fail`, exit 1 |
| 8 | `claude -p "<prompt>"` with a scoped `--allowedTools` list, piped through `tee "$AGENT_OUT"` | delegated to the agent |
| 9 | `STATUS=${PIPESTATUS[0]}`; discard any uncommitted agent edits with `git reset --hard`; `AFTER=$(git rev-parse HEAD)` | `WARNING: agent left uncommitted changes on sync/drive; discarding them.` |
| 10 | Result branch: `RESULT: claude exited $STATUS` / `RESULT: no changes proposed.` / `RESULT: proposed $BEFORE -> $AFTER on sync/drive` | every branch calls `record` and `discord` |
| 11 | On a proposal: `git push --force-with-lease`, then `gh pr create` or report the existing PR. On a quiet run: `gh pr close` any stale proposal | `ERROR: could not push sync/drive.`, `record FAIL`, notify, `discord fail`; a failed close logs `WARNING: could not close <url>` |
| 12 | `Sync finished: <date>`, then the `EXIT` trap removes the temp file and checks out `main` | — |

The script runs under `set -uo pipefail` — deliberately **not** `-e`. It does its own
checks at every step and needs the non-zero exits to reach its own logging branches rather
than killing the shell mid-run.

!!! danger "Step 9 reads `${PIPESTATUS[0]}`, not `$?`"
    The agent's output is piped through `tee` so a copy lands in `AGENT_OUT`. `$?` after a
    pipeline is the *last* command's status — `tee`'s — and `tee` exits `0` no matter how the
    agent exited. Reading `$?` would route every crashed run into the `BEFORE = AFTER` branch,
    logging `RESULT: no changes proposed.`, recording `OK  no changes`, posting a grey
    `✓ Site checked` embed — and **closing the open pull request as superseded**, discarding a
    proposal nobody had reviewed. Every failure would look like a clean quiet run on every
    channel at once.

!!! warning "Step 11 is where the run stops, and the site is still unchanged"
    Nothing after step 12 happens on a schedule. The pull request waits for a human, and the
    next run either force-pushes a newer proposal over it or closes it as superseded. Every
    channel reports `OK` throughout.

!!! warning "The dirty-tree guard exits 0, but still reports FAIL"
    Step 3 is a soft exit on purpose — a dirty tree means someone was editing the repo by
    hand, and the correct response is to leave that work alone rather than sync over it.
    But it is not a quiet outcome: the skip is **self-perpetuating**, because until the
    tree is committed or stashed every following run skips too and the site keeps drifting
    from Drive. So the branch writes `FAIL` to the status file, raises a notification and
    posts a `fail` embed to Discord even though the process exits 0.

---

## The scoped tool allowlist

Step 8 launches Claude Code headlessly with an explicit `--allowedTools` list — four
Google Drive tools plus a small local set:

| Tool | Why it is on the list |
| --- | --- |
| `mcp__claude_ai_Google_Drive__search_files` | enumerate the subfolders of `Build the Fab` |
| `mcp__claude_ai_Google_Drive__read_file_content` | read the docs `SYNC.md` names |
| `mcp__claude_ai_Google_Drive__get_file_metadata` | resolve folder and file identity |
| `mcp__claude_ai_Google_Drive__list_recent_files` | spot what moved since the last run |
| `Read`, `Edit`, `Write`, `Glob`, `Grep` | read and rewrite `index.html` / `stepper.html` |
| `Bash(git:*)` | `git add` and `git commit` on `sync/drive` — nothing else |

The Drive side is read-only by construction: no Drive write tool appears on the list, so
a confused run cannot edit the club's documents. The local side is narrowed to `git`, so
the agent cannot reach `launchctl`, the plist, or anything outside the repo — and `gh` is
absent, so the agent cannot open, comment on or merge a pull request even though the script
around it does. The prompt goes further than the allowlist can: it tells the agent to commit
and then explicitly **not** to push, merge or switch branches, and not to touch anything under
`docs/`. The prompt also restates the publishing rules and points at `CLAUDE.md` first and
`SYNC.md` second, so the rules survive even if the tool list is later widened.

---

## The dependency rule, stated as a rule

**Drive → proposal → `main` → site. Nothing flows backwards, and the third arrow is a
person.**

- **Drive is authoritative over the repo.** Project scope, status, timelines, roles and
  mission framing are decided in Drive documents; the HTML is a rendering of them.
- **`main` is authoritative over the live site.** Pages serves the files exactly as they
  are committed — no build step, no framework, no compile. There is no other place a
  change to the published page can come from.
- **Only a merge moves `main`.** The sync writes to `sync/drive` and stops. Nothing in the
  scheduled pipeline is capable of publishing on its own.
- **No arrow reverses.** The agent never writes to Drive, and nothing edits the
  deployed site outside a commit landing on `main`.

### What breaks if you hand-edit project copy in the HTML

**Hand-edits to project copy do not survive.** The agent does not diff your edit against
anything — it rewrites the affected section from the Drive documents each run, so at 08:13 on
the next Monday or Thursday a proposal appears that replaces your sentence with whatever Drive
says. The one thing that has changed is *when*: the revert now waits in a pull request instead
of landing on the live site, so a reviewer reading the diff can catch it. Nobody is notified
that a hand-edit is being undone, though, and the diff describes itself as a routine sync — so
in practice it is caught only by someone who already knows the sentence was hand-written.

This has been demonstrated, not assumed: on 2026-08-18 the Etcher entry was deleted from
`index.html` and committed (`0593a4a`), and the next sync restored it (`7dd018c`) without
being asked to. That test ran under the earlier design, where the restoration published
itself; under the current design the same sync produces a pull request restoring the entry.
The direction is unchanged — Drive wins over local content edits — only the gate in front of
it is new.

The split that matters:

| Change | Safe to make in the repo? |
| --- | --- |
| Project name, status, description, timeline rows | **No** — change the Drive doc instead |
| Team names and roles | **No** — change `Engineering Structure` |
| HTML structure, `style.css`, nav, layout | Yes — design is not Drive-sourced |
| The four deliberately non-Drive links and `jin00404@umn.edu` | Yes, and they must be **preserved** — see [Design Principles](design-principles.md) |

!!! tip "Run it early instead of editing the HTML"
    If Drive is already correct and the site is stale, do not patch the HTML — run
    `./scripts/sync-from-drive.sh` by hand, or ask Claude Code in this repo to
    "Sync the club website from Google Drive following SYNC.md." Both take the same path
    the scheduled job takes, so the result is what the next run would have produced anyway.

---

## How a run reports itself

The job is unattended, so the log alone is not a reporting channel — nobody opens a log
file to confirm that nothing went wrong, and a proposal nobody hears about is never merged.
Three side channels close that gap, and all of them are documented in full in
[Notifications](../operations/notifications.md).

**The status file.** `record <state> <detail>` writes one tab-separated line —
state, timestamp, detail — to `~/Library/Logs/mnfc-website-sync.status`, overwriting the
previous run. Every branch calls it: `OK "no changes"`,
`OK "proposed $AFTER (awaiting review)"`, or `FAIL` with the reason.

**The notification.** `notify` shells out to `osascript` for a macOS notification titled
`Website sync`. Every failure path calls it, and so does a successful proposal
(`Site update proposed and awaiting your review.`). A quiet run stays silent deliberately — a
"nothing changed" popup twice a week trains the reader to dismiss the notification they
actually need to read.

**Discord.** `scripts/notify-discord.sh` posts one embed per run to an incoming webhook —
grey `✓ Site checked` for a quiet run, amber `📋 Update proposed — review` carrying the pull
request URL, red `✗ Sync failed` for any failure. The maroon `↻ Site updated` style still
exists but nothing in the sync sends it, because the sync no longer publishes. Every state
carries an @mention when `discord-mention` is configured, and the headline is the commit
subject from `git log -1 --format=%s`, not text parsed out of the agent's prose.
The webhook URL is a secret and lives in `~/.config/mnfc-sync/discord-webhook`, never in the
repo; when it is absent the script prints one line and exits `0`, so the sync never fails
because Discord is unconfigured.

!!! warning "No channel tracks whether the proposal was merged"
    All four report on the *run*. None of them observes the pull request afterwards, so a
    proposal that sits open for a month leaves every channel reporting healthy runs the whole
    time. The amber ping is the only prompt anyone gets, and it is sent once.

**The watchdog.** `scripts/check-sync-ran.sh` runs as a second launchd job,
`com.mnfc.website-sync-watchdog`, on Mondays and Thursdays at 14:13 — six hours after each
sync is due. It
exists because the sync cannot report the one failure that matters most: **not running at
all.** A job that never fires writes no log line, sets no exit code, posts nothing to Discord,
and looks exactly like a quiet run. The watchdog reads the status file instead of the log and
notifies when:

| Condition | Notification |
| --- | --- |
| No status file exists | No sync has ever recorded a run — the schedule may not be installed |
| `STATE` is `FAIL` | Last sync failed, with the recorded detail |
| Status file older than `STALE_DAYS=4` | No sync in N days — was the Mac off? |

It first checks `launchctl list` for a currently-running sync and exits early if it finds
one, because both jobs fire together when the Mac wakes from a long sleep and the watchdog
would otherwise race the run it is meant to be checking.

---

## Moving parts and where each lives

| Part | Identifier / location |
| --- | --- |
| Drive root folder | **Ultra Hardcore Chip Codesign**, id `1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP` |
| Sync script | `scripts/sync-from-drive.sh` |
| Proposal branch | `sync/drive` — reset from `main` with `git checkout -B` on every run |
| GitHub CLI | `/opt/homebrew/bin/gh` — opens, finds and closes the pull request |
| Schedule installer | `scripts/install-schedule.sh` (`install` / `uninstall` / `status`) — installs both jobs |
| Watchdog script | `scripts/check-sync-ran.sh` |
| Discord notifier | `scripts/notify-discord.sh`; webhook in `~/.config/mnfc-sync/discord-webhook`, optional mention in `~/.config/mnfc-sync/discord-mention` |
| launchd label — sync | `com.mnfc.website-sync`, Weekday `1` **and** `4`, Hour `8`, Minute `13` |
| launchd label — watchdog | `com.mnfc.website-sync-watchdog`, Weekday `1` **and** `4`, Hour `14`, Minute `13` |
| launchd plists | `~/Library/LaunchAgents/com.mnfc.website-sync.plist` and `…-watchdog.plist`; `RunAtLoad` false on both |
| Log (stdout and stderr, both jobs) | `~/Library/Logs/mnfc-website-sync.log` |
| Status file | `~/Library/Logs/mnfc-website-sync.status` |
| `claude` binary | `/Users/leonardjin/.local/bin/claude` |
| Repo checkout | `/Users/leonardjin/Dev/ultra-hardcore-chip-codesign/club_website` |
| Published site | `https://minnesota-nanofabrication-club.github.io/club_website/` |
| Rules the agent reads | `CLAUDE.md` first, then `SYNC.md` |

!!! warning "Every one of those paths is absolute and hardcoded"
    `REPO`, `CLAUDE`, `GH` and `SCRIPT` are literal absolute paths in the two scripts, and the
    plists embed the script paths. The sync therefore runs from exactly one machine — if
    that Mac is replaced, wiped, or its user account renamed, both jobs stop together, and
    the watchdog that would have reported the silence is the thing that stopped. Nothing
    off that machine observes the site at all. Re-pointing the paths and re-running
    `./scripts/install-schedule.sh` is the whole recovery, but nothing triggers it
    automatically.

---

## Where the site can fail to update

Several states look the same from outside — a site that has not changed — and only the log,
the status file and the pull request list tell them apart:

| Log line | Status file | What it means |
| --- | --- | --- |
| `Opened PR: <url>` / `Updated existing PR: <url>` | `OK  proposed <sha> (awaiting review)` | **The run worked and the site is still unchanged.** A pull request is waiting for a human to merge it — the single most likely reason a site is stale |
| `RESULT: no changes proposed.` | `OK  no changes` | **Success.** Drive matched the site; rule 7 says make no commit |
| `SKIP: uncommitted local changes present…` | `FAIL  uncommitted local changes` | The tree was dirty; the job deliberately did nothing, and will skip again on every following run until it is cleaned up |
| `RESULT: claude exited $STATUS` | `FAIL  claude exited $STATUS` | The agent failed; nothing was proposed |
| `ERROR: could not push sync/drive.` | `FAIL  branch push failed` | The commit never left the machine, so no pull request exists. The next run re-proposes from scratch |
| *(no new entry at all)* | *unchanged, and ageing* | The Mac was off or asleep through the slot, or launchd is not loaded — this is the case the watchdog exists to catch |

The first row is the one that is new and the one that catches people out: every automated
channel says the run succeeded, and every one of them is telling the truth. Publishing was
never the run's job. Check
[the open pull request](../operations/reviewing-changes.md) before debugging anything else.

An asleep Mac is not a failure: launchd runs a missed calendar job when the machine next
wakes. A machine that was off through a whole slot simply skips that run, and the following
run — at most four days later — proposes every accumulated change at once, because the agent
diffs Drive against the current HTML rather than replaying a queue.

!!! note "Verification history"
    The full launchd-triggered path was confirmed on 2026-08-19: `launchctl kickstart`
    fired the job, the Drive connector authenticated under launchd's minimal environment,
    and the run correctly made no commit because Drive matched the site. SSH push was
    separately confirmed with `env -i` plus `git push --dry-run`, proving it does not
    depend on a shell-provided `ssh-agent`. That verification predates the switch to pull
    requests, and it covers the parts that did not change: the schedule, the connector, and
    push access from `launchd`'s environment.

---

## Why local rather than a cloud routine

A scheduled cloud routine was the first design, and it does not work. Cloud routines get a
**read-only** GitHub token on this repo, so `git push` and the GitHub API both return
`403`; granting write access requires a Claude Team/Enterprise plan. On the laptop, git
already has push access over SSH, so the identical loop closes at no extra cost. The move to
pull requests does not change that: pushing `sync/drive` and calling `gh pr create` both need
write access to the repo, so a read-only token cannot even propose.

The cloud routine still exists but is **disabled**. Do not re-enable it without fixing the
permission first — a re-enabled routine would run the sync, edit the HTML, and then fail at
the push, leaving the run's work stranded in a checkout nobody looks at.

The tradeoff is stated above: the job now depends on one specific Mac being on.

---

## Read next

| Page | Covers |
| --- | --- |
| [**Design Principles**](design-principles.md) | The non-negotiable rules — never invent content, the roster rule, what is never published |
| [**Data Contracts**](../data-contracts.md) | Which Drive folder feeds which page section, and the HTML entry shapes |
| [**Schedule**](../operations/schedule.md) | Installing, checking and removing the two launchd jobs |
| [**Sync Run**](../operations/sync-run.md) | Reading the log, and what to do about a failed run |
| [**Reviewing a Proposed Update**](../operations/reviewing-changes.md) | What to check in the diff, how to merge, and what happens if nobody does |
| [**Notifications**](../operations/notifications.md) | The log, the status file, macOS banners and Discord — what fires when |
