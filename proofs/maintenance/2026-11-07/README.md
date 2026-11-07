# Formal verification maintenance

Drawing and accepted-publication checks are **updated**. The upload theorem
and all eleven bounded native proofs are **in sync**. All required checks
pass across the retained receipts after correcting one expected diagnostic.
No product bug is found, and no product source, dependency, or proof bound
changes.

## Acceptance recorded before verification edits

The audit compares all project-local formal checks with root revision
`94665a580af130b7d13ae1b29228eec14d032ccd`, starting at their recorded sync,
`71c16701a0bba33e9635624dfc916acfb87d9344`.

Acceptance requires a source comparison for every covered function and new
writer of guarded state, an unchanged baseline run, a current-code rerun,
and sensitivity controls that fail the named property on broken production
sources. Each check receives an outcome: in sync, updated, bug, or blocked.
Only successful checks advance their sync revision. Product code is outside
this change.

Required evidence comes from the `proofs native-failures` workflow profiles:
the pinned toolchain, upload source policy, root frontend proofs, real native
resource-failure execution, the standalone upload kernel verdict, Bend law
mutations, and all eleven native proofs with their eighteen mutations and
restored baselines. The dependency generator check additionally confirms
that the window bundle embeds the extracted native implementation.

Correspondence review found two stale paths: draw extraction moved in
`2c3a442`, and accepted geometry publication changed in `dc70d54`. The final
required profiles therefore expand to `proofs native hierarchy`, including
the native skill's full runtime gate and the actual ECS hierarchy consumers.
The new publication check uses complete pure production declarations because
direct imports of their effect modules fail Bend's proof-safety gate.

Covered definitions and limits start in
[`formal-laws.md`](../../../.agents/skills/verify-entangle/features/formal-laws.md)
and the
[`native failure skill`](../../../.agents/skills/verify-native-failures/SKILL.md).
The root laws are frontend expression proofs. The standalone upload theorem
has a BendTT kernel verdict. Native proofs use bounded C assertions with
symbolic driver results, four registry rows, three edges, and one lease.
No window, performance, arbitrary native graph, hardware device-loss, or
other-backend claim is part of this audit.

## Correspondence review

All fifteen intervening commit messages and the covered-code diffs were read.
The native, ECS, and arithmetic dependency revisions did not change. Neither
the upload theorem nor the native extraction, claims, mutations, or bounds
changed. The retained `history.txt`, `covered-code.patch`, `laws.patch`, and
`proof.patch` record the comparison before this maintenance patch.

| Commit | Effect on verification |
| --- | --- |
| `49a6adf` | Adds the existing production-law mutation driver and sync record. No production change. |
| `513e5e4` | Adds the Asset cache, sixteen lifecycle laws, and three controls. The laws use current cache definitions directly. |
| `181d82b` | Moves source types, tinting, equality, and index validation into `content.bend`. Claims and proofs already follow that move. Adds baking, error-priority, identity, and duplicate-reuse claims. |
| `57f8623` | Adds PNG storage, array flattening, padding, read rejection, and decoder-error equations. The reusable array-tree witness matches the production constructors. It does not model inflate or decoding. |
| `90c7b7e` | Decoder qualification documentation. No covered-code change. |
| `cf00582` | Adds OBJ admission, emission, run, index, and read claims. Successful decode validity is connected through production `admit_result`; failures satisfy the validity predicate vacuously. |
| `5bf93cf` | Registers the existing decoder imports with source policy. No formal transition or promise changes. |
| `a016c6b` | Importer verification documentation. No covered-code change. |
| `d012aa4` | Adds the retained verification workflow. No covered production definition changes. |
| `ac805c7` | Adds strict JSON boundaries and scene loading with eight laws. Current proofs cover those selected boundaries and admission, not the whole parser or loader. |
| `36b5729` | Adds matrix-expression contracts and three controls. The production matrix definitions remain unchanged. |
| `dc70d54` | Adds UVs, normals, textured ranges, and deferred material ownership. Content and range laws already follow their new shapes. Accepted publication moves to `published`, leaving its old positive selection law disconnected. |
| `2c3a442` | Adds spatial state, hierarchy propagation, edits, globals, bounds, and child drawing. Spawn/schema laws already follow the new layout. Both draw-list entry points move to `Hierarchy.draw_list`; the older draw laws remain on inspector helpers. |
| `75750f3` | Changes hosting and a submodule URL. Pinned dependency bytes and formal behavior remain unchanged. |
| `94665a5` | Clone documentation only. No covered-code change. |

New writers and callers were checked as part of that comparison: Asset
request/completion/release, Creation seed derivation, hierarchy canonical
transform/spatial writes, scene and playground propagation and public edits,
JSON parent-anchor expansion, geometry preparation and publication, material
retirement/collection, texture upload/release, and both renderer consumers.
The new native callers do not change the extracted C implementation.

## Verification repairs

These changes repair correspondence and extend the existing promises. They
do not relax a failing property.

| Claims | Old description | Current description and evidence |
| --- | --- | --- |
| `draw_payload`, `draw_handle_independent` | `Observe.draw_item` constructs a flat item without using the entity handle. That helper no longer supplies either application's drawing. | `Hierarchy.drawing` uses the live transform for a root and the stored global for a child, independently of handle identity. `draw_child_payload` covers the second branch. `2c3a442` explicitly preserves flat scenes and adds parented global transforms. |
| `draw_found_order`, `draw_absent_strict`, `draw_finish_order` | Generic inspector helpers specialized to draw items. | The actual `mesh_read` and `read_rows` retain checked rows, reject missing mesh data, and reverse the accumulator. Inspector snapshot behavior remains covered separately by `row_found_order`, `row_absent_strict`, `row_finish_order`, and the existing `row_missing_strict`. The internal error becomes `MissingEntity`; `draw_failure_strict` preserves public `Fail{Unit{}}`. |
| `draw_rows_order`, `draw_rows_count`, `draw_success_rows`, `draw_failure_strict` | No corresponding claim along the new extraction path. | Actual hierarchy rows become one ordered draw item each; read failures stay failures and both result branches retain the world. The checks describe existing code added by `2c3a442`. |
| `geometry_install_accept` | For arbitrary `A`, `Policy.select(A,old,fresh,True{}) == fresh`. The success path no longer calls this branch. | The source-extracted `published` definition retains candidate geometry and active bindings, previous material ownership, the previous retirement queue, and candidate pending retirement. `dc70d54` promises deferred texture cleanup. The new law describes that expanded resident value. |
| `material_ownership_cons` | No claim connecting a binding to the retirement lists. | Extracted `ownership` includes the complete owned list for each binding in order. This closes the pure publication claim's dependency on that helper. |

The root check now has 192 laws. Accepted publication moves to a separate
two-law frontend harness with complete production type declarations. Only
imports change during extraction. No transition implementation is replaced,
and native handles retain their actual `U32` layouts. The direct-import
attempt failed Bend's foreign-effect proof-safety gate. That setup failure
was corrected by extraction, not by disabling the gate.

No list or native bound is reduced. Existing texture-era laws already changed
the mesh admission examples from 699,048/699,051 to 381,300/381,303, following
the intentional 381,300-vertex limit in `dc70d54`. Its 44-byte vertices keep
uploads within 16 MiB, as documented in `docs/textured-materials.md`. This
audit leaves those laws and the new UV, normal, texture, and spatial fields
intact.

Five new root mutation rows exercise the repaired drawing path. Three
publication mutations exercise the generated pure declarations. The workflow
now selects publication proofs and their controls whenever it selects laws.
The law mutation receipt also hashes every production file in its manifest.
Coverage records now include PNG, OBJ, JSON, textures, lighting, and the
publication harness. The native claims and dependency pins are unchanged.

The first complete rerun exposes one diagnostic-oracle mismatch: the existing
child-extraction mutation now fails the earlier `draw_child_payload` law,
while its manifest still expects `hierarchy_child_draw`. The defect is caught
correctly. The manifest now requires the new, precise location. This failure
is verification drift, not a product bug or a weakened property. The partial
receipt keeps its failed status and unexecuted stages.

## Results and classification

The unchanged baseline completes all eleven required stages in
`build/verification/workflow-TFY573Fe`. Root frontend proofs, the upload kernel
verdict, all nineteen original Bend controls, all eleven native proofs, all
eighteen native controls, and restored sources pass. Real resource-failure
execution also passes and reports zero live Vulkan objects.

That old root pass was on a stale description of drawing and accepted
publication. A separate disposable copy uses the original laws and proof
terms from `94665a5`. Dropping a draw row in `scene-hierarchy.bend` still gives
`ALL PROOFS CHECK`. Discarding candidate buffers in `scene-geometry.bend` also
gives `ALL PROOFS CHECK`. Both commands exit zero in
`build/verification/stale-controls-4jDHBHxn`. The retained reproduction is
`build/verification/formal-maintenance-2026-11-07/stale-controls.bend`.

The updated root proofs pass. The publication harness passes its baseline,
all three named controls, and restored declarations in
`build/verification/publication-3ZUkRmxu`.

| Check | Outcome | Sensitivity evidence |
| --- | --- | --- |
| Root frontend laws | Updated | Five new controls replace the root transform, drop a checked row, omit row reversal, drop a draw row, and hide a failed read. The existing controls remain required. |
| Publication frontend laws | Updated | Drop candidate buffers or prior material retirement: `geometry_install_accept` fails. Drop a binding's resources: `material_ownership_cons` fails. |
| Standalone upload kernel laws | In sync | Remove the production offset guard: `universal` fails. |
| `verify_device_loss` | In sync | Revive a lost device, retain stale submission storage, or invalidate another owner's command. |
| `verify_record_reset_failure` | In sync | Drop recorded edges on reset failure or retain usable begin/end phases after failure. |
| `verify_submit_result` | In sync | Treat an unknown submission outcome as executable. |
| `verify_synced_submission` | In sync | Drop staged semaphore edges for an uncertain submission. |
| `verify_uncertain_guards` | In sync | Permit uncertain reset or another submission on the same device. |
| `verify_lost_guards` | In sync | Return success from the lost-device command-reset guard. |
| `verify_descriptor_failure` | In sync | Omit quarantine after native cleanup failure or bypass its later free guard. |
| `verify_fence_reset_failure` | In sync | Swallow the fence-reset error. |
| `verify_idle_failure` | In sync | Swallow unresolved completion failure during entry cleanup. |
| `verify_completion` | In sync | Release recorded ownership during completion. |
| `verify_idle_success` | In sync | Skip completion after successful idle. |

The two correspondence gaps are **verification drift**, introduced by
`dc70d54` and `2c3a442`. No product bug or reachable product counterexample
has been found. Expected source-mutation failures are sensitivity evidence,
not defects in the unchanged product. The foreign-effect rejection is a
verification setup failure. No old passing description turns into a failing
current implementation after the repairs.

## Final evidence

The final `proofs upload native-failures` receipt is
[`build/verification/workflow-9pNy2v1l/manifest.tsv`](../../../build/verification/workflow-9pNy2v1l/manifest.tsv).
Its state is `complete`, `run.status` is zero, and all nineteen required stage
statuses are zero. This includes 192 root frontend laws, two publication
laws, two upload kernel laws, eleven native proof entries, and restored
baselines. All 45 formal sensitivity controls pass their expected checks:
24 Bend controls, three publication controls, and eighteen native controls.
Eleven separate upload source-policy controls also pass.

The earlier `proofs native hierarchy` receipt remains
[`failed`](../../../build/verification/workflow-3nLJc2nw/manifest.tsv), with
`run.status` one and its later unexecuted stages left `not_run`. Its native
and hierarchy stage statuses are both zero. Those completed stages retain
the unchanged runtime evidence; the corrected proof receipt reruns the
remaining proof and sensitivity requirements. No skipped stage is counted
as a pass. Only the mutation's expected diagnostic changes executable
verification between those runs. Product sources, laws, bounds, and runtime
drivers are unchanged.

The command plans and outer logs are in
`build/verification/formal-maintenance-2026-11-07`. The separate dependency
generator check exits zero. Final nested evidence under the successful
receipt's `source/build/verification` includes
`law-mutations-WTyfowOn`, `publication-J1rfa7Wn`,
`upload-mutations-Q43majih`, and `native-formal-eBspsHJx`.

The hierarchy stage passes real ECS state and JSON anchor checks,
deterministic replay of seventeen commands with complete identity and
transform/bounds bits, and full RGBA/D32 comparison against independent baked
geometry. All seven production controls and all seven restored baselines
pass their expected checks. The renderer reports zero live Vulkan objects.

The full native gate also passes assets, PNG, OBJ, JSON, textured materials,
all seven texture controls and restored baselines, the eleven positive native
handler proofs, real uploads and byte-for-byte readbacks, component and scene
examples, mesh replacement/retention, allocation-pressure rollback/retry,
and terminal cleanup. Rendering and resource drivers report zero live Vulkan
objects. The retained native and hierarchy stdout/stderr contain no
`Validation Error`, `SYNC-HAZARD`, or `VUID-` diagnostics.

The laws and harnesses match the completed runtime snapshot byte for byte.
The law-mutation manifest then changes one expected diagnostic from
`hierarchy_child_draw` to `draw_child_payload`. No production source, law,
bound, or runtime driver changes. The remaining proof and sensitivity stages
rerun through `proofs upload native-failures`, with a new retained receipt.
The earlier receipt remains failed; its completed native and hierarchy
stages supply the unchanged runtime evidence. Historical receipts remain
attached to their original sources.

## Coverage limits

Root and publication checks are frontend proofs. Only standalone upload has
a BendTT kernel verdict. PNG decoding/inflate, complete OBJ fidelity and
acceptance, the JSON parser/loader/parent-anchor expansion, shader execution,
general numerical accuracy, complete hierarchy graph invariants, and native
cleanup remain outside these universal claims. Existing runtime drivers
provide separate observed evidence; passing admission laws alone can be
vacuous when all inputs are rejected.

The publication harness proves pure fields and list retention after the
successful-retirement boundary. It does not prove Vulkan destruction or the
call from `sealed`; the audit reads that branch and both consumer paths.

Native bounds remain four scanned registry rows, three edges, one lease,
symbolic payloads and all 32-bit driver result patterns, with success excluded
only in failure-only entries. Unwind assertions retain the global bound six
and the tighter completion/idle bounds. Arbitrary graphs, concurrency, query
and presentation semantics, full multi-device entry teardown, handle
decoding, allocation success, driver behavior, and hardware device-loss
recovery are not proved. New texture resource lists can exceed that topology.
No live-window, other-backend, Bend GPU-dispatch, or performance result is claimed
by this maintenance run.

Task state: complete. Correspondence, positive proofs, sensitivity controls,
restored baselines, applicable runtime consumers, and sync records are
current. No check is blocked. Product sources are unchanged.
