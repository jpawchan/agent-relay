# Agent Relay — framework specification

This is the contract. The reference implementation in `framework/` satisfies
it; an agent regenerating the framework from `prompts/create-framework.md`
must satisfy it too. Anything not specified here is an implementation choice —
prefer the smallest boring option.

Note: `prompts/create-framework.md` embeds this whole contract so it can be
copied and used without the repository. If you change this file, update that
prompt to match.

## Shape

One dependency-free Python CLI (`relay`, stdlib only, Python 3.8+) plus
Markdown/TOML/JSON files. No daemon, database, UI, background service, or
third-party packages. `relay init <project>` instantiates a hidden,
disposable, gitignored-by-default runtime:

```
.agent-relay/
  relay              the CLI itself (self-contained with its doc files)
  orchestrator.md    orchestrator operating manual
  worker.md          compact worker contract, read by every worker
  memory.md          single indexed memory file, audience-tagged entries
  config.toml        worker command, tiers, limits (TOML; example shipped)
  tasks/             <id>.md task spec + <id>.json status per task
  work/<id>/         attempt-N.prompt.md / .log / .report.md / .diff
  archive/           moved done/cancelled tasks
```

Init must not overwrite existing files without `--force`, must append
`.agent-relay/` to `.gitignore` idempotently in git repos, and must not create
a `.gitignore` in non-git projects.

## Roles

- **Orchestrator** — the agent session the human talks to. Splits goals into
  tasks, launches waves, reviews diffs, and is the only authority for `done`.
- **Worker** — a fresh leaf agent session per attempt. One task, minimal
  context (worker.md + its spec + selectively loaded memory), reports
  compactly, cannot mark done, cannot ask the human, cannot spawn agents.

## Tasks

Task ids: `T###-short-slug`, auto-incremented, numbers never reused (archive
counts). The markdown spec is the source of truth for instructions; the JSON
is the source of truth for state. JSON fields:

```json
{
  "id": "T001-add-email-validation",
  "title": "...",
  "status": "queued",
  "attempt": 1,
  "tier": "default",
  "scope": ["src/auth/**"],
  "depends_on": [],
  "created_at": "...", "updated_at": "...",
  "history": [{"at": "...", "event": "created"}],
  "runner": {"pid": 123, "started_at": "..."}
}
```

(`runner` present only while running.)

### Lifecycle

Statuses: `queued, running, needs_review, needs_decision, blocked, failed,
done, cancelled`.

- Workers set only `needs_review | needs_decision | blocked | failed`, via
  `relay task finish`, only from `running`, and `needs_review` requires the
  attempt's report file to exist. The CLI enforces all of this.
- Only `relay task accept` sets `done`, only from `needs_review`.
- `return --reason` re-queues from any worker-final status, increments
  `attempt`, and appends the reason to the spec's `## Review feedback`.
- `decide --answer` re-queues from `needs_decision` and appends the answer to
  the spec's `## Decisions`.
- A worker that exits without setting a valid status is auto-marked `failed`
  (reason `invalid_worker_output`).
- Retries reuse the task id with a bumped attempt; changed scope means a new
  task.

## Parallel scheduling (scope leases)

Every task declares `scope`: file globs it may modify (`**` supported). Empty
scope means the whole project. `relay run` launches, concurrently, up to
`max_parallel` queued tasks such that:

1. every `depends_on` is `done`;
2. the task's scope is pairwise-disjoint from every co-scheduled task and
   every still-running task.

Disjointness is decided conservatively by static glob prefixes: two scopes
overlap unless no prefix of one is a prefix of the other (`src/auth/**` vs
`src/billing/**` co-run; `src/**` conflicts with both; empty conflicts with
everything). False positives (needless serialization) are acceptable; false
negatives (two workers on the same file) are not.

Rationale: independent tasks in parallel cost the same tokens as serial —
billing is per token per request on every major provider — but take a fraction
of the wall-clock time. Serialization is only for preventing rework on
dependent or overlapping tasks. `max_parallel = 1` reproduces strict serial
behavior.

Runner duties, per task: write the generated prompt to `work/<id>/`; set
status `running` with pid; launch the configured command with the prompt
substituted shell-quoted into `{prompt}` or `{prompt_file}`; export
`RELAY_TASK_ID`, `RELAY_ATTEMPT`, `RELAY_DIR`, `RELAY_ROOT`; capture combined
output to the attempt log; enforce `worker_timeout_minutes`; on exit, write
the scope-limited diff artifact and validate the worker's final status.

Per-wave duties: record a baseline of dirty files before launch; after the
wave, warn about changed files that fall outside every launched scope
(unattributed changes must be triaged before acceptance). Stale runners
(recorded pid dead) are surfaced by `status`/`validate` and cleared by
`task unlock` — never auto-cleared.

Git: required for parallel waves; diffs come from `git diff` limited to scope
plus `--no-index` diffs for untracked in-scope files. Without git the runner
forces serial mode and produces best-effort snapshot diffs of in-scope files.

## Worker launch prompt

Generated, small, and pointer-based — it names the task, scope, report path,
and finish command, and directs the worker to read `worker.md` and its spec
from disk. It never inlines the protocol or the spec. It warns that peers may
be running (no repo-wide formatters/migrations/full test suites unless the
spec says so).

## Review model

Diff-first: report, then scope diff, full files only when needed. High-risk
changes may get a read-only review task run by a fresh worker. The
orchestrator must review before accepting; nothing auto-accepts.

## Memory

One `memory.md`: compact index at top (`- M001 [W|O|B] summary`), detailed
entries below (`### M001 ...`). Agents read the index first and load entries
selectively by id. Entries are rare, durable, high-signal; never task
progress. `relay memory index [--for worker|orchestrator] | show | add`.

## Config

TOML. `[commands].worker` command template (placeholders `{prompt}`,
`{prompt_file}`); optional `[tiers.<name>].command` overrides selected by the
task's `tier` (fallback to default); `[limits]` `max_parallel`,
`max_extra_files`, `worker_timeout_minutes`. Agent-CLI-agnostic: any command
that accepts a prompt works. Never guess CLI flags — verify against the
installed CLI's `--help` before wiring a default.

## Safety invariants

Workers cannot mark done, ask the human, spawn sub-agents, leave scope, add
dependencies, run destructive commands, or touch auth/payment/security code
without explicit spec approval. Scope violations are detected post-run and
block acceptance. Planning docs like `roadmap.md` are human-facing only.

## Verification bar

A generated or modified implementation is acceptable only after real command
output shows: init into a temp git project (idempotent gitignore); task
create/list/show; a dry-run wave that respects scope conflicts and
dependencies; a real wave with a stub worker command proving parallel launch,
report/finish enforcement, diff artifacts, and `invalid_worker_output` on a
bad worker; accept/return/decide transitions (including the accept-from-
needs_review-only rule); memory add/index/show; archive; validate; and stale-
runner unlock. The repository ships this as `tests/smoke.sh`.
