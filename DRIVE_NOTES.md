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

- **[2026-08-30] `Organizational Structure` carries a `Project Leads` list** naming a lead, in
  prose, for lithography, sputtering, the furnace, the spinner and the etcher. It is real
  document text, not metadata — quote it before dropping a `Lead:` line on the grounds that
  the machine's own doc is silent. The furnace and spinner `Lead:` lines come from here:
  neither folder's docs contain an owner field at all, and `CLAUDE.md` makes this doc
  ground truth for who owns which project. Both are officers already named on the
  site, so publishing them adds no new person to a public page.
  **REMOVE WHEN:** the `Project Leads` list disappears from that doc, or each
  machine's own `[MASTER]` names its lead directly.

- **[2026-09-05] The etcher still has no `Lead:` line, and the reason has changed.** Its own
  `[MASTER]` was rewritten and is now genuinely the etcher's: one hand-written row for the
  V1.0 design doc, `In Progress`, plus two empty template rows. That row's `Owner` cell no
  longer reads `TBD` — it reads a bare first name, one letter off the full name the
  `Project Leads` list gives for the etcher. So the contradiction that removed the line is
  gone, but `SYNC.md` still says in as many words not to publish an etcher lead, and this is
  the only lead in that list who is not already a published officer. `Club Website — How It
  Works` also promises members that publishing a person's name requires that person's
  agreement. Left unpublished and flagged for a human; a name on a public indexed page is
  not the sync's call to make.
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
  page per machine for nine named machines (there are now sixteen untagged folders under
  `Build the Fab`, fifteen of them machines with pages), and it sources the officer team from
  `Engineering Structure`, which has been renamed. Flag them; do not resolve them.
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

- **[2026-09-15] The mission tab's `Plan: Build the Fab` line now gives a deadline that has
  already passed, so the site publishes the goal without one.** The heading is
  `Full Stack Design and Fabrication` and the prose around it (scaling computing systems,
  "understand the entire computing stack ... by building it ourselves", "No prerequisites")
  is unchanged, but the Plan line's deadline moved from the end of the 2026 fall semester to
  "by the end 2026 Spring semester" — a semester that ended before this run. A date already
  past is not publishable as a target, and picking which future semester was meant would be
  inventing one, so `index.html` carries the goal sentence with no deadline. An internal
  `[D]` deck states an end-of-Spring-2027 goal, which suggests the tab is mis-typed rather
  than genuinely re-planned, but a `[D]` deck is not a content source and nothing was
  published from it.
  **REMOVE WHEN:** the Plan line names a deadline that has not already passed.

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

- **[2026-09-15] Six machine folders now sit under `Build the Fab` that `SYNC.md`'s page
  table does not list:** `Hot Plate` (empty), `Spin-on Doping` (one empty `[MASTER]`),
  `Electron Microscope` (empty), `Inkjet Microplotter`, `DI Water Filtration` (one doc
  holding only a title) and `Laser Interferometry`. `Inkjet Microplotter` is the folder
  `SYNC.md`-era notes called `Microplotter`; it was renamed around 2026-09-10 and the page
  stayed at `microplotter.html` so the published URL would not break. Its proposal names
  three people as members but no owner or lead, so its page carries none, and its budget
  table and its open questions for an outside contact are not publishable. Laser
  Interferometry has a real system overview and gets `Architecture design`; the rest get a
  bare `Planned`. No tracker anywhere mentions any of the six, so their status comes from
  what their folders contain and nothing else.
  **REMOVE WHEN:** `SYNC.md`'s page table lists these six, or their folders are gone.

- **[2026-09-15] `Build the Fab/Firmware` is not a machine and deliberately has no page.**
  Its `[Master]` says the directory "contains all things firmware related for the entire
  project" — a BOM for firmware parts, requirements, high- and low-level design — with all
  code in a GitHub repo. It is a cross-cutting engineering directory, not a fabrication tool,
  so calling it a machine on the site would be a claim no document supports. It carries no
  `[D]` or `[LR]` tag, so the usual "tagged folders are not machines" test does not catch it;
  this is a judgment from the doc's own text. Note that its `[Master]` does name a sublead in
  prose, which would be a publishable lead if a human ever decides the folder earns a page.
  **REMOVE WHEN:** the folder documents a physical tool being built, or a human says it
  should have a page.

- **[2026-09-15] The `[D] Project Team Presentations` deck assigns several machines to
  different people than `Organizational Structure` does.** The deck, updated the day before
  this run, hands the furnace and the spinner to members other than the officer the
  `Project Leads` list names for both, adds owners for machines that list does not cover, and
  frames the whole split as a proposed reorganisation it calls "not immediate". It sits in a
  `[D]` folder, it identifies people by first name only, and `CLAUDE.md` makes
  `Organizational Structure` ground truth for who owns which project — so the site's `Lead:`
  lines were left exactly as they were. Flagged for a human; do not reconcile from the deck.
  **REMOVE WHEN:** the `Project Leads` list names the same people the deck does, or a human
  resolves it either way.

- **[2026-09-15] A new top-level `Radiation Hardening` folder holds an IC project proposal,
  and nothing from it is published.** It is the first document anywhere describing the IC
  half of the programme — mission profile, radiation modelling, a ~2,000-transistor design to
  be fabricated on the club's own line and then tested. `SYNC.md`'s table maps that half of
  the site to `Design the IC/`, which is still an empty folder, and this folder is mapped to
  nothing. It is also a proposal rather than design documentation, so `index.html` still says
  the IC half has no design documentation yet. Flagged for a human.
  **REMOVE WHEN:** `SYNC.md`'s table names this folder, the folder is gone, or a human says
  to publish from it.

- **[2026-09-15] The Drive root folder is now titled `Ultra Hardcore Design & Fabrication`.**
  The id is unchanged (`1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP`), so this is the second rename of
  the same folder, not a missing source. `CLAUDE.md` and `SYNC.md` still call it "Ultra
  Hardcore Chip D&F" and "Ultra Hardcore Chip Codesign" respectively.
  **REMOVE WHEN:** the rules files use the current title, or the root is renamed again.

- **[2026-08-30] The Probe Station's only description anywhere lives inside a sponsorship
  letter.** Treat as provisional; strip the pitch if used at all.
  **REMOVE WHEN:** the Probe Station folder contains a doc describing the machine.
