# Changelog

All notable changes to the `gvt-fleet` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and follows [semantic versioning](https://semver.org/).

## [Unreleased]

### Added

- **`/gvt-fleet:coach` skill.** The coach's entry point for the gvt-fleet multi-repo coordinator. It reads issues, shows the workers that need the coach and the ready issues, dispatches an issue on request, and wraps up a finished worker.
  - **Consumers:** it runs only in a session started at the root of a gvt-fleet workspace, and it needs the `gvt-dev` plugin.
  - New invocable skill → version bump at release.
