# Headless scene reference

The observed [scene consumer](../examples/scene.bend) runs eight production
ticks over 100 entities. It uses the same authoritative ECS world, registered
systems, numerical step, hierarchy propagation, and detached drawing extraction
as the interactive scene.

The [CPU batching verifier](../tools/verify-headless-scene.bend) checks all nine
splits of eight ticks. Zero-step advances preserve the complete retained
application state, clocks, Inspector cursor, entity identities, and detached
drawing. Actual tick-start observations provide the recurrence oracle.

## Numerical and identity checks

Each selected entity's canonical Transform passes through
[Step.step](../src/scene-step.bend) exactly once per tick. The reference compares
every transform float bit with an independently retained tick-start value and
checks the closed-form result for the supported 100 seeds and eight ticks.
Mesh IDs, full namespace/index/generation handles, rotations, and scales must
remain correct. Query order does not determine identity correspondence.

These checks do not assert determinism for arbitrary floating-point inputs,
iteration counts, or execution backends. The reference ordinal is distinct
from the world's change clock.

## Structural publication

The current [production schedule](../src/scene-runtime.bend) is bootstrap,
barrier, movement, barrier. The first barrier publishes deferred spawns before
movement; tick one must therefore move all 100 seeds.

The reference derives actual system IDs from their registration owners and
barrier positions from the retained schedule. It requires these ordered
observations: Ran bootstrap, Applied, Ran movement, Applied. The printed
sync=1 identifies the bootstrap barrier's zero-based plan position. It is not
the removed executor's generated synchronization ID.

At first entry the world and reservation-handle list are empty and seeds are
unexhausted. After every successful tick, seeds are exhausted, pending commands
are empty, and the 100 unique reservation handles equal admissions, canonical
live handles, and component-row handles. Later ticks retain those identities.
The historical receipt labels in the consumer now refer to the current API's
successful reservation handles; it no longer fabricates removed bundle receipts.

This observes completed publication and numerical results. It does not capture
an intermediate world at the first barrier or establish nontrivial final
structural work in this scene.

## Failure behavior and proof scope

Bootstrap stages a transaction and rolls back that transaction on reservation
failure. Ordinary movement retains performed effects on returned body errors.
The current static scheduler continues remaining steps and explicit barriers
after failure, then returns the first error. Entangle rejects Stopped or Invalid
and does not retry the returned application. Invocation is not idempotent.

The root scene_sync_boundary_pair law now states the exact production
bootstrap/barrier/movement/barrier plan. The movement laws describe declared
canonical reads and setters, and the bootstrap laws preserve actual seed
ownership and no-op behavior after exhaustion. They are local adapter laws,
not proofs of every dependency operation.

The [migration record](verification/2026-11-09-ecs-migration/README.md) links
current source-bound checks and their limitations. The
[original reference record](verification/2026-11-03-headless/README.md) retains
historical evidence for the previous dependency revision. CPU-only verification
does not establish rendering, window input, or GPU performance.
