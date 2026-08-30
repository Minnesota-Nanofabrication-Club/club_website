# Anatomy of a Sync Run

What `.github/workflows/sync-from-drive.yml` does, step by step, from the cron firing to the
Discord post. This page covers a single execution of the workflow — how it is set up and how
to read a failure is in [The Cloud Sync](cloud-sync.md), how the run reports itself is in
[Notifications](notifications.md), what a reviewer does with the result is in
[Reviewing a Proposed Update](reviewing-changes.md), and symptom-first diagnosis is in
[Troubleshooting](troubleshooting.md). **The run does not publish. It proposes: the agent
commits, the workflow force-pushes `sync/drive` and opens a pull request, and merging that
pull request is what puts anything on the live site.**

---

## Contents

- [What triggers a run](#what-triggers-a-run)
- [Step 1 — check out the repo](#step-1-check-out-the-repo)
- [Step 2 — check the run is configured](#step-2-check-the-run-is-configured)
- [Step 3 — sanity-check the repo](#step-3-sanity-check-the-repo)
- [Step 4 — mirror Drive with the service account](#step-4-mirror-drive)
- [Step 5 — record the tree before the agent runs](#step-5-record-the-tree)
- [Step 6 — the agent](#step-6-the-agent)
- [Step 7 — the guard](#step-7-the-guard)
- [Step 8 — open a review pull request](#step-8-open-a-review-pull-request)
- [Step 9 — report](#step-9-report)
- [Nothing closes a stale proposal](#nothing-closes-a-stale-proposal)
- [Log and marker reference](#log-marker-reference)
- [What the workflow does not handle](#what-the-workflow-does-not-handle)

---

## What triggers a run

```yaml
on:
  schedule:
    - cron: "13 13 * * 1,4"
  workflow_dispatch:
    inputs:
      dry_run:
        description: "Run the agent and show the diff, but commit nothing"
        type: boolean
        default: false
```

Two triggers, one job. `13 13 * * 1,4` is Monday and Thursday at 13:13 UTC — 08:13
America/Chicago through CDT, 07:13 through CST, because GitHub cron is always UTC and does
not shift for US daylight saving. GitHub also defers scheduled runs under peak load, so the
time is "morning-ish", never a guaranteed minute. The full timing table is in
[The Cloud Sync](cloud-sync.md#the-schedule).

The job runs on `ubuntu-latest` with `timeout-minutes: 45`, and every run is a fresh
container: **the agent has no memory of any previous run.** What carries between runs is what
is written down — `CLAUDE.md` and `SYNC.md` for the rules, `DRIVE_NOTES.md` for what the last
run learned about Drive. See [the three-tier memory model](#the-agent-maintains-its-own-notes).

```yaml
concurrency:
  group: sync-from-drive
  cancel-in-progress: false
```

**A hand-triggered run and a scheduled one cannot write at the same time.**
`cancel-in-progress` is `false` deliberately: a half-finished run that has already
force-pushed `sync/drive` is worse than a queued one, so the second run waits rather than
killing the first mid-push.

The job's `permissions` block is the minimum that works — `contents: write` to push the
proposal branch, `pull-requests: write` to open the PR a human merges, `issues: write` for the
failure-tracking issue, `id-token: write` for the Claude action's auth.

!!! note "The `secrets` context is hoisted into job-level `env:`"
    `secrets` is not available in a job- or step-level `if:`, but it is available in job-level
    `env:`. Every secret is therefore declared once at the top of the job and the steps branch
    on the environment variable instead. Without that, "skip this step when the webhook secret
    is missing" cannot be expressed at all.

---

## Step 1 — check out the repo

```yaml
- uses: actions/checkout@v5
  with:
    fetch-depth: 0
```

Full history, not a shallow clone. The guard in [step 7](#step-7-the-guard) diffs the tree
against a pre-agent SHA and the publish step force-pushes with `--force-with-lease`; both need
real history behind `HEAD`.

The runner checks out `main`. **Nothing in the run ever pushes to `main`** — the agent commits
on the runner's local `main`, and [step 8](#step-8-open-a-review-pull-request) pushes that
commit to `refs/heads/sync/drive` instead. The local checkout is destroyed with the container.

---

## Step 2 — check the run is configured

The step looks for Claude credentials (`CLAUDE_CODE_OAUTH_TOKEN`, or `ANTHROPIC_API_KEY` as
the fallback) and for `GDRIVE_SERVICE_ACCOUNT_JSON`. If either is missing it writes a setup
summary, logs a `::notice::`, sets `configured=false`, and **exits green**. Every later step
carries `if: steps.config.outputs.configured == 'true'`, so the whole job becomes a no-op.

**What breaks otherwise.** Between this workflow landing on `main` and someone running
`claude setup-token`, every cron would be a red X — and a red X that is always there is one
nobody reads. Failing loudly on an unconfigured repo trains people to ignore the exact signal
that has to stay meaningful.

**Both credentials are checked here, before any token is spent,** because a run with Claude
but no Drive is the dangerous shape: the agent would have write access to the proposal branch
and no source to check the site against.

!!! note "`if`, not `[ … ] && …`"
    The runner's default shell is `bash -e`, and an `&&` list whose test is false is itself a
    failing command. Written the concise way, the check would abort the step precisely when
    both secrets are present. The same pattern appears in the job summary step, where the
    short form would fail the step on exactly the runs that changed nothing.

---

## Step 3 — sanity-check the repo

```bash
for f in CLAUDE.md SYNC.md index.html style.css scripts/fetch_drive.py; do …done
python3 -m py_compile scripts/fetch_drive.py
rm -rf scripts/__pycache__
```

Five files must exist and `fetch_drive.py` must compile, before a single token is spent. A
missing `CLAUDE.md` or `SYNC.md` means the agent would run without the rules it is supposed to
follow, which is worse than not running.

The `rm -rf scripts/__pycache__` is not tidiness. `py_compile` leaves bytecode behind, and an
agent reaching for `git add -A` would commit it into the published site's repository — which
is exactly what happened before commit `0822ea6`.

---

## Step 4 — mirror Drive with the service account { #step-4-mirror-drive }

```bash
DRIVE_DIR="${RUNNER_TEMP}/drive"
python3 scripts/fetch_drive.py --out "$DRIVE_DIR"
```

`scripts/fetch_drive.py` walks the club Drive as a Google service account, exports every Doc,
Sheet and Slides file to text, and writes the tree plus a `manifest.json` mapping each local
file back to its Drive id, title and modified time. The agent then reads plain files and needs
no Drive credential of its own. Why a service account rather than the claude.ai Drive
connector is settled in
[The Google Drive problem](cloud-sync.md#the-google-drive-problem).

**The mirror goes to `$RUNNER_TEMP`, never into the working tree,** and `fetch_drive.py`
refuses an `--out` path underneath the repository root. The Drive tree holds budgets, BOM
costs, vendor pricing and outreach notes — the material publishing rule 3 keeps off the site
— and inside the repo that is one `git add -A` away from being in the published history
forever. Git history is not something you can quietly un-publish.

The script also skips folders it must never read for content:

| Skipped folder | Why |
| --- | --- |
| `[LR] *` | Learning resources. Reference material, never published |
| `[C] Finances` | The club budget |
| `[C] Funding` | Grant proposals and expense tables |
| `[C] Logistics` | Lab space, advisor outreach, named staff contacts |

Not fetching them keeps them out of the agent's context entirely, rather than relying on the
agent to remember not to use what it has already read.

**This step runs before the agent so a Drive problem costs nothing.** A bad key, an unshared
folder or a revoked account fails here, loudly, with no tokens spent and no half-written site.
A mirror that fetched zero files also fails the run: an empty mirror and a healthy one are
indistinguishable downstream, and the agent would read an empty directory, conclude Drive says
nothing, and propose stripping the site.

---

## Step 5 — record the tree before the agent runs { #step-5-record-the-tree }

```bash
echo "sha=$(git rev-parse HEAD)" >> "$GITHUB_OUTPUT"
```

One line, and the whole run's notion of "what is published now". The guard diffs against it,
the guard compares `HEAD` against it to decide whether anything changed, and the publish step
pushes whatever it points at. Asking git rather than asking the agent whether it committed
means the workflow's record of what happened comes from the repository, not from a summary: a
run that claims it changed nothing but left a commit is still reported as a proposal.

---

## Step 6 — the agent { #step-6-the-agent }

```yaml
- uses: anthropics/claude-code-action@v1
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    anthropic_api_key: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN != '' && '' || secrets.ANTHROPIC_API_KEY }}
    prompt: |
      …
    claude_args: |
      --model claude-opus-5
      --allowedTools "Read,Write,Edit,Glob,Grep,Bash(git:*)"
      --max-turns 200
```

`@v1` replaced the old per-tool inputs (`allowed_tools`, `direct_prompt`, `mode`, `max_turns`,
`model`) with `prompt` plus `claude_args`, which passes Claude Code CLI flags straight through.
`@beta` is deprecated.

**Both auth inputs are passed, and never both populated.** When the OAuth token exists the API
key input is forced empty by the expression above, so precedence is a property of this
workflow file rather than of the action's internal resolution order. If that order ever
changed upstream, a run expected to bill against the Max plan could silently start billing per
token instead.

### The allowlist

| Tool | Why it is on the list |
| --- | --- |
| `Read`, `Glob`, `Grep` | Read the repo and the Drive mirror |
| `Edit`, `Write` | Rewrite `index.html` and the machine subpages |
| `Bash(git:*)` | `git add` and `git commit` — nothing else |

**Everything absent from the list is the point.** There is no Drive tool, because there is
none to grant — the agent reads the mirror as files. `Bash(git:*)` is a prefix match on `git`,
so the agent gets version control and not a shell: no `curl`, no `rm -rf`, no `ssh`, no
package installs, nothing that reaches the network on its own. `gh` is absent, so the agent
cannot open, comment on or merge a pull request even though the workflow around it does.

!!! warning "Adding a tool here widens the unattended blast radius"
    Treat `--allowedTools` as a security boundary, not a convenience list. A tool added to make
    one debugging session easier stays granted for every unattended run afterwards. If a run
    genuinely needs a new capability, add it, and record why in `CLAUDE.md`.

### What the prompt tells it

The prompt is the whole specification of the job and restates the rules rather than assuming
them:

- Read `CLAUDE.md` **first**, then `SYNC.md`, then `index.html`, `stepper.html`, `style.css`
  and the existing machine subpages.
- Read the mirror at `$RUNNER_TEMP/drive`, starting from its `manifest.json`. Never copy any
  part of it into the repo, never `git add` from it, never write one of its paths into
  published HTML.
- Enumerate the subfolders of `Build the Fab`. Each is a machine and each gets its own
  subpage carrying the machine's name, who is responsible for it, current progress, and a
  short scope paragraph — **only where a doc supports each of those**.
- Never invent content; a machine with no design documentation gets a bare status line.
- **Never infer a person from metadata.** A lead must be named in the *text* of a document.
  File ownership, folder creation and document properties name nobody.
- Never publish budgets, funding, vendor pricing, BOM costs, outreach notes or `[MASTER]`
  to-do lists.
- Publish officers and the faculty advisor by name, plus the one person responsible for each
  machine on that machine's page. Never the general-member roster.
- On roles, `Engineering Structure` is ground truth and the Constitution is **not**.
- Do not touch `docs/`, `.github/`, `scripts/`, `mkdocs.yml`, `README.md`, `CLAUDE.md` or
  `SYNC.md`.
- Ignore the Drive doc `Club Website — How It Works`; flag drift rather than editing it.
- Preserve the design and the four non-Drive items.
- Update the footer date only if content changed.
- Commit with a subject naming what changed; if nothing meaningful changed, make **no** commit
  and say so. **Do not push and do not switch branches** — the workflow does both.

!!! warning "The agent is told to commit and stop there"
    The prompt does not merely omit the push — it forbids pushing and switching branches
    explicitly. The workflow owns both: it force-pushes to `sync/drive` and it never merges at
    all. An agent that pushed on its own would race the workflow's own push; an agent that
    switched branches would leave the guard diffing the wrong tree.

!!! note "The prompt duplicates the repo's own rules on purpose"
    Every publishing constraint above is already in `CLAUDE.md` and `SYNC.md`, which the
    prompt also tells the agent to read. The duplication is cheap insurance: the rules with
    real consequences — no invented content, no member names, no budgets, no inferred leads —
    must survive a run where a file read fails or the agent gets distracted mid-task. The
    metadata-inference ban was moved into the prompt for exactly that reason in commit
    `0eb44dd`, after a run on 2026-08-30 published three machine leads inferred from file
    ownership.

### The agent maintains its own notes

The agent has no memory between runs, so the repository carries three tiers of it:

| Tier | File | Who edits | Lifetime |
| --- | --- | --- | --- |
| Standing decisions, the *why* | `CLAUDE.md` | humans only | permanent |
| The procedure and publishing rules, the *how* | `SYNC.md` | humans only | permanent |
| Observations about the current state of Drive | `DRIVE_NOTES.md` | **the sync agent** | until they stop being true |

The prompt tells the agent to read `DRIVE_NOTES.md` early and to update it before finishing:
check every entry's `REMOVE WHEN` condition and delete the entry if it is met, add an entry
only for something that cost real reasoning, give every entry a `REMOVE WHEN`, and keep the
file at or under **20 entries**.

**What breaks otherwise.** "The etcher's timeline doc is actually the stepper's, pasted in" is
an observation that stops being true the moment somebody fixes the doc, and a note that has
outlived its cause is worse than no note — it is a confident instruction based on something
that is no longer the case. Requiring a removal condition is what keeps the file from
silently becoming a second, unreviewed rules file. An entry whose author cannot write a
removal condition *is* a rule, and the prompt says to raise it in the summary instead.

`DRIVE_NOTES.md` is deliberately the one tracked file the guard lets the agent write. The
split is the point: **the agent owns its observations, humans own the rules, and a confused
run can degrade its own notes but cannot rewrite its instructions.**

---

## Step 7 — the guard { #step-7-the-guard }

```bash
PROTECTED="$(git diff --name-only "$BEFORE" -- \
  docs/ .github/ scripts/ mkdocs.yml README.md CLAUDE.md SYNC.md || true)"
if [ -n "$PROTECTED" ]; then
  echo "::error::the agent modified files it must never touch:"
  exit 1
fi
```

**A prompt rule saying "leave `docs/` alone" is a request; this is the check.** Any change
under those paths fails the run *before* anything is pushed. Without it, one confused run
could rewrite the documentation of the sync from inside the sync — the exact drift `CLAUDE.md`
warns about — or edit the workflow that is running it.

`DRIVE_NOTES.md` is deliberately not in that list, for the reason given above.

The guard then does two more things:

**Uncommitted leftovers are discarded, not committed.**

```bash
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "::warning::the agent left uncommitted changes; discarding them."
  git reset -q --hard
fi
```

Those edits sit on a tree nobody reviewed, and they would otherwise ride along in the push.
Committing them because they happened to be there is how unreviewed content reaches a
proposal that looks like every other one. Nothing is lost that matters: the next run re-derives
the same edits from Drive.

**It decides whether anything changed at all**, by comparing `HEAD` against the pre-agent SHA:

| Condition | Output | Log line |
| --- | --- | --- |
| `AFTER = BEFORE` | `changed=false` | `No commit made — the site already matches Drive.` |
| otherwise | `changed=true`, plus `subject` and `files` | a `::group::` containing `git show --stat` |

`subject` is `git log -1 --format=%s` — one line, written by the agent that knew what it
changed. It becomes the pull request title *and* the Discord headline, so the two say the same
thing by construction. Parsing a headline out of the agent's free prose instead would depend
on a format the agent never promised to keep.

---

## Step 8 — open a review pull request

Runs only when `configured == 'true'` **and** `changed == 'true'`.

On a dry run it prints `git show "$AFTER"`, logs `::notice::dry run - the commit below exists
only on this runner.`, and exits. The runner is destroyed with the commit on it.

Otherwise:

```bash
git remote set-url origin \
  "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

git push --force-with-lease origin "HEAD:refs/heads/sync/drive"
```

**The remote is set explicitly rather than inherited.** `claude-code-action` rewrites the
`origin` remote for its own use, and what it leaves behind does not authenticate for a push
from this step. A side effect of the token-bearing URL is that `gh` can no longer infer the
repository from the remote, which is why every `gh` call in the workflow names `--repo`
explicitly.

**One reusable branch, force-pushed from current `main` every run.** The pull request always
shows *what Drive says now* against *what is published now*, rather than a pile of superseded
proposals. `--force-with-lease` rather than `--force`: if something else has moved
`origin/sync/drive` — a concurrent run, a human pushing a correction onto the proposal — the
push is refused rather than silently discarding that work. On a branch whose whole purpose is
to be reviewed, plain `--force` would mean destroying the reviewer's own commits.

Then exactly one of two things happens:

| `gh pr list --head sync/drive --state open` | Action | Log line |
| --- | --- | --- |
| empty | `gh pr create --base main --head sync/drive` with the commit subject as the title | `Opened: <url>` |
| a URL | `gh pr comment` noting that a later run refreshed it | `Updated the open proposal: <url>` |

A pull request tracks its head branch, so the force-push already updated the open PR's diff;
there is nothing to create and nothing to reopen. The comment exists so that a reviewer who
read the old diff is told, in the thread, that it has been replaced.

The PR body is written by the workflow, not the agent: it names the changed files, states that
**merging publishes to the live site**, notes that closing discards the proposal and that the
next scheduled run re-proposes it if Drive still disagrees, and explains that the branch is
reset from `main` every run.

!!! danger "Nothing has been published at this point"
    The run ends with the site exactly as it was. `Opened: …` and a
    `📋 Update proposed — review` ping describe work that is **waiting**, and it waits
    indefinitely — nothing merges the pull request on a timer, and the next run will simply
    force-push over it with a newer proposal. A proposal nobody opens is a site that never
    changes, and every channel this run wrote to reports success. Reviewing is the step that
    publishes: see [Reviewing a Proposed Update](reviewing-changes.md).

!!! warning "Do not do your own work on `sync/drive`"
    Any commit you make on that branch is destroyed by the next run's force-push, without
    warning. If you want to amend a proposal, branch off it under a different name, or push
    the fix to `main` through your own pull request. The branch belongs to the workflow.

---

## Step 9 — report { #step-9-report }

Three reporting steps, none of which can fail the run's real work.

**Job summary** (`if: always()`). Status, whether anything changed, whether anything was
published to `main` (always `no`), the commit subject, the changed files, and the site URL —
written to `$GITHUB_STEP_SUMMARY` so it renders at the top of the run page.

**Discord** (`if: always()`, and only when `DISCORD_WEBHOOK_URL` is set). Two steps: one
writes the webhook and the optional mention from secrets into the *runner's*
`~/.config/mnfc-sync/`, the other calls `scripts/notify-discord.sh`.

The config-file indirection is deliberate. `notify-discord.sh` is the one Discord renderer for
this project and it reads its webhook from `~/.config`; giving it one on the runner is cheaper
than growing a second, subtly-different formatter for CI. **The directory lives on the
throwaway runner and is gone when the job ends** — it is not a machine anyone owns.

| Job state | Discord call | Embed |
| --- | --- | --- |
| not `success` | `notify-discord.sh fail …` | red `✗ Sync failed`, with the run URL and no agent output |
| `changed != true` | `notify-discord.sh ok …` | grey `✓ Site checked` |
| `proposed = true` | `notify-discord.sh proposed …` | amber `📋 Update proposed — review`, with the PR link |
| otherwise (dry run) | `notify-discord.sh ok …` | grey, `Dry run — changes were computed but not published.` |

!!! warning "The `fail` embed deliberately carries no agent output"
    The tail of the agent's narration routinely quotes whatever it was last reading from
    Drive, and it reads the docs holding BOM costs, vendor pricing and sponsorship
    correspondence — the exact material rule 2 says never leaves Drive. Discord is a published
    surface: members join it and messages get screenshotted. The embed says
    `Nothing was published. Run log: <url>` and the diagnostic detail stays in the Actions log.

**The failure issue** (`if: failure()`). One tracking issue labelled `drive-sync-failure`,
commented on by every subsequent failing run, and **closed automatically by the next
successful run**. So one open issue means "still broken" and no open issue means "the last run
was fine".

**What breaks otherwise.** A silent cron failure is how the sibling repo went stale for weeks
without anyone noticing. A workflow that merely turns the checks tab red relies on somebody
opening the checks tab.

---

## Nothing closes a stale proposal { #nothing-closes-a-stale-proposal }

**A run that finds no differences leaves any open pull request exactly where it is.** The
publish step is gated on `changed == 'true'`, so a quiet run touches neither the branch nor
the PR; it posts a grey `✓ Site checked` and ends.

That is worth stating plainly because the earlier local script did the opposite — it closed a
stale proposal with a `Superseded:` comment — and several habits were built on that behaviour.

| What you might expect | What actually happens |
| --- | --- |
| A quiet run closes a proposal the site has caught up with | Nothing. The PR stays open and mergeable |
| An unreviewed proposal expires on its own | It does not. It waits until a later run force-pushes over it, or a human acts |

**What this costs.** A proposal whose change has since been made another way — merged from an
earlier run, or edited onto `main` by hand — stays open, green and mergeable, and merging it
republishes content that is already there or that the agent has since judged unnecessary.
Nothing in the GitHub UI distinguishes that from a fresh proposal. Check the PR's age and its
current diff before merging, and close it yourself if it no longer describes a change you
want.

---

## Log and marker reference { #log-marker-reference }

Everything the run writes is in the Actions log for that run, under
**Actions → Sync from Drive → the run**. There is no log file on anyone's machine.

| Marker | Written by | Meaning | What to do |
| --- | --- | --- | --- |
| `::notice::Missing secrets (…), so no sync ran.` | step 2 | The repo has no Claude and/or Drive credentials. The run exits **green** | Set the secrets — [The Cloud Sync](cloud-sync.md#the-secrets) |
| `::notice::CLAUDE_CODE_OAUTH_TOKEN is not set; falling back to ANTHROPIC_API_KEY` | step 2 | Running on per-token API billing rather than the Max plan | Mint an OAuth token if that was not intended |
| `::error::<file> is missing — the sync cannot proceed without it.` | step 3 | A required file was deleted | Restore it; nothing was spent |
| `skipping folder <path> ([LR] — reference material, not published)` | step 4 | Normal. A skipped Drive folder | Nothing |
| `::error::the agent modified files it must never touch:` | step 7 | The guard fired. **Nothing was pushed** | Read the listed paths in the log, then re-run |
| `::warning::the agent left uncommitted changes; discarding them.` | step 7 | The agent edited without committing | Nothing. Expect an agent-side fault nearby |
| `No commit made — the site already matches Drive.` | step 7 | **Success.** Drive matched the site | Nothing |
| `::notice::dry run - the commit below exists only on this runner.` | step 8 | A `dry_run` dispatch. The diff follows | Read the diff |
| `Opened: <url>` | step 8 | A new pull request was created against `main` | **Review and merge it** — nothing publishes until you do |
| `Updated the open proposal: <url>` | step 8 | A PR was already open; the force-push replaced its diff | Same — review the *current* diff, not one you read earlier |
| `Discord: posted (<status>).` | step 9 | The embed reached the webhook | Nothing |
| `Discord: not configured (no <path>); skipping notification.` | step 9 | No `DISCORD_WEBHOOK_URL` secret, so no config file was written | Nothing, unless you wanted Discord |
| `Discord: HTTP <code> -- <body>` | step 9 | The webhook rejected the post | See [Troubleshooting](troubleshooting.md#discord-http-401-404) |
| `Closing recovered failure issue #N` | step 9 | A previous failure was fixed | Nothing |

!!! note "Markers that no longer exist"
    `Sync started:`, `SKIP: uncommitted local changes present…`, `FATAL: repo not found`,
    `FATAL: git pull failed`, `RESULT: claude exited N`, `RESULT: no changes proposed.`,
    `RESULT: proposed A -> B`, `Closing stale proposal:` and `WATCHDOG: …` were written by the
    local `launchd` script, which was deleted in commit `a0a76d9`. Nothing emits them, there
    is no `~/Library/Logs/mnfc-website-sync.log` to find them in, and anything still grepping
    for them is looking for a run that cannot happen.

---

## What the workflow does not handle

Stated plainly so nobody assumes a safety net that is not there:

| Condition | Behavior |
| --- | --- |
| Nobody reviews the proposal | Nothing. No reminder, no timeout, no escalation. It waits until a later run force-pushes over it |
| A quiet run with a proposal still open | The proposal is left open and mergeable. Nothing closes it — see [above](#nothing-closes-a-stale-proposal) |
| The scheduled run never fires | Nothing notices. GitHub disables scheduled workflows in repositories with 60 days of no activity, and the symptom is silence — see [Notifications](notifications.md#what-none-of-these-channels-covers) |
| Merge conflicts on the pull request | Cannot normally arise — the branch is force-pushed from current `main` every run — but nothing checks |
| A failed push | Fails the job, which opens the failure issue. No retry. The next run re-proposes from scratch |
| A failed Discord post | `notify-discord.sh` exits non-zero, which fails that step; the proposal is already open and unaffected |
| Discord unconfigured | Not an error. The step is skipped entirely when the secret is absent |
| Drive credentials revoked | Fails at [step 4](#step-4-mirror-drive), before any tokens are spent |
| The agent hits `--max-turns 200` | Fails the agent step, which fails the job. Nothing is pushed |
| A `dry_run` on a run that changed nothing | The publish step never runs, and Discord reports a quiet run rather than a dry one |

Which Drive doc feeds which part of the page — and what is deliberately never published — is
in [Data contracts](../data-contracts.md). Every channel a run reports through is in
[Notifications](notifications.md). What to do with the pull request a run leaves behind is in
[Reviewing a Proposed Update](reviewing-changes.md). How a merge becomes a live page is in
[Deployment](deployment.md).

---

[← Architecture overview](../architecture/overview.md){ .md-button } [The Cloud Sync →](cloud-sync.md){ .md-button .md-button--primary }
