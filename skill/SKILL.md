---
name: agent-relay
description: "Use when a user wants to improve coding-agent project quality while controlling token usage through a lightweight orchestrator/worker delegation framework. Builds or uses a repo-local .agent-relay runtime with one worker at a time, compact task specs, indexed memory, and diff-first review."
version: 0.1.0
author: JPawchan
license: MIT
metadata:
  hermes:
    tags: [agentic-workflows, coding-agents, orchestration, delegation, token-efficiency, code-quality]
    related_skills: [hermes-agent, codex, claude-code, opencode]
---

# Agent Relay

## Overview

Agent Relay is a prompt-first skill for creating and using a lightweight orchestrator/worker delegation framework inside coding projects.

The goal is to improve software quality while reducing token usage. Quality remains the priority. The skill uses one orchestrator as final authority and one fresh worker session at a time, which usually saves tokens versus parallel workers by avoiding duplicated context and review work. Workers receive focused task specs, write compact reports/status files, and never mark tasks done. The orchestrator reviews worker output, diffs, and verification before accepting work or launching the next worker.

This skill is intentionally spec-first. Prefer generating or adapting the current best implementation from the prompts instead of treating any old script as permanent.

## When to Use

Use this skill when:

- The user wants orchestrator/worker coding-agent delegation.
- The user wants better code quality from multiple model perspectives.
- The user cares about token efficiency and context-window hygiene.
- A project is large enough that fresh focused worker sessions are useful.
- The user wants compact task files, status files, reports, and indexed memory.
- The user wants to generate a reusable `.agent-relay/` project runtime.

Do not use this skill for:

- Tiny one-shot edits where delegation overhead exceeds benefit.
- Tasks where the user explicitly wants one agent to implement directly.
- Fully parallel multi-worker systems; v1 is intentionally serial.
- Heavy daemon/database/UI orchestration systems.

## Source Files

The canonical prompts are:

```text
prompts/01-create-framework.md
prompts/02-use-framework.md
prompts/optional-improve-framework.md
```

The design reference files are:

```text
docs/framework-spec.md
docs/design-decisions.md
```

## Core Principles

1. Quality is the priority.
2. Token savings matter, but only when they do not meaningfully harm quality.
3. Use one active worker at a time.
4. Keep worker contexts minimal but sufficient.
5. Use fresh sessions to avoid context decay.
6. Write explicit task specs.
7. Store machine task state in compact JSON.
8. Store durable memory in indexed memory files.
9. Review diffs before accepting code changes.
10. Only the orchestrator may mark work done.

## Recommended Workflow

### 1. Create the framework

Give a coding agent:

```text
prompts/01-create-framework.md
```

Expected completion criteria:

- reusable framework template created
- `.agent-relay/` runtime init supported
- `summary_orchestrator.md` and `summary_worker.md` created
- helper scripts implemented with dependency-free Python
- smoke tests run
- Hermes command syntax verified instead of guessed

### Optional: improve the framework

Give a fresh agent or second coding agent:

```text
prompts/optional-improve-framework.md
```

The reviewer should inspect, test, simplify, and fix the framework directly. It must not merely comment.

### 2. Use in a project

After the framework is installed/instantiated in a project, give the orchestrator:

```text
prompts/02-use-framework.md
```

The orchestrator should then read:

```text
.agent-relay/summary_orchestrator.md
```

and follow it as the operating manual.

## Expected Runtime Shape

```text
.agent-relay/
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

The runtime directory should be hidden, gitignored by default, and disposable.

## Common Pitfalls

1. Using multiple workers at once. This defeats the token discipline and complicates review.
2. Letting workers mark tasks done. Workers may only report `needs_review`; the orchestrator accepts or rejects.
3. Giving workers the full orchestrator conversation. Use task specs and optional context packs instead.
4. Reading full files by default during review. Review diffs first; read full files only when needed.
5. Letting memory become a transcript dump. Memory should be rare, durable, indexed, and high-signal.
6. Hallucinating Hermes CLI flags. Inspect real CLI help before implementing provider/model/reasoning controls.
7. Treating `roadmap.md` as required agent context. If present, it should be human-facing unless explicitly requested.
8. Building a heavy system too early. Avoid daemon/database/UI/background-worker complexity in v1.

## Verification Checklist

- [ ] Create-framework prompt produced a working artifact, not only docs.
- [ ] Optional improve-framework prompt was run in a fresh context when serious use requires extra confidence.
- [ ] Helper scripts pass smoke tests.
- [ ] `init-project` works in a temporary project.
- [ ] One-worker lock is enforced.
- [ ] Worker cannot mark `done` through normal lifecycle commands.
- [ ] Reports, statuses, and diffs are created consistently.
- [ ] Hermes command syntax was verified on the actual machine.
- [ ] The final project runtime remains disposable and gitignored.
