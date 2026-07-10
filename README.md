# Agent Relay

Agent Relay is a small CLI for delegating coding tasks to fresh agents. It keeps
each task scoped, runs independent tasks in parallel, and records a report and
diff for review.

## How it works

1. The orchestrator turns a goal into small tasks.
2. Each task declares the files it may change and any dependencies.
3. Relay starts fresh workers for tasks that do not overlap.
4. The orchestrator reviews each report and diff, then accepts or returns the
   task.

Fresh workers avoid carrying a long session history into every task. Indexed
project memory lets them load only the facts they need.

Workers share the project working tree. Their edits exist before review;
`accept` records approval but does not merge a patch. Workers declare exact
changed paths, and Relay fails tasks when those declarations do not match their
scoped diffs. It also blocks approval when a wave changes files outside its
scopes. Workers are cooperative processes, not hostile-code sandboxes. See
`SPEC.md` for the full behavior and limitations.

## Requirements

- Git
- Python 3.11+
- macOS or Linux
- A Git worktree without tracked submodules

Agent Relay uses only the Python standard library. Install it at the Git
worktree root; nested project directories are not supported. Scope checks and
diffs cover Git-visible worktree files only, so workers must not modify
Git-ignored files.

## Install the ready-to-use framework

```bash
git clone https://github.com/jpawchan/agent-relay
agent-relay/framework/relay init /path/to/project
```

Then:

1. Edit `.agent-relay/config.toml` if the default Hermes command does not fit
   your setup.
2. Tell your main coding agent to read `.agent-relay/orchestrator.md`.

Relay keeps its state in `.agent-relay/`, which is added to `.gitignore`.
Deleting that directory also deletes its tasks, reports, and memory.

## Basic flow

The orchestrator normally runs these commands for you:

```bash
.agent-relay/relay task create --title "Add email validation" --scope "src/auth/**"
.agent-relay/relay task create --title "Fix date formatting" --scope "src/reports/**"
.agent-relay/relay run --dry-run
.agent-relay/relay run
.agent-relay/relay task accept T001-add-email-validation
.agent-relay/relay task return T002-fix-date-formatting --reason "Missing edge case"
```

## Generate the framework from a prompt

`prompts/create-framework.md` is a standalone prompt that contains the complete
specification. Give it to a coding agent when you want the agent to build the
framework instead of copying the reference code.

After generation, give another agent `prompts/improve-framework.md` to test and
simplify the result. Both prompts target the same contract in `SPEC.md`.

## Repository

```text
framework/    ready-to-use CLI and agent manuals
prompts/      prompts to create, review, and activate the framework
skill/        skill metadata for compatible agents
tests/        dependency-free end-to-end tests
SPEC.md       framework contract
```

## License

MIT. See `LICENSE`.
