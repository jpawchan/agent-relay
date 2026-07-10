# Prompt: create the Agent Relay framework

Copy this whole file and give it to a capable coding agent. It contains the
complete specification. No other file is needed.

---

You are a senior software engineer. Build a small delegation framework for
coding agents, called Agent Relay. You must deliver working, tested code, not
a design document.

## What you are building

Agent Relay lets one orchestrator agent hand out coding tasks to worker
agents. The orchestrator talks to the human, splits goals into small tasks,
and reviews all results. Each worker is a fresh agent session that sees only
its own task. Tasks that touch different files run at the same time.

The purpose is better code at lower token cost. Both come from the same
design: workers get small, focused contexts instead of a long shared history;
tasks are explicit and scoped; review happens on diffs; lessons are stored in
an indexed memory file and loaded selectively.

On parallelism, know the facts: API providers bill per token, per request.
Running two independent tasks at the same time costs the same as running them
one after another. What wastes tokens is rework — two workers editing the
same files, or a task running before the task it depends on. So the scheduler
must prevent exactly that, and nothing more.

## Ground rules

- The whole framework is one dependency-free Python file (standard library
  only, Python 3.8+) plus Markdown and TOML files.
- No daemon, no database, no UI, no background service, no third-party
  packages, no plugin system. If you feel tempted, stop.
- Never guess agent CLI flags. Before writing any worker command into config
  or docs, run the installed CLI's `--help` and use only flags you saw there.
  If a CLI is not installed, mark its example command as unverified.
- Prefer deleting code to adding it. Boring beats clever.

## The runtime directory

`relay init <project>` creates a hidden, disposable directory inside the
target project:

```
.agent-relay/
  relay              the CLI itself (copied in, executable)
  orchestrator.md    manual for the orchestrator agent
  worker.md          contract for worker agents, short enough to read per task
  memory.md          one indexed memory file
  config.toml        worker command, tiers, limits (copied from an example)
  tasks/             per task: <id>.md (the spec) and <id>.json (the state)
  work/<id>/         per attempt: prompt, log, report, diff
  archive/           finished tasks, moved out of the way
```

Init must not overwrite existing files unless given `--force`. In a git repo
it appends `.agent-relay/` to `.gitignore`, exactly once, even if run twice.
In a non-git project it must not create a `.gitignore`.

## Tasks

Task ids look like `T001-short-slug`: auto-incremented number plus a slug
from the title. Numbers are never reused, even after archiving.

The markdown file is the source of truth for instructions. The JSON file is
the source of truth for state. Never mix the two. JSON fields:

```json
{
  "id": "T001-add-email-validation",
  "title": "Add email validation",
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

`runner` exists only while a worker is running. The generated markdown spec
should have sections for: objective, acceptance criteria, context, what is
not allowed, verification commands, decisions, and review feedback.

## Lifecycle

Statuses: `queued, running, needs_review, needs_decision, blocked, failed,
done, cancelled`.

The CLI enforces these rules; prose in the docs is not enough:

- Workers may only set `needs_review`, `needs_decision`, `blocked`, or
  `failed`, only through a `finish` command, and only from `running`.
- `needs_review` is refused if the attempt's report file does not exist.
- Only an `accept` command sets `done`, and only from `needs_review`.
- A `return --reason` command re-queues a task from any worker-final status,
  increments `attempt`, and appends the reason to the spec's review feedback
  section, so the next attempt can read it.
- A `decide --answer` command re-queues from `needs_decision` and appends the
  answer to the spec's decisions section.
- A worker process that exits without setting a valid status is marked
  `failed` with reason `invalid_worker_output`.
- Retries keep the task id and bump `attempt`. A changed scope means a new
  task.

## Scheduling: parallel workers without conflicts

Every task declares `scope`: the file globs it may modify (`**` supported).
An empty scope means the whole project.

`relay run` launches, at the same time, up to `max_parallel` queued tasks
where:

1. every task in `depends_on` is `done`, and
2. the task's scope is disjoint from the scope of every other task being
   launched or still running.

Decide disjointness conservatively, using static glob prefixes: take each
pattern's text up to its first wildcard; two scopes overlap unless no prefix
on one side is a prefix of a prefix on the other side. So `src/auth/**` and
`src/billing/**` may run together, `src/**` conflicts with both, and an empty
scope conflicts with everything. Being too cautious (needless waiting) is
fine. Letting two workers touch the same file is not.

`relay run --dry-run` must show which tasks would launch and why each of the
others is skipped. `max_parallel = 1` gives strict serial behavior.

## The runner

For each launched task, the runner must:

- write the generated worker prompt to `work/<id>/attempt-N.prompt.md`;
- set status `running` and record the worker's pid;
- launch the command from config, substituting the prompt shell-quoted into
  a `{prompt}` or `{prompt_file}` placeholder (refuse to run if the command
  has neither);
- pass env vars `RELAY_TASK_ID`, `RELAY_ATTEMPT`, `RELAY_DIR`, `RELAY_ROOT`;
- capture combined stdout/stderr to `work/<id>/attempt-N.log`;
- kill the worker after `worker_timeout_minutes` (0 = no limit);
- after exit, write a diff of the task's scope to `work/<id>/attempt-N.diff`
  and check the worker set a valid final status.

Per wave: record which files were already dirty before launch; after all
workers finish, warn about changed files that fall outside every launched
scope — those must be attributed before anything is accepted.

Stale runners (recorded pid no longer alive) must be visible in a `status`
command and a `validate` command, and cleared only by an explicit `unlock`
command. Never auto-clear.

Git: required for parallel waves. Diffs come from `git diff` limited to the
scope, plus `--no-index` diffs for new untracked files in scope. Without git,
force serial mode and produce best-effort snapshot diffs of in-scope files.

## The worker launch prompt

Generate it; keep it short; point at files instead of pasting them. It must
name the task and attempt, the scope, the report path, and the exact finish
command, and tell the worker to read `worker.md` and its task spec from disk.
It must warn that other workers may be running, so no repo-wide formatters,
migrations, or full test suites unless the spec says so. On attempt 2+, it
points at the previous report and the feedback in the spec.

## The two manuals

`orchestrator.md` is the complete operating manual. An agent that has read
only this file must be able to use the framework correctly. It covers: the
purpose and the quality-first tradeoff rule; how work flows; the directory
layout; how to write good task specs (scopes, dependencies, minimal context,
exact verification commands, tiers for risky work); how scheduling works and
why parallel waves cost the same tokens as serial; diff-first review and the
accept/return/decide commands; failure handling (bad workers, stale runners,
blocked tasks); memory discipline; the safety rules; and a command reference.

`worker.md` is the contract every worker reads at the start of its task. It
covers: the worker's loop (read spec, work, verify, report, finish); the hard
limits (stay in scope, never mark done, never ask the human — escalate with
`needs_decision` instead, never spawn sub-agents, no repo-wide operations, no
new dependencies or destructive commands without spec approval, match project
style, no secrets in reports, never hide a failing check); and the report
format (result, summary, files changed, verification results, decisions,
risks — under ~80 lines, no chain-of-thought).

## Memory

One `memory.md` file. A compact index at the top, one line per entry:
`- M001 [W] summary` where the tag is `W` (for workers), `O` (for the
orchestrator), or `B` (both). Full entries below under `### M001 ...`
headings. Commands: `memory index [--for worker|orchestrator]`,
`memory show <id>`, `memory add --for ... "summary" "body"`.

Agents read the index first and load entries by id. Memory is for rare,
durable, high-signal lessons — never task progress, never logs.

## Config

TOML, with a commented example file. `[commands] worker` is the launch
command template. Optional `[tiers.<name>] command` entries let a task's
`tier` field pick a different model or CLI; unknown tiers fall back to the
default. `[limits]` holds `max_parallel`, `max_extra_files` (files a worker
may inspect beyond its spec before escalating), and `worker_timeout_minutes`.

## How you must verify your work

Write a smoke test script and make it pass. It must show, with real command
output, in a temporary git project:

1. init works and the gitignore entry is not duplicated on a second init;
2. task create and list;
3. a dry run that respects both dependencies and scope conflicts;
4. a real wave where two disjoint tasks run at the same time (prove it with
   timing: two workers that sleep 2 seconds must finish in well under 4),
   with reports and scope-limited diffs on disk;
5. accepting a task that is not `needs_review` is refused; finishing a task
   that is not `running` is refused;
6. return with a reason, re-run, attempt bumped, accept;
7. the `needs_decision` round trip: worker asks, orchestrator decides,
   task re-runs;
8. a worker that exits silently is marked `failed` / `invalid_worker_output`;
9. a stale runner is reported by `status` and `validate` and cleared by
   `unlock`;
10. memory add, index with audience filter, show; then `validate` clean and
    `archive` moving all finished tasks.

Use a stub worker script for the test, not a real agent.

## Done means

The `relay` CLI and its template files exist; `relay init` produces the
runtime above; every lifecycle and scheduling rule is enforced by code; both
manuals are written; the smoke test passes; and your final report lists the
files you created, the exact test commands with their output, and any CLI
syntax you could not verify on this machine.
