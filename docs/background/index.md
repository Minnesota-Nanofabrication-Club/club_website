# Background

This section is for anyone approaching the `club_website` repository for the first time — a
new club officer inheriting the site, a member wondering why their edit disappeared, or an
agent asked to change something. It explains the club, the repository, and the reasoning
behind an arrangement that looks strange until the failure modes it prevents are visible.

Nothing here is a procedure. The procedures live in
[Operations](../operations/sync-run.md) and the field-by-field mapping lives in
[Data Contracts](../data-contracts.md). This section is the *why* those pages assume.

---

## Start here

<div class="grid cards" markdown>

-   **The Club**

    ---

    What the Minnesota Nanofabrication Club is; the two halves of the program; the
    fabrication line of tools; the Hacker Fab connection; what the site exists to say.

    [The Club →](the-club.md)

-   **Why Google Drive Is the Source of Truth**

    ---

    The site is a mirror of a public subset of Drive; the divergence this prevents; the
    cost it imposes; why a precedence rule between Drive docs is necessary at all.

    [Why Google Drive Is the Source of Truth →](why-drive-is-truth.md)

-   **The Officer Roster Decision**

    ---

    The constitution's signature block is a registration artifact, not a roster; why a
    future sync must not "reconcile" it; the separate rule against publishing member names.

    [The Officer Roster Decision →](roster-decision.md)

</div>

!!! note "Where the sync-history page went"
    There used to be a fourth page here, *Why the Sync Runs Locally*, arguing for a `launchd`
    job on one Mac over a Claude Code cloud routine. That decision has since been reversed —
    the sync is a GitHub Actions workflow and the local machinery was deleted in commit
    `a0a76d9` — so the page was removed rather than left standing as a recommendation nobody
    should follow. **The reasoning was not thrown away.** All three designs, and why each was
    replaced, are recorded in
    [Why the sync lives here](../operations/cloud-sync.md#why-the-sync-lives-here).

---

## Reading order

The three pages are independent, but they build on each other in the order above.

| If you are | Read |
| --- | --- |
| New to the club entirely | [The Club](the-club.md) first, then the rest in order |
| About to edit the site | [Why Google Drive Is the Source of Truth](why-drive-is-truth.md) — it will change what you edit |
| Syncing and hitting a contradiction between Drive docs | [Why Google Drive Is the Source of Truth](why-drive-is-truth.md), then [The Officer Roster Decision](roster-decision.md) |
| Wondering why the site went stale | [Reviewing a Proposed Update](../operations/reviewing-changes.md) first — an unmerged proposal is the most common cause — then [Troubleshooting](../operations/troubleshooting.md) |

!!! info "For new club officers: this section is not about the club's work"

    Everything here concerns how the *website* is maintained. The club's actual engineering
    — tool builds, process development, timelines — lives in the **Ultra Hardcore Chip
    Codesign** Google Drive, and this repository deliberately holds only a thin public
    summary of it. If you are looking for a bill of materials or a project plan, you are in
    the wrong place; open Drive.
