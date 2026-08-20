# The Officer Roster Decision

Two Drive documents name different people as the club's officers. This page records which one
wins, why, and — more importantly — why an agent or officer who later notices the discrepancy
must leave it alone rather than fix it. It also covers the separate rule that keeps general
members off the site entirely.

**This is the specific mistake the precedence table in
[Why Google Drive Is the Source of Truth](why-drive-is-truth.md) exists to prevent.** It has
been gotten wrong once already.

---

## The discrepancy

The `Minnesota Nanofabrication Constitution` carries an **officer signature block**. That
block lists Vikram Narra, Davit Sandoyan, Harshit Mehendiratta and John Jeong as "Officers",
and it omits Bear Blinschauer.

The `Engineering Structure` document names a different set of people in different roles.

| Source | What it says | Status |
| --- | --- | --- |
| `Engineering Structure` | Leonard Jin — President; Andrew Choi — Vice President; Bear Blinschauer — Officer; Prof. Joseph "Joey" Talghader — Faculty Advisor; everyone else listed — Members | **Ground truth.** Publish this. |
| `Minnesota Nanofabrication Constitution`, officer signature block | Vikram Narra, Davit Sandoyan, Harshit Mehendiratta, John Jeong as "Officers"; Bear Blinschauer absent | Registration artifact. Not a roster. Never publish. |

The four names in the constitution's block appear in this documentation only as the contents
of that documented artifact. They are discussed here so the discrepancy is recognizable on
sight; they are not a roster, not current officers, and are not published on the site.

---

## Why the constitution is not evidence here

**The signature block exists to satisfy the RSO registration requirement of five officer
signatures.** It is a filing artifact — a set of signatures collected once, at registration
time, to meet a university form's minimum count. It was never intended to describe who runs
the club, and it is not updated when the club reorganizes, because nothing about registration
requires it to be.

`Engineering Structure`, by contrast, describes how the club actually operates and is kept
current. It is edited when roles change. That is the entire basis of the precedence rule: the
document that is maintained for a purpose is authoritative for that purpose, and a document
that is maintained for a different purpose is not evidence about it at all — no matter how
formal it looks.

!!! danger "Do not 'reconcile' the discrepancy"

    A sync that reads both documents will notice they disagree. The tempting, wrong move is
    to treat the constitution as the more official source and "fix" the site by pulling names
    out of its signature block onto the Team section.

    **Do not do this.** The result publishes four people who are not the officers, drops the
    officer who is, and does it on a public, search-indexed page. Follow `Engineering
    Structure` and move on.

    Resolved by Leonard on **2026-08-18**. It is settled, not open. Do not re-litigate it in
    a run summary either — the discrepancy is expected and needs no report.

**Why this needs to be written down at all.** The failure is not a random slip; it is
*reproducible*. Any reader — human or agent — encountering a constitution and an
informally-named "Engineering Structure" doc will rank the constitution higher on prior
reasoning about what a constitution is. That reasoning yields the same wrong answer on every
run, and the wrong answer looks like diligence: it presents as an agent catching an
inconsistency and correcting it. Nothing in the source documents themselves marks the
signature block as a filing artifact. The only place that fact can live is here, in
`CLAUDE.md`, and in `SYNC.md` — which is why it is stated in all three.

---

## What is published

`index.html` publishes four people, in the "Team" section:

| Name | Role |
| --- | --- |
| Leonard Jin | President |
| Andrew Choi | Vice President |
| Bear Blinschauer | Officer |
| Prof. Joseph "Joey" Talghader | Faculty Advisor |

The advisor's name links to `https://cse.umn.edu/ece/joseph-talghader`, his UMN faculty page.
That link is one of the deliberately preserved non-Drive-sourced links.

---

## The separate rule: general members are not published

This is a different decision from the one above, resting on a different reason, and the two
must not be collapsed into each other.

**Officers and the faculty advisor are published by name. General members are not.**

- General members' names are **students' full names on a public, search-indexed page**, and
  they have not opted in. Publishing a roster puts a person's name, university, and club
  affiliation into search results permanently, on the strength of nobody's decision but the
  club's.
- Officer names are in a different position: they are **already public via RSO
  registration**. Publishing them discloses nothing that is not already disclosed.

That asymmetry is the whole justification. It is not a judgment that officers matter more; it
is that consent already exists in one case and does not exist in the other.

!!! warning "Changing this needs the members' consent, not a decision"

    If the club wants a full roster on the site, the sequence is: get the members' consent,
    change the rule in `SYNC.md` and `CLAUDE.md`, then change the site. An agent may never
    make this change on its own initiative, and neither may a single officer — the people
    whose names would be published are the ones who have to agree.

The same instinct that produces the roster mistake produces this one: an `Engineering
Structure` doc that lists every member reads like a complete team roster waiting to be
mirrored. It is not. Publish the four roles above and stop.

Since the sync stopped publishing directly, a human sees every change to
`<ul class="member-list">` in a pull request before it is public — a fifth name in that list
is the single check the reviewer's guide calls out in a `!!! danger`, because it is the one
review failure with consequences for a person who never agreed to any of this. The gate helps;
it is not a substitute for the rule. It catches one careless run, not a rule that was quietly
loosened first. See
[Reviewing a Proposed Update](../operations/reviewing-changes.md#4-the-roster).

---

## Related rules

The roster rule sits alongside the other things that are never published — budgets, funding
status, vendor names or pricing, BOM costs, sponsorship correspondence, professor-outreach
notes, and `[MASTER]` to-do lists. All of them live in Drive and stay there.

The single email address on the site is `jin00404@umn.edu`, the club president's UMN address,
added at Leonard's request on 2026-08-18. **No other member or advisor addresses are
published**, even though they appear in Drive documents. Full details are in
[Data Contracts](../data-contracts.md).
