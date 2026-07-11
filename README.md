# Agent Relay

Agent Relay is a small delegation framework for coding agents.

You talk to one main agent. It acts as the orchestrator. It breaks your goal into
small tasks, and Relay starts a separate worker process for each ready task. The
orchestrator reviews the worker's report and Git diff before accepting the task.

Relay requires Python 3.11+, Git, macOS or Linux, and a command-line coding agent
for the workers. It uses no third-party Python packages.

## What is Agent Relay?

The orchestrator is your main coding agent. Relay is the tool it uses to keep
track of tasks and workers.

The orchestrator:

1. breaks your goal into small tasks;
2. gives each task a file scope, dependencies, and acceptance criteria;
3. asks Relay to start workers for the tasks that are ready;
4. reviews each report, Git diff, and test result;
5. accepts the work, returns it with feedback, or answers a worker's question.

Relay can run workers at the same time when their file scopes do not overlap.
The default worker is Hermes Agent. You can configure Claude Code, Codex,
OpenCode, or another non-interactive agent CLI that accepts a prompt or prompt
file.

Relay starts a separate process for every worker attempt. Whether that process
also starts a fresh model session depends on the worker CLI you configure.

## Why can it improve quality and reduce token use?

This can help with both, but not on every task.

### Quality

A long chat gets crowded. The model may still accept more tokens, but that does
not mean it can use every earlier detail equally well.

The exact limit is different for every model and task. There is no universal
100,000-token cutoff. The article
[Attention Decay](https://jpawchan.substack.com/p/attention-decay) explains what
usually goes wrong:

- facts in the middle of a long context are easier to miss;
- similar or conflicting information makes the right fact harder to find;
- old instructions lose influence as new messages arrive;
- finding one fact is easier than reasoning across many facts.

Relay gives each worker one task, its rules, and the project facts it needs. It
does not pass the orchestrator's whole conversation to every worker.

After a worker exits, Relay saves a Git diff. A worker asking for review must
also write a report and declare every changed path. The orchestrator can check
that work before accepting it.

This can make mistakes easier to spot. It cannot guarantee better code, honest
test results, or a good review.

### Token use

In one long session, completed work stays in the conversation. That old context
may be sent again with later requests even when the next task does not need it.

A Relay worker receives a short launch prompt that points to its task file,
worker rules, and selected project memory. It does not receive every previous
task and discussion.

This may reduce repeated input tokens on larger jobs. Relay also adds task
prompts, reports, and worker startup costs, so it can use more tokens on a small
job. Whether it saves tokens depends on the job and your setup.

### What about summarization?

Summarization helps after a conversation has already grown. It is also lossy.
Details left out of the summary may be needed later.

Delegation avoids putting the full history into each worker session in the first
place. Each task has its own task file and state. Worker attempts can have their
own prompt, log, report, result, and diff.

Relay does not summarize or compact the orchestrator's whole chat. Each worker
writes a task report, and the orchestrator reads the reports it needs.

You can still use summarization and Relay together.

## Requirements

### Generate the framework from a prompt

You do not need Agent Relay installed already.

You need:

- a coding agent that can create files and run commands;
- a Git project;
- Python 3.11+ on macOS or Linux so the generated framework can be tested.

Give the agent [`prompts/create-framework.md`](prompts/create-framework.md).
Then give [`prompts/improve-framework.md`](prompts/improve-framework.md) to a
fresh agent to check the implementation and run the tests.

This uses more tokens once. A newer model may produce a better implementation,
but the result still needs to pass the review prompt and tests.

### Use the ready-to-run framework

You need:

- Git;
- Python 3.11 or newer;
- macOS or Linux;
- a Git worktree without tracked submodules;
- a non-interactive coding-agent CLI for workers.

Relay itself uses the Python standard library. The worker CLI has its own
installation, account, and model requirements.

## Install

### Install with the prompts

1. Give `prompts/create-framework.md` to a coding agent in your project.
2. Let it create and test `.agent-relay/`.
3. Give `prompts/improve-framework.md` to a fresh agent.
4. Ask your main agent to read `.agent-relay/orchestrator.md`.

### Install the ready-to-run version

```bash
git clone https://github.com/jpawchan/agent-relay
agent-relay/framework/relay init /path/to/project
```

Then ask your main coding agent to read:

```text
/path/to/project/.agent-relay/orchestrator.md
```

Edit `/path/to/project/.agent-relay/config.toml` if you want to change the
worker command or limits.

Relay adds `.agent-relay/` to the project's `.gitignore`. That folder contains
the local tasks, reports, diffs, logs, and memory. Deleting it deletes that local
state.

## How to use it

1. Install Relay at the root of your Git project.
2. Tell your main coding agent to act as the orchestrator and read
   `.agent-relay/orchestrator.md`.
3. Describe the coding goal.
4. The orchestrator creates small tasks with file scopes and dependencies.
5. It previews the next worker wave and runs it.
6. Relay waits for the workers and saves their reports and diffs.
7. The orchestrator reviews each task and accepts it, returns it, or answers a
   question.
8. Repeat until the goal is complete, then archive finished tasks.

You normally talk to the orchestrator and let it run the commands. A short manual
example is:

```bash
.agent-relay/relay task create --title "Add email validation" --scope "src/auth/**"
.agent-relay/relay run --dry-run
.agent-relay/relay run
.agent-relay/relay task accept T001-add-email-validation --note "Reviewed"
```

## Functions

Every user-facing function is a CLI command.

| Command | What it does |
| --- | --- |
| `relay init [PATH]` | Install Relay at a Git worktree root. |
| `relay task create` | Create a task with a scope, dependencies, and optional worker tier. |
| `relay task list` | List active tasks and their status. |
| `relay task show ID` | Show one active or archived task as JSON. |
| `relay run --dry-run` | Preview the next worker wave without starting it. |
| `relay run [ID...]` | Run one ready wave and save worker artifacts. |
| `relay task finish ID` | Submit a worker status and exact changed paths. |
| `relay task accept ID` | Mark reviewed work as done. |
| `relay task return ID` | Return work with feedback and queue another attempt. |
| `relay task decide ID` | Answer a worker question and queue another attempt. |
| `relay task cancel ID` | Cancel a task. |
| `relay task unlock ID` | Mark a dead worker's stale task as failed. |
| `relay status` | Show task counts, active workers, and tasks needing attention. |
| `relay validate` | Check the config, Git project, tasks, dependencies, and worker leases. |
| `relay archive` | Move done and cancelled task files into the local archive. |
| `relay memory index/show/add` | List, read, or add small project-memory entries. |

Run `.agent-relay/relay <command> --help` for all arguments.

## What is in this repository?

| Path | What it contains |
| --- | --- |
| `framework/` | The ready-to-run Relay CLI, config example, and agent instructions. |
| `prompts/create-framework.md` | A prompt that asks an agent to build Relay from the specification. |
| `prompts/improve-framework.md` | A prompt that checks, tests, and fixes a generated implementation. |
| `prompts/use-framework.md` | A short prompt that tells an agent to use installed Relay. |
| `skill/` | Skill metadata for agent systems that support skills. |
| `tests/` | End-to-end tests built with Python's standard library. |
| `SPEC.md` | The exact behavior and safety rules. |
| `summary.md` | A code-verified project guide for coding agents. |

## Limits

- Workers share one Git working tree. Relay is not a security sandbox.
- Worker edits already exist before approval. `accept` records the decision; it
  does not apply a patch.
- Scope checks cover files visible to Git. They do not cover Git-ignored files.
- Tracked Git submodules are not supported.
- A fresh model session depends on the worker CLI.
- Relay can require reports and check diffs. It cannot guarantee that the code,
  tests, or review are good.

See [`SPEC.md`](SPEC.md) for the exact rules.

## License

MIT. See [`LICENSE`](LICENSE).
