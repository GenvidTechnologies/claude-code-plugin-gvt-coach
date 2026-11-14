# Issue Triage Conventions

> Project conventions consumed by `/gvt-dev:triage-issues`. The skill copies this
> file to the contract path `.gvt-agent.json` resolves for `docs/issue-triage.md`; edit it for your tracker. The companion **access
> mechanics** (fetch queries, label names) live in the `bugTracker` block of
> `.gvt-agent.json` — see the skill's SKILL.md for that block.
>
> This is the **flat-label variant** — for repos using a simple category-label set
> (e.g. GitHub's defaults: `bug`, `enhancement`, `documentation`, `duplicate`,
> `question`, `wontfix`) with **no** `type:`/`priority/`/`area:` scheme. If your repo
> uses a structured taxonomy, copy `issue-triage.template.md` instead.
>
> The example commands below assume **GitHub Issues via the `gh` CLI**. Replace
> them with your tracker's equivalents; the section headings must stay the same —
> the skill and analyst locate guidance by heading.

## Types

A single category label per issue, drawn from the existing flat set:

- `bug` — incorrect behavior in shipped functionality.
- `enhancement` — a new feature or improvement request.
- `documentation` — a docs-only gap or fix.
- `question` — a request for information or clarification (doubles as the
  needs-info signal — see Required fields).

Set exactly one category label. Add new categories only if the repo already uses
them — never invent a taxonomy the repo doesn't have.

## Priorities

**This repo has no priority labels.** Don't invent a `priority/*` scheme. When
ordering work, rank by recency and observable impact in discussion rather than a
label — a triaged issue carries no priority field. (If the repo later adopts
priority labels, switch to the structured template.)

## Class

Each open issue has a class: Now, Next or Later. Two places store it, and a
triage pass sets both:

- **The Iteration field of the `gvt-plugins` project** (organization project 1).
  The gvt-fleet coordinator derives the class from it: the current iteration is
  Now, the first iteration that starts after today is Next, and every other
  iteration is Later. So is an item with no iteration, and an issue that is not
  in the project. The coach overview reads only this class. Only the
  coordinator's `class` command writes it. The coordinator no longer reads or
  writes the labels `class:now` and `class:next` (its ADR 0015).
- **The Class field of the `gvt-plugins` project.** It is a single-select field
  with the options Now, Next, Later and Done. The coach overview does not read
  it, and the coordinator does not write it.

The two stores are not linked. When only one is set, they can disagree, and the
coach overview shows the Iteration class. Observed in the triage of #25: the
brief asked for "the project Class", and only the Class field was set. Both
stores said Later, so nothing was lost. A Next class set that way would not
have reached the overview.

Next can be set only when the project has a next iteration. Without one,
`class` refuses `next`. Observed in the triage of #29: project 1 had a current
iteration and no next one.

Propose a class for each triaged issue. The proposal defaults to Later. Set it
only with the coach's approval, through the recipes "Set coordinator class" and
"Set project Class".

For Later on an issue that is not in the project, run only "Set project Class".
`class later` does not add the issue to the project, and an issue with no
iteration is already Later. Done in the triage of #39 and #40.

## Labels

- category — exactly one of `bug` / `enhancement` / `documentation` / `question`.
- `duplicate` — set on non-canonical members of a duplicate cluster.
- `question` — also used to flag missing info (see Required fields); cleared when
  supplied.
- `wontfix` — set only with explicit approval when an issue is closed as out of scope.
- `triaged` — set **last**, by the skill, when triage is complete.
- No class label. The coordinator keeps the class in the project Iteration
  field (see Class). The labels `class:now` and `class:next` are no longer read
  or written; do not set them.

The triager sets the category label. Reporters may suggest one.

## Required fields

Every triaged issue should have enough to act on: for a `bug`, a reproduction
(steps or a failing case) plus expected vs. actual behavior and the build/version;
for an `enhancement`, a clear statement of the desired outcome and motivation.
Missing the essentials → add the **`question`** label and comment exactly what is
needed. (This repo has no dedicated `needs-info` label; `question` serves that
role — match the `needsInfoLabel` in the `bugTracker` block to it.)

An acceptance row that a background worker cannot check ends with
`(interactive)`. Examples: a row that needs an interactive Claude Code session,
or a row that needs the user present. A worker that cannot check such a row
reports it as not verified in the pull request and leaves its box unticked. The
issue then closes with that row open, so the pull request names who checks it.
Observed on #8: the row "A Monitor line starts a new turn in an interactive
coach session" went to a background worker, and the issue closed on merge with
the row unchecked.

An issue names the file it changes and quotes the sentence to change. It does
not give a line number. A line number goes stale when another change lands in
the file while the issue is open. Observed on #15: the body cited
`SKILL.md:296`, and one merged pull request later the sentence was at line 375.

An issue names the repository that owns each part it changes. The coordinator
owns its default prompts and its result keys. The skill owns only the arguments
it passes and the keys it reads. Observed in triage on #34: the body put "the
dispatch prompt guidance" in this repository, and it called the coordinator's
default "the default dispatch prompt". The skill passes no prompt by default,
so the change needed either a CLI change or a prompt that the skill composes.
The coach chose the composed prompt (#37).

An issue that moves or renames a file that a gvt-dev skill reads names the
`.gvt-agent.json` `paths` key the skill finds it by, and that key's default.
Observed in triage on #33: the body said to repoint the `paths` keys that name
`docs/`, but the only key was `plugin_root`. gvt-dev 5.0.0 finds the triage
contract through `paths['docs/issue-triage.md']` and the decision records
through `paths['docs/decisions/']`, so the move must add both keys.

## Splitting

Split when one issue bundles unrelated concerns, or when a single piece of work
spans parts that ship independently. Prefer **sub-issues** (a task-list of
checkboxes referencing new issues) when the parent is a tracking umbrella; prefer
**separate issues** when the parts share no parent. Keep the original as the
canonical/umbrella and move each split-out concern's detail into its own issue.

When new issues refer to each other, file first the one whose body has no
number to fill in. The others can then carry its number, and no issue needs an
edit after it is filed. Observed in the triage of #29: the split issue #30
named its workspace blocker in prose, so it went first, and the workspace
issue was filed with #30 already in its body.

## Duplicates

Policy: **link, do not auto-close.** For a duplicate cluster, choose the canonical
(usually the oldest with the best detail), add `duplicate` to the others, and
comment `Duplicate of #<canonical>` on each. Close a duplicate only with explicit
per-item approval.

## Dependencies

Express a dependency with a comment on the blocked issue: `Blocked by #<id>`
(optionally `Blocks #<id>` on the other). For umbrellas, list dependencies as a
GitHub task-list under a `Depends on` heading.

## Mutation recipes

The exact commands the triage skill runs to apply **approved** changes. `{id}`,
`{type}`, `{otherTypes}`, `{canonical}`, `{other}`, `{title}`, `{tmpfile}`,
`{triagedLabel}`, `{needsInfoLabel}`, and `{closeReason}` are substituted by the skill. (There are
no `{p}`/`{a}` substitutions — this repo has no priority or area labels.)

When a recipe's set would be empty, omit its --remove-label flag.

{otherTypes} is the set of category labels, written out in full, with the label being added removed.

- Set category: `gh issue edit {id} --add-label "{type}" --remove-label "{otherTypes}"`
- Check a body before any write that posts it (Edit body, Comment, Create split issue): `grep -n -i -E '<pattern>' {tmpfile}`, where `<pattern>` is the `always` pattern of `.github/scripts/leak-guard.sh`. When the write also sets a title (Edit body with a new title, Create split issue), check the title too: `printf '%s\n' "{title}" | grep -n -i -E '<pattern>'`. Any output blocks the write. The leak guard reads only tracked files, so it never sees an issue title or body. Observed in the triage of #40: the body as filed named the private workspace issue and pull request, and the rewrite named them in prose. Observed in the triage of #45: the title as filed named the private workspace repository too, and the new title names the decision record only as the coordinator's.
- Edit body (language fix / fill missing info): `gh issue edit {id} --body-file {tmpfile}` — the skill writes the approved new body to `{tmpfile}` first
- Comment: `gh issue comment {id} --body-file {tmpfile}` — the skill writes the comment text to `{tmpfile}` first
- Flag missing info: `gh issue edit {id} --add-label {needsInfoLabel}` (i.e. `question`; pair with a Comment saying what's missing)
- Clear missing-info flag: `gh issue edit {id} --remove-label {needsInfoLabel}`
- Mark duplicate: `gh issue edit {id} --add-label duplicate` then `gh issue comment {id} --body "Duplicate of #{canonical}"`
- Close duplicate (only with approval): `gh issue close {id} --reason "not planned" --comment "Duplicate of #{canonical}"`
- Close as completed or not planned (only with approval): `gh issue close {id} --reason "{closeReason}"` — post the reason first through the Comment recipe; `{closeReason}` is `completed` or `not planned`
- Create split issue: `gh issue create --title "{title}" --body-file {tmpfile} --label "{type}"` — the skill writes the drafted split body to `{tmpfile}` first
- Link dependency: `gh issue comment {id} --body "Blocked by #{other}"`
- Set coordinator class: `node bin/gvt-fleet.mjs --json class {ref} {class}`, run at the root of the gvt-fleet workspace. `{ref}` is the issue's `owner/name#{id}`, and `{class}` is `now`, `next` or `later` in lowercase. For `now` or `next` the command adds the issue to the project when it is not in it, and puts its item in the current or the next iteration. For `later` it clears a Now or Next value; it does not add an issue to the project. It reads the value back, and writes the coordinator's cache when the readback agrees and `sync` has read the project. A result with `status` `noop` means that the issue already had the class. A result with `status` `refused` and exit 1 is a closed issue, a project with no Iteration field, or `now` or `next` when the project has no current or no next iteration.
- Set project Class, in three steps:
  1. Add the issue to the project: `gh project item-add 1 --owner GenvidTechnologies --url {url} --format json --jq .id`. The output is `{itemId}`. For an issue that is already in the project, read `{itemId}` from the `projectItems` of the issue instead: `gh api graphql -f query='query{repository(owner:"GenvidTechnologies",name:"claude-code-plugin-gvt-fleet"){issue(number:{id}){projectItems(first:5){nodes{id project{number}}}}}}'`, and take the `id` of the node whose `project.number` is 1. Run "Set coordinator class" first: for `now` or `next` it adds the issue to the project. Checked in the triage of #29.
  2. Look up the ids: `gh api graphql -f query='query{organization(login:"GenvidTechnologies"){projectV2(number:1){id field(name:"Class"){... on ProjectV2SingleSelectField{id options{id name}}}}}}'`. `{projectId}` is `projectV2.id`, `{fieldId}` is `field.id`, and `{optionId}` is the `id` of the option whose `name` is the class. Look the ids up on each run: rebuilding the options of the field gives new option ids.
  3. Set the field: `gh project item-edit --project-id {projectId} --id {itemId} --field-id {fieldId} --single-select-option-id {optionId}`. The command prints nothing on success.
- Read back the project Class: `gh api graphql -f query='query{repository(owner:"GenvidTechnologies",name:"claude-code-plugin-gvt-fleet"){issue(number:{id}){projectItems(first:5){nodes{project{title} fieldValueByName(name:"Class"){... on ProjectV2ItemFieldSingleSelectValue{name}}}}}}}'`
- Stamp triaged: `gh issue edit {id} --add-label {triagedLabel}`

Read the labels back after this edit: confirm the issue now carries exactly the intended labels before it is stamped triaged (use the tracker's read-one query, or the native issue view).
