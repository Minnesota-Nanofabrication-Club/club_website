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

- **[2026-08-30] The etcher's timeline doc is the stepper's, pasted in.** Its stages are
  lithography steps — "Photoresist Patterning and Validation", "Exposure Process
  Development" — and every milestone body is empty. Do not publish it as the etcher's plan.
  **REMOVE WHEN:** the etcher's timeline doc describes etching stages rather than exposure
  or photoresist patterning, or its milestone bodies are filled in.

- **[2026-08-30] `Engineering Structure` now carries a `Project Leads` list** naming a lead,
  in prose, for lithography, sputtering, the furnace, the spinner and the etcher. That list
  is where the furnace, spinner and etcher `Lead:` lines on the site come from: those three
  machines' own `[MASTER]` docs name nobody, and `CLAUDE.md` makes `Engineering Structure`
  ground truth for who owns which project. Their `TBD` owner cells are unedited template
  blanks, not a contradiction. Do not drop those names just because the machine's own doc is
  silent — check this list first.
  **REMOVE WHEN:** the `Project Leads` list disappears from `Engineering Structure`, or each
  machine's own `[MASTER]` names its lead directly.

- **[2026-08-30] The club folder is now tagged `[C] Minnesota Nanofabrication Club (MNF)`.**
  The `[C]` prefix does **not** mean skip it. `SYNC.md`'s skip list names `[C] Finances`,
  `[C] Funding` and `[C] Logistics` specifically, and this folder holds `Engineering
  Structure` and the Constitution — both required reading.
  **REMOVE WHEN:** the folder is no longer tagged `[C]`, or `SYNC.md`'s skip list is
  rewritten to cover the tag rather than those three named folders.

- **[2026-08-30] `Project and Goals` is no longer in the club folder,** though `SYNC.md`
  still lists it as the source for "Full Stack Codesign". That framing now traces only to
  the root `[MASTER]`, which carries the "Every abstraction exists for a reason" paragraph
  and a one-line "Plan: Build the Fab". Do not delete the section over the missing doc.
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

- **[2026-08-30] `[MASTER]` in `Build the Fab` is a vendor-outreach ledger, not an overview
  doc,** despite the name. Sponsorship letters, contact addresses, SKUs, response tracking.
  Nothing in it is publishable, and the machine descriptions inside it were written to
  persuade rather than to document.
  **REMOVE WHEN:** that doc's content is primarily an overview of the fab line rather than
  vendor correspondence.

- **[2026-08-30] The Probe Station's only description anywhere lives inside a sponsorship
  letter.** Treat as provisional; strip the pitch if used at all.
  **REMOVE WHEN:** the Probe Station folder contains a doc describing the machine.
