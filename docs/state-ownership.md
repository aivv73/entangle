# Scene state ownership

The retained `Scene.Application()` owns the authoritative component state through
its Bendvy world. Future simulation chunks must be storage owned by that world,
with exclusive access transferred to a numerical task and returned afterward.
They cannot be an independently writable mirror of ECS components.

This contract completes the E2 ownership decision. Entangle has no simulation
chunk implementation or chunk transfer API yet. R0 must establish which storage
operations the pinned Bend toolchain and Bendvy can support.

## Authoritative state and observations

For each live entity and component, one storage owner determines the next
authoritative value. Several systems can update that storage in schedule order.
A single owner does not mean that only one system may ever write a component.

| Representation | Authority |
| --- | --- |
| `Scene.Application()` and its `D.World()` | Retain component storage, allocator, deferred commands, and schedule state. |
| Registered `GeneralWriter` and its execution scope `H` | Authorize an update of the current component in that world. The operation consumes and returns the scope. |
| `C.Transform`, query row views, and `Observe.Snapshot` | Copyable values. They carry no scope or writer and cannot publish themselves. |
| `Draw.DrawList` | Detached rendering input. It has neither entity handles nor a component writer. |
| Future owned simulation chunks | A partition of authoritative storage while tasks hold it. Ordinary ECS access to that partition must be unavailable until ownership returns. |
| Future halos, neighbor snapshots, and render projections | Derived read inputs with a defined observation phase. They do not authorize component replacement. |

`World`, the retained application state, and the schedule wrapper have kind
`Type`. Bend's affine checker prevents reusing the same owner. Component records
have kind `Data`, so copying a transform remains legal and useful.

Affinity alone does not establish this contract. Two separately allocated affine
arrays can contain independently evolving copies of the same components. A
component handle also identifies an entity without granting access to its storage.

## Current write path

[`scene-schema.bend`](../src/scene-schema.bend) registers ordinary `Transform` and
`MeshRef` columns and a `Spatial` column. `Spatial` holds the accepted parent,
source bounds, rollback checkpoint, and derived global matrix/world bounds.
Its payload-to-view projections copy values for observation.
They do not transfer component storage to the reader.

[`scene.bend`](../src/scene.bend) retains the world inside `Scene.Application()`.
`Scene.run` consumes that application and returns its successor with a schedule
report. Bootstrap publishes initial components before the movement system runs.

[`scene-motion.bend`](../src/scene-motion.bend) requests a `WriteRows` capability
for transforms on entities with `MeshRef`. `move_rows` uses the selected handle
and discards the row's copied transform. `GeneralWriter.modify` supplies the
current stored transform to `translate`, which calls `Step.step` and returns the
replacement. Each call returns the scope used by the next row.

Calling `Step.step` on a snapshot calculates a detached value. It does not update
the scene. Production movement has no snapshot-to-world writeback operation.
Later systems must also update through the owner instead of installing values
computed from an earlier observation without an explicit conflict policy.

Numerical writes are immediate. A refused query returns the incoming scope.
A refused write stops movement and retains earlier accepted writes. Structural
commands publish at the schedule's apply boundaries. Ownership transfer must not
silently turn these operations into an atomic batch or add rollback. The explicit
[hierarchy publication contract](scene-hierarchy.md) adds a domain validation
boundary after the schedule: invalid derived spatial state restores the previously
accepted local transforms while retaining schedule administrative progress. Public
transform/parent edits instead validate the complete candidate before any write.
This does not roll back unrelated scheduled state. See the
[headless reference](headless-reference.md) and
[schedule visibility contract](schedule-visibility.md).

[`scene-observe.bend`](../src/scene-observe.bend) consumes and reconstructs the
application around read-only inspection. Spatial extraction captures live handles
once and uses checked ECS access. Snapshots and drawing data may outlive
the observation. Rendering or replaying them cannot restore an older scene.

## Future chunk integration

The selected model keeps ECS as the persistent owner. Chunk layout is an internal
storage choice. A work batch describes computation over that storage and need
not have the same boundaries as a storage chunk.

A future transfer API must represent these conditions in its types and checked
operations before production simulation uses it:

1. The simulation adapter consumes the owner or an exclusive storage capability.
   Partitioning transfers payload ownership. It does not clone canonical fields
   into a second persistent container.
2. Each task receives exclusive access to its assigned partition. Partition
   membership covers the selected entities without overlap. Entity handles retain
   their namespace and generation and do not become unchecked physical indexes.
3. While tasks hold partitions, the remaining coordinator cannot obtain an ECS
   reader or writer for those partitions. A usable world and writable detached
   chunks must never coexist for the same components.
4. Cross-partition reads use a specified read-only representation, such as a
   bounded snapshot from tick start. That representation carries no writeback
   permission. Its phase and copy costs are part of the algorithm's contract.
5. Completion returns each owned partition through the same adapter before
   ordinary ECS access and extraction resume. A refused or cancelled operation
   must account for every partition and define the resulting authoritative state.
6. Structural changes that invalidate partition membership or storage addresses
   wait for ownership to return. Their publication order follows the explicit
   schedule contract. Render extraction observes a completed state boundary.

These are requirements for a future API, not descriptions of a shipped lease or
split operation. The pinned dependency's `chunk-column.Column` is an affine
storage implementation. Its existence does not establish a safe Entangle task
handoff. If exclusive transfer cannot be expressed, simulation remains sequential
through the current ECS writer. Independently allocated chunks may be canonical
storage if the world owns them without retaining writable duplicate columns.

R0 may run a standalone numerical reference from copied initial values. That is
a separate execution for comparison, not a live mirror with a writeback path.
CPU or GPU dispatch changes execution only. The ownership and numerical contract
must remain the same without GPU dispatch.

## Excluded designs and trusted boundary

A permanent ECS store plus a mutable simulation mirror violates this contract,
even if a scheduler runs their writers sequentially or synchronizes them every
frame. The contract also excludes restoring a retained draw list, snapshot, or
neighbor halo as current component state.

Moving persistent authority outside ECS would require a separate design change.
That change must remove writable ECS storage for those fields, expose derived
read projections, and route edits as commands to the simulation owner. A second
store cannot be introduced as an incremental compatibility path.

Trusted provisioning code can construct raw world records and register writers.
The current public Bendvy constructors do not make this repository an opaque
capability sandbox. The contract constrains those callers too. The affine checker
prevents owner reuse, but it does not forbid an engineer from adding a new store.
Future chunk integration therefore needs production-path ownership checks and
must remove any duplicate writer path in the same change.

## Verification and limits

`LAWS.bend` states general claims against the current production adapter:

- `scene_move_view_independent` proves that substituting any optional head-row
  view leaves traversal unchanged for arbitrary remaining rows and scope.
- `scene_move_current_component` proves that traversal passes `Move.translate`
  to the supplied writer for that handle, then continues with the returned scope.
- `scene_move_query_refusal` proves that a refused query returns the incoming
  scope with the query error and does not call the writer.
- `scene_step_adapter` binds that callback to the numerical kernel. Existing
  kernel laws specify its translation, preserved rotation and scale, and output.

`PROOF.bend` checks these claims. They assume the supplied writer's contract and
do not prove every Bendvy storage operation or prevent future duplicate stores.
The native verifier exercises the actual registered writer across eight ticks,
checks every entity's identity and transform, and checks detached render replay.

```sh
bend PROOF.bend
bend tools/verify.bend
```

The [verification record](verification/2026-11-03-state-ownership/README.md)
records the runs and their limits. R0 and R1 still need checks for partition
coverage, unavailable competing writers, ownership return on failure, and
equivalence with the sequential reference. No future chunk implementation is
proved by the current adapter laws.
