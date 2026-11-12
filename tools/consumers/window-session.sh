#!/usr/bin/env bash
set -euo pipefail
consumer_repo="$PWD"
mkdir -p build/verification
consumer_evidence=$(mktemp -d "$consumer_repo/build/verification/consumers-XXXXXXXX")
consumer_runtime=$(mktemp -d "$consumer_repo/build/consumer-runtime-XXXXXXXX")
consumer_display_pid=
printf 'Evidence: %s\n' "$consumer_evidence"
cleanup() {
  consumer_status=$?
  trap - EXIT INT TERM
  if [ -n "$consumer_display_pid" ]; then
    kill "$consumer_display_pid" 2>/dev/null || true
    wait "$consumer_display_pid" 2>/dev/null || true
  fi
  mkdir -p "$consumer_evidence/last-runtime"
  cp "$consumer_runtime"/build/*.log "$consumer_runtime"/build/*.ppm "$consumer_evidence/last-runtime/" 2>/dev/null || true
  printf '%s\n' "$consumer_status" > "$consumer_evidence/run.status"
  rm -rf -- "$consumer_runtime"
  printf 'Removed owned runtime %s; reaped display %s\n' "$consumer_runtime" "$consumer_display_pid" > "$consumer_evidence/cleanup.log"
  exit "$consumer_status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
run() {
  local label=$1
  shift
  printf '%q ' "$@" >> "$consumer_evidence/commands.log"
  printf '\n' >> "$consumer_evidence/commands.log"
  if "$@" > "$consumer_evidence/$label.log" 2>&1; then
    printf '0\n' > "$consumer_evidence/$label.status"
  else
    local code=$?
    printf '%s\n' "$code" > "$consumer_evidence/$label.status"
    cat "$consumer_evidence/$label.log"
    return "$code"
  fi
}
mkdir -p "$consumer_evidence/bin" "$consumer_runtime/build"
git rev-parse HEAD > "$consumer_evidence/revision.txt"
git diff --binary > "$consumer_evidence/worktree.patch"
git status --short > "$consumer_evidence/worktree.txt"
git submodule status --recursive > "$consumer_evidence/dependencies.txt"
sha256sum LAWS.bend PROOF.bend src/*.bend > "$consumer_evidence/engine.sha256"
rg --files -0 examples assets/consumers tools/consumers | sort -z | xargs -0 sha256sum > "$consumer_evidence/sources.sha256"
run toolchain bend tools/verify-toolchain.bend
run proof bend PROOF.bend
run build-viewer bend examples/model-viewer.bend -o "$consumer_evidence/bin/viewer"
run build-game bend examples/energy-courier.bend -o "$consumer_evidence/bin/game"
run build-driver bend tools/consumers/window.bend -o "$consumer_evidence/bin/driver"
run build-runtime bend tools/consumers/runtime.bend -o "$consumer_evidence/bin/runtime"
run runtime "$consumer_evidence/bin/runtime" +RTS --threads 1 --gpu off
run build-fit-boundary bend tools/consumers/fit-boundary.bend -o "$consumer_evidence/bin/fit-boundary"
run fit-boundary "$consumer_evidence/bin/fit-boundary" +RTS --threads 1 --gpu off
ln -s "$consumer_repo/assets" "$consumer_runtime/assets"
Xwayland -noreset -displayfd 3 -geometry 1280x1024 -listen tcp -ac 3>"$consumer_evidence/display" >"$consumer_evidence/xwayland.log" 2>&1 &
consumer_display_pid=$!
printf '%s\n' "$consumer_display_pid" > "$consumer_evidence/display.pid"
for attempt in $(seq 1 100); do
  [ -s "$consumer_evidence/display" ] && break
  kill -0 "$consumer_display_pid"
  sleep 0.05
done
test -s "$consumer_evidence/display"
read -r consumer_display_number < "$consumer_evidence/display"
export DISPLAY=":$consumer_display_number"
export ENTANGLE_X11_PORT="$((6000 + consumer_display_number))"
export VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation
export VK_LAYER_VALIDATE_SYNC=1
unset VK_LAYER_ENABLES
doctor() {
  kill -0 "$consumer_display_pid" &&
  test "$DISPLAY" = ":$(cat "$consumer_evidence/display")" &&
  test "$ENTANGLE_X11_PORT" = "$((6000 + consumer_display_number))" &&
  test -x "$consumer_runtime/build/indexed-window" &&
  ps -p "$consumer_display_pid" -o pid,ppid,args
}
for consumer_case in viewer game fallback custom fit-fallback; do
  if [ "$consumer_case" = game ]; then
    cp "$consumer_evidence/bin/game" "$consumer_runtime/build/indexed-window"
  elif [ "$consumer_case" = fallback ] || [ "$consumer_case" = custom ] || [ "$consumer_case" = fit-fallback ]; then
    case "$consumer_case" in
      fallback) consumer_input=/missing-entangle-model.obj ;;
      custom) consumer_input="$consumer_repo/docs/verification/2026-11-04-model-obj/corpus/sign.obj" ;;
      fit-fallback) consumer_input="$consumer_repo/assets/consumers/extreme.obj" ;;
    esac
    printf '#!/usr/bin/env bash\nexec %q %q\n' "$consumer_evidence/bin/viewer" "$consumer_input" > "$consumer_runtime/build/indexed-window"
    chmod +x "$consumer_runtime/build/indexed-window"
  else
    cp "$consumer_evidence/bin/viewer" "$consumer_runtime/build/indexed-window"
  fi
  sha256sum "$consumer_runtime/build/indexed-window" > "$consumer_evidence/$consumer_case-executable.sha256"
  run "$consumer_case-doctor" doctor
  cd "$consumer_runtime"
  run "$consumer_case" timeout --signal=KILL 120s "$consumer_evidence/bin/driver" "$consumer_case" +RTS --threads 1 --gpu off
  cp build/consumer-window.log "$consumer_evidence/$consumer_case-native.log"
  cp build/consumer-*.ppm "$consumer_evidence/"
  mkdir -p "$consumer_evidence/$consumer_case"
  mv "$consumer_evidence"/consumer-*.ppm "$consumer_evidence/$consumer_case/"
  cd "$consumer_repo"
  kill -0 "$consumer_display_pid"
done
rg -q 'Could not open requested model:.*Showing bundled beacon' "$consumer_evidence/fallback-native.log"
rg -q 'Requested model does not fit scene creation. Showing bundled beacon.' "$consumer_evidence/fit-fallback-native.log"
sha256sum -c "$consumer_evidence/sources.sha256" > "$consumer_evidence/sources-restored.log"
sha256sum -c "$consumer_evidence/engine.sha256" > "$consumer_evidence/engine-restored.log"
printf 'Consumer native and X11 evidence passed: %s\n' "$consumer_evidence"
