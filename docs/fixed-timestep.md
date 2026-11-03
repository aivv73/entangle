# Fixed timestep

The native scene advances in 250 ms simulation steps. Each continuing live poll
executes at most four steps, including while the window is hidden. Rendering runs
once after the batch and consumes its final drawing list. Each executed step keeps
the existing sequential movement, observation, validation, and extraction.

## Clock contract

[Time](../src/time.bend) owns the pure scheduling policy.
`Config{interval_tail,limit_tail}` represents the positive interval and capacity
as each field plus one. `defaults()` returns `Config{249n,3n}`. A caller selects
configuration in source and keeps it fixed for the lifetime of a clock.
`Clock{sample,remainder}` stores the high-water timestamp and fractional carry,
both in integer milliseconds. `start(now)` starts with zero carry.
`poll(config,clock,now)` returns `Batch{clock,steps,dropped}`.

For previous sample `s`, previous remainder `r`, and interval `dt`, a poll adds
`max(now - s, 0)` to `r`. It divides that accumulated time into whole steps and a
fraction. It executes `min(whole,limit)` steps, drops the remaining whole steps,
and preserves the fraction. The next sample is `max(s,now)`.

The accounting identity is:

```text
old_remainder + elapsed = (steps + dropped) * dt + new_remainder
0 <= steps <= limit
0 <= new_remainder < dt
```

At 1375 ms after a zero-carry start, the default policy executes four steps,
drops one, and retains 125 ms. Another 125 ms makes one step due. Dropped steps
never mutate the world or advance its executed-tick counter. This bounds work
per poll, not the duration of a step. A stalled application intentionally loses
simulation time rather than keeping unbounded debt.

Clock regression adds no elapsed time and leaves the high-water sample unchanged.
Recovery counts only time beyond that sample. A permanent clock reset requires
an explicit new clock. Repeated samples schedule no further work after a batch.
Changing how time is partitioned between polls can change drops under overload.

## Startup, replay, and input

Startup creates the world and executes tick one before polling. The clock starts
after that tick, before startup observation and extraction. Startup preparation
after the sample therefore contributes to the first live batch.
Replay retains tick-one drawing, explicitly executes tick two, then bypasses the
clock and further simulation. Replay drawing remains frozen while camera input
and window handling continue. Terminal verification also bypasses live scheduling.

The interactive loop polls and consumes events once before planning a batch.
Close or Escape exits before another simulation step. Camera keys update the view
once per poll, including polls with zero steps. Catch-up never repeats key events.
The simulation kernel currently receives `Unit` on every executed step and has no
gameplay input queue. Dropped steps receive no input. Timestamped gameplay-event
assignment remains future work.

The numerical kernel has fixed per-step displacement. The clock controls its
invocation frequency and does not rescale displacement when configuration changes.
Fixed scheduling does not promise bitwise numerical determinism across hardware,
compiler settings, execution lanes, or numerical algorithms. Existing exact
retained-drawing and pixel checks cover their recorded configuration only.

## Design choice

Two independent read-only sketches compared these shapes before synthesis.

| Shape | Stored state | Tradeoff |
|---|---|---|
| Accumulator, selected | High-water timestamp and fractional carry | Direct elapsed-time accounting and fewer arithmetic invariants. |
| Deadline grid | High-water timestamp and next deadline | Preserves grid phase, but needs separate before-deadline and overdue branches and a deadline-range invariant. |

The sketches agreed on whole-step dropping and preserving the fraction. One
preferred the grid because it resembles the old callers. The selected accumulator
replaces the old resetting deadline and states its accounting directly.
The shared `SceneApp.schedule` installs the resulting clock exactly once.
`advance` performs one world step without reading or resetting time.
The batch executor consumes a structurally decreasing `Nat` sequentially.

## Diagnostics and verification

The baseline uses the same planner. Each attempt records `fixed_steps` and
`dropped_steps`. Its `simulation`, `observation`, and `extraction` spans sum all
executed steps in that attempt. An unavailable constituent makes the sum
unavailable. Zero-step attempts retain unavailable scheduling reasons.
Renderer counters and presentations remain per render.
`steady_actual_ticks` counts executed steps on eligible steady presentations,
independently of timing availability. Startup and `replay_initial_*` spans remain
separate. Previously recorded baseline artifacts remain historical measurements.

[LAWS.bend](../LAWS.bend) states general positivity, initialization, batch-bound,
fractional-remainder, high-water, and conservation claims.
[PROOF.bend](../PROOF.bend) proves them using the pinned dependency's natural
arithmetic proofs. [The runtime property verifier](../tools/verify-time.bend)
checks accounting, bounds, duplicate samples, and regression over 768826
configuration and clock combinations. This is bounded executable evidence in
addition to the general formal claims.

[The native window verifier](../tools/verify-window.bend) pauses the actual scene
process for 1600 ms and resumes it. Its log audit requires a four-step batch with
positive drops and checks every world increment against the batch count.
It also drives live movement, hidden ticks, camera replay, resize, and cleanup.
See [the verification record](verification/2026-11-03-fixed-timestep/README.md).
