# Checked host uploads

Both production renderers use a capacity-bearing engine buffer. Upload length is derived from serialized byte lists. The exact universal range predicate guards the native effect.

Run `bend tools/verify.bend` for source policy, root proofs, real Vulkan upload/readback, and the existing offscreen gate. Run `bend proofs/upload-range/PROOF.bend --verdict` for the standalone universal numeric theorem. Root proof success is distinct from kernel success.

To challenge the source policy, build `tools/verify-upload-boundary.bend` as `build/verify-upload-boundary`, then build and run `tools/verify-upload-mutations.bend`. Require a baseline pass, rejection for every isolated mutation, and a restored pass. Keep the printed `build/verification/upload-mutations-*` directory.

Require the runtime driver's endpoint, empty, crossing, beyond-capacity, maximum-U64, invalid-byte, and unchanged-destination checks, plus zero live Vulkan objects. Its log separately reports actual allocation padding. Exact 16 MiB and limit-plus-one native transfers are not exercised. See [the enforced boundary and limits](../../../../docs/upload-range.md).

A change to this buffer also affects [offscreen rendering](offscreen-rendering.md), both [camera-window entries](camera-window.md), [mesh movement and replay](mesh-movement.md), and [public creation rendering](scene-creation.md). Follow those recipes and report their results separately. A headless pass is not a window pass. Retain diagnostics-on and diagnostics-off evidence when changing upload instrumentation.

Inside the skill's owned-display launch shell, after its doctor passes and before teardown, run the diagnostics driver. It verifies actual window uploads, both startup write spans, an exact two-write and 240-byte count, and zero-object cleanup in each mode. It does not measure or compare performance.

```bash
cd "$entangle_repo"
run build-upload-diagnostics bend tools/verify-upload-diagnostics.bend -o "$entangle_evidence/bin/verify-upload-diagnostics"
sha256sum "$entangle_evidence/bin/verify-upload-diagnostics" >> "$entangle_evidence/binaries.sha256"
cd "$entangle_runtime"
run upload-diagnostics timeout --signal=KILL 120s "$entangle_evidence/bin/verify-upload-diagnostics"
```

This short driver checks upload instrumentation. The feature recipes above separately establish visible presentation, input, and replay behavior.
