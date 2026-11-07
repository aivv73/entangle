# Native resource failures

Acquisition leases, WSI fences, presentation semaphore reuse, and resize/Close
use [verify-presentation](../../verify-presentation/SKILL.md). That separate
bounded proof and live-window profile are required before multiple frames in
flight or asynchronous presentation.

`tools/verify-resource-failures.bend` drives the unchanged production buffer and geometry helpers against the pinned native Vulkan registry. `tools/verify.bend` runs it after mesh replacement. This path needs Linux `/proc`, `prlimit`, the pinned toolchain, a Vulkan device, and the validation layer. It needs no display.

Run the standalone driver from the repository root:

```bash
set -euo pipefail
mkdir -p build/verification
failure_evidence=$(mktemp -d "$PWD/build/verification/resource-failures-XXXXXXXX")
bend tools/verify-resource-failures.bend -o "$failure_evidence/failures" \
  > "$failure_evidence/build.log" 2>&1
sha256sum "$failure_evidence/failures" > "$failure_evidence/binary.sha256"
env -u DISPLAY -u WAYLAND_DISPLAY -u VK_LAYER_ENABLES \
  VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation VK_LAYER_VALIDATE_SYNC=1 \
  timeout 120s "$failure_evidence/failures" +RTS --threads 1 --gpu off \
  > "$failure_evidence/native.log" 2>&1
printf '0\n' > "$failure_evidence/run.status"
printf 'Evidence: %s\n' "$failure_evidence"
```

Require the final `Native resource failure verification passed; live Vulkan objects: 0` line and no `Validation Error`, `SYNC-HAZARD`, or `VUID-` diagnostics. Require every result below:

- `failure-recording`: a real GPU fill remains recorded after an invalid fill, repeated begin/end, and premature submission reject. A signaled fence rejects submission; resetting the fence permits submission of the same command. Exact readback must be `[68,51,34,17]`.
- `failure-pending`: command reset, fence reset/destruction, pool destruction, resubmission, and host read reject before completion observation. Exact live counts remain unchanged. Completion preserves recorded references; successful reset and collection release the allocation. Reusing the command and fence succeeds.
- `failure-rollback`: an invalid index byte fails after a successful vertex upload. All four combinations of retained vertex/index candidates are exercised. The original error, each cleanup error, successful-write counters, live counts, and collected handles must match. Both disposals run even when the first rejects. Reset permits final cleanup.
- `failure-allocation`: the first candidate allocation succeeds before a process-local address-space cap is applied. A valid serialized mesh then reaches the production index-allocation stage. Require a genuine `vkAllocateMemory: VkResult -1` or `-2`, immediate rollback, a stale first-candidate handle, unchanged old allocation identities/ranges/bytes, and the returned diagnostic owner. A guard rejection or unexpected allocation success fails verification.
- `failure-terminal`: leave both candidates retained when rollback rejects and return the error through the real entry scope. Teardown must release every native object while preserving the initiating error and both cleanup diagnostics.

`process-address-limit.bend` reads its own PID and `VmSize` from `/proc/self/status`. It saves the soft `RLIMIT_AS`, restricts it to the measured size plus 4096 KiB, and leaves the hard limit unchanged. It refuses to raise an existing soft limit. It restores and reads back the old limit before interpreting the allocation result. The cap applies only to this disposable verifier process. The payload is 72 vertex bytes and 8388600 index bytes, below the production transport limit. A successful allocation/upload after restoration verifies that the device remains usable.

The allocation mechanism is lane-specific verification, outside engine algorithms. A driver that handles memory pressure differently may fail this gate; such a run does not establish allocation-failure coverage. Preserve its logs. Process exit releases the cap even if the verifier terminates before restoration.

These checks preserve native dispatch and introduce no mocks, injected Vulkan results, or alternative allocators. The partial-upload checks enter the production upload stage with invalid bytes; ordinary geometry serialization does not produce those bytes. Allocation verification pauses between the two existing preparation stages to apply the process limit. It does not add a production fault hook.

Uncertain submission, device loss, Vulkan begin/end/reset failures, and descriptor free/reset driver errors are covered separately by [formal verification of production handlers and lifetime](../../verify-native-failures/SKILL.md). Its lifetime suite also checks paired retirement, retained allocated-resource graphs and destruction guards, reference staging, collection, and two-command completion/reset. Run its positive proofs and source mutations when these paths change. The default native gate includes both positive suites; the workflow adds their mutations. Pure material cleanup-queue decisions are covered by the publication harness.

Those rare errors remain unobserved as real hardware events in this driver. Native destroy/free calls for buffers and memory return no Vulkan status; their observed cleanup failures are registry lifetime rejections. The [runtime record](../../../../docs/verification/2026-11-03-native-failures/README.md) distinguishes these results from native driver failures. Formal coverage has explicit bounds and does not prove all native behavior, other backends, or performance.
