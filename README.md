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
| [Reviewing a Proposed Update](docs/operations/reviewing-changes.md) | **What to check in the diff, and how to merge — merging is what publishes** |
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

**Short version: you edit Google Drive. Twice a week the site proposes the matching change
as a pull request, and merging it is what publishes.**

```
  Google Drive            Scheduled agent            Pull request           Live site
  "Ultra Hardcore   ──▶   reads Drive, edits   ──▶   branch sync/drive  ──▶   ┌──────────┐
   Chip Codesign"          the HTML, commits          → PR vs main           │ you merge │
                        Mon + Thu, 8:13am                    │               └─────┬────┘
                                │                            │                     ▼
                                │                            │              main updated
                                │                            │                     │
                                │                            ▼                     ▼
                                └──────────▶ Discord ping with the PR link   Pages rebuilds
                                                                                (~1 min)
```

**Nothing is published until a human merges.** The sync never pushes to `main`. It resets the
`sync/drive` branch from `main`, commits the agent's edits there, force-pushes, and opens (or
updates) one pull request. A run that finds no differences closes any proposal still open,
because merging a stale one would republish content the agent has since judged unnecessary.

**What runs it.** A `launchd` job on Leonard's Mac that calls Claude Code headlessly —
see [`scripts/sync-from-drive.sh`](scripts/sync-from-drive.sh). The write-back path was
verified end to end on 2026-08-19 under `launchd` itself: the site was deliberately broken,
and the job detected the drift against Drive and repaired it with no session of anyone's
involved. That test ran under the earlier design, which pushed straight to `main`; the same
run today produces a pull request instead.

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
./scripts/sync-from-drive.sh             # propose right now, don't wait for the schedule
gh pr list --head sync/drive             # is a proposal waiting for review?
gh pr diff sync/drive                    # read it
gh pr merge sync/drive                   # publish it
./scripts/notify-discord.sh --test       # check the Discord webhook is wired up
```

**How it reports.** Every run appends to `~/Library/Logs/mnfc-website-sync.log` and writes a
one-line outcome to `~/Library/Logs/mnfc-website-sync.status`. Every run also posts to
Discord — a grey "site checked" for a quiet run, an amber "📋 Update proposed — review"
carrying the commit subject and the pull request link, red on failure. Failures and proposals
additionally raise a macOS notification; a quiet run raises none. Every Discord post carries
an `@` mention, including quiet runs — the point is confirmation the job ran at all, and an
absent ping only reads as a signal if a present one is guaranteed. Twice a week is a low
enough rate for that to stay legible.

**Nothing chases an unmerged proposal.** It is announced once. A later run either force-pushes
a newer proposal over it or closes it as superseded, and the status file keeps reading
`OK  proposed <sha> (awaiting review)` in the meantime — so every channel reports a healthy
run while the site sits unchanged. Review in the days after the ping, not weeks later.

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
   work in progress. Otherwise checks out `main` and pulls the latest.
2. Resets the `sync/drive` branch onto current `main`, so the proposal always shows current
   Drive against what is published now — never a pile-up of older proposals.
3. Reads [`CLAUDE.md`](CLAUDE.md) and [`SYNC.md`](SYNC.md) — the rules it must follow.
4. Reads the club Google Drive (read-only).
5. Compares Drive against the current HTML.
6. **If something changed**, edits the HTML and commits — on the branch, without pushing or
   merging. **If nothing changed, it does nothing** — no empty commits — and closes any
   proposal left open from an earlier run.
7. Force-pushes the branch and opens a pull request against `main`, or reports that the
   already-open one was updated.
8. Logs what it did, posts the outcome and the PR link to Discord, and returns the repo to
   `main`.

**Then a human merges, and GitHub Pages takes over.** Merging is the approval step and the
publishing step at once: the commit lands on `main`, Pages rebuilds automatically, and the new
version is live in about a minute. Pages serves the files exactly as they are — there is no
build step, no framework, no compile.

**What to check before merging:** every claim traces to a Drive doc; no budgets, BOM costs,
vendor pricing or outreach notes; no general-member names in the team list; the four
deliberately non-Drive items still present (the advisor's UMN faculty page, the Hacker Fab
docs, the CMU stepper paper, `jin00404@umn.edu`); the footer date bumped. The full checklist
is in [Reviewing a Proposed Update](docs/operations/reviewing-changes.md).

**Why Drive and not the HTML?** Because the agent rewrites the HTML from Drive, hand-edits
to project copy come back as a proposal that undoes them, in a diff that looks like any other
routine sync. Design and structure changes are safe;
project *content* should change in Drive. See [`SYNC.md`](SYNC.md) for exactly which Drive
folder feeds which part of the page, and what is deliberately never published (budgets,
vendor pricing, member names).

**Running it early.** You don't have to wait for the schedule. Either run
`./scripts/sync-from-drive.sh`, or from this repo in Claude Code say:

```
Sync the club website from Google Drive following SYNC.md.
```

**If the site looks stale.** Check `gh pr list --head sync/drive` first — the likeliest cause
is a proposal nobody merged, and that state reports success on every channel. Then check
`./scripts/install-schedule.sh status`, which shows whether the job is loaded and tails the
log. A run that finds no Drive changes is a success, not a failure, so "no changes proposed"
in the log is normal. The likeliest cause of a genuinely missed run is the Mac being off or
asleep through both slots; just run the script by hand.
