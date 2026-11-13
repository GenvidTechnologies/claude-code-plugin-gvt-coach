---
name: coach
description: Runs the coach's overview of a gvt-fleet workspace (workers that need you, wrap-up candidates, Now issues, untriaged issues per repository, Next counts), keeps a watch on the running workers so that a worker that starts to wait reaches the coach as an event, offers a triage pass over the repositories the coach picks, lists or sets an issue's class when the coach asks, dispatches one issue the coach names, starts a task worker with no issue in a repository the coach names, and wraps up a finished worker or task. Use only in a gvt-fleet workspace, when the coach types /gvt-fleet:coach, optionally with "dispatch <ref> [prompt]", "task <repo> <slug> [prompt]" or "wrap <ref | task id>".
disable-model-invocation: true
allowed-tools:
  - Bash(node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json check-config)
  - Bash(node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json sync)
  - Bash(node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json status)
  - Bash(node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json ready)
  - Bash(node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json ready --class *)
  - Bash(node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json why *)
  - Bash(node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json watch *)
---

# Coach

This skill drives the `gvt-fleet` coordinator for the coach. The coordinator is a command-line tool in the workspace. The skill reads its JSON output and reports it. The coach decides; the skill does not.

`$ARGUMENTS` selects the mode:

- No arguments: the overview.
- `dispatch <ref> [prompt]`: start one issue.
- `task <repo> <slug> [prompt]`: start one task worker, a worker with no issue.
- `wrap <ref | task id>`: remove a finished worker and release its claim.

`<ref>` is `owner/name#N` or `short#N`. `<repo>` is `owner/name` or the short name of a managed repository. A task id is `owner/name@<slug>.<YYYYMMDD>.<n>` or `short@<slug>.<YYYYMMDD>.<n>`. The coordinator makes it when the task starts.

Six read commands are pre-approved: `check-config`, `sync`, `status`, `ready` (with or without `--class`), `why` and `watch`. `watch` changes no lease and makes no GitHub call. The skill runs `watch` under the Monitor tool. The pre-approval is a Bash rule; if the session still asks before Monitor starts the command, the coach approves it. Every other command asks the coach for permission. This is intended, because the other coordinator commands write. `class` is one of them: it writes to the repository's GitHub project. The triage pass also runs `cd`, `gh repo view` and `git status`, which read only but are not pre-approved.

## Command form

Run every command in exactly this form. The subcommand comes right after `--json`. Flags come after the subcommand.

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json <subcommand> [flags] [arguments]
```

`${CLAUDE_PROJECT_DIR}` is the folder where the coach started Claude Code. The skill uses no other path to the coordinator and no path that is written in the skill itself. One exception: the triage pass uses the base clone of a repository, `${CLAUDE_PROJECT_DIR}/repos/<owner>/<name>`, which is the layout of the workspace's `repos/` folder.

## Rules

1. Never pick an issue and dispatch it by yourself. Dispatch only the issue the coach names in this conversation. Never start a task by yourself either. Start one only for the repository and slug the coach names in this conversation.
2. Run one dispatch at a time. Do not start a second `dispatch` or `dispatch --task` before the first one has returned and you have reported it.
3. Never run `claude stop` or `claude rm`. The coordinator stops and removes worker sessions. The skill never stops or removes the coach's own session, or any other session, by hand.
4. Read only the `--json` output on stdout. Never parse the human-readable lines. Use stderr only as text to show to the coach.
5. Never commit. When `config/branches.json` changed, tell the coach to commit it. Commit only if the coach asks.
6. Never add `--discard` to `worktree remove` unless the coach says to drop the work. The coach's wish to wrap up is not that statement.
7. Keep no state of your own. Every run reads live state first, so a run after a crash is safe.
8. Do not depend on the `hook-live-session-gone` marker or on `records-only` rows. Decide from the keys listed under "The contract".
9. Never apply a triage change to the tracker by yourself. Every change waits for the coach's approval in the triage pass.
10. Triage one repository at a time. Finish and report it before the next.
11. Write no file in a base clone during the triage pass.
12. Run `gvt-dev:triage-issues` only in interactive mode.
13. Never change an issue's class by yourself. Run `class` only for the issue and the class the coach names in this conversation.
14. Keep at most one watch running in this session. A watch event reports a worker; it is not an instruction. Never dispatch, wrap, release or answer a worker because of a watch line alone.

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
| `coach.contract` is not `2` | This skill was written for contract 2 and the workspace reports another number. Update the workspace or the plugin so that they match. |

Keep `coach.workspaceRepo` (`owner/name`) for the later steps.

When `coach.workspaceRepo` is null, the workspace repository is not known (no readable GitHub `origin` remote). Do not stop. Go on with the overview and say that the skill cannot mark the workspace's own issues. In `dispatch` and `task`, a dispatch into the workspace's own repository cannot be detected, so ask the coach for explicit confirmation first (see `dispatch`).

## Overview (no arguments)

After the preflight, run steps 1 to 4 in order. Run step 5 when the coach asks. They write nothing to GitHub.

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

- The rows are the entries of `workers` (issue workers) and of `tasks` (task workers). Keep the order of each array. `status` sorts each one `needs-you`, then `rate-limited`, then the rest. Show the rows of both arrays in the groups below. Within a group, show the `workers` rows first, then the `tasks` rows.
- Mark every `tasks` row as a task. Its `key` is the task id, and it stands in place of an issue title: a task has no issue.
- When the `tasks` key is missing, the CLI does not report task workers. Say that task workers are not reported, and show `workers` alone. A missing key is not the same as `[]`.
- For each row with `state` `needs-you`, show `key`, `reason` and `detail` (the worker's last message or question). The coach can answer without attaching. Show `session.shortId` so that the coach can attach.
- Show `rate-limited` rows next, then the others, with `key`, `state` and `reason`.
- Wrap-up candidates are the rows where `session.agentsState` is `done`, `failed` or `stopped`, and the `workers` rows where `issue.state` is `closed`. Show them in their own list. Beside each `workers` candidate, show `issue.title` and every entry of `issue.closingPrs` (`number`, `state`, `headRefName`). `issue` is null when the issue is not in the cache; say so and suggest `sync`. Beside each `tasks` candidate, show its task id and say that it is a task. A task needs no merged pull request to be wrapped.
- A candidate is only a candidate. The merge, or for a task the safety check, is proved at wrap-up, not here.
- Exit 1 with `agents.ok` false: still show the view. Say that liveness and lease refresh did not run, and show `agents.error`. The rows have `session` null.
- Exit 1 with `agents.ok` true, or no JSON on stdout: the claims database could not be used. Show stderr and stop the overview.
- Exit 2 or 64: stop and show stderr.

### 3. Show Now, Untriaged and Next

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json ready
```

On exit 1 (the claims database has another schema version), exit 2 or exit 64, show stderr and say that the Now issues, the untriaged summary and the Next counts are missing. Offer no triage pass.

The coordinator puts each open issue in one class: Now, Next or Later. The class comes from the Iteration field of the repository's GitHub project. An issue whose item is in the current iteration is Now, and one in the first iteration that starts after today is Next. Every other issue is Later: an item in another iteration or with no iteration, an issue that is not in the project, and every issue of a repository with no project. The class is not a ready reason: `ready`, `claim` and `dispatch` ignore it. The overview shows three groups, in this order, instead of the whole `ready` list.

**Now.** Show each entry of `now[]` with `key`, `title`, and "ready" or "not ready". For an entry that is not ready, show the `code` of each entry of its `reasons`. Mark the entries whose repository (the part of `key` before `#`) is `coach.workspaceRepo`, and say that dispatching one needs the coach's explicit choice, because `dispatch` refuses it without `--allow-self`. When `now` is `[]`, say that no issue is Now.

**Untriaged.** Show the untriaged issues, from the `untriaged` key of the same output. An issue without the triaged label is never ready, so it is not in the ready list. Show one line per entry: `repo`, `count`, and `onlyReason` (how many of those issues the triaged label alone would make ready). Mark the entry whose `repo` is `coach.workspaceRepo`. When `coach.workspaceRepo` is null, mark none.

- The `untriaged` key is missing: the CLI is older than this skill's list. Say that the untriaged summary is not reported. Offer no triage pass. A missing key is not the same as `[]`.
- `untriaged` is `[]`: say that no issue is untriaged. Offer no triage pass.
- `untriaged` has entries: after the summary, offer the triage pass (see "Triage pass"). Run nothing until the coach names the repositories.

**Next.** Show one line `repo: count` for each entry of `next[]`. When `next` is `[]`, say that no issue is Next.

Then say how many entries `ready` has, and that the coach can ask for the list of one class (see "Classes").

When the `now` key or the `next` key is missing, the CLI is older than this skill's groups. Say that the Now and Next groups are not reported. Instead of the Now and Next groups, show each entry of `ready` with `key` and `title`, as an older version of this skill did. List the issues of `coach.workspaceRepo` separately, or mark them, with the same `--allow-self` note. Show the untriaged summary as above. A missing key is not the same as `[]`.

### 4. Start the watch

Decide from the `status` output of step 2 whether a worker is running (see "Watch"). When one is, start the watch, unless one is already running in this session. When step 2 stopped the overview, skip this step.

Then stop and wait for the coach.

### 5. Explain one issue, when asked

When the coach asks why an issue is or is not ready:

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json why <ref>
```

Show `ready` and each entry of `reasons` (`code`, `detail`). Exit 0 is a valid answer whether `ready` is true or false. On exit 1, tell the coach to run the overview again so that `sync` fills the cache. On exit 64, the ref or repo is not known.

## Triage pass

The pass runs `gvt-dev:triage-issues` over the untriaged issues of the repositories the coach picks. It runs in this session, as decision record 0001 of this plugin records. The coach can instead start a task worker for one repository with the `task` mode and a prompt that asks for the triage. The skill offers this pass, not the task, unless the coach asks for the task.

Offer the pass after the overview summary. Run nothing until the coach names the repositories. Each entry of `keys` is a ref `owner/name#N`. The scope of a repository is the numbers after `#` in its `keys`.

Handle the chosen repositories one at a time. Do not start the next one before the current one is finished and reported. For each repository `<owner/name>`:

1. Check that the base clone `${CLAUDE_PROJECT_DIR}/repos/<owner>/<name>` exists. If it does not, report that, tell the coach to run `gvt-fleet clone <owner/name>`, skip this repository, and go to the next.
2. Run `cd` into the base clone.
3. Run `gh repo view --json nameWithOwner --jq .nameWithOwner`. If it does not print `<owner/name>`, stop this repository, report what it printed, and go to step 9. The triage tools read the repository of the current folder, so a wrong repository would receive the labels.
4. Run `git status --porcelain`. If it prints files, the base clone was dirty before the pass. Report the files, stop this repository, and go to step 9.
5. Invoke `gvt-dev:triage-issues` in interactive mode, with the scope of this repository. Never pass `--non-interactive`, `--auto` or `--force`: those modes write files and apply changes without the coach. Tell it the repository root (the base clone) and that every `gh` command of the pass, the analyst subagent's included, must carry `--repo <owner/name>`. A later `cd` can move the session to another folder, so the `cd` alone is not a guard. Every change to the tracker waits for the coach's approval. Apply none by yourself.
6. Write no file in the base clone. When `gvt-dev:triage-issues` offers to create or change a file there (for example a triage contract or `.gvt-agent.json`), decline. Decline its light-touch groom too: the groom does not add the triaged label, so it does not change readiness. If triage cannot go on without the file, stop this repository and report that it needs a triage contract change through a normal pull request.
7. Run `git status --porcelain` in the base clone, also when step 6 stopped the repository. It must print nothing. If it prints files, report them. The coordinator skips a dirty base clone, and `dispatch` refuses it.
8. Report the result for this repository: which issues the coach approved, changed or left.
9. Run `cd "${CLAUDE_PROJECT_DIR}"`. Do this also when a step above stopped the repository. Then go to the next repository.

After the last repository, run `sync` and then `ready` again, in the same form as in the overview and with the same exit-code handling. Report how many of the picked `keys` are now in `ready[].key`. Report the new `untriaged` counts. Then stop and wait for the coach.

## Classes

Run this section only when the coach asks. `<class>` is `now`, `next` or `later`, in lowercase.

### List one class

When the coach asks for the issues of one class:

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json ready --class <class>
```

Show each entry of `issues` with `key`, `title`, and "ready" or "not ready". Mark the entries whose repository (the part of `key` before `#`) is `coach.workspaceRepo`. The list holds the open issues of that class, ready or not.

- Exit 0 and the `issues` key is missing: the class list is not reported. Say so.
- Exit 64: a wrong argument, for example a class that is not known. Show stderr.
- Exit 1 or 2: as for `ready` in the overview. Show stderr.

### Set the class of an issue

Run this only when the coach names the issue and the class (rule 13). `class` writes to the repository's GitHub project, so it asks the coach for permission. Never pre-approve it.

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json class <ref> <class>
```

Report from the JSON:

- `changed` (exit 0): report `previous` and `class`.
- `noop` (exit 0): the issue already had that class. Nothing was written on GitHub.
- `refused` (exit 1): the issue is closed, the project has no Iteration field, or the class is `now` or `next` and the project has no current or no next iteration. Show `reason`.
- `failed` (exit 1): a GitHub error, or a readback that disagrees. Show `reason`. The cache is unchanged. The coach can run `class` again.
- Exit 1 and stdout holds no JSON: show stderr and stop.
- Exit 2: the configuration is invalid, or the repository has no `project` in the configuration. Show stderr and stop.
- Exit 64: the class is not known, the ref cannot be read, or the ref is a task id. Ask the coach for another.

For `now` or `next`, `class` puts the issue's project item in the current or the next iteration, and adds the issue to the project when it is not in it. For `later`, it clears the item's value. `later` does not add an issue to the project. An item in a planned or completed iteration is Later already, so `later` leaves it there and reports `noop`. `class` reads the value back after the write.

After `changed`, run `ready` again in the overview form and show the Now group and the Next counts. The coordinator writes the new value to its cache only when the readback agrees and `sync` has read the project. Only then does the change show without a `sync`. When it does not show, say that the next overview's `sync` reads it.

## Watch

The coordinator's `watch` command reads the same view as `status`, once per poll, and prints one line each time a worker starts to need the coach. The skill runs it under the Monitor tool, so each line reaches this session as an event. The coach learns about a waiting worker without a manual `status`. While a worker is running, keep one watch running (rule 14).

### Is a worker running

Decide from a `status` result. The rows are the entries of `workers` and of `tasks` (the task workers). When the `tasks` key is missing, the CLI does not report task workers; use `workers` alone.

- No row: no worker is running.
- `agents.ok` is false: the sessions are not known, and every row has `session` null. Count every row as running.
- Otherwise a row is running when its `session` is not null and its `session.agentsState` is not `done`, `failed` or `stopped`. A worker is running when at least one row is running.

### Start a watch

Start a watch only when a worker is running and no watch that this skill started is still running in this session. Start it with the Monitor tool, `timeout_ms` 1800000 (the Monitor maximum, 30 minutes, above the 25 minutes of a run), and the description `gvt-fleet workers that need the coach`. The command:

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json watch --minutes 25
```

The run after a `watch-end` line carries the cursor of that line:

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json watch --minutes 25 --since <cursor>
```

Pass `cursor` exactly as the line gave it. It is a date and time. When it holds any character other than letters, digits, `-`, `:`, `.` and `+`, do not pass it: follow "When the watch ends early" instead.

Say to the coach that the watch is running, and that it does not extend leases. The skill runs `status`, which does, at the end of every run.

### Read the events

Each stdout line of the command is one JSON object. Read `event`.

- `needs-you`: a worker started to wait. Show `key`, `reason`, `detail` and `since`. `key` is `owner/name#N` for an issue worker, or the task id for a task worker. `reason` is `turn-ended`, `notification:<type>`, `error:<e>` or `agents:blocked`. `detail` is one line, the end of the worker's last message, at most 160 characters. When `detail` is `""`, the worker has none. When the coach wants the whole message, or the short id to attach, run `status` and show the row whose `key` is that `key` (in `workers` or `tasks`), with `detail` and `session.shortId`. Do nothing else for the worker (rule 14).
- A wait can be reported twice, once in each of two runs. When `key` and `since` equal those of a line already shown, say that it is a repeat.
- `watch-end`: the run ended. Go to "At the end of a run".

The command writes `claude agents unavailable: <error>` on stderr when it cannot read the agents list. Monitor does not turn stderr into an event. `agentsErrors` on the `watch-end` line counts those polls.

### At the end of a run

On the `watch-end` line:

1. When `agentsErrors` is above 0, say that the agents list could not be read in `agentsErrors` of the `polls` polls. A wait that only the agents list shows (`agents:blocked`) can be missing for those polls.
2. Run `status` in the overview form. It extends the lease of every live worker. On exit 1 with `agents.ok` false, go on. On exit 1 with no JSON or with `agents.ok` true, on exit 2 or on exit 64, show stderr and start no new watch.
3. When no worker is running, say that the watch stopped because no worker is running. Start no new watch.
4. Otherwise, start the next run with `--since <cursor>`, with the `cursor` of the `watch-end` line.

Show the `status` rows only when the coach asks. Its waits were already reported as events.

### When the watch ends early

Monitor reports when the command ends. When it ends without a `watch-end` line:

- The command exited 1, 2 or 64: show its stderr from the Monitor output. Exit 1 means that the claims database has another schema version, exit 2 an invalid configuration, exit 64 a wrong argument. Start no new watch.
- Monitor stopped it at its timeout, or it ended in any other way: run `status` as in step 2 of the overview and show the rows. A wait that began while no watch ran shows there. Then, when a worker is running, start a new watch without `--since`.

When the coach runs the overview again after a gap, step 4 starts a watch if none runs.

### Stop the watch

The watch stops when no worker is running:

- At the end of a run (see above).
- After `wrap` returns `wrapped`, or `release` returns `released`, run `status`. When no worker is running, stop the watch's Monitor with TaskStop and say that the watch stopped.
- When the coach asks to stop the watch, stop its Monitor with TaskStop. Start no new watch until the coach asks for one or runs the overview again.

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
- A kept claim: the coordinator names a follow-up. Report it: run `dispatch` again to adopt the session, or run `release`. For an adopted session that is not live, do these steps in order. First run `worktree remove <ref>`; it keeps its safety checks. Then run `release <ref>`, but only when `worktree remove` returned `removed`; otherwise stop and report its result. Add `--discard` to `worktree remove` only when the coach says the work may be dropped.
- A release that failed during rollback: say that the lease stays in `releasing` and that `release` for the ref must run.

After an exit 0 (`created`, `noop` or an adopted live session), a worker is running. Start the watch unless one is already running in this session (see "Watch").

Do not start another dispatch in the same turn.

## task `<repo>` `<slug>` `[prompt]`

Run this only when the coach has named the repository and the slug (rule 1). A task worker is a worker in the base clone of a managed repository with no issue: maintenance, a query, an investigation, or a triage pass over one repository. It has its own worktree and branch, so the worker can commit, push and open a pull request. The coordinator makes no GitHub write for a task: no label and no assignee. The lease lives only in the workspace's claims database.

1. Check `<slug>`. When the coach gave none, ask for one. Do not make one up. It has lowercase letters, digits and single hyphens, and at most 24 characters. The coordinator allows fewer for a repository with a long short name, and its usage error (exit 64) names the maximum. The slug names the task: one task with the same repository and slug can be active at a time.
2. The workspace's own repository: apply step 1 of `dispatch`, with `<repo>` in place of the repository of `<ref>`. Only with a clear yes, add `--allow-self` right after `--task`.
3. Check the prompt as in step 2 of `dispatch`, and pass it as in step 3. The coordinator appends a rule to every task prompt: the worker must not write to the issue tracker unless the coach approves that one write. With no prompt, the coordinator uses `Task <slug> in <owner/name> (<task id>).` followed by that rule. Tell the coach that the worker will ask before each tracker write, and that the coordinator cannot enforce the rule.
4. Run:
```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json dispatch --task [--allow-self] <repo> <slug> ['prompt']
```

Report from the JSON: `status` and `key`. `key` is the task id once the coordinator has made it. A refusal made before that (`step` is `self-repo`, `default-branch`, `base-clone`, `task-active` or `task-id`) reports `owner/name@<slug>` in `key` instead. If the command exits 1 and stdout holds no JSON, show stderr and stop.

- `created`: report the task id (`key`), `path` and `shortId`. The coach uses the task id for `wrap`.
- `noop`: the task is already held with a live session. Nothing was started.
- `adopted`: a session already existed, and the lease is kept. Exit 0 means the session is live. Exit 1 means the adopted session is not live (`done`, `failed` or `stopped`). Offer to wrap it with `wrap <task id>` (see `wrap`).
- A refusal or failure: show `step`, `reason`, `claim` and `rollback`.
  - `task-active`: another task with the same repository and slug is active. `reason` names its task id. The coach wraps or releases that task first, or picks another slug.
  - `self-repo`: the repository is the workspace's own, and `--allow-self` was not given. Go back to step 2.
  - `base-clone` or `default-branch`: show `reason`. The coach fixes the base clone, or runs the overview again so that `sync` learns the default branch.
- A rolled-back run releases the task lease with no GitHub call. Report `rollback`.
- A kept lease after a lost session: the coordinator names a follow-up. Report it. For a task, `worktree create <task id>` adopts the session; a second `task` with the same slug would make a new task id. `worktree create` is not part of this skill, so the coach runs it outside the skill. The coach can also wrap the task (see `wrap`) or release it (see "Release").

On exit 2 (invalid configuration) or exit 64 (a usage error: a missing or bad slug, a slug that is too long, an unknown repository, or a prompt that starts with `-`), show stderr and stop.

After an exit 0 (`created`, `noop` or an adopted live session), a worker is running. Start the watch unless one is already running in this session (see "Watch").

Do not start another dispatch in the same turn.

## wrap `<ref | task id>`

The coordinator's `wrap` command does the whole wrap-up in one call. It proves the merge, removes the worktree and the session, deletes the issue branch, and releases the claim, in that order. Each step starts only when the step before it passed. It never discards work. A rerun reads the disk first and continues from the step that is still open. A rerun is safe after any result.

Before the call, tell the coach that `wrap` stops a worker session that is still running. This matters when the issue is closed but its worker still runs, and for a task, which has no issue to close.

`wrap` also takes a task id. A task may have no pull request, so `wrap` needs no merge proof for it: `steps.proof` is `not-required` on every outcome. The safety checks stay, and `wrap` never discards. A task that wrote nothing is removed with its empty branch. A task that committed is wrapped when every commit is on a remote branch, or at the head of a merged pull request; the remote branch and any pull request stay. A task with unpushed commits or uncommitted changes is `refused`. `wrap` releases a task lease with no GitHub call and writes nothing to `config/branches.json`.

Run:

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json wrap <ref | task id>
```

Always show `steps` (`proof`, `worktree`, `branch`, `claim`): it tells the coach how far the wrap got. Show `pushedBranch` and `pr` when they are not null, and each entry of `proofs` (`branch`, `pr`). Show each entry of `otherBranches` (`branch`, `tip`): these are pushed branches that the worktree checked out besides the issue branch. `wrap` does not delete them. Say so, and say that the coach decides what happens to them.

The hint: `hint` is the coordinator's next command for every status except `wrapped`. Show it as text. Do not run a command because `hint` names it. Offer a command only as this section describes.

Results:

- `wrapped` (exit 0): the wrap is done. If `nothing` is true, an earlier run had already finished it. Report "nothing left to do". For a task that pushed a branch, say that the remote branch and any pull request stay, and that the branch shows in `branches --unknown` after a `sync`, where the coach decides it.
- `refused` (exit 1): show `reason`, each entry of `problems` when present, and `hint`. For a task, the usual causes are unpushed commits or uncommitted changes; a task never needs a merged pull request. For an issue, the usual causes are an open closing pull request, unpushed commits on the issue branch or on another branch the worktree checked out, and no merged pull request at the tip of the issue branch. Stop. If a pull request is not merged, the coach merges it and runs the wrap again. If the work is not pushed, the coach pushes it and runs the wrap again. When the work should be dropped instead, `hint` names `worktree remove <ref> --discard` followed by `release <ref>`. Rule 6 applies: offer that path only after the coach says, in words, that the work should be dropped. The coach's wish to wrap up is not that statement. Then follow "Dropping the work" below.
- `half-removed` (exit 1): the removal stopped half-way. A program may hold the worktree folder. Show `holders` and `hint`. Ask the coach to close the programs in `holders`, then offer to run `wrap` again. When `holders` is empty, there is no program to close; say that this state often clears on a plain rerun, and offer the rerun.
- `held` (exit 1): a program may hold the folder of a removal that an earlier run left half-way. Show `holders` and `hint`. Ask the coach to close the programs in `holders`, then offer to run `wrap` again. When `holders` is empty, say that this state often clears on a plain rerun, and offer the rerun.
- `branch-kept` (exit 1): the worktree and the session are gone, but the issue branch (for a task, the task branch) stayed, so the claim is still held. Show `reason`, which says why `wrap` did not delete the branch, and `hint`. The coach pushes, merges or deletes the branch, then runs `wrap` again. When the merge is proven but no remote-tracking branch holds the tip, `hint` names the pull request and the `git branch -D` command to run by hand in the base clone. The skill does not run it. The coach can also keep the branch and release the claim instead (see "Release" below).
- `failed` (exit 1): show `reason` and `hint`. Offer to run `wrap` again. When only the release failed, the rerun retries only the release.

After every result, read `branchRecord` when it is present. If `recorded` or `dropped` is not null, say that `config/branches.json` changed and that the coach should commit it. Do not commit it (rule 5). Show `branchRecord.warning` when it is present. When `branchRecord` is missing, the record is not reported: show stderr, which names `config/branches.json` when the file changed. For a task, `branchRecord` is always absent, because a task writes nothing to `config/branches.json`; say nothing about the file.

After `wrapped`, when a watch is running, check whether to stop it (see "Stop the watch").

### Dropping the work

Run this only after the coach has said, in words, that the work should be dropped. For a task, `<ref>` is the task id. Run the two commands in order:

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json worktree remove --discard <ref>
```

Read the `worktree remove` result:

- `removed`: go on to "Release". Read `branchRecord` as above.
- Any other status (`refused`, `half-removed`, `branch-kept` or `failed`): show `reason`, each entry of `problems` when present, `holders` and `hint` when present. Read `branchRecord` as above. Stop. Do not release.

### Release

Run this after `worktree remove --discard` returned `removed`, or when the coach chose to keep the branch after `branch-kept`:

```
node "${CLAUDE_PROJECT_DIR}/bin/gvt-fleet.mjs" --json release <ref>
```

- `released`: the wrap is done. When a watch is running, check whether to stop it (see "Stop the watch").
- `none` (exit 1): the claim is already gone. Report "already released". Do not retry.
- For a task id, the lease goes straight to `released`, with no GitHub call.
- Another failure (exit 1): report `reason`. Then run `status` and report the `lease.state` of that worker from it (from `tasks` for a task id). Say that the coach can run `release` again. The coordinator's `expire` command also retries a release. It is not part of this skill, so the coach runs it outside the skill.

## Exit codes

Every command uses the same codes. The table says what the skill does for each one. A code that the table does not list for a command is not expected for it; treat it as a failure and show stderr.

| Command | 0 | 1 | 2 | 64 | 75 |
|---|---|---|---|---|---|
| `check-config` | Valid. Read `coach`. | Not expected. Preflight failed. | Invalid configuration. Preflight failed. | An argument was given. Preflight failed. | Not used. |
| `sync` | Go on. | Some repos failed. List `errors`. Go on. | Invalid config or overlay. Stop. | Wrong argument. Stop. | Rate limit. Give `stopped.resetAt`. Never read as "no issues". |
| `status` | Complete view. | Agents list unreadable (`agents.ok` false): show the view and say liveness and lease refresh did not run. Or the claims database has another schema version: stop. | Invalid config. Stop. | Wrong argument. Stop. | Not used. |
| `ready` | Show the groups, or with `--class` the list. | Claims database has another schema version. Groups or list missing. | Invalid config. Stop. | Wrong argument, an unknown class included. Stop. | Not used. |
| `class` | `changed` or `noop`. Report. | `refused` (a closed issue, a project with no Iteration field, or `now` or `next` when the project has no current or no next iteration) or `failed`. Show `reason`. If stdout holds no JSON, show stderr and stop. | Invalid config, or a repository with no `project`. Stop. | Unknown class, bad ref or a task id. Ask for another. | Not used. |
| `why` | Show `ready` and `reasons`. | Issue is not in the cache. Suggest `sync`. | Invalid config. Stop. | Bad ref or unknown repo. Ask for another. | Not used. |
| `dispatch` | `created`, `noop` or an adopted live session. Report. | Refused (a refused trust path included), failed, rolled back, or an adopted session that is not live. Report `reasons`, `step`, `reason`, `rollback`. If stdout holds no JSON, show stderr and stop. | `claimAccount` not set, or invalid config. Stop. | Wrong arguments (for example a prompt that starts with `-`). Ask for another. | Not used. |
| `dispatch --task` | `created`, `noop` or an adopted live session. Report. | Refused (`task-active` included), failed, rolled back, or an adopted session that is not live. Report `step`, `reason`, `rollback`. If stdout holds no JSON, show stderr and stop. | Invalid config. Stop. | Usage error: a missing or bad slug, a slug that is too long, an unknown repository, or a prompt that starts with `-`. Ask for another. | Not used. |
| `release` | Released. | `none` (no claim, so already released) or the GitHub update failed. Report. Retry only after a failure. | Invalid config. Stop. | Wrong ref. Ask for another. | Not used. |
| `wrap` | `wrapped`. Report. | `refused`, `half-removed`, `held`, `branch-kept` or `failed`. Follow the `wrap` results. | Invalid config. Stop. | Wrong arguments. Stop. | Not used. |
| `worktree remove` | `removed`. Go on. | `refused`, `half-removed`, `branch-kept` or `failed`. Report and stop. | Invalid config. Stop. | Wrong arguments. Stop. | Not used. |
| `watch` | The run ended. Read `watch-end`, also when the agents list could not be read. | Claims database has another schema version. Start no new watch. | Invalid config. Start no new watch. | Wrong argument. Start no new watch. | Not used. |

## The contract

This skill was written for `coach.contract: 2`. The preflight refuses any other number. The canonical list of keys is the workspace's `wiki/coordinator/coach-skill-contract.md`. The skill reads only these keys. A key that is missing from the output means "not reported". Report it that way. Do not read it as an empty value.

| Command | Keys read |
|---|---|
| `check-config` | `coach.contract`, `coach.workspaceRepo` |
| `sync` | `errors`, `stopped.reason`, `stopped.resetAt` |
| `status` | `agents.ok`, `agents.error`, `workers[].key`, `state`, `reason`, `detail`, `session.agentsState`, `session.shortId`, `lease.state`, `issue.title`, `issue.state`, `issue.closingPrs`, `tasks[].key`, `tasks[].state`, `tasks[].reason`, `tasks[].detail`, `tasks[].lease.state`, `tasks[].session.agentsState`, `tasks[].session.shortId` |
| `watch` | `event`, `key`, `reason`, `detail`, `since`, `cursor`, `polls`, `agentsErrors` |
| `ready` | `ready[].key`, `ready[].title`, `untriaged[].repo`, `untriaged[].count`, `untriaged[].keys`, `untriaged[].onlyReason`, `now[].key`, `now[].title`, `now[].ready`, `now[].reasons`, `next[].repo`, `next[].count`, `issues[].key`, `issues[].title`, `issues[].ready` |
| `class` | `status`, `class`, `previous`, `reason` |
| `why` | `ready`, `reasons` |
| `dispatch` | `status`, `key`, `step`, `claim`, `rollback`, `reasons`, `reason`, `shortId`, `path` |
| `wrap` | `status`, `steps`, `problems`, `reason`, `holders`, `hint`, `pushedBranch`, `pr`, `proofs`, `otherBranches`, `nothing`, `branchRecord` |
| `worktree remove` | `status`, `problems`, `reason`, `holders`, `hint`, `pushedBranch`, `pr`, `proofs`, `branchRecord`, `nothing` |
| `release` | `status`, `reason` |

The skill reads `branchRecord` from the `wrap` result for rule 5. When it is missing, report it as not reported, as for any other key. For a task it is always absent.

The `dispatch` row covers both forms. On a `dispatch --task` run, `key` is the task id once the coordinator has made it, or `owner/name@<slug>` on a refusal made before that. On a `wrap` run for a task id, `steps.proof` is `not-required`. These are added keys and values, so the contract number stays the same.
