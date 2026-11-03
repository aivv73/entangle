# Checked host uploads

Both production renderers use a capacity-bearing engine buffer. Upload length is derived from serialized byte lists. The exact universal range predicate guards the native effect.

Run `bend tools/verify.bend` for source policy, root proofs, real Vulkan upload/readback, and the existing offscreen gate. Run `bend proofs/upload-range/PROOF.bend --verdict` for the standalone universal numeric theorem. Root proof success is distinct from kernel success.

To challenge the source policy, build `tools/verify-upload-boundary.bend` as `build/verify-upload-boundary`, then build and run `tools/verify-upload-mutations.bend`. Require a baseline pass, rejection for every isolated mutation, and a restored pass. Keep the printed `build/verification/upload-mutations-*` directory.

Require both mandatory upload drivers to pass. The production driver covers empty reads and writes at zero and capacity, zero allocation and empty creation failures, maximum offsets and counts, invalid bytes after a valid prefix, unchanged destinations, allocation padding, and immediate cleanup. Both drivers check 140 scalar native ABI inputs and compare each returned limb. The standalone separately checks flattened high-limb buffer creation without a large allocation.

Each driver writes and reads exactly 16777216 bytes at offset one inside a capacity of 16777218 bytes. Require every byte, exact list exhaustion, and both guards to match. Both rejected `L+1` payloads invert every byte, so a partial write is observable. Distinguish the production writer's engine rejection from the standalone's direct native writer rejection. Both exercise native `L+1` read rejection. Require complete unchanged readback and zero final live objects. Errors must match exact codes and messages. The flattened ABI probe requires distinct fields `[257,1,2]` and a returned size high limb of exactly one on the available device. See [the boundary and coverage limits](../../../../docs/upload-range.md) and [the ABI evidence](../../../../docs/verification/2026-11-03-upload-abi/README.md).

Focused reruns use the pinned native toolchain and the same 300000 ms deadline as the default gate.

```bash
bend tools/verify-upload-runtime.bend -o build/verify-upload-runtime
VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation VK_LAYER_VALIDATE_SYNC=1 timeout --signal=KILL 300s ./build/verify-upload-runtime +RTS --threads 1 --gpu off
bend tools/verify-upload-native-limit.bend -o build/verify-upload-native-limit
VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation VK_LAYER_VALIDATE_SYNC=1 timeout --signal=KILL 300s ./build/verify-upload-native-limit +RTS --threads 1 --gpu off
```

The native verifier's complete source hash is mandatory. It accepts no caller-owned device, buffer, or allocation and returns no resource. Never approve raw writer symbols in the dependency manifest. The mutation driver must reject a changed native verifier as well as the original bypass cases, then pass after restoration. Scalar roundtrips can hide paired conversion errors and do not cover every Vulkan structure. Resource replacement and broader lifetime remain open.

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
