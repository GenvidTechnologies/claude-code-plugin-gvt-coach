# claude-code-plugin-gvt-coach

The **`gvt-coach` plugin** for Claude Code. It provides one skill, `/gvt-coach:coach`, the coach's entry point for the gvt-loop multi-repo coordinator.

The skill reads issues from the managed repositories through the coordinator. It shows the workers that need the coach and the issues that are ready. It dispatches an issue to a worker on request. It wraps up a worker that has finished.

The plugin is distributed through the [`claude-code-gvt-marketplace`](https://github.com/GenvidTechnologies/claude-code-gvt-marketplace) catalog (marketplace name `gvt-plugins`).

## Requirements

- The skill runs only in a session started at the root of a gvt-loop workspace. It reaches the coordinator through `${CLAUDE_PROJECT_DIR}`.
- The plugin depends on the `gvt-dev` plugin. Install `gvt-dev` first.

## Install

```text
/plugin marketplace add https://github.com/GenvidTechnologies/claude-code-gvt-marketplace.git
/plugin install gvt-coach@gvt-plugins
```

Enable the plugin at user scope.

## Load for development

Clone this repository and start Claude Code with the plugin folder:

```text
claude --plugin-dir <clone>/plugin
```

## Contributing

Read [`CLAUDE.md`](CLAUDE.md) for the layout, the conventions and the validation command.

## License

MIT-0. See [`LICENSE`](LICENSE).
