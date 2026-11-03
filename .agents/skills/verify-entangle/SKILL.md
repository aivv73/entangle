---
name: verify-entangle
description: Verify Entangle's native X11 mesh playground and scene window, public scene creation, headless ECS simulation, and offscreen rendering through existing Bend drivers. Use after changes to controls, simulation, scene compilation, rendering, or resource cleanup.
---

# Verify Entangle

Read [the feature map](features/README.md) first. Entangle's primary interactive app is a native X11 window. Its other user paths are Bend scene descriptions and command-line examples. There is no web server, account, database, or seed service. Examples supply their own scene data.

## Launch

Run from the repository root on Linux x86-64. Read `AGENTS.md`, run `bend guide`, and check `toolchain.bend`. The current native lane requires Bend 2.0.39, Clang 23.1.4, Node.js or Bun, initialized dependencies, Vulkan and X11 development headers, and a Vulkan graphics/presentation device. The live recipe also needs `Xwayland`, a working parent Wayland session, and `VK_LAYER_KHRONOS_validation`.

Inspect dependencies with `git submodule status --recursive`. If they are missing, use the README's initialization commands. Stop on a build or startup failure and retain its logs. Do not treat a headless pass as a window pass.

The following Bash block is the complete mesh verification lifecycle. Run it in one shell invocation. It builds fresh executables, starts an owned rootful Xwayland, runs the doctor, drives the app, replays both traces, and cleans up. Each invocation prints its evidence path. Allow several minutes for compilation.

The isolated working directory redirects the drivers' historical output paths into fresh evidence. Never symlink its `docs` directory to the repository's real `docs`. Never replace the repository's `build/indexed-window` with the mesh executable.

```bash
set -euo pipefail
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
find src examples tools -type f -name '*.bend' -print0 | sort -z | xargs -0 sha256sum > "$entangle_evidence/sources.sha256"
sha256sum toolchain.bend LAWS.bend PROOF.bend >> "$entangle_evidence/sources.sha256"
test "$(bend version)" = 'bend 2.0.39'
clang --version > "$entangle_evidence/clang.txt"
test "$(head -n 1 "$entangle_evidence/clang.txt")" = 'clang version 23.1.4'
test "$(clang -dumpmachine)" = 'x86_64-pc-linux-gnu'
run proof bend PROOF.bend
run build-app bend examples/mesh-playground.bend -o "$entangle_evidence/bin/mesh-playground"
run build-driver bend tools/verify-mesh-window.bend -o "$entangle_evidence/bin/verify-mesh-window"
run build-replay bend tools/replay-mesh-window.bend -o "$entangle_evidence/bin/replay-mesh-window"
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
cd "$entangle_runtime"
run window timeout --signal=KILL 120s "$entangle_evidence/bin/verify-mesh-window"
run replay-live "$entangle_evidence/bin/replay-mesh-window" "$entangle_evidence/mesh/native-live.log"
run replay-close "$entangle_evidence/bin/replay-mesh-window" "$entangle_evidence/mesh/native-close.log"
test -s "$entangle_evidence/mesh/initial.ppm"
test -s "$entangle_evidence/mesh/reset.ppm"
cmp "$entangle_evidence/mesh/initial.ppm" "$entangle_evidence/mesh/reset.ppm"
sha256sum "$entangle_evidence"/mesh/*.ppm > "$entangle_evidence/captures.sha256"
```

The display number file signals Xwayland readiness. The Bend driver then locates only its child's window by PID and waits for a populated 640×480 frame. Its first capture must contain all four mesh materials. A blank window or a live process alone is insufficient.

This recipe uses the existing helper's unauthenticated X11 TCP connection on a disposable display. Do not redirect it to the user's display. Independent runs have distinct display numbers and directories. Repository-wide gates that write fixed `build` paths must run sequentially.

## Doctor

Run `doctor` from the launch shell before input or whenever ownership looks wrong. It is one read-only check of the owned display process, display number, TCP port, evidence destination, and exact executable bytes. `doctor.log` records its result. A failed check means stop and run cleanup. The live driver's populated-frame and validation checks establish renderer health after launch.

For a CPU-only invocation, check `bend version`, `clang --version`, `clang -dumpmachine`, and `git submodule status` instead. Do not require a display for headless verification.

## Drive

Use the existing Bend drivers. The launch recipe runs the [mesh movement](features/mesh-movement.md) path with trace logging and also exercises the mesh entry of [camera and window controls](features/camera-window.md). Each driver starts and reaps its own application. Do not start an extra interactive copy for it to discover.

`verify-mesh-window` sends held movement edges through the actual X11 keyboard map, uses `bend-ui-test` for taps and Close, captures real window pixels, and checks cleanup. `replay-mesh-window` executes the recorded input and ticks against the real ECS application and compares full identities and transform bits. Compile these drivers natively. The default runner has previously hit a stack fault on a large trace.

Run every relevant entry in the feature map for a change. One mesh run does not cover the cube window, public creation, headless batching, or offscreen depth rendering. The feature files give their commands and expected results.

## Evidence

Keep the printed `build/verification/entangle-XXXXXXXX` directory after teardown. It contains commands, per-stage exit codes, revision and source hashes, fresh binaries, compiler and dependency information, window captures, input/state traces, replay results, and cleanup status. This directory is gitignored. Link the exact path in your report. Copy selected evidence elsewhere only when requested, and preserve the originals.

Require `run.status` and each executed stage's `.status` to be zero. Inspect `window.log` for all six `player-axis=... held=moved release=stable Space=exact` lines and the focus, resize, and exit results. Both native logs must report `Mesh playground closed; live Vulkan objects: 0` without `Validation Error`, `SYNC-HAZARD`, or `VUID-` diagnostics. Both replay logs must report real ECS replay matches. Inspect `initial.ppm`, `held.ppm`, and `reset.ppm` with an image viewer. The initial and reset files must compare byte-for-byte.

Capture the action as well as its result. A screenshot alone does not prove input, and digest equality alone does not prove world equality. Preserve the real input/state logs and successful replay checks. Verify written captures and resource cleanup alongside the visible state. Do not introduce mocks or example-based unit tests. Formal claims belong in `LAWS.bend`, with proofs in `PROOF.bend`.

`ENTANGLE_MESH_EVIDENCE=1` enables logging. It is not a dry-run: the application still opens a window, consumes input, runs ECS ticks, and allocates Vulkan resources. Report ordinary untraced execution separately if you run it. Report skipped paths and failed attempts explicitly. This recipe makes no performance, other-backend, or device-loss recovery claim.

## Cleanup

The launch block's EXIT trap runs on success and failure. Normal driver exits reap the application through the existing bridge. Its `atexit` handler kills only its owned child on assertion failure. The bounded `timeout` kills its command process group if a driver hangs. Such a run fails and cannot establish clean Vulkan shutdown.

The trap stops and reaps only the Xwayland PID it started, then deletes only the fresh runtime directory. It retains binaries, logs, traces, captures, and status files in the evidence directory. Never kill by process name or remove the evidence directory to clean up. After a failed attempt, finish cleanup before starting a new run with a new evidence directory.

After the launch shell exits, inspect `cleanup.log` and `run.status` at the printed path. Confirm the runtime directory named in `cleanup.log` is absent and the recorded display PID is gone. Confirm that `commands.log`, `window.log`, both replay logs, and `mesh/initial.ppm` still exist. Preserve partial evidence on failure, even when later artifacts were never created.

## Helpers

This skill ships no new executable helpers. Its shell block only builds and orchestrates the existing Bend drivers. Their invocations appear above and in the feature map. Keep verification behavior in those Bend drivers. Use `/maintain-verification-skill` when controls, paths, or observable results change.
