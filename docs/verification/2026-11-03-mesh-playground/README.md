# Mesh playground verification

The separate app uses the existing ECS schema, spawn system, bootstrap receipt
inspection, inspector query, renderer, and camera API. The old scene sources and
public APIs are unchanged. Only the registered player writer mutates transforms. It opens the existing
generalized query gate before modifying the retained player handle, and the
callback reads the current stored transform. Query refusal preserves the
incoming scope and control state and reports a body error.
Its retained state is `Boot | PlayerReady`, with a full handle, held keys,
immutable initial transform, and pending reset. `Ready` is already a Base
constructor. Current transforms remain authoritative in the ECS.

## Run the app

From the repository root:

```sh
mkdir -p build
bend examples/mesh-playground.bend -o build/mesh-playground
./build/mesh-playground
```

Hold I/K for world -Z/+Z, J/L for -X/+X, and U/O for +Y/-Y. Space restores the
player's initial transform and clears movement. WASD orbit, QE zoom, R resets
the camera, and Escape or Close exits. Opposing keys cancel. Movement uses
0.048 units per active axis per 16 ms fixed step, with at most four catch-up
steps per poll. X/Z stay in [-3,3], and Y stays in [-0.2,2.5]. Diagonal motion
is intentionally axis based. Focus loss or unmap clears keys and anchors the
clock. Camera controls retain the existing press behavior.

## Reproduce the checks

Run the proof and native baseline gates sequentially:

```sh
bend PROOF.bend
bend tools/verify.bend
bend tools/verify-mesh-playground.bend
```

The mesh driver builds its native binary and runs real ECS and Vulkan code.
To rerun an already built driver, use `./build/verify-mesh-playground native`.
The laws state last-state input semantics for each movement key, opposing-axis
cancellation, reset intent, reset preservation through release/inactivity,
idempotent clearing, preserved rotation/scale, no writes in Boot or idle, and
write dispatch only to the retained full handle. No example unit tests or mocks
are used.

The runtime driver checks the actual assets, including opposite directed edge
incidences, distinct face indices, nonzero outward face normals, connected
vertices, expected topology sizes, valid compiled geometry, and four distinct
packed ranges. It checks bootstrap against compiled seeds, static entity
identities and exact transform bits after every tick, held/repeated/released
keys, opposing keys on all axes, reset across zero-step polls, one-shot reset,
inactive clearing, bounds, and deterministic replay. It renders retained earlier
draws after later motion, requires exact replay pixels, and observes that the
later world remains unchanged. All Vulkan scopes end with zero live objects.

Build the native window and evidence drivers:

```sh
bend examples/mesh-playground.bend -o build/mesh-playground
bend tools/verify-mesh-window.bend -o build/verify-mesh-window
bend tools/replay-mesh-window.bend -o build/replay-mesh-window
```

The launch bridge always starts `./build/indexed-window`. Use an isolated
working directory to preserve the old binary. The following recipe uses an
owned disposable rootful Xwayland with TCP enabled for the Bend protocol helper.
The helper connects to loopback and requires this unauthenticated owned display.
The application itself works with the usual local X11 display.

```sh
mesh_repo="$PWD"
mesh_evidence="$mesh_repo/docs/verification/2026-11-03-mesh-playground"
mkdir -p build/mesh-runtime/build
ln -sfn "$mesh_repo/docs" build/mesh-runtime/docs
ln -sfn "$mesh_evidence" build/mesh-runtime/build/window-evidence
cp build/mesh-playground build/mesh-runtime/build/indexed-window
: > build/mesh-runtime/display
Xwayland -displayfd 3 -geometry 1280x1024 -listen tcp -ac \
  3>build/mesh-runtime/display >build/mesh-runtime/xwayland.log 2>&1 &
mesh_xwayland_pid=$!
trap 'kill "$mesh_xwayland_pid" 2>/dev/null; wait "$mesh_xwayland_pid" 2>/dev/null' EXIT
for attempt in $(seq 1 100); do
  [ -s build/mesh-runtime/display ] && break
  kill -0 "$mesh_xwayland_pid" || break
  sleep 0.05
done
[ -s build/mesh-runtime/display ] || exit 1
read -r mesh_display_number < build/mesh-runtime/display
(
  cd build/mesh-runtime
  env -u VK_LAYER_ENABLES DISPLAY=":$mesh_display_number" \
    ENTANGLE_X11_PORT="$((6000 + mesh_display_number))" \
    ENTANGLE_MESH_EVIDENCE=1 VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation \
    VK_LAYER_VALIDATE_SYNC=1 "$mesh_repo/build/verify-mesh-window"
) >"$mesh_evidence/window.log" 2>&1
./build/replay-mesh-window "$mesh_evidence/native-live.log"
./build/replay-mesh-window "$mesh_evidence/native-close.log"
```

`ENTANGLE_MESH_EVIDENCE=1` records input edges, active state, bounded batch size,
and the full namespace/index/generation, mesh ID, and transform bits after each
tick and batch. The replay driver executes those recorded steps in the actual
retained ECS application. It checks batch accounting, each recorded state,
static objects, player pose, and bounds. Logging is disabled for ordinary runs.

Pinned `bend-ui-test` accepts complete press/release pairs. It rejects separated
press-only plans. Therefore camera taps, Space, Escape, and Close use that
package, while `tools/mesh-x11-focus.bend` uses the actual server keyboard map
and X11 SendEvent protocol for separated held movement edges. It matches only
keysym slot zero, which the pinned backend reads. It also sets and
reads back actual X11 input focus. This is real X11 execution, with no new C,
mock ECS or renderer, or dependency change.

## Evidence and limits

`bootstrap.log` records the required successful ECS check before window work.
`proof.log`, `native.log`, `ecs.log`, `window.log`, and the native process logs
record the executed gates. The native window driver checks all six player
movement keys, continuous held motion, repeated presses, opposing movement,
release stopping, exact Space reset, six camera keys with exact R reset,
real focus loss, queued FocusOut/FocusIn within one poll, unmap/restore, repeated landscape/portrait resizing, unfocused
Escape, hidden Close, and zero live Vulkan objects. Its initial capture must
contain all four actual mesh materials. Native mesh logs use Khronos and
synchronization validation through the modern environment settings, avoiding
the legacy bridge's deprecated-setting warning.

The general zero-step reset property is checked by deterministic real ECS
replay because native event timing does not guarantee a zero-step poll. Native
input is delivered through X11 SendEvent, rather than physical hardware or
XTest. This run validates Linux X11/Vulkan on the available machine. It makes
no Metal, CUDA, WebGPU, concurrency, or performance claim. Mesh algorithms and
control semantics contain no GPU-backend-specific assumptions.

The pinned native backend emits `wsadqe` releases and a right-button release on
focus loss or unmap. The new app recognizes this complete sequence at its poll
boundary. This also clears held movement and anchors the clock if focus is
restored before the same poll ends. The native verifier pauses its owned child,
queues both actual server focus changes, resumes it, and requires the
`mesh-focus-burst-cleared` evidence marker, a zero-step batch, unchanged
authoritative state across the boundary, and stable geometry afterward.
This adapter is tied to the pinned native event contract and must be reviewed
if that dependency changes.

The old window gates run against separately built executables in
`build/mesh-old-runtime` and `build/mesh-creation-runtime`. The existing
`build/indexed-window` stays byte-identical. Reproduce those checks after the
mesh gate, on the same owned display:

```sh
mkdir -p build/mesh-old-runtime/build "$mesh_evidence/old-window"
ln -sfn "$mesh_evidence/old-window" build/mesh-old-runtime/build/window-evidence
bend examples/scene-window.bend -o build/mesh-old-runtime/build/indexed-window
bend tools/verify-window.bend -o build/verify-old-window
for mesh_mode in live replay terminal; do
  (
    cd build/mesh-old-runtime
    DISPLAY=":$mesh_display_number" ENTANGLE_WINDOW_MODE="$mesh_mode" \
      "$mesh_repo/build/verify-old-window" "$mesh_mode" validation
  ) >"$mesh_evidence/old-$mesh_mode.log" 2>&1
done
mkdir -p build/mesh-creation-runtime/build build/mesh-creation-runtime/docs/verification \
  "$mesh_evidence/old-creation"
ln -sfn "$mesh_evidence/old-creation" \
  build/mesh-creation-runtime/docs/verification/2026-11-03-public-creation
bend tools/creation-window-app.bend -o build/mesh-creation-runtime/build/indexed-window
bend tools/verify-creation-window.bend -o build/verify-old-creation-window
(
  cd build/mesh-creation-runtime
  DISPLAY=":$mesh_display_number" "$mesh_repo/build/verify-old-creation-window"
) >"$mesh_evidence/old-creation.log" 2>&1
```

The old verification bridge enables synchronization validation through its
legacy setting and emits the existing deprecated-setting warning. Its gates
pass their established clean-diagnostics predicate. The mesh gate uses modern
validation settings and requires clean diagnostics without that warning.

## Recorded outcomes

All required gates passed on 2026-11-03. `proof.log` reports ALL PROOFS CHECK.
`native.log` ends with the pinned native compatibility verdict. `ecs.log`
records topology, selective real ECS replay, bounds, and retained rendering.
The final reviewed native run recorded 1,431 batches and 647 tick states.
Its batches included 818 zero-step polls, 17 two-step polls, one three-step
poll, and five four-step catch-up polls. `replay-live.log` matches every recorded state and
batch accounting. `replay-close.log` matches 20 hidden-Close batches.
`window.log` records all six held player directions, release and exact reset,
all six camera controls, the queued-focus property, unmap/restore, resize,
Escape, and Close. Both mesh process logs have no validation warnings/errors
and end with zero live Vulkan objects.

`ordinary/window.log` repeats the pixel and lifecycle checks with
`ENTANGLE_MESH_EVIDENCE` unset. This verifies the ordinary launch without
per-tick observation or evidence logging. Clock anchoring and authoritative
state checks require the traced run. Both ordinary process logs are also
clean and report zero live Vulkan objects. Its captures live under `ordinary/`.

`old-live.log`, `old-replay.log`, `old-terminal.log`, and `old-creation.log`
record successful unchanged window gates. The terminal verifier itself writes
no output on success; `old-window/terminal.log` contains the actual scoped
cleanup message. `old-binary.sha256` verifies that the original binary stayed
unchanged. The old native logs retain the bridge's known settings warning.

Independent parent verification rebuilt the app, reran the proofs, mesh runtime
driver, and full native baseline, then reran both traced and ordinary window
checks. `parent-review/` retains the independent proof and runtime logs.
The final window logs and captures above come from the independently rebuilt
application and corrected verifier.

Independent code review found no blocking issue. It identified two verification
improvements, both applied before the final window runs. The X11 helper now
matches only keysym slot zero, and ordinary-run messages report pixel stability
without claiming the traced clock/state checks. The comment review kept the
single native release-sequence comment after checking the pinned dependency.

The selected design reuses the schema and retains one full player handle. A
new marker/resource schema and a generic schedule framework were rejected
because this application has one permanent controlled entity. One implementation
owner kept the coupled ECS, input, proof, and verification changes consistent.

Captured PPM files were converted losslessly to PNG to keep the checked-in
evidence small. `initial.png`, `held.png`, `released.png`, `reset.png`,
`focus-restored.png`, `focus-burst.png`, and `unmap-restored.png` show the
native mesh scenario. Camera and extent captures are named `key-*.png` and
`resize-*.png`. The verifier regenerates PPM files on a new run. Convert them
with `magick input.ppm output.png` if PNG copies are wanted.

`captures.sha256`, `sources.sha256`, and `binaries.sha256` identify the captures,
production/proof/verification sources, and local executables. Source and binary
paths in these manifests are relative to the repository root. Dependencies are
unchanged, and all new application and verification code is Bend.

A verifier correction is retained under `observation-failure/`. The first
query-first rerun failed an overly strict comparison between a capture taken
while SIGSTOP was active and the resumed frame. SIGSTOP can interrupt between
ECS advancement and presentation. A pre-pause frame may therefore finish after
resume. The real trace showed unchanged authoritative state across the focus
marker and a zero-step batch. The revised driver checks those facts directly
for every focused-loss marker and still requires stable post-resume pixels.
The failed verifier run killed its owned child during cleanup, so that archived
partial log is not a successful shutdown record. Final gate logs are separate.

Recheck the archived real focus trace with the compiled verifier:

```sh
./build/verify-mesh-window focus-log \
  docs/verification/2026-11-03-mesh-playground/observation-failure/native-live.log
```

`observation-failure/state-check.log` records the successful authoritative
check. Use the native executable for this large trace scan. An attempted
standalone default-runner scan hit a Bend stack fault; the compiled driver
checked the same archived trace successfully. The final native gate also
pauses and resumes a focused, moving child without a focus change, and requires
a recorded four-step catch-up batch. This exercises the cap independently of
the focus-loss case, which must execute zero steps.
