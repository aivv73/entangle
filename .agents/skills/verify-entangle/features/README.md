# Entangle verification map

Read this index before choosing checks. Each file maps user actions to existing Bend drivers and observable results. The map describes coverage to run, not a claim that every path passed in the latest session.

## Baseline preconditions

- Run from the repository root with the toolchain and dependency revisions in `toolchain.bend`.
- Use the skill's fresh runtime and owned display for native window checks. Drivers find only their own child window.
- Run the doctor before input. Preserve evidence outside disposable runtime state.
- Run gates that write fixed repository `build` paths sequentially. Do not drive or terminate another session's app.
- Read `AGENTS.md`. Use formal laws, real runtime checks, and live input/replay evidence. Add no unit tests or mocks.

## Driving conventions

The executable `tools/verify-window-session.sh` launcher drives mesh movement. For additional camera-window scenarios, follow that feature recipe with its own owned display and runtime. CPU and offscreen recipes are independent shell invocations. They create their own evidence directory and exit after the real process returns.

For an optional window block, copy `tools/verify-window-session.sh` into the ignored `build/verification` directory, insert the block before its `run window ...` command, and run that copy from the repository root. Keep the copied script with the evidence. Do not edit the shared launcher or run the block after its display has been cleaned up.

Use the exact key symbols and native driver modes in the feature files. Do not infer desktop coverage from a headless run. Do not reuse archived captures as evidence for a new build.

## Proof and skip reporting

Record the feature ID, entry point, command, output, exit status, and resulting state. For UI changes, retain captures, native action/state traces where available, and zero-object shutdown logs. For file output, inspect the resulting file. Report build failures and missing display, validation layer, or device prerequisites explicitly.

A mesh pass covers the mesh entry of camera controls. It does not establish the cube entry. A creation CLI pass does not establish rendered colors or depth. If a change affects multiple entries, run all affected entries or list those skipped.

## Features

Use the [verification profiles](../../../../docs/development.md#run-verification) to select required checks. Profile success is scoped to its listed scenarios.

- [Formal laws](formal-laws.md): production Bend definitions, the universal upload-range theorem, mutation controls, and synchronization records.
- [S41 math qualification](../../../../docs/verification/2026-11-05-jonmath/README.md): explicit candidate adapters, numerical contracts, sensitivity controls, and exact retained scene comparisons through the `math` profile.
- [Source assets](../../../../docs/assets.md#verification-and-limits): typed cache handles, real file loading, cached failures, release/retry, exact retained mesh and material sources, source-only dependency closure, and scene execution after source release.
- [PNG source images](images.md): pinned decoder, retained real images, complete-pixel comparison, file/cache/retry behavior and production mutation controls.
- [Static OBJ sources](models.md): pinned parser, exact mesh/material/label conversion, file/cache/retry, source-only closure, real ECS/offscreen geometry, and owned X11 culling evidence.
- [JSON scene files and manifests](json-scene.md): one pinned parser, strict schema and reference validation, bounded loading, cache/retry, source preservation, and real ECS/offscreen evidence.
- [Scene hierarchy](scene-hierarchy.md): parent validation, complete affine globals and world bounds, transactional edits, lighting, actual ECS replay, X11 controls, sensitivity controls, and measured sequential propagation.
- [Hierarchy formal verification](../../verify-hierarchy-formal/SKILL.md): universal cardinality and conditional traversal/publication proofs, explicit certificate-construction gaps, schedule rollback, and production sensitivity controls.
- [Checked host uploads](upload-boundary.md): enforced source policy, exact production payload lengths, real Vulkan writes and readback, rejection, and cleanup.
- [Mesh replacement](mesh-replacement.md): both renderer APIs, changed pixels and ranges, rejected-candidate preservation, recorded commands, multiple submissions, uniform and sampled-image descriptor retention, memory aliases, atomic retirement rejection, collection, and cleanup.
- [Native resource failures and lifetime](resource-failures.md): recording/submission/reset rejection, real allocation failure under a process limit, partial preparation rollback, cleanup diagnostics, terminal teardown, and bounded production proofs of rare driver errors, retirement, reference graphs, and collection.
- [Presentation ownership](../../verify-presentation/SKILL.md): acquisition serials, stale leases, separate render/present completion, binary semaphore and fence reuse, retry/uncertainty, and resize/Close. Required by window profiles and before multiple frames in flight or asynchronous presentation.
- [Bend 2.0.40 pointer ABI](../../../../docs/verification/2026-11-07-bend-2.0.40/README.md): the owned window launcher runs `verify-pointer-mutations`, which sends real X11 button, motion, and scroll events to the production bridge. It checks pointer identity, `Tool.Mouse`, signed F32 coordinates, timestamps, all three W3C button identities and both edges, rejects the old middle/right mapping, and restores the passing source.
- [Mesh movement](mesh-movement.md): six movement keys, held/repeated/opposing input, release, Space reset, and focus loss.
- [Camera and window controls](camera-window.md): both interactive apps, camera reset, resize, hide/restore, Escape, and Close.
- [Public scene creation](scene-creation.md): scene descriptions, compilation, separate instances, shared geometry, and validation.
- [Headless simulation](headless-simulation.md): eight production ticks, zero-step preservation, split batches, and observations.
- [Offscreen rendering](offscreen-rendering.md): image output, exact coverage/depth, retained draws, and resource cleanup.
- [Textured materials](../../../../docs/textured-materials.md): vertex attributes, PNG cache release, sampling and lighting, camera updates, texture replacement and retention, shader controls, and the textured X11 example.

Application module registration is a developer API described in `docs/modules-registration.md`. This seed map does not claim exhaustive API coverage. Extend it when a task changes an unmapped user path.
