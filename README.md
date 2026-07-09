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

## Why only one worker at a time?

Agent Orchestra is optimized for quality per token, not maximum parallel throughput.

Parallel workers often look attractive, but they can create hidden costs:

- multiple workers read overlapping context
- parallel edits can conflict
- the orchestrator must review several branches of work at once
- duplicated exploration burns tokens
- stale assumptions spread before review catches them
- the human-facing orchestrator loses a clean sequential story of what changed

The preferred loop is deliberately serial:

1. orchestrator defines one focused task
2. one fresh worker executes it
3. worker writes a compact report/status/diff
4. orchestrator reviews and accepts/rejects
5. only then does the next worker start

This keeps context small, review clear, and token usage controlled while preserving the two-model quality loop.

## Installation guide

This is not a traditional package you install once and trust forever. The recommended installation is agentic: ask a coding agent to create the current best implementation from the prompt/spec, then use it in your project.

### Step 1: Create the framework

Give this prompt to your coding agent:

```text
prompts/01-create-framework.md
```

The agent should create a reusable framework template and verify it with real smoke tests.

### Step 2: Use the framework in a project

After the framework exists and has instantiated `.agent-orchestra/` inside a project, give the orchestrator this small activation prompt:

```text
prompts/02-use-framework.md
```

The orchestrator will read `.agent-orchestra/summary_orchestrator.md` and follow it as the operating manual.

### Optional: improve or update the framework

Use this prompt when you want a fresh agent to review, test, simplify, or improve an existing framework implementation:

```text
prompts/optional-improve-framework.md
```

This step is recommended before serious use, but it is optional in the basic installation flow.

## Repository layout

```text
README.md
LICENSE
skill/
  SKILL.md
prompts/
  01-create-framework.md
  02-use-framework.md
  optional-improve-framework.md
docs/
  design-decisions.md
  framework-spec.md
template/
  README.md
```

## Using as an agentic skill

If your agent supports skills, use:

```text
skill/SKILL.md
```

The skill explains when to use Agent Orchestra and points to the prompt files.

## What the generated framework should create

The creation prompt asks an agent to create a reusable framework template that can instantiate this runtime folder inside a project:

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

This is a public skill/spec package, not a polished installable application. The prompts are the source of truth. A reference implementation can be generated from them and should be reviewed with the optional improvement prompt before serious use.

## License

MIT. See `LICENSE`.
