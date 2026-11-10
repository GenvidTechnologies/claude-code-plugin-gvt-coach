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
- **Changelog:** each new invocable skill adds an entry under `[Unreleased]` in `plugin/CHANGELOG.md` and needs a version bump at release. So does a contract bump (see "Coordinator contract").
- **License:** MIT-0.
- **No machine paths and no private names** in any file. `.github/scripts/leak-guard.sh` enforces this. Read the script for the blocked names, and do not copy them into a file.
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

An issue body says whether its change raises the contract number. It does not write the number as a literal. A literal goes stale when the CLI raises the number while the issue is open. Observed in triage on #7 and #8: both said the number "stays 1" while the skill already pinned 2.

An acceptance row that pledges "the contract number does not change" checks the branch diff, not the number:

```
git diff origin/main...HEAD -- plugin/skills/coach/SKILL.md | grep -E '^[-+][^-+]' | grep -c -E 'contract[^|]{0,6}[0-9]'
```

It prints 0 when no added or removed line pairs `contract` with a digit. Positive control: the same pipeline over `f841961`, the commit that raised the number (`git diff f841961~1 f841961 -- plugin/skills/coach/SKILL.md | …`), prints 4. Used on #7.

Every sentence in SKILL.md about what a CLI command returns or does has a source in the workspace's command reference. `wiki/coordinator.md` is its index, and each command's section is in a file under `wiki/coordinator/` (for example `wiki/coordinator/workers.md` for `status` and `watch`). Read these files from `main` of the workspace repository. `<workspace>` is its `owner/name`, the `origin` of the workspace checkout. The leak guard blocks the name, so this file does not write it.

```
gh api -H "Accept: application/vnd.github.raw" "repos/<workspace>/contents/wiki/coordinator/workers.md?ref=main"
```

Do not read them from a local checkout of the workspace. A checkout can be on another branch or behind `main`. Observed on #8: a local checkout still had the reference as one `docs/coordinator.md` of 944 lines, while `main` had split it into an index and ten files. The text of each section was the same, but the paths in this file and in SKILL.md no longer matched `main`. When the reference is silent, read the CLI code. When the code is silent too, leave the sentence out. No test compares SKILL.md with the CLI. Observed on #7: the code review found three sentences that said more than the reference. One had no source at all (the exit code of an older CLI for `--class`). One was true only by the CLI code (`class` removes the other label of an issue that carries both). One attached a half-way state to the wrong result.

A contract bump is a breaking change for consumers:

- The `[Unreleased]` section of `plugin/CHANGELOG.md` gets a `Changed` entry with a **Consumers** note that names the contract number the plugin needs.
- The release bumps at least the minor version.
- The plugin release ships first. The workspace moves its CLI to the new contract after the release. Until both move, the skill stops at the preflight.
