# CLAUDE.md — Minnesota Nanofabrication Club website

Read this before changing anything in this repo. It records decisions that are **not**
recoverable from the code or the Drive docs themselves, and that have already been gotten
wrong once.

## What this repo is

A static site (plain HTML + CSS, no build step) deployed by GitHub Pages from `main` to
https://minnesota-nanofabrication-club.github.io/club_website/

Content is mirrored from the club's **Ultra Hardcore Chip Codesign** Google Drive.
[`SYNC.md`](SYNC.md) is the procedure: which Drive folder feeds which page section, and
the publishing rules. A scheduled cloud routine re-runs that sync weekly. **Read `SYNC.md`
too** — this file is the *why*, `SYNC.md` is the *how*.

## Source-of-truth hierarchy

Google Drive is authoritative over this repo. Do not hand-edit project copy in the HTML;
update Drive instead, or the next sync may overwrite it.

**Within Drive, when two documents disagree, use this precedence:**

| Topic | Ground truth | Notes |
| --- | --- | --- |
| Engineering / organizational structure — who holds which role, who owns which project, how teams are organized | **`Engineering Structure`** doc | Always wins. It reflects how the club actually operates and is kept current. |
| Club purpose, membership eligibility, governance, formal policy | `Minnesota Nanofabrication Constitution` | Reference material. Cite it for purpose and eligibility language. |
| Project scope, status, timelines, BOMs | That project's folder under `Build the Fab` | Each tool's `[Master]` and timeline docs. |
| Overall mission framing | `Project and Goals` | Source of the "Full Stack Codesign" language. |

### ⚠️ The constitution does NOT define the engineering structure

This is the specific mistake to avoid. The constitution's **officer signature block** lists
Vikram Narra, Davit Sandoyan, Harshit Mehendiratta and John Jeong as "Officers" and omits
Bear Blinschauer. That block exists to satisfy the RSO registration requirement of five
officer signatures — **it is a registration artifact, not a statement of who the officers
are.**

The `Engineering Structure` doc is the ground truth for roles:

- Leonard Jin — President
- Andrew Choi — Vice President
- Bear Blinschauer — Officer
- Prof. Joseph "Joey" Talghader — Faculty Advisor
- everyone else listed there — Members

If a future sync notices this discrepancy, **do not "reconcile" it** by pulling names out of
the constitution's signature block onto the site. Follow `Engineering Structure` and move on.
Resolved by Leonard on 2026-08-18.

## Publishing rules that are easy to get wrong

These are stated in full in `SYNC.md`; the two with real consequences:

1. **Never invent content.** Every claim on the site must trace to a Drive doc. An empty
   project folder gets a bare status ("Planned"), not invented prose.
2. **Officers and the faculty advisor are published by name; general members are not.**
   Those are students' full names on a public, search-indexed page and they have not opted
   in. Officer names are already public via RSO registration. Changing this needs the
   members' consent, not just a decision to do it.

Also never publish: budgets, funding status, vendor names or pricing, BOM costs, sponsorship
correspondence, professor-outreach notes, or the `[MASTER]` to-do lists. Those live in Drive.

## Editing

Edit the HTML directly and push to `main`; Pages redeploys automatically. Preview locally with
`python3 -m http.server 8000`. Match the existing structure and `style.css` — no frameworks,
no external assets, no build step. Update the "last updated" date in the `index.html` footer
whenever content changes.
