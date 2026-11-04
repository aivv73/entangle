# Production native failure verification

The resource-lifecycle failure item uses two kinds of evidence: real Vulkan
execution for allocation failure, rollback, lifetime rejection, recovery and
teardown; bounded formal verification for rare driver errors. The native
implementation and its dispatch table are unchanged.

```bash
bend tools/verify-native-failures.bend -o build/verify-native-failures
./build/verify-native-failures --mutations +RTS --threads 1 --gpu off
```

The runner uses CBMC 6.9.0. On first use it downloads the official Linux
package, checks SHA-256
`3de313799ec2afc0154dad0e9d72db25d55aab007fa4652bf237626b808ca932`,
and extracts it under `build/verification/native-formal-tools`. Subsequent
runs require that version. The generated evidence includes the executable
hash. The default `tools/verify.bend` gate runs the positive proofs alongside
the real Vulkan checks.

## Connection to production

`extract.bend` reads the pinned `deps/bend-vulkan/src/native.c` on every run.
The directives in `handlers.in.c` select complete native types and helpers,
or contiguous statements after a native call / before dispatch. Those
statements are copied verbatim. Missing markers stop extraction. The generated
`handlers.c` is retained for review; it is never compiled into the engine.
The public native effects in `Vulkan.bend` import `src/native.c` directly. The window bundle is
checked against the same source with the dependency's existing
`python3 deps/bend-vulkan/tools/generate.py --check` command.

Small wrappers bind validated native objects and a symbolic driver return.
Where production normalizes that result through `bv_device_result`, the
wrapper calls that same extracted function. For tail extractions, the complete
native call line is an exact-match extraction marker. Other regions use the
explicit section boundaries in the template. Review the surrounding call and
normalization when either changes.
The wrappers do not implement lifecycle transitions. C assertions are used
because the handlers themselves are C; orchestration and extraction use Bend.

`prelude.h` projects Bend results to their numeric status for this ownership
proof. String construction, Bend term allocation and result-constructor tags
are outside it. Calls that would remove a registry row or clear a descriptor
pool are forbidden assertions in failure-only proofs. This proves such calls
cannot be reached; it does not substitute a cleanup implementation. Actual
reference-list cleanup and completion code is extracted, including `free`.
No Vulkan entry point is mocked, replaced, or invoked by the proof.

## Properties

| Proof entry | Production behavior checked |
| --- | --- |
| `verify_device_loss` | The original result is preserved; loss stays sticky, invalidates owned commands, retains references, and leaves another device alone. |
| `verify_record_reset_failure` | Begin/end/reset failures preserve status, generation, recorded edges, descriptor bindings and lease identity; the command becomes invalid. |
| `verify_submit_result` | Every result becomes pending, executable after allocation failure, invalid after loss, or uncertain with its fence and lease retained. |
| `verify_synced_submission` | Pending/uncertain submissions retain both staged semaphore edges; rejected submissions preserve prior semaphore state and recorded edges. |
| `verify_uncertain_guards` | Uncertain work blocks reset, fence observation/reset/destruction, pool destruction, and another submission with a fresh fence. |
| `verify_lost_guards` | A lost device blocks command reset and fence reset/observation before dispatch. |
| `verify_descriptor_failure` | Native free/reset failure preserves accounting and ownership, quarantines the pool, propagates loss, and blocks later free/reset/submit. |
| `verify_fence_reset_failure` | Native fence-reset failure preserves its status and references and propagates device loss. |
| `verify_idle_failure` | Failed idle does not claim completion or release references; an unknown completion error cannot reach entry-owned device destruction. |
| `verify_completion` | Completion releases submission edges, preserves recorded edges, invalidates formerly uncertain commands, and quarantines uncertain semaphores. |
| `verify_idle_success` | Successful idle calls completion for active work and retains recorded ownership. |

`mutations.tsv` deliberately breaks production statements in disposable
copies. Each case must exit with CBMC's property-failure status and name its
expected failed assertion. Parse errors, missing markers, timeouts, or an
unrelated failure do not count as a successful negative control. The original
dependency is never edited. Every original proof runs again afterward.

## Bounds and assumptions

The proof starts with valid object pointers and an acyclic, explicit registry
topology: two commands belonging to one device, a command belonging to another
device, and a resource row. Submission/completion proofs have at most two
semaphore edges and one recorded edge; descriptor proofs have a pool/layout
dependency pair and one referring command. One lease is present. Numeric
result bits, command generations, descriptor accounting and a selected slot
among all 64 descriptor bindings are symbolic where relevant. Some payload
states deliberately overapproximate reachable states.

CBMC checks all 32-bit `VkResult` patterns, with success excluded only in
failure-only entries. The global loop unwind bound is six; idle completion is
bounded to one active command (two loop tests). Completion's edge loop allows
three edges (four tests); its query-slot loop allows no slots (one test), as
the registry has no query pools. Unwinding assertions, pointer,
bounds and signed-overflow checks are enabled. A violated bound fails the
proof. This does not establish arbitrary registry/list sizes, arbitrary graph
topologies, concurrency, allocation success, Vulkan dispatch correctness,
presentation/query semantics, or device recovery.

The relevant native guards are checked after handle validation. This does
not prove every API guard or the preceding handle decoder. The entry cleanup
proof begins after idle/presentation completion returned: it proves refusal
to destroy on an unresolved error, not the complete multi-device teardown.
Real-runtime checks separately validate successful cleanup and zero live
objects. Device loss and unknown native cleanup errors are formally covered,
not claimed as observed hardware events.

The existing formal claims in `LAWS.bend` continue to prove pure Bend
transaction policy. They do not claim to prove foreign C handlers. Review the
native assertions here alongside those laws and the
[real-runtime evidence](../../docs/verification/2026-11-03-native-failures/README.md).
