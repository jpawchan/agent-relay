# Agent Relay project guide

## What and why

Agent Relay is a dependency-free Python CLI for delegating scoped coding tasks to fresh agent processes.
One orchestrator creates tasks, starts dependency-ready workers, and reviews each report and Git diff.
Non-overlapping tasks can run in parallel while one orchestrator keeps the project-level view.
It is for Git projects that need explicit task boundaries, retryable review, and local state without a server.
It coordinates worker CLIs; it is not an agent model, package manager, patch queue, or security sandbox.

## Current state

- Canonical local root: `/Users/naz/agent-relay-review`.
- Remote: `https://github.com/jpawchan/agent-relay.git`, branch `main`.
- Published `main` commit before this guide: `1e92e20dadae20091647fb54af4e043c79e3bc45`.
- Local `HEAD` matched remote `main` before `summary.md` was created.
- `summary.md` is the only intended uncommitted project change from this update.
- The ready-to-run implementation is `framework/relay`; it is complete rather than a scaffold.
- Local verification on 2026-07-11: all 26 end-to-end tests passed in 32.774 seconds.
- Syntax verification passed for `framework/relay` and `tests/test_relay.py`.
- A temporary installation initialized, validated, and reported zero tasks successfully.
- GitHub Actions tests Python 3.11 and 3.13 on Ubuntu and macOS.
- The latest CI run for the published commit passed all four matrix jobs.
- No package installation, build step, daemon, database, HTTP server, schema, or migration system exists.
- No known unfinished product path or confirmed bug remains in the tracked source.
- Known design limits are listed under Landmines; do not present them as bugs or silently remove them.
- The last published change rewrote `README.md` and the GitHub description around verified behavior.

## Run and verify

Run all development commands from the repository root:

```bash
cd /Users/naz/agent-relay-review
python3 --version
git --version
```

Requirements are Python 3.11+, Git on `PATH`, macOS or Linux, and a target Git root without submodules.
There is no dependency install or build command.

Run the verified local checks:

```bash
python3 framework/relay --help
python3 -m py_compile framework/relay tests/test_relay.py
python3 tests/test_relay.py
```

Expected evidence:

```text
usage: relay [-h] {init,task,run,status,validate,archive,memory} ...
# py_compile is silent and exits 0
Ran 26 tests in ...
OK
```

The suite takes about 33 seconds, uses temporary Git repos and stub workers, and makes no agent or network call.
Use this disposable smoke test after changing initialization or configuration:

```bash
tmp=$(mktemp -d "${TMPDIR:-/tmp}/agent-relay-guide.XXXXXX")
git -C "$tmp" init -q
git -C "$tmp" config user.name GuideCheck
git -C "$tmp" config user.email guide@example.invalid
python3 -c 'from pathlib import Path; import sys; Path(sys.argv[1], "seed.txt").write_text("seed\\n")' "$tmp"
git -C "$tmp" add seed.txt
git -C "$tmp" commit -qm seed
./framework/relay init "$tmp"
"$tmp/.agent-relay/relay" validate
"$tmp/.agent-relay/relay" status
rm -rf "$tmp"
```

Expected lines are `ok: 0 active task(s)` and `tasks: none`.
Install into a real target only when required:

```bash
./framework/relay init /absolute/path/to/git-worktree-root
```

This creates `.agent-relay/`, adds it to the target `.gitignore`, and copies `config.toml` plus the manuals.
Relay is not a service, so it has no start/stop command; `relay run` blocks until its wave exits.
Ctrl-C stops worker groups and exits 130; SIGTERM/SIGHUP use `128 + signal`.
Do not smoke-test a real worker unless its CLI and credentials are configured.

## Stack

| Layer | Verified implementation |
| --- | --- |
| Language | Python 3.11+; executable source is `framework/relay`. |
| Dependencies | Python standard library only; there is no dependency manifest or lockfile. |
| CLI | `argparse` subcommands built by `build_parser()` in `framework/relay`. |
| Concurrency | `ThreadPoolExecutor` launches worker subprocesses for one selected wave. |
| Processes | `subprocess.Popen(..., start_new_session=True)` gives each worker a process group. |
| Locking | POSIX `fcntl.flock`; this is one reason Windows is unsupported. |
| Signals | `signal`, `os.killpg`, and `signal.pthread_sigmask`. |
| Configuration | TOML parsed by Python 3.11 `tomllib`. |
| Runtime state | JSON task records plus Markdown task specs, reports, memory, logs, and diffs. |
| Version control | Git CLI snapshots, trees, and diffs; Relay does not use a Git library. |
| Tests | `unittest` with temporary Git repositories and embedded Python worker fixtures. |
| CI | GitHub Actions: `checkout@v7`, `setup-python@v6`, Ubuntu/macOS, Python 3.11/3.13. |
| License | MIT, in `LICENSE`. |

Relay itself makes no HTTP requests and has no external API integration.
The configured worker command is the only connection to Hermes, Codex, Claude Code, or another agent CLI.

## Repository map

### Root

| Path | Role |
| --- | --- |
| `framework/relay` | Entire production CLI: paths, config, tasks, scopes, Git snapshots, runner, validation, archive, memory, parser. |
| `tests/test_relay.py` | Canonical 26-test end-to-end suite and all stub worker fixtures. |
| `SPEC.md` | Normative behavioral contract; every implementation and prompt promise must match it. |
| `README.md` | User-facing explanation, installation, workflow, commands, repository map, and limits. |
| `summary.md` | Coding-agent orientation and change-routing guide; keep it current with code. |
| `.github/workflows/ci.yml` | Only CI workflow and its operating-system/Python matrix. |
| `.gitignore` | Ignores caches, `.DS_Store`, and installed `.agent-relay/` runtime state. |
| `LICENSE` | MIT license text. |

### Framework templates

| Path | Role |
| --- | --- |
| `framework/config.example.toml` | Default worker command and execution limits copied to runtime `config.toml`. |
| `framework/orchestrator.md` | Operating manual for task creation, waves, review, failure handling, and memory. |
| `framework/worker.md` | Worker contract: scope, targeted checks, short report, and exact changed paths. |
| `framework/memory.md` | Empty indexed-memory template copied on first initialization. |

### Prompts and skill

| Path | Role |
| --- | --- |
| `prompts/create-framework.md` | Standalone generation prompt with an embedded exact copy of `SPEC.md`. |
| `prompts/improve-framework.md` | Review prompt naming the required safety and concurrency checks. |
| `prompts/use-framework.md` | Six-line instruction that activates an installed orchestrator. |
| `skill/SKILL.md` | Portable skill metadata, install command, use cases, and invariants. |

### Production code regions

| Concern | Start with these functions in `framework/relay` |
| --- | --- |
| Runtime discovery and safe paths | `find_relay_dir`, `runtime_paths_are_safe`, `require_relay_dir`. |
| Durable state and locks | `file_lock`, `task_lock`, `atomic_write`, `atomic_json`. |
| Config and worker argv | `load_config`, `configured_limits`, `command_template`, `worker_argv`. |
| Task persistence | `load_task`, `save_task`, `record`, `load_all_tasks`, `load_archived_tasks`. |
| Scope parsing and matching | `normalize_scope`, `scopes_overlap`, `scope_pattern_matches`, `path_in_scopes`. |
| Task commands | Functions named `cmd_task_*`. |
| Git safety and snapshots | `require_git_root`, `git_snapshot`, `git_changed_paths`, `git_tree_diff`. |
| Worker launch | `WORKER_PROMPT`, `build_prompt`, `prepare_worker`, `run_one_worker`. |
| Scheduling and finalization | `pick_wave`, `finalize_task`, `cmd_run`, `run_wave`. |
| Validation | `dependency_cycles`, `task_problems`, `cmd_validate`. |
| Archive | `cmd_archive`. |
| Memory | `cmd_memory_index`, `cmd_memory_show`, `cmd_memory_add`. |
| Installation and CLI | `cmd_init`, `build_parser`, `main`. |

### Change routing

| Task type | Files to inspect or change first |
| --- | --- |
| Fix task lifecycle or scheduler bug | `framework/relay`, matching cases in `tests/test_relay.py`. |
| Add or change a CLI command | `framework/relay`, `tests/test_relay.py`, `framework/orchestrator.md`, `README.md`, `SPEC.md`. |
| Change scope syntax or attribution | `framework/relay`, scope/attribution tests, `framework/worker.md`, `framework/orchestrator.md`, `SPEC.md`. |
| Change worker launch protocol | `framework/relay`, `framework/worker.md`, `framework/config.example.toml`, worker fixtures, `SPEC.md`. |
| Change default configuration | `framework/config.example.toml`, config functions in `framework/relay`, config tests, `SPEC.md`. |
| Change runtime file layout | `cmd_init` and path helpers, manuals, tests, `README.md`, `SPEC.md`. |
| Change memory format | Memory functions, `framework/memory.md`, both manuals, memory test, `SPEC.md`. |
| Change archive behavior | `cmd_archive`, archive tests, orchestrator failure guidance, `SPEC.md`. |
| Change supported platforms or Python | `framework/relay`, CI, tests, README, skill, prompts, and `SPEC.md`. |
| Change normative behavior | Update `SPEC.md`, regenerate its embedded copy in `prompts/create-framework.md`, then run the full suite. |
| Change public positioning only | `README.md`; keep claims within behavior proven by code and tests. |

## How it works

### Runtime layout after `relay init`

```text
<git-root>/.agent-relay/
├── relay                  copied production executable
├── orchestrator.md        copied orchestrator manual
├── worker.md              copied worker contract
├── memory.md              durable indexed project facts
├── config.toml            user-managed worker command and limits
├── tasks/                 active `<id>.json` state and `<id>.md` specs
├── work/<id>/             per-attempt prompt, log, report, result, and diff
├── archive/               done/cancelled task state and `<id>.work/`
└── .locks/                scheduler, execution, memory, and per-task lock files
```

`.agent-relay/` is local and Git-ignored; deleting it deletes task state, reports, logs, and memory.

### End-to-end flow

```text
user goal
   |
   v
orchestrator agent reads orchestrator.md
   |
   v
task create -> tasks/T###-slug.{json,md}
   |
   v
run --dry-run -> dependency and case-folded scope selection
   |
   v
run -> execution lock -> scheduler lock -> lease tasks -> baseline Git tree
   |
   +--> worker process A -- edits shared tree -- report/result -- exits
   +--> worker process B -- edits shared tree -- report/result -- exits
   |
   v
post-wave Git tree -> changed paths -> scoped diffs + violation diff
   |
   v
finalize lease/result/report/path declarations -> terminal worker status
   |
   v
orchestrator reviews report + diff -> accept | return | decide | cancel
```

### Initialization

`cmd_init` requires the target directory to be the actual Git worktree root.
It rejects tracked Gitlinks/submodules and unsafe symlink layouts.
It copies `relay`, both manuals, the memory template, and the config template.
It creates `tasks`, `work`, `archive`, and `.locks`.
It adds `.agent-relay/` to `.gitignore` once.
Without `--force`, existing static files are left in place.
With `--force`, only `relay` and the two manuals refresh; config, memory, tasks, work, and archive survive.

### Task creation and state

`task create` holds the scheduler lock and assigns `T###-slug` monotonically across active and archived tasks.
The JSON record stores id, title, status, attempt, tier, scopes, dependencies, timestamps, and history.
The Markdown spec stores objective, acceptance criteria, context, restrictions, verification, decisions, and feedback.
An omitted scope or `.` normalizes to an empty scope list meaning the whole project.
Dependencies must name existing tasks and cannot repeat, self-reference, or point to cancelled work.

Task statuses:

```text
queued -> running -> needs_review -> done
                  -> needs_decision -> queued (new attempt)
                  -> blocked       -> queued (after repair and return)
                  -> failed        -> queued (after return)
queued/attention state -> cancelled
```

Workers can submit only `needs_review`, `needs_decision`, `blocked`, or `failed`.
Only the orchestrator can record `done` through `task accept`.

### Scheduling and execution

`pick_wave` selects queued tasks whose dependencies are done and whose scopes do not overlap a running or selected task.
Done dependencies remain valid after archive.
`max_parallel` limits one wave; tasks beyond it wait.
A real `run` holds the execution lock from the first snapshot through finalization.
Separate `run` processes therefore serialize; concurrency exists only inside one wave.
`run --dry-run` takes no execution lock and prints every selected or skipped task.
Each run generates one random lease shared by its claimed tasks.
Each worker gets its task id, attempt, lease, runtime path, and project root through environment variables.
Worker stdout and stderr share `attempt-N.log`.
Timeout or interruption terminates worker process groups, not only direct child processes.

### Git snapshots and scope enforcement

`git_snapshot` uses a temporary `GIT_INDEX_FILE`; it does not use or replace the user's real index.
The temporary index starts from `HEAD` or an empty tree, then runs `git add -A` and `git write-tree`.
This captures tracked and untracked Git-visible files, modes, deletions, binaries, and unborn repositories.
Git-ignored files are intentionally absent from snapshots and scope guarantees.
The generated tree is rejected if it contains mode `160000` Gitlinks.
Before/after tree ids define attempt-local changes, so pre-existing dirty work is not attributed to the wave.
Every changed path outside the union of wave scopes creates `attempt-N.violations.diff` and blocks the tasks.
Each task also gets `attempt-N.diff` limited to its own scope.
The worker's exact `--changed PATH` declarations must equal observed paths in its scope, case-insensitively.
A mismatch becomes `failed` with `changed_paths_mismatch`.

### Finalization and review

`task finish` only works inside a worker with matching task id, attempt, and lease.
A `needs_review` result requires a non-empty regular `attempt-N.report.md`.
The worker result JSON must contain valid status, note, timestamp, lease, and canonical changed-path list.
The task stays `running` until the worker process exits and Relay writes the final diff.
A stale finalizer cannot overwrite a newer attempt because status, attempt, and lease must still match.
The orchestrator reads `attempt-N.report.md` and `attempt-N.diff` before choosing a lifecycle command.
`task accept` records review and changes state to `done`; worker edits already exist in the shared tree.
`task return` increments the attempt and appends review feedback but does not revert prior edits.
Scope-violating paths must match the pre-wave state before a blocked task can be returned.
`task decide` appends the answer and queues a new attempt.
`task unlock` is only for a stale `running` record after its worker PID is confirmed dead.

### Validation, memory, and archive

`validate` checks Git root/submodules, config shape, ids, statuses, fields, dependencies, cycles, scopes, runners, reports, and violations.
It also rejects duplicate task ids/numbers and overlapping active runners.
`memory.md` stores durable facts with `W`, `O`, or `B` audience tags and monotonic `M###` ids.
Workers load only memory ids referenced by their task spec; memory is not copied into every prompt.
`archive` moves done/cancelled JSON, Markdown, and work directories into `archive/`.
Archive preflights every destination before moving anything.
Signals are blocked during the short move transaction; failures roll completed moves back in reverse order.

## Configuration

### Source and installed files

| File | Purpose | Read by |
| --- | --- | --- |
| `framework/config.example.toml` | Source default copied on first initialization. | `cmd_init`. |
| `.agent-relay/config.toml` | Per-project worker command, tiers, parallel limit, and timeout. | `load_config`, `run_wave`, `prepare_worker`. |
| `framework/memory.md` | Source empty memory layout. | `cmd_init`. |
| `.agent-relay/memory.md` | Installed durable memory and audience index. | Memory commands and agent manuals. |

There is no `.env` file and Relay reads no API key or credential variable.
Worker credentials belong to the configured external CLI, outside Relay.

### TOML keys

| Name | Purpose |
| --- | --- |
| `commands.worker` | Default worker argv template; example is Hermes with `{prompt}`. |
| `limits.max_parallel` | Positive integer wave size; default fallback is 3. |
| `limits.worker_timeout_minutes` | Non-negative numeric timeout; 0 disables timeout. |
| `tiers.<name>.command` | Optional command override selected by a task's `tier`; missing tiers fall back to `commands.worker`. |

`relay run --max-parallel N` overrides `limits.max_parallel` for that invocation.
The worker template must contain exactly one complete `{prompt}` or `{prompt_file}` argument.
`shlex.split` parses it and `Popen` executes the argv directly without a shell.
Shell operators, pipes, redirection, variable expansion, and command substitution do not work.
Use an explicit wrapper executable when shell-like preparation is unavoidable.

### Environment variables

| Name | Direction | Purpose and read site |
| --- | --- | --- |
| `RELAY_DIR` | Optional input and worker export | `find_relay_dir` override; workers receive the installed runtime path. |
| `RELAY_TASK_ID` | Worker export | Binds the process to one task and blocks orchestrator-only commands. |
| `RELAY_ATTEMPT` | Worker export | Binds result submission to the current attempt. |
| `RELAY_LEASE` | Worker export | Prevents stale or foreign result/finalizer writes. |
| `RELAY_ROOT` | Worker export | Absolute target Git root used by the worker. |

Without `RELAY_DIR`, Relay searches from the current directory upward for `.agent-relay/`.
When the executable itself is inside `.agent-relay/`, its own directory is the final fallback.

## Landmines

- Do not add runtime dependencies casually; dependency-free installation is a tested project constraint.
- Do not claim Windows support without replacing `fcntl`, process-group signals, and `pthread_sigmask` behavior.
- Do not run Relay from a nested directory at initialization; the target must equal `git rev-parse --show-toplevel`.
- Do not add tracked submodules; Gitlinks in `HEAD`, the index, or generated snapshots are rejected.
- Do not replace temporary-index snapshots with `git diff HEAD`; that would misattribute existing dirty work and mishandle unborn repos.
- Do not include ignored files in snapshots without a secret/build-output policy; current workers are forbidden to modify ignored paths.
- Do not treat scopes as case-sensitive on Linux; all matching and overlap checks deliberately case-fold across supported systems.
- Do not make overlap detection more permissive without proving safety; fixed prefixes may serialize work conservatively by design.
- Do not assume workers have isolated worktrees; every worker in a wave edits one shared project tree.
- Do not describe role checks as a sandbox; workers run as the same operating-system user and can bypass cooperative rules.
- Do not make `accept` apply a patch; acceptance records review because edits are already present.
- Do not assume `return` reverts an attempt; retries inherit the current tree and receive prior report context.
- Do not finalize immediately when `task finish` runs; late in-scope edits before process exit must appear in the attempt diff.
- Do not remove exact changed-path declarations; they detect cross-scope attribution failures in the shared tree.
- Do not accept a path declaration that differs only by unnormalized spelling; canonical storage and case-folded comparison are deliberate.
- Do not weaken lease checks; old workers and stale finalizers must not mutate a newer attempt.
- Keep lock acquisition order consistent: scheduler/execution locks wrap task locks in the commands that need both.
- Do not run multiple snapshot windows concurrently; the execution lock protects before/after attribution.
- Do not kill workers one by one with separate grace periods; all process groups are signalled before one shared wait.
- Do not remove archive destination preflight; partial archive moves were a prior failure mode.
- Do not let termination interrupt the archive move set; masking plus rollback keeps active/archive state consistent.
- Do not allow symlinks under managed runtime paths; every command validates the runtime tree before reading or writing state.
- Do not parse task JSON without handling malformed UTF-8 as well as malformed JSON.
- Do not hand-edit task JSON; use lifecycle commands so history, attempts, leases, and locks remain coherent.
- Do not reuse task numbers after archive; `next_task_id` scans active and archived state.
- Do not edit only `SPEC.md`; `prompts/create-framework.md` embeds it exactly between `BEGIN SPEC` and `END SPEC` markers.
- The test `test_memory_archive_and_prompt_spec_alignment` fails when the embedded contract drifts.
- Keep the default Hermes token order `... --source tool -q {prompt}`; `-q` must receive the prompt argument.
- A worker command can be provider-agnostic only if it accepts one non-interactive prompt or prompt-file argument.
- Running the default Hermes command can fail for external quota, authentication, or provider reasons unrelated to Relay parsing.
- `summary.md` is orientation, not the normative contract; update code/tests/spec first when behavior changes.

## Guide self-test routes

| Plausible task | Guide-only starting route |
| --- | --- |
| Fix wildcard scope matching | `scope_pattern_matches` and `path_in_scopes` in `framework/relay`; scope tests in `tests/test_relay.py`; change `SPEC.md` and its embedded prompt only if semantics change. |
| Add task pause/resume | `STATUSES`, task handlers, `task_problems`, and `build_parser` in `framework/relay`; add cases in `tests/test_relay.py`; update `framework/orchestrator.md`, `framework/worker.md`, `README.md`, `SPEC.md`, and its embedded prompt. |
| Add per-tier timeout | `configured_limits`, `command_template`, and `run_wave` in `framework/relay`; update `framework/config.example.toml`, `tests/test_relay.py`, `SPEC.md`, and its embedded prompt; run syntax, full tests, and the smoke test. |

Last updated 2026-07-11 — created a code-verified guide covering current state, commands, architecture, configuration, routing, and landmines.
