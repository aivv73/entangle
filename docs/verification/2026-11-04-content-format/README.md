# Mesh and material format verification

The engine owns one source format in [content.bend](../../../src/content.bend).
The [reference](../../content.md) defines the supported values and importer
obligations. The [design rationale](../../public-creation-design.md#source-ownership)
records the boundary and rejected alternatives.
The [reviewable change](https://entire.com/et/bend-engine/-/trails/24/changes/entangle/21)
is based on `513e5e4935987e8c11d9d652f83a2b6e5beb8d78`.

## Implementation evidence

Fresh local evidence is retained in
`build/verification/internal-content-FIv2ZfM1`. Its README lists commands, exit
statuses, source hashes, native binaries, and corrected authoring attempts.
Root proofs, the procedural source-cache example, the asset verifier, public
creation, mesh playground execution, and isolated headless execution pass.

The source-only asset check copies exactly the example, Content, Components,
and Asset modules, then compiles and executes that copy. Both payload types use
the production cache and remain usable after release. The isolated headless
run compiles without a graphics checkout, graphics loader, display, or GPU.

Eight new root claims cover mesh and material equality reflexivity, bake count
and concatenation, validation error priority, and duplicate geometry reuse.
Existing white identity, position preservation, and index properties now name
Content directly. No existing claim or premise was weakened. These are frontend
proof checks, not a new BendTT kernel verdict or a proof of native rendering.

## Coordinator review

The coordinator inspected the complete diff and confirmed direct consumer
migration, unchanged six-word vertex serialization, source bounds, error priority,
reference numbering, and first-use order. The procedural triangle is shared by
the source-only and scene examples. No old format wrappers remain.

The native creation verifier's output matches the pre-change run byte for byte.
The baseline is `build/verification/mesh-material-baseline/creation.log`.
Both runs exercise actual ECS identities, packed ranges, colors, depth, retained
replay, rejection recovery, empty geometry, cameras, and zero-object cleanup.

## Baseline window attempt

`build/verification/entangle-OSL6jObG` retains the pre-change native window run.
All movement, camera, resize, focus, hidden Close, validation, and cleanup checks
passed. Live replay matched 1,486 recorded batches. The hidden-Close trace had
ten batches and failed the unchanged replay gate's requirement for more than ten.
The attempt therefore has exit one. Its owned display and runtime were removed.
Initial, held, and reset captures were inspected. Initial and reset bytes match.

## Final verification

The coordinator ran `bend tools/verify.bend` with Khronos validation and
synchronization validation enabled. It exited zero. The complete log and status
are in `build/verification/internal-format-final/native.log` and `native.status`.
The gate includes source-only cache execution, root proofs, native failure-handler
verification, checked uploads, real ECS execution, exact RGBA and D32 readback in
both index orders, mesh replacement, retained resources, and genuine allocation
failure with rollback and recovery. All Vulkan paths finish with zero live objects.
No validation errors, synchronization hazards, or VUID diagnostics were emitted.

The coordinator inspected the retained offscreen image in that evidence directory.
Other backends and performance are outside this change. The native failure
verifier states its unexercised driver errors explicitly in the log.

The final X11 run is `build/verification/entangle-7qTn51Zw`. It follows the
verify-entangle launch recipe with the cube and public-creation additions.
Every stage and the complete run exited zero. The cube passes live movement,
hidden ticks, retained replay, all camera controls, resize, restore, Escape,
Close, and terminal Action cleanup. The public scene capture contains red,
green, and white geometry with ranges `3,3,6`.

The mesh playground passes all six movement axes, held and repeated input,
opposites, release, reset, camera controls, focus changes, resize, and hidden
Close. Full-state replay matches 1,493 live batches and 14 hidden-Close batches.
The initial and reset captures match each other and the pre-change captures
byte for byte. Initial, held, reset, and material captures were inspected.
Native logs contain no validation diagnostics and report zero live Vulkan objects.
Cleanup reaped owned display PID 230472 and removed only the disposable runtime.

The earlier short-trace failure remains recorded above. Neither the replay
threshold nor the window driver changed. These results cover the pinned Linux
X11/Vulkan lane, not every driver, backend, or possible source mesh.
