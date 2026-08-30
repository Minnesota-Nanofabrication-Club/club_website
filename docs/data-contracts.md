# Data Contracts

The canonical reference for what maps to what: which Google Drive document feeds which
page, what markup each section expects, and which content on the site is
deliberately not Drive-sourced. **Every claim published on the site traces to one row of
one table on this page** — if it does not appear here, it does not belong in the HTML.

This page describes the contracts. The procedures that consume them live in
[Add a project entry](guides/add-project.md) and
[Design principles](architecture/design-principles.md).

## Contents

- [Drive → page mapping](#drive-mapping)
- [One page per machine](#one-page-per-machine)
- [Drive tag conventions](#tags)
- [Folders that are never fetched](#never-fetched)
- [HTML contracts](#html-contracts)
- [Class vocabulary](#class-vocabulary)
- [The footer contract](#footer-contract)
- [Content that is not Drive-sourced](#not-drive-sourced)
- [The excluded doc](#excluded-doc)

---

## Drive → page mapping { #drive-mapping }

Root folder: **Ultra Hardcore Chip D&F** — `1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP`

!!! note "The root folder was renamed; the id did not change"
    It was **Ultra Hardcore Chip Codesign** until August 2026. The id is what everything
    actually resolves — `SYNC.md`, `scripts/fetch_drive.py`'s `DEFAULT_FOLDER_ID`, and the
    Drive share granted to the service account all key off it — so the rename cost nothing.
    Older documents and older docs pages still use the previous name.

| Drive location | Feeds |
| --- | --- |
| `Minnesota Nanofabrication Club (MNF)/Project and Goals` | "Full Stack Codesign" section |
| `Minnesota Nanofabrication Club (MNF)/Engineering Structure` | "Team" section |
| `Minnesota Nanofabrication Club (MNF)/Minnesota Nanofabrication Constitution` | "About" / "Get Involved" (purpose, membership eligibility) |
| `Build the Fab/<machine>/` | **one subpage per machine**, plus one `<li>` in "Current Projects" |
| `Design the IC/` | "Full Stack Codesign" section on `index.html` |

The mapping is one-directional and total. `Build the Fab/<machine>/` is the only wildcard row:
one subfolder produces exactly one page and exactly one `<li>` in `.project-list`, which is why
the nine entries in `index.html` are nine subfolders and not an editorial selection. A machine
that appears in Drive but not on the site is a missed sync, not a decision.

Drive is authoritative over the repo in both directions of disagreement. Hand-editing
project copy in the HTML does not update Drive, so the next sync diffs the edited HTML
against the unchanged Drive doc and reverts it — the edit survives until the next scheduled
run, at most four days, and then disappears with no record of why. Change the Drive doc
instead.

---

## One page per machine { #one-page-per-machine }

The site is **ten pages**: `index.html` plus one per subfolder of `Build the Fab`.

| Drive folder | Page |
| --- | --- |
| `Maskless Lithography Stepper` | `stepper.html` |
| `DC Magnetron Sputterer` | `sputterer.html` |
| `Tube Furnace` | `tube-furnace.html` |
| `Reactive-Ion Etcher` | `etcher.html` |
| `Photoresist Spinner` | `spinner.html` |
| `Photoresist Developer` | `developer.html` |
| `Probe Station` | `probe-station.html` |
| `Ultrasonic Cleaner` | `ultrasonic-cleaner.html` |
| `Wafer Arm` | `wafer-arm.html` |

**A new subfolder means a new page**, added to the nav on every page and to `index.html`. A
folder tagged `[D]` or `[LR]` is not a machine and gets no page.

Each page carries, **only where a doc supports it**: the machine's name as Drive spells it, its
current status, `Lead: <name>` if a document's text names one, "What It Does", "Subsystems",
and a timeline.

!!! danger "`Lead:` must be quoted from a document, never inferred from metadata"
    Who owns the Drive file, who created the folder, whose address is in the document
    properties, who edited it last — **none of those name a lead.** Owning a file means somebody
    made a document.

    A run on 2026-08-30 published `Lead: Davit Sandoyan` on the etcher and `Lead: Andrew Choi`
    on the spinner and the tube furnace purely because those accounts owned files in those
    folders. No document said any of it; the review gate caught it. If you cannot quote the
    sentence that names the lead, there is no lead to publish — a guessed identity on a public,
    indexed page is worse than no name at all.

    Where a top-level tracker cell disagrees with the machine's own doc, the machine's doc
    wins. A bare first name matching nobody in `Engineering Structure` is not a name.

**Omit a section rather than emptying it.** A heading with "TBD" underneath reads as a promise
the club has not made. A folder with nothing in it gets a page with the name, the status, and
one sentence saying there is no design documentation yet — not a description written from
general knowledge of what such a machine does. That description would come from the agent, not
from Drive, and rule 1 forbids it.

**Never borrow a description from another machine's doc.** Docs get copied between folders and
the copy is not always edited; if a timeline's stages describe a different process, it is not
that machine's timeline.

---

## Drive tag conventions { #tags }

Documents and folders in Drive carry a leading bracket tag naming their role.

| Tag | Meaning | Published? |
| --- | --- | --- |
| `[LR]` | Learning resource — reference material the club reads | **Never**, and never even fetched. Reference material is not club output; publishing it would present someone else's tutorial as a project claim. |
| `[D]` | Documentation | Only through the mapping table above, and only the concise subset. Not a machine — gets no page. |
| `[Master]` / `[MASTER]` | The main outline doc for that folder, and the first thing to read in it | Read it for scope, status and the lead; the to-do lists, vendor drafts and contact details inside it are internal and never published. |
| `[C]` | Club administration | Never. `[C] Finances`, `[C] Funding` and `[C] Logistics` are not fetched at all. |
| `[BOM]` | Bill of materials | Never. Costs and vendors. |

An untagged doc is not implicitly publishable. The mapping table decides what is read;
the tags decide what is disqualified inside a folder that is otherwise in scope.

---

## Folders that are never fetched { #never-fetched }

`scripts/fetch_drive.py` refuses to mirror four folder patterns, so their contents never enter
the agent's context at all:

| Pattern | What is in it |
| --- | --- |
| `[LR] *` | Learning resources — reference material, never published |
| `[C] Finances` | The club budget |
| `[C] Funding` | Grant proposals and expense tables |
| `[C] Logistics` | Lab space, advisor outreach, named staff contacts |

**Not fetching is stronger than not publishing.** A rule the agent has to remember while
holding a budget spreadsheet in context is a rule that can be forgotten in one run; a document
that was never downloaded cannot be quoted. Their absence from the mirror is correct and is not
a sign of a broken fetch.

This is not total coverage. The top-level `[MASTER]` in `Build the Fab` is a vendor-outreach
ledger despite its name, and sponsorship drafts and personal contact details sit inside
otherwise-publishable machine docs. Those the agent does read, which is why the never-publish
rule is also in the prompt and checked at review.

---

## HTML contracts { #html-contracts }

The site is plain HTML and CSS with no build step, so the markup shapes below *are* the
schema — nothing validates them and nothing fails loudly when they are wrong. A
malformed entry renders as unstyled body text rather than raising an error, so it looks
like sloppy copy rather than a broken contract.

### A `.project-list` entry

`Current Projects` in `index.html` is a single `<ul class="project-list">` with one `<li>` per
machine. Every entry now takes the same compact form — a linked name and a status:

```html
<li>
  <span class="name"><a href="tube-furnace.html">Tube Furnace</a></span>
  <span class="status">Design complete</span>
</li>
```

`<span class="name">` and `<span class="status">` are both required. **The link goes *inside*
the `.name` span, never around it** — `.project-list .name` sets the weight and size, and a
link wrapping the span inherits neither.

`.project-list p` is still defined in `style.css` and the shape still accepts an optional
`<p>`, but no entry uses one: since every machine has its own page, the description belongs
there rather than duplicated in the index list. Two copies of a description are two things to
keep in step, and the sync would have to rewrite both from the same doc.

!!! note "A bare status is correct, not unfinished"
    A machine whose Drive folder is empty carries a name and a status and nothing else — and
    its own page carries one sentence saying there is no design documentation yet. The
    publishing rule is *never invent content*. Writing a plausible sentence about what an
    etcher does would produce copy that traces to no document — and because the sync diffs the
    HTML against Drive, there would be nothing in Drive to diff it against, so the invented
    prose would neither be corrected nor removed. It would sit on a public page indefinitely,
    indistinguishable from sourced content. The `.status` span carries the entire message on
    its own: `Planned`.

### A `.member-list` entry

`Team` in `index.html` is a `<ul class="member-list">`. Name, an `&mdash;` separator, and
role:

```html
<li><span class="name">Leonard Jin</span> &mdash; <span class="role">President</span></li>
```

The faculty-advisor variant links from inside the `.name` span, for the same reason the
stepper entry does:

```html
<li><span class="name"><a href="https://cse.umn.edu/ece/joseph-talghader">Prof. Joseph &ldquo;Joey&rdquo; Talghader</a></span> &mdash; <span class="role">Faculty Advisor</span></li>
```

Only officers and the faculty advisor appear here. The general-member roster in
`Engineering Structure` is read for role assignments and never published — those are
students' full names on a public, search-indexed page and they have not opted in.
Officer names are already public through RSO registration, which is what makes the
officer rows publishable and the member rows not. Changing this needs the members'
consent, not a sync-time decision.

### A machine subpage header

Every machine page opens with the same three elements — an `<h1>` carrying the machine's name
as Drive spells it, a `p.status`, and, **only when a document's text names one**, a
`p.project-lead`:

```html
<section>
  <h1>DC Magnetron Sputterer</h1>
  <p class="status">In design</p>
  <p class="project-lead">Lead: Bear Blinschauer</p>
</section>
```

`main h1` is styled the way `h2` is on `index.html`, so a machine page's title and the home
page's section headings read as the same level of thing. The status string reuses one of the
values already in play — `In build`, `In design`, `Design complete`, `Design and bill of
materials`, `Architecture design`, `Planned` — rather than coining a synonym.

**A page with no lead simply omits the `p.project-lead` line.** There is no placeholder, no
`Lead: TBD`, and no name inferred from who owns the folder. See
[One page per machine](#one-page-per-machine).

The rest of the page is `<h2>` sections — "What It Does", "Subsystems", a timeline — each
present only where a Drive doc supports it.

### A `.table-wrap` table row

Tables on the machine pages — Key Components, Project Timeline — are a `<table>` inside a
`<div class="table-wrap">`. There is no `<thead>`; the header row is a plain `<tr>` of `<th>`:

```html
<div class="table-wrap">
  <table>
    <tr><th>Component</th><th>Role</th></tr>
    <tr><td>410 nm Lumiled UV LEDs</td><td>Exposure light source</td></tr>
  </table>
</div>
```

The Project Timeline table takes three cells per row — stage, timeline, milestone:

```html
<tr>
  <td>System assembly</td>
  <td>Weeks 2 &ndash; 5</td>
  <td>Stepper mechanically assembled and electrically connected</td>
</tr>
```

`.table-wrap` is the only thing keeping a wide table from forcing the whole page to
scroll sideways: it sets `overflow-x: auto`, and `table` sets `width: 100%`. Dropping the
wrapper does not break the table — it breaks the page around it on a phone, silently and
only at narrow widths.

Row striping comes from `tr:nth-child(even) td`, which counts the header row. Rows are
styled by position, so inserting a row re-stripes everything below it; that is expected
and needs no markup change.

---

## Class vocabulary { #class-vocabulary }

**This list is exhaustive.** `style.css` defines exactly these selectors and no others.
A class name that does not appear below has no rule behind it and renders as unstyled
text, because the sheet opens with a `*` reset that strips default margins and padding.

| Selector | What it is for |
| --- | --- |
| `.header-inner` | Width-constrained wrapper inside `<header>` — the 860px column |
| `.tagline` | "University of Minnesota Twin Cities" line under the site title |
| `nav a` | Header navigation links |
| `nav a.active` | The current page's nav link — gold text and gold underline |
| `nav .nav-label` | The non-link label inside the nav row |
| `main h1` | A machine subpage's title — styled to read as the same level as an `index.html` `<h2>` |
| `p.status` | A machine subpage's status line — small sans-serif, muted, italic |
| `p.project-lead` | A machine subpage's `Lead: <name>` line — same size, upright, more space beneath |
| `.member-list` | The `<ul>` in "Team"; removes bullets and the list indent |
| `.member-list .name` | Member name — bold |
| `.member-list .role` | Member role — muted and italic |
| `.project-list` | The `<ul>` in "Current Projects"; removes bullets and the list indent |
| `.project-list .name` | Project name — bold, slightly enlarged |
| `.project-list .status` | Status chip — small sans-serif, muted, italic, inline after the name |
| `.project-list p` | Optional project description — tightened top margin, reduced size. Defined, currently unused |
| `.table-wrap` | Horizontal-scroll wrapper for a wide `<table>` |
| `table`, `th`, `td` | Full-width bordered table; `th` is maroon with white sans-serif text |
| `tr:nth-child(even) td` | Alternating row background |
| `.note` | The cream callout box in "Get Involved" |
| `.footer-inner` | Width-constrained wrapper inside `<footer>` |
| `.footer-inner .synced` | The "last updated" line — see [the footer contract](#footer-contract) |

`.name` is not a shared class. It is defined twice, scoped by parent, with different size
rules under `.member-list` and `.project-list`; a `.name` span outside both lists matches
neither rule and gets no styling at all.

Colors come from custom properties on `:root`, never from literals in the markup:

| Property | Value | Role |
| --- | --- | --- |
| `--maroon` | `#7a0019` | UMN maroon — header background, headings, links, left rules |
| `--maroon-dark` | `#5b0013` | `<h3>` text |
| `--gold` | `#ffcc33` | UMN gold — header underline, tagline, active nav |
| `--ink` | `#222222` | Body text |
| `--muted` | `#666666` | Roles, statuses, footer |
| `--paper` | `#ffffff` | Card and table backgrounds |
| `--bg` | `#faf8f5` | Page background |
| `--line` | `#e5e0d8` | Borders and heading rules |

Adding a class means editing `style.css`, which the publishing rules allow only when a
genuinely new content type needs it. Reuse an existing selector first: almost every new
piece of content is a project entry, a member entry, a table, or a `.note`.

---

## The footer contract { #footer-contract }

`index.html` closes with a `.synced` span carrying the site's sync timestamp:

```html
<span class="synced">Project information synced from the club Google Drive &middot; last updated 2026-08-30</span>
```

**Bump the date whenever content changes.** It is the only externally visible signal that
the mirror is current; a reader has no other way to tell a site synced this week from one
abandoned in the spring, and the sync leaves no other trace on the page.

**No machine subpage carries a `.synced` span**, and that asymmetry is deliberate rather than
an oversight: **one page carries the sync timestamp for the whole site.** With nine subpages
the argument is stronger than it was with one. The date reports when the site last matched
Drive, not when a particular file was last touched. Giving each page its own span would change
what the number means — a run that updates only the stepper timeline would bump `stepper.html`
and leave the other nine pages reading days stale, and every date would then be honest about
its own file while the set of them jointly misreported the freshness of the mirror. One
timestamp cannot drift out of step with nine that do not exist.

Every machine page reaches the reader through `index.html`'s project list and the shared nav,
so the page carrying the date is the page every visitor passes through.

---

## Content that is not Drive-sourced { #not-drive-sourced }

Four items on the site come from outside Drive. The never-invent rule governs *claims*,
not *links*: a link to a public reference page is not a claim about the club, so these are
authorized in place.

| Content | Where | Authorized by |
| --- | --- | --- |
| `https://cse.umn.edu/ece/joseph-talghader` | `index.html` — Team, inside the advisor's `.name` span | `SYNC.md` rule 2, link clause |
| `https://docs.hackerfab.org/home` | `index.html` — About; `stepper.html` — intro | same clause |
| `https://arxiv.org/pdf/2510.15082` (CMU stepper paper) | `stepper.html` — intro | same clause |
| `jin00404@umn.edu` | `index.html` — Get Involved | `SYNC.md`: the one email published on the site, added at Leonard's request 2026-08-18 |

!!! warning "These must be preserved across every sync"
    A sync rebuilds each section by diffing the HTML against its Drive source. These four
    items have no Drive source, so a rebuild that trusts the mapping table alone reads
    them as content with nothing behind it and drops them — silently, with no error and
    no prose explaining the removal. The failure is easy to miss even now that a human
    reviews every proposal before it publishes: the section still renders, still reads
    correctly, and has simply lost its outbound links and the club's only published contact
    address, so the only trace is a `-` line in a diff full of legitimate `-` lines. Carry
    them forward explicitly on every run, and check for all four by name when reviewing —
    see [Reviewing a Proposed Update](operations/reviewing-changes.md#what-to-check-in-the-diff).

`jin00404@umn.edu` is the **only** address published anywhere on the site. Members' and
the advisor's addresses appear in Drive docs and must not be lifted onto the page, no
matter which doc a sync happens to read them from.

Verify a link resolves and points at the right subject before adding a new one. Do not
guess a URL — a plausible-looking dead link is worse than no link, because it reads as
sourced.

---

## The excluded doc { #excluded-doc }

`Minnesota Nanofabrication Club (MNF)/Club Website — How It Works` sits inside a
folder the mapping table draws from, but it is documentation *about* the sync, written
for club members. **Never publish it.** It is not content for the site.

!!! note "If it drifts, flag it — never edit it silently"
    When that doc contradicts `SYNC.md` or `CLAUDE.md`, report the discrepancy in the run
    summary and stop. It is a Drive doc club members read directly, outside version
    control, so a silent correction is unrecoverable and invisible: no commit, no diff, no
    way for the person who wrote it to see that their explanation changed. Flagging keeps
    the decision with a human who can also fix whatever made the two disagree.

    It has in fact drifted, and twice over. It describes a cloud routine that could not
    publish, and states that "Nothing runs on anyone's laptop" — a sentence that was true when
    written, became false when the sync moved to a `launchd` job on one Mac, and is true again
    now that the sync runs in GitHub Actions, for reasons the document does not give. A doc
    that is accidentally right is not right. A human updates it in Drive; see
    [The Cloud Sync](operations/cloud-sync.md#why-the-sync-lives-here) for what actually runs.
