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

## Editing

Edit the HTML directly and push to `main`; Pages redeploys automatically. To preview
locally, open `index.html` in a browser, or serve the folder:

```
python3 -m http.server 8000
```

## How the site updates itself

**Short version: you edit Google Drive. The website catches up on its own every Monday.**

```
  Google Drive                Weekly agent               GitHub                Live site
  "Ultra Hardcore   ──▶   reads Drive, rewrites   ──▶   push to   ──▶   Pages rebuilds
   Chip Codesign"          the HTML if needed            main            (~1 min)
                          Mondays 8:13am
```

**What runs it.** A `launchd` job on Leonard's Mac that calls Claude Code headlessly —
see [`scripts/sync-from-drive.sh`](scripts/sync-from-drive.sh). Verified end to end on
2026-08-18: the entire loop, including the push and the Pages rebuild, was confirmed by
deliberately breaking the site and watching the job repair it.

> **Why local and not a cloud routine?** That was the first design, and it fails: cloud
> routines get a read-only GitHub token on this repo, so `git push` and the GitHub API both
> return `403`. Granting write needs a Claude Team/Enterprise plan. Locally, git already has
> push access over SSH, so the whole loop works at no extra cost. The cloud routine still
> exists but is **disabled** — don't re-enable it without fixing the permission first.
>
> The tradeoff: **the Mac has to be on.** If it's asleep at 8:13am Monday, `launchd` runs the
> job when it next wakes. If the machine is off all week, that week's sync is skipped —
> harmless, since the next run picks up everything.

**Managing the schedule:**

```
./scripts/install-schedule.sh            # install or reinstall
./scripts/install-schedule.sh status     # is it loaded? what did the last run do?
./scripts/install-schedule.sh uninstall  # remove
./scripts/sync-from-drive.sh             # run right now, don't wait for Monday
```

Every run appends to `~/Library/Logs/mnfc-website-sync.log`, including what changed and
whether the push succeeded.

**What it does each Monday**, in order:

1. Bails out early if the working tree has uncommitted changes, so it never clobbers
   work in progress. Otherwise pulls the latest `main`.
2. Reads [`CLAUDE.md`](CLAUDE.md) and [`SYNC.md`](SYNC.md) — the rules it must follow.
3. Reads the club Google Drive (read-only).
4. Compares Drive against the current HTML.
5. **If something changed**, edits the HTML, commits, and pushes to `main`.
   **If nothing changed, it does nothing** — no empty commits.
6. Logs what it did, and retries the push once if the commit didn't make it out.

**Then GitHub Pages takes over.** Any push to `main` triggers a rebuild automatically, and
the new version is live in about a minute. Pages serves the files exactly as they are —
there is no build step, no framework, no compile.

**Why Drive and not the HTML?** Because the agent rewrites the HTML from Drive, hand-edits
to project copy can be overwritten on the next run. Design and structure changes are safe;
project *content* should change in Drive. See [`SYNC.md`](SYNC.md) for exactly which Drive
folder feeds which part of the page, and what is deliberately never published (budgets,
vendor pricing, member names).

**Running it early.** You don't have to wait for Monday. Either run
`./scripts/sync-from-drive.sh`, or from this repo in Claude Code say:

```
Sync the club website from Google Drive following SYNC.md.
```

**If the site looks stale.** Check `./scripts/install-schedule.sh status` — it shows whether
the job is loaded and tails the log. A run that finds no Drive changes is a success, not a
failure, so "no changes committed" in the log is normal. The likeliest cause of a genuinely
missed week is the Mac being off or asleep the whole time; just run the script by hand.
