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
| Nine machine pages | `stepper.html`, `sputterer.html`, `tube-furnace.html`, `etcher.html`, `spinner.html`, `developer.html`, `probe-station.html`, `ultrasonic-cleaner.html`, `wafer-arm.html` — one per subfolder of `Build the Fab` |
| `style.css` | Shared stylesheet |
| `.github/workflows/sync-from-drive.yml` | **The sync** — the only thing that runs on a schedule |
| `scripts/` | `fetch_drive.py` (mirrors Drive for the sync), `notify-discord.sh` (posts the outcome), `generate_sitemap.py` (run by hand) |
| `SYNC.md` | How the site is kept in sync with the club Google Drive |
| `CLAUDE.md` | Context and standing decisions for anyone (or any agent) editing this repo |
| `DRIVE_NOTES.md` | The sync agent's own notes about the current state of Drive — it maintains this itself |
| [`docs/`](docs/) | **Full documentation** — architecture, operations, guides, background |

## 📚 Documentation

This README is the overview. **[`docs/`](docs/) is the full reference** — and it is the
authoritative one. If the two ever disagree, `docs/` is right.

| Start here | For |
| --- | --- |
| [Architecture Overview](docs/architecture/overview.md) | How Drive, the agent, git and Pages fit together |
| [Design Principles](docs/architecture/design-principles.md) | The rules that keep the arrangement predictable, and why |
| [Data Contracts](docs/data-contracts.md) | Which Drive folder feeds which page section; the HTML shapes |
| [Anatomy of a Sync Run](docs/operations/sync-run.md) | What a run does, step by step, and every log marker |
| [The Cloud Sync](docs/operations/cloud-sync.md) | The schedule, the secrets, the service account, and why the sync runs in GitHub Actions |
| [Notifications](docs/operations/notifications.md) | The run log, the job summary, Discord, the failure issue |
| [Reviewing a Proposed Update](docs/operations/reviewing-changes.md) | **What to check in the diff, and how to merge — merging is what publishes** |
| [Troubleshooting](docs/operations/troubleshooting.md) | Symptom → cause → fix |
| [Deployment](docs/operations/deployment.md) | How a merge becomes a live page, and what is not in the repo |
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
  Google Drive            GitHub Actions             Pull request           Live site
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
updates) one pull request. A run that finds no differences does nothing at all — which means it
also leaves any older proposal open and mergeable, so check a proposal's age and its current
diff before merging it.

**What runs it.** [`.github/workflows/sync-from-drive.yml`](.github/workflows/sync-from-drive.yml)
on GitHub Actions, `cron: "13 13 * * 1,4"` — Monday and Thursday, 08:13 CDT / 07:13 CST, since
GitHub cron is always UTC and does not shift for daylight saving. **Nothing runs on anyone's
laptop.** Each run is a throwaway `ubuntu-latest` container, so the agent starts with no memory
of the last run; what carries between runs is what the repo writes down — `CLAUDE.md` and
`SYNC.md` for the rules, `DRIVE_NOTES.md` for what the last run learned about Drive.

> **Why the cloud and not a local job?** Both earlier designs failed, in different ways. A
> Claude Code cloud *routine* came first and could not write: routines get a read-only GitHub
> token on this repo, so `git push` and the GitHub API both returned `403`, and the symptom was
> a job that ran, reported activity, and changed nothing. A `launchd` job on Leonard's Mac
> replaced it and did work — until **2026-08-27**, when the scheduled run died thirty-six
> minutes in with "Your computer went to sleep mid-response". `launchd` does not wake a
> sleeping Mac; it runs a missed job at whatever wake happens next, which on a closed laptop is
> a few-second maintenance wake. `caffeinate` keeps an already-awake machine awake and cannot
> start one, and that Apple Silicon machine has no scheduled power-on. **A schedule on a machine
> that can be closed is best-effort by construction**, and the failure is silent — the only
> symptom is content that quietly ages. A hosted runner is awake because it does not exist until
> the cron fires. All the local machinery — the sync script, the installer, the watchdog, both
> launchd jobs and their log files — was deleted in `a0a76d9` once the cloud path had run green
> end to end. Full history: [The Cloud Sync](docs/operations/cloud-sync.md#why-the-sync-lives-here).

**Two credentials make it go**, both repository secrets. `CLAUDE_CODE_OAUTH_TOKEN` — from
`claude setup-token`, so the run bills against the existing Max plan rather than per token — and
`GDRIVE_SERVICE_ACCOUNT_JSON`, a Google service account key with read-only access to the club
Drive folder. The agent itself has **no Drive credential and no network**: `scripts/fetch_drive.py`
mirrors Drive to plain files under `$RUNNER_TEMP` *before* the agent starts, and the agent just
reads files with `Read, Write, Edit, Glob, Grep, Bash(git:*)`. With either secret missing the
run exits **green** with a `::notice::` rather than red, so an unconfigured repo does not train
everyone to ignore a permanent red X. Setup, including creating the service account:
[The Cloud Sync](docs/operations/cloud-sync.md).

**Working with it:**

```
R=Minnesota-Nanofabrication-Club/club_website

gh workflow run "Sync from Drive" --repo "$R"          # propose now, don't wait for the slot
gh workflow run "Sync from Drive" --repo "$R" -f dry_run=true   # run it but push nothing
gh run list --repo "$R" --workflow "Sync from Drive"   # did the last runs pass?
gh issue list --repo "$R" --label drive-sync-failure   # is the sync currently broken?
gh pr list --repo "$R" --head sync/drive               # is a proposal waiting for review?
gh pr diff --repo "$R" sync/drive                      # read it
gh pr merge --repo "$R" sync/drive                     # publish it
./scripts/notify-discord.sh --test                     # check a Discord webhook by hand
```

Or from a browser: **Actions → Sync from Drive → Run workflow**, which offers the same
`dry run` input.

**How it reports.** There is no log file, status file or desktop notification anywhere — every
channel lives on GitHub or in Discord.

- **The Actions run log**, complete but only useful if you already suspect a problem.
- **A job summary** at the top of each run page: status, whether anything changed, the commit
  subject, the files touched. `published to main` is always `no`, printed anyway, because that
  line is the design.
- **Discord**, one embed per run via `scripts/notify-discord.sh` — a grey `✓ Site checked` for a
  quiet run, an amber `📋 Update proposed — review` carrying the commit subject and the pull
  request link, red `✗ Sync failed` on any failure. Every state carries an `@` mention,
  including quiet runs: the point is confirmation the job ran at all, and an absent ping only
  reads as a signal if a present one is guaranteed. Twice a week is a low enough rate for that
  to stay legible.
- **A GitHub issue** labelled `drive-sync-failure`, opened on the first failing run, commented
  on by every failure after it, and closed automatically by the next success. It is the only
  channel that persists a *condition* rather than reporting an event.

**Two gaps worth knowing about.** Nothing chases an unmerged proposal — it is announced once,
and a later run either force-pushes a newer proposal over it or, if Drive now matches the site,
leaves it open and untouched while every channel keeps reporting healthy runs. And **there is
no watchdog**: a run that never fires writes nothing anywhere and looks exactly like a quiet
week, which is why even quiet runs ping. GitHub also disables scheduled workflows in
repositories with 60 days of no activity, silently.

**Discord setup** (once, as repository secrets). In Discord: *Server Settings → Integrations →
Webhooks → New Webhook*, pick the channel, *Copy Webhook URL*. Then:

```
gh secret set DISCORD_WEBHOOK_URL --repo Minnesota-Nanofabrication-Club/club_website
gh secret set DISCORD_MENTION     --repo Minnesota-Nanofabrication-Club/club_website  # optional, e.g. <@USER_ID>
```

The workflow writes both onto the runner at `~/.config/mnfc-sync/` for `notify-discord.sh`, and
that directory dies with the container. The webhook URL is a secret — anyone holding it can post
to that channel — so it never goes in this repo. With no webhook secret the Discord steps are
skipped and the sync carries on: publishing the site matters, announcing it does not.

**What it does on each run**, in order:

1. Checks out `main` with full history.
2. Checks the Claude and Drive secrets are present. If either is missing it writes a setup
   summary and **exits green** without spending anything.
3. Sanity-checks the repo — `CLAUDE.md`, `SYNC.md`, `index.html`, `style.css` and
   `scripts/fetch_drive.py` all exist, and the script compiles.
4. Mirrors the Drive tree to `$RUNNER_TEMP/drive` as the service account. This runs *before* the
   agent, so a bad key or an unshared folder fails loudly with no tokens spent. `[LR]`,
   `[C] Finances`, `[C] Funding` and `[C] Logistics` are never fetched at all.
5. Records the current commit as the baseline.
6. Runs the agent, which reads [`CLAUDE.md`](CLAUDE.md) and [`SYNC.md`](SYNC.md), reads the
   mirror, rewrites the HTML where it disagrees with Drive, prunes and updates `DRIVE_NOTES.md`,
   and **commits** — without pushing or switching branches. **If nothing changed it makes no
   commit** and says so.
7. **The guard:** if the agent touched `docs/`, `.github/`, `scripts/`, `mkdocs.yml`,
   `README.md`, `CLAUDE.md` or `SYNC.md`, the run fails and **nothing is pushed**. A prompt rule
   is a request; this is the check. `DRIVE_NOTES.md` is deliberately writable — the agent owns
   its observations, humans own the rules.
8. Force-pushes `sync/drive` and opens a pull request against `main`, or comments on the one
   already open. Skipped entirely when nothing changed.
9. Writes the job summary, posts to Discord, and opens or closes the failure issue.

**Then a human merges, and GitHub Pages takes over.** Merging is the approval step and the
publishing step at once: the commit lands on `main`, Pages rebuilds automatically, and the new
version is live in about a minute. Pages serves the files exactly as they are — there is no
build step, no framework, no compile.

**What to check before merging:** every claim traces to a Drive doc; every `Lead:` is quoted from
a document's text and not inferred from who owns the file; no budgets, BOM costs, vendor pricing
or outreach notes; no general-member names in the team list; the four deliberately non-Drive
items still present (the advisor's UMN faculty page, the Hacker Fab docs, the CMU stepper paper,
`jin00404@umn.edu`); the footer date bumped. The full checklist is in
[Reviewing a Proposed Update](docs/operations/reviewing-changes.md).

**Why Drive and not the HTML?** Because the agent rewrites the HTML from Drive, hand-edits
to project copy come back as a proposal that undoes them, in a diff that looks like any other
routine sync. Design and structure changes are safe;
project *content* should change in Drive. See [`SYNC.md`](SYNC.md) for exactly which Drive
folder feeds which part of the page, and what is deliberately never published (budgets,
vendor pricing, member names).

**Running it early.** You don't have to wait for the schedule. Either trigger the workflow —
**Actions → Sync from Drive → Run workflow** — or, from this repo in Claude Code, say:

```
Sync the club website from Google Drive following SYNC.md.
```

**If the site looks stale.** Check `gh pr list --head sync/drive` first — the likeliest cause is
a proposal nobody merged, and that state reports success on every channel. Then check
`gh run list --workflow "Sync from Drive"` and `gh issue list --label drive-sync-failure`. A run
that finds no Drive changes is a success, not a failure, so `changed: false` is normal. If there
were no runs at all on recent Mondays or Thursdays, check whether GitHub disabled the schedule
(`gh workflow list` shows `disabled_inactivity`) and re-enable it.
