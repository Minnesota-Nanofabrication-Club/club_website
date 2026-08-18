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
3. **Don't publish internal material.** Budgets, funding status, vendor pricing, BOM
   costs, advisor/professor outreach notes, and meeting to-dos stay in Drive.
4. **Roster:** publish officers (President, Vice President, Officers) and the faculty
   advisor only. Do not publish the general-member roster — those are students' full
   names on a public page, and they haven't opted in. If the club decides otherwise,
   change this rule first, then the site.

   ⚠️ **Unresolved conflict — do not "fix" this automatically.** Two Drive docs disagree
   about who the officers are:
   - *Minnesota Nanofabrication Constitution* (ratified 2026-08-04, signature block) lists
     Vikram Narra, Davit Sandoyan, Harshit Mehendiratta and John Jeong as **Officers**, and
     does not mention Bear Blinschauer.
   - *Engineering Structure* (edited more recently) lists Bear Blinschauer as the sole
     **Officer** and puts Narra, Sandoyan, Mehendiratta and Jeong under **Members**.

   The RSO registration requires five officer signatures, which may explain the
   constitution's list. Until Leonard resolves this, the site publishes the
   *Engineering Structure* version: Leonard Jin (President), Andrew Choi (Vice President),
   Bear Blinschauer (Officer), Prof. Talghader (Faculty Advisor). Leave it that way and
   flag the conflict again in your summary rather than adding or removing names.
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
