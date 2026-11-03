# Sequential movement step

`src/scene-step.bend` exposes the numerical transition used by the existing
movement system. Consumers can call it without an ECS world, window, or clock.

```bend
import Base
import ../src/components.bend as C
import ../src/scene-step.bend as Step

def move_once(transform:C.Transform) -> C.Transform & Unit:
	Step.step(Unit{},transform)
```

## Inputs, state, and events

The signature is `step(input:Unit, state:C.Transform) -> C.Transform & Unit`.

| Value | Contract |
| --- | --- |
| `input` | `Unit{}` requests one numerical update of one transform. There are no movement controls or duration fields. |
| `state` | The complete current transform, including translation, rotation, and scale. |
| First result | The replacement transform. Translation evaluates `F32.add(x,1.0)`, `F32.add(y,0.5)`, and `F32.sub(z,2.0)`. Rotation and scale pass through unchanged. |
| Second result | `Unit{}` means no gameplay events. It is not an ECS write receipt or a presentation result. |

One kernel call is a per-transform update, not a whole scene tick. Calling it
twice advances twice. There is no deduplication, rollback, or retry policy.
The kernel preserves the existing F32 operations, including their behavior for
nonfinite inputs. It adds no normalization or finite-value checks.

## State ownership and execution

The ECS application remains the persistent owner of scene transforms.
The [state ownership contract](state-ownership.md) defines the current write
boundary and the required exclusive transfer for future simulation chunks.
`scene-motion.translate` receives the current component through the registered
writer, calls `Step.step`, and returns its result to that writer. The existing
`move_rows` recursion processes selected entities sequentially. It does not
collect a second writable list of transforms or dispatch parallel work.

`Scene.run` remains the pure whole-scene operation. It consumes the retained
application and returns the updated application and Bendvy report. The
application includes world storage, bootstrap state, system owners, and schedule
state. Detached drawing data is an observation, not an authoritative store.

Bootstrap still publishes before movement. Successful schedule completion still
performs final apply. `Finished`, `Stopped`, and `Invalid` reports, including
ordered invocation observations, remain separate from the kernel's empty
gameplay-event output. `Scene.tick` still checks for exactly two successful,
distinct system invocations in IO.

The [headless reference](headless-reference.md) checks actual tick entry,
production apply boundaries, receipt identities, and per-handle numerical
recurrence. Its example-local observed runner retains the same completion path.
Final apply has empty structural work here; the explicit bootstrap sync publishes
before movement. Numerical writes are immediate, and failures retain earlier
writes and publication without rollback or retry.

Query and write refusals stay in the ECS adapter. A refused write stops traversal;
earlier writes are not rolled back. The extraction leaves those branches
unchanged. The numerical kernel itself has no failure variant.

The host owns polling, camera input, scheduling, clock reads, logging, and
rendering. The [fixed-timestep policy](fixed-timestep.md) now schedules zero to
four 250 ms scene steps per live poll. It drops excess whole steps and retains
fractional time. This kernel extraction itself adds no timing policy or full
headless scene API.

## Design decision

Three independent sketches compared the numerical boundary with a whole-scene
wrapper and a detached batch reducer. The selected third candidate keeps one
`step` operation with Unit input and output. The independent cross-review agreed.
The first candidate supplied the more specific `scene-step.bend` filename.
The second supplied the distinction between historical evidence and active
callers. Historical verification snapshots remain unchanged.

A whole-scene wrapper would duplicate the existing pure `Scene.run` boundary.
A batch reducer would require collecting and writing back components and could
change partial-failure behavior. Neither is needed to expose the numerical rule.
The explicit empty input and output preserve today's contract without inventing
events, controls, or a second state owner.

## Verification

`LAWS.bend` states the general numerical and field-preservation claims against
the production kernel, including its empty event output. An adapter equality law
binds the ECS callback to that kernel. `PROOF.bend` provides their proofs. Run from
the repository root:

```sh
bend PROOF.bend
bend tools/verify.bend
```

The native verifier checks eight scene ticks, all 100 entity identities and
transforms, bootstrap exhaustion, ordered drawing data, exact offscreen color
and depth, retained replay, and Vulkan cleanup. The separate
[window verifier](window-verification.md) covers live movement, hidden ticks,
camera controls, resizing, exit, and retained replay.

These runtime checks cover successful movement. They do not inject refused
component writes or prove cross-backend bitwise determinism. The kernel laws do
not prove the native runtime, driver, or complete schedule.

The [extraction evidence](verification/2026-11-03-step/README.md) records the
before-and-after runs and deterministic replay comparison.
