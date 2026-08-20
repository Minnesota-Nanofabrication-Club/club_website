# Minnesota Nanofabrication Club

### 👉 [minnesota-nanofabrication-club.github.io/club_website](https://minnesota-nanofabrication-club.github.io/club_website/)

**Looking for the club? Everything is on the website above** — what we're building,
the projects currently underway, and how to join.

---

This repository just holds the source for that site. It's a static site (plain HTML
and CSS, no build step) served by GitHub Pages from `main`.

| File | Purpose |
| --- | --- |
| `index.html` | Home — about the club, Full Stack Codesign, current projects, team |
| `stepper.html` | Maskless lithography stepper project page |
| `style.css` | Shared stylesheet |
| `SYNC.md` | How the site is kept in sync with the club Google Drive |
| `CLAUDE.md` | Context and standing decisions for anyone (or any agent) editing this repo |
| [`docs/`](docs/) | **Full documentation** — architecture, operations, guides, background |
| `scripts/` | The sync job, its schedule, the watchdog, and Discord notifications |

## 📚 Documentation

This README is the overview. **[`docs/`](docs/) is the full reference** — and it is the
authoritative one. If the two ever disagree, `docs/` is right.

| Start here | For |
| --- | --- |
| [Architecture Overview](docs/architecture/overview.md) | How Drive, the agent, git and Pages fit together |
| [Design Principles](docs/architecture/design-principles.md) | The rules that keep the arrangement predictable, and why |
| [Data Contracts](docs/data-contracts.md) | Which Drive folder feeds which page section; the HTML shapes |
| [Anatomy of a Sync Run](docs/operations/sync-run.md) | What a run does, step by step, and every log marker |
| [The Schedule](docs/operations/schedule.md) | The launchd jobs, sleep/off behaviour, the watchdog |
| [Notifications](docs/operations/notifications.md) | Log, status file, macOS alerts, Discord setup |
| [Troubleshooting](docs/operations/troubleshooting.md) | Symptom → cause → fix |
| [Add a Project](docs/guides/add-project.md) | The Drive path, and the manual HTML template |
| [Change Site Content](docs/guides/edit-content.md) | Decision guide: does this belong in Drive or the repo? |
| [Background](docs/background/index.md) | Why Drive is the source of truth; the settled roster decision |

Preview the docs locally with `mkdocs serve` (needs `mkdocs-material`). They are
deliberately **not** auto-deployed: GitHub Pages serves the club site itself from the root
of `main`, and `mkdocs gh-deploy` publishes to a `gh-pages` branch — pointing Pages there
would take the club site off the air to host its own documentation.

## Editing

Edit the HTML directly and push to `main`; Pages redeploys automatically. To preview
locally, open `index.html` in a browser, or serve the folder:

```
python3 -m http.server 8000
```

## How the site updates itself

**Short version: you edit Google Drive. The website catches up on its own, twice a week.**

```
  Google Drive              Scheduled agent             GitHub                Live site
  "Ultra Hardcore   ──▶   reads Drive, rewrites   ──▶   push to   ──▶   Pages rebuilds
   Chip Codesign"          the HTML if needed            main            (~1 min)
                        Mon + Thu, 8:13am                                     │
                                │                                             ▼
                                └──────────▶ Discord ping with a one-line summary
```

**What runs it.** A `launchd` job on Leonard's Mac that calls Claude Code headlessly —
see [`scripts/sync-from-drive.sh`](scripts/sync-from-drive.sh). Verified end to end on
2026-08-19 under `launchd` itself: the site was deliberately broken, and the job detected
the drift against Drive, repaired it, committed, pushed, and triggered the Pages rebuild
with no session of anyone's involved.

> **Why local and not a cloud routine?** That was the first design, and it fails: cloud
> routines get a read-only GitHub token on this repo, so `git push` and the GitHub API both
> return `403`. Granting write needs a Claude Team/Enterprise plan. Locally, git already has
> push access over SSH, so the whole loop works at no extra cost. The cloud routine still
> exists but is **disabled** — don't re-enable it without fixing the permission first.
>
> The tradeoff: **the Mac has to be on and logged in.** If it's asleep at 8:13am, `launchd`
> runs the job when it next wakes. If the machine is off for a scheduled slot, that run is
> skipped — harmless, since the next one picks up everything. It does need to run at least
> once a month, though: the stored credential refreshes itself on each run, and after about
> four weeks of no runs at all it expires and needs an interactive `/login`.

**Managing the schedule:**

```
./scripts/install-schedule.sh            # install or reinstall
./scripts/install-schedule.sh status     # is it loaded? what did the last run do?
./scripts/install-schedule.sh uninstall  # remove
./scripts/sync-from-drive.sh             # run right now, don't wait for the schedule
./scripts/notify-discord.sh --test       # check the Discord webhook is wired up
```

**How it reports.** Every run appends to `~/Library/Logs/mnfc-website-sync.log` and writes a
one-line outcome to `~/Library/Logs/mnfc-website-sync.status`. Every run also posts to
Discord — a grey "site checked" for a quiet run, maroon "site updated" with the commit
subject when something changed, red on failure. Failures additionally raise a macOS
notification and an `@` mention in Discord; quiet runs deliberately do neither, because a
ping that fires whether or not anything happened is a ping you learn to ignore.

A second `launchd` job, `com.mnfc.website-sync-watchdog`, runs six hours after each sync and
alerts if the last run failed or if nothing has run in over four days. It exists because the
sync cannot report the one failure that matters most — never running at all. A job that
never fires sends nothing and logs nothing, which looks exactly like a quiet week.

**Discord setup** (once). In Discord: *Server Settings → Integrations → Webhooks → New
Webhook*, pick the channel, *Copy Webhook URL*. Then, in your own terminal:

```
mkdir -p ~/.config/mnfc-sync
printf '%s' 'PASTE_THE_WEBHOOK_URL' > ~/.config/mnfc-sync/discord-webhook
chmod 600 ~/.config/mnfc-sync/discord-webhook
printf '%s' '<@YOUR_DISCORD_USER_ID>' > ~/.config/mnfc-sync/discord-mention   # optional, for @pings
```

The webhook URL is a secret — anyone holding it can post to that channel — so it lives in
`~/.config`, never in this repo. With no config file the notification is skipped and the
sync carries on: publishing the site matters, announcing it does not.

**What it does on each run**, in order:

1. Bails out early if the working tree has uncommitted changes, so it never clobbers
   work in progress. Otherwise pulls the latest `main`.
2. Reads [`CLAUDE.md`](CLAUDE.md) and [`SYNC.md`](SYNC.md) — the rules it must follow.
3. Reads the club Google Drive (read-only).
4. Compares Drive against the current HTML.
5. **If something changed**, edits the HTML, commits, and pushes to `main`.
   **If nothing changed, it does nothing** — no empty commits.
6. Logs what it did, retries the push once if the commit didn't make it out, and posts the
   outcome to Discord.

**Then GitHub Pages takes over.** Any push to `main` triggers a rebuild automatically, and
the new version is live in about a minute. Pages serves the files exactly as they are —
there is no build step, no framework, no compile.

**Why Drive and not the HTML?** Because the agent rewrites the HTML from Drive, hand-edits
to project copy can be overwritten on the next run. Design and structure changes are safe;
project *content* should change in Drive. See [`SYNC.md`](SYNC.md) for exactly which Drive
folder feeds which part of the page, and what is deliberately never published (budgets,
vendor pricing, member names).

**Running it early.** You don't have to wait for the schedule. Either run
`./scripts/sync-from-drive.sh`, or from this repo in Claude Code say:

```
Sync the club website from Google Drive following SYNC.md.
```

**If the site looks stale.** Check `./scripts/install-schedule.sh status` — it shows whether
the job is loaded and tails the log. A run that finds no Drive changes is a success, not a
failure, so "no changes committed" in the log is normal. The likeliest cause of a genuinely
missed run is the Mac being off or asleep through both slots; just run the script by hand.
