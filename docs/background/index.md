# Background

This section is for anyone approaching the `club_website` repository for the first time — a
new club officer inheriting the site, a member wondering why their edit disappeared, or an
agent asked to change something. It explains the club, the repository, and the reasoning
behind an arrangement that looks strange until the failure modes it prevents are visible.

Nothing here is a procedure. The procedures live in
[Operations](../operations/schedule.md) and the field-by-field mapping lives in
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

-   **Why the Sync Runs Locally**

    ---

    The cloud routine was the first design and it cannot publish; `403` on both `git push`
    and the GitHub API; the twice-weekly local `launchd` job that replaced it, and its one
    tradeoff.

    [Why the Sync Runs Locally →](why-local-not-cloud.md)

</div>

---

## Reading order

The four pages are independent, but they build on each other in the order above.

| If you are | Read |
| --- | --- |
| New to the club entirely | [The Club](the-club.md) first, then the rest in order |
| About to edit the site | [Why Google Drive Is the Source of Truth](why-drive-is-truth.md) — it will change what you edit |
| Syncing and hitting a contradiction between Drive docs | [Why Google Drive Is the Source of Truth](why-drive-is-truth.md), then [The Officer Roster Decision](roster-decision.md) |
| Wondering why the site went stale | [Why the Sync Runs Locally](why-local-not-cloud.md), then [the schedule](../operations/schedule.md) |

!!! info "For new club officers: this section is not about the club's work"

    Everything here concerns how the *website* is maintained. The club's actual engineering
    — tool builds, process development, timelines — lives in the **Ultra Hardcore Chip
    Codesign** Google Drive, and this repository deliberately holds only a thin public
    summary of it. If you are looking for a bill of materials or a project plan, you are in
    the wrong place; open Drive.
