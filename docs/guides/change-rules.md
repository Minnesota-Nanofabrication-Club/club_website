# Guide: Change a Publishing Rule

How to change what the site is allowed to publish. The rules live in **three** places that
have to agree — `CLAUDE.md`, `SYNC.md`, and the prompt string inside
`scripts/sync-from-drive.sh` — and a change that touches only one of them leaves the sync
agent following the old rule.

---

## The three places a rule lives

| File | Role | What it holds |
| --- | --- | --- |
| `CLAUDE.md` | the **why** | Standing decisions, the source-of-truth precedence table, and the reasoning that is not recoverable from the code or the Drive docs |
| `SYNC.md` | the **how** | The Drive → section mapping, the numbered publishing rules, and the steps of a run |
| `scripts/sync-from-drive.sh` | the **executed instruction** | A prompt string passed to `claude -p` that restates several rules inline and orders the agent to read `CLAUDE.md` first, then `SYNC.md` |

The prompt is a deliberate subset, not a copy. It restates the rules with the worst
consequences so the agent has them before it opens a single file, and delegates the rest to
the two Markdown files it tells the agent to read.

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
| Never invent content; an empty project folder gets a bare status | yes | rule 1 | yes |
| Stay concise — overview, not a doc mirror | — | rule 2 | no |
| Preserve the three external links and `jin00404@umn.edu` | — | rule 2 clause | no |
| Never publish budgets, funding, vendor pricing, BOM costs, outreach notes, to-do lists | yes | rule 3 | yes |
| Roster: officers and the faculty advisor only | yes | rule 4 | yes |
| `Engineering Structure` beats the Constitution on roles | yes (precedence table) | rule 4 note | yes |
| Preserve the design — no frameworks, external assets, or build step | yes (Editing) | rule 5 | yes |
| Update the footer date when content changes | yes (Editing) | rule 6 | yes |
| No Drive change ⇒ no commit | — | rule 7 | yes |
| `[LR]` folders are never published | — | Drive layout | no |
| Never publish `Club Website — How It Works` | — | Drive layout | no |

Rows marked `no` in the prompt column reach the agent only because the prompt orders it to
read `SYNC.md`. Removing that instruction from the prompt would silently drop four rules.

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

## Step 3 — Reconcile the prompt in `scripts/sync-from-drive.sh`

Open the `claude -p "..."` string and check whether the rule you changed is restated there.
If it is, update or delete the restatement so it cannot contradict `SYNC.md`. Keep it a
strict subset: the prompt may be shorter than `SYNC.md`, never different from it.

While you are in the file, check `--allowedTools`. A rule that requires reading a new Drive
location still runs under the four scoped `mcp__claude_ai_Google_Drive__*` tools plus
`Read,Edit,Write,Glob,Grep,Bash(git:*)`; a rule that requires anything outside that set
will fail at run time rather than being refused politely.

## Step 4 — Update the member-facing Drive doc yourself

`Minnesota Nanofabrication Club (GopherFab)/Club Website — How It Works` explains the sync
to club members. It is documentation *about* the site, never content *for* it, and the sync
is forbidden from editing it — it may only flag drift in the run summary. So a rule change
leaves it stale until a human updates it in Drive.

!!! note "It is already drifted"
    As of 2026-08-19 the doc still says the sync runs in the cloud and that "Nothing runs
    on anyone's laptop", which stopped being true at commit `99e3012`. Fix that while you
    are in there.

## Step 5 — Commit all changed files together, then verify with one run

One commit containing `CLAUDE.md`, `SYNC.md`, and the script keeps the three files provably
in step in the history; three separate commits create windows where they disagree. Then
prove the new rule is actually in force:

```bash
./scripts/sync-from-drive.sh
tail -40 ~/Library/Logs/mnfc-website-sync.log
```

Read the agent's one-paragraph summary in the log, not just the `RESULT:` line — a run that
ignored your rule change still exits 0 and still reports success. See
[Running a sync](../operations/sync-run.md).

---

## The roster rule

!!! danger "Publishing the general-member roster requires the members' consent, not an edit to the rule"
    Officers and the faculty advisor are published by name because those names are already
    public through RSO registration. General members' names are not: they are students'
    full names on a public, search-indexed page, and no member has opted in. Editing rule 4
    changes the agent's behaviour immediately — the next run reads every name in
    `Engineering Structure` and writes it into `<ul class="member-list">`, the commit pushes
    to `main`, and GitHub Pages serves it within about a minute. There is no review step
    between the rule edit and publication, and once a page is indexed, deleting the names
    does not retract them. **Get the members' consent first; edit the rule second; let the
    sync publish third.**

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

- **Editing `SYNC.md` only.** The prompt in `scripts/sync-from-drive.sh` keeps issuing the
  old rule as a direct instruction, and the agent follows it.
- **Editing the prompt only.** The rule then exists nowhere a human editing the site by
  hand will see it, and the next `SYNC.md` reader reverts it.
- **Changing the site before changing the rule.** Inverts the audit trail: the published
  page becomes the record of a decision the rule file never captured.
- **Writing the rule without the reasoning.** `CLAUDE.md` is the *why* file. A rule with no
  recorded justification is a rule someone will helpfully undo.
- **Treating the roster rule as an ordinary edit.** It is the one rule whose change is
  irreversible in effect. Consent first.
- **Re-litigating the Constitution-vs-`Engineering Structure` question.** Settled
  2026-08-18. Follow `Engineering Structure` and move on.
- **Silently editing `Club Website — How It Works` from a sync run.** The sync may only
  flag its drift; a human updates it in Drive.
