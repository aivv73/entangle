# Upload ABI and transport-boundary verification

This record closes the scoped S39 ABI, boundary, and negative verification item. Resource replacement and broader resource lifetime remain open.

The implementation is based on `57d1f4c04e2642d37a45dae31d59625c25e47f74` on `verify/upload-abi-limits`. Production sources, laws, proofs, dependency pins, and native effects are unchanged. [Reviewed source hashes](review/sources.sha256) identify the final verification implementation and the original production capsules. [Initial source hashes](sources.sha256) retain the implementation before the review corrections below. [Toolchain provenance](provenance.log) records Bend 2.0.39, Clang 23.1.4, Linux x86_64, and dependency revisions.

## Reproduce the checks

Run from the repository root with the pinned dependencies. Preserve stdout, stderr, and each exit status in a fresh evidence directory.

```bash
bend PROOF.bend
bend tools/verify-upload-boundary.bend -o build/verify-upload-boundary
./build/verify-upload-boundary
bend tools/verify-upload-runtime.bend -o build/verify-upload-runtime
VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation VK_LAYER_VALIDATE_SYNC=1 timeout --signal=KILL 300s ./build/verify-upload-runtime +RTS --threads 1 --gpu off
bend tools/verify-upload-native-limit.bend -o build/verify-upload-native-limit
VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation VK_LAYER_VALIDATE_SYNC=1 timeout --signal=KILL 300s ./build/verify-upload-native-limit +RTS --threads 1 --gpu off
VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation VK_LAYER_VALIDATE_SYNC=1 bend tools/verify.bend
bend tools/verify-upload-mutations.bend -o build/verify-upload-mutations
./build/verify-upload-mutations
```

The default gate compiles and runs both upload drivers with fixed `+RTS --threads 1 --gpu off` arguments. Its per-command deadline remains 300000 ms. The focused final runs also set `VK_LOADER_DEBUG=layer`. Their logs confirm the active validation layer and GTX 1660 device. No `Validation Error`, `SYNC-HAZARD`, or `VUID-` diagnostic was present.

The initial [commands](commands.log), [statuses](statuses.tsv), [proof log](proof.log), [source-policy log](source-boundary.log), [production log](production.log), [native log](native.log), [default gate log](default-gate.log), and [mutation summary](mutations.log) retain the implementation runs before review. Negative mutation statuses are expected rejections, separate from failed build attempts. The [changed native source rejection](trusted-native-change.log) records the initial trust failure. [Initial binary hashes](binaries.sha256) identify those executables. Binaries are retained locally, not copied into this directory.

## Review corrections

Independent source review found two weaknesses in the original verification. Oversized payloads repeated the stored bytes, so a rejected operation could write a prefix without changing observed content. The final payload generator takes a mask. Successful writes use zero, and oversized writes use 255. Every rejected payload byte now differs from the destination.

The original flattened ABI check accepted any requirement at least as large as the request. Swapped size limbs could satisfy that lower bound. The reviewed check also requires high limb exactly one. Transfer-destination usage makes all three flattened inputs distinct. This remains a device-scoped probe, with no universal padding claim.

The coordinator and a separate `gpt-6.1-sol` reviewer agreed on both corrections. The reviewer found no further source blockers. Review used the same model family. The trusted standalone source was reviewed again and its hash refreshed after fresh proof and runtime passes. [Reviewed production](review/production.log) and [reviewed native](review/native.log) logs retain complete readback and cleanup results. [Reviewed binary hashes](review/binaries.sha256) identify those fresh executables.

The final [commands](review/commands.log) and [statuses](review/statuses.tsv) record successful parent reruns of the root proof, both fresh upload builds and executions, the [default gate](review/default-gate.log), and [all eleven source mutations](review/mutations.log). The baseline and restored mutation copies pass. The [changed trusted verifier](review/trusted-native-change.log) rejects. Validation was active in both focused runs, and no validation error appeared in either run or the default gate. The [decision record](review/decisions.tsv) retains the design choice, review corrections, and final gate result. Full parent evidence remains in `build/verification/upload-abi-eRwOfahQ/review`.

## Executed coverage

- Both drivers compare individual returned limbs for 12 scalar boundary pairs, all 64 walking-one values, and all 64 walking-zero values. Inputs include zero, maximum limbs, U64 max, the 2^32 carry, sign bits, reversed asymmetric pairs, and alternating masks.
- Production empty reads and writes succeed at zero and capacity. Zero allocation and empty `upload_new` retain the exact native nonzero-size error. Immediate live counts remain unchanged.
- Production reads and writes reject U32-max, high-only, and U64-max offsets. Read counts include zero, one, and U32 max. Crossing, endpoint, beyond-capacity, byte256, and failed-new-upload checks remain present. A maximum-U32 byte after a valid prefix leaves all seven destination bytes unchanged.
- Each large scenario uses requested capacity `16777218`, guard bytes `193` and `207`, and offset one. Exact `16777216`-byte writes and reads succeed. Production returns the exact count. Every readback byte and exact list exhaustion are checked against an index-derived byte. The oracle constructs no expected list and uses no hash or samples.
- Both rejected `16777217`-byte writes invert every payload byte with XOR 255. A partial write therefore changes observable content. The production write has a valid destination range but fails at the engine transport limit. Its corresponding read reaches the native read-limit rejection. After each rejection, 256 reads of 65536 bytes and both guard reads verify the complete requested destination.
- The standalone directly executes the native `16777217`-byte writer rejection. It requires code `0x60000003` and the exact native invalid-byte/copy-length message. Complete payload and guard readback establish unchanged content. Native read rejection requires code `0x60000005` and the exact read-limit message.
- Native invalid bytes after a valid prefix and U64-max empty/nonempty offsets reject. A U32-max read count takes native limit-error precedence even at U64-max offset. Subsequent complete readback and both guards match. Zero native allocation preserves the immediate live count.
- The real unbound `BufferCreateInfo{W.U64{257,1},TRANSFER_DST}` probe succeeds. Distinct flattened fields `[257,1,2]` make size and usage permutations observable. The check requires size at least the request and high limb exactly one. Actual memory requirements are `W.U64{272,1}`. The buffer is destroyed without a 4 GiB allocation. This bound is an expectation for the available device, not a universal Vulkan padding bound.
- Explicit large-buffer disposal restores live counts before entry teardown. Both drivers finish with zero live Vulkan objects. The default gate also passes the existing native compatibility, scene, timing, and offscreen rendering checks.
- The mutation driver rejects all ten existing bypass cases and a source change to the trusted native verifier. Its baseline and restored source copies pass.

## Trust and limits

The [standalone native verifier](../../../tools/verify-upload-native-limit.bend) is pinned by its complete source hash. Its only resource-bearing definitions are `run(entry) -> V.Action(Unit)` and `main() -> IO(Unit)`. The run owns creation, binding, raw operations, and disposal. No helper accepts or returns a device, buffer, or allocation. An ordinary importer cannot pass engine memory or obtain the verifier's memory. Shared byte and ABI helpers carry no memory capability. Raw writer symbols remain absent from the dependency manifest. Any source change invalidates the trusted hash.

The scalar hook calls the real pinned `bv_u64` decoder and `bv_words` tuple encoder. Reviewed native source decodes `(uint64_t)hi << 32 | lo` and returns low word followed by high word. A roundtrip alone can hide paired inverse errors. It does not validate every Vulkan structure ABI. The real high-limb creation probe separately covers the flattened `[lo,hi,usage]` buffer layout and memory-requirement result path. A device that refuses this unbound buffer or needs a larger high limb fails this probe rather than receiving an ABI pass.

Production maximum-offset rejections occur before native dispatch. Production oversized writes also stop before native dispatch. Only the standalone establishes direct native writer limit-plus-one rejection. Complete-content claims cover the requested `L+2` bytes, not Vulkan allocation padding. General numeric containment remains established by the existing universal law. This run adds no fake IO law or traditional test.

Large linked lists, natural lengths, and one exact-limit readback list remain part of the actual transport. Payloads are generated at their call sites without a retained reusable expected copy. Peak resident memory was not measured. The commands passed within the unchanged deadlines on the available host with approximately 22 GiB RAM. No speedup, other backend, complete ABI, device-loss, dynamic replacement, or broader lifetime claim follows. No window rerun was needed because production code and UI behavior are unchanged.

## Failed attempts and retained originals

[Failed build attempts](failed-attempts.log) and [all statuses](statuses.tsv) retain seven small-driver compilation failures and one native-driver compilation failure. Repairs corrected list-pattern syntax, tuple destructuring, shift arity, affine reuse, and reusable-versus-affine payload quantities. The final generator accepts a quantity parameter. No runtime scenario, proof, source-policy, or default-gate failure occurred.

An initial source-inspection command used `deps/bend-vulkan/native.c` and exited 2 because the file is actually `deps/bend-vulkan/src/native.c`. Inspection continued at the correct path. Entire Brain reported an unavailable code index, so current source supplied the grounding. Neither condition changed dependencies or setup.

Full implementation commands, all failed logs and statuses, loader diagnostics, binaries, and source snapshots remain in `build/verification/upload-abi-eRwOfahQ/implementation-20261103`. The mutation summary names its separate isolated evidence directory. Parent baseline evidence in `build/verification/upload-abi-eRwOfahQ` remains intact.

The staged whitespace check found trailing spaces in copied command and compiler-error logs. These selected copies omit that whitespace. The local originals remain unchanged. The staged check passes after this formatting correction.
