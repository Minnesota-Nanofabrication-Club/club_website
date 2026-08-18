# Google Drive → website sync

The club's **Ultra Hardcore Chip Codesign** Google Drive is the source of truth for
project information. This site mirrors a concise, public-facing subset of it. A
scheduled job re-runs this sync weekly; it can also be run by hand at any time.

## Run it manually

From this repo, in Claude Code:

```
Sync the club website from Google Drive following SYNC.md.
```

## Drive layout

Root folder: **Ultra Hardcore Chip Codesign** — `1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP`

| Drive location | Feeds |
| --- | --- |
| `Minnesota Nanofabrication Club (GopherFab)/Project and Goals` | "Full Stack Codesign" section |
| `Minnesota Nanofabrication Club (GopherFab)/Engineering Structure` | "Team" section |
| `Minnesota Nanofabrication Club (GopherFab)/Minnesota Nanofabrication Constitution` | "About" / "Get Involved" (purpose, membership eligibility) |
| `Build the Fab/*` (one subfolder per tool) | "Current Projects" — one entry per subfolder |
| `Build the Fab/Maskless Lithography Stepper/Project Timeline` | `stepper.html` timeline table |
| `Design the Compute Kernel/` | "Compute Kernel" project entry |

Tag conventions used in Drive: `[LR]` = learning resource, `[D]` = documentation,
`[Master]` = the main outline doc for that folder. `[LR]` folders are reference material
and are **not** published to the site.

## Rules

1. **Never invent content.** Every claim on the site must trace back to a Drive doc. If
   a project folder is empty or only holds a diagram link, say so with a short status
   ("Architecture design", "Planned") rather than writing filler about it.
2. **Stay concise.** The site is an overview for people who don't know the club, not a
   documentation mirror. A few sentences per project. Deep detail belongs in Drive or
   in the docs book, not here.

   Rule 1 governs *claims*, not *links*. Links to public reference pages are fine and
   should be **preserved** even though they aren't sourced from Drive — currently the
   advisor's UMN faculty page, Hacker Fab docs, and the CMU stepper paper. Verify a link
   resolves and points at the right subject before adding one; don't guess a URL.

   The club contact address in "Get Involved" (`jin00404@umn.edu`, Leonard's UMN address)
   is likewise deliberate and not Drive-sourced. **Preserve it.** Added at Leonard's
   request 2026-08-18. This is the one email published on the site — do not add members'
   or the advisor's addresses, even though they appear in Drive docs.
3. **Don't publish internal material.** Budgets, funding status, vendor pricing, BOM
   costs, advisor/professor outreach notes, and meeting to-dos stay in Drive.
4. **Roster:** publish officers (President, Vice President, Officers) and the faculty
   advisor only. Do not publish the general-member roster — those are students' full
   names on a public page, and they haven't opted in. If the club decides otherwise,
   change this rule first, then the site.

   **Which doc names the officers — settled, do not re-litigate.** The *Engineering
   Structure* doc is ground truth for roles. The *Constitution*'s officer signature block
   names a different set of people (Vikram Narra, Davit Sandoyan, Harshit Mehendiratta,
   John Jeong) and omits Bear Blinschauer — that block exists to satisfy the RSO
   requirement of five officer signatures and is a registration artifact, not a roster.

   Publish what *Engineering Structure* says: Leonard Jin (President), Andrew Choi (Vice
   President), Bear Blinschauer (Officer), Prof. Talghader (Faculty Advisor). If you notice
   the discrepancy, do **not** "fix" it by pulling names off the constitution. Resolved by
   Leonard 2026-08-18; see `CLAUDE.md` for the full precedence table.
5. **Preserve the design.** Match the existing HTML structure and `style.css`. No new
   frameworks, no external assets, no build step.
6. Update the "last updated" date in the footer of `index.html` whenever content changes.
7. If nothing in Drive changed, make no commit.

## What the job does

1. Read the Drive folders listed above.
2. Diff the meaningful content against the current HTML.
3. Apply changes to `index.html` / `stepper.html` (and `style.css` only if a new
   content type genuinely needs it).
4. Commit with a message naming what changed, and push to `main`. GitHub Pages
   redeploys automatically.
5. Report a one-paragraph summary of what changed, or "no changes".
