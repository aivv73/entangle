# Entangle verification map

Read this index before choosing checks. Each file maps user actions to existing Bend drivers and observable results. The map describes coverage to run, not a claim that every path passed in the latest session.

## Baseline preconditions

- Run from the repository root with the toolchain and dependency revisions in `toolchain.bend`.
- Use the skill's fresh runtime and owned display for native window checks. Drivers find only their own child window.
- Run the doctor before input. Preserve evidence outside disposable runtime state.
- Run gates that write fixed repository `build` paths sequentially. Do not drive or terminate another session's app.
- Read `AGENTS.md`. Use formal laws, real runtime checks, and live input/replay evidence. Add no unit tests or mocks.

## Driving conventions

The complete launch block drives mesh movement. Camera-window additions run inside that same shell before its `run window ...` line, while the owned display is alive. CPU and offscreen recipes are independent shell invocations. They create their own evidence directory and exit after the real process returns.

Use the exact key symbols and native driver modes in the feature files. Do not infer desktop coverage from a headless run. Do not reuse archived captures as evidence for a new build.

## Proof and skip reporting

Record the feature ID, entry point, command, output, exit status, and resulting state. For UI changes, retain captures, native action/state traces where available, and zero-object shutdown logs. For file output, inspect the resulting file. Report build failures and missing display, validation layer, or device prerequisites explicitly.

A mesh pass covers the mesh entry of camera controls. It does not establish the cube entry. A creation CLI pass does not establish rendered colors or depth. If a change affects multiple entries, run all affected entries or list those skipped.

## Features

- [Formal laws](formal-laws.md): production Bend definitions, the universal upload-range theorem, mutation controls, and synchronization records.
- [Checked host uploads](upload-boundary.md): enforced source policy, exact production payload lengths, real Vulkan writes and readback, rejection, and cleanup.
- [Mesh replacement](mesh-replacement.md): both renderer APIs, changed pixels and ranges, rejected-candidate preservation, recorded commands, multiple submissions, uniform and sampled-image descriptor retention, memory aliases, atomic retirement rejection, collection, and cleanup.
- [Native resource failures](resource-failures.md): recording/submission/reset rejection, real allocation failure under a process limit, partial preparation rollback, cleanup diagnostics, terminal teardown, and bounded proofs of production handlers for rare driver errors.
- [Mesh movement](mesh-movement.md): six movement keys, held/repeated/opposing input, release, Space reset, and focus loss.
- [Camera and window controls](camera-window.md): both interactive apps, camera reset, resize, hide/restore, Escape, and Close.
- [Public scene creation](scene-creation.md): scene descriptions, compilation, separate instances, shared geometry, and validation.
- [Headless simulation](headless-simulation.md): eight production ticks, zero-step preservation, split batches, and observations.
- [Offscreen rendering](offscreen-rendering.md): image output, exact coverage/depth, retained draws, and resource cleanup.

Application module registration is a developer API described in `docs/modules-registration.md`. This seed map does not claim exhaustive API coverage. Extend it when a task changes an unmapped user path.
