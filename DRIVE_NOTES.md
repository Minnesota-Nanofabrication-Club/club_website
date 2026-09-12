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

- **[2026-09-05] `Engineering Structure` no longer exists under that name.** The club folder
  now holds `Organizational Structure` (last modified 2026-09-02), whose text is the same
  material: the four club-and-project officers, then a `Project Leads` list. `CLAUDE.md` and
  `SYNC.md` both still name `Engineering Structure` as ground truth for roles, and
  `SYNC.md` says a named source that cannot be found is an error rather than a no-op — so
  this is a rename to follow, not a missing source, but the rules files say a name that is
  no longer in Drive. Flagged for a human; do not edit those files.
  **REMOVE WHEN:** the rules files name `Organizational Structure`, or a doc called
  `Engineering Structure` is back in the club folder.

- **[2026-09-12] The `Project Leads` list in `Organizational Structure` is now contradicted
  for two machines, and both `Lead:` lines came off the site.** That list (still real document
  text, not metadata — quote it before dropping a `Lead:` line) gives Lithography → Leonard Jin,
  Sputtering → Bear BlinSchauer, Furnace and Spinner → Andrew Choi, Etcher → Davit Sandoyan.
  A newer deck, `Build the Fab/[D] Project Team Presentations/MNF Project Team 9-14`
  (modified 2026-09-12, ten days after that doc), carries a full role list assigning the
  furnace and the spinner to two other people, named only by first name and matching nobody
  in `Organizational Structure`. Lithography and sputtering agree across both, so those two
  `Lead:` lines stand; furnace and spinner were removed rather than published against the
  newer source, and the first names in the deck are not publishable identities. Flagged for a
  human — a roles doc and a project deck disagreeing about who owns two machines is not the
  sync's call to settle.
  **REMOVE WHEN:** `Organizational Structure` and the project-team deck name the same furnace
  and spinner leads, or a human resolves which source wins.

- **[2026-09-05] The etcher still has no `Lead:` line, and the reason has changed.** Its own
  `[MASTER]` was rewritten and is now genuinely the etcher's: one hand-written row for the
  V1.0 design doc, `In Progress`, plus two empty template rows. That row's `Owner` cell no
  longer reads `TBD` — it reads a bare first name, one letter off the full name the
  `Project Leads` list gives for the etcher. So the contradiction that removed the line is
  gone, but `SYNC.md` still says in as many words not to publish an etcher lead, and this is
  the only lead in that list who is not already a published officer. The project-team deck
  uses the same bare first name for the etching lead, so all three sources still stop short of
  a full name that two of them agree on. `Club Website — How It Works` also promises members
  that publishing a person's name requires that person's agreement. Left unpublished and
  flagged for a human; a name on a public indexed page is not the sync's call to make.
  **REMOVE WHEN:** `SYNC.md` stops saying not to publish an etcher lead, or a human resolves
  it either way.

- **[2026-09-05] The etcher's timeline doc is now internally consistent enough to publish
  week numbers, and the site publishes its Schedule Summary.** The per-stage `Timeline:`
  headings no longer match the stepper's (they now read Week 1, 2–4, 4–7, 9, 11, 13–15).
  One disagreement is left: Stage 2 is headed Weeks 4–7 while the Schedule Summary says
  Weeks 4–8, and Stage 2's own sub-stages run into week 8 — so the summary is the edited
  number and the heading is the stale one. The Pre-Semester stage is omitted from the site
  because its only milestone is a funding approval.
  **REMOVE WHEN:** the Stage 2 heading and the Schedule Summary agree, or the per-stage
  headings match the stepper timeline's again.

- **[2026-08-30] `Club Website — How It Works` was rewritten on 2026-08-30 and still agrees
  with `SYNC.md` about the mechanism** — a cloud job, the `[MASTER]` tab as the mission
  source. Three disagreements are left. The real one is a privacy decision: the doc still
  tells members "Only officers and the faculty advisor are published" and "Listing is
  opt-in", where `CLAUDE.md` records Leo deliberately reversing that for machine leads on
  2026-08-29. Nothing on the site turns on it today, because every lead currently published
  is also an officer. The other two are staleness: it says the site has ten pages and one
  page per machine for nine named machines (there are now fourteen machine folders and
  fifteen pages), and it sources the officer team from `Engineering Structure`, which has
  been renamed. Flag them; do not resolve them.
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
  only place the framing now lives. Do not delete the section over the missing doc.
  **REMOVE WHEN:** a `Project and Goals` doc reappears in the club folder.

- **[2026-09-05] The mission prose in that tab was rewritten and the old framing is gone.**
  The heading is now `Full Stack Design and Fabrication` (was `...and Assembly`) and the
  "Every abstraction exists for a reason" paragraph the site used to quote has been replaced
  by the scaling-computing-systems framing, a one-line mission ("understand the entire
  computing stack ... by building it ourselves") and a "No prerequisites" invitation. The
  site follows the new text. If a page still says "every abstraction exists for a reason",
  it is stale, not sourced.
  **REMOVE WHEN:** nothing on the site quotes the old framing and no rules file refers to it.

- **[2026-09-12] The `Plan: Build the Fab` deadline is not publishable right now: two docs
  disagree and one of them reads as a slip.** The `[M] Full Stack Codesign` tab says the IC is
  to be demonstrated "by the end 2026 Spring semester" — a semester already past — while the
  project-team deck opens with "End of Spring 2027 semester tape-out an integrated electrical
  circuit". The site carried "end of the 2026 fall semester" from an earlier version of the
  tab, which nothing in Drive now says, so the sentence was left with no date at all rather
  than picking one. Do not restore a deadline until the two agree.
  **REMOVE WHEN:** the mission tab and the project-team deck give the same deadline.

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

- **[2026-09-12] Five machine folders now sit under `Build the Fab` that `SYNC.md`'s
  page table does not list:** `Hot Plate` (empty), `Spin-on Doping` (one `[MASTER]` doc with
  nothing in it), `Electron Microscope` (empty), `DI Water Filtration` (one doc holding only
  its own title, appeared 2026-09-12) and `Inkjet Microplotter`, which was called
  `Microplotter` until about 2026-09-10 — the page kept the `microplotter.html` filename so
  links do not break, and only the machine name on the page changed. Only the microplotter
  has content: a project proposal with objectives, a technical overview and open questions,
  plus a parts list. That proposal names three people as members but no owner or lead, so its
  page carries none; its budget table and its open questions for an outside contact are not
  publishable. The other four get a bare `Planned`. No tracker anywhere mentions any of the
  five, so their status comes from what their folders contain and nothing else.
  **REMOVE WHEN:** `SYNC.md`'s page table lists these five, or their folders are gone.

- **[2026-09-12] `Meeting Notes` in the `Inkjet Microplotter` folder is not about the
  microplotter.** It is a 9/10 meeting record about wafer sizes, tilted alignment in software,
  manual versus motorised XYZ adjustment and a conference submission — stepper and club-wide
  material that happens to sit in that folder. Nothing on the microplotter page comes from it.
  **REMOVE WHEN:** that document describes microplotter work.

- **[2026-09-12] The IC half of the programme is documented outside `Design the IC`.** That
  folder is still empty; the IC work lives in a top-level `Radiation Hardening` folder holding
  a project proposal — a roughly 2,000-transistor radiation-hardened IC for a spacecraft
  application, to be fabricated on the club's own line and then characterised under radiation.
  The site's "Design the IC" section now follows that proposal, so it no longer says there is
  no documentation. The proposal's first section describes the funding program the work sits
  under; that part is not published.
  **REMOVE WHEN:** the proposal moves into `Design the IC`, or `SYNC.md`'s table names the
  `Radiation Hardening` folder.

- **[2026-09-12] The Drive root folder is now titled `Ultra Hardcore Design & Fabrication`.**
  `CLAUDE.md` and `SYNC.md` both call it "Ultra Hardcore Chip D&F"; the folder id
  `1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP` is unchanged, so this is the same folder renamed again,
  not a missing source. Flagged for a human; do not edit those files.
  **REMOVE WHEN:** the rules files name the folder's current title, or it is renamed again.

- **[2026-08-30] The Probe Station's only description anywhere lives inside a sponsorship
  letter.** Treat as provisional; strip the pitch if used at all.
  **REMOVE WHEN:** the Probe Station folder contains a doc describing the machine.
