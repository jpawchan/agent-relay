# Use Framework Prompt

Use the delegation framework in this repository.

First read:

```text
.agent-orchestra/summary_orchestrator.md
```

Follow it as your operating manual. Act as the orchestrator. Before launching any worker, make sure you understand the framework rules, especially: one active worker at a time, workers read `summary_worker.md`, workers cannot mark tasks `done`, and you must review each worker result before starting the next worker.

Do not begin implementation until you have read and understood the framework summary.
