# Changelog

All notable changes to the `gvt-fleet` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and follows [semantic versioning](https://semver.org/).

## [Unreleased]

### Added

- **Untriaged summary in the coach overview.** Step 3 of the overview now shows, for each repository, how many open issues are untriaged and how many the triaged label alone would make ready.
  - **Consumers:** the summary needs a workspace CLI whose `ready --json` reports `untriaged`. With an older CLI the overview says "not reported" and offers no triage pass. The coach contract stays at 1.
- **Triage pass.** The coach can name repositories from the summary. For each one, in turn, the skill runs `gvt-dev:triage-issues` in the repository's base clone. It checks the repository with `gh repo view`, tells the triage skill to put `--repo <owner/name>` on every `gh` command, runs it only in interactive mode, waits for the coach's approval of every tracker change, and writes no file in the base clone. Afterwards it runs `sync` and `ready` and reports how many of the picked issues became ready.

## [0.1.0] - 2026-11-05

### Added

- **`/gvt-fleet:coach` skill.** The coach's entry point for the gvt-fleet multi-repo coordinator. It reads issues, shows the workers that need the coach and the ready issues, dispatches an issue on request, and wraps up a finished worker.
  - **Consumers:** it runs only in a session started at the root of a gvt-fleet workspace, and it needs the `gvt-dev` plugin.
  - New invocable skill → version bump at release.
