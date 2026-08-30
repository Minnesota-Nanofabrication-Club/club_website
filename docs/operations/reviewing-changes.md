# Reviewing a Proposed Update

What to do when the sync tells you it has something for you. The run that produced the
proposal is described in [Anatomy of a Sync Run](sync-run.md); the rules the diff is checked
against are in [Design Principles](../architecture/design-principles.md) and
[Data Contracts](../data-contracts.md). **Merging the pull request is what publishes. Until
somebody merges it, the live site is unchanged and stays unchanged.**

---

## Contents

- [What arrives](#what-arrives)
- [Opening the pull request](#opening-the-pull-request)
- [What to check in the diff](#what-to-check-in-the-diff)
- [Merging](#merging)
- [What happens after you merge](#what-happens-after-you-merge)
- [Closing it instead](#closing-it-instead)
- [Doing nothing](#doing-nothing)

---

## What arrives

A run that finds differences between Drive and the published site reports on three surfaces at
once:

| Channel | What it says |
| --- | --- |
| Discord | An amber `📋 Update proposed — review` embed, with an `@` mention if the `DISCORD_MENTION` secret is set |
| The job summary | `changed: true`, `published to main: no`, the commit subject, and the files touched |
| The pull request | Open on `sync/drive`, titled with the commit subject, body written by the workflow |

The Discord embed is posted by `scripts/notify-discord.sh` under the username `Website Sync`
and carries two things:

```
📋 Update proposed — review

Add the probe station subpage from Drive
Review and merge to publish: https://github.com/Minnesota-Nanofabrication-Club/club_website/pull/7
```

- **The headline is the commit subject** — one line written by the agent that made the
  change, taken from `git log -1 --format=%s`. It is also the pull request's title.
- **The link is the pull request.** Open it; the embed carries no diff and no Drive content,
  deliberately — the run log quotes Drive documents that hold budget and vendor material.

!!! note "`📋 Update proposed` is not `↻ Site updated`"
    Four embed styles exist. `✓ Site checked` (grey) means the run found nothing to do;
    `📋 Update proposed — review` (amber) means a pull request is waiting on you; `✗ Sync
    failed` (red) means the run broke. `↻ Site updated` (maroon) is the published-state style
    and the sync does not send it — the sync never publishes. Full table in
    [Notifications](notifications.md#the-four-states).

---

## Opening the pull request

Click the link in Discord, or from a clone:

```bash
R=Minnesota-Nanofabrication-Club/club_website
gh pr view --repo "$R" sync/drive --web      # open it in a browser
gh pr diff --repo "$R" sync/drive            # or read the diff in the terminal
```

Every proposal comes from the same branch, `sync/drive`, and there is **at most one open at a
time**. The branch is force-pushed from current `main` on every run that changes something, so
the diff you are looking at is *current Drive* against *currently published* — never a stack of
older proposals.

The body of the pull request is written by the workflow, not the agent: it names the changed
files, states that merging publishes, and notes that the branch is reset on every run.

!!! warning "Review the diff that is there now, not the one you read yesterday"
    If the run logged `Updated the open proposal: <url>`, a later run force-pushed a new
    proposal over the one you were reading, at the same URL, with the same PR number, and left
    a comment on the thread saying so. GitHub shows the current diff; an approval you left on
    the old one does not carry any meaning forward. Re-read before merging.

!!! warning "Check the age of the proposal too"
    Nothing closes a superseded proposal. A run that finds Drive and the site already in
    agreement makes no commit, and therefore never reaches the step that touches the branch or
    the PR — so a pull request whose change has since been made another way sits there, green
    and mergeable, indefinitely. If the diff describes something already live, close it rather
    than merging it. See
    [Nothing closes a stale proposal](sync-run.md#nothing-closes-a-stale-proposal).

---

## What to check in the diff

The agent follows the publishing rules, and the diff is where you confirm it did. Seven checks,
in the order they are cheapest to make:

### 1. Only the right files changed

Expect `index.html`, one or more machine subpages, `DRIVE_NOTES.md`, and occasionally
`style.css` when a genuinely new content type needs a class.

**Nothing under `docs/`, `.github/` or `scripts/`, and neither `CLAUDE.md` nor `SYNC.md`, can
appear** — the guard step fails the run without pushing if any of them changed, so a proposal
containing one cannot exist. If you are somehow looking at one, you are not looking at a
proposal this workflow made.

`DRIVE_NOTES.md` is the exception and its presence is normal: it is the agent's own working
memory, and it is the one tracked file the guard lets the agent write. Read its diff like any
other — each entry must carry a `REMOVE WHEN` condition, the file must stay at or under 20
entries, and it must never record costs, vendors, prices, contacts or member names.

### 2. Every claim traces to a Drive document

This is publishing rule 1 and the one the reviewer is genuinely needed for. For each changed
sentence, status or timeline row, ask which Drive document says it. A project folder that is
empty gets a bare status — `Planned`, `Architecture design` — and **no description at all**.

**What breaks otherwise:** an agent with no source for a tool writes fluent, plausible, wrong
prose — a build status the club has not reached, a capability the tool does not have, a
timeline nobody agreed to. Published under the club's name to prospective members, faculty and
the Hacker Fab community, that text is indistinguishable from a real commitment, and nobody
reading it can tell it was generated rather than sourced. An under-described project costs
nothing; a fabricated one costs credibility that editing the page later does not recover. The
folder-to-section mapping is in [Data Contracts](../data-contracts.md).

### 3. No internal material

Scan for anything in these categories, none of which may ever appear on the site:

- budgets and funding status
- vendor names, vendor pricing, BOM costs
- sponsorship correspondence
- professor- and advisor-outreach notes
- `[MASTER]` to-do lists and `[LR]` learning-resource content

The agent reads the Drive folders that hold all of this, so its presence in a diff is a rule
violation, not an impossibility. These are unrecoverable once published: a static page is
fetched, cached and archived within a minute of the merge.

### 4. The roster

!!! danger "Officers and the faculty advisor by name — never anyone else"
    `<ul class="member-list">` in `index.html` holds exactly four entries: Leonard Jin
    (President), Andrew Choi (Vice President), Bear Blinschauer (Officer), and Prof. Joseph
    "Joey" Talghader (Faculty Advisor). **A fifth name in that list is the one review failure
    with consequences for a real person**, and it is the reason a human reviews these diffs at
    all.

    A general-member roster puts students' full legal names on a public, search-indexed page,
    permanently associated with the club, discoverable by employers, and outside their control
    once crawled and cached. Those members have not opted in. Officers are different **only**
    because their names are already public through RSO registration, so publishing them
    discloses nothing new — that distinction is the entire justification for the line and it
    does not stretch to cover one more name.

    Publishing the roster requires **the members' consent**, not a reviewer deciding it would
    be nice to have. If the club decides otherwise, the rule changes in `SYNC.md` and
    `CLAUDE.md` first — see [Change a Publishing Rule](../guides/change-rules.md). Reject the
    proposal; do not "fix it after merging".

    Watch for the same failure in a second form: the Constitution's officer signature block
    names four people who are **not** the current officers. A proposal that swaps the Team
    section over to those names is the settled roster discrepancy being re-litigated — see
    [The Officer Roster Decision](../background/roster-decision.md). Reject it.

Email addresses follow the same logic: `jin00404@umn.edu` is the only address the site
publishes. Members' and the advisor's addresses appear in Drive documents; appearing there is
not consent to being published.

### 5. Every machine lead is quoted, not inferred

Each machine subpage may name **one** person responsible for that machine. That is the one
deliberate exception to the roster rule, and it is the point of the per-machine rebuild.

!!! danger "A lead must appear in the text of a document, saying so"
    **Who owns the Drive file, who created the folder, whose address is in the document
    properties, who edited it last — none of those name a lead.** Owning a file means somebody
    made a document.

    This is not hypothetical. A run on 2026-08-30 published `Lead: Davit Sandoyan` on the
    etcher and `Lead: Andrew Choi` on the spinner and the tube furnace purely because those
    accounts owned files in those folders. No document said any of it. **The review gate is
    what caught it**, before two members' full names reached a public, indexed page on the
    strength of a file-ownership record.

    When a lead appears in a diff, ask which sentence in which Drive doc says it. If you
    cannot be shown one, the name comes out. A guessed identity on a public page is worse than
    no name at all — and when a tracker cell disagrees with the machine's own doc, the
    machine's doc wins.

### 6. The four preserved non-Drive items are still present

These four are deliberately **not** Drive-sourced and must survive every sync. A proposal that
removes one is a regression, not a change:

| Item | Where |
| --- | --- |
| `https://cse.umn.edu/ece/joseph-talghader` — the advisor's UMN faculty page | `index.html`, Team |
| `https://docs.hackerfab.org/home` — the Hacker Fab documentation | `index.html` About, `stepper.html` |
| `https://arxiv.org/pdf/2510.15082` — the CMU stepper paper | `stepper.html` |
| `jin00404@umn.edu` | `index.html`, Get Involved |

An agent rewriting a section from Drive has no Drive source for any of them, so the failure
mode is deletion by omission — nothing in the diff announces it beyond a removed line. Search
the diff for a `-` on each. Full detail in
[Data Contracts](../data-contracts.md#not-drive-sourced).

### 7. The footer date moved

`index.html`'s footer carries a "last updated" date, and the agent is told to bump it **only
when it changes something**. A content diff with a stale footer date means the page will claim
to be older than it is; a footer-only diff means the run bumped a date without a reason to.
Either is worth a question before merging.

---

## Merging

Merge in the GitHub UI, or from the terminal:

```bash
gh pr merge --repo Minnesota-Nanofabrication-Club/club_website sync/drive
```

Merging is the approval step and the publishing step at once — there is nothing else to run
afterwards. The merge is authored by **you**, not by the workflow, which is what makes Pages
rebuild: a push made with the built-in `GITHUB_TOKEN` does not trigger downstream builds, and
the only thing the workflow pushes is `sync/drive`.

!!! warning "Leave the `sync/drive` branch alone"
    The workflow owns that branch: it force-pushes over it on every run that proposes anything.
    Do not commit your own work to it, and do not treat GitHub's post-merge "Delete branch"
    button as part of the process — the next run recreates and overwrites the branch
    regardless, so anything you put there is destroyed without warning. If a proposal needs a
    correction, make it on `main` through your own pull request, or fix the Drive document and
    let the next run re-propose.

---

## What happens after you merge

The merge lands the commit on `main`, and **GitHub Pages rebuilds from `main` automatically**
— the new version is live in about a minute. There is no build step and no workflow file;
Pages serves the committed files exactly as they are. See [Deployment](deployment.md).

The next scheduled run then finds `main` already matching Drive, logs
`No commit made — the site already matches Drive.`, reports `changed: false`, and posts a grey
`✓ Site checked` embed. That quiet run is the confirmation that the merge closed the loop.

If the page has not changed after a few minutes, work through
[When a push does not appear](deployment.md#when-a-push-does-not-appear) — the usual causes
are browser cache and a Pages build that has not finished.

---

## Closing it instead

Closing the pull request discards the proposal. Nothing is published, and nothing else in the
system changes.

**It does not stop the change coming back.** The sync re-derives its proposal from Drive on
every run, so if Drive still disagrees with the site, the next run commits the same change
again, force-pushes it, and — because `gh pr list --head sync/drive --state open` now finds
nothing — opens a **new** pull request for it. Closing is how you reject one diff, not how you
reject a change.

To stop a change permanently, change its source:

| Why you are closing it | What to do instead |
| --- | --- |
| The Drive document is wrong | Fix the Drive document; the next run proposes the corrected text |
| The content should never be published | Change the rule in `SYNC.md` and `CLAUDE.md` — see [Change a Publishing Rule](../guides/change-rules.md) |
| The agent misread a correct document | Close it, then trigger a run — **Actions → Sync from Drive → Run workflow** — and read the new proposal |
| Something in the diff looks unsafe | Close it and investigate before the next scheduled run |
| Its change is already on the site | Close it. Nothing else will — see [A stale proposal is still open](troubleshooting.md#stale-proposal-still-open) |

---

## Doing nothing

**An unreviewed proposal is not a queue. It is a change that never happens.**

Nothing merges the pull request on a timer, nothing re-pings, and no channel escalates. Every
run reports success either way, so from every monitoring surface the system looks healthy while
the site drifts further from Drive with each passing week.

What the next run does to an untouched proposal depends on what it finds:

| Next run finds | What happens to your open PR |
| --- | --- |
| Drive still disagrees with the site | Force-pushed over. Same URL, same PR number, a new diff — whatever you had half-read is gone, and a fresh `proposed` ping describes the *new* change. |
| Drive now matches the site | **Nothing at all.** The run makes no commit, so it never reaches the step that touches the branch or the PR. Your proposal stays open, green and mergeable. |

The second row is the one worth understanding, and it is the opposite of what the previous
design did — the deleted local script closed a stale proposal with a `Superseded:` comment.
Now nobody does. A proposal whose change has since landed another way is a green, mergeable
pull request whose merge republishes content that is already there, or that the agent has since
judged unnecessary — an approval button that lies about what approving does, sitting open
indefinitely. **Closing it is a human's job.** See
[Nothing closes a stale proposal](sync-run.md#nothing-closes-a-stale-proposal).

---

[← Notifications](notifications.md){ .md-button } [Troubleshooting →](troubleshooting.md){ .md-button .md-button--primary }
