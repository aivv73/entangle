# Entangle

Entangle's native dependency baseline uses Bendvy and bend-vulkan on Linux x86-64.
The pins and compiler requirements are in [toolchain.bend](toolchain.bend).
Git submodules retain the exact dependency revisions.

## Create a scene

Use immutable `Vertex`, `Mesh`, `Basic`, `Instance`, and `Camera` values from
`src/creation.bend`. Call `Create.compile` once and pass its seeds to
`Scene.create`. The same result supplies packed geometry to either renderer.
The [public example](examples/public-creation.bend) creates three real ECS
instances without resource IDs or Vulkan handles:

```sh
bend examples/public-creation.bend -o build/public-creation
./build/public-creation +RTS --threads 1 --gpu off
```

The [creation reference](docs/public-creation.md) describes validation, material
baking, draw ranges, camera configuration, and startup callbacks. The
[verification record](docs/verification/2026-11-03-public-creation/README.md)
contains the runtime evidence.

## Verify the native baseline

Use Bend 2.0.39 and Clang 23.1.4 targeting `x86_64-pc-linux-gnu`.
The Vulkan native effect ABI requires this Bend version. Verification rejects
other compiler versions, dependency revisions, and dirty dependency checkouts.

Install Vulkan development headers, `libvulkan.so.1`, and a Vulkan driver with
a graphics queue. The baseline is headless and requires no CUDA or display.
Bend's default runner also needs Node.js or Bun. The compiler and tools must
be available on `PATH`.

From this repository's root:

```sh
git -c protocol.entire.allow=always submodule update --init deps/bendvy deps/bend-vulkan
git -C deps/bend-vulkan submodule update --init deps/bend-collections
bend tools/verify.bend
```

The bend-vulkan checkout uses Entire's Git transport and your existing Entire
access. The command permits that transport for this invocation only. Bendvy
uses a shallow checkout to avoid downloading its full history.

The verifier runs the project component laws and imported Vulkan and Bendvy execution laws through `PROOF.bend`, generates C
with Bend, and compiles it with the pinned Clang using `-std=c11 -O2`.
One executable runs Bendvy's public scheduled-health example followed by
bend-vulkan's public buffer-roundtrip example. It compares the complete ECS
output, checks host and GPU buffer readback, and requires zero live Vulkan
objects after cleanup. A missing Vulkan device fails verification.
The Bend runtime uses one CPU thread with Bend GPU dispatch disabled; Vulkan
still executes the buffer fill on the graphics device.

A second native executable checks every component field, exact defaults, float bit
preservation, and translation replacement while preserving rotation and scale.
A third runs the shared mesh scene through eight schedule ticks and checks all
100 entities after every tick.

Successful verification ends with:

```text
Pinned native toolchain and dependency compatibility verified.
```

Build artifacts stay under `build/`. Upgrade pins in a separate change and rerun
verification. Do not use `git submodule update --remote` or `bend update` to
prepare this baseline.

This establishes native compilation and runtime compatibility. The offscreen
renderer below also verifies the first rendered ECS scene. The separate window
gate verifies input, camera controls, and presentation. Performance measurements
remain separate E1 work. Pure proofs do not cover the native ABI or GPU driver.

The [verification record](docs/verification/2026-11-02/README.md) contains the
successful run, exact commands, and environment details.

## Project components

`src/components.bend` imports only Base. Constructors and pattern matching expose
these records. They have no ECS registration or resource ownership.

| Record | Fields |
| --- | --- |
| `Vec3` | `x`, `y`, `z`: `F32` |
| `Quat` | `x`, `y`, `z`, `w`: `F32`, raw xyzw coefficients without a normalization guarantee |
| `Transform` | `translation: Vec3`, `rotation: Quat`, `scale: Vec3` |
| `Velocity` | `linear: Vec3`, translation units per second in the same frame as translation |
| `MeshRef` | `id: U32`, logical mesh key |
| `MaterialRef` | `id: U32`, logical material key |

`Transform.identity()` returns zero translation, rotation `(0, 0, 0, 1)`, and
unit scale. `Velocity.zero()` returns zero linear velocity. All `U32` IDs are
valid logical keys, including zero. Mesh and material keys use separate namespaces.
The records do not guarantee that an asset exists or manage its lifetime.

For a consumer beside `examples/components.bend`:

```python
import Base
import ../src/components.bend as C

def at(pose: C.Transform, translation: C.Vec3) -> C.Transform:
	C.Transform{_, rotation, scale} = pose
	C.Transform{translation, rotation, scale}

def main() -> C.Transform:
	at(C.Transform.identity(), C.Vec3{1.0, 2.0, 3.0})
```

`LAWS.bend` states reconstruction, field preservation, exact defaults, and
translation replacement claims. `PROOF.bend` proves them alongside the dependency
laws. These claims use structural equality without float arithmetic or quaternion
normalization assumptions. `bend tools/verify.bend` also runs the native consumer
in `examples/components.bend`. The scene below registers Transform and MeshRef
and supplies detached data to the offscreen renderer.

## Shared mesh scene

Run the native scene and all existing verification from the repository root:

```sh
bend tools/verify.bend
```

To run the scene alone with the same pinned compiler and runtime options:

```sh
mkdir -p build
bend examples/scene.bend -o build/scene.c
clang -std=c11 -O2 build/scene.c -lpthread -lm -ldl -o build/scene
./build/scene --threads 1 --gpu off
```

The scene starts with an empty Bendvy world. Its first schedule tick queues 100
entities, publishes them before movement, and translates each once by
`(1.0, 0.5, -2.0)`. Later ticks translate the same entities once each. Every entity
has a Transform and the same logical `MeshRef{7}`. A registered writer changes
only Transform translation and preserves rotation and scale.

The writer calls the pure `step(Unit{}, transform)` in `src/scene-step.bend`.
It returns the replacement transform and `Unit{}` for no gameplay events.
The [step contract](docs/step-kernel.md) defines the per-transform tick input,
ECS ownership, sequential execution, and separate schedule reports.
The [headless reference](docs/headless-reference.md) defines tick start,
immediate numerical writes, explicit bootstrap publication, and final apply.
It supplies checked evidence for future R0 work without completing R0.
The [state ownership contract](docs/state-ownership.md) keeps the retained ECS
world authoritative and specifies exclusive ownership transfer for future chunks.
Detached snapshots and drawing data carry no write authority.

The executable prints the empty initial population, then numerical and boundary
evidence for each tick. The last tick and success line are:

```text
tick=8 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted
boundaries tick=8 start=100 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0
Shared mesh scene verified across 8 ticks.
```

`src/scene.bend` owns registration and the retained two-node schedule.
`scene-schema.bend`, `scene-spawn.bend`, and `scene-motion.bend` define its two
component columns, one-time recursive bootstrap, and translation writer.
`scene-observe.bend` reads the actual retained world through Bendvy's passive
inspector. `examples/scene.bend` compares every row against independent integer
and half-integer arithmetic. It requires the complete live set to match the
admitted set by namespace, index, and generation. It rejects duplicate or missing
rows, failed component reads, unsuccessful schedule reports, changed handles,
remaining seeds, pending commands, and refused publication receipts.

`LAWS.bend` states general claims for translation, rotation and scale
preservation, seed contents and count, and exhausted-bootstrap behavior.
`PROOF.bend` contains their proofs. Native validation covers the framework's
registration, publication, and repeated execution for this 100-entity workload.
The bounded coordinates are exactly representable in F32. The proofs do not
assume arbitrary F32 associativity or prove the native runtime.

Mesh ID 7 is a shared logical identity. This ECS-only example has no mesh payload, asset
manager, renderer, or rotation update. It uses sequential CPU execution and adds
no GPU dispatch or runtime parallelism.

`Observe.draw_list(app, instance)` in `src/scene-observe.bend` returns
`(app, (instance, Result Draw.DrawList))`. Import `src/scene-draw.bend` for the
detached payload types. Each ordered `DrawItem` contains the complete `Transform`
and `MeshRef` ID. A scene before its first tick returns an empty list. Missing
required component reads fail the entire extraction without a partial list.

Thread the returned application and inspector instance into subsequent calls.
Extraction preserves the inspector instance and world clock, including a Fresh
instance, and retains every schedule/application field. DrawList contains no
World, handles, bootstrap evidence, or materials. It can be retained across ticks.
The drawing path shares the observer's strict component traversal and query
order without building a diagnostic Snapshot or separately enumerating handles.
`examples/scene.bend` validates exact ordered payloads, every transform float bit,
mesh IDs, repeated extraction, retained lists across ticks, and continued scene
execution. The formal drawing laws cover projection and local traversal steps;
they do not claim a proof of the complete runtime.

## Render the detached scene

Run the pinned verification command from the repository root.

```sh
bend tools/verify.bend
```

To run only the native renderer verification, use the pinned compiler.

```sh
mkdir -p build
bend examples/scene-render.bend -o build/scene-render.c
clang -std=c11 -O2 build/scene-render.c -lpthread -lm -ldl -o build/scene-render
env -u DISPLAY -u WAYLAND_DISPLAY ./build/scene-render --threads 1 --gpu off
```

The executable renders the actual observer's empty state and 100 objects across
eight ECS ticks in both near-first and far-first index orders. It compares every
RGBA8 byte and exact D32 word against independent integer rectangles and dyadic
depth encoding. It checks repeated frames, retained tick-one replay, empty after
populated, unknown mesh and invalid transform rejection followed by valid replay, observer cursor and
application clock preservation, and zero live Vulkan objects after scope cleanup.
A terminal Action error also closes a fully allocated scope. Scalar cross-product
checks cover distinct quaternion components, asymmetric XYZ input and translation,
and nonuniform XYZ scale. Open `build/scene-render.ppm` to inspect tick one.
The PPM is deterministic and is regenerated by each successful run.

`src/scene-render.bend` accepts a detached `Draw.DrawList`, compiled
`Create.Geometry`, and `Config` with a fixed four-column `scene-matrix.Mat4` camera. Call
`with(config, geometry, renderer => ...)` to own the Vulkan scope. Thread the renderer
returned by `render(renderer, draws)` into subsequent frames. Input errors return
`UnknownMesh` or `InvalidTransform` before recording. Vulkan Action failures end
the scope. `Entry.with` owns cleanup, including partial creation and completion.
The renderer imports no ECS modules or dependency examples. It uploads geometry
once per scope and resolves each mesh reference to its indexed range. Attachments,
staging, pipeline, command buffer, and fence are reused. Empty geometry owns no
vertex or index buffers and renders only the clear values.

Matrices use column vectors and column-major serialization. Each draw pushes
`camera * T * R(q) * S` as the shader's existing sixteen words. Finite quaternion
coefficients are preserved, with squared norm accepted in `[0.9999, 1.0001]`.
Finite model-camera products are required. Mesh vertices contain XYZ position and
RGB color. Indices are U32 triangles. The target clears to opaque blue and depth
one, uses RGBA8 UNORM and D32 SFLOAT with LESS depth testing, and reads both planes
synchronously. There is no window or asset registry.

Targets are bounded to 4096 per axis and 4,194,304 pixels, then checked against
device limits. Packed geometry is bounded to 699,050 vertices and three million indices.
Each upload or plane readback fits the public API's 16 MiB transfer limit. Missing graphics
queues, formats, compatible memory, or supported copy alignment fail explicitly.
The verification mesh and camera are specific to the executable, not the renderer.
The independently derived coverage bound and exact depth formula are recorded in
`docs/render-verification.md`. Formal claims in `LAWS.bend` cover push-constant
extent and index validation under concatenation and reordered mesh sections.
They do not prove driver behavior or arbitrary floating-point matrix algebra.

## Run the ECS window

Install X11 development headers and use an X11 display with Vulkan presentation
support. From the repository root:

```sh
mkdir -p build
bend examples/scene-window.bend -o build/indexed-window
./build/indexed-window
```

A/D orbit, W/S change elevation, Q/E zoom, and R resets the existing camera.
Escape or Close exits. The 100 shared cubes advance one genuine ECS tick every
250 ms, including while hidden. They overlap into a dense line because the
original scene positions and scales are unchanged. The view stays centered on
tick one, so the scene eventually leaves the view. R resets the camera, not ECS.

The window renderer uses the dependency's back-face-culling pipeline. Supply a
closed, consistently wound mesh with orientation-preserving model transforms.
It does not promise arbitrary-mesh parity with the unculled offscreen renderer.
The example uploads the existing cube faces once, without the dependency's floor.

## Run game logic without graphics

`src/headless.bend` advances an existing affine application by an explicit number
of sequential ticks and returns it. The caller creates the scene and supplies
its tick callback. Zero ticks returns the unchanged application.

```sh
mkdir -p build
bend examples/scene-headless.bend -o build/scene-headless.c
clang -std=c11 -O2 build/scene-headless.c -lpthread -lm -o build/scene-headless
env -u DISPLAY -u WAYLAND_DISPLAY ./build/scene-headless +RTS --threads 1 --gpu off
bend tools/verify-headless.bend
```

The example prints `Headless scene completed 8 production ticks.`
The CPU gate rebuilds the example, the existing observed reference, and the
production batching verifier with the pinned Bend and Clang versions.
It requires no Vulkan checkout, headers, loader, display, or GPU.
The [runner contract and isolated build evidence](docs/headless-reference.md)
describe ownership, failure behavior, and verification limits.

## Verify the ECS window

Run the graphics-inclusive native gate and the separate native-window gate:

```sh
bend PROOF.bend
bend tools/verify.bend
bend tools/verify-window.bend -o build/verify-window
./build/verify-window
```

The window gate builds and drives **Entangle's** executable at
`build/indexed-window`. It requires an unobscured display that respects requested
client sizes. Tiling desktops can override resize requests. For deterministic
resizing, start an owned rootful Xwayland and stop it after the verifier exits:

```sh
mkdir -p build/window-evidence
: > build/window-evidence/display
Xwayland -displayfd 3 -geometry 1280x1024 -nolisten tcp \
  3>build/window-evidence/display >build/window-evidence/xwayland.log 2>&1 &
window_display_pid=$!
trap 'kill "$window_display_pid" 2>/dev/null; wait "$window_display_pid" 2>/dev/null' EXIT
for attempt in $(seq 1 100); do
  [ -s build/window-evidence/display ] && break
  kill -0 "$window_display_pid" || break
  sleep 0.05
done
[ -s build/window-evidence/display ] || exit 1
read -r window_display_number < build/window-evidence/display
DISPLAY=":$window_display_number" ./build/verify-window
```

Live execution checks populated geometry, successive ECS movement, ticks while
hidden, and hidden Close. Retained tick-one replay checks all six camera keys,
exact R reset, repeated portrait and landscape resizing, unmap/restore, and Escape.
It also checks rejected-input recovery and scoped terminal-error cleanup. All
scenarios check live Vulkan objects after Entry returns and reject validation
errors. Khronos and synchronization validation run when discovery finds the layer.
Logs and PPM captures go to `build/window-evidence`.

`ENTANGLE_WINDOW_MODE=replay` retains the genuine tick-one DrawList while the
World reaches tick two. `ENTANGLE_WINDOW_MODE=terminal` returns an intentional
Action error after a frame to verify scope cleanup. Both are verification modes
of the same executable and rendering path.

See [the window verification record](docs/window-verification.md) for the
verified environment, API contract, proof scope, and limitations.


## Record the native window baseline

The separate bounded collector uses the same renderer and indexed-draw traversal.
It records exact CPU spans, GPU timestamps, successful host mesh writes, accepted
push payloads, indexed draws, and submissions. The normal window API and controls
remain available with diagnostics off.

```sh
bend examples/scene-window-baseline.bend -o build/scene-window-baseline
bend tools/baseline-collect.bend -o build/baseline-collect
DISPLAY=":$window_display_number" timeout --signal=TERM --kill-after=5s 600s \
  ./build/baseline-collect +RTS --threads 1 --gpu off
```

Use the owned rootful Xwayland setup above and stop it after collection. Preserve
`docs/verification/2026-11-03-baseline` before rerunning because the driver writes
its named output files there. It runs five fresh live and five fresh replay
processes in alternating order. Each process has an external watchdog. A failed
repeat stops collection and retains its output and status.

The live collector uses fixed 250 ms ECS steps, with at most four catch-up steps
per poll, and extends steady collection until eight actual live ticks complete.
It records executed and dropped steps and sums each batch's CPU spans.
Replay retains tick-one drawing while the
real world is at tick two. Both use 30 completed warm-up frames, at least 120 steady
frames, a fixed initial camera, a 640 by 480 window, and one frame slot.

See [the measured baseline](docs/baseline-measurements.md) for actual results,
exact timing and counter boundaries, provenance, limitations, raw evidence, native
validation, and complete rerun commands. These instrumented values make no speedup
claim. Push payload bytes are separate from host mesh writes and physical traffic.

## Application ownership

The [frame-order contract](docs/frame-order.md) defines the E2 phase sequence and
distinguishes it from the current demonstration loop. The
[fixed-timestep policy](docs/fixed-timestep.md) implements bounded scheduling,
fractional carry, whole-step dropping, and clock-regression handling.
Global-transform propagation remains unimplemented.

The [schedule-visibility reference](docs/schedule-visibility.md) defines when
Bendvy publishes structural commands and how removal notices reach readers and
expire. It distinguishes dependency semantics from the current scene, which has
no removal producer or reader.

`examples/scene-window-app.bend` owns concrete scene state, mesh, camera projection,
observation, drawing, retention, and verification. `examples/scene-window.bend`
owns executable modes and the interactive loop. `src/app.bend` owns the Vulkan
entry scope and post-scope live-object count. `src/time.bend` owns fixed-step
configuration, clock state, and bounded catch-up batches. `src/input.bend` owns the camera controller and
snapshot event draining. `src/error.bend` owns shared Action requirements and
renderer input-error promotion. The baseline retains its instrumented execution
and reporting policy.

The [extraction verification record](docs/verification/2026-11-03-app/README.md)
records the native checks and before/after replay comparison.

`src/modules.bend` declares the four required startup slots in
`Registration<A>`. `Core<A>` produces `IO(A)`, Input supplies the initial camera,
Assets supplies a public scene description, and Render receives compiled geometry.
The example assembles its defaults in `examples/scene-window-modules.bend`:

```bend
def defaults() -> Modules.Registration<Scene.Application()>:
	Modules.Registration{Modules.Core{core_start},Modules.Input{input_start},Modules.Assets{asset_load},Modules.Render{render_open}}
```

Import `src/modules.bend` as `Modules` and supply your top-level operations through
these constructors. The example adapters show the required signatures.
Registration is fixed in source and supports startup only. Callback erasure by
the compiler is not guaranteed. Assets and Core share one compilation result.
The [creation reference](docs/public-creation.md) specifies the callback types.

`examples/scene-window.bend` consumes each operation once in its existing startup
order. Compilation supplies geometry to Render and seeds to Core. Core groups
`Scene.create(seeds)` and the first `Scene.tick()`. The registration
never enters `Running` or the hot loop. Scope, concrete state, event handling,
timing, observation, and loop ownership remain with the owners above.
The [module synthesis record](docs/modules-registration.md) explains the selected
contract and proof boundary.
