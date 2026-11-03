# Schedule visibility

This reference defines structural-change and removal-notice visibility for the
Bendvy schedules used by Entangle. The linked dependency source is authoritative
for the revision pinned in [toolchain.bend](../toolchain.bend).
Older dependency prose does not override it.
The [frame-order contract](frame-order.md) describes the target application loop,
not an existing phase-registration or fixed-timestep API.

## Writes and structural publication

Ordinary component writes return in the world consumed by later systems.
Structural commands remain queued until an apply boundary publishes them.
An ordering edge alone does not publish commands when automatic barriers are
disabled. A reserved entity identity is pending, not live, until successful
materialization. These boundaries are defined by
[invocation state](../deps/bendvy/src/ecs/execution-state.bend),
[deferred execution](../deps/bendvy/src/ecs/execution-deferred-schedule.bend), and
[reservation materialization](../deps/bendvy/src/ecs/execution-reservation-materialization.bend).

An explicit barrier publishes before the next system's condition and body.
With `finalApply` enabled, final publication runs only for `Exec.Finished`.
`Exec.Stopped` and `Exec.Invalid` skip final apply. They retain the returned world,
including earlier writes and earlier publications, and retain unapplied system
IDs. Schedule failure does not roll back work. Commands from an admitted body
that returns an error remain eligible for publication if execution continues.
See `admitted`, `synchronize`, and `finished` in the
[deferred executor](../deps/bendvy/src/ecs/execution-deferred-schedule.bend).

An apply attempt does not guarantee that every command succeeds.
[Generalized publication](../deps/bendvy/src/ecs/execution-generalized-publication.bend)
collects remaining queues even after refused publication.
[Command publication](../deps/bendvy/src/ecs/execution-command-publication.bend)
returns receipts for applied and refused commands. An `App.Finished` report alone
does not establish that receipts contain no refusals or that queues are empty.
The [retained schedule](../deps/bendvy/src/ecs/execution-schedule.bend) stores the
returned state and unapplied IDs separately from its report.

## Removal notices and readers

Command publication appends a `Removed{key}` notice when removal actually
displaces a component. Removing an absent component, a rejected command, and
inserting a replacement produce no removal notice. A successful despawn appends
notices for the components actually removed, followed by `Despawned`.
The sources are
[command publication](../deps/bendvy/src/ecs/execution-command-publication.bend)
and [removed-component traversal](../deps/bendvy/src/ecs/execution-command-removed.bend).

Each system invocation receives a lifecycle snapshot in its
[scope](../deps/bendvy/src/ecs/execution-state.bend).
A consumer sees a queued removal in the same schedule only if its invocation
starts after the publishing barrier. Final apply makes notices available to
subsequent invocations, not to systems that already ran.

The [notice journal](../deps/bendvy/src/ecs/execution-lifecycle-notices.bend)
has `previous` and `current` generations. Each successful completion through the
default [Root runner](../deps/bendvy/src/ecs/execution-generalized-root-application.bend)
rotates the journal after the configured final-apply policy. Rotation drops the
old `previous`, moves `current` to `previous`, and clears `current`.
Stopped and invalid runs do not rotate.

A notice published during successful run N survives completion N. It remains
available during run N+1 and expires at completion N+1. This counts successful
Root completions, not displayed frames or elapsed time. Several successful
schedule runs in one frame rotate several times. Hidden-window ticks still
count. Drawing and read-only extraction do not rotate the journal.

Each registered reader has an independent affine cursor. A read returns the
reader with its updated cursor, so one reader does not consume another reader's
notices. `Retained` starts at the oldest retained notices. `Future` starts after
the notices already present at registration. When unread notices expire, the
next read reports their count in `missed`, including on an `Empty` result.
Readers do not extend journal retention.
The journal's `register`, `starting_generic`, and `read_channel` define these rules.

Notice rows carry sequence, entity identity, and tick. They do not own removed
payloads. Displaced affine payloads return through command receipts.
A removal notice establishes no GPU completion or resource-retirement guarantee.
Renderer completion remains governed by the
[frame-order contract](frame-order.md#phase-contract).

## Current scene and future integration

[Scene.configure](../src/scene.bend) sets automatic barriers to `False`, final
apply to `True`, and an explicit barrier before movement. Bootstrap precedes
movement through a dependency edge. Its queued spawns therefore become live
before movement in the first tick. Movement writes are visible to observation
and extraction after `Scene.tick` returns.

The current schedule contains only
[bootstrap](../src/scene-spawn.bend) and
[movement](../src/scene-motion.bend). It has no removal producer or notice reader.
The current [observer](../src/scene-observe.bend) and
[application loop](../examples/scene-window-app.bend) consume the resulting world
and detached drawing data, not removal notices.

Future phase integration requires publication before any dependent transform
work or extraction, as defined in the frame-order contract. A future removal
consumer requires an invocation after the relevant barrier and before journal
expiration. Multiple simulation schedules per frame must account for each Root
completion when placing consumers. These are integration obligations, not
implemented phase or fixed-timestep support.

This document completes only the schedule-visibility definition in the
[E2 roadmap](../ROADMAP_updated_v6_EN.md#e2--app-plugins-and-the-game-loop).
The claims were traced to source. This documentation change adds no runtime
behavior, removal workload, or formal proof.

## Verification

On November 3, 2026, `bend PROOF.bend` reported `ALL PROOFS CHECK`.
The [proof output](verification/2026-11-03-schedule-visibility/proof.txt)
covers the existing laws, not a formal proof of this entire contract.

Fresh native builds used Bend 2.0.39 and Clang 23.1.4 on Linux x86-64.
Both executables ran with one CPU thread and Bend GPU dispatch disabled.
The [scene output](verification/2026-11-03-schedule-visibility/scene-native.txt)
shows zero entities before the first tick, then 100 translated entities with
stable identities and preserved fields across eight ticks.

The existing upstream
[notice scenario](../deps/bendvy/examples/lifecycle-systems/notice-scenario.bend)
ran through actual command publication and lifecycle readers.
Its [native output](verification/2026-11-03-schedule-visibility/notices-native.txt)
shows the fast reader consuming one output-removal notice at update 0 and the
second at update 1. The dormant reader first reads at update 2 and receives
`empty/missed=2`. At update 3 it receives `empty/missed=0`.
This is runtime evidence for publication, cursor progress, and expiration.
It does not cover every failure policy or a removal consumer in Entangle's scene.

Reproduce these checks from the repository root.

```sh
bend PROOF.bend
bend examples/scene.bend -o /tmp/entangle-schedule-scene.c
clang -std=c11 -O2 /tmp/entangle-schedule-scene.c -lpthread -lm -ldl -o /tmp/entangle-schedule-scene
env -u DISPLAY -u WAYLAND_DISPLAY /tmp/entangle-schedule-scene --threads 1 --gpu off
bend deps/bendvy/examples/lifecycle-systems/notice-scenario.bend -o /tmp/entangle-schedule-notices.c
clang -std=c11 -O2 /tmp/entangle-schedule-notices.c -lpthread -lm -ldl -o /tmp/entangle-schedule-notices
/tmp/entangle-schedule-notices --threads 1 --gpu off
```
