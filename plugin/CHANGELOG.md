# Changelog

All notable changes to the `gvt-fleet` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and follows [semantic versioning](https://semver.org/).

## [Unreleased]

### Added

- **Class list and class change on request.** The coach can ask for the issues of one class (`ready --class <now|next|later>`, pre-approved because it only reads). The coach can also ask to move an issue to another class. The skill then runs `class <ref> <class>`, which writes labels on GitHub, so it always asks for permission. Afterwards the skill runs `ready` again and shows the change without a `sync`.
  - **Consumers:** both need a workspace CLI that has `ready --class` and the `class` command. With an older CLI the skill shows the CLI's error.
- **Watch on the running workers.** While a worker runs, the skill keeps one `gvt-fleet watch --minutes 25` running under the Monitor tool, so a worker that starts to wait reaches the coach as an event, with its `key`, `reason` and `detail`. The overview starts the watch, and so does a `dispatch` that exits 0. At each `watch-end` line the skill runs `status`, which extends the leases, and starts the next run from the line's `cursor`. When Monitor ends a run early, the skill shows `status` and starts a new run. The watch stops when no worker is running, or when the coach asks. `watch` is pre-approved, because it changes no lease and makes no GitHub call.
  - **Consumers:** the watch needs a workspace CLI that has the `watch` command. With an older CLI the command exits 64 and the skill starts no watch. These are added keys, so the coach contract stays at 2.
- **Task mode.** `task <repo> <slug> [prompt]` starts a task worker, a worker in a managed repository's base clone with no issue, through `dispatch --task`. The rules of `dispatch` apply: only when the coach names the repository and the slug, one at a time, the same prompt checks, and `--allow-self` only on a clear yes for the workspace's own repository. The overview lists the `tasks` rows of `status` in the same groups as the issue workers, marked as tasks, and a finished task is a wrap-up candidate. `wrap <task id>` wraps a task with no merge proof; dropping a task's work still needs the coach's words. The contract table adds `dispatch` `key` and the `tasks[]` `state`, `reason` and `lease.state` keys.
  - **Consumers:** the task mode needs a workspace CLI that has `dispatch --task` and reports `tasks` in `status --json`. With an older CLI the task dispatch exits 64 and the overview says task workers are not reported. These are added keys, so the coach contract stays at 2.

### Changed

- **The overview shows Now, Untriaged and Next instead of the whole ready list.** Step 3 shows each Now issue (ready or not, with its reason codes, marked when it carries both class labels), the untriaged summary, and one count line for each repository with Next issues. It still says how many issues are ready.
  - **Consumers:** the groups need a workspace CLI whose `ready --json` reports `now` and `next`. With an older CLI the overview says the groups are not reported and shows the ready list as before. These are added keys, so the coach contract stays at 2.

## [0.2.0] - 2026-11-08

### Added

- **Untriaged summary in the coach overview.** Step 3 of the overview now shows, for each repository, how many open issues are untriaged and how many the triaged label alone would make ready.
  - **Consumers:** the summary needs a workspace CLI whose `ready --json` reports `untriaged`. With an older CLI the overview says "not reported" and offers no triage pass. The coach contract stays at 1.
- **Triage pass.** The coach can name repositories from the summary. For each one, in turn, the skill runs `gvt-dev:triage-issues` in the repository's base clone. It checks the repository with `gh repo view`, tells the triage skill to put `--repo <owner/name>` on every `gh` command, runs it only in interactive mode, waits for the coach's approval of every tracker change, and writes no file in the base clone. Afterwards it runs `sync` and `ready` and reports how many of the picked issues became ready.

### Changed

- **The skill now needs coach contract 2.** The preflight accepts `coach.contract: 2` only. In contract 2, the merge gate proves the issue's own work, not the branch that is checked out in the worktree, and `worktree remove` reports every proving pull request in `proofs`.
  - **Consumers:** update the workspace CLI to a version that reports contract 2 together with this plugin. A CLI on contract 1 stops the skill at the preflight, and so does a plugin on contract 1 against a contract-2 CLI.
- **`wrap <ref>` runs one `gvt-fleet wrap` call.** It replaces the sequence `worktree remove --require-merged`, `worktree finish`, `release`. The skill shows `steps`, and for each status it shows the coordinator's `hint` and offers the rerun that `wrap` supports. A rerun after a full wrap now exits 0 with `wrapped` and `nothing: true`, not 1, and the skill reports "nothing left to do". The skill also shows `otherBranches`, the pushed branches that `wrap` does not delete. The skill no longer runs `worktree finish`.
- **The safety rules stay.** The skill never commits `config/branches.json`. It offers `worktree remove --discard` only after the coach says the work should be dropped. It offers `release` after that drop, or to keep a branch that `wrap` kept when the coach chooses to keep it. It never runs a command only because `hint` names it.

## [0.1.0] - 2026-11-05

### Added

- **`/gvt-fleet:coach` skill.** The coach's entry point for the gvt-fleet multi-repo coordinator. It reads issues, shows the workers that need the coach and the ready issues, dispatches an issue on request, and wraps up a finished worker.
  - **Consumers:** it runs only in a session started at the root of a gvt-fleet workspace, and it needs the `gvt-dev` plugin.
  - New invocable skill → version bump at release.
