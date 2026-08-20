# Why the Sync Runs Locally

The twice-weekly Drive → site sync runs as a `launchd` job on one Mac, not as a scheduled
Claude Code cloud routine. This page records why, because the cloud routine was the first design and
the reason it was abandoned is not visible from the code that replaced it.

**The cloud routine still exists and is disabled. Do not re-enable it without fixing the
permission problem described below** — it will appear to work and will silently propose
nothing.

The sync has since stopped publishing directly and now opens a pull request instead. That
does not change anything on this page: pushing a branch and opening a pull request are both
writes to the repository, and they hit the same `403` a push to `main` did.

---

## The first design, and exactly how it fails

The original arrangement was a scheduled Claude Code cloud routine: it wakes on a schedule,
reads the club Drive through the Google Drive connector, compares Drive against the HTML,
edits the HTML, commits, and pushes to `main`.

Every step of that works except the last one.

**Cloud routines get a read-only GitHub token on this repository.** The agent authenticates,
the read paths all succeed — `git clone`, `git pull`, reading files, computing the diff — so
the run looks healthy right up to the write. Then:

- `git push` returns **`403`**.
- The GitHub API returns **`403`** for the same reason, so the obvious fallback of committing
  through the REST API instead of over git fails identically.

Both paths are blocked by the same token scope, which is why there is no workaround at the
routine's level. Granting the token write access requires a **Claude Team or Enterprise
plan**. That is the whole blocker: not a bug, not a misconfiguration in the repo, and not
something a different prompt or a retry can route around.

!!! warning "The failure is silent from the outside"

    This is what makes the disabled routine dangerous to re-enable casually. The agent reads
    Drive correctly and works out the *right* change — the reasoning half of the job is
    fine. Only publication fails. From the outside the routine runs on schedule, reports
    activity, and the site simply never changes. A site that is never updated by a job that
    reports success looks exactly like a site with no Drive changes to apply, which is the
    normal, healthy outcome of most runs.

    If the routine is ever re-enabled, verify a real push lands before trusting it.

---

## What runs instead

A `launchd` agent on Leonard's Mac, label `com.mnfc.website-sync`, running
`scripts/sync-from-drive.sh` twice a week — Monday and Thursday, 8:13am. The script calls
Claude Code headlessly with the Drive connector and a git-scoped tool allowlist, pushes the
agent's commit to the `sync/drive` branch, opens a pull request against `main` with `gh`, and
reports the outcome to a Discord webhook. A human merges to publish.

**Locally, git already has push access over SSH.** The credentials are the ones the repo's
owner already uses by hand, so the write half of the loop needs no new grant, no plan
upgrade, and no cost. The reasoning half is unchanged — it is the same headless Claude Code
run reading the same Drive with the same rules.

| | Cloud routine | Local `launchd` job |
| --- | --- | --- |
| Reads Drive | Yes | Yes |
| Computes the right change | Yes | Yes |
| Can push a branch or open a PR | **No — `403` on `git push` and the GitHub API** | Yes, over SSH plus an authenticated `gh` |
| Cost to fix / run | Claude Team or Enterprise plan | None |
| Requires a machine to be awake | No | **Yes** |
| Current state | Exists, **disabled** | Active |

Operational detail — the plist, the subcommands, the log — is in
[the schedule](../operations/schedule.md); the reporting channels are in
[Notifications](../operations/notifications.md).

---

## The tradeoff

**The Mac has to be on.** That is the entire cost of the local design, and it is accepted
deliberately.

- If the machine is asleep at 8:13am on a scheduled day, `launchd` runs the job when it next
  wakes.
- If the machine is off through the whole slot, that run is skipped. This is harmless: the
  sync is a full reconciliation of Drive against the HTML, not an incremental replay, so the
  next run picks up everything that accumulated. Nothing is lost, only delayed — and with
  slots on Monday and Thursday the next one is at most four days away.
- The sync can always be run by hand — `./scripts/sync-from-drive.sh` — without waiting for
  the next slot.

The comparison is worth stating plainly: the failure mode of the local design is *the site
updates late*. The failure mode of the cloud design is *the site never updates and nothing
says so*. A delay that any human can notice and fix in one command is a better failure than a
silent no-op on a schedule.

!!! note "The propose-then-approve design accepts a second, deliberate delay"
    A run now ends at a pull request, so the site also waits on a human reading a diff. That
    delay is the point — it is what buys the review of the roster, the internal material and
    the preserved links before anything is public — and it is bounded by whoever is watching
    the Discord channel rather than by the schedule. It is not the same failure as the cloud
    routine's: here the change exists, is visible, and is one click from live. See
    [Reviewing a Proposed Update](../operations/reviewing-changes.md).

!!! warning "One machine is a single point of failure, and it is undocumented"

    `scripts/sync-from-drive.sh` hardcodes absolute paths, including the repo location and
    `CLAUDE=/Users/leonardjin/.local/bin/claude`. The sync therefore runs from exactly one
    laptop. Nothing in the repository currently documents what to do if that machine is
    replaced or the owner graduates. This is a known gap, not a solved problem.

---

## The commit history as evidence

The pivot is legible in `git log`, in order:

```
e1cf67f  Note that the weekly sync cannot publish yet (read-only GitHub token)
854470e  Add local weekly sync script and launchd installer
0593a4a  TEMP: remove Etcher to test local sync write-back
7dd018c  Add Etcher project entry from Drive Build the Fab folder
99e3012  Document local launchd sync and fix two SIGPIPE false negatives
f043e01  TEMP: drop Etcher entry to verify launchd write-back path
63344a8  Restore Etcher project entry from Drive Build the Fab folder
29d4d81  Propose site updates as a pull request instead of publishing them
```

Read as a narrative:

- **`e1cf67f`** is the moment the cloud design was written off — the repo's own docs recording
  that the scheduled sync could read but not publish.
- **`854470e`** is the replacement: the local script plus the `launchd` installer.
- **`0593a4a` → `7dd018c`** is the first proof, on **2026-08-18**. The Etcher entry was deleted
  from `index.html` by hand and the sync was run from a terminal; it read Drive, noticed the
  site was missing a project that the `Build the Fab` folder contained, and restored the entry
  on its own. That pair of commits *is* the write-back path being demonstrated end to end,
  including the push.
- **`99e3012`** hardened the script — it fixed two SIGPIPE false negatives in the
  push-verification logic and corrected the `README.md`, which until then still claimed the
  sync could not publish. This is also the commit after which the Drive document
  `Club Website — How It Works` became wrong, since it still says the sync runs in the cloud
  and that "Nothing runs on anyone's laptop."
- **`f043e01` → `63344a8`** repeats the Etcher test on **2026-08-19**, this time triggered
  through `launchd` itself rather than from a shell — confirming the connector authenticates
  under `launchd`'s minimal environment and that SSH push works without a shell-provided
  `ssh-agent`.
- **`29d4d81`** is a change of a different kind: the write access proved by all of the above
  is still used, but no longer to publish. The run commits to `sync/drive`, force-pushes it
  and opens a pull request, and a human merge is what reaches `main`. The local-vs-cloud
  argument is untouched — a read-only token cannot open a pull request either.

!!! note "Why the Etcher entry is the test fixture"

    It is the only project entry with no description — its Drive folder is empty, so under
    rule 1 the site shows a bare name and status. That makes it the smallest possible piece
    of Drive-derived content: deleting it is an unambiguous, easily-reverted break that the
    sync must notice and repair, and restoring it exercises the full read → diff → edit →
    commit → push chain without risking real copy. It is still the fixture under the
    pull-request flow — the chain now ends at `gh pr create` and a merge instead of at a push
    to `main`.

---

## If you are considering re-enabling the cloud routine

The order of operations is fixed:

1. Obtain write access for the routine's GitHub token — which currently means a Claude Team
   or Enterprise plan.
2. Prove a push lands, on a throwaway commit, before trusting the routine with real content.
   Under the current design, prove `gh pr create` works too — the token needs to open pull
   requests, not just push a branch.
3. Only then disable the local `launchd` job, so the two never run concurrently — there is no
   lock file, nothing in the script guards against overlapping runs, and both would reset and
   force-push the same `sync/drive` branch.

Skipping step 1 produces a routine that reads Drive, reasons correctly, and proposes
nothing, on a schedule, indefinitely. That is the state that `e1cf67f` recorded and that the
local design exists to escape.
