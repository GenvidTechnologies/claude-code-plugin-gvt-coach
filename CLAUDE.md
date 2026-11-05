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
- **Changelog:** each new invocable skill adds an entry under `[Unreleased]` in `plugin/CHANGELOG.md` and needs a version bump at release.
- **License:** MIT-0.
- **No machine paths and no private names** in any file. `.github/scripts/leak-guard.sh` enforces this. Read the script for the blocked names, and do not copy them into a file.
- **Skill names** are short nouns.
- **Decision records**, when the first one is needed, go in `docs/decisions/`. Version 0.1.0 ships none.

## Coordinator contract

The skill pins the `coach.contract` number that the gvt-fleet CLI reports. When the workspace raises that number, update the skill to match.
