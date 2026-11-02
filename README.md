# Entangle

Entangle's native dependency baseline uses Bendvy and bend-vulkan on Linux x86-64.
The pins and compiler requirements are in [toolchain.bend](toolchain.bend).
Git submodules retain the exact dependency revisions.

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

This establishes native compilation and runtime compatibility. The first
rendered ECS scene, window/input integration, and performance measurements
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
in `examples/components.bend`. The scene below registers Transform and MeshRef.
Rendering remains separate E1 work.

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

The executable prints the empty initial population, then one verified line per
tick. The last tick and success line are:

```text
tick=8 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted
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

Mesh ID 7 is a shared logical identity. This example has no mesh payload, asset
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
