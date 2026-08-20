# Guide: Add a Project

How a new fabrication tool gets an entry in the **Current Projects** list on `index.html`.
The primary path is not editing HTML — **create the tool's folder in Google Drive and let
the next sync propose the entry.** The manual path further down exists only for when the
entry has to be live before the next scheduled run — the job fires Monday and Thursday, so
that wait is at most four days plus however long the pull request takes to merge.

---

## The Drive path — do this one

The Drive → HTML contract is one subfolder per tool, one `<li>` per subfolder: every
subfolder of `Build the Fab` becomes exactly one entry in `<ul class="project-list">`.
Creating the folder is therefore the entire change. See
[Drive → HTML data contracts](../data-contracts.md) for the full mapping.

### Step 1 — Create the folder in Drive

In the **Ultra Hardcore Chip Codesign** Drive (root id
`1qQZ3JM8xMfNSt4A_lxrTC6NTEt2bjITP`), create a subfolder under `Build the Fab` named as
the tool should read on the site. `Build the Fab/Maskless Lithography Stepper` is the live
example — it surfaces as the entry **Maskless Lithography Stepper**.

Do not tag the folder `[LR]`. `[LR]` marks learning resources, which are never published;
a tool folder carrying that tag is skipped and no entry appears.

### Step 2 — Put the sourcing material in it, or leave it empty

The folder's contents decide how much of the entry the sync can write:

| What is in the folder | What the sync proposes |
| --- | --- |
| Nothing, or only a diagram link | Name plus a bare status — `Planned` — and no `<p>` |
| A `[Master]` outline or scope/status doc | Name, status, and a few sentences traced to that doc |
| Budgets, BOM costs, vendor pricing, `[MASTER]` to-do lists | Nothing — those never leave Drive |

An empty folder is a legitimate, finished state. The `Etcher` entry is the live example:
its Drive folder is empty, so it carries `Planned` and nothing else. **Never fill the gap
with plausible prose.** A description with no Drive doc behind it cannot be checked by the
next person, the sync will not delete it, and the site then carries a claim the club has
no record of ever making — which is exactly the failure the never-invent rule exists to
prevent.

### Step 3 — Let the sync run, or trigger it now

The scheduled job (`com.mnfc.website-sync`, launchd, Monday and Thursday at 08:13) picks the
folder up on its own. To get the proposal sooner, run the sync from the repo:

```bash
./scripts/sync-from-drive.sh
```

The script redirects all output to `~/Library/Logs/mnfc-website-sync.log` and prints
nothing to the terminal, so read the log for the result. Equivalently, ask Claude Code
from inside the repo:

```
Sync the club website from Google Drive following SYNC.md.
```

### Step 4 — Merge the proposal

Either way the sync writes the `<li>`, updates the footer date, commits to `sync/drive`, and
opens a pull request. **It does not publish.** The entry appears on the site when someone
merges that pull request, and GitHub Pages redeploys about a minute later:

```bash
gh pr diff sync/drive       # confirm the entry matches the Drive folder
gh pr merge sync/drive
```

Check the new `<li>` against the folder that produced it: an empty folder must yield the bare
form, and any description must trace to a doc in that folder. The full checklist is in
[Reviewing a Proposed Update](../operations/reviewing-changes.md); full run and failure
handling is in [Running a sync](../operations/sync-run.md).

!!! warning "An unmerged proposal is the new way for a new project to not appear"
    The run reports success on every channel the moment the pull request is open, and nothing
    reminds anyone afterwards. If the tool is still missing from the site days later, look for
    an open PR before assuming the Drive folder was wrong — and note that a proposal left
    unmerged is force-pushed over, or closed as superseded, by a later run.

---

## The manual path — when the entry must exist now

Use this only when the site has to show the tool before a sync can run. **Create the Drive
folder first anyway.** A hand-written entry with no matching folder is content the sync
cannot corroborate — and since the sync writes one entry per Drive subfolder, the entry is
orphaned from the contract that is supposed to keep it true.

### Step 1 — Open `index.html` and find the list

The entries live in `<ul class="project-list">` inside the **Current Projects**
`<section>`. Fab tools come from `Build the Fab`; the trailing `Compute Kernel` entry
comes from `Design the Compute Kernel/` instead, so insert new tools **above** it.

### Step 2 — Paste the entry

Full form — name, status, and a description that a Drive doc supports:

```html
<li>
  <span class="name">Tool Name</span>
  <span class="status">Architecture design</span>
  <p>
    One to three sentences, every clause traceable to a doc in that tool's
    Build the Fab folder.
  </p>
</li>
```

Bare form — name and status only. This is what an empty Drive folder gets, and it is what
`Etcher` looks like on the live site today:

```html
<li>
  <span class="name">Etcher</span>
  <span class="status">Planned</span>
</li>
```

If the tool later earns its own detail page, wrap the name the way the stepper does:
`<span class="name"><a href="stepper.html">Maskless Lithography Stepper</a></span>`.

Two formatting details that match the rest of the file: write em dashes as the `&mdash;`
entity rather than a literal character, and add no new classes — `.name`, `.status` and
`.project-list p` are already styled in `style.css`, and inventing a class breaks the
no-new-CSS rule in [design principles](../architecture/design-principles.md).

### Step 3 — Update the footer date

In the `<footer>` of `index.html`, set today's date in the `.synced` span:

```html
<span class="synced">Project information synced from the club Google Drive &middot; last updated 2026-08-19</span>
```

That date is the site's only signal of freshness. Leave it stale and a reader has no way
to tell a current page from one that stopped tracking Drive months ago.

### Step 4 — Preview, then get it onto `main`

```bash
python3 -m http.server 8000
```

Open `http://localhost:8000/index.html` and confirm the new `<li>` renders with the same
maroon left border and inline italic status as its neighbours. Then get the edit onto `main`
— commit it and push, or open your own pull request — and **do not leave it sitting in the
working tree**. Do not commit it to `sync/drive`: the next run resets that branch with
`git checkout -B` and the work is gone.

!!! warning "An uncommitted edit silently stops every future sync"
    `scripts/sync-from-drive.sh` runs a dirty-tree guard before anything else: if
    `git diff --quiet` or `git diff --cached --quiet` fails it logs
    `SKIP: uncommitted local changes present; not syncing over them.` and **exits 0**.
    The soft exit is deliberate — the job must never clobber work in progress — but it
    means a forgotten uncommitted edit stalls the sync indefinitely — every Monday and
    Thursday run hits the same guard — while every run still reports success.

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
  the site that nobody has committed to build.
- **Adding the entry without creating the Drive folder.** Drive is authoritative; an entry
  with no folder behind it has no owner, no status source, and nothing to keep it current.
- **Inventing a status string.** Statuses in use are `In build`, `Design and bill of
  materials`, `Architecture design`, `In design`, and `Planned`. Reuse one rather than
  coining a synonym.
