# Verify the Bend laws

Run from the repository root with the versions and dependencies in
`toolchain.bend`. Read `AGENTS.md` and run `bend guide` first.

```bash
bend PROOF.bend
bend proofs/upload-range/PROOF.bend --verdict
bend tools/verify-law-mutations.bend -o build/verify-law-mutations
./build/verify-law-mutations +RTS --threads 1 --gpu off
```

Require exit zero and `ALL PROOFS CHECK` from both proof commands. The root
command is a frontend proof check. Only the standalone upload command above
runs the BendTT kernel. Do not describe the root result as a kernel verdict.

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

## Coverage and assumptions

The authoritative claims are [root LAWS.bend](../../../../LAWS.bend) and
[upload LAWS.bend](../../../../proofs/upload-range/LAWS.bend). Proofs import
production definitions directly. There is no separate transition model.

| Check | Covered production code | Scope |
| --- | --- | --- |
| Root component and scene laws | `src/components.bend`, `scene.bend`, `scene-step.bend`, `scene-motion.bend`, `scene-spawn.bend`, `scene-schema.bend`, `scene-draw.bend`, `scene-observe.bend`, `headless.bend`, `tools/component-consumer.bend`, `examples/scene-seeds.bend` | Field reconstruction, update/query behavior, ordered extraction, bootstrap, seeds, and batch recursion. Imported Bendvy definitions are pinned by `toolchain.bend`. |
| Root content, creation, and rendering laws | `src/content.bend`, `creation.bend`, `scene-matrix.bend`, `measurement-counters.bend`, `scene-geometry-policy.bend` | Source equality reflexivity, universal white identity, tint position, ordered baking and count, validation error priority, duplicate reuse, ranges, index validation, bit layouts, matrix multiplication order, F32 dot-product grouping, quaternion/TRS expressions, counter independence, and pure geometry-selection policy. |
| Root time, input, and player laws | `src/time.bend`, `input.bend`, `mesh-control.bend` | Fixed-step accounting and bounds, high-water clock samples, input draining, camera reset, movement intent, and query refusal. |
| Root upload laws | `src/upload-size.bend`, `deps/bend-vulkan/src/core.bend` | Byte-list length, exact conversion under its stated premise, and the universal range theorem. |
| Root asset laws | `src/asset.bend` | Request hit/miss, terminal states, key preservation, eviction, released lookup/load, scope rejection, and monotonic allocation counter preservation. |
| Standalone upload kernel verdict | `proofs/upload-range/*.bend`, `deps/bend-vulkan/src/core.bend`, imported bend-collections arithmetic | All three U64 inputs, all limb bit patterns, and unbounded natural arithmetic. No offset or no-overflow premise. |

Count root claims with `rg -c '^law ' LAWS.bend`. Quantifiers and premises in
`LAWS.bend` define their bounds. Abstract callbacks are quantified, not evidence of foreign
execution. Floating-point bit-layout and reconstruction claims do not prove
general floating-point accuracy. Native effects, handle decoding, runtime
code generation, and GPU execution are outside these proofs. The standalone
kernel also trusts Bend's translation into its kernel language.

Pure geometry selection does not establish native resource retirement or
descriptor retention. Follow [native resource failures](resource-failures.md),
[mesh replacement](mesh-replacement.md), and the separate
[native failure skill](../../verify-native-failures/SKILL.md) for those checks.
The feature recipes establish runtime behavior separately.

## Synchronization

Both checks were compared with root commit
`71c16701a0bba33e9635624dfc916acfb87d9344` on November 4, 2026, with the
dependency commits in `toolchain.bend`. Their outcome is **in sync**.
No pre-Asset property or bound changed in that audit. The Asset API addition,
based at `49a6adf`, adds 16 root claims and three mutation controls. Its root
proof and seven-control mutation run pass in
`build/verification/asset-api-VAx7I8tG`; the unchanged standalone upload checks
pass in the same mutation run. This does not change the standalone kernel theorem.

The source-format extraction moves existing claims to `src/content.bend` and
adds eight root claims for equality reflexivity, baking, error priority, and
duplicate reuse. Root proofs and real native execution pass. The
[format verification record](../../../../docs/verification/2026-11-04-content-format/README.md)
records these checks separately from the earlier mutation and kernel runs.

Before this record existed, the audit used the last verification-file commits:
`ea6743da89c0eaf134287dee4e3b0832ce41a6d8` for root laws and
`8a93ddde63474da13779174e8a6542bb1ae228cc` for standalone upload proofs.
The only later engine change was the diagnostic timing boundary in
`b9ca65622018613de994014cd38354529a3e879e`. It changes no term described by
these laws. The upload theorem and its production dependency are unchanged.

When maintaining this record, inspect diffs and commit messages from the sync
commit, including dependencies and new writers of guarded state. Rerun the
commands above after checking the correspondence. Advance the sync commit
only for checks that run successfully. Record blocked checks separately.

The local S44 JSON loading change adds eight root laws and two law mutation
controls. The [JSON verification record](../../../../docs/verification/2026-11-04-json-scene/README.md)
retains their source-specific frontend and sensitivity evidence. It does not
advance the earlier synchronization commit or add a kernel verdict for JSON.
