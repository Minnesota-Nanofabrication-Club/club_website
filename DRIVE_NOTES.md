# Drive notes

**Working memory for the sync agent. You maintain this file; a human maintains the rules.**

The agent that syncs this site has no memory between runs. Every run is a fresh container,
and the only thing that survives is what is written down. This file is where the agent
writes down what it learned about the *current state of Drive* — the quirks, the
half-finished docs, the contradictions it had to reason through — so the next run does not
have to re-derive them and possibly decide differently.

## This file is not the rules

| | Where | Who edits | Lifetime |
| --- | --- | --- | --- |
| **Rules and standing decisions** | `CLAUDE.md`, `SYNC.md` | humans only | permanent |
| **Observations about Drive right now** | this file | the sync agent | until they stop being true |

The distinction is the whole point. "When the evidence is weak, publish less" is a rule: it
is true regardless of what Drive contains, and it belongs in `SYNC.md`. "The etcher's
timeline doc is actually the stepper's, pasted in" is an observation: it is true today and
will stop being true the moment someone fixes that doc, at which point continuing to obey
it would suppress a perfectly good timeline.

**Never edit `CLAUDE.md` or `SYNC.md`.** The workflow will fail the run if you do. If you
believe a rule is wrong or missing, say so in your run summary and leave it to a human.

## How to maintain this file

Do this every run, as part of the sync:

1. **Check each entry's `REMOVE WHEN` condition.** You are reading these docs anyway. If
   the condition is met, delete the entry. An entry that has outlived its cause is worse
   than no entry — it is a confident instruction based on something that is no longer true.
2. **Add an entry only for something that cost you real reasoning** and that the next run
   would otherwise have to work out again. A fact you can see at a glance in the doc is not
   worth an entry.
3. **Every entry needs a `REMOVE WHEN`.** If you cannot write a condition under which the
   note should be deleted, it is probably a rule, not an observation — say so in your
   summary and let a human decide whether it belongs in `SYNC.md`.
4. **Cap: 20 entries.** At the cap, drop the least useful one rather than growing the file.
   If you are dropping something that still feels important, that is a signal worth putting
   in your run summary.
5. **Never record anything that must not be published.** No costs, vendor names, prices,
   contacts, or member names beyond those the rules already allow on the site. This file is
   in a public repository.

Date every entry so staleness is visible. If an entry has survived many runs unchanged, it
may be a rule in disguise — flag it in your summary rather than promoting it yourself.

---

## Entries

- **[2026-09-04] `Engineering Structure` is now titled `Organizational Structure`.** Same
  document: the officer list (President, Vice President, Officer, Faculty Club Advisor) and
  the `Project Leads` list are both still in it, and it is still ground truth for roles.
  `CLAUDE.md` and `SYNC.md` both name it by the old title — do not read the rename as the
  named source having gone missing and do not go looking for a second doc.
  **REMOVE WHEN:** the rules files use the current title, or the doc stops carrying the
  officer and `Project Leads` lists.

- **[2026-08-30] `Organizational Structure` carries a `Project Leads` list** naming a lead, in
  prose, for lithography, sputtering, the furnace, the spinner and the etcher. It is real
  document text, not metadata — quote it before dropping a `Lead:` line on the grounds that
  the machine's own doc is silent. The furnace and spinner `Lead:` lines come from here:
  neither folder's docs contain an owner field at all, and `CLAUDE.md` makes that doc ground
  truth for who owns which project. Both are officers already named on the site, so publishing
  them adds no new person to a public page.
  **REMOVE WHEN:** the `Project Leads` list disappears from that doc, or each machine's own
  `[MASTER]` names its lead directly.

- **[2026-09-04] The etcher still has no `Lead:` line, but the reason `SYNC.md` gives for
  that is now out of date.** Its `[MASTER]` was rewritten between 2026-08-31 and 2026-09-03:
  it is the etcher's own tracker now, not the stepper's pasted in, and its `Owner` cell reads
  `David` rather than `TBD`. So the contradiction `SYNC.md` cites ("contradicted by the
  etcher's own doc which says TBD") no longer exists, and `Organizational Structure` names an
  Etcher Lead in prose. `SYNC.md` still says in as many words not to publish an etcher lead,
  and this is the only lead in that list who is not already a published officer, so this run
  left the line off and flagged it for a human rather than putting a student's full name on an
  indexed page on its own judgement. Do not publish the bare first name either way.
  **REMOVE WHEN:** `SYNC.md`'s Leads section stops naming the etcher, or the etcher's own doc
  spells its owner's full name.

- **[2026-09-04] The etcher's timeline doc now agrees with itself.** The per-stage
  `Timeline:` headings and the Schedule Summary table give the same schedule (Weeks 2–4, 4–8,
  9–10, 11–12, 13–15) and no longer match the stepper's, and the stepper leftovers are gone,
  so the week numbers are published. Its first stage is a funding-approval milestone and its
  own doc is the only source for it — that stage stays off the site as funding status.
  **REMOVE WHEN:** the two sets of dates in that doc disagree again.

- **[2026-08-30] `Club Website — How It Works` was rewritten on 2026-08-30 and now agrees
  with `SYNC.md` about the mechanism** — ten pages, a cloud job, the `[MASTER]` tab as the
  mission source. One disagreement is left, and it is a real privacy decision: the doc still
  tells members "Only officers and the faculty advisor are published" and "Listing is
  opt-in", where `CLAUDE.md` records Leo deliberately reversing that for machine leads on
  2026-08-29. Nothing on the site turns on it today, because every lead currently published
  is also an officer. Flag it; do not resolve it.
  **REMOVE WHEN:** that doc's "not published" section matches `CLAUDE.md`'s machine-lead
  rule, or a human reconciles the two.

- **[2026-08-30] Two copies of `Club Website — How It Works` now sit in the club folder,**
  the older one titled `Club Website — How It Works (superseded 2026-08-30)`. Neither is ever
  published, but if you read either, read the untagged one: the superseded copy still
  describes a two-page site, sources the mission from the deleted `Project and Goals` doc,
  and says the sync runs on a laptop.
  **REMOVE WHEN:** the superseded copy is no longer in the club folder.

- **[2026-08-30] The club folder is now tagged `[C] Minnesota Nanofabrication Club (MNF)`.**
  The `[C]` prefix does **not** mean skip it. `SYNC.md`'s skip list names `[C] Finances`,
  `[C] Funding` and `[C] Logistics` specifically, and this folder holds `Engineering
  Structure` and the Constitution — both required reading.
  **REMOVE WHEN:** the folder is no longer tagged `[C]`, or `SYNC.md`'s skip list is
  rewritten to cover the tag rather than those three named folders.

- **[2026-08-30] `Project and Goals` is no longer in the club folder.** `SYNC.md` has since
  been corrected to point at the root `[MASTER]`, whose `[M] Full Stack Codesign` tab is the
  only place the framing now lives: the "Every abstraction exists for a reason" paragraph
  under `Full Stack Design and Assembly`, and a one-line `Plan: Build the Fab`. Do not delete
  the section over the missing doc.
  **REMOVE WHEN:** a `Project and Goals` doc reappears in the club folder.

- **[2026-08-30] The spinner and the tube furnace link the same Excalidraw diagram.** At
  least one label is wrong, so neither is safe to embed or link.
  **REMOVE WHEN:** the two docs link different URLs.

- **[2026-08-30] The tracker marks the Ultrasonic Cleaner `In Progress` while its folder is
  empty** and its update cell holds unedited template text. Treat as `Planned`.
  **REMOVE WHEN:** the Ultrasonic Cleaner folder contains any document.

- **[2026-08-30] The tracker says the Tube Furnace is `Not Started`; its own timeline says
  design and calculations are complete.** The machine's doc wins, so the site says "Design
  complete".
  **REMOVE WHEN:** the tracker and the furnace's own doc agree on a status.

- **[2026-08-30] The sputterer's safety section is marked unresolved** — it says repeatedly
  that it "needs input from MNC and advisor". Omitted from the site entirely.
  **REMOVE WHEN:** the safety section no longer says it needs input from the club or advisor.

- **[2026-08-31] The vendor-outreach ledger in `Build the Fab` has been renamed from
  `[MASTER]` to `[MASTER] Funding Emails`,** which is what it always was: sponsorship
  letters, contact addresses, SKUs, response tracking. `SYNC.md`'s skip list still names it
  by the old title. Nothing in it is publishable, and the machine descriptions inside it
  were written to persuade rather than to document.
  **REMOVE WHEN:** that doc's content is primarily an overview of the fab line rather than
  vendor correspondence.

- **[2026-08-31] The root `[MASTER]` doc is now titled `[MASTER] Status & Priorities`.**
  `CLAUDE.md` and `SYNC.md` both call it `[MASTER]`; it is the same document and still
  carries the `[M] Full Stack Codesign` tab that the mission framing comes from. Do not read
  the rename as the named source having gone missing.
  **REMOVE WHEN:** that doc no longer carries the `[M] Full Stack Codesign` tab, or the rules
  files are updated to use its current title.

- **[2026-08-30] The Probe Station's only description anywhere lives inside a sponsorship
  letter.** Treat as provisional; strip the pitch if used at all.
  **REMOVE WHEN:** the Probe Station folder contains a doc describing the machine.

- **[2026-09-04] The `[M] Full Stack Codesign` tab was rewritten and the old framing is gone
  from Drive entirely.** Its heading is now "Full Stack Design and Fabrication", and the
  "Every abstraction exists for a reason" paragraph the site carried since August appears
  nowhere in the mirror. What replaced it: computing scale as the defining challenge of the
  decade, "we believe we should understand the entire computing stack. Our mission is to gain
  that understanding by building it ourselves", and "No prerequisites." The `Plan: Build the
  Fab` line now ends "by the end 2026 fall semester". Do not restore the old wording from an
  older copy of the site.
  **REMOVE WHEN:** that tab is rewritten again — i.e. the site's About section no longer
  matches it.

- **[2026-09-04] Three machine folders appeared under `Build the Fab`: Microplotter,
  Spin-on Doping and Hot Plate.** The Microplotter's source is a `Microplotter Project
  Proposal`, not a `[MASTER]` — the page's "Proposed" status comes from the doc being a
  proposal with no progress recorded anywhere, and its Budget table, its cost comparison
  against a commercial instrument and its "Open questions" section are all unpublishable.
  Spin-on Doping's `[MASTER]` is a zero-byte document and Hot Plate's folder is empty, so both
  get a bare `Planned`.
  **REMOVE WHEN:** the Microplotter folder gains a `[MASTER]` or a record of build progress,
  or either of the other two folders gains a document with content.

- **[2026-09-04] `Club Website — How It Works` has drifted further from the site.** It tells
  members the site has ten pages and lists nine machines; `Build the Fab` now holds twelve
  machine folders, so the site has thirteen pages. It also names the roles doc by its old
  title, and §6 tells members that excluded material "is not fetched at all" — but the mirror
  does contain the vendor-outreach ledger, the advisor-outreach doc and the BOM sheets, so
  that exclusion rests on the agent not publishing them, not on their being withheld. Flag it;
  never edit it and never publish from it.
  **REMOVE WHEN:** that doc's page count matches the number of machine folders, or a human
  reconciles it.
