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

    What a run does step by step; the twice-weekly GitHub Actions schedule and the secrets
    behind it; how a run reports itself on four channels; how to review and merge a proposal;
    what each marker means and how to recover from a bad run.

    [Anatomy of a Sync Run →](operations/sync-run.md)

-   **Extending**

    ---

    Add a project; change site content; change a publishing rule without leaving the agent
    following the old one.

    [Add a Project →](guides/add-project.md)

-   **Background**

    ---

    What the club is, why Drive is the source of truth, and the officer-roster decision that
    is settled and should not be re-litigated.

    [Background →](background/index.md)

</div>

---

## Quick reference

| Thing | Where |
| --- | --- |
| Live site | `https://minnesota-nanofabrication-club.github.io/club_website/` — ten pages: `index.html` plus one per machine |
| Drive root | **Ultra Hardcore Chip D&F**, id `1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP` |
| The sync | `.github/workflows/sync-from-drive.yml` — proposes; it does not publish |
| The schedule | `cron: "13 13 * * 1,4"` — Mondays **and** Thursdays, 08:13 CDT / 07:13 CST |
| Manual trigger | **Actions → Sync from Drive → Run workflow**, with a `dry_run` input |
| The proposal branch | `sync/drive`, force-pushed from `main` every run; at most one open pull request |
| Drive mirror | `scripts/fetch_drive.py` — service account, read-only, into `$RUNNER_TEMP` |
| Discord notifier | `scripts/notify-discord.sh` — webhook from the `DISCORD_WEBHOOK_URL` secret |
| Run log | the Actions run page. There is **no** log file on anyone's machine |
| Failure state | an open GitHub issue labelled `drive-sync-failure` |
| Standing decisions | `CLAUDE.md` (the *why*) |
| The procedure | `SYNC.md` (the *how*) |
| The agent's own notes | `DRIVE_NOTES.md` — observations about Drive, agent-maintained, capped at 20 |

```bash
R=Minnesota-Nanofabrication-Club/club_website

gh workflow run "Sync from Drive" --repo "$R"        # propose now, don't wait for the slot
gh run list --repo "$R" --workflow "Sync from Drive" # did the last runs pass?
gh issue list --repo "$R" --label drive-sync-failure # is the sync currently broken?
gh pr list --repo "$R" --head sync/drive             # is a proposal waiting for review?
gh pr merge --repo "$R" sync/drive                   # merge it — this is what publishes
python3 -m http.server 8000                          # preview at http://localhost:8000
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
