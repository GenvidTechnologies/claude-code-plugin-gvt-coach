# claude-code-plugin-gvt-fleet

The **`gvt-fleet` plugin** for Claude Code. It provides one skill, `/gvt-fleet:coach`, the coach's entry point for the gvt-fleet multi-repo coordinator.

The skill reads issues from the managed repositories through the coordinator. It shows the workers that need the coach, the Now issues, the untriaged issues of each repository, and how many Next issues each repository has. It offers a triage pass over the repositories the coach picks. It lists the issues of one class, or moves an issue to another class, when the coach asks. It dispatches an issue to a worker on request. It wraps up a worker that has finished.

The plugin is distributed through the [`claude-code-gvt-marketplace`](https://github.com/GenvidTechnologies/claude-code-gvt-marketplace) catalog (marketplace name `gvt-plugins`).

## Requirements

- The skill runs only in a session started at the root of a gvt-fleet workspace. It reaches the coordinator through `${CLAUDE_PROJECT_DIR}`.
- The plugin depends on the `gvt-dev` plugin. Install `gvt-dev` first.

## Install

```text
/plugin marketplace add https://github.com/GenvidTechnologies/claude-code-gvt-marketplace.git
/plugin install gvt-fleet@gvt-plugins
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
