---
name: coach
description: Runs the coach's overview of a gvt-fleet workspace (workers that need you, wrap-up candidates, ready issues, untriaged issues per repository), offers a triage pass over the repositories the coach picks, dispatches one issue the coach names, and wraps up a finished worker. Use only in a gvt-fleet workspace, when the coach types /gvt-fleet:coach, optionally with "dispatch <ref> [prompt]" or "wrap <ref>".
disable-model-invocation: true
allowed-tools:
  - Bash(node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json check-config)
  - Bash(node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json sync)
  - Bash(node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json status)
  - Bash(node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json ready)
  - Bash(node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json why *)
---

# Coach

This skill drives the `gvt-fleet` coordinator for the coach. The coordinator is a command-line tool in the workspace. The skill reads its JSON output and reports it. The coach decides; the skill does not.

`$ARGUMENTS` selects the mode:

- No arguments: the overview.
- `dispatch <ref> [prompt]`: start one issue.
- `wrap <ref>`: remove a finished worker and release its claim.

`<ref>` is `owner/name#N` or `short#N`.

Five read commands are pre-approved: `check-config`, `sync`, `status`, `ready` and `why`. Every other command asks the coach for permission. This is intended, because those commands write.

## Command form

Run every command in exactly this form. The subcommand comes right after `--json`. Flags come after the subcommand.

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json <subcommand> [flags] [arguments]
```

`${CLAUDE_PROJECT_DIR}` is the folder where the coach started Claude Code. The skill uses no other path to the coordinator and no path that is written in the skill itself.

## Rules

1. Never pick an issue and dispatch it by yourself. Dispatch only the issue the coach names in this conversation.
2. Run one dispatch at a time. Do not start a second `dispatch` before the first one has returned and you have reported it.
3. Never run `claude stop` or `claude rm`. The coordinator stops and removes worker sessions. The skill never stops or removes the coach's own session, or any other session, by hand.
4. Read only the `--json` output on stdout. Never parse the human-readable lines. Use stderr only as text to show to the coach.
5. Never commit. When `config/branches.json` changed, tell the coach to commit it. Commit only if the coach asks.
6. Never add `--discard` to `worktree remove` unless the coach says to drop the work. The coach's wish to wrap up is not that statement.
7. Keep no state of your own. Every run reads live state first, so a run after a crash is safe.
8. Do not depend on the `hook-live-session-gone` marker or on `records-only` rows. Decide from the keys listed under "The contract".
9. Never apply a triage change to the tracker by yourself. Every change waits for the coach's approval in the triage pass.
10. Triage one repository at a time. Finish and report it before the next.
11. Write no file in a base clone during the triage pass.

## Preflight

Run this first, in every mode:

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json check-config
```

Stop at once, and run no other command, when any of these is true. Give the coach the matching message:

| Condition | Message to the coach |
|---|---|
| The command does not start (node is missing, or the CLI file is missing), or the exit code is not 0 and not 2 | The preflight failed: this folder is not a gvt-fleet workspace, or the coordinator cannot run. Show the exit code and stderr. |
| The exit code is 2 | The workspace configuration is invalid. Show stderr. |
| The output is not JSON, or has no `coach` key | The workspace is older than this skill. Update the workspace, then run the skill again. |
| `coach.contract` is not `1` | This skill was written for contract 1 and the workspace reports another number. Update the workspace or the plugin so that they match. |

Keep `coach.workspaceRepo` (`owner/name`) for the later steps.

When `coach.workspaceRepo` is null, the workspace repository is not known (no readable GitHub `origin` remote). Do not stop. Go on with the overview and say that the skill cannot mark the workspace's own issues. In `dispatch`, a dispatch into the workspace's own repository cannot be detected, so ask the coach for explicit confirmation first (see `dispatch`).

## Overview (no arguments)

After the preflight, run these four steps in order. They write nothing to GitHub.

### 1. Refresh the cache

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json sync
```

- Exit 0: go on.
- Exit 1: some repos failed. List each entry of `errors` (`repo`, `message`). Say that the cache for those repos may be old. Go on.
- Exit 75: the rate limit stopped the run. Give the reset time from `stopped.resetAt` and the reason from `stopped.reason`. Say that the cache view is not up to date. Never read this as "no issues". Go on with the cache.
- Exit 2 or 64: stop and show stderr.

### 2. Show the workers

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json status
```

- Keep the order of `workers`. `status` sorts `needs-you`, then `rate-limited`, then the rest.
- For each worker with `state` `needs-you`, show `key`, `reason` and `detail` (the worker's last message or question). The coach can answer without attaching. Show `session.shortId` so that the coach can attach.
- Show `rate-limited` rows next, then the others, with `key`, `state` and `reason`.
- Wrap-up candidates are the rows where `session.agentsState` is `done`, `failed` or `stopped`, or where `issue.state` is `closed`. Show them in their own list. Beside each, show `issue.title` and every entry of `issue.closingPrs` (`number`, `state`, `headRefName`). `issue` is null when the issue is not in the cache; say so and suggest `sync`.
- A candidate is only a candidate. The merge is proved at wrap-up, not here.
- Exit 1 with `agents.ok` false: still show the view. Say that liveness and lease refresh did not run, and show `agents.error`. The rows have `session` null.
- Exit 1 with `agents.ok` true, or no JSON on stdout: the claims database could not be used. Show stderr and stop the overview.
- Exit 2 or 64: stop and show stderr.

### 3. Show the ready issues

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json ready
```

Show each entry of `ready` with `key` and `title`. List the issues of `coach.workspaceRepo` separately, or mark them. Say that dispatching one needs the coach's explicit choice, because `dispatch` refuses it without `--allow-self`.

On exit 1 (the claims database has another schema version), exit 2 or exit 64, show stderr and say that the ready list is missing.

Then show the untriaged issues, from the `untriaged` key of the same output. An issue without the triaged label is never ready, so it is not in the ready list. Show one line per entry: `repo`, `count`, and `onlyReason` (how many of those issues the triaged label alone would make ready). Mark the entry whose `repo` is `coach.workspaceRepo`.

- The `untriaged` key is missing: the CLI is older than this skill's list. Say that the untriaged summary is not reported. Offer no triage pass. A missing key is not the same as `[]`.
- `untriaged` is `[]`: say that no issue is untriaged. Offer no triage pass.
- `untriaged` has entries: after the summary, offer the triage pass (see "Triage pass"). Run nothing until the coach names the repositories.

### 4. Explain one issue, when asked

When the coach asks why an issue is or is not ready:

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json why <ref>
```

Show `ready` and each entry of `reasons` (`code`, `detail`). Exit 0 is a valid answer whether `ready` is true or false. On exit 1, tell the coach to run the overview again so that `sync` fills the cache. On exit 64, the ref or repo is not known.

Then stop and wait for the coach.

## Triage pass

The pass runs `gvt-dev:triage-issues` over the untriaged issues of the repositories the coach picks. It runs in this session. The reasons are in the decision record `docs/decisions/0001-run-the-triage-pass-in-the-coach-session.md` of the plugin repository.

Offer the pass after the overview summary. Run nothing until the coach names the repositories. Take the issue numbers from the `keys` of the chosen `untriaged` entries.

Handle the chosen repositories one at a time. Do not start the next one before the current one is finished and reported. For each repository `<owner/name>`:

1. Check that the base clone `${CLAUDE_PROJECT_DIR}/repos/<owner>/<name>` exists. If it does not, report that, tell the coach to run `gvt-fleet clone <owner/name>`, skip this repository, and go to the next.
2. Run `cd` into the base clone.
3. Run `gh repo view --json nameWithOwner --jq .nameWithOwner`. If it does not print `<owner/name>`, stop this repository, report what it printed, and go to the next. The triage tools read the repository of the current folder, so a wrong repository would receive the labels.
4. Invoke `gvt-dev:triage-issues` with the issue numbers of that repository's `keys` as the scope. Tell it the repository root (the base clone) and that every `gh` command of the pass, the analyst subagent's included, must carry `--repo <owner/name>`. A subagent may start in another folder, so the `cd` alone is not a guard.
5. Every change to the tracker waits for the coach's approval. Apply none by yourself.
6. Write no file in the base clone. When `gvt-dev:triage-issues` offers to create or change a file there (for example a triage contract or `.gvt-agent.json`), decline. If triage cannot go on without that file, stop this repository. Report that it needs a triage contract change through a normal pull request. Go on with the next repository.
7. When the repository is finished, run `git status --porcelain` in the base clone. It must print nothing. If it prints files, report them. The coordinator skips a dirty base clone, and `dispatch` refuses it.
8. Report the result for this repository: which issues the coach approved, changed or left.
9. Run `cd "${CLAUDE_PROJECT_DIR}"`. Do this also when a step above stopped the repository.

After the last repository, run `sync` and then `ready` again, in the same form as in the overview and with the same exit-code handling. Report how many of the picked `keys` are now in `ready[].key`. Report the new `untriaged` counts. Then stop and wait for the coach.

## dispatch `<ref>` `[prompt]`

Run this only when the coach has named the issue.

1. If `<ref>` is in `coach.workspaceRepo`, ask the coach to confirm. Only with a clear yes, add `--allow-self` as the first argument after `dispatch`. Without it, the coordinator refuses. When `coach.workspaceRepo` is null, the workspace repository is unknown: the coordinator cannot read the workspace origin, and it refuses every `dispatch` without `--allow-self`. Tell the coach this. Ask the coach to confirm the dispatch explicitly. Only with a clear yes, add `--allow-self`, whichever repository `<ref>` is in. Without a clear yes, do not dispatch.
2. Check the prompt. It must not be empty. It must not start with `-`. It must not equal `--json`, `--help`, `-h`, `--config` or `--state-dir`, because the coordinator would read these as flags. It must not contain a single quote. If the prompt breaks a rule, ask the coach for another one. With no prompt, leave out the argument, and the coordinator uses its default.
3. Pass the prompt as one argument: put it in single quotes in the Bash command.
4. Run:
```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json dispatch [--allow-self] <ref> ['prompt']
```

Report from the JSON: `status`, `step`, `claim` and `rollback`. If the command exits 1 and stdout holds no JSON (for example an issue that cannot be read), show stderr and stop.

- `created`: report `path` and `shortId`.
- `noop`: the issue is already held with a live session. Nothing was started.
- `adopted`: a session already existed, and the claim is kept. Exit 0 means the session is live. Exit 1 means the adopted session is not live (`done`, `failed` or `stopped`).
- A refusal carries either `reasons` or a single `reason` (with `step`). Show whichever is present: each entry of `reasons`, or `reason` and `step`.
- A failed or rolled-back run: report `step`, `reason`, and whether the claim was released (`rollback`).
- A kept claim: the coordinator names a follow-up. Report it: run `dispatch` again to adopt the session, or run `release`. For an adopted session that is not live, do these steps in order. First run `worktree remove <ref>` with no `--require-merged`; it keeps its safety checks. Then run `release <ref>`, but only when `worktree remove` returned `removed`; otherwise stop and report its result. Add `--discard` to `worktree remove` only when the coach says the work may be dropped.
- A release that failed during rollback: say that the lease stays in `releasing` and that `release` for the ref must run.

Do not start another dispatch in the same turn.

## wrap `<ref>`

Run the steps in order. Stop at the first non-zero exit. One exception: `branch-kept` (exit 1) goes on to the steps described for it below.

Before step 1, tell the coach that `worktree remove` stops a worker session that is still running. This matters when the issue is closed but its worker still runs.

1. Remove the worktree and prove the merge:

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json worktree remove --require-merged <ref>
```

2. Release the claim when step 1 exits 0 (`removed`), when `worktree finish` returns `removed`, or when the coach agrees to release after `branch-kept`:

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json release <ref>
```

Results of step 1:

- `removed`: go to step 2. If `nothing` is true, there was nothing left to remove; go on.
- `refused`: show `reason`, and each entry of `problems` when present. Show `pr` and `pushedBranch` when they are not null. Stop. Do not suggest `--discard`. If the problem is an unmerged pull request, the coach merges it and runs the wrap again. If the work is not pushed, the coach pushes it. Offer `--discard` only after the coach says, in words, that the work should be dropped. Then run the command below, never with `--require-merged` (the coordinator exits 64 for both flags together):

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json worktree remove --discard <ref>
```
- `half-removed`: show `holders` and `hint`. Tell the coach to close those programs. Then offer:

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json worktree finish <ref>
```

- `branch-kept`: the worktree and session are gone, but the local branch stayed. Show `reason`. The merge was proved in step 1, so no work is lost. By the git documentation, `git branch -d` compares the branch with its upstream when one is set, and otherwise with the HEAD of the base clone. So it refuses when the branch has no upstream, or its remote-tracking branch is gone (for example deleted on merge and pruned by a fetch), and its commits are not in that HEAD, as after a squash merge. Offer `worktree finish` as above. It uses the same `git branch -d`, so it will likely keep the branch again. In that case, tell the coach that only the local branch is left. The coach can delete it by hand outside the skill. Then ask whether to release the claim (step 2).
- `failed`: show `reason` and stop.

Results of `worktree finish`:

- `removed`: go to step 2.
- `held`: show `holders` and `hint`. The coach closes the programs. Run `worktree finish` again.
- `branch-kept`: show `reason`. The merge was proved in step 1, so only the local branch is left. `worktree finish` uses the same `git branch -d`, so this is likely. The coach can delete the branch by hand outside the skill. Ask whether to release the claim (step 2).
- Anything else: show `reason` and stop.

Results of `release`:

- `released`: the wrap is done.
- `none` (exit 1) on a rerun: the claim is already gone. Report "already released". Do not retry.
- Another failure (exit 1): report `reason`. Then run `status` and report the `lease.state` of that worker from it. Say that the coach can run `release` again. The coordinator's `expire` command also retries a release. It is not part of this skill, so the coach runs it outside the skill.

After the wrap, and also when the wrap stops at `refused` or `half-removed`, read `branchRecord` in the `worktree remove` result. If `recorded` or `dropped` is not null, say that `config/branches.json` changed and that the coach should commit it. Do not commit it. Show `branchRecord.warning` when it is present.

## Exit codes

Every command uses the same codes. The table says what the skill does for each one. A code that the table does not list for a command is not expected for it; treat it as a failure and show stderr.

| Command | 0 | 1 | 2 | 64 | 75 |
|---|---|---|---|---|---|
| `check-config` | Valid. Read `coach`. | Not expected. Preflight failed. | Invalid configuration. Preflight failed. | An argument was given. Preflight failed. | Not used. |
| `sync` | Go on. | Some repos failed. List `errors`. Go on. | Invalid config or overlay. Stop. | Wrong argument. Stop. | Rate limit. Give `stopped.resetAt`. Never read as "no issues". |
| `status` | Complete view. | Agents list unreadable (`agents.ok` false): show the view and say liveness and lease refresh did not run. Or the claims database has another schema version: stop. | Invalid config. Stop. | Wrong argument. Stop. | Not used. |
| `ready` | Show the list. | Claims database has another schema version. List missing. | Invalid config. Stop. | Wrong argument. Stop. | Not used. |
| `why` | Show `ready` and `reasons`. | Issue is not in the cache. Suggest `sync`. | Invalid config. Stop. | Bad ref or unknown repo. Ask for another. | Not used. |
| `dispatch` | `created`, `noop` or an adopted live session. Report. | Refused (a refused trust path included), failed, rolled back, or an adopted session that is not live. Report `reasons`, `step`, `reason`, `rollback`. If stdout holds no JSON, show stderr and stop. | `claimAccount` not set, or invalid config. Stop. | Wrong arguments (for example a prompt that starts with `-`). Ask for another. | Not used. |
| `release` | Released. | `none` (no claim, so already released) or the GitHub update failed. Report. Retry only after a failure. | Invalid config. Stop. | Wrong ref. Ask for another. | Not used. |
| `worktree remove` | `removed`. Go on. | `refused`, `half-removed`, `branch-kept` or `failed`. Follow the wrap steps. | Invalid config. Stop. | Wrong arguments, or `--discard` with `--require-merged`. Stop. | Not used. |
| `worktree finish` | `removed`. Go on. | A step was refused, held or failed, or the branch was kept. Follow the wrap steps. | Invalid config. Stop. | Wrong arguments. Stop. | Not used. |

## The contract

This skill was written for `coach.contract: 1`. The preflight refuses any other number. The canonical list of keys is the section "The coach skill contract" in the workspace's `docs/coordinator.md`. The skill reads only these keys. A key that is missing from the output means "not reported". Report it that way. Do not read it as an empty value.

| Command | Keys read |
|---|---|
| `check-config` | `coach.contract`, `coach.workspaceRepo` |
| `sync` | `errors`, `stopped.reason`, `stopped.resetAt` |
| `status` | `agents.ok`, `agents.error`, `workers[].key`, `state`, `reason`, `detail`, `session.agentsState`, `session.shortId`, `lease.state`, `issue.title`, `issue.state`, `issue.closingPrs` |
| `ready` | `ready[].key`, `ready[].title`, `untriaged[].repo`, `untriaged[].count`, `untriaged[].keys`, `untriaged[].onlyReason` |
| `why` | `ready`, `reasons` |
| `dispatch` | `status`, `step`, `claim`, `rollback`, `reasons`, `reason`, `shortId`, `path` |
| `worktree remove` | `status`, `problems`, `reason`, `holders`, `hint`, `pushedBranch`, `pr`, `branchRecord`, `nothing` |
| `worktree finish` | `status`, `reason`, `holders`, `hint` |
| `release` | `status`, `reason` |
