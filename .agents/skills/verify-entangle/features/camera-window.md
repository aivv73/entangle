# Camera and window controls

Both interactive examples let you orbit and zoom the camera, resize or hide the window, and exit while releasing Vulkan resources.

## Sub-features

- `camera-orbit` uses A/D for orbit and W/S for elevation.
- `camera-zoom` uses Q/E to change distance.
- `camera-reset` restores the camera with R.
- `window-resize` redraws geometry at new extents and revisited extents.
- `window-restore` resumes presentation after unmap/remap.
- `window-exit` exits through Escape or a window-manager Close event.
- `cube-live` advances the cube world over time, including while hidden.
- `cube-replay` renders retained tick-one drawing data after the world reaches tick two.

## How to get to it (user POV)

- Build and run `examples/mesh-playground.bend` for the controllable object scene.
- Build and run `examples/scene-window.bend` for the 100-cube simulation.
- In either window, use A/D, W/S, Q/E, and R. Resize, hide/restore, press Escape, or use the window's Close action.

## Driving it with Bend X11 drivers

Preconditions: the skill's launch shell owns a ready Xwayland and has passed its doctor.

- **Mesh entry.** The complete launch recipe already taps key symbols 97, 100, 119, 115, 113, and 101. Require `geometry-moved=true R=exact` for each. It also exercises repeated resize, restored focus, unfocused Escape, and hidden Close. Both native logs must report zero live Vulkan objects.
- **Cube entry.** Insert the following block immediately before `run window ...` in the launch recipe. It builds the actual cube example, runs all three existing scenarios, keeps their output separately, and restores the mesh binary and evidence link before the mesh run resumes.

```bash
cd "$entangle_repo"
run build-cube bend examples/scene-window.bend -o "$entangle_evidence/bin/cube-window"
run build-cube-driver bend tools/verify-window.bend -o "$entangle_evidence/bin/verify-window"
sha256sum "$entangle_evidence/bin/cube-window" "$entangle_evidence/bin/verify-window" >> "$entangle_evidence/binaries.sha256"
mkdir -p "$entangle_evidence/cube"
cp "$entangle_evidence/bin/cube-window" "$entangle_runtime/build/indexed-window"
rm "$entangle_runtime/build/window-evidence"
ln -s "$entangle_evidence/cube" "$entangle_runtime/build/window-evidence"
cd "$entangle_runtime"
run cube-live timeout --signal=KILL 120s env ENTANGLE_WINDOW_MODE=live "$entangle_evidence/bin/verify-window" live validation
run cube-replay timeout --signal=KILL 120s env ENTANGLE_WINDOW_MODE=replay "$entangle_evidence/bin/verify-window" replay validation
run cube-terminal timeout --signal=KILL 120s env ENTANGLE_WINDOW_MODE=terminal "$entangle_evidence/bin/verify-window" terminal validation
cp "$entangle_evidence/bin/mesh-playground" "$entangle_runtime/build/indexed-window"
rm "$entangle_runtime/build/window-evidence"
ln -s "$entangle_evidence/mesh" "$entangle_runtime/build/window-evidence"
run doctor-after-cube doctor
```

- **Observe the cube results.** `cube-live.log` must report successive geometry movement, hidden ticks, and hidden Close. `cube-replay.log` must report exact camera resets, repeated resize, restored presentation, and Escape. The application log `cube/replay.log` must contain `replay-tick=1 world-tick=2 retained=exact` and `renderer recovered`. `cube/terminal.log` must report terminal Action cleanup with zero live objects. Keep the PPM files under `cube`.

## Gotchas

- The ordinary cube scene moves out of view over time. R never resets its simulation. Exact reset pixels are checked using retained tick-one rendering in replay mode.
- A restored window can still show old pixels. The cube driver requires D to change geometry after restore and R to restore the baseline.
- Do not invoke the cube driver's default mode from the isolated runtime. It tries to build sources relative to its current directory. Explicit `live`, `replay`, and `terminal` modes use the fresh binary already installed there.
- The terminal scenario intentionally exercises a scoped failure. It proves that cleanup path, not device-loss recovery.
