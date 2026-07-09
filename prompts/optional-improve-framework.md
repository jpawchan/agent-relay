# Optional Improve Framework Prompt

You are an elite senior software engineer and adversarial reviewer. A previous coding agent created a lightweight delegation framework for orchestrator/worker coding agents. Your job is to inspect it, test it, simplify overbuilt parts, fix bugs directly, and ensure it matches the intended design.

Do not merely comment. Improve the artifact.

The framework’s purpose is to increase software quality while reducing token usage. Quality is the priority. Token savings may justify quality reduction only when the token savings are large relative to the quality loss. If the tradeoff cannot be evaluated, follow the framework principles: split work into focused tasks, use fresh worker sessions, keep context minimal but sufficient, verify with tools/tests, review before accepting, and use stronger/more expensive models only when risk justifies it.

## Expected design to verify

The framework should be a reusable template that instantiates a disposable project-local runtime directory:

```text
.agent-orchestra/
```

The runtime directory should be hidden, gitignored by default, and contain task/status/report/memory files for the current project.

The framework should be lightweight:

- dependency-free Python helper scripts
- Markdown for docs/tasks/reports/memory/context
- JSON for status files
- TOML for config
- no database
- no daemon
- no UI
- no async/background workers in v1
- no complex scheduler
- one active worker at a time

## Required files to inspect

Inspect the reusable framework and any instantiated runtime template. It should contain equivalents of:

```text
agent-orchestra-framework/
  template/
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
  README.md
```

If names differ, judge whether the design remains equivalent and easy to use.

## What to verify in summaries

### `summary_orchestrator.md`

Must be a complete operating manual for the orchestrator. Verify it explains:

- purpose and quality-vs-token tradeoff rule
- orchestrator responsibilities
- worker contract at a high level
- directory layout
- one-worker-at-a-time rule
- synchronous v1 execution model
- task lifecycle/statuses
- indexed memory usage
- one detailed active task at a time
- optional context packs
- model/reasoning tier selection
- Hermes profile/command-template usage
- worker launch flow
- diff-first review
- review before next worker starts
- optional read-only review/audit workers
- accept/reject/request-fixes flow
- rare/high-signal memory updates
- git and non-git fallback behavior
- failure handling, usage limits, unexpected files, stale locks
- safety rules
- minimal command reference
- `roadmap.md`, if present, is human-facing only and not normal agent context

### `summary_worker.md`

Must be compact enough for every worker to read. Verify it says:

- worker is a leaf agent
- worker handles exactly one task
- worker reads task spec and optional context pack
- worker respects scope and budget
- worker can inspect additional files only within budget
- worker escalates architecture/product/security/scope decisions
- worker does not ask human directly
- worker does not spawn subworkers
- worker does not mark `done`
- worker preserves project style
- worker prefers test-first when practical
- worker verifies code changes or reports why not
- worker writes compact report and status JSON before exit
- worker reports decisions/evidence/risks, not full internal reasoning
- worker avoids dependency changes, destructive commands, secrets leakage, broad refactors, global config changes, and out-of-scope sensitive changes

Fix inconsistencies between the two summaries.

## What to verify in helper scripts

### `bin/init-project`

Verify:

- Instantiates `.agent-orchestra/` inside a target project.
- Copies template files and helper scripts.
- Creates required directories.
- Does not overwrite existing files unless force is explicit.
- Adds `.agent-orchestra/` to `.gitignore` only for git repos, carefully and idempotently.
- Does not create `.gitignore` for non-git projects unless explicitly requested.
- Runtime is disposable/untracked by default.

### `bin/memory`

Verify commands work:

```bash
.agent-orchestra/bin/memory index orchestrator
.agent-orchestra/bin/memory index worker
.agent-orchestra/bin/memory show orchestrator M001
.agent-orchestra/bin/memory show worker M001
.agent-orchestra/bin/memory add worker "Short index sentence" "Detailed memory text"
.agent-orchestra/bin/memory export
```

Verify:

- Stable memory IDs are used.
- Compact index is at top.
- `show` loads by ID, not fragile line number only.
- `add` updates index and detailed entries consistently.
- `export` produces a timestamped export of both memory files.
- Memory files do not encourage task-progress logging.

### `bin/task`

Verify commands work:

```bash
.agent-orchestra/bin/task create --title "Add email validation" --type implementation
.agent-orchestra/bin/task create --id T001-add-email-validation --title "Add email validation" --type implementation
.agent-orchestra/bin/task list
.agent-orchestra/bin/task list --json
.agent-orchestra/bin/task status T001-add-email-validation
.agent-orchestra/bin/task validate
.agent-orchestra/bin/task validate T001-add-email-validation
.agent-orchestra/bin/task accept T001-add-email-validation --note "Reviewed diff and tests"
.agent-orchestra/bin/task reject T001-add-email-validation --reason "Missing edge-case test"
.agent-orchestra/bin/task request-fixes T001-add-email-validation --reason "Missing edge-case test"
.agent-orchestra/bin/task decide T001-add-email-validation --answer "Use existing auth middleware"
.agent-orchestra/bin/task lock-status
.agent-orchestra/bin/task unlock --force
.agent-orchestra/bin/task archive-done
```

Verify:

- IDs auto-generate as `T001-short-slug`.
- Status JSON is source of truth for machine state.
- Task Markdown is a strict template for task instructions.
- Scripts do not depend on YAML parsing.
- `list` is derived from status JSON, not a prose roadmap.
- `validate` catches invalid status/report/attempt/lock states.
- `accept` only works from `needs_review` and marks `done`.
- `reject`/`request-fixes` records review result but does not automatically create duplicate tasks unless explicitly requested.
- Multiple attempts are tracked under one task ID.
- `archive-done` moves done/cancelled/superseded artifacts to archive without deleting by default.

### `bin/run-worker`

Inspect and, if safe/cheap, test. It should:

- Be synchronous-only in v1.
- Validate framework state before run.
- Refuse if another worker is active.
- Use `.agent-orchestra/status/active.lock` or equivalent.
- Be conservative with stale locks; require explicit force unlock for ambiguous cases.
- Set status to `running`.
- Record git baseline if git repo.
- Snapshot expected files in non-git fallback when possible.
- Generate a minimal worker launch prompt.
- Launch one worker via configured command or default Hermes command.
- Capture worker output to log.
- Validate worker report/status after exit.
- Generate diff artifact after worker exits.
- Use git diff when available.
- Use best-effort unified diffs from snapshots when git is unavailable.
- Detect/flag unexpected changed files when possible.
- Mark task `failed` with reason `invalid_worker_output` if worker exits without valid status/report.
- Remove lock on normal exit.
- Not implement background/async workers in v1.
- Not implement heartbeats in v1.

## Hermes integration checks

Verify the implementation does not hallucinate Hermes flags.

Run/read actual installed CLI help where available:

```bash
hermes --help
hermes chat --help
hermes config --help
hermes profile --help
```

Expected behavior:

- Default command without config should use existing Hermes config:
  `hermes chat -q "<generated prompt>"`
- Optional TOML config supports worker tiers.
- Optional Hermes profiles are preferred for per-tier model/reasoning/tool settings.
- Direct provider/model/reasoning flags are used only if verified by actual CLI help/docs.
- If profile is explicitly configured but missing/fails validation, runner fails clearly. It must not silently fall back.
- If no tier config exists, fallback to default Hermes config and print that fallback clearly.
- If reasoning cannot be enforced through verified Hermes CLI/profile behavior, the framework must document that limitation instead of pretending it works.

## Status lifecycle to verify

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

Workers may not mark `done`. Only orchestrator/task accept may mark `done`.

Verify status transitions are not dangerously permissive. The framework does not need a complex state machine, but it should prevent obvious mistakes such as accepting a task that is not `needs_review`.

## Review model to verify

The framework should encode this review discipline:

- Orchestrator reviews directly by default.
- Separate review/audit workers are optional, serial, read-only, and only for high-risk/high-complexity/context-freshness cases.
- Review findings use severities: `critical`, `major`, `minor`, `note`.
- Code-changing tasks require diff-first review.
- Full files are read only when needed.
- The orchestrator must review before launching the next worker.

## Safety checks

Verify summaries/scripts discourage or prevent:

- Multiple active workers.
- Workers asking the human directly.
- Workers spawning subworkers.
- Workers marking `done`.
- Silent dependency additions.
- Destructive commands without explicit permission.
- Secrets in logs/reports.
- Broad unrelated refactors.
- Out-of-scope auth/security/payment/data-loss-sensitive changes.
- Hidden test failures.

## Required test procedure

Run real tests/smoke checks. At minimum:

1. Create a temporary sample project.
2. Run `init-project` into it.
3. Confirm `.agent-orchestra/` exists with expected files.
4. Confirm `.gitignore` behavior in a git repo is idempotent.
5. Test non-git init behavior separately if easy.
6. Test memory index/show/add/export.
7. Test task create/list/status/validate.
8. Test accept/reject/request-fixes/decide lifecycle.
9. Test archive-done.
10. Test lock-status and safe force unlock behavior.
11. Inspect or test run-worker with a safe/trivial command template if launching real Hermes would be costly.
12. Run any included unit/self-tests.

If any test cannot be run, state exactly why and what you did instead.

## Fixing rules

Fix bugs directly. Simplify overbuilt code. Prefer small, clear, boring Python.

Do not add:

- database
- daemon
- background process manager
- web UI
- heavy scheduler
- third-party dependencies
- YAML dependency
- complex plugin system

Unless absolutely necessary, do not expand scope. The goal is a reliable v1.

## Completion criteria

You are done only when you have:

- Inspected all framework files created by the creation prompt.
- Run helper smoke tests.
- Tested `init-project` in a temporary sample project.
- Tested memory index/show/add/export.
- Tested task create/list/status/validate/accept/reject/request-fixes/decide/archive behavior.
- Inspected `run-worker` logic and tested it with a safe command if feasible.
- Checked one-active-worker locking is enforced.
- Checked summaries match the intended design.
- Simplified overbuilt code.
- Fixed bugs directly.
- Documented remaining limitations.
- Produced a concise review report with changed files and real verification results.

Your final report should include:

- What you changed.
- What you tested.
- Exact commands run and whether they passed.
- Remaining limitations or risks.
- Whether the framework is ready for orchestrator use.
