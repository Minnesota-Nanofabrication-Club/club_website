# Nanofab Club Website

**A static site that proposes its own updates from Google Drive.**

The Minnesota Nanofabrication Club's public site is plain HTML and CSS with no build step,
served by GitHub Pages from `main`. Its content is not maintained by editing the HTML — it
is mirrored from the club's **Ultra Hardcore Chip Codesign** Google Drive by a scheduled
agent that reads Drive, rewrites the pages when they disagree, and opens a pull request.

This documentation covers the machinery, not the club. If you are looking for the club
itself, that is the [site](https://minnesota-nanofabrication-club.github.io/club_website/).

!!! tip "The two things to know"
    **You update the site by updating Drive.** Project copy hand-edited into the HTML is
    undone the next time the sync runs, with no warning and no record of what was lost.
    The exceptions — a handful of external links and one contact address that live only in
    the repo — are listed in [Data Contracts](data-contracts.md).

    **The sync proposes; a human merges.** Every run stops at a pull request against `main`,
    and merging it is what publishes. A proposal nobody merges is a change that never reaches
    the site — see [Reviewing a Proposed Update](operations/reviewing-changes.md).

---

## Where to start

<div class="grid cards" markdown>

-   **Architecture**

    ---

    How Drive, the scheduled agent, git and GitHub Pages fit together; and the rules that
    keep the arrangement predictable.

    [Overview →](architecture/overview.md)

-   **Operations**

    ---

    What a run does step by step; the twice-weekly launchd schedule; how a run reports
    itself on four channels; how to review and merge a proposal; what each log marker means
    and how to recover from a bad one.

    [Anatomy of a Sync Run →](operations/sync-run.md)

-   **Extending**

    ---

    Add a project; change site content; change a publishing rule without leaving the agent
    following the old one.

    [Add a Project →](guides/add-project.md)

-   **Background**

    ---

    Why Drive is the source of truth, why the sync runs on a laptop instead of the cloud,
    and the officer-roster decision that is settled and should not be re-litigated.

    [Background →](background/index.md)

</div>

---

## Quick reference

| Thing | Where |
| --- | --- |
| Live site | `https://minnesota-nanofabrication-club.github.io/club_website/` |
| Drive root | **Ultra Hardcore Chip Codesign**, id `1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP` |
| The sync | `scripts/sync-from-drive.sh` — proposes; it does not publish |
| The proposal branch | `sync/drive`, reset from `main` every run; at most one open pull request |
| The schedule | `scripts/install-schedule.sh` — launchd, Mondays **and** Thursdays 8:13am |
| The watchdog | `scripts/check-sync-ran.sh` — launchd, Mondays **and** Thursdays 2:13pm |
| Run log | `~/Library/Logs/mnfc-website-sync.log` |
| Last outcome | `~/Library/Logs/mnfc-website-sync.status` |
| Discord notifier | `scripts/notify-discord.sh` — webhook in `~/.config/mnfc-sync/discord-webhook` |
| Standing decisions | `CLAUDE.md` (the *why*) |
| The procedure | `SYNC.md` (the *how*) |

```bash
./scripts/sync-from-drive.sh              # propose now, don't wait for the next slot
./scripts/install-schedule.sh status      # is it loaded? what did the last run do?
gh pr list --head sync/drive              # is a proposal waiting for review?
gh pr merge sync/drive                    # merge it — this is what publishes
./scripts/notify-discord.sh --test        # is the Discord webhook wired up?
python3 -m http.server 8000               # preview the site at http://localhost:8000
```

---

## Reading these docs

These pages are written for MkDocs Material and preview locally with:

```bash
mkdocs serve
```

There is deliberately no automatic deployment for this documentation. GitHub Pages for this
repository serves the club website itself from the root of `main`; `mkdocs gh-deploy`
publishes to a `gh-pages` branch, and pointing Pages at that branch would take the club site
off the air to make room for its own documentation. Read these locally, or on GitHub — the
Markdown renders well enough there to be useful, though admonitions appear as plain text.
