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

- **[2026-08-31] The etcher's timeline doc has been rewritten and is now genuinely the
  etcher's**, with filled-in milestones about vacuum, gas flow and toxic-gas testing. It is
  publishable — but its dates are not. The per-stage `Timeline:` headings are still the
  stepper's numbers byte for byte (Week 1, Weeks 2–5, 6–9, 10–12, 13–15), while its own
  Schedule Summary table gives a different set (Weeks 2–4, 4–8, 9–10, 11–12). One of the two
  is unedited template and there is nothing in the doc that says which, so the site publishes
  the stages and milestones without week numbers. One sub-stage, "Exposure Process
  Development", is also stepper leftover — do not publish it as an etcher stage.
  **REMOVE WHEN:** the two sets of dates in that doc agree, or the per-stage headings stop
  matching the stepper timeline's.

- **[2026-08-30] `Engineering Structure` carries a `Project Leads` list** naming a lead, in
  prose, for lithography, sputtering, the furnace, the spinner and the etcher. It is real
  document text, not metadata — quote it before dropping a `Lead:` line on the grounds that
  the machine's own doc is silent. The furnace and spinner `Lead:` lines come from here:
  neither folder's docs contain an owner field at all, and `CLAUDE.md` makes `Engineering
  Structure` ground truth for who owns which project. Both are officers already named on the
  site, so publishing them adds no new person to a public page.
  **REMOVE WHEN:** the `Project Leads` list disappears from `Engineering Structure`, or each
  machine's own `[MASTER]` names its lead directly.

- **[2026-08-30] The etcher is the one machine where that list is contradicted, so its
  `Lead:` line was removed.** Unlike the furnace and spinner, the etcher's own `[MASTER]` has
  an `Owner` column and every row of it reads `TBD`. `SYNC.md` also says in as many words not
  to publish an etcher lead. Machine's own doc wins, and this is the only lead in the list who
  is not already a published officer. Do not read the table's "Done" marks as a human having
  filled in the owner question and left it open — the whole table is a copy, see the next entry.
  **REMOVE WHEN:** the etcher's own `[MASTER]` names an owner instead of `TBD`, or `SYNC.md`
  stops saying not to publish one.

- **[2026-08-30] The etcher's `[MASTER]` tracker is the stepper's tracker pasted in with the
  `Description` column blanked.** Its rows still carry the stepper's ThorLabs sponsorship
  entry, the stepper's "Prof. Ilic (9/3)" milestone and the same three untouched
  `Task 1 (done) / Next: Task 2` template rows. None of that is etcher progress, and the real
  dates and "Done" marks in it belong to the stepper. The etcher's `In Progress` status is
  independently supported by the top-level tracker, whose etcher row is hand-written; nothing
  else in the etcher's own doc says anything about the etcher.
  **REMOVE WHEN:** the etcher's `[MASTER]` has `Description` cells naming etcher work, or its
  rows no longer match the stepper's tracker.

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
