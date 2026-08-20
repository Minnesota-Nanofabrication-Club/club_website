# Why Google Drive Is the Source of Truth

The club's real work happens in the **Ultra Hardcore Chip Codesign** Google Drive. This
repository holds a mirror of a small, public-facing subset of it. This page explains why the
direction of authority runs Drive → repo and never the reverse, what that arrangement buys,
what it costs, and why a precedence rule *between* Drive documents is also required.

**The rule in one line: Google Drive is authoritative over this repository.** Do not
hand-edit project copy in the HTML; change the Drive document instead.

---

## The arrangement

Drive root: **Ultra Hardcore Chip Codesign**, id `1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP`.

A twice-weekly job — Monday and Thursday — reads the Drive folders, diffs their meaningful
content against the current HTML, edits `index.html` and `stepper.html` where they disagree,
commits, and pushes to `main`. GitHub Pages redeploys automatically. The folder-to-section mapping is the contract:

| Drive location | Feeds |
| --- | --- |
| `Minnesota Nanofabrication Club (GopherFab)/Project and Goals` | "Full Stack Codesign" |
| `Minnesota Nanofabrication Club (GopherFab)/Engineering Structure` | "Team" |
| `Minnesota Nanofabrication Club (GopherFab)/Minnesota Nanofabrication Constitution` | "About" / "Get Involved" |
| `Build the Fab/*` (one subfolder per tool) | "Current Projects", one entry per subfolder |
| `Build the Fab/Maskless Lithography Stepper/Project Timeline` | `stepper.html` timeline table |
| `Design the Compute Kernel/` | "Compute Kernel" entry |

The full field-level contract, including tag conventions (`[LR]`, `[D]`, `[Master]`) and the
documents that are never published, is in [Data Contracts](../data-contracts.md).

---

## What breaks without it

The naive arrangement is the obvious one: the club keeps its documents in Drive, and someone
edits the website when the website needs changing. That arrangement fails in two specific
ways, and both have been observed in student organizations generally enough that the
repository was designed against them from the start.

**Failure one: two divergent copies with no tiebreaker.** Once a project's status exists both
as a sentence in `index.html` and as a paragraph in a `[Master]` doc, the two drift the first
time anyone updates one and not the other. Nothing detects the drift, because nothing
compares them. A visitor then reads "Architecture design" on the site while the team has been
in build for a month, and the person who spots it has no way to know which copy is stale —
both look equally authoritative, both were written by the same club, neither carries a
timestamp that means anything. Making Drive authoritative does not prevent the two copies
from existing; it makes one of them *derived*, so the question "which is right?" has an
answer that does not require asking anyone.

**Failure two: the site nobody remembers to update.** Editing a website is a separate task
from doing the work the website describes, and it is the task that gets dropped. A club site
that requires a deliberate human act to stay current goes stale in weeks — the semester's
work happens in Drive because that is where collaboration is convenient, and the HTML keeps
describing last semester. Deriving the site from Drive removes the separate task entirely:
updating the Drive doc *is* updating the site, on a delay of at most four days. Nobody has to
remember anything.

!!! warning "The cost: you cannot fix the site by editing the site"

    This is a real cost, not a technicality. A hand-edit to project copy in `index.html`
    survives exactly until the next sync notices that the HTML disagrees with Drive and
    rewrites the HTML to match. The edit vanishes, no error is raised, and the commit that
    removed it looks like an ordinary sync commit.

    The correct move is always: change the Drive document, then run the sync (or wait for
    the next Monday or Thursday). Structural and design changes to the HTML — markup,
    `style.css`, page layout — are safe, because the sync only rewrites content. Project
    *copy* is not safe.

There is one guard against losing work this way. The sync refuses to run at all if the
working tree has uncommitted changes: it logs
`SKIP: uncommitted local changes present; not syncing over them.` and exits `0`. That
protects work in progress, but it does nothing for a hand-edit that was already committed —
that one gets overwritten on the next run.

---

## Why a precedence rule between Drive documents is needed

Making Drive authoritative settles repo-versus-Drive conflicts. It does not settle
Drive-versus-Drive conflicts, and those are the harder ones.

The Drive holds several documents written at different times, by different people, for
different audiences. A constitution is written once for a registration filing and then rarely
touched. An engineering structure document is edited whenever the club reorganizes. A
project's `[Master]` doc is edited whenever that project moves. Nothing keeps them consistent
with each other, and nothing *should* — they serve different purposes.

So two documents will eventually disagree, and an agent reading both needs a deterministic
answer. Without a stated precedence, the tie is broken by whichever document the agent read
last, or by which one sounds more official — and "sounds more official" reliably picks the
constitution, which is the wrong answer for exactly the topic where it is most tempting.
The result is not a random error but a *consistent* one that reappears on every run, because
the same reasoning produces the same wrong conclusion every time.

**The precedence table:**

| Topic | Ground truth | Why |
| --- | --- | --- |
| Engineering / organizational structure — who holds which role, who owns which project, how teams are organized | **`Engineering Structure`** | Always wins. It reflects how the club actually operates and is kept current. |
| Club purpose, membership eligibility, governance, formal policy | `Minnesota Nanofabrication Constitution` | Reference material. Cite it for purpose and eligibility language. |
| Project scope, status, timelines, BOMs | That project's folder under `Build the Fab` | Each tool's `[Master]` and timeline docs. |
| Overall mission framing | `Project and Goals` | Source of the "Full Stack Codesign" language. |

The table is organized by *topic*, not by document rank. No document is globally superior;
each is authoritative over the subject it is maintained for and subordinate everywhere else.
The constitution is ground truth for eligibility language and simultaneously not evidence at
all about who the officers are.

That last case is not hypothetical — it is the discrepancy the whole table was written to
resolve, and it has a page of its own: [The Officer Roster Decision](roster-decision.md).

---

## The rules the mirror runs under

Precedence decides *which* document wins. These decide what may cross from Drive to the
public page at all.

1. **Never invent content.** Every claim on the site traces to a Drive doc. An empty project
   folder gets a bare status ("Planned"), never invented prose.
2. **Stay concise.** The site is an overview for people who do not know the club, not a
   documentation mirror.
3. **Never publish internal material** — budgets, funding status, vendor names or pricing,
   BOM costs, sponsorship correspondence, professor-outreach notes, or `[MASTER]` to-do
   lists.
4. **Roster:** officers and the faculty advisor by name; never the general-member roster.
5. **Preserve the design.** No frameworks, no external assets, no build step.
6. **Update the "last updated" date** in the `index.html` footer whenever content changes.
7. **If nothing in Drive changed, make no commit.**

!!! note "Rule 1 governs claims, not links"

    The site's three external links — the advisor's UMN faculty page, `docs.hackerfab.org`,
    and the CMU stepper paper — are not Drive-sourced and are deliberately preserved. So is
    the single published contact address, `jin00404@umn.edu`, added at Leonard's request on
    2026-08-18. An agent enforcing rule 1 too literally would strip all four as unsourced.

---

## Documentation about the site is not content for the site

`Minnesota Nanofabrication Club (GopherFab)/Club Website — How It Works` lives in Drive
alongside the content documents, but it explains the sync process to club members. It is
documentation *about* the website, not content *for* it, and it is never published.

It also must never be silently edited. If it drifts out of step with `SYNC.md` or
`CLAUDE.md`, the correct action is to flag the drift in the run summary and leave the
document alone — a human decides which side is wrong.

!!! warning "That document has in fact drifted"

    As of 2026-08-19 it still claims the sync runs in the cloud and that "Nothing runs on
    anyone's laptop." That stopped being true at commit `99e3012`. See
    [Why the Sync Runs Locally](why-local-not-cloud.md) for what actually runs.
