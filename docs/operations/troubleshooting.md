# Troubleshooting

Diagnosing a sync that did not do what you expected. Start with the symptom table, then read
the section it points at. For what each log marker means in isolation, see the
[log and marker reference](sync-run.md#log-marker-reference); for how a run reports itself see
[Notifications](notifications.md). **Before anything else: two states look like failures and
are not — `No commit made — the site already matches Drive.` is how most runs end, and a site
that has not changed since the last run is expected whenever nobody has merged the proposal.**

---

## Contents

- [First: read the run](#first-read-the-run)
- [Symptom table](#symptom-table)
- [The site looks stale](#the-site-looks-stale)
- [No pull request appeared](#pr-not-appearing)
- [The proposal is sitting unmerged](#proposal-unmerged)
- [A stale proposal is still open](#stale-proposal-still-open)
- [The guard fired](#guard-fired)
- [The Drive mirror failed](#drive-mirror-failed)
- [The agent step failed](#agent-step-failed)
- [No run happened at all](#no-run-happened)
- [Discord posts not arriving](#discord-posts-not-arriving)
- [Discord returns HTTP 401 or 404](#discord-http-401-404)
- [Known unhandled cases](#known-unhandled-cases)

---

## First: read the run

Almost every diagnosis starts on the Actions tab. Everything below can be done from a browser
instead; the commands are here because they are faster.

```bash
R=Minnesota-Nanofabrication-Club/club_website

gh run list --repo "$R" --workflow "Sync from Drive" --limit 5
gh run view --repo "$R" <run-id>            # the job summary and step statuses
gh run view --repo "$R" <run-id> --log      # everything
```

| Source | Command | Answers |
| --- | --- | --- |
| The run | `gh run list --workflow "Sync from Drive"` | Did a run happen, and did it pass? |
| The job summary | the top of the run page | Did it change anything, and what? |
| The failure issue | `gh issue list --label drive-sync-failure` | Is the sync *currently* broken? |
| Discord | the channel the webhook posts to | One embed per run, with the PR link on `proposed` |
| The pull request | `gh pr list --head sync/drive --state all --limit 5` | Is a proposal open, merged, or closed? |
| Git | `git fetch origin && git log --oneline -5 origin/main` | Did the merge land on `main`? |

!!! tip "`No commit made — the site already matches Drive.` is the healthy steady state"
    Publishing rule 7 says a sync that finds no Drive changes makes no commit. A history of
    green runs with `changed: false` means the site matches Drive. Nothing needs doing. Do not
    "fix" it by forcing a commit.

!!! warning "A green run is not a published change"
    The run succeeding says the *run* did its job. It does not say the site changed — nothing
    reaches the live site until a human merges the pull request. A green run whose summary
    reads `changed: true` and a site that has not moved is the expected combination. Go to
    [Reviewing a Proposed Update](reviewing-changes.md) rather than debugging the sync.

---

## Symptom table

| Symptom | Likely cause | Go to |
| --- | --- | --- |
| Site missing a Drive change from days ago | Any of the below — start with the run list | [The site looks stale](#the-site-looks-stale) |
| Discord posted `📋 Update proposed` but no PR exists | The `gh pr create` call failed after the push | [No pull request appeared](#pr-not-appearing) |
| A pull request has been open for days and the site is unchanged | Nobody merged it — merging is what publishes | [The proposal is sitting unmerged](#proposal-unmerged) |
| A PR is open whose change is already on the site | A quiet run does not close it; nothing does | [A stale proposal is still open](#stale-proposal-still-open) |
| A proposal you were reading has a different diff | A later run force-pushed over it | [The proposal is sitting unmerged](#proposal-unmerged) |
| Run failed at `Check the agent stayed inside the site` | The agent edited a protected path | [The guard fired](#guard-fired) |
| Run failed at `Mirror Drive with the service account` | Drive credential, sharing, or API enablement | [The Drive mirror failed](#drive-mirror-failed) |
| Run failed at `Sync the site from Drive` | Auth, credit, or `--max-turns` | [The agent step failed](#agent-step-failed) |
| Run exited green having done nothing, with a `::notice::` about secrets | The repo has no Claude and/or Drive secret | [The secrets](cloud-sync.md#the-secrets) |
| No run on a Monday or Thursday at all | GitHub deferred it, disabled the schedule, or the workflow is gone | [No run happened at all](#no-run-happened) |
| Content the agent proposed is missing from the site | Drive may not say what you think it says | [Data contracts](../data-contracts.md) |
| The PR is merged but the page is unchanged | Pages build, browser cache, or a Pages settings change | [Deployment](deployment.md#when-a-push-does-not-appear) |
| No Discord messages at all | The webhook secret is unset, or the run never happened | [Discord posts not arriving](#discord-posts-not-arriving) |
| Log shows `Discord: HTTP 401` or `Discord: HTTP 404` | Webhook revoked, deleted, or the URL is wrong | [Discord HTTP errors](#discord-http-401-404) |
| `No commit made — the site already matches Drive.` | **Nothing.** Drive matched the site | not a failure |

---

## The site looks stale

Work outwards from the published page to the source. Each step rules out one link in the chain
described in [Anatomy of a Sync Run](sync-run.md).

**Start with the pull request.** Under the propose-then-approve flow the single most common
cause of a stale site is not a broken run — it is a correct proposal nobody merged.

```bash
R=Minnesota-Nanofabrication-Club/club_website

# 1. Is there a proposal waiting for a human?
gh pr list --repo "$R" --head sync/drive --state all --limit 5

# 2. Is the change on main at all?
git fetch origin && git log --oneline -5 origin/main

# 3. Is the sync currently broken?
gh issue list --repo "$R" --label drive-sync-failure --state open

# 4. What did the last few runs do?
gh run list --repo "$R" --workflow "Sync from Drive" --limit 5
```

| Result | Meaning | Next |
| --- | --- | --- |
| Step 1 shows an **open** PR | The sync did its job; the merge is what is missing | [The proposal is sitting unmerged](#proposal-unmerged) |
| Step 1 shows nothing, but a run logged `Opened:` | The `gh pr create` call failed | [No pull request appeared](#pr-not-appearing) |
| Step 2 shows the change on `main` | The repo is current — the problem is downstream | [Deployment](deployment.md#when-a-push-does-not-appear) |
| Step 3 shows an open issue | The sync is failing. Read the linked run | this page, by failing step |
| Step 4 shows green runs with `changed: false` | Drive and the site agree | suspect the source, below |
| Step 4 shows no runs on recent Mondays or Thursdays | The schedule is not firing | [No run happened at all](#no-run-happened) |

**If everything checks out, suspect the source before the pipeline.** The agent publishes only
what a Drive doc supports and only from the folders `SYNC.md` names. A change made in a
document the contract does not read — or in one of the folders `fetch_drive.py` deliberately
skips — will never appear on the site no matter how many times the sync runs. Confirm the
Drive location against [Data contracts](../data-contracts.md) first.

To force a run once the blockage is cleared: **Actions → Sync from Drive → Run workflow**, or

```bash
gh workflow run "Sync from Drive" --repo "$R"
gh run watch --repo "$R"
```

---

## No pull request appeared { #pr-not-appearing }

**Cause.** A run reported a proposal, but there is no pull request to review. The push and the
PR are separate operations in the same step, and the log distinguishes them.

```bash
R=Minnesota-Nanofabrication-Club/club_website
gh run view --repo "$R" <run-id> --log | grep -n 'force-with-lease\|Opened:\|Updated the open proposal'
gh pr list --repo "$R" --head sync/drive --state all --limit 5
git ls-remote origin refs/heads/sync/drive     # did the branch reach GitHub?
```

| What you find | What happened | Fix |
| --- | --- | --- |
| The step failed at `git push` | `--force-with-lease` was refused because something else moved `origin/sync/drive` | Check who pushed the branch; re-run the workflow |
| The branch exists, `Opened:` line contains something that is not a URL | The push worked; `gh pr create` failed and its stderr was captured instead of a URL | Read the message, then open the PR by hand |

The branch is already on GitHub in the second case, so the pull request can be opened
manually:

```bash
gh pr create --repo "$R" --base main --head sync/drive
```

!!! warning "`gh pr create` failures are captured, not raised"
    The step takes the last line of `gh pr create`'s combined output as the PR URL. If the
    call fails, that last line is an error message, and it is what the Discord post prints
    after "Review and merge to publish:". The step still succeeds, so **every channel reports
    a successful proposal and there is nothing to review.** The commit is safely on
    `sync/drive` either way; opening the PR by hand is the whole fix.

---

## The proposal is sitting unmerged { #proposal-unmerged }

**This is not a fault.** The sync proposes; a human merges; merging is what publishes. A pull
request open for a week means exactly that nobody merged it, and every channel will keep
reporting healthy runs while it sits there.

```bash
R=Minnesota-Nanofabrication-Club/club_website
gh pr list --repo "$R" --head sync/drive --state open
gh pr diff --repo "$R" sync/drive
```

Review it against the checks in
[Reviewing a Proposed Update](reviewing-changes.md#what-to-check-in-the-diff), then merge:

```bash
gh pr merge --repo "$R" sync/drive
```

GitHub Pages rebuilds from `main` in about a minute.

!!! warning "Waiting is not free — a later run replaces the diff without telling you twice"
    If Drive has moved again, the next run force-pushes a newer proposal onto the same branch:
    same URL, same PR number, a different diff, and a fresh `proposed` ping describing the new
    change rather than the one you were reading. Re-read before merging, and review in the days
    after the ping rather than weeks later.

If the intent is to reject the change rather than delay it, closing the PR does not stop it
coming back — the next run re-derives the same proposal from Drive and opens a new pull
request. Fix the Drive document, or change the rule; see
[Closing it instead](reviewing-changes.md#closing-it-instead).

---

## A stale proposal is still open { #stale-proposal-still-open }

**Cause.** Nothing closes proposals. The publish step only runs when the agent committed
something, so a run that finds Drive and the site in agreement leaves any open pull request
exactly where it was — open, green, and mergeable.

```bash
R=Minnesota-Nanofabrication-Club/club_website
gh pr view --repo "$R" sync/drive --json createdAt,updatedAt,title,url
gh pr diff --repo "$R" sync/drive
git fetch origin && git log --oneline -5 origin/main
```

Two versions of this are worth telling apart:

| What you see | Meaning |
| --- | --- |
| The PR's change is already on the site | Someone merged an equivalent change, or made the same edit on `main`. Merging this is a no-op at best and a revert at worst |
| The PR's change is genuinely not on the site | It is simply unmerged. Review it normally |

**Merging a stale proposal republishes content the agent has since judged unnecessary,** and
nothing in the GitHub UI distinguishes it from a fresh one: the button says "merge", the checks
pass. Close it yourself when its diff no longer describes a change you want:

```bash
gh pr close --repo "$R" sync/drive --comment "Superseded — the site already matches Drive."
```

!!! note "The old sync closed these automatically; this one does not"
    The deleted `launchd` script closed a stale proposal on any run that found no differences,
    with a `Superseded:` comment. The workflow has no such step. If a runbook or an old habit
    assumes a quiet run tidies up after itself, that assumption is now wrong, and the
    consequence is a mergeable pull request nobody is watching.

---

## The guard fired { #guard-fired }

**Cause.** The agent modified something under `docs/`, `.github/`, `scripts/`, or one of
`mkdocs.yml`, `README.md`, `CLAUDE.md`, `SYNC.md`. The run failed at
`Check the agent stayed inside the site`.

```
::error::the agent modified files it must never touch:
  docs/operations/sync-run.md
Refusing to publish. Review the run, then reset main to <sha>.
```

**Nothing was pushed.** The runner is destroyed with the offending commit on it, so there is
nothing to clean up in the repository — the message about resetting `main` is a holdover from
when the workflow committed there directly and does not apply.

**Diagnose.** Read the listed paths, then read the agent's narration above the error for why it
went there. The usual causes:

| Cause | What to do |
| --- | --- |
| The agent decided a docs page was wrong and "fixed" it | Nothing in the workflow. If the page *is* wrong, a human fixes it — that is the rule, not a bug |
| A prompt edit removed or weakened the "do not touch" clause | Restore it. See [Change a Publishing Rule](../guides/change-rules.md) |
| A new file was added at a protected path by accident | Re-run; if it repeats, the prompt needs to say so explicitly |

Then re-run the workflow. The guard is doing its job: **a prompt rule is a request and this is
the check**, and the failure mode it prevents is the documentation of the sync being rewritten
from inside the sync.

---

## The Drive mirror failed { #drive-mirror-failed }

**Cause.** `scripts/fetch_drive.py` could not read the club Drive. This step runs before the
agent deliberately, so a Drive problem costs no tokens and leaves no half-written site.

| Error | Almost always | Fix |
| --- | --- | --- |
| `404` on the root id | The folder is not shared with the service account, or only a subfolder is | Share the **root** folder — [step 6](cloud-sync.md#creating-the-service-account) |
| `403` | The Drive API is not enabled on the project | [Step 2](cloud-sync.md#creating-the-service-account) |
| `invalid_grant` | The key was deleted or disabled in the console | Mint a new key, re-set `GDRIVE_SERVICE_ACCOUNT_JSON` |
| "not valid JSON" | The secret holds part of the key file | Re-set it with `< key.json`, never by pasting |
| "nothing was fetched" | The account can see the folder id but no files in it | Sharing landed on the wrong address |

Reproduce it locally without touching the workflow:

```bash
export GDRIVE_SERVICE_ACCOUNT_JSON="$(cat ~/Downloads/mnfc-drive-key.json)"
python3 scripts/fetch_drive.py --out /tmp/drive --dry-run
```

!!! note "This replaces the old silent failure mode"
    Under the local design, Drive auth was delegated entirely to the agent, and an expired
    connector produced a run that read nothing, found no differences, reported `OK  no
    changes` — and closed the open proposal on the strength of it. Fetching the mirror in a
    separate step that fails loudly, before the agent starts, is what removed that whole class
    of failure. A Drive problem is now a red step, not a quiet green one.

---

## The agent step failed { #agent-step-failed }

**Cause.** `anthropics/claude-code-action@v1` exited non-zero. The action prints the reason in
its own step log.

| Reason | Tell | Fix |
| --- | --- | --- |
| Bad or expired credential | An auth error early in the step | `claude setup-token`, then re-set `CLAUDE_CODE_OAUTH_TOKEN` |
| Usage exhausted | A quota or credit message | Wait for the window, or set `ANTHROPIC_API_KEY` as a fallback |
| Hit `--max-turns 200` | The step ends mid-task with no commit | Read what it was doing; a Drive doc that provokes an enormous rewrite is the usual cause |
| Billing to the wrong place | `::notice::CLAUDE_CODE_OAUTH_TOKEN is not set; falling back to ANTHROPIC_API_KEY` | Set the OAuth token — see [The secrets](cloud-sync.md#the-secrets) |

**Nothing was pushed and nothing needs cleaning up.** A failed agent step fails the job, so the
publish step never runs, the failure issue opens, and any pull request from an earlier run is
left exactly as it was.

**Do not paste the agent's output anywhere public.** It routinely quotes Drive documents
holding BOM costs and vendor pricing. That is why the `fail` embed carries only a run URL.

To iterate on a fix without proposing anything, re-run with **dry run** ticked.

---

## No run happened at all { #no-run-happened }

**Cause.** The cron did not fire, or fired and produced nothing anyone saw. There is **no
watchdog** — the local one was deleted with the rest of the launchd machinery — so an absent
Discord post on a Monday or Thursday is the entire signal.

```bash
R=Minnesota-Nanofabrication-Club/club_website
gh run list --repo "$R" --workflow "Sync from Drive" --limit 10
gh workflow list --repo "$R"          # is "Sync from Drive" active or disabled_inactivity?
```

| State | Meaning | Fix |
| --- | --- | --- |
| A run exists but hours late | GitHub defers scheduled runs under peak load | Nothing. The time is "morning-ish" by design |
| The workflow shows `disabled_inactivity` | GitHub disables scheduled workflows in repositories with 60 days of no activity | `gh workflow enable "Sync from Drive" --repo "$R"` |
| No runs, workflow active, secrets unset | Runs exit green immediately with a `::notice::` | [The secrets](cloud-sync.md#the-secrets) |
| No runs and no workflow | The file was deleted or renamed on `main` | Restore `.github/workflows/sync-from-drive.yml` |

**A missed slot is harmless in itself.** The sync is not incremental: it reads Drive's current
state and proposes the HTML that matches. Nothing queues, nothing is lost, and the next run
proposes every accumulated change in one pull request. Trigger one now with **Actions → Sync
from Drive → Run workflow** if you do not want to wait.

!!! danger "This is the one failure with no automated detector"
    A run that never starts writes no log, sets no status, opens no issue and posts nothing.
    It looks exactly like a quiet week. The guaranteed Discord ping on *every* outcome —
    including runs that changed nothing — exists solely so that silence is meaningful. If quiet
    runs ever stop pinging, this failure mode becomes invisible again.

---

## Discord posts not arriving { #discord-posts-not-arriving }

**Cause.** A run happened but nothing appeared in the channel. Discord is designed to fail
quietly at the config level, so absence of posts is not by itself evidence that the sync
failed.

```bash
R=Minnesota-Nanofabrication-Club/club_website
gh secret list --repo "$R"                                   # is DISCORD_WEBHOOK_URL set?
gh run view --repo "$R" <run-id> --log | grep -n 'Discord:'
```

| What you find | Cause | Fix |
| --- | --- | --- |
| `DISCORD_WEBHOOK_URL` is not in the secret list | The two Discord steps are skipped entirely | `gh secret set DISCORD_WEBHOOK_URL` — see [Setting up Discord](notifications.md#setting-up-discord) |
| `Discord: not configured (no <path>); skipping notification.` | The secret exists but the config step did not write the file | Read the `Configure Discord` step's log |
| `Discord: send failed -- <error>` | Network failure, DNS, or a timeout past 15 seconds | Re-run; there is no automatic retry |
| Posts arrive but never ping | `DISCORD_MENTION` is unset | `gh secret set DISCORD_MENTION` |
| No `Discord:` line and no run | No run happened | [No run happened at all](#no-run-happened) |

To test the webhook itself without spending an agent run, write it to your own machine and call
the script:

```bash
mkdir -p ~/.config/mnfc-sync
printf '%s' 'https://discord.com/api/webhooks/...' > ~/.config/mnfc-sync/discord-webhook
chmod 600 ~/.config/mnfc-sync/discord-webhook
./scripts/notify-discord.sh --test
```

---

## Discord returns HTTP 401 or 404 { #discord-http-401-404 }

**Cause.** The webhook URL was accepted by the network but rejected by Discord.

| Code | Meaning | Fix |
| --- | --- | --- |
| `401` | The token half of the URL is wrong or has been regenerated | Re-copy the URL from **Server Settings → Integrations → Webhooks** |
| `404` | The webhook was deleted, or the URL is malformed | Create a new webhook and re-set the secret |
| `403` | The webhook lacks access to the channel it targets | Recreate it against a channel the integration can post to |
| `429` | Rate-limited | Nothing — one post per run is far under any limit |

Both `401` and `404` mean the same practically: **the value in `DISCORD_WEBHOOK_URL` no longer
identifies a live webhook.** A webhook URL carries its own authority, so there is nothing else
to check — no account, no token scope, no permission grant. Issue a new webhook and re-set the
secret:

```bash
gh secret set DISCORD_WEBHOOK_URL --repo Minnesota-Nanofabrication-Club/club_website
```

!!! warning "A dead webhook now fails the run, and that is deliberate"
    `notify-discord.sh` exits `1` on an HTTP error, and the workflow step runs under
    `set -euo pipefail` — so the job goes red and the failure issue opens. The proposal itself
    is unaffected; it was pushed and opened before the Discord step ran. Under the deleted
    local design the send failure was swallowed by a `|| true`, which meant a dead webhook
    produced a silent channel and a healthy-looking log — indistinguishable from the sync
    never running.

---

## Known unhandled cases

Stated so nobody assumes coverage that does not exist:

| Gap | Consequence |
| --- | --- |
| **No watchdog** | A run that never starts is reported by nothing. An absent Discord ping is the only signal — see [No run happened at all](#no-run-happened) |
| **Nothing closes a stale proposal** | A quiet run leaves an open PR open and mergeable, however superseded its diff — see [above](#stale-proposal-still-open) |
| **Nothing chases an unmerged proposal** | Announced once. No reminder, no timeout, no escalation |
| **No push retry** | A refused `--force-with-lease` fails the job. The next run re-proposes from scratch |
| **`gh pr create` failures are captured as text** | The Discord post shows an error string where the PR link should be, and the step still succeeds — see [No pull request appeared](#pr-not-appearing) |
| **No check that a merge actually published** | No channel watches the live site. See [Deployment](deployment.md#when-a-push-does-not-appear) |
| **The agent's log is repo-visible** | The Actions log holds whatever it read from Drive, including budget and vendor material. Do not forward it |
| **Pages settings are outside the repo** | Nothing in version control describes the GitHub Pages configuration. See [Deployment](deployment.md#what-is-not-in-the-repo) |

---

[← Reviewing a Proposed Update](reviewing-changes.md){ .md-button } [Deployment →](deployment.md){ .md-button .md-button--primary }
