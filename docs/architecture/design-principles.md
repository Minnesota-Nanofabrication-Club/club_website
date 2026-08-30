# Design Principles

Seven rules govern what goes on the club website and how it gets there. They exist because
the site is rewritten twice a week by an agent that will follow whatever the rules say —
so a rule that is vague, or a rule that lives only in someone's head, becomes a published
mistake on a search-indexed page. Each rule below is stated with the failure mode it
prevents.

Since the sync switched to proposing rather than publishing, a human reads the diff before
anything reaches the site. That review is a second line of defence, not a replacement for the
rules: a reviewer checking a proposal is checking it *against these rules*, and a violation is
only catchable if the rule was written down first. The reviewer's checklist is in
[Reviewing a Proposed Update](../operations/reviewing-changes.md).

The rules are recorded in `CLAUDE.md` (the standing decisions) and `SYNC.md` (the procedure).
The prompt inside `.github/workflows/sync-from-drive.yml` restates the load-bearing ones
inline, so they hold even if a run somehow skips reading the files. `DRIVE_NOTES.md` is a
fourth file the agent reads, but it holds *observations about Drive*, never rules — see
[the three-tier memory model](overview.md#the-three-tier-memory-model).

---

## 1. Never invent content

**Every claim on the site must trace back to a Drive document.** A project folder that is
empty, or that holds only a diagram link, gets a bare status — `Planned`,
`Architecture design` — and nothing else.

A machine whose folder is empty is the worked example: its `<li>` in `index.html` carries a
`<span class="name">` and a `<span class="status">` and **no `<p>` description at all**, and
its own subpage carries the name, the status, and one sentence saying there is no design
documentation yet — not a description written from general knowledge of what such a machine
does. **Omit a section rather than emptying it**: a heading with "TBD" underneath reads as a
promise the club has not made.

On `index.html` every machine now takes the same compact form — a linked name and a status, with
the description living on the machine's own page:

```html
<li>
  <span class="name"><a href="sputterer.html">DC Magnetron Sputterer</a></span>
  <span class="status">In design</span>
</li>
```

!!! warning "Filler prose becomes a club commitment"
    An agent asked to describe a tool it has no source for will produce fluent,
    plausible, wrong text — a build status the club has not reached, a capability the tool
    does not have, a timeline nobody agreed to. Published under the club's name to
    prospective members, faculty and the wider Hacker Fab community, that text is
    indistinguishable from a real commitment, and nobody who reads it can tell it was
    generated rather than sourced. A bare `Planned` conveys strictly less and is strictly
    true. The asymmetry is the whole reason the rule is absolute: an under-described
    project costs nothing, a fabricated one costs credibility that is not recoverable by
    editing the page later.

**Rule 1 governs claims, not links.** Four items on the site are deliberately not
Drive-sourced and must be **preserved** through every sync:

| Item | Where | Authorized by |
| --- | --- | --- |
| `https://cse.umn.edu/ece/joseph-talghader` | `index.html` Team | `SYNC.md` rule 2, link clause |
| `https://docs.hackerfab.org/home` | `index.html` About, `stepper.html` | same clause |
| `https://arxiv.org/pdf/2510.15082` | `stepper.html` (CMU stepper paper) | same clause |
| `jin00404@umn.edu` | `index.html` Get Involved | `SYNC.md` — the one email published on the site, added at Leonard's request 2026-08-18 |

Verify that a link resolves and points at the right subject before adding one. Never guess
a URL — a guessed faculty page is an invented claim wearing an `<a>` tag.

!!! danger "Rule 1 also forbids inferring a person from metadata"
    A machine subpage may name the one person responsible for that machine — the deliberate
    exception to the roster rule below. That name must appear in the **text** of a Drive
    document saying so. Who owns the file, who created the folder, whose address is in the
    document properties, who edited it last: none of those name a lead. Owning a file means
    somebody made a document.

    A run on 2026-08-30 published three people as machine leads on exactly that basis and every
    one was unsupported. The review gate caught it. If you cannot quote the sentence that names
    the lead, there is no lead to publish — and a guessed identity on a public page is worse
    than no name at all.

---

## 2. Drive is the source of truth, not the HTML

**Project content changes in Google Drive. The repo renders it.** The agent rewrites the
affected sections of `index.html` and the machine subpages from the Drive documents each run;
it does not merge, and it does not ask.

**What breaks otherwise:** a hand-edit to project copy survives until the next scheduled run —
Monday or Thursday, so at most four days — and then a proposal appears that undoes it, under a
commit message describing the change as a routine sync. There is no conflict and no warning;
the traces are a diff in a pull request and an amber `📋 Update proposed — review` post in
Discord. The pull request means the revert is visible before it ships, but only to a reviewer
who already knows the sentence was hand-written — from inside the diff it is indistinguishable
from any other Drive-sourced correction, and merging it is the expected action. This is
demonstrated behavior: deleting the Etcher entry (`0593a4a`) and letting the sync restore it
(`7dd018c`) is how the write-back path was verified on 2026-08-18, under an earlier
publish-directly design.

| Change | Where to make it |
| --- | --- |
| Machine name, status, description, lead | That machine's folder under `Build the Fab` |
| Timeline rows on a machine page | That machine's timeline doc, inside its own folder |
| Roles and team membership | `Engineering Structure` |
| Purpose, eligibility, governance wording | `Minnesota Nanofabrication Constitution` |
| Mission framing | `Project and Goals` |
| HTML structure, `style.css`, nav, layout | The repo — design is not Drive-sourced |

See [Architecture Overview](overview.md) for the full pipeline and
[Data Contracts](../data-contracts.md) for the folder-to-section mapping.

---

## 3. Drive documents have a fixed precedence

Drive documents disagree with each other. When they do, this table decides — it is not a
judgment call to be re-made per run:

| Topic | Ground truth | Notes |
| --- | --- | --- |
| Engineering / organizational structure, roles, project ownership | **`Engineering Structure`** | **Always wins.** It reflects how the club actually operates and is kept current |
| Club purpose, membership eligibility, governance, formal policy | `Minnesota Nanofabrication Constitution` | Reference material; cite it for purpose and eligibility language |
| Project scope, status, timelines, BOMs | That project's folder under `Build the Fab` | Each tool's `[Master]` and timeline docs |
| Overall mission framing | `Project and Goals` | Source of the "Full Stack Codesign" language |

Drive tag conventions: `[LR]` marks a learning resource and is **never published**, `[D]`
marks documentation, `[Master]` marks the main outline doc for a folder.

### Why `Engineering Structure` beats the Constitution on roles

The Constitution's **officer signature block** names four people as "Officers" who are not
the current officers, and omits Bear Blinschauer, who is. That block exists to satisfy the
RSO registration requirement of five officer signatures — **it is a registration artifact,
not a statement of who the officers are.** Reading it as a roster produces a Team section
that lists four people who do not hold those roles and drops one who does. The specific
names are in `CLAUDE.md` and `SYNC.md`; they are not repeated here, and they must not reach
the site.

Publish what `Engineering Structure` says: Leonard Jin (President), Andrew Choi (Vice
President), Bear Blinschauer (Officer), Prof. Joseph "Joey" Talghader (Faculty Advisor).

!!! warning "Do not re-litigate the roster discrepancy"
    A sync that notices the mismatch must **not** "reconcile" it by pulling names off the
    Constitution onto the site. The discrepancy is expected, understood, and settled — it
    will be noticed again by every future run, and every future run must reach the same
    answer. Resolved by Leonard on 2026-08-18.

---

## 4. Officers and the advisor by name — never the general-member roster

**Publish the President, Vice President, Officers and the faculty advisor. Publish no other
member's name.** The `<ul class="member-list">` in `index.html` holds exactly four entries
for this reason.

!!! danger "Member names are a privacy decision, not a formatting one"
    A general-member roster puts students' **full legal names on a public,
    search-indexed page** — permanently associated with the club, discoverable by
    employers, and outside the students' control once crawled and cached. Those members
    have not opted in. Officers are different only because their names are **already public
    via RSO registration**, so publishing them discloses nothing new. That distinction is
    the entire justification for the line; it does not extend one name past it.

    **Changing this needs the members' consent, not just a decision to do it.** A future
    maintainer — human or agent — deciding the roster "would be nice to have" is not
    authorization. If the club decides otherwise, change the rule in `SYNC.md` and
    `CLAUDE.md` first, then the site.

Email addresses follow the same logic: `jin00404@umn.edu` is the **one** address published,
deliberately. Do not add members' or the advisor's addresses even though they appear in
Drive documents.

---

## 5. Internal material never leaves Drive

**Never publish**, in any section, on either page:

- budgets and funding status
- vendor names, vendor pricing, BOM costs
- sponsorship correspondence
- professor- and advisor-outreach notes
- `[MASTER]` to-do lists
- `[LR]` learning-resource folders
- `Minnesota Nanofabrication Club (MNF)/Club Website — How It Works` — that document
  explains this sync *to* club members; it is documentation about the website, not content
  for it

**What breaks otherwise:** these categories are harmful in a way that project copy is not.
Published vendor pricing and BOM costs hand a negotiating position to every supplier the
club has not yet talked to; published funding status shapes how sponsors and the department
read the club before anyone has a conversation; outreach notes are candid remarks about
named faculty written for an internal audience. None of that is fixable by deleting the page
later — a static site is fetched, cached and archived within a minute of the merge. The same
reasoning keeps this material out of Discord: the `fail` embed forwards none of the agent's
output, because that output quotes the documents these categories live in.

The first line of defence is that most of it is never fetched. `scripts/fetch_drive.py` skips
`[LR]` folders and `[C] Finances`, `[C] Funding` and `[C] Logistics` outright, so that material
never enters the agent's context. What remains — vendor drafts and contact details embedded
inside otherwise-publishable `[MASTER]` docs — the agent does read, which is why the rule is
also stated in the prompt and checked at review.

!!! note "Flag drift, never edit it silently"
    If `Club Website — How It Works` drifts out of step with `SYNC.md` or `CLAUDE.md`, note it
    in the run summary rather than correcting the Drive document. It has in fact drifted: it
    still describes the sync as a cloud routine that cannot publish and states that "Nothing
    runs on anyone's laptop" — a sentence that has now been true, false, and true again for
    entirely different reasons. A human updates it in Drive.

---

## 6. No frameworks, no external assets, no build step

The site is plain HTML and CSS. GitHub Pages serves the committed files exactly as they
are. `style.css` defines the complete vocabulary the pages use — `:root` custom properties
(`--maroon` `#7a0019`, `--maroon-dark` `#5b0013`, `--gold` `#ffcc33`, `--ink`, `--muted`,
`--paper`, `--bg`, `--line`), plus `.header-inner`, `.footer-inner`, `.tagline`, `nav a`,
`nav a.active`, `.member-list`, `.project-list`, `.table-wrap`, table styling, `.note`, and
`.footer-inner .synced`. A sync touches `style.css` only if a genuinely new content type
needs it.

**What breaks otherwise:** a build step turns the deployed page into the output of a
toolchain that has to run somewhere. The sync's `--allowedTools` list grants `Bash(git:*)` and
nothing else, so the agent cannot run a bundler even if a future page needs one — the run would
edit sources, commit, and propose a diff whose built assets no longer match, which a reviewer
reading source diffs has no way to notice.
An external asset adds a third party who can change or remove what the club's page renders,
on a page nobody checks between runs. Keeping the repo byte-identical to what Pages
serves means the diff in a commit *is* the change to the site, with nothing in between.

Preview locally with `python3 -m http.server 8000`; there is nothing else to run.

---

## 7. No change in Drive means no commit

**If nothing meaningful changed, the run makes no commit and says so.** The guard step compares
the pre-agent SHA against `HEAD`, logs `No commit made — the site already matches Drive.`, and
sets `changed=false` — an explicitly successful outcome, not an absence of one. The publish
step is skipped entirely, which also means **nothing closes a pull request left open from an
earlier run**; see
[Nothing closes a stale proposal](../operations/sync-run.md#nothing-closes-a-stale-proposal).

**What breaks otherwise:** an empty commit per run destroys the log's only signal. `git log`
and the log file are how anyone answers "did the site actually change?" — with a commit on
every Monday and Thursday regardless, the answer requires reading every diff, and the
`last updated` date in the `index.html` footer stops meaning "content changed" and starts
meaning "a run happened". The date is updated **only** when something actually changes, which
is what makes it worth printing. Under the pull-request flow the cost is higher still: an
empty commit is an empty *proposal*, so a reviewer is pinged, opens a diff, finds nothing in
it, and learns to skim the next one. The signal carries into Discord the same way — an amber
`📋 Update proposed — review` is a real change to look at, because a run with nothing to do
posts a grey `✓ Site checked` instead.

!!! note "A run with no commit is a success, not a failure"
    A run that produces no commit means Drive matched the site. Reading it as a breakage — and
    "fixing" it — is how empty commits get introduced. The genuinely bad states announce
    themselves: a failed job goes red, posts `✗ Sync failed` to Discord, and opens a
    `drive-sync-failure` issue that stays open until a run succeeds. The one state that
    announces nothing is a slot where no run happened at all, and nothing detects it — see
    [Sync Run](../operations/sync-run.md) and
    [Notifications](../operations/notifications.md#what-none-of-these-channels-covers).

---

## Rules at a glance

| # | Rule | Enforced by |
| --- | --- | --- |
| 1 | Never invent content; an empty folder gets a bare status, and a lead must be quoted, not inferred | `SYNC.md` rule 1, restated in the workflow prompt |
| 2 | Drive is the source of truth; do not hand-edit project copy | `CLAUDE.md` source-of-truth hierarchy |
| 3 | Fixed precedence between Drive docs; `Engineering Structure` wins on roles | `CLAUDE.md` precedence table |
| 4 | Officers and advisor by name; never the general-member roster | `SYNC.md` rule 4 |
| 5 | Budgets, funding, vendor pricing, BOM costs, outreach notes, `[MASTER]` to-dos stay in Drive | `SYNC.md` rule 3, plus the folders `fetch_drive.py` never mirrors |
| 6 | No frameworks, no external assets, no build step | `SYNC.md` rule 5 |
| 7 | No change in Drive ⇒ no commit | `SYNC.md` rule 7, the guard step's `BEFORE`/`AFTER` check |

An eighth constraint is not a publishing rule but is enforced harder than any of them: the
agent may not touch `docs/`, `.github/`, `scripts/`, `mkdocs.yml`, `README.md`, `CLAUDE.md` or
`SYNC.md`. The prompt says so and [the guard step](overview.md#what-runs-in-order) fails the
run if it happens anyway.

---

## Read next

| Page | Covers |
| --- | --- |
| [**Architecture Overview**](overview.md) | Drive → mirror → hosted agent → guard → pull request → Pages, end to end |
| [**Data Contracts**](../data-contracts.md) | Which Drive folder feeds which page, and the HTML entry shapes |
| [**The Cloud Sync**](../operations/cloud-sync.md) | The schedule, the secrets, and why the sync runs in GitHub Actions |
| [**Sync Run**](../operations/sync-run.md) | The workflow step by step, and every marker it writes |
| [**Reviewing a Proposed Update**](../operations/reviewing-changes.md) | Checking a proposal against these rules before merging it |
| [**Notifications**](../operations/notifications.md) | The run log, the job summary, Discord and the failure issue |
