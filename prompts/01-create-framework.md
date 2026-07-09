# Create Framework Prompt

You are an elite senior software engineer. Create a lightweight, repo-local-at-runtime delegation framework for coding agents.

The purpose of this framework is to increase software quality while reducing token usage. Quality is the priority. Token savings may justify quality reduction only when the token savings are large relative to the quality loss. If the tradeoff cannot be evaluated, follow the framework principles: split work into focused tasks, use fresh worker sessions, keep context minimal but sufficient, verify with tools/tests, review before accepting, and use stronger/more expensive models only when risk justifies it.

You must create a working artifact, not a design document. Implement the framework as small, dependency-free Python helper scripts plus Markdown/TOML/JSON files. Keep the architecture boring, small, fast, easy to inspect, and easy for coding agents to use.

## Core concept

There is one reusable framework template outside projects. When the user wants to use delegation in a project, the framework instantiates a hidden project-local runtime directory:

```text
.agent-relay/
```

This directory is workspace state, not product source code. It is hidden, gitignored by default, disposable, and contains task/status/report/memory files for the current project.

Only one worker may run at a time. Workers are fresh leaf-agent sessions. Workers perform focused tasks, verify them, and report compactly. The orchestrator remains the final authority and must review before marking a task done or launching the next worker.

## Required reusable framework structure

Create a reusable framework folder with at least this structure:

```text
agent-relay-framework/
  template/
    summary_orchestrator.md
    summary_worker.md
    memory_orchestrator.md
    memory_worker.md
    config.example.toml
    tasks/
      README.md
    status/
      README.md
    reports/
      README.md
    logs/
      README.md
    snapshots/
      README.md
    context/
      README.md
    archive/
      README.md
    export/
      README.md
    bin/
      memory
      task
      run-worker
      init-project
  README.md
```

If you choose a slightly different top-level folder name, keep the internal template/runtime layout equivalent and explain it.

The helper scripts must be dependency-free Python using only the standard library. They should run directly when executable, and also support being run as:

```bash
python .agent-relay/bin/task ...
python .agent-relay/bin/memory ...
python .agent-relay/bin/run-worker ...
python path/to/framework/template/bin/init-project ...
```

Do not add a database, daemon, UI, service, or heavy scheduler.

## Runtime directory created by init-project

`bin/init-project /path/to/project` must instantiate:

```text
/path/to/project/.agent-relay/
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

Behavior:

- Copy a snapshot of the template into the project runtime.
- Do not overwrite existing files unless an explicit force option is used.
- If the target project is a git repo, add `.agent-relay/` to `.gitignore` if it is not already ignored.
- If `.gitignore` exists, append carefully without removing/reordering existing content.
- If the project is a git repo and `.gitignore` does not exist, create one containing `.agent-relay/`.
- If the project is not a git repo, do not create `.gitignore` unless explicitly requested.
- Default install is untracked/disposable. Optionally support a tracked mode, but runtime task/status/report/log/snapshot state should still be ignored.

## Files and formats

Use:

- Markdown for human/agent-readable docs, task specs, reports, memories, and context packs.
- JSON for machine-readable task status files.
- TOML for config: `config.example.toml`, optional project-local `config.toml`.

Do not require YAML parsing. If a task spec visually uses frontmatter, scripts must not depend on parsing YAML. Status JSON is the source of truth for task state. Task Markdown is the source of truth for task instructions.

## Required summaries

### `summary_orchestrator.md`

This is the orchestrator operating manual. It must be complete enough that the user can tell an orchestrator: “read `.agent-relay/summary_orchestrator.md` and use this framework.”

It must cover:

- Framework purpose: improve quality while reducing token usage.
- Quality-vs-token tradeoff rule.
- Orchestrator responsibilities.
- Worker responsibilities at a high level.
- Directory layout.
- Exact one-worker-at-a-time rule.
- Synchronous v1 execution model.
- Task lifecycle/statuses.
- How to inspect memory indexes without reading full memory files.
- How to create one detailed active task at a time.
- How to use optional context packs.
- How to choose worker tiers/model profiles.
- How to launch workers.
- How to review reports, verification output, changed files, and diffs.
- Diff-first review; full-file review only when necessary.
- When to use optional read-only review/audit workers.
- How to accept/reject/request fixes.
- How to update memory rarely and with high signal.
- How to handle git and non-git projects.
- How to handle failures, blocked tasks, usage limits, stale locks, unexpected files.
- Safety rules.
- Minimal command reference.
- Explicit instruction that `roadmap.md`, if present, is human-facing only and not normal agent context unless human asks.

The orchestrator should read `summary_orchestrator.md` and `summary_worker.md` at framework startup, then read only memory indexes by default.

### `summary_worker.md`

This is the compact worker contract. Workers should read it from disk at the beginning of every task.

It must cover:

- Worker is a leaf agent, not orchestrator.
- Worker handles exactly one task.
- Worker must read the task spec and optional context pack.
- Worker must stay within scope and budget.
- Worker may inspect additional files only within budget.
- Worker may make local implementation decisions, but must escalate architecture/product/security/scope decisions.
- Worker must not ask the human directly.
- Worker must not spawn subworkers.
- Worker must not mark `done`.
- Worker must preserve project style/conventions.
- Worker should prefer test-first for behavior changes when practical.
- Worker must verify code changes or clearly report why verification was impossible.
- Worker must write compact report and status JSON before exiting.
- Worker must report decisions/evidence/risks, not full chain-of-thought.
- Worker must avoid secrets leakage, destructive commands, dependency additions, broad refactors, global config changes, and out-of-scope security/auth/payment/data changes unless explicitly allowed.

Keep this file focused and compact enough to read for every worker task.

## Memory system

Create `memory_orchestrator.md` and `memory_worker.md` using an indexed memory format.

Required behavior:

- Compact index at the top.
- Stable memory IDs such as `M001`, `M002`.
- Detailed entries below the index.
- Agents read the index first, then selectively load relevant entries.
- Memory writes must be rare, durable, project-relevant, and high-signal.
- Do not store task progress, completed-task logs, temporary TODOs, verbose summaries, or stale facts in memory.

Implement `bin/memory` with at least:

```bash
.agent-relay/bin/memory index orchestrator
.agent-relay/bin/memory index worker
.agent-relay/bin/memory show orchestrator M001
.agent-relay/bin/memory show worker M003
.agent-relay/bin/memory add worker "Short index sentence" "Detailed memory text"
.agent-relay/bin/memory export
```

`memory export` should create or print a timestamped export containing both memory files, e.g. in `.agent-relay/export/`.

Use stable IDs as canonical references. Optional line ranges may be generated for convenience, but line numbers must not be the only reference mechanism.

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

Workers may set:

```text
needs_review
needs_decision
blocked
failed
usage_limit
cancelled only if explicitly told to cancel
```

Only the orchestrator may set:

```text
done
```

Task status JSON is the machine-readable source of truth. It should include fields like:

```json
{
  "id": "T001-add-email-validation",
  "title": "Add email validation",
  "type": "implementation",
  "status": "queued",
  "attempt": 1,
  "model_tier": "standard_worker",
  "tier_reason": "Normal feature slice touching two modules; not security-sensitive.",
  "created_at": "...",
  "updated_at": "...",
  "artifacts": {
    "task": ".agent-relay/tasks/T001-add-email-validation.md",
    "report": null,
    "diff": null,
    "log": null,
    "context": null
  },
  "scope_check": {
    "unexpected_files": [],
    "requires_orchestrator_attention": false
  },
  "attempts": []
}
```

Support multiple attempts under the same task ID. Use paths such as:

```text
reports/T001-add-email-validation-attempt-1.md
reports/T001-add-email-validation-attempt-1.diff
logs/T001-add-email-validation-attempt-1.log
```

Same task ID is used for retries/fixes within the same scope. Create a new task if scope changes.

Support cancellation/supersession/merge metadata, e.g. `cancelled`, `superseded_by`, `merged_into`.

## Task helper

Implement `bin/task` with at least:

```bash
.agent-relay/bin/task create --title "Add email validation" --type implementation
.agent-relay/bin/task create --id T001-add-email-validation --title "Add email validation" --type implementation
.agent-relay/bin/task list
.agent-relay/bin/task list --json
.agent-relay/bin/task status T001-add-email-validation
.agent-relay/bin/task validate
.agent-relay/bin/task validate T001-add-email-validation
.agent-relay/bin/task accept T001-add-email-validation [--note "..."]
.agent-relay/bin/task reject T001-add-email-validation --reason "..."
.agent-relay/bin/task request-fixes T001-add-email-validation --reason "..."
.agent-relay/bin/task decide T001-add-email-validation --answer "..."
.agent-relay/bin/task lock-status
.agent-relay/bin/task unlock --force
.agent-relay/bin/task archive-done
```

Behavior:

- `create` auto-generates IDs if absent: `T001-short-slug`, incrementing from existing tasks.
- `create` creates a strict Markdown task template and matching status JSON with `queued`.
- `list` derives operational queue from status JSON files, not from a prose roadmap.
- `validate` checks task/status/report consistency, allowed statuses, report existence when required, attempts consistency, and no more than one running task.
- `accept` only works from `needs_review`, marks `done`, records timestamp and note.
- `reject`/`request-fixes` records review result but does not automatically create a new task unless explicitly implemented as an option.
- `archive-done` moves done/cancelled/superseded task artifacts into `.agent-relay/archive/` and does not delete by default.

## Task spec template

`task create` must generate a strict task spec template like:

```md
# T001: Add Email Validation

## Metadata
- ID: T001-add-email-validation
- Type: implementation
- Status: queued
- Priority: normal
- Model tier: standard_worker
- Tier reason: ...
- Attempt: 1
- Depends on: none

## Objective
One clear sentence describing the task.

## Acceptance Criteria
- Specific observable requirement 1
- Specific observable requirement 2

## Scope
Allowed:
- `path/or/pattern`

Expected touched files:
- `path/or/pattern`

Not allowed:
- Do not add dependencies unless explicitly approved.
- Do not refactor unrelated files.
- Do not change public APIs unless explicitly required.

## Context
Minimal relevant context, summaries, and file paths.

## Context Pack
Optional path: `.agent-relay/context/T001-add-email-validation.md`

## Relevant Memory
Memory IDs or short excerpts selected from `memory_worker.md`, if any.

## Verification Required
- Run targeted tests/checks.
- Run broader checks when affordable.

## Budget / Escalation Limits
- Inspect at most N additional files before escalating.
- If more than N unrelated files need changes, mark `needs_decision`.
- If architecture/product/security/scope decision is needed, mark `needs_decision`.

## Required Outputs
- Update status JSON at `.agent-relay/status/T001-add-email-validation.json`.
- Write report to `.agent-relay/reports/T001-add-email-validation-attempt-1.md`.
- Do not mark `done`; use `needs_review` when ready for orchestrator review.
```

Task specs should contain task-specific context and reference `summary_worker.md`; they should not repeat the whole worker protocol.

## Worker report template

Workers must produce compact reports, usually under 100-200 lines, like:

```md
# T001 Report - Attempt 1

## Result
needs_review

## Summary
One to three sentences describing what changed.

## Files Changed
- `path/to/file.ts`: concise change description

## Verification
- `npm test -- email`: passed
- `npm run typecheck`: passed

## Decisions Made
- Used existing helper X to avoid adding dependency.

## Risks / Follow-up
- None, or concise bullets.

## Unexpected Files
- None, or list with justification.

## Diff
See `.agent-relay/reports/T001-add-email-validation-attempt-1.diff`.
```

Reports should include decisions, evidence, and risks, not full internal reasoning.

## Context packs

Support optional task-specific context files:

```text
.agent-relay/context/T001-add-email-validation.md
```

Rules:

- Optional.
- Short.
- Task-specific.
- Prefer paths and summaries before copied code excerpts.
- Use small code excerpts only when necessary to prevent guessing.
- Do not treat context packs as global project memory.

## Roadmap

Do not make a roadmap part of the normal agent workflow.

If `roadmap.md` exists, it is optional and human-facing only. Summaries should say agents do not read it by default unless the human explicitly asks or the task is framework maintenance.

Operational queue is derived from status JSON files and `task list`.

## Worker runner

Implement `bin/run-worker` as synchronous-only v1.

Required behavior:

1. Validate framework state before run.
2. Refuse to start if another worker is active.
3. Use a simple lock file such as `.agent-relay/status/active.lock` containing task ID, PID, and start time.
4. Do not auto-clear ambiguous locks. Provide `task lock-status` and `task unlock --force`.
5. Set task status to `running`.
6. Record baseline before launch:
   - If git is available and project is a git repo, record branch/commit/status.
   - If git is unavailable, snapshot expected/touched files listed in task spec/status when possible.
7. Generate a minimal worker launch prompt dynamically.
8. Launch one worker via configured command or default Hermes command.
9. Capture worker output to log.
10. After worker exits, validate worker output/status/report.
11. Generate diff artifact after the worker exits:
    - If git exists, use `git diff` and `git diff --name-only`.
    - If no git, produce best-effort unified diffs from snapshots.
12. Detect/flag unexpected changed files when possible.
13. Update status JSON with artifacts and scope warnings.
14. Remove lock on normal exit.
15. If worker exits without valid status/report, mark task `failed` with reason `invalid_worker_output`.

No background/async worker mode in v1. No heartbeat protocol in v1. Timestamps and lock file are enough.

## Worker launch prompt

`run-worker` should generate a small prompt similar to:

```text
You are a worker agent, not the orchestrator.
Work on exactly one task.
First read `.agent-relay/summary_worker.md`.
Then read the task spec at `<task path>`.
If a context pack is referenced, read it.
Follow the worker protocol exactly.
Do not ask the human questions.
Do not spawn subworkers.
Do not mark the task done.
Before exiting, write the required report and update the required status JSON to an allowed worker status.
```

Do not paste the full worker protocol into every launch prompt. The worker reads `summary_worker.md` from disk.

## Hermes integration and config

The framework is Hermes-first but should support configurable command templates.

Use TOML config:

```toml
[commands]
default_worker = "hermes chat -q {prompt}"

[tiers.cheap_worker]
profile = ""
provider = ""
model = ""
reasoning = "low"
command = ""
description = "Low-cost worker for mechanical/simple tasks."

[tiers.standard_worker]
profile = ""
provider = ""
model = ""
reasoning = "medium"
command = ""
description = "Default coding worker."

[tiers.premium_worker]
profile = ""
provider = ""
model = ""
reasoning = "high"
command = ""
description = "High-reasoning worker for difficult/risky tasks."

[tiers.review_worker]
profile = ""
provider = ""
model = ""
reasoning = "high"
command = ""
description = "Read-only independent review/audit worker."

[limits]
one_active_worker = true
max_files_to_inspect_before_escalation = 5
```

Rules:

- If no project-local `config.toml` exists, use default existing Hermes config:
  `hermes chat -q "<generated prompt>"`.
- If `config.toml` defines a tier profile, use that profile.
- Prefer Hermes profiles for per-tier model/reasoning/tool settings.
- Direct provider/model/reasoning flags may be used only if verified as supported by the installed Hermes CLI.
- If a profile is explicitly configured but missing/fails validation, fail clearly. Do not silently fall back to default.
- If no tier config exists, fallback to default Hermes config and print that fallback clearly.
- Command templates should be configurable enough to support non-Hermes agents later.

You must verify Hermes syntax on the actual machine before implementing Hermes-specific flags. Run/read:

```bash
hermes --help
hermes chat --help
hermes config --help
hermes profile --help
```

Do not hallucinate unsupported flags. If reasoning cannot be controlled through verified CLI/profile behavior, document the limitation and record desired reasoning in task metadata without pretending it was enforced.

## Git and non-git behavior

Git is optional but preferred.

If git exists and the project is a git repo:

- Record branch and commit baseline.
- Detect dirty working tree before worker runs.
- Use git diff for review artifacts.
- Use git diff name lists to detect changed/unexpected files.
- Warn about uncommitted user changes.
- Do not automatically commit/stash unless explicitly requested.

If git is unavailable:

- Framework still works.
- Snapshot expected/touched files before worker run.
- For new files, record paths.
- Produce best-effort diffs from snapshots.
- Report limitations clearly.
- Do not snapshot the whole project by default.

Do not block a worker from editing unexpected files in v1; detect/report scope violations after the run.

## Review and acceptance rules

Orchestrator reviews directly by default. Separate review/audit workers are optional, serial, read-only, and used only when independence/context freshness/high risk justifies extra tokens.

Review worker types:

- `review`: normal code review of a specific task/diff.
- `audit`: broader adversarial inspection of risky area/security/architecture/migration/failure mode.

Review findings should use severity:

- `critical`: must fix before acceptance.
- `major`: should fix before acceptance unless explicitly waived.
- `minor`: can be follow-up.
- `note`: observation only.

For code-changing tasks, orchestrator must inspect:

- worker report
- changed file list
- verification results
- relevant diff

Full files are read only when necessary for confidence.

## Safety rules

Workers must not:

- Ask the human directly.
- Spawn subworkers.
- Mark `done`.
- Add dependencies unless explicitly allowed or escalated.
- Run destructive commands unless explicitly allowed.
- Leak secrets into reports/logs.
- Modify auth/security/payment/data-loss-sensitive code outside scope.
- Change global environment/config unnecessarily.
- Hide failing tests or skipped verification.
- Perform broad unrelated cleanup/refactors.

## Verification requirements for your build

You must verify this framework actually works.

At minimum:

1. Run helper self-tests or smoke tests.
2. Initialize a temporary sample project with `init-project`.
3. Create a task.
4. List/status/validate tasks.
5. Test memory index/show/add/export.
6. Test lock-status/unlock behavior in a safe way.
7. Test accept/reject/request-fixes lifecycle.
8. Test archive-done.
9. Inspect `run-worker` logic. If safe and cheap, run it on a trivial task; if not, document why you skipped real worker launch and validate everything around it.
10. Verify Hermes command syntax with real CLI help output.

Do not claim success without real command output.

## Completion criteria

You are done only when you have:

- Created the reusable framework template.
- Created `summary_orchestrator.md`.
- Created `summary_worker.md`.
- Created indexed memory files.
- Created `config.example.toml`.
- Implemented dependency-free Python helpers:
  - `memory`
  - `task`
  - `run-worker`
  - `init-project`
- Included smoke tests or self-test commands.
- Verified tests/smoke tests pass.
- Verified Hermes command syntax instead of guessing.
- Documented unsupported Hermes features/fallbacks.
- Produced a concise final report with paths, changed files, and verification output.

Favor the smallest correct implementation. If you are tempted to add a daemon, database, UI, async worker system, complex scheduler, full YAML parser, or global roadmap reader, do not. Keep v1 lightweight.
