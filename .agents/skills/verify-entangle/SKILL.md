---
name: verify-entangle
description: Verify Entangle's source assets, PNG decoder, production laws, native rendering and resource behavior, and X11 controls/replay through existing drivers. Select affected checks after code or verification changes.
---

# Verify Entangle

Read [the feature map](features/README.md) first. Entangle's primary interactive app is a native X11 window. Its other user paths are Bend scene descriptions and command-line examples. There is no web server, account, database, or seed service. Examples supply their own scene data.

For formal verification maintenance, follow [the law checks](features/formal-laws.md).
That entry records covered code, assumptions, commands, mutation controls, and
the synchronization commit separately from live-window evidence.
Accepted geometry publication uses freshly extracted pure declarations;
follow the linked publication driver as well as root `PROOF.bend`.
Acquisition, presentation, swapchain replacement, and window-close changes also
use [verify-presentation](../verify-presentation/SKILL.md). Window profiles require
its bounded proofs and sensitivity controls alongside the live evidence.

## Select required evidence

Follow [the development workflow](../../../docs/development.md). Create `build` with `mkdir -p build`, run `bend tools/verify-workflow.bend -o build/verify-workflow`, inspect `./build/verify-workflow --plan PROFILE...`, then execute the affected profiles. The runner retains a source snapshot, commands, per-stage statuses and logs. Required failures and unexecuted stages cannot produce a passing receipt. Read the feature map for scenarios outside the profiles.

Keep one implementation owner. For a new critical verifier, establish sensitivity to the named production defect and restore the baseline. Use a focused independent check only for a concrete uncertainty about the oracle, bounds, or production correspondence; no automatic adversarial panel.

## Launch

Run from the repository root on Linux x86-64. Read `AGENTS.md`, run `bend guide`, and check `toolchain.bend`. The current native lane requires Bend 2.0.39, Clang 23.1.4, Node.js or Bun, initialized dependencies, Vulkan and X11 development headers, and a Vulkan graphics/presentation device. The live recipe also needs `Xwayland`, a working parent Wayland session, and `VK_LAYER_KHRONOS_validation`.

Inspect dependencies with `git submodule status --recursive`. If they are missing, use the README's initialization commands. Stop on a build or startup failure and retain its logs. Do not treat a headless pass as a window pass.

The executable launcher contains the complete mesh verification lifecycle. It builds fresh executables, starts an owned rootful Xwayland, runs the doctor, drives the app, replays both traces, and cleans up. Each invocation prints its evidence path. Allow several minutes for compilation.

The isolated working directory redirects the drivers' historical output paths into fresh evidence. Never symlink its `docs` directory to the repository's real `docs`. Never replace the repository's `build/indexed-window` with the mesh executable.

```bash
bash tools/verify-window-session.sh
```

The display number file signals Xwayland readiness. The Bend driver then locates only its child's window by PID and waits for a populated 640×480 frame. Its first capture must contain all four mesh materials. A blank window or a live process alone is insufficient.

This recipe uses the existing helper's unauthenticated X11 TCP connection on a disposable display. Do not redirect it to the user's display. Independent runs have distinct display numbers and directories. Repository-wide gates that write fixed `build` paths must run sequentially.

## Doctor

The launcher runs `doctor` before input. Run it again from the launch shell whenever ownership looks wrong. It is one read-only check of the owned display process, display number, TCP port, evidence destination, and exact executable bytes. `doctor.log` records its result. A failed check means stop and run cleanup. The live driver's populated-frame and validation checks establish renderer health after launch.

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

The launcher in `tools/verify-window-session.sh` builds and orchestrates the existing Bend drivers. Their invocations appear above and in the feature map. Keep verification behavior in those Bend drivers. Use `/maintain-verification-skill` when controls, paths, or observable results change.
