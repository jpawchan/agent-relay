# Prompt: review and improve the framework

Copy this whole file and give it to a capable coding agent, in a project or
repository that already contains an Agent Relay implementation. No other file
is needed.

---

You are a skeptical senior engineer with write access. Another agent built or
modified an Agent Relay installation: a delegation framework where an
orchestrator agent splits coding work into scoped tasks, worker agents run in
parallel on non-overlapping file scopes, and every change is reviewed as a
diff before acceptance. Your job is to test it, fix what is broken, and
simplify what is overbuilt. Change the code directly; do not just write
comments.

## What a correct installation looks like

- One dependency-free Python CLI called `relay` plus Markdown/TOML files, in a
  hidden `.agent-relay/` directory (or a `framework/` directory in the source
  repository). No daemon, database, UI, or third-party packages.
- Runtime layout: `orchestrator.md` and `worker.md` manuals, one indexed
  `memory.md`, `config.toml`, `tasks/` with a markdown spec and a JSON state
  file per task, `work/<id>/` with prompt/log/report/diff per attempt, and
  `archive/`.
- Task lifecycle: `queued, running, needs_review, needs_decision, blocked,
  failed, done, cancelled`. Workers set only the middle four, only via
  `finish`, only from `running`, and `needs_review` requires the report file.
  Only `accept` sets `done`, only from `needs_review`. `return` and `decide`
  re-queue with a bumped attempt and append the reason or answer to the spec.
  A worker that exits without a valid status becomes `failed`
  (`invalid_worker_output`).
- Scheduling: tasks declare file-glob scopes and dependencies. `relay run`
  launches, concurrently, only queued tasks whose dependencies are done and
  whose scopes are pairwise disjoint (judged conservatively by static glob
  prefixes; an empty scope conflicts with everything). Diffs are captured per
  task, limited to its scope. After a wave, changes outside every launched
  scope are reported. Non-git projects run serial with snapshot diffs.
- Stale runners (dead pid still marked running) show up in `status` and
  `validate`, and only an explicit `unlock` clears them.

## How to test it

Run the repository's smoke test if there is one. Whether or not it exists,
verify these yourself in a throwaway git project, with a stub script as the
worker command:

1. init twice; the `.gitignore` entry must appear exactly once.
2. Create two tasks with disjoint scopes and a third that overlaps one of
   them and depends on the first. The dry run must pick the two disjoint
   tasks and explain why the third waits.
3. Run the wave. Both workers must run at the same time (verify with
   timing), and each must end with a report and a diff containing only its
   own files.
4. Try to break the lifecycle: accept a queued task, finish a task that is
   not running, finish `needs_review` without a report, set `done` as a
   worker. Every one of these must be refused.
5. Return a task with a reason; confirm the reason lands in the spec and the
   attempt number rises. Do the `needs_decision` round trip.
6. Make the stub exit silently; the task must become `failed` with reason
   `invalid_worker_output`.
7. Fake a dead pid on a running task; `status` and `validate` must flag it
   and `unlock` must clear it.
8. Exercise memory add/index/show (with the audience filter), `validate`,
   and `archive`.

## How to attack it

- Try to construct two tasks that could run at the same time on the same
  file. If you succeed, that is the most important bug in the system.
- Check the docs against the code: every command and rule promised in
  `orchestrator.md` and `worker.md` must actually exist and behave as
  written. Fix whichever side is wrong.
- Look for guessed CLI flags in config or docs. Verify each against the
  installed CLI's `--help`; mark unverifiable ones as such.
- Look for overbuilding: extra state files, unused options, speculative
  abstractions. Delete them.

## Report when done

What you changed and why; the exact commands you ran with pass/fail output;
anything still broken or unverifiable; and a clear yes or no: is this
installation ready for real orchestrator use.
