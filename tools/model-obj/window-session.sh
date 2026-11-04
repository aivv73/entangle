#!/usr/bin/env bash
set -euo pipefail
model_repo="$PWD"
test -f "$model_repo/toolchain.bend"
mkdir -p "$model_repo/build/verification"
model_evidence=$(mktemp -d "$model_repo/build/verification/model-window-XXXXXXXX")
model_runtime=$(mktemp -d "$model_repo/build/model-window-runtime-XXXXXXXX")
model_display_pid=
printf 'Evidence: %s\n' "$model_evidence"
cleanup() {
  model_status=$?
  trap - EXIT INT TERM
  if [ -n "$model_display_pid" ]; then
    kill "$model_display_pid" 2>/dev/null || true
    wait "$model_display_pid" 2>/dev/null || true
  fi
  cd "$model_repo"
  rm -f -- "$model_runtime/build/indexed-window" "$model_runtime/build/model-window.log" "$model_runtime/build/model-window.ppm"
  rmdir "$model_runtime/build" "$model_runtime"
  printf '%s\n' "$model_status" > "$model_evidence/run.status"
  printf 'Removed runtime %s; reaped owned display %s\n' "$model_runtime" "$model_display_pid" > "$model_evidence/cleanup.log"
  exit "$model_status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
run() {
  local label=$1
  shift
  printf '%q ' "$@" >> "$model_evidence/commands.log"
  printf '\n' >> "$model_evidence/commands.log"
  if "$@" > "$model_evidence/$label.log" 2>&1; then
    printf '0\n' > "$model_evidence/$label.status"
  else
    local status=$?
    printf '%s\n' "$status" > "$model_evidence/$label.status"
    cat "$model_evidence/$label.log"
    return "$status"
  fi
}
mkdir -p "$model_evidence/bin" "$model_evidence/inputs" "$model_runtime/build"
git rev-parse HEAD > "$model_evidence/revision.txt"
git status --short > "$model_evidence/worktree.txt"
git diff --binary > "$model_evidence/worktree.patch"
git submodule status --recursive > "$model_evidence/dependencies.txt"
sha256sum src/model-obj.bend src/content.bend examples/model-assets.bend tools/model-obj/*.bend tools/model-obj/window-session.sh > "$model_evidence/sources.sha256"
bend version > "$model_evidence/bend.txt"
clang --version > "$model_evidence/clang.txt"
test "$(bend version)" = 'bend 2.0.39'
test "$(head -n 1 "$model_evidence/clang.txt")" = 'clang version 23.1.4'
test "$(clang -dumpmachine)" = 'x86_64-pc-linux-gnu'
run build-app bend tools/model-obj/window-app.bend -o "$model_evidence/bin/window-app"
run build-driver bend tools/model-obj/window.bend -o "$model_evidence/bin/window"
run build-reverse bend tools/model-obj/reverse.bend -o "$model_evidence/bin/reverse"
run reverse "$model_evidence/bin/reverse" "$model_evidence/inputs/reversed.obj" +RTS --threads 1 --gpu off
cp docs/verification/2026-11-04-model-obj/corpus/sign.mtl "$model_evidence/inputs/sign.mtl"
cp "$model_evidence/bin/window-app" "$model_runtime/build/indexed-window"
sha256sum "$model_evidence"/bin/* > "$model_evidence/binaries.sha256"
Xwayland -noreset -displayfd 3 -geometry 1280x1024 -listen tcp -ac 3>"$model_evidence/display" >"$model_evidence/xwayland.log" 2>&1 &
model_display_pid=$!
printf '%s\n' "$model_display_pid" > "$model_evidence/display.pid"
for attempt in $(seq 1 100); do
  [ -s "$model_evidence/display" ] && break
  kill -0 "$model_display_pid"
  sleep 0.05
done
test -s "$model_evidence/display"
read -r model_display_number < "$model_evidence/display"
export DISPLAY=":$model_display_number"
export ENTANGLE_X11_PORT="$((6000 + model_display_number))"
export VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation
export VK_LAYER_VALIDATE_SYNC=1
unset VK_LAYER_ENABLES
doctor() {
  kill -0 "$model_display_pid" &&
  test "$DISPLAY" = ":$(cat "$model_evidence/display")" &&
  test "$ENTANGLE_X11_PORT" = "$((6000 + model_display_number))" &&
  cmp "$model_evidence/bin/window-app" "$model_runtime/build/indexed-window" &&
  sha256sum -c "$model_evidence/binaries.sha256" &&
  ps -p "$model_display_pid" -o pid,ppid,args
}
run doctor doctor
for model_case in sign wedge reversed; do
  case "$model_case" in
    reversed) model_input="$model_evidence/inputs/reversed.obj" ;;
    *) model_input="$model_repo/docs/verification/2026-11-04-model-obj/corpus/$model_case.obj" ;;
  esac
  cd "$model_runtime"
  run "$model_case" env ENTANGLE_OBJ_INPUT="$model_input" timeout --signal=KILL 120s "$model_evidence/bin/window" "$model_case"
  cp build/model-window.log "$model_evidence/$model_case-native.log"
  cp build/model-window.ppm "$model_evidence/$model_case.ppm"
  cd "$model_repo"
  run "doctor-$model_case" doctor
done
sha256sum "$model_evidence"/*.ppm > "$model_evidence/captures.sha256"
