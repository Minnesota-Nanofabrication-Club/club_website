# The Club

The Minnesota Nanofabrication Club is a student organization at the University of Minnesota
Twin Cities building an open, vertically integrated semiconductor program. This page covers
what the club does and what the public site exists to communicate — it is not a project
reference, and it deliberately states only what the site itself states.

**Every claim on this page traces to `index.html` or to a Drive document that feeds it.**
That constraint is not stylistic; it is the same rule the sync runs under, described in
[Why Google Drive Is the Source of Truth](why-drive-is-truth.md).

---

## What the club is

A student organization at the University of Minnesota Twin Cities, registered as an RSO
(registered student organization), rebuilding the semiconductor stack from first principles.

The premise stated in the site's About section: every abstraction in a modern chip exists
for a reason, and the way to understand why each layer exists is to rebuild the entire stack
— designing a custom compute kernel, developing the fabrication equipment and processes
needed to manufacture it, and integrating both into a functioning silicon system.

The stated initial goal is to fabricate micron-scale transistors, then systematically improve
the process toward submicron feature resolution.

Membership is open to all currently enrolled undergraduate students at the University of
Minnesota Twin Cities. No prior fabrication experience is required.

!!! info "For readers outside the university: what an RSO is"

    A *registered student organization* is a student group formally recognized by the
    university. Registration requires filing a constitution and a set of officer signatures.
    That filing requirement is the origin of the one documented trap in this repository —
    see [The Officer Roster Decision](roster-decision.md).

---

## Full Stack Codesign — the two halves

The program is described on the site as one project with two halves: design, fabricate, and
demonstrate a **custom integrated circuit** through a vertically integrated fabrication
workflow.

| Half | Scope as published |
| --- | --- |
| **Build the Fab** | Design, fabricate, and demonstrate a custom integrated circuit (IC) through a vertically integrated fabrication workflow. |
| **Design the IC** | Published as *"There is no design documentation for this half yet."* — the Drive folder holds nothing the site can source from. |

The two halves are not decoration on the site; they are the top-level structure of the Drive as
well. `Build the Fab/` and `Design the IC/` are sibling folders under the Drive root, and each
feeds a different part of the page. The mapping is in
[Data Contracts](../data-contracts.md).

!!! note "The second half says nothing, on purpose"
    A heading with one honest sentence under it is what rule 1 produces from an empty folder.
    The alternative — a paragraph about compute primitives, simulation and FPGA validation
    written from general knowledge — would read better and trace to nothing. The wording of
    this half was corrected against Drive in commit `30968c1`; it previously described a
    "compute kernel" rather than a custom IC.

The phrase "Full Stack Codesign" and the framing of the two halves come from the
`Project and Goals` document. When mission language on the site needs to change, that
document is where it changes.

---

## The fabrication line

"Current Projects" on `index.html` lists one entry per machine, and **every machine has its own
page**. Each is a self-contained build with its own architecture, timeline, and bill of
materials; together they make up the fabrication line.

| Machine | Page | Published status |
| --- | --- | --- |
| Maskless Lithography Stepper | `stepper.html` | In build — prototype targeted this semester |
| DC Magnetron Sputterer | `sputterer.html` | In design |
| Tube Furnace | `tube-furnace.html` | Design complete |
| Reactive-Ion Etcher | `etcher.html` | Planned |
| Photoresist Spinner | `spinner.html` | Architecture design |
| Photoresist Developer | `developer.html` | Planned |
| Probe Station | `probe-station.html` | Planned |
| Ultrasonic Cleaner | `ultrasonic-cleaner.html` | Planned |
| Wafer Arm | `wafer-arm.html` | Planned |

Ten pages in total, then: the home page plus one per subfolder of `Build the Fab`. **A new
subfolder in Drive means a new page**, not an editorial decision — see
[One page per machine](../data-contracts.md#one-page-per-machine).

The **Maskless Lithography Stepper** is the furthest along. It projects circuit patterns
directly onto photoresist-coated substrates using a UV-retrofitted DLP projector, microscope
optics, machine-vision alignment, and a motorized XYZ stage — no photomasks required.

The other half of the program — the custom compute kernel the fab is being built to produce,
validated through simulation, FPGA implementation and commercial silicon before it reaches the
club's own process — is described in the "Full Stack Codesign" section rather than as a
machine in this list.

!!! note "A bare status with no description is correct, not unfinished"

    Several entries carry a name and a status and nothing else, and their pages say only that
    there is no design documentation yet. That is because those Drive folders are empty. Rule 1
    of the sync — never invent content — means an empty folder gets a bare status and stops. An
    agent that "improves" the site by writing a plausible sentence about what an etcher does
    has broken the rule that makes every other sentence on the page trustworthy.

    The Etcher entry is also the fixture the sync's write-back path was proved with, on
    2026-08-18: it was deleted from `index.html` by hand (`0593a4a`) and the next run restored
    it (`7dd018c`) without being asked. It is the smallest possible piece of Drive-derived
    content, which is what makes it an unambiguous, easily-reverted break to test against.

---

## Hacker Fab

The club is active in the broader **Hacker Fab** community and contributes open designs,
documentation, and experimental results that make semiconductor fabrication more accessible.
The site links to `https://docs.hackerfab.org/home` from the About section and from
`stepper.html`.

That link, the advisor's UMN faculty page, and the CMU stepper paper on `stepper.html` are
the three external references the site carries. None of them is sourced from Drive, and all
three are explicitly preserved across syncs — the sync rules govern *claims*, not *links*.

---

## What the site is for

The public site is an overview for people who do not know the club. It is not a
documentation mirror.

- A prospective member should be able to learn what the club builds, what is underway, who
  to contact, and whether they are eligible to join.
- Depth belongs in Drive. A few sentences per project is the intended level of detail.
- The single published contact address is `jin00404@umn.edu`, in "Get Involved". No other
  member or advisor addresses are published, even though they appear in Drive documents.

The site is plain HTML and CSS with no build step, no frameworks, and no external assets,
served by GitHub Pages from `main`. That constraint is itself a standing rule rather than an
accident of how it started; see [Design Principles](../architecture/design-principles.md).

---

## Who is named on the site

`index.html` publishes four people: Leonard Jin (President), Andrew Choi (Vice President),
Bear Blinschauer (Officer), and Prof. Joseph "Joey" Talghader (Faculty Advisor).

The general-member roster is deliberately absent, and the officer list is deliberately *not*
taken from the club's constitution. Both of those are load-bearing decisions with a
documented history — [The Officer Roster Decision](roster-decision.md) covers them.
