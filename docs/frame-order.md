# Frame order

This is the target E2 contract for an application loop iteration. It defines
ordering, not an implemented phase-registration API. The current demonstration
implements only part of this contract, as described below.

input → fixed simulation → update → apply deferred changes → update global transforms → extraction → rendering → completion handling

## Phase contract

Each phase finishes its CPU-side work before the next phase consumes its output.
GPU submission does not imply GPU completion. An iteration may advance simulation
without producing a drawable frame.

1. **Input.** Collect platform events and prepare application input before any
   simulation or update work. Handle exit before starting another simulation
   step. Input preparation owns event consumption, not the renderer.
2. **Fixed simulation.** Run zero or more due simulation steps with a fixed
   timestep. Steps consume prepared input and update the authoritative application
   state in order. The [fixed-timestep policy](fixed-timestep.md) defines the
   current interval, catch-up limit, dropped time, and input assignment.
3. **Update.** Run once per continuing loop iteration after all due fixed steps,
   including iterations with no fixed step. Apply frame-level application work,
   such as camera updates. Systems may queue structural changes through Bendvy.
4. **Apply deferred changes.** Apply outstanding structural changes from the
   simulation and update work before global transforms or extraction read the
   world. This is the final required boundary, not a prohibition on earlier
   dependency-required Bendvy barriers. The [schedule-visibility contract](schedule-visibility.md)
   defines publication, removal notices, and retention. A removal consumer sees
   published notices when its invocation starts after the relevant barrier.
5. **Update global transforms.** Resolve world-space transforms from the committed
   component and hierarchy state. Finish propagation before extraction, so drawing
   data cannot combine a new local transform with a stale ancestor transform.
6. **Extraction.** Read the resulting world and produce detached drawing data.
   Preserve application ownership and world state. Rendering consumes this data
   rather than querying or mutating ECS. A failed extraction must not publish a
   partial drawing list as a successful result.
7. **Rendering.** Consume the extracted data and the prepared camera to record
   and submit drawing work and request presentation when the target is drawable.
   Keep the required resources alive through all uses. Hidden or unavailable
   targets may skip drawing without undoing simulation work.
8. **Completion handling.** Account for renderer submission and presentation
   outcomes. Reuse or retire resources only after the backend's completion and
   reference-release requirements are satisfied. Submission alone is not success,
   and skipped drawing must not count as completed drawing. Any resulting
   application changes enter a subsequent iteration, not the extracted snapshot.

The order describes logical responsibilities. It does not require eight callbacks,
a new scheduler, or a separate host call for each phase. A renderer may perform
required waits within its rendering call. Completion handling must still respect
the order of submission, completion, reference release, and resource retirement.
It does not imply a global GPU wait on every future frame.

If a phase fails, dependent phases must not consume its partial result as valid.
Cleanup of already-owned resources still runs. This contract does not promise
rollback of world changes, recovery from device loss, or bitwise numerical
determinism.

## Current implementation

The [interactive loop](../examples/scene-window.bend) calls `Win.poll`, then
`Camera.snapshot`, then its fixed-step `update`, and finally `SceneApp.draw`.
Camera input changes the camera once before the batch. The function named
`update` executes scheduled steps; it is not the separate update phase above.

[SceneApp.advance](../examples/scene-window-app.bend) runs `Scene.tick`, validates
the observed world, and extracts a drawing list. Live mode runs zero to four
250 ms steps per poll. The [clock](../src/time.bend) drops excess whole steps,
preserves fractional time, and ignores clock regression until the high-water
sample is exceeded. Every executed step validates and extracts. Rendering uses
the final list and reuses it on zero-step polls.

[Scene.configure](../src/scene.bend) disables automatic deferred barriers, enables
final apply, and inserts an explicit barrier before movement. Bootstrap precedes
movement, so its deferred spawns are visible to movement in the same tick.
[Bendvy's deferred executor](../deps/bendvy/src/ecs/execution-deferred-schedule.bend)
performs final apply on successful schedule completion. These existing barriers
are part of the current scene schedule, not eight application phases.

The [schema](../src/scene-schema.bend) contains `Transform` and `MeshRef`.
There is no hierarchy or global-transform propagation phase.
[Extraction](../src/scene-observe.bend) copies those components into detached
`DrawItem` values. The target global-transform phase therefore remains future work.

The [window renderer](../src/scene-window.bend) currently combines rendering and
completion handling inside `Win.frame`. For an acquired image, it submits drawing,
waits for the render fence, reads diagnostics, resets the fence and command buffer,
presents, waits for presentation, and conditionally retires the target. Fence
completion and release of recorded-command references are distinct boundaries.
The current implementation has one frame in flight.

## Startup, skipped frames, and completion names

- Startup is outside the repeating phase sequence. The
  [Core adapter](../examples/scene-window-modules.bend) creates the scene and runs
  its first tick before ordinary input polling. The executable extracts tick one
  during initialization.
- Replay retains tick-one drawing data, advances the world to tick two during
  initialization, and then draws the retained list without further simulation
  ticks. This is an explicit verification mode, not live-loop timing semantics.
- Hidden and zero-sized windows skip drawing while input polling and due live
  ticks continue. Exit closes the renderer without another tick or draw.
- The [baseline collector](../examples/scene-window-baseline.bend) drains events
  and renders with the initial camera. It measures the shared tick, extraction,
  and renderer paths; it is not an interactive-input reference.
- [Bendvy schedule completion](../deps/bendvy/src/ecs/execution-generalized-root-application.bend)
  performs world lifecycle maintenance before extraction. It is not the final
  renderer-completion phase and must not move after rendering to match its name.
- The executable's `completed` function handles the terminal application result
  after [App's resource scope](../src/app.bend) returns. It is shutdown handling,
  not a per-frame phase.

## Scope and verification

This definition completes only the frame-order item in the
[E2 roadmap](../ROADMAP_updated_v6_EN.md#e2--app-plugins-and-the-game-loop).
The [schedule-visibility contract](schedule-visibility.md) separately defines
structural publication and removal-notice semantics. The
[sequential movement kernel](step-kernel.md) now exposes the per-transform
numerical update. The [fixed-timestep implementation](fixed-timestep.md) adds
bounded scheduling. Headless execution and the second application remain
separate tasks.
The [static module slots](../src/modules.bend) remain startup-only.

The current-path descriptions were checked against the linked source files.
The existing [window verification](window-verification.md) and
[App verification record](verification/2026-11-03-app/README.md) cover the current
demonstration. The [fixed-timestep record](verification/2026-11-03-fixed-timestep/README.md)
covers the clock and real-window catch-up. These checks do not verify the complete
target phase sequence.
