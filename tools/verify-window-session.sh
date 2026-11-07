#!/usr/bin/env bash
set -euo pipefail
entangle_extended=${1:-}
test "$#" -le 1
case "$entangle_extended" in ""|extended|hierarchy) ;; *) exit 2 ;; esac
entangle_repo="$PWD"
test -f "$entangle_repo/toolchain.bend"
mkdir -p "$entangle_repo/build/verification"
entangle_evidence=$(mktemp -d "$entangle_repo/build/verification/entangle-XXXXXXXX")
entangle_runtime=$(mktemp -d "$entangle_repo/build/verify-entangle-runtime-XXXXXXXX")
entangle_xwayland_pid=
printf 'Evidence: %s\n' "$entangle_evidence"

cleanup() {
  entangle_status=$?
  trap - EXIT INT TERM
  if [ -n "$entangle_xwayland_pid" ]; then
    kill "$entangle_xwayland_pid" 2>/dev/null || true
    wait "$entangle_xwayland_pid" 2>/dev/null || true
  fi
  cd "$entangle_repo"
  for entangle_file in \
    "$entangle_runtime/assets" \
    "$entangle_runtime/build/indexed-window" \
    "$entangle_runtime/build/window-evidence" \
    "$entangle_runtime/build/public-creation-window.log" \
    "$entangle_runtime/build/replacement-window.log" \
    "$entangle_runtime/docs/verification/2026-11-03-mesh-playground" \
    "$entangle_runtime/docs/verification/2026-11-03-public-creation"; do
    if [ -e "$entangle_file" ] || [ -L "$entangle_file" ]; then
      rm -- "$entangle_file"
    fi
  done
  rmdir "$entangle_runtime/build" "$entangle_runtime/docs/verification" \
    "$entangle_runtime/docs" "$entangle_runtime"
  printf '%s\n' "$entangle_status" > "$entangle_evidence/run.status"
  printf 'Removed runtime %s; reaped owned display %s\n' \
    "$entangle_runtime" "$entangle_xwayland_pid" > "$entangle_evidence/cleanup.log"
  test -d "$entangle_evidence"
  exit "$entangle_status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

run() {
  local label=$1
  shift
  printf '%q ' "$@" >> "$entangle_evidence/commands.log"
  printf '\n' >> "$entangle_evidence/commands.log"
  if "$@" > "$entangle_evidence/$label.log" 2>&1; then
    printf '0\n' > "$entangle_evidence/$label.status"
  else
    local status=$?
    printf '%s\n' "$status" > "$entangle_evidence/$label.status"
    cat "$entangle_evidence/$label.log"
    return "$status"
  fi
}

mkdir -p "$entangle_evidence/bin" "$entangle_evidence/mesh" "$entangle_runtime/build" "$entangle_runtime/docs/verification"
git rev-parse HEAD > "$entangle_evidence/revision.txt"
git status --short > "$entangle_evidence/worktree.txt"
git diff --binary > "$entangle_evidence/worktree.patch"
git submodule status --recursive > "$entangle_evidence/dependencies.txt"
find src examples tools assets -type f -print0 | sort -z | xargs -0 sha256sum > "$entangle_evidence/sources.sha256"
sha256sum toolchain.bend LAWS.bend PROOF.bend >> "$entangle_evidence/sources.sha256"
run toolchain bend tools/verify-toolchain.bend
clang --version > "$entangle_evidence/clang.txt"
test "$(head -n 1 "$entangle_evidence/clang.txt")" = 'clang version 23.1.4'
test "$(clang -dumpmachine)" = 'x86_64-pc-linux-gnu'
run proof bend PROOF.bend
run build-pointer-driver bend tools/verify-pointer-mutations.bend -o "$entangle_evidence/bin/verify-pointer-mutations"
run build-app bend examples/mesh-playground.bend -o "$entangle_evidence/bin/mesh-playground"
run build-driver bend tools/verify-mesh-window.bend -o "$entangle_evidence/bin/verify-mesh-window"
run build-replay bend tools/replay-mesh-window.bend -o "$entangle_evidence/bin/replay-mesh-window"
if [ "$entangle_extended" = extended ] || [ "$entangle_extended" = hierarchy ]; then
  run build-hierarchy bend tools/hierarchy/window.bend -o "$entangle_evidence/bin/hierarchy-window"
  run build-hierarchy-driver bend tools/hierarchy/window-driver.bend -o "$entangle_evidence/bin/hierarchy-driver"
  run build-hierarchy-replay bend tools/hierarchy/replay.bend -o "$entangle_evidence/bin/hierarchy-replay"
fi
if [ "$entangle_extended" = extended ]; then
  run build-cube bend examples/scene-window.bend -o "$entangle_evidence/bin/cube-window"
  run build-cube-driver bend tools/verify-window.bend -o "$entangle_evidence/bin/verify-window"
  run build-creation bend tools/creation-window-app.bend -o "$entangle_evidence/bin/creation-window"
  run build-creation-driver bend tools/verify-creation-window.bend -o "$entangle_evidence/bin/verify-creation-window"
  run build-replacement bend tools/mesh-replacement-window.bend -o "$entangle_evidence/bin/replacement-window"
  run build-replacement-driver bend tools/verify-mesh-replacement-window.bend -o "$entangle_evidence/bin/verify-replacement-window"
  run build-textured bend examples/textured-scene.bend -o "$entangle_evidence/bin/textured-window"
  run build-textured-driver bend tools/verify-textured-window.bend -o "$entangle_evidence/bin/verify-textured-window"
  ln -s "$entangle_repo/assets" "$entangle_runtime/assets"
fi
sha256sum "$entangle_evidence"/bin/* > "$entangle_evidence/binaries.sha256"
cp "$entangle_evidence/bin/mesh-playground" "$entangle_runtime/build/indexed-window"
ln -s "$entangle_evidence/mesh" "$entangle_runtime/build/window-evidence"
ln -s "$entangle_evidence/mesh" "$entangle_runtime/docs/verification/2026-11-03-mesh-playground"
Xwayland -noreset -displayfd 3 -geometry 1280x1024 -listen tcp -ac \
  3>"$entangle_evidence/display" >"$entangle_evidence/xwayland.log" 2>&1 &
entangle_xwayland_pid=$!
printf '%s\n' "$entangle_xwayland_pid" > "$entangle_evidence/display.pid"
for attempt in $(seq 1 100); do
  [ -s "$entangle_evidence/display" ] && break
  kill -0 "$entangle_xwayland_pid"
  sleep 0.05
done
test -s "$entangle_evidence/display"
read -r entangle_display_number < "$entangle_evidence/display"
export DISPLAY=":$entangle_display_number"
export ENTANGLE_X11_PORT="$((6000 + entangle_display_number))"
export ENTANGLE_MESH_EVIDENCE=1
export VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation
export VK_LAYER_VALIDATE_SYNC=1
unset VK_LAYER_ENABLES

doctor() {
  kill -0 "$entangle_xwayland_pid" &&
  test "$DISPLAY" = ":$(cat "$entangle_evidence/display")" &&
  test "$ENTANGLE_X11_PORT" = "$((6000 + entangle_display_number))" &&
  test "$(readlink "$entangle_runtime/build/window-evidence")" = "$entangle_evidence/mesh" &&
  cmp "$entangle_evidence/bin/mesh-playground" "$entangle_runtime/build/indexed-window" &&
  sha256sum -c "$entangle_evidence/binaries.sha256" &&
  ps -p "$entangle_xwayland_pid" -o pid,ppid,args
}
run doctor doctor
run pointer "$entangle_evidence/bin/verify-pointer-mutations" +RTS --threads 1 --gpu off
cd "$entangle_runtime"
if [ "$entangle_extended" = extended ]; then
  mkdir -p "$entangle_evidence/cube" "$entangle_evidence/creation" "$entangle_evidence/replacement" "$entangle_evidence/textured"
  cp "$entangle_evidence/bin/cube-window" build/indexed-window
  rm build/window-evidence
  ln -s "$entangle_evidence/cube" build/window-evidence
  run cube-live timeout --signal=KILL 120s env ENTANGLE_WINDOW_MODE=live "$entangle_evidence/bin/verify-window" live plain
  run cube-replay timeout --signal=KILL 120s env ENTANGLE_WINDOW_MODE=replay "$entangle_evidence/bin/verify-window" replay plain
  run cube-terminal timeout --signal=KILL 120s env ENTANGLE_WINDOW_MODE=terminal "$entangle_evidence/bin/verify-window" terminal plain
  cp "$entangle_evidence/bin/creation-window" build/indexed-window
  ln -s "$entangle_evidence/creation" docs/verification/2026-11-03-public-creation
  ln -s "$entangle_evidence/creation/native.log" build/public-creation-window.log
  run creation-window timeout --signal=KILL 120s "$entangle_evidence/bin/verify-creation-window"
  cp "$entangle_evidence/bin/replacement-window" build/indexed-window
  rm build/window-evidence
  ln -s "$entangle_evidence/replacement" build/window-evidence
  ln -s "$entangle_evidence/replacement/native.log" build/replacement-window.log
  run replacement-window timeout --signal=KILL 120s "$entangle_evidence/bin/verify-replacement-window"
  cp "$entangle_evidence/bin/textured-window" build/indexed-window
  rm build/window-evidence
  ln -s "$entangle_evidence/textured" build/window-evidence
  run textured-window timeout --signal=KILL 120s "$entangle_evidence/bin/verify-textured-window"
  cp "$entangle_evidence/bin/mesh-playground" build/indexed-window
  rm build/window-evidence
  ln -s "$entangle_evidence/mesh" build/window-evidence
  run doctor-after-extended doctor
fi
if [ "$entangle_extended" = extended ] || [ "$entangle_extended" = hierarchy ]; then
  mkdir -p "$entangle_evidence/hierarchy"
  cp "$entangle_evidence/bin/hierarchy-window" build/indexed-window
  rm build/window-evidence
  ln -s "$entangle_evidence/hierarchy" build/window-evidence
  run hierarchy-window timeout --signal=KILL 120s "$entangle_evidence/bin/hierarchy-driver"
  run hierarchy-replay "$entangle_evidence/bin/hierarchy-replay" "$entangle_evidence/hierarchy/native.log"
  cp "$entangle_evidence/bin/mesh-playground" build/indexed-window
  rm build/window-evidence
  ln -s "$entangle_evidence/mesh" build/window-evidence
  run doctor-after-hierarchy doctor
fi
run window timeout --signal=KILL 120s "$entangle_evidence/bin/verify-mesh-window"
run replay-live "$entangle_evidence/bin/replay-mesh-window" "$entangle_evidence/mesh/native-live.log"
run replay-close "$entangle_evidence/bin/replay-mesh-window" "$entangle_evidence/mesh/native-close.log"
test -s "$entangle_evidence/mesh/initial.ppm"
test -s "$entangle_evidence/mesh/reset.ppm"
cmp "$entangle_evidence/mesh/initial.ppm" "$entangle_evidence/mesh/reset.ppm"
sha256sum "$entangle_evidence"/mesh/*.ppm > "$entangle_evidence/captures.sha256"
