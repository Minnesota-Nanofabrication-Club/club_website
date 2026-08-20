# Data Contracts

The canonical reference for what maps to what: which Google Drive document feeds which
page section, what markup each section expects, and which content on the site is
deliberately not Drive-sourced. **Every claim published on the site traces to one row of
one table on this page** — if it does not appear here, it does not belong in the HTML.

This page describes the contracts. The procedures that consume them live in
[Add a project entry](guides/add-project.md) and
[Design principles](architecture/design-principles.md).

## Contents

- [Drive → page-section mapping](#drive-mapping)
- [Drive tag conventions](#tags)
- [HTML contracts](#html-contracts)
- [Class vocabulary](#class-vocabulary)
- [The footer contract](#footer-contract)
- [Content that is not Drive-sourced](#not-drive-sourced)
- [The excluded doc](#excluded-doc)

---

## Drive → page-section mapping { #drive-mapping }

Root folder: **Ultra Hardcore Chip Codesign** — `1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP`

| Drive location | Feeds |
| --- | --- |
| `Minnesota Nanofabrication Club (GopherFab)/Project and Goals` | "Full Stack Codesign" section |
| `Minnesota Nanofabrication Club (GopherFab)/Engineering Structure` | "Team" section |
| `Minnesota Nanofabrication Club (GopherFab)/Minnesota Nanofabrication Constitution` | "About" / "Get Involved" (purpose, membership eligibility) |
| `Build the Fab/*` (one subfolder per tool) | "Current Projects" — one entry per subfolder |
| `Build the Fab/Maskless Lithography Stepper/Project Timeline` | `stepper.html` timeline table |
| `Design the Compute Kernel/` | "Compute Kernel" project entry |

The mapping is one-directional and total. `Build the Fab/*` is the only wildcard row:
one subfolder produces exactly one `<li>` in `.project-list`, which is why the six
entries in `index.html` are six subfolders and not an editorial selection. A tool that
appears in Drive but not on the site is a missed sync, not a decision.

Drive is authoritative over the repo in both directions of disagreement. Hand-editing
project copy in the HTML does not update Drive, so the next sync diffs the edited HTML
against the unchanged Drive doc and reverts it — the edit survives until the next scheduled
run, at most four days, and then disappears with no record of why. Change the Drive doc
instead.

---

## Drive tag conventions { #tags }

Documents and folders in Drive carry a leading bracket tag naming their role.

| Tag | Meaning | Published? |
| --- | --- | --- |
| `[LR]` | Learning resource — reference material the club reads | **Never.** Reference material is not club output; publishing it would present someone else's tutorial as a project claim. |
| `[D]` | Documentation | Only through the mapping table above, and only the concise subset. |
| `[Master]` | The main outline doc for that folder | Read it for scope and status; the `[MASTER]` to-do lists inside it are internal and never published. |

An untagged doc is not implicitly publishable. The mapping table decides what is read;
the tags decide what is disqualified inside a folder that is otherwise in scope.

---

## HTML contracts { #html-contracts }

The site is plain HTML and CSS with no build step, so the markup shapes below *are* the
schema — nothing validates them and nothing fails loudly when they are wrong. A
malformed entry renders as unstyled body text rather than raising an error, so it looks
like sloppy copy rather than a broken contract.

### A `.project-list` entry

`Current Projects` in `index.html` is a single `<ul class="project-list">` with one
`<li>` per tool. The full shape, with the optional description:

```html
<li>
  <span class="name">Tube Furnace</span>
  <span class="status">Architecture design</span>
  <p>
    High-temperature furnace for the thermal steps of the process, including oxide
    growth and dopant drive-in.
  </p>
</li>
```

`<span class="name">` and `<span class="status">` are both required. `<p>` is optional.
When the tool has its own page, the link goes *inside* the `.name` span, never around
it — `.project-list .name` sets the weight and size, and a link wrapping the span
inherits neither:

```html
<span class="name"><a href="stepper.html">Maskless Lithography Stepper</a></span>
```

The bare form, with no `<p>`, is the Etcher entry as it stands in `index.html`:

```html
<li>
  <span class="name">Etcher</span>
  <span class="status">Planned</span>
</li>
```

!!! note "The bare Etcher entry is correct, not unfinished"
    `Build the Fab/Etcher` is an empty Drive folder. The publishing rule is *never invent
    content*, so an empty folder gets a bare status and nothing else. Writing a plausible
    sentence about what an etcher does would produce copy that traces to no document —
    and because the sync diffs the HTML against Drive, there would be nothing in Drive to
    diff it against, so the invented prose would neither be corrected nor removed. It
    would sit on a public page indefinitely, indistinguishable from sourced content. The
    `.status` span carries the entire message on its own: `Planned`.

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

### A `.table-wrap` table row

Both tables in `stepper.html` — Key Components and Project Timeline — are a `<table>`
inside a `<div class="table-wrap">`. There is no `<thead>`; the header row is a plain
`<tr>` of `<th>`:

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
| `.member-list` | The `<ul>` in "Team"; removes bullets and the list indent |
| `.member-list .name` | Member name — bold |
| `.member-list .role` | Member role — muted and italic |
| `.project-list` | The `<ul>` in "Current Projects"; removes bullets and the list indent |
| `.project-list .name` | Project name — bold, slightly enlarged |
| `.project-list .status` | Status chip — small sans-serif, muted, italic, inline after the name |
| `.project-list p` | Optional project description — tightened top margin, reduced size |
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
<span class="synced">Project information synced from the club Google Drive &middot; last updated 2026-08-19</span>
```

**Bump the date whenever content changes.** It is the only externally visible signal that
the mirror is current; a reader has no other way to tell a site synced this week from one
abandoned in the spring, and the sync leaves no other trace on the page.

`stepper.html` has no `.synced` span, and that asymmetry is deliberate rather than an
oversight: **one page carries the sync timestamp for the whole site.** The date reports
when the site last matched Drive, not when a particular file was last touched. Giving
each page its own span would change what the number means — a run that updates only the
stepper timeline would bump `stepper.html` and leave `index.html` reading days stale,
and both dates would then be honest about their own file while jointly misreporting the
freshness of the mirror. One timestamp cannot drift out of step with a second one that
does not exist.

`stepper.html` reaches the reader through the nav link in `index.html`, so the page
carrying the date is the page every visitor passes through.

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

`Minnesota Nanofabrication Club (GopherFab)/Club Website — How It Works` sits inside a
folder the mapping table draws from, but it is documentation *about* the sync, written
for club members. **Never publish it.** It is not content for the site.

!!! note "If it drifts, flag it — never edit it silently"
    When that doc contradicts `SYNC.md` or `CLAUDE.md`, report the discrepancy in the run
    summary and stop. It is a Drive doc club members read directly, outside version
    control, so a silent correction is unrecoverable and invisible: no commit, no diff, no
    way for the person who wrote it to see that their explanation changed. Flagging keeps
    the decision with a human who can also fix whatever made the two disagree.

    It has in fact drifted as of 2026-08-19 — it still describes the sync as running in
    the cloud and states that "Nothing runs on anyone's laptop", which stopped being true
    at commit `99e3012`.
