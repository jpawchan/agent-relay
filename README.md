# Agent Orchestra

Agent Orchestra is a prompt-first, agentic skill/spec for building lightweight orchestrator/worker delegation frameworks inside coding projects.

It is designed for people who want higher code quality from coding agents while controlling token usage. The core pattern is simple:

- one orchestrator talks to the human and remains final authority
- one worker runs at a time
- workers get fresh, small contexts
- tasks are explicit and scoped
- workers report compactly
- the orchestrator reviews diffs and verification before accepting work
- durable memory is indexed and loaded selectively

This repository is intentionally spec-first. The goal is not to freeze one implementation forever, but to give coding agents a precise operating protocol for generating the best current lightweight delegation framework for your environment.

## Why prompt/spec-first?

AI coding tools, model capabilities, CLI flags, reasoning controls, and user workflows change quickly. A fixed package can become stale. A good agentic skill remains useful because stronger future models can use the same principles to generate a better implementation.

So this repo provides two paths:

### Path A: Recommended agentic generation

1. Give `prompts/01-builder.md` to a coding agent.
2. Give `prompts/02-reviewer-refiner.md` to a second agent or fresh session to test and improve the result.
3. In projects where you want to use the framework, give the orchestrator `prompts/03-orchestrator-activation.md`.

### Path B: Use as a skill

Load or paste `skills/autonomous-ai-agents/agent-orchestra/SKILL.md` into an agent that supports skills. The skill tells the agent when and how to use the framework and points it to the prompt files.

## Repository layout

```text
prompts/
  01-builder.md
  02-reviewer-refiner.md
  03-orchestrator-activation.md
skills/
  autonomous-ai-agents/
    agent-orchestra/
      SKILL.md
docs/
  design-decisions.md
  framework-spec.md
examples/
  README.md
template/
  README.md
```

## What the generated framework should create

The builder prompt asks an agent to create a reusable framework template that can instantiate this runtime folder inside a project:

```text
.agent-orchestra/
  summary_orchestrator.md
  summary_worker.md
  memory_orchestrator.md
  memory_worker.md
  config.example.toml
  tasks/
  status/
  reports/
  logs/
  snapshots/
  context/
  archive/
  export/
  bin/
    memory
    task
    run-worker
    init-project
```

The runtime folder is hidden, gitignored by default, disposable, and project-local.

## Current status

This is a public skill/spec package, not a polished installable application. The prompts are the source of truth. A reference implementation can be generated from them and should be reviewed with the reviewer/refiner prompt before serious use.

## License

MIT. See `LICENSE`.
