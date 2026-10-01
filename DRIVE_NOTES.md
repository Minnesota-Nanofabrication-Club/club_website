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
  the machine's own doc is silent. The furnace `Lead:` line comes from here: that folder's
  docs contain no owner field at all, and `CLAUDE.md` makes this doc ground truth for who
  owns which project. He is an officer already named on the site, so publishing him adds no
  new person to a public page. The spinner no longer takes its lead from this list — see the
  spinner entry below.
  **REMOVE WHEN:** the `Project Leads` list disappears from that doc, or each
  machine's own `[MASTER]` names its lead directly.

- **[2026-10-01] The etcher's own `[MASTER]` and timeline doc are both gone from its folder.**
  What is left is a `Component Library` of per-part sourcing records, an `Advanced ICP-RIE`
  BOM and parts tracker, and one letter asking an outside professor for design advice — all
  three unpublishable under `SYNC.md`'s skip list. The site therefore carries only the
  etcher's name and the `In Progress` status from the root tracker's row, which is what
  `SYNC.md` prescribes when a machine's own doc records no progress. The "What It Does" and
  "Project Timeline" sections the page used to carry came from the two deleted docs and were
  removed on 2026-10-01; do not restore them from memory of an earlier version of the site.
  **REMOVE WHEN:** the etcher folder contains a design document or project timeline again.

- **[2026-10-01] Still no etcher `Lead:`, and the sources have thinned rather than agreed.**
  `Project Leads` names an Etcher Lead; the root tracker's etcher row carries a bare first
  name one letter off that full name; the etcher's own `[MASTER]`, which used to be the
  tiebreaker, no longer exists. `SYNC.md` says in as many words not to publish an etcher
  lead, and this is the only lead in that list who is not already a published officer.
  `Club Website — How It Works` also promises members that publishing a person's name
  requires that person's agreement. Left unpublished and flagged for a human.
  **REMOVE WHEN:** `SYNC.md` stops saying not to publish an etcher lead, or a human resolves
  it either way.

- **[2026-10-01] The spinner's `Lead:` line was removed, because its own folder now
  contradicts `Organizational Structure`.** `Project Leads` names an officer as Spinner Lead;
  the spinner's own `[Master]` gives a different, bare first name as the owner of its design
  doc, and its timeline doc says in prose that the same person "leads Spinner in Gen 1".
  A first name on its own is a guessed identity and cannot be published, and the officer's
  name is now a name "from a source that another doc contradicts" — `SYNC.md` forbids both,
  so the page names nobody. Do not quietly restore either one.
  **REMOVE WHEN:** `Organizational Structure` and the spinner's own docs name the same
  person, or either gives a full name the other does not contradict.

- **[2026-08-30] `Club Website — How It Works` still agrees with `SYNC.md` about the
  mechanism** — a cloud job, the `[MASTER]` tab as the mission source — and has not been
  touched since 2026-08-30. Three disagreements are left. The real one is a privacy
  decision: the doc still tells members "Only officers and the faculty advisor are
  published" and "Listing is opt-in", where `CLAUDE.md` records Leo deliberately reversing
  that for machine leads on 2026-08-29. Nothing on the site turns on it today, because every
  lead currently published is also an officer. The other two are staleness: it says the site
  has ten pages and one page per machine for nine named machines (as of 2026-10-01 there are
  fifteen machine folders worth publishing, and sixteen pages), and it sources the officer
  team from `Engineering Structure`, which has been renamed. A second, older copy titled
  `Club Website — How It Works (superseded 2026-08-30)` also sits in the club folder; if you
  read either, read the untagged one. Flag these; do not resolve them.
  **REMOVE WHEN:** that doc's "not published" section matches `CLAUDE.md`'s machine-lead
  rule, or a human reconciles the two.

- **[2026-10-01] The club folder is tagged `[C] Minnesota Nanofabrication Club (MNF)`, and
  the `[C]` prefix does not mean skip.** `SYNC.md`'s skip list names `[C] Finances`,
  `[C] Funding` and `[C] Logistics`; none of those three titles exists any more. The `[C]`
  folders now in Drive are `Club Collabs`, `Finance`, `Funding Applications`,
  `Minnesota Nanofabrication Club (MNF)` and `Outreach and Events`. The club folder holds
  `Organizational Structure` and the Constitution and is required reading; the finance,
  funding and outreach folders are the ones the skip list is aiming at.
  **REMOVE WHEN:** `SYNC.md`'s skip list is rewritten to match the folder titles actually in
  Drive.

- **[2026-08-30] `Project and Goals` is no longer in the club folder.** `SYNC.md` has since
  been corrected to point at the root `[MASTER]`, whose `[M] Full Stack Codesign` tab is the
  only place the framing now lives. Do not delete the section over the missing doc.
  **REMOVE WHEN:** a `Project and Goals` doc reappears in the club folder.

- **[2026-10-01] The `Build the Fab` plan deadline moved out by two semesters.** The
  `[M] Full Stack Codesign` tab now reads "by the end 2027 Spring semester"; it said the end
  of the 2026 fall semester through the 2026-09-06 run, and the site followed the old date
  until 2026-10-01. The rest of that tab — the scaling-computing-systems framing, the
  one-line mission, the "No prerequisites" invitation — is unchanged.
  **REMOVE WHEN:** that line's deadline changes again.

- **[2026-10-01] The root Drive folder is now titled `Ultra Hardcore Design & Fabrication`.**
  `CLAUDE.md` and `SYNC.md` both call it `Ultra Hardcore Chip D&F`. The id is unchanged
  (`1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP`), so this is the same folder renamed again, not a
  missing source. Flagged for a human; the rules files are not the agent's to edit.
  **REMOVE WHEN:** the rules files use the folder's current title, or the folder is renamed
  again.

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

- **[2026-10-01] Six machine folders under `Build the Fab` are not in `SYNC.md`'s page
  table:** `Hot Plate` (empty), `Spin-on Doping` (one `[MASTER]` doc with nothing in it),
  `Electron Microscope` (empty), `Inkjet Microplotter`, `Laser Interferometry` and
  `DI Water Filtration` (one doc holding only its own title). The Microplotter — the folder
  was `Microplotter` until it was renamed, so the page is still `microplotter.html` — has a
  project proposal with objectives and a technical overview; it names three people as members
  but no owner or lead, so its page carries none, and its budget table, its parts lists and
  its open questions for an outside contact are not publishable. Laser Interferometry has a
  system overview describing a proposed heterodyne architecture, plus a timeline doc that
  says its own dates are not set yet. The rest get a bare `Planned`. No tracker mentions any
  of the six, so their status comes from what their folders contain and nothing else.
  **REMOVE WHEN:** `SYNC.md`'s page table lists these six, or their folders are gone.

- **[2026-10-01] Four folders under `Build the Fab` are not machines and have no page.**
  `Alignment Firmware` and `Computer Vision Alignment` are stepper software subsystems —
  their `[Master]` docs are a to-do tracker and an empty file, and the stepper page already
  describes both in its Subsystems list. `Process Design` is the fab's process recipe (wafer
  and resist specs, then step-by-step priming, coating, bake, exposure and develop
  parameters): `SYNC.md` says to publish specifications rather than procedures for anything
  hazardous, and an SOP sheet is a procedure. `Web Development` is a to-do tracker for this
  website, so it is documentation about the site rather than content for it. None carries the
  `[D]` tag that `SYNC.md` uses to exclude a folder, so the next run will have to make this
  call again unless a human writes it down.
  **REMOVE WHEN:** `SYNC.md` says how to treat an untagged `Build the Fab` folder that is not
  a machine, or these four are tagged `[D]`.

- **[2026-10-01] A new top-level `Radiation Hardening` folder holds an IC design project, and
  `SYNC.md`'s table does not cover it.** Its proposal is to define a space mission profile,
  model the radiation environment, design a roughly 2,000-transistor radiation-hardened IC,
  fabricate it on the club's own line and characterise it under radiation exposure. The table
  maps the site's "Design the IC" half to the `Design the IC/` folder, which is still empty,
  so the site still says that half has no design documentation yet — which is now arguably
  false. Left alone because adding a source-to-section mapping is a rule change. Note also
  that the proposal opens by describing the DoD workforce program behind it, and that a
  sibling folder under `[C] Funding Applications` is a funding application to the same
  program; the funding side of it is not publishable.
  **REMOVE WHEN:** `SYNC.md`'s table says which part of the site `Radiation Hardening` feeds,
  or the folder moves under `Design the IC`.

- **[2026-08-30] The Probe Station's only description anywhere lives inside a sponsorship
  letter.** Treat as provisional; strip the pitch if used at all.
  **REMOVE WHEN:** the Probe Station folder contains a doc describing the machine.
