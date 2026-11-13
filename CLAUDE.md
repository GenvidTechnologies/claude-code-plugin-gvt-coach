# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Purpose

This repository is the **`gvt-fleet` plugin** for Claude Code. It ships one skill, `/gvt-fleet:coach`, the coach's entry point for the gvt-fleet multi-repo coordinator. The skill runs only in a session started at the root of a gvt-fleet workspace, and it depends on the `gvt-dev` plugin. The plugin is published through the `claude-code-gvt-marketplace` catalog (marketplace name `gvt-plugins`).

## Layout

| Path | Content |
|---|---|
| `plugin/.claude-plugin/plugin.json` | Plugin manifest. Its `version` is the plugin version. |
| `plugin/skills/<name>/SKILL.md` | One directory per skill. |
| `plugin/CHANGELOG.md` | Versioned consumer surface. |
| `docs/decisions/` | Decision records, `NNNN-kebab-title.md`. |
| `.github/scripts/leak-guard.sh` | Blocks machine paths and private names. |
| `.github/workflows/leak-guard.yml` | Runs the leak guard in CI. |
| `.gvt-agent.json` | Command registry for gvt-dev skills. |
| `README.md`, `LICENSE` | Public description and MIT-0 license. |

## Validate

`commands.validate` in `.gvt-agent.json` is the validation command. It runs the leak guard and then `claude plugin validate plugin`. Run it before every commit.

## Conventions

- **Commits:** `<scope>: <description>`.
- **Branches:** kebab-case.
- **Merges:** squash merge only.
- **Tags:** `v<semver>`, annotated, and equal to the `version` in `plugin.json`.
- **Changelog:** each new invocable skill adds an entry under `[Unreleased]` in `plugin/CHANGELOG.md` and needs a version bump at release. So does a contract bump (see "Coordinator contract"). An issue that proposes "a skill" says whether it means a new invocable skill or a mode of `/gvt-fleet:coach`. A new skill has a changelog entry, a version bump and a short noun as its name, and it changes the README sentence that says the plugin provides one skill. Observed in triage on #34: "a wrap skill" could mean either, and the coach left the choice to the plan (#37, #38).
- **License:** MIT-0.
- **No machine paths and no private names** in any file. `.github/scripts/leak-guard.sh` enforces this. Read the script for the blocked names, and do not copy them into a file. The rule also holds for issue and pull request bodies, which no check reads. This repository is public and the workspace repository is private. A body that depends on a workspace issue describes it in prose, and the workspace issue links back to this repository. Observed in triage on #29: the split issue #30 is blocked by a workspace issue and names it only in prose.
- **README:** `README.md` summarises what the overview and each mode show. A change to what they show also updates that summary, in the same commit. No check ties the two together. Observed on #7: the overview changed, and only the code review found the stale README sentence.
- **Skill names** are short nouns.
- **Decision records** go in `docs/decisions/`, numbered `NNNN-kebab-title.md`. Version 0.1.0 ships none. The first record is 0001. An issue body does not write the number of a record it proposes. It says "a decision record in `docs/decisions/`", and the record takes the next free number when it is written. A literal goes stale when another record lands while the issue is open, as for the contract number (see "Coordinator contract"). Observed in triage on #18: the body proposed `0002`.

## Coordinator contract

The skill pins the `coach.contract` number that the gvt-fleet CLI reports. When the workspace raises that number, update the skill to match.

The skill reads the keys in the CLI's contract table (the workspace's `wiki/coordinator/coach-skill-contract.md`). Sometimes the skill needs a result key that the table does not list for that command. Then:

- The skill reads the key and treats a missing key as "not reported", as for any key.
- The skill's own contract table lists the key.
- An issue goes to the workspace repository, asking to list the key in the table and pin it in the CLI's contract test. Adding a key does not raise the contract number.

Observed on #6: the `wrap` result carries `branchRecord`, which the skill needs for rule 5, but the CLI's `wrap` row did not list it.

A CLI change that the skill adopts can also make `docs/issue-triage.md` stale, for example its Class section and its "Set coordinator class" recipe. An issue that adopts such a change names both files. No check compares the triage contract with the CLI. Observed in triage on #29: the body named only `SKILL.md`, and the triage contract still said that labels keep the class (fixed in #31).

An issue body says whether its change raises the contract number. It does not write the number as a literal. A literal goes stale when the CLI raises the number while the issue is open. Observed in triage on #7 and #8: both said the number "stays 1" while the skill already pinned 2.

An issue that asks the skill to read a key names the results after which the skill reads it. Take that set from the command reference, which says on which results the key is present. Observed in triage on #22: the body read `checkedOutBranch` only after `wrapped`, while the reference says the key is always present on a `wrap` result, so a `branch-kept` result can also report a kept branch.

An acceptance row that pledges "the contract number does not change" checks the branch diff, not the number. It compares the contract fragments on the removed lines with those on the added lines:

```
git diff origin/main...HEAD -- plugin/skills/coach/SKILL.md | grep -E '^-[^-]' | grep -o -E 'contract[^|]{0,6}[0-9]+'
git diff origin/main...HEAD -- plugin/skills/coach/SKILL.md | grep -E '^[+][^+]' | grep -o -E 'contract[^|]{0,6}[0-9]+'
```

The number is unchanged when both commands print the same lines, or nothing. Controls, over one commit each (`git diff <c>~1 <c> -- plugin/skills/coach/SKILL.md | …`):

| Commit | Removed lines | Added lines |
|---|---|---|
| `f841961`, which raised the number | `contract 1`, `contract: 1` | `contract 2`, `contract: 2` |
| `e664c32`, a path fix on the line that holds the number | `contract: 2` | `contract: 2` |

A commit that adds a new mention of the current number also prints a difference. Read the diff in that case.

An earlier form of this check counted the added and removed lines that pair `contract` with a digit, and expected 0. It counts a changed line, not a changed number. Observed on #15: the path fix in `e664c32` made it print 2 while the number stayed the same.

Every sentence in SKILL.md about what a CLI command returns or does has a source in the workspace's command reference. `wiki/coordinator.md` is its index, and each command's section is in a file under `wiki/coordinator/` (for example `wiki/coordinator/workers.md` for `status` and `watch`). Read these files from `main` of the workspace repository. `<workspace>` is its `owner/name`, the `origin` of the workspace checkout. The leak guard blocks the name, so this file does not write it.

```
gh api -H "Accept: application/vnd.github.raw" "repos/<workspace>/contents/wiki/coordinator/workers.md?ref=main"
```

Do not read them from a local checkout of the workspace. A checkout can be on another branch or behind `main`. Observed on #8: a local checkout still had the reference as one `docs/coordinator.md` of 944 lines, while `main` had split it into an index and ten files. The text of each section was the same, but the paths in this file and in SKILL.md no longer matched `main`. When the reference is silent, read the CLI code. When the code is silent too, leave the sentence out. No test compares SKILL.md with the CLI. Observed on #7: the code review found three sentences that said more than the reference. One had no source at all (the exit code of an older CLI for `--class`). One was true only by the CLI code (`class` removes the other label of an issue that carries both). One attached a half-way state to the wrong result.

A change that touches several command groups reads every file under `wiki/coordinator/`, not one. Fetch them with a `.mjs` script in the session's scratch folder that lists the folder (`repos/<workspace>/contents/wiki/coordinator?ref=main`) and calls `gh` once for each file through `execFileSync`. A shell `for` loop over `gh api` is refused in a worktree-isolated session. Observed on #4.

An issue body's command syntax and ordering are proposals. The command reference on `main` decides. When they differ, follow the reference and say so in the pull request. The `--json` output can have another shape than the text output. For example, the text output of `status` sorts issue workers and task workers into one list, but `status --json` keeps them in two arrays, `workers` and `tasks`. Observed on #4: the body wrote the task name as optional (`[name]`), while `dispatch --task` requires the slug, and it asked for task rows "in the order `status` gives", which the JSON does not define across the two arrays.

A contract bump is a breaking change for consumers:

- The `[Unreleased]` section of `plugin/CHANGELOG.md` gets a `Changed` entry with a **Consumers** note that names the contract number the plugin needs.
- The release bumps at least the minor version.
- The plugin release ships first. The workspace moves its CLI to the new contract after the release. Until both move, the skill stops at the preflight.
