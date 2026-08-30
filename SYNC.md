# Google Drive → website sync

The club's **Ultra Hardcore Chip Codesign** Google Drive is the source of truth for
project information. This site mirrors a concise, public-facing subset of it. A
scheduled job re-runs this sync on Mondays and Thursdays; it can also be run by hand at
any time.

## Run it manually

From this repo, in Claude Code:

```
Sync the club website from Google Drive following SYNC.md.
```

## Drive layout

Root folder: **Ultra Hardcore Chip D&F** — `1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP`
(renamed from "Ultra Hardcore Chip Codesign" in August 2026; the id did not change)

| Drive location | Feeds |
| --- | --- |
| `[MASTER]` doc, **`[M] Full Stack Codesign` tab** | "Full Stack Codesign" section, and the mission sentence in "About" |
| `[C] Minnesota Nanofabrication Club (MNF)/Engineering Structure` | "Team" section |
| `[C] Minnesota Nanofabrication Club (MNF)/Minnesota Nanofabrication Constitution` | "About" / "Get Involved" (purpose, membership eligibility) |
| `Build the Fab/<machine>/` | **one subpage per machine** — see below |
| `Design the IC/` | The second half of the "Full Stack Codesign" section on `index.html` |

> **A named source that does not exist is an error, not a no-op.**
>
> This table previously pointed the mission at `Minnesota Nanofabrication Club (MNF)/
> Project and Goals`. That document no longer exists — the mission moved into a *tab* of
> the top-level `[MASTER]` doc. The sync therefore looked for the mission in a place that
> was not there, found nothing to compare, and correctly obeyed "never invent, publish
> less" by leaving the section untouched. On 2026-08-30 the goal changed from a custom
> *compute kernel* to a custom *integrated circuit* and the site kept saying "compute
> kernel" through a run that reported success.
>
> So: **if a source named in this table cannot be found, stop and say so in the run
> summary and in the Discord report.** Do not treat a missing source as "nothing changed".
> Silence from a missing source is indistinguishable from silence from an unchanged one,
> and only one of those is safe.
>
> **Read tabs.** Several club docs put distinct subjects in separate tabs of one document.
> A doc export returns every tab concatenated; a reader that stops at the first tab will
> miss most of `[MASTER]`.

### One page per machine

Every subfolder of `Build the Fab` gets its own page. `index.html` lists them with their
current status and links to each.

| Drive folder | Page |
| --- | --- |
| `Maskless Lithography Stepper` | `stepper.html` |
| `DC Magnetron Sputterer` | `sputterer.html` |
| `Tube Furnace` | `tube-furnace.html` |
| `Reactive-Ion Etcher` | `etcher.html` |
| `Photoresist Spinner` | `spinner.html` |
| `Photoresist Developer` | `developer.html` |
| `Probe Station` | `probe-station.html` |
| `Ultrasonic Cleaner` | `ultrasonic-cleaner.html` |
| `Wafer Arm` | `wafer-arm.html` |

A new subfolder means a new page, added to the nav on every page and to `index.html`.
A folder tagged `[D]` or `[LR]` is not a machine and gets no page.

Each page carries, **only where a doc supports it**: the machine name, its current status,
`Lead: <name>` if a doc names one, "What It Does", "Subsystems", and a timeline.

**Omit a section rather than emptying it.** A heading with "TBD" underneath reads as a
promise the club has not made. A folder with nothing in it gets a page with the name, the
status, and one sentence saying there is no design documentation yet — not a description
written from general knowledge of what such a machine does. That description would come
from you, not from Drive, and rule 1 forbids it.

**Never borrow a description from another machine's doc.** If the stepper's master explains
what a spin coater does, that is the stepper's doc, not the spinner's.

### Leads

Publish `Lead:` only where the **text of a document states the owner**.

⚠️ **Never infer a lead from metadata.** Not from who owns a Drive file, not from who
created the folder, not from an email address in a document's properties, not from who last
edited it. A run on 2026-08-30 published "Lead: Davit Sandoyan" on the etcher and "Lead:
Andrew Choi" on the spinner and tube furnace purely because those accounts owned files in
those folders. No document said any of it. The review gate caught it before it reached the
site; without that gate it would have put two members' full names on a public, indexed page
on the strength of a file-ownership record.

Owning a file means somebody made a document. It does not mean they lead the project, and
inferring it invents an organisational fact about a real person. As of 2026-08-30 that is the stepper
(Leonard Jin) and the sputterer (Bear Blinschauer). The top-level `[MASTER]` tracker lists
`David` for the etcher — a bare first name matching nobody in `Engineering Structure`,
contradicted by the etcher's own doc which says `TBD`. **Do not publish it.** A guessed
identity on a public page is worse than no name at all. If a tracker cell disagrees with the
machine's own doc, the machine's doc wins.

Tag conventions used in Drive: `[LR]` = learning resource, `[D]` = documentation,
`[MASTER]` = the main outline doc for that folder and the first thing to read in it. `[LR]` folders are reference material
and are **not** published to the site.

**Ignore `Minnesota Nanofabrication Club (MNF)/Club Website — How It Works`.** That
doc explains this sync process to club members; it is documentation *about* the website,
not content *for* it. Never publish it. If it drifts out of step with this file or
`CLAUDE.md`, flag it in your summary — don't edit it silently.

## Canonical club name

The club is **Minnesota Nanofabrication Club**, short form **MNF**. Settled by Leo
2026-08-29.

Older Drive docs use "GopherFab" and "MNFC" — both are wrong and should be corrected
wherever they turn up. Some docs also use the full name and "MNF" interchangeably, and the
sponsorship letters claim "ten engineers" where `Engineering Structure` lists nine. None of
that variation belongs on the site: a club whose own pages disagree about its name cannot be
found by that name, and a search engine has no way to tell that four spellings are one
organisation. Publish the full name on first use and `MNF` thereafter. Do not carry a
headcount onto the site unless `Engineering Structure` states one.

## How to traverse the Drive

Read in this order. Later sources lose to earlier ones on the same fact.

1. **`CLAUDE.md`**, then this file. Standing decisions and precedence.
   Then **`DRIVE_NOTES.md`** — what the last run learned about the current state of Drive.
2. **The machine's own `[MASTER]` doc**, for everything about that machine.
3. **The machine's timeline doc**, if one exists *and is actually about that machine*.
4. **`Engineering Structure`**, for roles and names. Ground truth for people.
5. **The top-level `[MASTER]` tracker**, only for a status the machine's own doc does
   not give. It is frequently stale — see gray areas below.

**Skip entirely, never read for content:**

| Folder / doc | Why |
| --- | --- |
| `[LR] *` | Learning resources. Reference only. |
| `[C] Finances`, `[C] Funding`, `[C] Logistics` | Budgets, grant proposals, expense tables, lab-space and outreach logistics. Nothing here is publishable. |
| `[MASTER]` in `Build the Fab` | Despite the name, a vendor-outreach ledger: sponsorship letters to named companies, contact addresses, SKUs, response tracking. |
| Any `[BOM]` sheet | Costs and vendors. |
| Vendor / email / sponsorship sections inside any `[MASTER]` | The stepper's master carries five drafts of a vendor reply, a personal phone number, and notes profiling named individuals. Read past them. |
| `Club Website — How It Works` | Documentation *about* this sync, not content for the site. |

**Prioritize:** a machine's own doc over any tracker; prose written about the machine over
prose written about it inside a sponsorship letter; a doc that is specific over one that is
a template with the blanks unfilled.

## Gray areas — how to judge

The principle behind all of these: **when the evidence is weak, publish less.** A thin page
is honest. A confident page built on a guess is not, and nobody reading the site can tell
the difference.

- **An unfilled template is not content.** Rows reading `Task 1 (done) / Next: Task 2`, or a
  timeline whose every milestone body is empty, are boilerplate nobody edited. They are not
  milestones and must not be published as any.
- **Check that a doc is about the machine whose folder it sits in.** Docs get copied between
  folders and the copy is not always edited. If a timeline's stages describe a different
  process, it is not that machine's timeline.
- **A machine's own doc beats the top-level tracker** on that machine's status, description
  and owner. The tracker is frequently stale, and stale tracker state loses to what the
  folder actually contains.
- **Do not publish guidance the club marks unresolved.** A section that says it still needs
  input from the club or the advisor is not settled, and publishing it makes the site appear
  to give guidance nobody agreed to.
- **Publish specifications, not procedures, for anything dangerous.** High temperatures,
  mains wiring, vacuum, and process gases are fine to describe. Step-by-step instructions
  are not: a public page that reads as a procedure invites someone to follow it.
- **When two docs claim the same resource, link neither.** An ambiguous link is worse than
  no link.
- **Prose written to persuade is provisional.** Descriptions that exist only inside a
  sponsorship or outreach letter were written to win support, not to document. Use them only
  if nothing better exists, and strip the pitch.
- **Never publish a guessed identity.** A partial name, or a name from a source that another
  doc contradicts, does not go on a public page. No name is better than a wrong one.

**The specific cases these came from live in [`DRIVE_NOTES.md`](DRIVE_NOTES.md)**, which the
agent maintains and prunes. Rules go here; observations about what Drive contains right now
go there, so this file does not accumulate instructions that quietly stop being true.

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
