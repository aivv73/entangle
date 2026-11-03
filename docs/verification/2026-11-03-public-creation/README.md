# Public creation verification

This run verifies the startup creation API on `feat/public-creation` on November
3, 2026. The implementation is tracked in
[change 16](https://entire.com/et/bend-engine/-/trails/15/changes/entangle/16).
The [reference](../../public-creation.md) describes the final API. The
[design synthesis](../../public-creation-design.md) records the selected
simplification and the fixture projection correction.

## Results

- [Proof log](proof.log) reports `ALL PROOFS CHECK`. Ten new claims cover white
  vertex and mesh identity, preserved positions, ordered seed conversion, bundle
  count, empty compilation, empty and matching range resolution, empty traversal,
  and camera reset configuration. Proofs call production functions. This is the
  standard Bend checker, not `--verdict` validation.
- [Native log](native.log) records `bend tools/verify.bend`. It retains the pinned
  dependency checks, real ECS eight-tick oracle, both triangle index orders,
  exact RGBA8 and D32, repeated frames, retained replay, invalid-input recovery,
  terminal cleanup, and zero live Vulkan objects.
- [Creation log](creation.log) records the production creation verifier. Four
  distinct Bendvy entities use three materialized ranges of 3, 3, and 6 indices.
  Repeated red instances share a range. Actual ECS rows match compiled seeds
  after each of two ticks, with exhausted bootstrap and clean publication.
  Actual red, green, and white pixels appear. D32 at colored geometry is exactly
  `0.28125` at tick one and `0.03125` at tick two. White and tinted scenes have
  identical complete depth readback. Retained replay is exact after a rejected
  unknown reference. Every scope leaves zero live Vulkan objects.
- The creation verifier also executes empty startup and an empty-mesh entity.
  Both render only the clear color and depth. Production renderer storage uses
  `None` for geometry buffers. Invalid indices, material channels, and quaternion
  transforms fail compilation. A configured target and lens survive six camera
  controls and reset. Zero extent and an invalid lens reject view creation.
- [Window log](window.log) records the existing real X11 gate on an owned rootful
  Xwayland with Khronos and synchronization validation. Live movement, bounded
  catch-up, hidden ticks, hidden Close, six camera controls, repeated resizes,
  retained replay, unmap/restore, Escape, rejection recovery, and terminal cleanup
  pass. Every completed scope reports zero live Vulkan objects.
- [Comparison log](equivalence.log) records byte-identical results for all 13
  deterministic before/after captures and the replay and terminal logs. The full
  native baseline log and the offscreen PPM also compare byte-identically.
  No expected pixel values changed. [Offscreen hashes](offscreen.sha256) and
  [capture hashes](window-captures.sha256) identify the preserved artifacts.
- [Material window log](material-window.log) records a separate actual X11
  capture of the new compiled scene. The driver checks substantial exact red,
  green, and white coverage and clean shutdown. The
  [process log](material-process.log) retains the validation settings notice and
  the zero-object shutdown. The [capture](materials.png) shows two triangles and
  a quad. Its source PPM is [preserved](materials.ppm).
- [Public example log](example.log) records the example's two production ticks.
  The example imports no Vulkan module or handles.

The baseline [native](native-before.log), [proof](proof-before.log), and
[window](window-before.log) logs are preserved here. The parent's native baseline
was read to confirm completion before reuse. A fresh implementation-owned X11
baseline was captured before edits. Default replay screenshots are preserved
[before](default-before.png) and [after](default-after.png).

The complete baseline captures remain in
`build/public-creation-baseline/window-evidence`. Candidate captures remain in
`build/public-creation-window-evidence`. Timing-dependent live captures prove
movement through the window gate and are not compared byte-for-byte.

## Independent review

The parent repeated the [proof gate](review-proof.log),
[native gate](review-native.log), [creation renderer](review-creation.log), and
[actual X11 gate](review-window.log). All passed. The full native output and
offscreen image match the baseline exactly. The fresh window run also preserves
all 13 deterministic captures and both logs, as recorded in the
[independent comparison](review-equivalence.log). The comment review found no
added or modified comments requiring changes.

Review found that the isolated headless verifier omitted four new transitive
source files. A [fresh run reproduced the missing seed module](isolated-failure.log).
The explicit source manifest now includes creation, matrix, mesh validation,
and example seeds. The [corrected isolated run](isolated.log) rebuilt and ran
the headless example, eight-tick scene, and all nine batching partitions without
graphics dependencies or device access. Its [file manifest](isolated-files.txt)
records the isolated inputs. Historical headless evidence was preserved.

Review also removed the duplicate example seed implementation. The existing
seed-content and seed-count laws now cover the generator used by startup.
An unused camera conversion helper was removed. The fresh proof, isolated
runtime, and window runs cover these corrections.

## Reproduce

From the repository root, use the pinned compiler and native toolchain:

```sh
bend PROOF.bend
bend tools/verify.bend
bend tools/verify-creation.bend -o build/verify-creation
env -u DISPLAY -u WAYLAND_DISPLAY ./build/verify-creation +RTS --threads 1 --gpu off
bend examples/public-creation.bend -o build/public-creation
./build/public-creation +RTS --threads 1 --gpu off
bend examples/scene-window-baseline.bend -o build/creation-baseline-consumer
bend tools/verify-headless-isolated.bend
```

Run `./build/verify-window` using the owned rootful Xwayland procedure in the
[README](../../../README.md#verify-the-ecs-window). Preserve the output directory
before another run. Then compare the deterministic captures:

```sh
bend tools/compare-window-evidence.bend -o build/compare-window-evidence
./build/compare-window-evidence build/public-creation-baseline/window-evidence build/public-creation-window-evidence
cmp build/public-creation-baseline/native.log docs/verification/2026-11-03-public-creation/native.log
cmp build/public-creation-baseline/scene-render.ppm build/scene-render.ppm
```

The material driver uses the existing owned-child X11 bridge. That bridge starts
`build/indexed-window`. After the ordinary window gate finishes, preserve its
binary, compile the material executable to that path, and run the material
verifier on an owned display:

```sh
cp build/indexed-window build/public-creation-default-window
bend tools/creation-window-app.bend -o build/indexed-window
bend tools/verify-creation-window.bend -o build/verify-creation-window
DISPLAY=":$window_display_number" ./build/verify-creation-window
cp build/public-creation-default-window build/indexed-window
```

The fixture first used the offscreen camera's positive Y projection and produced
no visible triangles under the window pipeline's existing back-face culling.
The corrected fixture uses negative Y projection, as the normal orbit camera
does. Source indices, pipeline culling, and acceptance thresholds were unchanged.

## Limits

No new GPU dispatch, backend-specific core code, dependency edits, traditional
tests, or performance claims were introduced. Runtime verification ran on the
available Linux Vulkan lane. It does not establish execution on Metal or future
WebGPU, cross-backend float identity, reservation-failure injection, or general
formal bounds for every compiled scene. The first generated geometry reference
remains 7 for demo compatibility. Creation is startup-only, and reset restores
the standard orbit while keeping the configured target and lens. The second
interactive application remains a separate unchecked roadmap task.
