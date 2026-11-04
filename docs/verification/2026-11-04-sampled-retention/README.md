# Sampled-image retaining references

Tracked by [trail 21](https://entire.com/et/bend-engine/-/trails/21).

The [sampled retention helper](../../../tools/verify-sampled-retention.bend)
extends the real Vulkan checks in `tools/verify-mesh-replacement.bend`.
The default `tools/verify.bend` gate runs it alongside the existing uniform
buffer and bound-memory checks. This work is based on root `5ef97bb` with
the unchanged dependency revisions in `toolchain.bend`.

## Ownership checked

The helper allocates real RGBA8 images, bound memory, image views, samplers,
two descriptor sets, and two slots per set. It uses the production image
allocator and the existing retention driver's pipeline and rejection checks.

- Rebinding a set preserves the earlier recorded set. Recording and
  executable unsubmitted commands freeze their sets.
- Two real submissions keep both sets frozen until their recorded owners
  release them. Updates, set free, pool reset, and pool destruction reject
  with the native lifetime code.
- Waiting for one submission and resetting its command permits rewriting
  its independent set. The other set stays frozen and retains its original
  resources. Device idle preserves the second command's recorded references.
- Destroying the completed command pool releases commands, while the sets
  still reject destruction of their views and samplers. Views retain images,
  and image bindings retain memory.
- Partial array rewrites retain untouched slots. Rewriting an entire set
  leaves the independent set's ownership intact. The last old slot alone
  still blocks resource destruction.
- Final overwrite releases the old descriptor references. Freeing one set
  leaves the other set's resources intact; freeing the final set permits
  explicit destruction. Pool reset and pool destruction each exercise a
  separate release path. Allocation after reset also checks pool reuse.
- Resource destruction removes exactly one registry object per step.
  Memory free still rejects after view destruction while the image exists.
  After cleanup, all four resource handles reject lookup or destruction
  with the native invalid-handle code. Pool cleanup also invalidates sets.

Every rejection and release stage checks the expected live-object count.
The helper restores its entry count before returning; the enclosing entry
scope must finish with zero live Vulkan objects.

## Reproduce

Use the [offscreen verification recipe](../../../.agents/skills/verify-entangle/features/mesh-replacement.md#offscreen-and-retained-command-verification)
for an isolated focused run. No display is needed. For the complete gate
and the existing negative controls, run sequentially from the repository root:

```bash
python3 deps/bend-vulkan/tools/generate.py --check
bend tools/verify.bend -o build/verify
env -u DISPLAY -u WAYLAND_DISPLAY -u VK_LAYER_ENABLES \
  VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation VK_LAYER_VALIDATE_SYNC=1 \
  ./build/verify +RTS --threads 1 --gpu off
./build/verify-native-failures --mutations +RTS --threads 1 --gpu off
bend tools/verify-upload-mutations.bend -o build/verify-upload-mutations
./build/verify-upload-mutations +RTS --threads 1 --gpu off
```

The complete gate includes `bend PROOF.bend`. Require all four
`Sampled descriptors:` lines and
`Mesh replacement offscreen and native retention verified; live Vulkan objects: 0`.
Native logs must contain no validation errors, sync hazards, or VUID diagnostics.

## Results

The complete run exited with status `0`. Local evidence is retained in
`build/verification/sampled-retention-iGhvQNpc`. Its `native-gate.log`
records the final implementation, including all four sampled-descriptor
results, exact existing renderer readbacks, and zero-object shutdown.
The final replacement executable is `bin/replacement-final`.
`replacement.log` and `bin/replacement` retain the earlier focused run.

- Root proofs report `ALL PROOFS CHECK`.
- The full native gate passes with Vulkan validation and synchronization
  validation enabled. Native logs contain no validation errors, sync
  hazards, VUID diagnostics, or warnings.
- All 11 bounded native failure proof entries pass. All 18 source mutations
  produce their expected counterexamples; all 11 original entries pass again.
- All 11 upload-policy mutations reject; baseline and restored copies pass.
- Native/window bundle consistency passes. Dependency checkouts stay clean.
- The four replacement captures match between the focused and final runs.
  Their inspected pixels show the red square, green square, green triangle,
  and empty blue frame.

The default gate's formal evidence is
`build/verification/native-formal-8mWfp7oS`. Mutation and restored-proof
evidence is `build/verification/native-formal-4XWIrjSm`; upload-policy
evidence is `build/verification/upload-mutations-5jOnENlY`.
The main evidence directory retains commands, stage statuses, source and
binary hashes, compiler/dependency versions, logs, and original captures.
Source, binary, and capture manifests match their retained artifacts.

## Limits

These submitted commands bind sampled descriptors without drawing or sampling
texels. They check native retaining references, not texture output, filtering,
image-layout transitions, or texture upload. Images and samplers use explicit
destruction; the buffer retirement API is unchanged.

No production renderer, native implementation, dependency pin, or execution
parallelism changed. The upload inventory adds only the reviewed sampled
descriptor types, constants, sampler creation, and image/view/sampler cleanup.
It does not grant raw upload access. Existing upload mutations check that
boundary separately; native failure mutations exercise the existing bounded
handler proofs, not sampled-image ownership mutations.

Formal laws and proofs are unchanged because this adds real-runtime coverage
of foreign ownership behavior, with no new pure policy. Existing proofs do
not establish a general sampled-resource lifetime theorem. X11 was not rerun
for this verification-only change. Other backends and performance remain
outside the result.
