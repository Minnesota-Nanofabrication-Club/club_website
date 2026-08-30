# Guide: Add a Project

How a new fabrication tool gets an entry in the **Current Projects** list on `index.html`
**and a page of its own**. The primary path is not editing HTML — **create the tool's folder
in Google Drive and let the next sync propose the page.** The manual path further down exists
only for when the entry has to be live before the next scheduled run — the workflow fires
Monday and Thursday, so that wait is at most four days plus however long the pull request
takes to merge.

---

## The Drive path — do this one

The Drive → HTML contract is one subfolder per machine, one page per subfolder: every
subfolder of `Build the Fab` becomes exactly one entry in `<ul class="project-list">` **and one
`<machine>.html` page linked from it and from the nav on every page.** Creating the folder is
therefore the entire change. See [Data Contracts](../data-contracts.md#one-page-per-machine)
for the full mapping.

### Step 1 — Create the folder in Drive

In the **Ultra Hardcore Chip D&F** Drive (root id `1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP`), create
a subfolder under `Build the Fab` named as the tool should read on the site.
`Build the Fab/DC Magnetron Sputterer` is the live example — it surfaces as the entry **DC
Magnetron Sputterer** and the page `sputterer.html`.

Do not tag the folder `[LR]` or `[D]`. `[LR]` marks learning resources, which are never
published — and are not even mirrored, so nothing about the folder reaches the agent. `[D]`
marks documentation, which is not a machine and gets no page.

### Step 2 — Put the sourcing material in it, or leave it empty

The folder's contents decide how much of the page the sync can write:

| What is in the folder | What the sync proposes |
| --- | --- |
| Nothing, or only a diagram link | An `<li>` with a bare status — `Planned` — and a page carrying the name, the status, and one sentence saying there is no design documentation yet |
| A `[MASTER]` outline or scope/status doc | Name, status, "What It Does", "Subsystems" — each section only where the doc supports it |
| A timeline doc that is genuinely about *this* machine | A timeline table on the page |
| A doc whose **text** names the person responsible | `Lead: <name>` under the status |
| Budgets, BOM costs, vendor pricing, `[MASTER]` to-do lists | Nothing — those never leave Drive |

An empty folder is a legitimate, finished state, and **omitting a section is better than
emptying it** — a heading with "TBD" underneath reads as a promise the club has not made.
**Never fill the gap with plausible prose.** A description with no Drive doc behind it cannot
be checked by the next person, the sync will not delete it, and the site then carries a claim
the club has no record of ever making.

!!! danger "Putting your name on the folder does not make you the lead"
    The `Lead:` line comes from a *sentence in a document*, never from Drive metadata. Owning
    the folder, creating the docs, or being the last to edit them names nobody, and a run on
    2026-08-30 published three leads on exactly that basis before the review gate caught it.
    If you want to be listed as the lead of a machine, **write it in that machine's
    `[MASTER]` doc.**

### Step 3 — Let the sync run, or trigger it now

The scheduled workflow (Monday and Thursday, 13:13 UTC) picks the folder up on its own. To get
the proposal sooner, trigger a run: **Actions → Sync from Drive → Run workflow**, or

```bash
R=Minnesota-Nanofabrication-Club/club_website
gh workflow run "Sync from Drive" --repo "$R"
gh run watch --repo "$R"
```

Everything the run prints is on that run's page; there is no log file anywhere. Equivalently,
ask Claude Code from inside a clone of the repo:

```
Sync the club website from Google Drive following SYNC.md.
```

### Step 4 — Merge the proposal

Either way the sync writes the `<li>`, writes the new page, adds it to the nav on every page,
updates the footer date, commits to `sync/drive`, and opens a pull request. **It does not
publish.** The page appears on the site when someone merges that pull request, and GitHub Pages
redeploys about a minute later:

```bash
gh pr diff  --repo "$R" sync/drive       # confirm the page matches the Drive folder
gh pr merge --repo "$R" sync/drive
```

Check the new page against the folder that produced it: an empty folder must yield the bare
form, any description must trace to a doc in *that* folder — never borrowed from another
machine's — and any `Lead:` line must be quotable from a document. The full checklist is in
[Reviewing a Proposed Update](../operations/reviewing-changes.md); full run and failure
handling is in [Anatomy of a Sync Run](../operations/sync-run.md).

!!! note "Regenerate the sitemap in the same pass"
    Nothing runs `scripts/generate_sitemap.py` automatically. A new machine page therefore
    lands on the site absent from `sitemap.xml`, and the omission is invisible — the page
    renders and links fine, it is just slower for Google to find. See
    [SEO](seo.md#robotstxt-and-sitemapxml).

!!! warning "An unmerged proposal is the likeliest way for a new project not to appear"
    The run reports success on every channel the moment the pull request is open, and nothing
    reminds anyone afterwards. If the tool is still missing from the site days later, look for
    an open PR before assuming the Drive folder was wrong — and note that a proposal left
    unmerged is force-pushed over by a later run that finds a different change to propose.

---

## The manual path — when the entry must exist now

Use this only when the site has to show the tool before a sync can run. **Create the Drive
folder first anyway.** A hand-written entry with no matching folder is content the sync cannot
corroborate — and since the sync writes one entry and one page per Drive subfolder, the entry
is orphaned from the contract that is supposed to keep it true.

### Step 1 — Open `index.html` and find the list

The entries live in `<ul class="project-list">` inside the **Current Projects** `<section>`.
Every entry comes from a subfolder of `Build the Fab`; the list is ordered roughly by how far
along the build is, so put a new `Planned` tool near the bottom.

### Step 2 — Paste the entry

Name, status, and a link to the page:

```html
<li>
  <span class="name"><a href="tool-name.html">Tool Name</a></span>
  <span class="status">Architecture design</span>
</li>
```

**The link goes inside the `.name` span, never around it** — `.project-list .name` sets the
weight and size, and a link wrapping the span inherits neither.

Two formatting details that match the rest of the file: write em dashes as the `&mdash;`
entity rather than a literal character, and add no new classes — `.name` and `.status` are
already styled in `style.css`, and inventing a class breaks the no-new-CSS rule in
[design principles](../architecture/design-principles.md).

### Step 3 — Create the page and add it to the nav

Copy an existing machine page as the template — `sputterer.html` is the plainest — and replace
its `<head>`, its `<h1>`, its `p.status`, and its body sections. The `<head>` template and the
title/description rules are in [SEO](seo.md#the-head-template); the page shape is in
[Data Contracts](../data-contracts.md#html-contracts).

**The nav is repeated in full on every page.** Adding a tenth machine means editing the nav in
all eleven files, and a page that is not in every nav is reachable only from the project list.

Omit `p.project-lead` unless a Drive document's text names the person responsible.

### Step 4 — Update the footer date

In the `<footer>` of `index.html`, set today's date in the `.synced` span:

```html
<span class="synced">Project information synced from the club Google Drive &middot; last updated 2026-08-30</span>
```

That date is the site's only signal of freshness. Leave it stale and a reader has no way to
tell a current page from one that stopped tracking Drive months ago. No machine page carries
one — the timestamp lives in exactly one place.

### Step 5 — Regenerate the sitemap, preview, then get it onto `main`

```bash
python3 scripts/generate_sitemap.py
python3 -m http.server 8000
```

Open `http://localhost:8000/index.html`, confirm the new `<li>` renders like its neighbours,
and click through to the new page from every nav. Then get the edit onto `main` — commit it
and push, or open your own pull request. Do **not** commit it to `sync/drive`: the next run
force-pushes over that branch and the work is gone.

!!! warning "Hand-written project copy is on borrowed time"
    Everything you wrote in step 3 is rewritten from Drive by the next sync. If the Drive
    folder does not yet say what your page says, the proposal that follows will look like a
    routine sync while quietly deleting it. That is the correct behaviour — it is why the
    Drive path is the primary one — but it means the manual path buys you days, not a
    permanent edit.

---

## Common pitfalls

- **Writing a description no Drive doc supports.** The next sync will not remove it — it
  only adds and corrects against Drive — so the invented sentence persists indefinitely,
  and the next person cannot trace it to anything. Review does not catch it either: it is
  already on `main`, so it never appears in a proposal's diff. If the folder is empty, ship
  the bare form and add the description when the doc exists.
- **Forgetting the footer date.** Nothing enforces it. The content changes, the `.synced`
  span keeps its old date, and the site starts under-reporting its own freshness.
- **Publishing an `[LR]` folder.** `[LR]` folders are learning resources — reference
  material the club collected, not projects it is building. Publishing one puts a tool on
  the site that nobody has committed to build. The sync will not do this on its own: `[LR]`
  folders are never even mirrored.
- **Adding the entry without creating the Drive folder.** Drive is authoritative; an entry
  with no folder behind it has no owner, no status source, and nothing to keep it current.
- **Adding the page without adding it to every nav.** The nav is duplicated in each file, so a
  new page is otherwise reachable only from the project list.
- **Naming yourself the lead by owning the folder.** The `Lead:` line comes from a sentence in
  a document. Write it in the machine's `[MASTER]` doc.
- **Inventing a status string.** Statuses in use are `In build`, `Design and bill of
  materials`, `Architecture design`, `In design`, and `Planned`. Reuse one rather than
  coining a synonym.
