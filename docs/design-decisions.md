# Design Decisions

This project is shared as an agentic skill/spec rather than primarily as an installable package.

## Why

The durable value is the orchestration method:

- one orchestrator as final authority
- one worker at a time
- fresh worker sessions
- compact task specs
- indexed memory
- diff-first review
- explicit verification

AI models and agent CLIs change quickly. Future models may generate better implementations from the same prompts. Therefore the prompts and design principles are the source of truth; any implementation is a generated or reference artifact.

## Packaging position

Recommended public positioning:

> Agent Relay is an agentic skill/spec for generating lightweight orchestrator/worker delegation frameworks inside coding projects. It is prompt-first, with optional reference implementation artifacts.

## Non-goals for v1

- no daemon
- no database
- no UI
- no async/background worker orchestration
- no parallel workers
- no hard dependency on a specific model
- no hard dependency on unverified Hermes CLI flags
