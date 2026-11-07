# Scene hierarchy

The [contract](../../../../docs/scene-hierarchy.md) defines keep-local reparenting,
`parent_global * T * R * S`, full affine globals, inverse-transpose normals,
per-object world AABBs, and atomic rejection before publication. ECS owns mutable
state; globals and world bounds are derived. E5 persistent RenderScene is separate.

Run `verify-workflow --plan native hierarchy textured-window`, then those profiles.
For a focused run use `hierarchy hierarchy-window`. The runner records exact source
and per-stage status; incomplete stages never count as passes.

`tools/hierarchy/runtime.bend` runs actual ECS flat forests, a 128-node chain,
63-node branches, public edits, scheduled motion, reparent/detach, independent
branches, and exact rejection preservation. Foreign namespace, stale generation,
missing slot, self-link, cycle, singular lit ancestry, and non-finite transforms
must fail. Real JSON files establish forward placement references and multipart
anchors. The point/bounds oracle walks local transforms directly, without using
production matrix multiplication. It checks relative error at `1e-4`.

`render.bend` compares eight actual ECS states with independently baked geometry
and tangent-derived normals through the actual offscreen renderer. Compare every
RGBA byte within one UNORM step and D32 value within `2e-6`; require drawn coverage.
`replay.bend` re-executes the captured public commands against the real application
and compares complete handle, local, accepted, global, and bounds bit strings.
`verify-hierarchy.bend` retains runtime traces and executes their replay.

`mutations.bend` runs passing runtime/render baselines, then separately breaks
cycle detection, parent composition, world bounds, publication, JSON parent
expansion, inverse-transpose normals, and static consumer extraction. Require each
named behavioral failure, then a passing restored build. Law controls separately
break composition, cycle detection, bounds derivation, rejection preservation,
and child draw extraction. Static textured seed draws must match the complete
derived draw values of the actual ECS. The mesh application and Creation/OBJ/JSON
consumers use the same public derived extraction path.

The owned Xwayland launcher supports `hierarchy` and includes hierarchy in
`extended`. Keys 1–5 translate/rotate/scale/reparent/detach; R restores exact
pixels. Keys 6–9 attempt invalid changes; the driver waits for the recorded
acknowledgement before checking unchanged pixels. It checks resize/restore/Close,
clean Vulkan validation, zero live objects, and replays the entire state trace.
Inspect retained initial/moved/reset captures and cleanup records.

`benchmark.bend` measures accepted root updates and full offscreen frames with
readback. Final analytic forest state and every RGBA/D32 byte are recorded outside
the timed interval. `measure.bend` alternates five baseline/candidate pairs for
1000 flat nodes, 256 chain nodes, and 1023 branching nodes; identical complete state
and image bytes are mandatory. The source receipt must identify both binaries.

The [hierarchy formal skill](../../verify-hierarchy-formal/SKILL.md) adds direct
production proofs through `hierarchy-formal`, also required by `hierarchy`.
Successful evaluation and the candidate/evaluation pipeline preserve cardinality
for arbitrary lists. Forest and rejection certificates check actual array
operations; certified traversal preserves index order. A certified complete batch
checks both optional writes per row and retains commit administration. Parametric
forward-parent and real schema qualifications establish concrete entry paths.
General construction of those certificates from every supported forest and every
successful ECS read remains open. A pass does not certify all-forest atomicity.

Four symbolic hierarchy claims also require a kernel verdict: successful-result
cardinality, certified forest visits, certified rejections and sequence order.
Root laws, concrete hierarchy entry qualifications and ECS publication remain
frontend proofs. Neither layer proves floating-point accuracy or all-forest
certificate construction. Runtime evidence covers the available
Linux Vulkan lane. No spawn/despawn, keep-world reparenting, subtree bounds,
incremental propagation, persistent RenderScene, or cross-backend claim is made.

The [November 5 final record](../../../../docs/verification/2026-11-05-scene-hierarchy/README.md)
retains the complete `native hierarchy textured-window` receipt, all seven
hierarchy sensitivity cycles, five hierarchy law controls, live captures and
23-command hierarchy replay, and the one validated performance improvement.
