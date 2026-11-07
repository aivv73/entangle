# Verify the Bend laws

Run from the repository root with the versions and dependencies in
`toolchain.bend`. Read `AGENTS.md` and run `bend guide` first.

```bash
bend PROOF.bend
bend proofs/upload-range/PROOF.bend --verdict
bend tools/verify-law-mutations.bend -o build/verify-law-mutations
./build/verify-law-mutations +RTS --threads 1 --gpu off
bend tools/verify-publication.bend -o build/verify-publication
./build/verify-publication --mutations +RTS --threads 1 --gpu off
```

Require exit zero and `ALL PROOFS CHECK` from both proof commands. The root
command is a frontend proof check. Only the standalone upload command above
runs the BendTT kernel. Do not describe the root result as a kernel verdict.
The publication driver checks freshly extracted pure production declarations.
Require its baseline, three named mutation rejections, and restored pass.
The `proofs` workflow profile includes all these commands and preserves a
source-specific receipt. Pair it with `native hierarchy` after changes to the
draw-extraction or publication correspondence.

The mutation driver copies production sources and dependencies into a fresh
`build/verification/law-mutations-*` directory. It checks unchanged sources,
changes one production definition at a time, restores each definition, and
checks the restored sources. It preserves laws and proofs throughout.
Require every mutation in `proofs/law-mutations.tsv` to exit one, print `SOME PROOFS FAIL`, and identify
the expected `Location: Laws.<name>`. A parser error or timeout is not a
successful negative control. The driver records source hashes, changed
definitions, logs, and statuses. Retain the printed evidence directory.

The controls replace the rejected geometry with its candidate, let a clock
sample regress, drop upload bytes, and remove the upload offset guard. They
exercise `geometry_install_reject`, `time_high_water`,
`upload_transport_length`, and the standalone `universal` law. They do not
claim mutation coverage of every root law. Asset controls retain a released
entry, overwrite a cached failure, and reuse an allocation identity. They must
fail `asset_release_entry`, `asset_failed_stable`, and `asset_request_miss`.
Math controls exchange matrix columns, regroup F32 additions, and reverse a
quaternion cross-term sign. They must fail `render_multiply_order`,
`render_apply_order`, and `render_model_contract`. The [S41 record](../../../../docs/verification/2026-11-05-jonmath/README.md)
keeps candidate-adapter qualification and native scene evidence separate from
these frontend expression proofs.

Five extraction controls now replace the live root transform, drop a checked
mesh row, omit the final row reversal, drop a draw row, and turn a read failure
into an empty successful drawing. They must fail `draw_payload`,
`draw_found_order`, `draw_finish_order`, `draw_rows_order`, and
`draw_failure_strict`. These controls exercise `src/scene-hierarchy.bend`,
which both application draw-list paths now use. The old inspector helpers
still serve snapshots and have separate `row_*` laws.
The existing child-extraction control now fails `draw_child_payload` before
the lower-level `hierarchy_child_draw` law. Keep its expected diagnostic
bound to that current entry-path claim.

Accepted geometry publication moved from `Geometry.select(...,True{})` to
`src/scene-geometry.bend:published`. Its law now lives in the
[publication harness](../../../../proofs/geometry-publication/README.md).
That harness copies complete production types and pure definitions, including
material retirement and native handle layouts. It changes only imports.
The `.bend.in` claim and proof templates become `LAWS.bend` and `PROOF.bend`
inside each fresh evidence directory. Directly importing the effect modules
would fail Bend's foreign-effect proof-safety gate. Keep that gate enabled.

## Coverage and assumptions

The authoritative claims are [root LAWS.bend](../../../../LAWS.bend),
[upload LAWS.bend](../../../../proofs/upload-range/LAWS.bend), and the
[publication law template](../../../../proofs/geometry-publication/LAWS.bend.in).
Root and upload proofs import production definitions directly. Publication
copies the named production declarations. There is no separate transition model.

| Check | Covered production code | Scope |
| --- | --- | --- |
| Root component and scene laws | `src/components.bend`, `scene.bend`, `scene-step.bend`, `scene-motion.bend`, `scene-spawn.bend`, `scene-schema.bend`, `scene-draw.bend`, `scene-observe.bend`, `scene-hierarchy.bend`, `headless.bend`, `tools/component-consumer.bend`, `examples/scene-seeds.bend` | Field reconstruction, update/query behavior, actual draw-row acquisition and extraction, root and child payloads, order, count, failure propagation, separate inspector snapshot laws, bootstrap, seeds, and batch recursion. Imported Bendvy definitions are pinned by `toolchain.bend`. |
| Root content, creation, and rendering laws | `src/content.bend`, `creation.bend`, `scene-matrix.bend`, `measurement-counters.bend`, `scene-geometry-policy.bend` | Source equality reflexivity, universal white identity, tint position, ordered baking and count, validation error priority, duplicate reuse, ranges, index validation, bit layouts, matrix multiplication order, F32 dot-product grouping, quaternion/TRS expressions, counter independence, and pure geometry-selection policy. |
| Root time, input, and player laws | `src/time.bend`, `input.bend`, `mesh-control.bend` | Fixed-step accounting and bounds, high-water clock samples, input draining, camera reset, movement intent, and query refusal. |
| Root upload laws | `src/upload-size.bend`, `deps/bend-vulkan/src/core.bend` | Byte-list length, exact conversion under its stated premise, and the universal range theorem. |
| Root asset laws | `src/asset.bend` | Request hit/miss, terminal states, key preservation, eviction, released lookup/load, scope rejection, and monotonic allocation counter preservation. |
| Root PNG laws | `src/image-png.bend`, `src/content.bend`, `proofs/image-array.bend`, `deps/jonlib-png/codec.bend` | Array flattening order, tail and length equations, positive dimensions and exact storage, one padding equation, incomplete-read rejection, and decoder error mapping. The reusable tree witness describes array shape. This is not a proof of PNG decoding or inflate. |
| Root OBJ laws | `src/model-obj.bend`, `src/content.bend`, `deps/jonlib-obj/obj.bend` | Part validity, triangle and index emission, run boundaries and coalescing, selected parser/index behavior under stated premises, incomplete reads, and successful-result validity through decode. Rejected results satisfy validity vacuously. Source fidelity and successful parsing need real-input checks. |
| Root JSON laws | `src/json-boundary.bend`, `src/scene-file.bend`, pinned JSON and bytes packages | Rejected guards, oversized input, incomplete reads, wrong-kind and missing references, model-part preservation, admitted-scene compilability, and depth eight. They do not prove the parser, the complete loader, or parent-anchor expansion. |
| Root texture and lighting laws | `src/content.bend`, `src/render-format.bend`, `src/lighting.bend` | The 44-byte vertex stride, RGBA byte order, source-image retention, zero-width rejection, and invalid light-direction rejection. Shader behavior and normal-matrix accuracy require separate evidence. |
| Root hierarchy laws | `src/hierarchy.bend`, `scene-hierarchy.bend`, `scene-draw.bend` | Root and parent matrix expressions, root/child extraction, empty/derived bounds, visiting/missing/invalid rejection, and unchanged world after rejected public edits. Five source mutations bind these claims to production behavior. Numerical and graph coverage additionally use the real ECS/render/replay drivers. |
| Accepted publication frontend proofs | `src/scene-geometry.bend:published`, `src/scene-materials.bend:ownership,retire`, their complete type closure | Candidate buffers, ranges, and active bindings are published. Prior ownership and both retirement queues are preserved in order. The binding ownership step retains the complete resource list. Three production mutations establish sensitivity. Inspect `sealed` and its callers at every sync. No finite list bound is imposed. |
| Standalone upload kernel verdict | `proofs/upload-range/*.bend`, `deps/bend-vulkan/src/core.bend`, imported bend-collections arithmetic | All three U64 inputs, all limb bit patterns, and unbounded natural arithmetic. No offset or no-overflow premise. |

Count root claims with `rg -c '^law ' LAWS.bend`. Quantifiers and premises in
`LAWS.bend` define their bounds. Abstract callbacks are quantified, not evidence of foreign
execution. Floating-point bit-layout and reconstruction claims do not prove
general floating-point accuracy. Native effects, handle decoding, runtime
code generation, and GPU execution are outside these proofs. The standalone
kernel also trusts Bend's translation into its kernel language.

Pure geometry selection does not establish native resource retirement or
descriptor retention. The publication proof establishes pure list retention,
not successful native retirement or cleanup. Hierarchy branch equations do
not prove the complete ECS access layer or every parent forest. Follow
[native resource failures](resource-failures.md),
[mesh replacement](mesh-replacement.md), and the separate
[native failure skill](../../verify-native-failures/SKILL.md) for those checks.
The feature recipes establish runtime behavior separately.

## Synchronization

| Check | Outcome | Checked production revision |
| --- | --- | --- |
| Root frontend proofs, 192 laws | Updated: actual hierarchy draw path and separate inspector snapshots | `94665a580af130b7d13ae1b29228eec14d032ccd` |
| Accepted publication, two frontend laws | Updated: source-extracted publication and material retirement | `94665a580af130b7d13ae1b29228eec14d032ccd` |
| Standalone upload, two kernel laws | In sync: theorem and imported production definitions unchanged | `94665a580af130b7d13ae1b29228eec14d032ccd` |

The November 7, 2026 audit reads every commit in `71c1670..94665a5`, including
the Asset, content extraction, PNG, OBJ, JSON, math, texture, hierarchy, and
hosting changes. Dependency revisions remain those in `toolchain.bend`.
The [maintenance record](../../../../proofs/maintenance/2026-11-07/README.md)
lists each commit, correspondence change, control, and retained receipt.

The old 185-law root check passed on a stale description of drawing and
accepted publication. The repaired laws check the current functions. The
snapshot helpers remain covered under `row_*`; the unused positive
`Geometry.select` law is replaced by the publication harness. Public root
draws still use local transforms, while parented draws use globals, as
specified by `2c3a442`. Publication retains deferred materials as specified
by `dc70d54`. No promise is weakened and no bound is reduced in this audit.

Earlier feature commits had already updated the content, vertex, range,
spawn, and schema claims. In particular, `dc70d54` intentionally changed the
admitted vertex count from 699,050 to 381,300 for the 44-byte vertex format
within the 16 MiB upload limit. Its limit laws already reflect that change.
The current audit does not alter those claims.

The [November 4 record](../../../../docs/verification/2026-11-04-formal-maintenance/README.md)
retains the previous synchronization and its fallback verification-file
commits. Historical receipts describe their original sources.

When maintaining this record, inspect diffs and commit messages from the sync
commit, including dependencies and new writers of guarded state. Rerun the
commands above after checking the correspondence. Advance the sync commit
only for checks that run successfully. Record blocked checks separately.
