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
in `examples/components.bend`. ECS schema registration, movement, and rendering
remain separate E1 work.
