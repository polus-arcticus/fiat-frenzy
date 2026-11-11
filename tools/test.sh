#!/usr/bin/env bash
# Runs every test suite at once, each in its own process, and prints one summary line per suite.
# The sim suite takes about a second, the scene suite about ten, the intro suite about five, so the
# whole run is as long as the slowest.
#   tools/test.sh            all three
#   tools/test.sh sim        just the model tests   (extra arguments go to tests/run.gd, e.g. --only=rescue)
#   tools/test.sh scene|intro
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/app-port/Godot_v4.7.2-stable_linux.x86_64}"
suite="${1:-all}"
[ $# -gt 0 ] && shift
out="$(mktemp -d)"
status=0

run() {  # name script [args...]
  local name="$1" script="$2"; shift 2
  timeout 600 "$GODOT" --headless --path . --script "$script" ${1:+-- "$@"} >"$out/$name.txt" 2>&1
  echo $? >"$out/$name.code"
}

case "$suite" in
  sim)   run sim tests/run.gd "$@" ;;
  scene) run scene tests/smoke_scene.gd ;;
  intro) run intro tests/smoke_intro.gd ;;
  all)
    run sim tests/run.gd "$@" &
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
