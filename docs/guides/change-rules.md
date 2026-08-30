# Guide: Change a Publishing Rule

How to change what the site is allowed to publish. The rules live in **three** places that
have to agree — `CLAUDE.md`, `SYNC.md`, and the prompt string inside
`.github/workflows/sync-from-drive.yml` — and a change that touches only one of them leaves
the sync agent following the old rule.

---

## The three places a rule lives

| File | Role | What it holds |
| --- | --- | --- |
| `CLAUDE.md` | the **why** | Standing decisions, the source-of-truth precedence table, and the reasoning that is not recoverable from the code or the Drive docs |
| `SYNC.md` | the **how** | The Drive → page mapping, the numbered publishing rules, the gray-area judgements, and what a run does |
| `.github/workflows/sync-from-drive.yml` | the **executed instruction** | The `prompt:` block passed to `claude-code-action`, which restates several rules inline and orders the agent to read `CLAUDE.md` first, then `SYNC.md`, then `DRIVE_NOTES.md` |

The prompt is a deliberate subset, not a copy. It restates the rules with the worst
consequences so the agent has them before it opens a single file, and delegates the rest to
the Markdown files it tells the agent to read.

!!! warning "`DRIVE_NOTES.md` is a fourth file the agent reads, and it is not one of these"
    It holds the agent's own observations about the current state of Drive, each with a
    `REMOVE WHEN` condition, and **the agent edits it**. A rule never goes there: a rule is
    true regardless of what Drive contains, so it has no removal condition, and anything the
    agent can rewrite is not a rule. If you find yourself wanting to put an instruction in
    `DRIVE_NOTES.md`, it belongs in `SYNC.md`. See
    [the three-tier memory model](../architecture/overview.md#the-three-tier-memory-model).

**Why the drift matters concretely.** The prompt is the literal instruction in the model's
context; `CLAUDE.md` and `SYNC.md` arrive only after the agent reads them. If a rule is
loosened in `SYNC.md` but its stricter restatement is left in the prompt, the agent gets a
direct order that contradicts the file it was told to obey, and the *old* rule usually
wins. If a rule is tightened in the prompt but not in `SYNC.md`, the tightening exists
nowhere a human editing the site by hand will ever see it, so the site drifts between
agent-written and human-written runs.

### Which rule appears where

| Rule | `CLAUDE.md` | `SYNC.md` | prompt |
| --- | --- | --- | --- |
| Never invent content; an empty machine folder gets a bare status | yes | rule 1 | yes |
| **Never infer a lead from file metadata** | — | Leads section | yes |
| Stay concise — overview, not a doc mirror | — | rule 2 | no |
| Preserve the three external links and `jin00404@umn.edu` | — | rule 2 clause | no |
| Never publish budgets, funding, vendor pricing, BOM costs, outreach notes, to-do lists | yes | rule 3 | yes |
| Roster: officers and the faculty advisor only, plus one lead per machine page | yes | rule 4 | yes |
| `Engineering Structure` beats the Constitution on roles | yes (precedence table) | rule 4 note | yes |
| Preserve the design — no frameworks, external assets, or build step | yes (Editing) | rule 5 | yes |
| Update the footer date when content changes | yes (Editing) | rule 6 | yes |
| No Drive change ⇒ no commit | — | rule 7 | yes |
| One page per machine; omit a section rather than emptying it | — | Drive layout | yes |
| `[LR]` folders are never published | — | Drive layout | yes (their absence is explained) |
| Never publish `Club Website — How It Works` | — | Drive layout | yes |
| Maintain `DRIVE_NOTES.md`; never edit `CLAUDE.md` or `SYNC.md` | — | — | **prompt only** |
| Never touch `docs/`, `.github/`, `scripts/`, `mkdocs.yml`, `README.md` | — | — | **prompt only, plus the guard step** |

Rows marked `no` in the prompt column reach the agent only because the prompt orders it to
read `SYNC.md`. Removing that instruction would silently drop them.

The last two rows are the reverse case. `docs/` and the rest are out of bounds because the
prompt says so — they are not publishing rules, since those files are never published at all,
so `SYNC.md` has nothing to say about them. Rewrite the prompt without that clause and the
agent starts treating these pages as content to reconcile against Drive, which has no document
about them.

!!! note "That last one is the only rule with an enforcement mechanism behind it"
    The guard step diffs `docs/ .github/ scripts/ mkdocs.yml README.md CLAUDE.md SYNC.md`
    against the pre-run SHA and **fails the run without pushing** if anything changed. Every
    other rule on this page is enforced by the agent following instructions and by a human
    reading the diff. If you delete the prompt clause, the guard still holds; if you weaken the
    guard, only the prompt is left.

The prompt also carries the workflow instructions that are not rules about content at all:
commit, but do **not** push or switch branches. Those exist because the workflow owns the
force-push and the pull request. Editing them out does not loosen a publishing rule — it
breaks the propose-then-approve flow.

!!! note "A fifth place a rule effectively lives"
    [Reviewing a Proposed Update](../operations/reviewing-changes.md) restates the
    load-bearing rules as a reviewer's checklist. It is not consulted by the agent, so it
    cannot cause the drift described above — but a rule change that leaves it stale means the
    human gate is checking proposals against a rule the club has replaced. Update it in the
    same pass.

---

## Step 1 — Write the decision down in `CLAUDE.md` first

Record what changed, why, who decided it, and the date — the house format is a closing
line like *Resolved by Leonard on 2026-08-18*. `CLAUDE.md` exists specifically to hold
reasoning that cannot be reconstructed from the code or the Drive docs; a rule whose
justification is not written down gets "corrected" back by the next person who finds it
surprising.

If the change touches precedence between Drive docs, update the precedence table in the
same edit.

## Step 2 — Change the procedure in `SYNC.md`

Edit the numbered rule itself. Keep the numbering stable if you can — `CLAUDE.md` and this
docs book both refer to rules by number.

If the rule governs what appears on the site, **change the rule before changing the
site.** SYNC.md rule 4 states this explicitly for the roster. The ordering is what makes
the site's content auditable: the rule file is the record of what the club agreed to, so a
site change that lands first is a change nobody agreed to yet.

## Step 3 — Reconcile the prompt in the workflow

Open the `prompt:` block in `.github/workflows/sync-from-drive.yml` and check whether the rule
you changed is restated there. If it is, update or delete the restatement so it cannot
contradict `SYNC.md`. Keep it a strict subset: the prompt may be shorter than `SYNC.md`, never
different from it.

While you are in the file, check two other things:

- **`--allowedTools`**, currently `Read,Write,Edit,Glob,Grep,Bash(git:*)`. A rule that requires
  a capability outside that set will fail at run time rather than being refused politely.
  Widening it widens the unattended blast radius, so record why in `CLAUDE.md`.
- **Whether the rule changes what should be *fetched*.** A rule about a Drive folder that
  `scripts/fetch_drive.py` skips — `[LR]`, `[C] Finances`, `[C] Funding`, `[C] Logistics` — has
  no effect, because the agent never sees those folders. Changing what is mirrored is an edit
  to `SKIP_FOLDER_PATTERNS` in that script, and it is the stronger control: a document that
  was never downloaded cannot be quoted by a run that forgot a rule.

!!! danger "Test a prompt change with a dry run"
    **Actions → Sync from Drive → Run workflow**, `dry_run` ticked. The agent runs and commits
    on the runner, the full diff is printed, and nothing is pushed. That is the only way to see
    what a reworded rule actually does before it reaches a pull request — and it costs one
    agent run and no branch churn.

## Step 4 — Update the member-facing Drive doc yourself

`Minnesota Nanofabrication Club (MNF)/Club Website — How It Works` explains the sync
to club members. It is documentation *about* the site, never content *for* it, and the sync
is forbidden from editing it — it may only flag drift in the run summary. So a rule change
leaves it stale until a human updates it in Drive.

!!! note "It is already drifted"
    The doc still describes a cloud routine that cannot publish and states that "Nothing runs
    on anyone's laptop" — a sentence that has been true, then false, then true again for
    entirely different reasons as the sync moved from a Claude routine to a `launchd` job to
    GitHub Actions. Fix it properly while you are in there; see
    [Why the sync lives here](../operations/cloud-sync.md#why-the-sync-lives-here).

## Step 5 — Commit all changed files together, then verify with one run

One commit containing `CLAUDE.md`, `SYNC.md`, and the workflow keeps the three provably in step
in the history; three separate commits create windows where they disagree.

**A human has to make this commit.** The guard step fails any run in which the agent touches
`CLAUDE.md`, `SYNC.md` or `.github/`, so a rule change is never something a sync can do to
itself. Then prove the new rule is actually in force:

```bash
R=Minnesota-Nanofabrication-Club/club_website
gh workflow run "Sync from Drive" --repo "$R" -f dry_run=true
gh run watch --repo "$R"
```

Read the agent's one-paragraph summary in the run log, not just the step statuses — a run that
ignored your rule change still goes green. Then read the printed diff: it is the evidence that
the rule took effect. Once it looks right, re-run without `dry_run` and the change arrives as a
pull request you merge after reading it. If the rule was meant to *remove* something from the
site, the proposal is what removes it — and until it is merged, nothing has changed. See
[Anatomy of a Sync Run](../operations/sync-run.md) and
[Reviewing a Proposed Update](../operations/reviewing-changes.md).

---

## The roster rule

!!! danger "Publishing the general-member roster requires the members' consent, not an edit to the rule"
    Officers and the faculty advisor are published by name because those names are already
    public through RSO registration. General members' names are not: they are students'
    full names on a public, search-indexed page, and no member has opted in. Editing rule 4
    changes the agent's behaviour on the very next run: it reads every name in
    `Engineering Structure` and writes it into `<ul class="member-list">`, and that lands in
    a pull request whose title says something like "sync team section from Drive". The review
    step is real but thin — it is one person, reading a diff that looks routine, against a
    rule file that now *says* the roster is publishable. Approving it takes one click, and
    once a page is indexed, deleting the names does not retract them. **Get the members'
    consent first; edit the rule second; let the sync propose and a reviewer merge third.**
    Never edit the rule expecting to catch the consequence at review — by then the rule the
    reviewer checks against is the one you already changed.

The same asymmetry applies in reverse and is cheap: removing a name needs no consent. If a
member asks to be removed, edit `Engineering Structure` in Drive and run a sync.

---

## The settled question: `Engineering Structure` vs the Constitution

This one is decided. Do not re-open it.

The Constitution's officer signature block names Vikram Narra, Davit Sandoyan, Harshit
Mehendiratta and John Jeong as "Officers" and omits Bear Blinschauer. That block exists to
satisfy the RSO registration requirement of five officer signatures — **it is a
registration artifact, not a statement of who the officers are.** The `Engineering
Structure` doc reflects how the club actually operates and is kept current, so it is ground
truth for roles:

- Leonard Jin — President
- Andrew Choi — Vice President
- Bear Blinschauer — Officer
- Prof. Joseph "Joey" Talghader — Faculty Advisor
- everyone else listed there — Members, and therefore not published

A sync that notices the discrepancy must **not** "reconcile" it by pulling names off the
constitution. Resolved by Leonard 2026-08-18, and recorded in all three files precisely
because it had already been gotten wrong once — the failure mode is a well-meaning agent
finding two documents that disagree, treating the formal-sounding one as authoritative,
and publishing four people who do not hold the roles it assigns them while dropping one who
does.

If a genuine officer change happens, it goes into `Engineering Structure`. The Constitution
is amended through club governance and does not become the roster source by being amended.

---

## Common pitfalls

- **Editing `SYNC.md` only.** The prompt in `.github/workflows/sync-from-drive.yml` keeps
  issuing the old rule as a direct instruction, and the agent follows it.
- **Writing a rule into `DRIVE_NOTES.md`.** The agent prunes that file. A rule with no
  `REMOVE WHEN` condition does not belong there, and one with a removal condition is not a
  rule.
- **Changing a rule about a folder that is never fetched.** `[LR]` and the `[C]` folders never
  reach the agent, so a prompt clause about them changes nothing. Edit
  `SKIP_FOLDER_PATTERNS` in `scripts/fetch_drive.py` instead.
- **Editing the prompt only.** The rule then exists nowhere a human editing the site by
  hand will see it, and the next `SYNC.md` reader reverts it.
- **Changing the site before changing the rule.** Inverts the audit trail: the published
  page becomes the record of a decision the rule file never captured.
- **Treating the review step as a safety net for a rule change.** The reviewer checks a
  proposal against the rules as they now read — including the one you just edited.
- **Leaving the reviewer checklist stale.** The human gate then enforces the old rule.
- **Writing the rule without the reasoning.** `CLAUDE.md` is the *why* file. A rule with no
  recorded justification is a rule someone will helpfully undo.
- **Treating the roster rule as an ordinary edit.** It is the one rule whose change is
  irreversible in effect. Consent first.
- **Re-litigating the Constitution-vs-`Engineering Structure` question.** Settled
  2026-08-18. Follow `Engineering Structure` and move on.
- **Silently editing `Club Website — How It Works` from a sync run.** The sync may only
  flag its drift; a human updates it in Drive.
