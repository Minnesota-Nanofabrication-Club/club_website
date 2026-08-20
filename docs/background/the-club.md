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
demonstrate a custom compute kernel through an open, vertically integrated semiconductor
workflow.

| Half | Scope as published |
| --- | --- |
| **Build the Fab** | Develop an open semiconductor fabrication process — from fabrication equipment to functioning transistors and logic gates — capable of producing custom integrated circuits. |
| **Design the Compute Kernel** | Design a custom compute primitive that is mathematically sound, hardware efficient, and validated through simulation, FPGA implementation, and commercial silicon. |

The two halves are not decoration on the site; they are the top-level structure of the
Drive as well. `Build the Fab/` and `Design the Compute Kernel/` are sibling folders under
the Drive root, and each feeds a different part of the page. The mapping is in
[Data Contracts](../data-contracts.md).

The phrase "Full Stack Codesign" and the framing of the two halves come from the
`Project and Goals` document. When mission language on the site needs to change, that
document is where it changes.

---

## The fabrication line

"Current Projects" on `index.html` lists one entry per tool. Each tool is a self-contained
build with its own architecture, timeline, and bill of materials; together they make up the
fabrication line.

| Project | Published status |
| --- | --- |
| Maskless Lithography Stepper | In build — prototype targeted this semester |
| Sputterer | Design and bill of materials |
| Tube Furnace | Architecture design |
| Photoresist Spinner | Architecture design |
| Etcher | Planned |
| Compute Kernel | In design |

The **Maskless Lithography Stepper** is the only project with its own page, `stepper.html`.
It projects circuit patterns directly onto photoresist-coated substrates using a
UV-retrofitted DLP projector, microscope optics, machine-vision alignment, and a motorized
XYZ stage — no photomasks required.

The **Compute Kernel** entry is the other half of the program appearing in the same list: the
custom compute primitive the fab is being built to produce, validated through simulation,
FPGA implementation, and commercial silicon before it reaches the club's own process.

!!! note "The Etcher entry has no description, and that is correct"

    Every other entry carries a `<p>` of descriptive copy. The Etcher entry is a bare name
    and a status, because its Drive folder is empty. Rule 1 of the sync — never invent
    content — means an empty folder gets a bare status and nothing else. An agent that
    "improves" the site by writing a plausible sentence about etching has broken the rule
    that makes every other sentence on the page trustworthy. The Etcher entry is also the
    test fixture used to prove the sync's write-back path; see
    [Why the Sync Runs Locally](why-local-not-cloud.md).

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
