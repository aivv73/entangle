# Schedule visibility

Entangle uses the current Bendvy component, transaction, registered-system, and
static-schedule APIs pinned in [toolchain.bend](../toolchain.bend). The
[ECS migration record](verification/2026-11-09-ecs-migration/README.md) records
the migration from the removed execution-composer API.

## Production order

[scene-runtime.bend](../src/scene-runtime.bend) builds this explicit plan from
the actual bootstrap and movement registration IDs:

1. Run bootstrap.
2. Apply a structural barrier.
3. Run movement.
4. Apply a final structural barrier.

Bendvy's [schedule](../deps/bendvy/src/ecs/schedule.bend) validates that plan
against the supplied ID catalog and rejects repeated system IDs. At execution
it checks the schedule's world namespace. Each dispatched
[system](../deps/bendvy/src/ecs/system.bend) also checks its runtime namespace
and registration metadata before invoking its closed runner. The returned
schedule retains the same affine registration owners.

## Deferred creation

[Bootstrap](../src/scene-spawn.bend) threads a real
[transaction](../deps/bendvy/src/ecs/transaction.bend) through
[commands.tx_spawn](../deps/bendvy/src/ecs/commands.bend). Reservation returns a
complete namespace/index/generation handle immediately. It stages activation and
schema population for the barrier; reserved entities are not yet live or readable.

On successful bootstrap completion, transaction finish queues those commands
in authored order. The first barrier activates the entities and installs
Transform, MeshRef, and Spatial through their
[schema-bound component families](../src/scene-schema.bend).
Movement therefore sees the new entities on tick one. Successful bootstrap
retains its reservation handles and clears its seeds. Subsequent invocations
keep those handles and stage no additional spawns.

Bootstrap reservation failure rolls back its staged transaction. Allocator
progress is not rewound. The low-level deferred population callback is trusted
schema setup; its payload ownership and capacity assumptions are those of the
pinned command and component APIs.

## Component writes and observations

[Movement](../src/scene-motion.bend) registers an ordinary query declaring
write Transform and requiring MeshRef. Its body receives opaque capabilities,
reads the current canonical component, then writes the replacement through its
declared setter. The automatic scene applies the existing numerical step;
the mesh controller selects only its retained full player handle.

Queries and ordinary systems retain performed effects after returned body
errors under the pinned ordinary-system contract. Registered admission and
completed execution are different outcomes; completed execution consumes its
lifecycle cursor even on error.

[Passive extraction](../src/scene-observe.bend) uses canonical read-only
Inspector grants. It preserves the world clock and caller's Inspector cursor.
Detached observations and drawing lists own no component writeback authority.
Hierarchy propagation runs after the schedule and restores accepted spatial
checkpoints if newly derived state is rejected.

## Failure and evidence

The static schedule continues its remaining steps after a system failure,
including explicit barriers, then returns the first error with the retained
world and owners. This differs from the removed executor's early-stop path.
Entangle maps it to Stopped; namespace refusal maps to Invalid.
The application tick exits on either result and does not retry returned state.

A successful scene reports exactly Ran bootstrap, Applied, Ran movement,
Applied. Applied records an executed barrier, not a command count or a
per-system publication receipt. The observed reference checks the actual
plan's barrier positions, empty pending work, exhausted seeds, reservation
identities, canonical live/component identities, and exact transform results.
The root schedule law describes the production plan; it does not prove the
entire scheduler or external effects.

The fork also supplies events, removal readers, and other facilities, but
Entangle's scene adapter does not claim to implement their former execution
journal or automatic retention policies. Use the pinned upstream documentation
when introducing those capabilities.
