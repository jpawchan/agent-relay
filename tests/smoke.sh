#!/usr/bin/env bash
# Agent Relay smoke test — exercises the verification bar in docs/spec.md.
# Usage: tests/smoke.sh   (from anywhere; needs python3 + git)
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
RELAY_SRC="$HERE/framework/relay"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0

ok()   { PASS=$((PASS+1)); echo "ok  $1"; }
fail() { echo "FAIL $1"; exit 1; }
expect_fail() { if "$@" >/dev/null 2>&1; then return 1; else return 0; fi; }

# ---------------------------------------------------------------- stub worker
cat > "$TMP/stub.py" <<'PY'
import json, os, sys, time, subprocess
mode = os.environ.get("STUB_MODE", "ok")
rd, tid, att = os.environ["RELAY_DIR"], os.environ["RELAY_TASK_ID"], os.environ["RELAY_ATTEMPT"]
root = os.environ["RELAY_ROOT"]
if mode == "bad":
    sys.exit(0)  # exits without report or status -> invalid_worker_output
task = json.load(open(os.path.join(rd, "tasks", tid + ".json")))
time.sleep(2)  # long enough to prove waves overlap
if mode == "ok":
    scope = (task.get("scope") or ["misc/**"])[0]
    prefix = scope.split("*")[0].rstrip("/") or "misc"
    os.makedirs(os.path.join(root, prefix), exist_ok=True)
    with open(os.path.join(root, prefix, tid + ".txt"), "a") as f:
        f.write("attempt %s\n" % att)
    report = os.path.join(rd, "work", tid, "attempt-%s.report.md" % att)
    os.makedirs(os.path.dirname(report), exist_ok=True)
    with open(report, "w") as f:
        f.write("# %s report — attempt %s\n\n## Result\nneeds_review\n\n"
                "## Summary\nStub change in %s.\n\n## Verification\n- none: stub\n" % (tid, att, prefix))
    status = "needs_review"
else:
    status = "needs_decision"
subprocess.run([sys.executable, os.path.join(rd, "relay"), "task", "finish",
                tid, "--status", status, "--note", "stub " + mode],
               cwd=root, check=True)
PY

# ---------------------------------------------------------------- init
PROJ="$TMP/proj"
mkdir -p "$PROJ"
git -C "$PROJ" init -q
"$RELAY_SRC" init "$PROJ" >/dev/null
[ -x "$PROJ/.agent-relay/relay" ] || fail "init: relay not copied/executable"
[ -f "$PROJ/.agent-relay/orchestrator.md" ] || fail "init: docs missing"
[ -f "$PROJ/.agent-relay/config.toml" ] || fail "init: config.toml missing"
grep -qx '.agent-relay/' "$PROJ/.gitignore" || fail "init: gitignore entry missing"
"$RELAY_SRC" init "$PROJ" >/dev/null
[ "$(grep -c '.agent-relay/' "$PROJ/.gitignore")" = 1 ] || fail "init: gitignore not idempotent"
ok "init + idempotent gitignore"

cd "$PROJ"
RELAY=".agent-relay/relay"
python3 - "$PROJ/.agent-relay/config.toml" "$TMP/stub.py" <<'PY'
import sys, re
path, stub = sys.argv[1], sys.argv[2]
text = open(path).read()
text = re.sub(r'worker = .*', 'worker = "python3 %s {prompt_file}"' % stub, text, count=1)
text = re.sub(r'max_parallel = \d+', 'max_parallel = 3', text)
open(path, "w").write(text)
PY

# ---------------------------------------------------------------- tasks
"$RELAY" task create --title "alpha one" --scope 'alpha/**' >/dev/null
"$RELAY" task create --title "beta one"  --scope 'beta/**'  >/dev/null
"$RELAY" task create --title "alpha two" --scope 'alpha/**' --depends-on T001-alpha-one >/dev/null
"$RELAY" task list | grep -q T001-alpha-one || fail "task list"
ok "task create/list"

DRY="$("$RELAY" run --dry-run)"
echo "$DRY" | grep -q 'would run: T001-alpha-one, T002-beta-one' || fail "dry-run wave wrong: $DRY"
echo "$DRY" | grep -q 'skip T003-alpha-two: waiting on' || fail "dry-run dep skip wrong: $DRY"
ok "dry-run respects deps + scopes"

# ---------------------------------------------------------------- parallel wave
START=$(date +%s)
"$RELAY" run >/dev/null
ELAPSED=$(( $(date +%s) - START ))
[ "$ELAPSED" -lt 4 ] || fail "wave took ${ELAPSED}s — workers did not run in parallel"
"$RELAY" task show T001-alpha-one | grep -q '"status": "needs_review"' || fail "T001 not needs_review"
"$RELAY" task show T002-beta-one  | grep -q '"status": "needs_review"' || fail "T002 not needs_review"
[ -s ".agent-relay/work/T001-alpha-one/attempt-1.report.md" ] || fail "T001 report missing"
[ -s ".agent-relay/work/T001-alpha-one/attempt-1.diff" ] || fail "T001 diff missing/empty"
grep -q 'alpha/T001-alpha-one.txt' ".agent-relay/work/T001-alpha-one/attempt-1.diff" || fail "diff lacks scoped file"
ok "parallel wave (${ELAPSED}s for 2x2s workers) + reports + diffs"

# ---------------------------------------------------------------- lifecycle rules
expect_fail "$RELAY" task accept T003-alpha-two || fail "accepted a queued task"
expect_fail "$RELAY" task finish T003-alpha-two --status needs_review || fail "finished a non-running task"
"$RELAY" task accept T001-alpha-one --note "reviewed" >/dev/null
"$RELAY" task accept T002-beta-one >/dev/null
ok "accept rules enforced"

"$RELAY" run >/dev/null   # T003 now runnable (dep done)
"$RELAY" task show T003-alpha-two | grep -q needs_review || fail "T003 did not run after dep done"
"$RELAY" task return T003-alpha-two --reason "smoke feedback" >/dev/null
grep -q "smoke feedback" ".agent-relay/tasks/T003-alpha-two.md" || fail "return feedback not in spec"
"$RELAY" run T003-alpha-two >/dev/null
"$RELAY" task show T003-alpha-two | grep -q '"attempt": 2' || fail "attempt not bumped"
"$RELAY" task accept T003-alpha-two >/dev/null
ok "return -> re-run -> accept"

# ---------------------------------------------------------------- needs_decision
"$RELAY" task create --title "asks a question" --scope 'gamma/**' >/dev/null
STUB_MODE=ask "$RELAY" run T004-asks-a-question >/dev/null
"$RELAY" task show T004-asks-a-question | grep -q needs_decision || fail "needs_decision not set"
"$RELAY" task decide T004-asks-a-question --answer "use option A" >/dev/null
grep -q "use option A" ".agent-relay/tasks/T004-asks-a-question.md" || fail "decision not in spec"
"$RELAY" run T004-asks-a-question >/dev/null
"$RELAY" task accept T004-asks-a-question >/dev/null
ok "needs_decision -> decide -> re-run"

# ---------------------------------------------------------------- bad worker
"$RELAY" task create --title "bad worker" --scope 'delta/**' >/dev/null
STUB_MODE=bad "$RELAY" run T005-bad-worker >/dev/null
"$RELAY" task show T005-bad-worker | grep -q '"status": "failed"' || fail "bad worker not failed"
"$RELAY" task show T005-bad-worker | grep -q invalid_worker_output || fail "failure reason missing"
"$RELAY" task cancel T005-bad-worker --reason "smoke" >/dev/null
ok "invalid_worker_output detected"

# ---------------------------------------------------------------- stale runner
"$RELAY" task create --title "stale runner" --scope 'eps/**' >/dev/null
python3 - ".agent-relay/tasks/T006-stale-runner.json" <<'PY'
import json, sys
t = json.load(open(sys.argv[1]))
t["status"] = "running"; t["runner"] = {"pid": 999999, "started_at": "x"}
json.dump(t, open(sys.argv[1], "w"))
PY
"$RELAY" status | grep -q STALE || fail "stale runner not reported"
expect_fail "$RELAY" validate || fail "validate missed stale runner"
"$RELAY" task unlock T006-stale-runner >/dev/null
"$RELAY" task show T006-stale-runner | grep -q '"status": "failed"' || fail "unlock did not fail task"
"$RELAY" task cancel T006-stale-runner >/dev/null
ok "stale runner: status/validate/unlock"

# ---------------------------------------------------------------- memory + archive
"$RELAY" memory add --for worker "Use tabs in this repo" "Long explanation." >/dev/null
"$RELAY" memory add --for orchestrator "Split UI work by page" "Details." >/dev/null
"$RELAY" memory index --for worker | grep -q M001 || fail "memory index"
[ "$("$RELAY" memory index --for worker | wc -l | tr -d ' ')" = 1 ] || fail "audience filter"
"$RELAY" memory show M002 | grep -q "Details." || fail "memory show"
"$RELAY" validate >/dev/null || fail "validate not clean"
"$RELAY" archive | grep -q 'archived 6' || fail "archive count wrong"
[ -z "$(ls .agent-relay/tasks)" ] || fail "tasks left behind after archive"
ok "memory + validate + archive"

echo
echo "PASS — all $PASS groups"
