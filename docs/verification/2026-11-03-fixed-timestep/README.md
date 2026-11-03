# Fixed-timestep verification

Verified locally on November 3, 2026. Dependency pins are unchanged.

The [policy and design comparison](../../fixed-timestep.md) describe the
accumulator, positive configuration, four-step cap, whole-step dropping,
fractional carry, clock regression, startup, replay, and input assignment.
[decisions.tsv](decisions.tsv) records the implementation choices retrospectively.

## Results

- [proof.log](proof.log) records `bend PROOF.bend` reporting `ALL PROOFS CHECK`.
  The general claims cover positive configuration, initialization, exact
  executed-step selection, bounded batches, remainder bounds, whole-step
  accounting, and clock high-water state. Existing dependency pins are unchanged.
- [native.log](native.log) records the complete pinned native/offscreen gate.
  It includes 768826 executable scheduling-property combinations, eight actual
  scene ticks, both indexed-render orders, retained drawing, and zero-object cleanup.
  [time-properties.log](time-properties.log) repeats the property sweep with an
  additional saturation check that positive drops require a full batch.
- The optional whole-repository `bend PROOF.bend --verdict` exited with status one.
  [proof-verdict.log](proof-verdict.log) reports BendTT translation limitations
  for runtime-dependent template arguments in pinned Bendvy and scene declarations.
  This does not establish kernel acceptance of the whole repository.
- [time-verdict.log](time-verdict.log) records `ALL PROOFS CHECK` and status zero
  for the timing claims and proof bodies extracted unchanged from the final
  `LAWS.bend` and `PROOF.bend`. This checks the isolated timing slice with BendTT,
  including exact executed-step selection, while avoiding the scene declarations.
- [window.log](window.log) records the actual X11/Vulkan gate on an owned rootful
  Xwayland. Khronos and synchronization validation were enabled after
  [discovery](discovery.log). Live movement, hidden ticks and Close, six camera
  controls, repeated resizing, unmap/restore, Escape, rejected-input recovery,
  and terminal scope cleanup passed.
- [window-live.log](window-live.log) contains `fixed-batch steps=4 dropped=2
  remainder-ms=160` after the actual process was stopped for 1600 ms. The verifier
  audits every executed world tick against its batch and rejects batches above
  four. Shutdown reports zero live Vulkan objects.
- [replay-equivalence.log](replay-equivalence.log) records byte-identical results
  for all 13 retained camera, resize, and restore captures, plus replay and terminal
  logs, against `build/step-after/window-evidence`. The current captures remain
  under `build/window-evidence`. [window-replay.log](window-replay.log) keeps
  world tick two and retained drawing tick one. [window-terminal.log](window-terminal.log)
  records intentional terminal cleanup.
- [live.jsonl](live.jsonl) completes 292 presentations and eight eligible steady
  simulation steps. [replay.jsonl](replay.jsonl) completes 151 presentations and
  zero steady simulation steps. Both report zero live objects after cleanup.
  Their corresponding `.stderr` files are empty.
- [live-stall.jsonl](live-stall.jsonl) exercises measured catch-up on a genuine
  steady frame. Attempt 45 executes four steps and drops two. World tick changes
  from two to six. Simulation, observation, and extraction each have one aggregated
  span. Rendering still records 100 indexed draws and one submission. The run
  completes 151 presentations and eight eligible steady steps with zero live
  objects. [live-stall.stderr](live-stall.stderr) is empty.
- After removing unused initialization timestamp arguments,
  [final-window.log](final-window.log),
  [final-replay-equivalence.log](final-replay-equivalence.log), and
  [final-collectors.log](final-collectors.log) record repeated window, exact replay,
  and live/replay collector passes on the rebuilt final executables.
  Final raw collector streams remain under `build/fixed-timestep`.

The collector's `fixed_steps` excludes forced startup and replay-initialization
ticks. `steady_actual_ticks` includes executed steps only on eligible steady
presentations. The recorded baseline artifacts from before this feature remain
untouched. These runs validate correctness and diagnostics. They make no
performance or cross-platform bitwise numerical determinism claim.

## Independent verification

The parent reviewed the clock, both loop consumers, diagnostics, laws, and runtime
audits. No correctness issues remained. A separate scoped comment review found
no added or modified comments or suppressions and requested no changes.

[parent-proof.log](parent-proof.log) records a fresh `bend PROOF.bend` pass.
[parent-time-verdict.log](parent-time-verdict.log) records independent BendTT
acceptance of the isolated timing claims. Source hashes matched
[source.sha256](source.sha256).

[parent-native.log](parent-native.log) records a fresh build and successful full
native verification through `bend tools/verify.bend -o build/verify` and
`./build/verify`. It covers the scheduling properties, eight-tick scene, both
offscreen draw orders, retained drawing, and cleanup. Its complete output matches
[native.log](native.log) byte for byte.

The parent repeated the actual live-window gate with Vulkan validation on an
owned rootful Xwayland. [parent-window.log](parent-window.log) records the passing
stall, movement, hidden-tick, and Close checks.
[parent-window-live.log](parent-window-live.log) records four executed steps,
two dropped steps, and 188 ms of fractional carry after the stall. Every world
tick matched its planned batch, and cleanup left zero live Vulkan objects.

## Rerun

Build and run the native gate:

```sh
bend guide
bend PROOF.bend
bend tools/verify.bend -o build/verify
./build/verify
```

The optional kernel check for the timing slice uses a generated file in `build`.
Only import paths and the local law-name prefix change:

```sh
cat > build/fixed-timestep-proof.bend <<'EOF'
import Base
import ../src/time.bend as Time
import ../deps/bend-vulkan/deps/bend-collections/proofs/math/natural/arith.bend as Arithmetic
import ../deps/bend-vulkan/deps/bend-collections/proofs/math/natural/misc.bend as Misc
EOF
sed -n '/^law time_defaults:/,/^law input_close:/p' LAWS.bend | sed '$d' >> build/fixed-timestep-proof.bend
sed -n '/^def Laws.time_defaults()/,/^def Laws.input_close/p' PROOF.bend | sed '$d;s/Laws\.time_/time_/g' >> build/fixed-timestep-proof.bend
bend build/fixed-timestep-proof.bend --verdict
```

Use the owned rootful Xwayland setup in [README](../../../README.md#verify-the-ecs-window).
The implementation run used `Xwayland -displayfd 3 -geometry 1280x1024 -nolisten tcp`,
read the allocated display number, and stopped that server after verification.
With that display active, run:

```sh
bend examples/scene-window-baseline.bend -o build/scene-window-baseline
bend tools/verify-window.bend -o build/verify-window
DISPLAY=":$window_display_number" ./build/verify-window
DISPLAY=":$window_display_number" ENTANGLE_WINDOW_MODE=live ./build/verify-window live validation
DISPLAY=":$window_display_number" ENTANGLE_WINDOW_MODE=replay ./build/verify-window replay validation
DISPLAY=":$window_display_number" ENTANGLE_WINDOW_MODE=terminal ./build/verify-window terminal validation
bend tools/compare-window-evidence.bend -o build/compare-window-evidence
./build/compare-window-evidence build/step-after/window-evidence build/window-evidence
DISPLAY=":$window_display_number" timeout --signal=TERM --kill-after=5s 70s \
  ./build/scene-window-baseline +RTS --threads 1 --gpu off
DISPLAY=":$window_display_number" ENTANGLE_WINDOW_MODE=replay \
  timeout --signal=TERM --kill-after=5s 70s \
  ./build/scene-window-baseline +RTS --threads 1 --gpu off
```

The comparator requires the existing historical capture directory. The window
gate independently checks retained replay on each run if that directory is absent.

For the measured stall run, launch the collector directly in the background,
wait 0.6 seconds, send `kill -STOP` to that process, wait 1.6 seconds, then send
`kill -CONT` and wait for its exit. The exact attempt number and remainder depend
on the real runtime. Require `fixed_steps=4`, positive `dropped_steps`, and a world
tick delta of four in the resulting batch. Do not run `tools/baseline-collect.bend`
to reproduce this record, since that driver writes the historical baseline paths.

## Limits

The runtime property sweep is bounded evidence. Formal bounds and accounting are
general. Whole-repository BendTT acceptance remains unavailable for the template
declarations named above. The stop/resume exercise covers the available Linux native execution
lane, not CUDA or Metal dispatch. Camera replay equality covers this pinned
configuration. Gameplay input is currently `Unit`. Timestamped gameplay-event
queues, variable numerical timestep support, global-transform propagation, and
the complete target frame-phase API remain outside this feature.
