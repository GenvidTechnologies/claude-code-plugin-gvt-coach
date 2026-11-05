# Changelog

All notable changes to the `gvt-coach` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and follows [semantic versioning](https://semver.org/).

## [Unreleased]

### Added

- **`/gvt-coach:coach` skill.** The coach's entry point for the gvt-loop multi-repo coordinator. It reads issues, shows the workers that need the coach and the ready issues, dispatches an issue on request, and wraps up a finished worker.
  - **Consumers:** it runs only in a session started at the root of a gvt-loop workspace, and it needs the `gvt-dev` plugin.
  - New invocable skill → version bump at release.
