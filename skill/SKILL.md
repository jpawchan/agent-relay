---
name: agent-relay
description: "Use when a user wants higher code quality from coding agents while controlling token spend, via an orchestrator/worker delegation framework. Installs or operates a repo-local .agent-relay runtime: scoped task specs, parallel non-conflicting workers, diff-first review, indexed memory."
version: 0.2.0
author: JPawchan
license: MIT
metadata:
  hermes:
    tags: [agentic-workflows, coding-agents, orchestration, delegation, token-efficiency, code-quality]
    related_skills: [hermes-agent, codex, opencode]
---

# Agent Relay

Agent Relay runs an orchestrator/worker pattern inside a coding project: one
orchestrator talks to the human and owns acceptance; fresh workers each get one
scoped task with minimal context; a scheduler runs non-conflicting workers in
parallel (same tokens as serial, far less wall-clock time); review is
diff-first; durable lessons live in an indexed memory file loaded selectively.

## When to use

- The user wants delegation with quality control: explicit tasks, scoped
  changes, reviewed diffs.
- A project is big enough that fresh, focused worker sessions beat one long
  degrading context.
- The user cares about token efficiency without giving up review rigor.

Do not use for one-shot edits (delegation overhead exceeds benefit) or when
the user wants a single agent to implement directly.

## How to install into a project

Preferred (zero tokens): copy the tested reference implementation, then run
init.

```
git clone https://github.com/jpawchan/agent-relay
agent-relay/framework/relay init /path/to/project
```

Alternative (agentic): give a coding agent `prompts/create-framework.md` —
the prompt is self-contained and carries the full specification, so it works
without the repository. Then harden the result with
`prompts/improve-framework.md`. Use this path to adapt the framework to an
unusual environment or let a newer model build its own version.

## How to operate

Give the orchestrator agent `prompts/use-framework.md`, or simply: "read
`.agent-relay/orchestrator.md` and follow it". Workers are launched by
`relay run`; their contract is `.agent-relay/worker.md`.

## Invariants to preserve

- Tasks declare file scopes; only disjoint-scope tasks run concurrently.
- Workers cannot mark `done`, ask the human, spawn agents, or leave scope.
- The orchestrator reviews report + diff before accepting anything.
- Memory stays rare, durable, indexed — never a transcript dump.
- The runtime dir stays hidden, gitignored, disposable.
