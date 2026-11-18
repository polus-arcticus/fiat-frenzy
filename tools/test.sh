#!/usr/bin/env bash
# Runs every test suite at once, each in its own process (the sim suite split into SHARDS processes), and prints one summary
# line per process. The scene and intro suites run with --fixed-fps 60: each frame is 1/60 s of game time however fast the
# machine draws it, so they never wait on the clock. About 12 s in all (the scene suite is the longest).
#   tools/test.sh            all three
#   tools/test.sh sim        just the model tests   (extra arguments go to tests/run.gd, e.g. --only=rescue; with them, one
#                            process)
#   tools/test.sh scene|intro
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/app-port/Godot_v4.7.2-stable_linux.x86_64}"
SHARDS="${SHARDS:-4}"
suite="${1:-all}"
[ $# -gt 0 ] && shift
out="$(mktemp -d)"
status=0

run() {  # name script [args...]
  local name="$1" script="$2"; shift 2
  # (a script that does not compile leaves Godot waiting instead of quitting: the timeout is what ends that, so it is short)
  timeout 120 "$GODOT" --headless --fixed-fps 60 --path . --script "$script" ${1:+-- "$@"} >"$out/$name.txt" 2>&1
  echo $? >"$out/$name.code"
}

sim() {  # the sim suite: in shards at once, or (with arguments, say --only) in one process
  if [ $# -gt 0 ]; then
    run sim tests/run.gd "$@"
  else
    for i in $(seq 0 $((SHARDS - 1))); do
      run "sim$i" tests/run.gd "--shard=$i/$SHARDS" &
    done
    wait
  fi
}

case "$suite" in
  sim)   sim "$@" ;;
  scene) run scene tests/smoke_scene.gd ;;
  intro) run intro tests/smoke_intro.gd ;;
  all)
    sim "$@" &
    run scene tests/smoke_scene.gd &
    run intro tests/smoke_intro.gd &
    wait ;;
  *) echo "usage: tools/test.sh [sim|scene|intro|all]"; exit 2 ;;
esac

for f in "$out"/*.txt; do
  name="$(basename "$f" .txt)"
  code="$(cat "$out/$name.code")"
  summary="$(grep -E "ALL PASSED|FAILED|SCRIPT ERROR|only [0-9]+" "$f" | tail -1)"
  [ "$code" != 0 ] && status=1
  grep -q "SCRIPT ERROR" "$f" && status=1
  printf '%-6s %s\n' "$name" "${summary:-no summary: see $f}"
  if [ "$code" != 0 ] || grep -q "SCRIPT ERROR" "$f"; then
    grep -E "FAIL|SCRIPT ERROR|only [0-9]+" "$f" | head -20
  fi
done
exit $status
