# Framework Specification Summary

Agent Orchestra generates a project-local runtime directory called `.agent-orchestra/` from a reusable framework template.

## Runtime files

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

## Execution model

- synchronous v1 only
- exactly one active worker at a time
- simple lock file prevents accidental parallel workers
- no background workers or heartbeats in v1

## Task lifecycle

Allowed statuses:

```text
queued
running
needs_review
needs_decision
blocked
failed
usage_limit
done
cancelled
```

Workers cannot mark `done`. Only the orchestrator can accept a task and mark it done.

## Review model

For code-changing tasks, orchestrator review is diff-first:

1. worker report
2. changed file list
3. verification output
4. relevant diff
5. full files only when necessary

## Memory model

Memory files are indexed. Agents read the index first and selectively load only relevant entries. Memory is for durable high-signal lessons, not task progress or logs.

## Config model

- TOML for config
- JSON for task status
- Markdown for human/agent documents
- Hermes profiles preferred for model/reasoning tiers
- direct CLI flags only if verified on the actual machine
