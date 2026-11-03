# Mesh movement

The mesh playground lets you move an orange octahedron among fixed shapes, stop movement on release or lost focus, and restore its starting position.

## Sub-features

- `mesh-axes` moves with I/K along -Z/+Z, J/L along -X/+X, and U/O along +Y/-Y.
- `mesh-held` continues movement while held and handles repeated key presses.
- `mesh-opposite` cancels opposing movement keys.
- `mesh-release` stops movement after release.
- `mesh-reset` restores the initial transform with Space and clears held input.
- `mesh-inactive` clears held input after focus loss or unmap, including queued focus changes.
- `mesh-replay` reproduces recorded states through the actual ECS application.

## How to get to it (user POV)

Build `examples/mesh-playground.bend` and launch the resulting native executable. The title starts with `Mesh playground | IJKL UO move`. Focus this window, hold a movement key, release it, or press Space. Camera controls are a separate feature.

## Driving it with Bend X11 drivers

Preconditions: use the skill's complete launch block, owned Xwayland, validation layer, and `ENTANGLE_MESH_EVIDENCE=1`.

- **Move each axis.** The launch block's `run window timeout --signal=KILL 120s "$entangle_evidence/bin/verify-mesh-window"` sends all six held keys. Require six `player-axis=... held=moved release=stable Space=exact` messages for key symbols 105, 107, 106, 108, 117, and 111.
- **Hold and cancel.** The same driver holds J, repeats J, and adds L. `held.ppm` must differ from `initial.ppm`. The driver checks stable pixels with both keys held and after the remaining key is released. Keep `opposite.ppm` and `released.ppm`.
- **Reset.** Space must return exactly to `initial.ppm`. The launch block compares it with `reset.ppm`. The driver also checks that motion stays stopped.
- **Lose focus.** The driver changes real X11 focus, queues FocusOut/FocusIn during a process pause, and unmaps/remaps the window. Keep `focus-restored.ppm`, `focus-paused.ppm`, `focus-burst.ppm`, and `unmap-restored.ppm`. Its trace check requires zero steps and unchanged authoritative state for queued focus-loss batches.
- **Replay.** The launch block runs `replay-mesh-window` separately on `native-live.log` and `native-close.log`. Both must exit zero and report matching full handles and transform bits. These checks include static objects and player bounds.

## Gotchas

- Space resets the object. R resets only the camera.
- Movement uses fixed 16 ms steps with at most four catch-up steps. Do not assert a fixed distance from a wall-clock key hold.
- X/Z are bounded to [-3,3] and Y to [-0.2,2.5]. Motion can stop at a bound while a key remains held.
- The live opposing-key case exercises J/L. To cover cancellation on all axes and runtime bounds directly, run `bend tools/verify-mesh-playground.bend` sequentially from the repository root and retain its output. That supplemental real ECS/rendering gate does not replace X11 input proof.
- Do not require the SIGSTOP capture to equal the first post-resume capture. A frame computed before the pause can finish presentation later. The authoritative trace and stable post-resume frames establish focus-loss behavior.
- Ordinary untraced execution cannot prove the trace-only state and catch-up claims.
