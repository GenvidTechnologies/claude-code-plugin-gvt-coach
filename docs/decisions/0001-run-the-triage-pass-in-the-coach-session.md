# 0001. Run the triage pass in the coach session

- **Status:** accepted
- **Date:** 2026-11-06
- **Issue:** #3

## Context

An issue without the triaged label is never ready, so the coach overview did not show it. The overview now summarizes untriaged issues per repository and offers a triage pass (#3 has the background).

`gvt-dev:triage-issues` triages one repository at a time. It reads the triage contract and the `.gvt-agent.json` of the repository root it runs in. Its example `bugTracker` block, and this repository's own, use plain `gh issue ...` commands with no `--repo`. Run from the workspace root, such commands would read and write the workspace's own repository, and a label could land on the wrong issue with the same number. A subagent that the session starts begins in the folder of the session's last `cd`, as long as that folder is inside the session's working folders. A later `cd` can move it, so a `cd` alone does not fix this. The skill is interactive, and every tracker change waits for the coach's approval.

## Decision

The triage pass runs in the coach session, one repository at a time, from that repository's base clone in the workspace (`repos/<owner>/<name>`). The decision has three parts:

- **Wrong-repository guard.** Before it starts `gvt-dev:triage-issues`, the skill confirms that `gh repo view --json nameWithOwner --jq .nameWithOwner` prints the target `owner/name`. It requires `--repo <owner/name>` on every `gh` command of the pass, the analyst subagent's included.
- **No file writes in a base clone.** The skill declines any offer to create or change a file there. If triage cannot go on without the file, the skill stops that repository and reports that it needs a triage contract change through a normal pull request. The coordinator skips a dirty base clone and `dispatch` refuses one. After each repository the skill checks that `git status --porcelain` prints nothing.
- **Approval.** The skill never applies a triage change by itself, and it runs `gvt-dev:triage-issues` only in interactive mode.

## Compromise

The rejected alternative is a worker session per repository. It keeps the coach's context small, because one repository's issue corpus would not fill it. It needs a dispatch form that is not tied to one issue, and that form is not built. The accepted cost is that each repository's corpus fills the coach's context while it is triaged. One repository at a time limits that cost.

## Consequences

- The coach can triage from the overview with no new coordinator command.
- A long pass uses coach context. The coach can stop after any repository.
- A repository that has no triage contract cannot be triaged by this pass. It needs a pull request first. The pass declines the light-touch groom of `gvt-dev:triage-issues`, because the groom does not add the triaged label and so does not change readiness.
- Revisit this decision when task dispatch exists, that is, a dispatch form that starts a worker session without one issue. A worker per repository then becomes possible.
