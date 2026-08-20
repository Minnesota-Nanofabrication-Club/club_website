# Design Principles

Seven rules govern what goes on the club website and how it gets there. They exist because
the site is rewritten twice a week by an agent that will follow whatever the rules say —
so a rule that is vague, or a rule that lives only in someone's head, becomes a published
mistake on a search-indexed page. Each rule below is stated with the failure mode it
prevents.

The rules are recorded in `CLAUDE.md` (the standing decisions) and `SYNC.md` (the
procedure). The `claude -p` prompt in `scripts/sync-from-drive.sh` restates the load-bearing
ones inline, so they hold even if a run somehow skips reading the files.

---

## 1. Never invent content

**Every claim on the site must trace back to a Drive document.** A project folder that is
empty, or that holds only a diagram link, gets a bare status — `Planned`,
`Architecture design` — and nothing else.

The Etcher entry in `index.html` is the worked example. Its Drive folder is empty, so its
`<li>` carries a `<span class="name">` and a `<span class="status">` and **no `<p>`
description at all**, unlike the five entries around it:

```html
<li>
  <span class="name">Sputterer</span>
  <span class="status">Design and bill of materials</span>
  <p>Optional description, only if a Drive doc supports it.</p>
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

---

## 2. Drive is the source of truth, not the HTML

**Project content changes in Google Drive. The repo renders it.** The agent rewrites the
affected sections of `index.html` and `stepper.html` from the Drive documents each run; it
does not merge, and it does not ask.

**What breaks otherwise:** a hand-edit to project copy survives until 08:13 on the next
scheduled day — Monday or Thursday, so at most four days — then disappears under a commit
whose message describes it as a routine sync. There is no conflict, no warning, and no macOS
notification; the only traces are one line in `~/Library/Logs/mnfc-website-sync.log` on a
single laptop and a `↻ Site updated` post in Discord. This is demonstrated behavior:
deleting the Etcher entry (`0593a4a`) and letting the sync restore it (`7dd018c`) is how the
write-back path was verified on 2026-08-18.

| Change | Where to make it |
| --- | --- |
| Project name, status, description | The tool's folder under `Build the Fab` |
| Timeline rows in `stepper.html` | `Build the Fab/Maskless Lithography Stepper/Project Timeline` |
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
- `Minnesota Nanofabrication Club (GopherFab)/Club Website — How It Works` — that document
  explains this sync *to* club members; it is documentation about the website, not content
  for it

**What breaks otherwise:** these categories are harmful in a way that project copy is not.
Published vendor pricing and BOM costs hand a negotiating position to every supplier the
club has not yet talked to; published funding status shapes how sponsors and the department
read the club before anyone has a conversation; outreach notes are candid remarks about
named faculty written for an internal audience. None of that is fixable by deleting the page
later — a static site is fetched, cached and archived within a minute of the push.

!!! note "Flag drift, never edit it silently"
    If `Club Website — How It Works` drifts out of step with `SYNC.md` or `CLAUDE.md`, note
    it in the run summary rather than correcting the Drive document. It has in fact drifted
    as of 2026-08-19: it still claims the sync runs in the cloud and that "Nothing runs on
    anyone's laptop", which stopped being true at commit `99e3012`.

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
toolchain that has to run somewhere. The sync's `--allowedTools` list grants `Bash(git:*)`
and nothing else, so the agent cannot run a bundler even if a future page needs one — the
run would edit sources, commit, push, and publish a site whose built assets no longer match.
An external asset adds a third party who can change or remove what the club's page renders,
on a page nobody checks between runs. Keeping the repo byte-identical to what Pages
serves means the diff in a commit *is* the change to the site, with nothing in between.

Preview locally with `python3 -m http.server 8000`; there is nothing else to run.

---

## 7. No change in Drive means no commit

**If nothing meaningful changed, the run makes no commit and says so.** The script compares
`BEFORE=$(git rev-parse HEAD)` against `AFTER`, logs `RESULT: no changes committed.`, and
records `OK  no changes` to the status file — an explicitly successful outcome, not an
absence of one.

**What breaks otherwise:** an empty commit per run destroys the log's only signal. `git log`
and the log file are how anyone answers "did the site actually change?" — with a commit on
every Monday and Thursday regardless, the answer requires reading every diff, and the
`last updated` date in the `index.html` footer stops meaning "content changed" and starts
meaning "a run happened". The date is updated **only** when something actually changes, which
is what makes it worth printing. The same signal carries into Discord: `changed` is a real
change because a run with nothing to do posts `ok` instead.

!!! note "`no changes committed` is a success, not a failure"
    A run that produces no commit means Drive matched the site. Reading it as a
    breakage — and "fixing" it — is how empty commits get introduced. The genuinely bad
    states announce themselves: every failure path writes `FAIL` to the status file, raises a
    notification and posts `✗ Sync failed` to Discord, and a slot with no run at all is caught
    by the watchdog. See [Sync Run](../operations/sync-run.md) and
    [Notifications](../operations/notifications.md).

---

## Rules at a glance

| # | Rule | Enforced by |
| --- | --- | --- |
| 1 | Never invent content; empty folder gets a bare status | `SYNC.md` rule 1, restated in the `claude -p` prompt |
| 2 | Drive is the source of truth; do not hand-edit project copy | `CLAUDE.md` source-of-truth hierarchy |
| 3 | Fixed precedence between Drive docs; `Engineering Structure` wins on roles | `CLAUDE.md` precedence table |
| 4 | Officers and advisor by name; never the general-member roster | `SYNC.md` rule 4 |
| 5 | Budgets, funding, vendor pricing, BOM costs, outreach notes, `[MASTER]` to-dos stay in Drive | `SYNC.md` rule 3 |
| 6 | No frameworks, no external assets, no build step | `SYNC.md` rule 5 |
| 7 | No change in Drive ⇒ no commit | `SYNC.md` rule 7, script `BEFORE`/`AFTER` check |

---

## Read next

| Page | Covers |
| --- | --- |
| [**Architecture Overview**](overview.md) | Drive → launchd → headless agent → push → Pages, end to end |
| [**Data Contracts**](../data-contracts.md) | Which Drive folder feeds which page section, and the HTML entry shapes |
| [**Schedule**](../operations/schedule.md) | The `com.mnfc.website-sync` launchd job, Mon + Thu |
| [**Sync Run**](../operations/sync-run.md) | Reading `~/Library/Logs/mnfc-website-sync.log` |
| [**Notifications**](../operations/notifications.md) | The status file, macOS banners and the Discord webhook |
