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
                          Mondays 8:13am CT
```

**What runs it.** A scheduled Claude Code cloud agent (a "routine"), not a server or a
GitHub Action. It lives in Leonard's Claude account and is managed at
[claude.ai/code/routines](https://claude.ai/code/routines). Nothing runs on anyone's laptop,
so it works whether or not your machine is on.

**What it does each Monday**, in order:

1. Spins up a fresh sandbox and clones this repo.
2. Reads [`CLAUDE.md`](CLAUDE.md) and [`SYNC.md`](SYNC.md) — the rules it must follow.
3. Reads the club Google Drive through a read-only connector.
4. Compares Drive against the current HTML.
5. **If something changed**, edits the HTML, commits, and pushes to `main`.
   **If nothing changed, it does nothing** — no empty commits.
6. Sends Leonard a summary of what it did.

**Then GitHub Pages takes over.** Any push to `main` triggers a rebuild automatically, and
the new version is live in about a minute. Pages serves the files exactly as they are —
there is no build step, no framework, no compile.

**Why Drive and not the HTML?** Because the agent rewrites the HTML from Drive, hand-edits
to project copy can be overwritten on the next run. Design and structure changes are safe;
project *content* should change in Drive. See [`SYNC.md`](SYNC.md) for exactly which Drive
folder feeds which part of the page, and what is deliberately never published (budgets,
vendor pricing, member names).

**Running it early.** You don't have to wait for Monday. Either hit *Run now* on the routine
page, or from this repo in Claude Code say:

```
Sync the club website from Google Drive following SYNC.md.
```

**If the site looks stale.** Check the routine's last run at
[claude.ai/code/routines](https://claude.ai/code/routines) — the run log shows what it read
and why it did or didn't change anything. A run that finds no Drive changes is a success,
not a failure.
