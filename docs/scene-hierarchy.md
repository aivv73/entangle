# Scene hierarchy

Implementation task: [Trail 31](https://entire.com/et/bend-engine/-/trails/31).
The semantics and acceptance below were recorded before implementation.

## Semantics and ownership

Each scene instance has one optional parent, identified by its zero-based source
instance index. Forward references are allowed. Roots have no parent. The graph
must be a forest. Self-parenting, cycles, and missing parents are errors.
Runtime edits use full Bendvy entity handles, including namespace and generation.
An absent parent detaches the object. Reparenting preserves the local transform.
It may change the object's world position. There is no preserve-world operation.
Runtime spawn and despawn remain outside this API.

Local transforms use column vectors and `T * R * S`. A root's GlobalTransform is
its local model matrix. A child's matrix is `parent_global * child_local`.
GlobalTransform retains the complete affine matrix, including shear. It is never
decomposed back into rotation and scale. World bounds enclose the eight transformed
corners of the source mesh AABB over all source vertices, including unused ones.
They bound that object's geometry, not its subtree. A mesh without vertices has
empty bounds. Lighting uses the inverse transpose of the
world linear transform. A singular transform is allowed for unlit geometry;
textured geometry requires a finite, numerically usable inverse: absolute
determinant at least `1e-30`, finite inverse entries, and inverse-column squared
lengths in `[1e-24,1e24]`. These are numerical admission limits, not a condition
number guarantee. Non-finite transformed corners reject the candidate. Quaternion
squared lengths retain the Creation tolerance `[0.9999,1.0001]`.
Textured roots also retain the flat renderer's local scale-magnitude limits
`[1e-6,1e6]`. Detachment validates those limits before publication.

Source bounds and the material's lighting requirement come from compilation.
They describe that scene's source geometry. Renderer-only geometry replacement
does not rebind ECS source metadata: recreate the scene from matching compiled
sources when changing its meshes or materials. Runtime mesh/material rebinding
and using these bounds for culling are outside this API.

Creation descriptions are immutable inputs. The ECS owns local transforms,
parent relationships, source bounds, and derived state. A completed tick or
accepted public edit publishes a consistent set of local transforms, globals,
and bounds. GlobalTransform and world bounds have no public setter. Detached
observations and render lists cannot write back to the world. A last-accepted
local value retained with derived state is a rollback checkpoint, not a second
simulation authority.

The baseline recomputes the complete forest sequentially at each publication
boundary. Validation and derivation finish before public edits write components.
A rejected public edit preserves the complete world. If a scheduled transform
update makes derivation invalid, local transforms return to their last accepted
values and existing derived values remain valid. Schedule administrative progress
is retained. The persistent RenderScene and incremental invalidation belong to E5.

## Description and runtime API sketch

`Creation.parent(instance, Some{index})` assigns a parent in a scene description.
`None{}` makes a root. Existing `Instance{mesh,material,transform}` remains a root.
Compilation validates relationships and derived numerical state before bootstrap.

`Scene.set_parent(app, entity, parent)` and `Scene.set_transform(app, entity, local)`
return the owned application beside an acceptance result. Invalid or stale
handles, invalid transforms, and invalid derived state return a diagnostic.
The same operations are available for the mesh application.

Version 1 JSON retains existing flat scenes. An optional `parent` is a zero-based
placement index or null. The placement transform is applied once at its first
part, which serves as the parent anchor; remaining parts attach to the anchor
with identity local transforms. This expansion is used only for scenes
with parent links, so old flat instance order and transform behavior remain intact.
Parent references address placements before model expansion. Empty models are
rejected in scenes containing parent links. Unknown fields and invalid references
remain errors.

Inheritance affects spatial state, not which entities a system chooses to move.
The existing demonstration's scheduled motion still edits every local transform.
To move an entire placement rigidly, edit its anchor; a system that separately
edits descendant locals adds their own motion to the inherited parent motion.

## Acceptance and required evidence

The production path is description → Creation/JSON validation → ECS columns →
sequential derivation → detached draws → shared offscreen/window draw recording.
The hierarchy evaluator, ECS publication adapter, normal payload, and renderer
preflight enforce the contract.

Required evidence includes:

- Formal claims in `LAWS.bend` against production definitions for composition,
  rejection, publication, and bounds derivation. Numerical properties additionally
  run in native Bend with explicit tolerance and independently calculated geometry.
- Actual ECS executions covering deep chains, branches, forward references,
  movement, rotation, nonuniform scale/shear, reparenting, detachment, independent
  branches, and exact preservation after invalid edits.
- Real Vulkan RGBA/D32 readbacks against an independently transformed mesh,
  including surface-normal lighting. Owned X11 execution and deterministic replay
  compare complete local/global/bounds state, not just a digest.
- Existing flat-scene, JSON, textured rendering, mesh, and window consumers.
- Passing baseline → deliberate production regression rejected at the named
  property → restored passing baseline. A build failure is not detection evidence.
- A source-specific `verify-workflow` receipt with every required stage complete.

## Performance evaluation plan

Measure sequential publication cost and its share of real rendering workloads
for flat, deep, and branching scenes. Count accepted updates and validate final
state/output. Use five interleaved runs per comparison and report median/range.
Inspect the machine load and use a separate profiling run to identify the limiter.
Consider improvement only if propagation exceeds 2 ms per 1000-node update or
adds over 10% to a representative frame. Set a concrete target before trying a
change. Allow at most three single-change attempts, retain only repeatable gains
with identical state/render output, and validate a winner on additional scenes.
Otherwise retain the straightforward implementation. No parallelism is planned.
