# Agent Relay

Agent Relay is a small, dependency-free CLI for delegating scoped coding tasks
to fresh agents. It runs independent work in parallel and gives the orchestrator
a report and Git diff to review before approval.

It is designed to keep model contexts focused. This can improve reliability and
reduce repeated input tokens, but it does not guarantee better code or lower
costs.

## What is Agent Relay?

You work with one orchestrator agent. The orchestrator:

1. turns your goal into small tasks;
2. gives each task a file scope, dependencies, and acceptance criteria;
3. starts a fresh worker process for each ready task;
4. runs workers in parallel when their scopes do not overlap;
5. reviews each worker's report, diff, and test evidence;
6. accepts the task, returns it with feedback, or answers a blocking question.

The default worker command uses Hermes Agent. You can configure any
non-interactive CLI agent that accepts a prompt argument, such as Codex or
Claude Code. Agent Relay coordinates those tools; it is not tied to a model or
provider.

## Why fresh workers help

A model's advertised context window is not a promise that every token remains
equally useful. As context grows, relevant facts become harder to retrieve,
instructions compete with newer text, and multi-step reasoning can degrade long
before the context window is full. The exact point varies by model and task.

[Attention Decay](https://jpawchan.substack.com/p/attention-decay) explains the
research and practical symptoms, including lost-in-the-middle retrieval,
attention dilution, and prompt fade.

Agent Relay follows a simple pattern: one focused task, one worker invocation. A
worker receives a short launch prompt pointing to its task specification, worker
contract, and any referenced project memory instead of the orchestrator's full
conversation. Completed work stays in task reports and state files rather than
being copied into every later worker context.

This can help in two ways:

- **Quality:** shorter, task-specific contexts make constraints and relevant
  evidence easier for a worker to use. Reports and diffs also provide an
  explicit review step before approval.
- **Token use:** later workers do not repeatedly receive the full history of
  completed tasks. Savings depend on the agent, provider pricing, prompt
  caching, and how the orchestrator manages its own session.

### Delegation and summarization

Summarization compresses an existing long conversation. It is useful, but it is
lossy: omitted details may matter later, and one summary still mixes unrelated
work.

Delegation avoids building that history inside each worker session. Every task
has its own specification, report, result, log, and diff. The orchestrator keeps
the high-level view and loads only the project facts needed for the next task.
Summaries and delegation complement each other; Agent Relay does not control or
automatically compact the orchestrator's chat history.

## Requirements

### To generate the framework from a prompt

You need a coding agent that can create files and run commands in the target
repository. Give it `prompts/create-framework.md`; no existing Agent Relay
installation is required.

The generated framework still targets the runtime requirements below. Use a
fresh reviewer with `prompts/improve-framework.md` afterward to test the result
against the same specification.

### To use the ready-to-run framework

- Git
- Python 3.11 or newer
- macOS or Linux
- A Git worktree root without tracked submodules
- A non-interactive coding-agent CLI for workers

Agent Relay itself uses only the Python standard library. Worker agents may have
their own requirements.

## Install

### Generate it from the prompt

1. Give `prompts/create-framework.md` to a coding agent in your project.
2. Let the agent create and test `.agent-relay/`.
3. Give `prompts/improve-framework.md` to a fresh agent for an independent
   implementation review.
4. Ask your main agent to read `.agent-relay/orchestrator.md`.

This costs more tokens once, but lets a newer model produce an implementation
from the normative specification.

### Install the ready-to-run framework

```bash
git clone https://github.com/jpawchan/agent-relay
agent-relay/framework/relay init /path/to/project
```

Then edit `/path/to/project/.agent-relay/config.toml` if needed and ask your main
coding agent to read `.agent-relay/orchestrator.md`.

Initialization adds `.agent-relay/` to the project's `.gitignore`. The directory
contains all local tasks, reports, diffs, logs, and memory; deleting it deletes
that state.

## How to use it

1. Install Agent Relay at the Git worktree root.
2. Tell your main coding agent to act as the orchestrator and read
   `.agent-relay/orchestrator.md`.
3. Describe the coding goal as usual.
4. The orchestrator creates scoped tasks and previews the next parallel wave.
5. Relay launches ready workers and waits for them to finish.
6. The orchestrator reviews each report, diff, and verification result.
7. The orchestrator accepts good work, returns incomplete work with feedback, or
   answers worker questions.
8. Run another wave until the goal is complete, then archive finished tasks.

A minimal manual flow looks like this:

```bash
.agent-relay/relay task create --title "Add email validation" --scope "src/auth/**"
.agent-relay/relay run --dry-run
.agent-relay/relay run
.agent-relay/relay task accept T001-add-email-validation --note "Reviewed"
```

Normally the orchestrator runs these commands for you.

## Commands

| Command | Purpose |
| --- | --- |
| `relay init [PATH]` | Install Agent Relay at a Git worktree root. |
| `relay task create` | Create a scoped task with optional dependencies and a worker tier. |
| `relay task list` | List active tasks and their states. |
| `relay task show ID` | Print one active or archived task as JSON. |
| `relay run --dry-run` | Preview the next non-overlapping worker wave. |
| `relay run [ID...]` | Run one ready wave and capture reports, logs, results, and diffs. |
| `relay task finish ID` | Let a leased worker submit its status and exact changed paths. |
| `relay task accept ID` | Mark reviewed work as done. |
| `relay task return ID` | Queue another attempt with review feedback. |
| `relay task decide ID` | Answer a worker question and queue another attempt. |
| `relay task cancel ID` | Cancel work that is no longer needed. |
| `relay task unlock ID` | Mark a stale, no-longer-running worker as failed. |
| `relay status` | Show task counts, running workers, and tasks needing attention. |
| `relay validate` | Check configuration, Git state, task state, dependencies, and leases. |
| `relay archive` | Move done and cancelled task artifacts into the local archive. |
| `relay memory index/show/add` | Store and retrieve small, durable project facts by audience. |

Run `.agent-relay/relay <command> --help` for complete arguments.

## What is in this repository?

| Path | Contents |
| --- | --- |
| `framework/` | Ready-to-run CLI, configuration, and agent manuals. |
| `prompts/create-framework.md` | Standalone prompt containing the complete framework specification. |
| `prompts/improve-framework.md` | Independent review and improvement prompt. |
| `prompts/use-framework.md` | Short prompt that activates an installed orchestrator. |
| `skill/` | Skill metadata for compatible agent systems. |
| `tests/` | Dependency-free end-to-end tests using temporary Git projects. |
| `SPEC.md` | Normative behavior, safety rules, and limitations. |

## Limits

- Workers share one Git working tree and run as the same operating-system user;
  Agent Relay is coordination, not a security sandbox.
- Worker edits already exist before approval. `accept` records review; it does
  not apply a patch.
- Scope enforcement covers Git-visible files. Git-ignored files are outside its
  guarantees.
- Tracked Git submodules are unsupported.
- A fresh model context depends on the configured worker command starting a new
  session rather than resuming an old one.
- Agent Relay provides reports, diffs, and lifecycle checks, but the
  orchestrator is responsible for performing a competent review.

See [`SPEC.md`](SPEC.md) for the exact contract.

## License

MIT. See [`LICENSE`](LICENSE).
