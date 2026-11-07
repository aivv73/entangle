# Production native failure and lifetime verification

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

`--lifetime` selects the nine logical lifetime entries only. Combine it with
`--mutations` for their production controls and restored baselines. The default
checks both suites. Each result retains literal arguments, generated source,
status, and a CBMC log. `run.status` remains nonzero until all selected checks
finish successfully. The `native` workflow profile supplies the complete
source-specific receipt and required real-runtime consumers.

Each extracted source is compiled once by `goto-cc` from the same pinned CBMC
package. The runner checks its version, records the executable/source/GOTO hashes
and compilation status, and selects proof functions from the retained GOTO file.
The adapter was qualified against the actual sampled-resource graph: both direct
C and GOTO checks pass. See the task record for the probe.

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
| `verify_lifetime_retirement` | Two pairs seal together after validation. Null handles, foreign buffers, mismatched bindings, offsets, recording references, aliases, and prior errors preserve the original flags and ownership. |
| `verify_lifetime_graph` | A sampled descriptor/view/image/memory graph and sampler retain every resource. Sealed descendants block recording, active memory checks respect owners, and destruction guards refuse retained resources. |
| `verify_lifetime_prepare` | Staging preserves prior references on refusal or allocation failure, and installs the complete deduplicated recorded set on success. |
| `verify_lifetime_collection_00`, `_01`, `_10`, `_11` | Four separate initial list orders cover both buffer/memory adjacencies for each pair. Collection removes exactly eligible allocations, respects owner/loss/reference guards, advances safely past removed rows, and is idempotent. |
| `verify_lifetime_completion_reset_pending`, `_uncertain` | Both initial phases preserve recorded allocations through completion; two successful resets release their edges, while a descriptor retains its allocation until its own removal. |

`mutations.tsv` deliberately breaks production statements in disposable
copies. Each case must exit with CBMC's property-failure status and name its
expected failed assertion. Any failed unwind assertion rejects the run, even
when the expected property also fails. Parse errors, missing markers, timeouts,
or an unrelated failure do not count as a successful negative control. The original
dependency is never edited. Every original proof runs again afterward.
`lifetime-mutations.tsv` supplies the lifetime suite's separate controls.
Its optional sixth field selects the collection counterexample configuration.
Other entries retain five fields.
The 23 controls include leaked staged references after refusal or malloc failure,
and forgotten registry-row deallocation. These fail the standard CBMC leak
property, so leak checking is itself covered by production-source sensitivity.

## Lifetime correspondence and limits

`lifetime.in.c` copies complete types and helpers, the paired-retirement
validation/sealing continuation, successful command reset, destruction guards,
and collection control/metadata statements. Retirement begins after handle/list
decoding and staging. A symbolic prior error covers refusal before sealing; the
staging allocator and its list decoding are outside this proof.

Collection observes the exact `DestroyBuffer` and `FreeMemory` call boundaries.
The extraction requires their complete native call lines, but never invokes or
substitutes a Vulkan function. The assumption is that these void driver calls do
not mutate the wrapper's private `bv_rows` metadata. The actual `bv_remove` and
its `free` statements run unchanged. Boundary assertions check valid ownership,
retirement, references, and buffer-before-memory order. Real Vulkan retention and
cleanup remain separately required.
Its retaining-reference oracle is derived independently from the initial owner
edges. At memory destruction the observer also checks that the paired buffer
has been destroyed and is absent from the actual registry. It does not validate
the production guard by calling the same predicate again.

The initial ownership subgraphs contain at most eight scanned rows and eight
edges. The retirement entry has two pairs and a recording descriptor path, with
up to two aliases. The sampled entry has a four-edge command-to-memory path, a
sampler branch, and an unrelated allocation. Reference staging admits two input
resources over one prior recorded edge, including duplicates and sealed
descendants. Collection has two owned pairs, a descriptor holder, and a foreign
pair. Four concrete-order entries cover the Cartesian product of both
buffer/memory adjacency orders; each order checks the complete six-bit
retirement/reference/error input space.
The completion/reset
sequence has two pairs, two commands, and a persistent descriptor owner.

`collection-cases.bend` generates every concrete configuration entry for each
order. Bits 0/2 mark the first/second pair retired, bits 1/3 mark its retaining
descriptor edge, bit 4 selects an invalid owner, and bit 5 selects device loss.
The runner requires all 64 values for each order, so the complete product has
256 checks. Heap identities, pointer safety, allocation bookkeeping, and all
remaining model choices stay subject to CBMC. The two completion/reset entries
cover pending and uncertain initial phases separately. There are 261 positive
lifetime checks per baseline or restored pass. No selected configuration can be
skipped and still produce `run.status=0`.

Predicate/retirement entries use distinct initial stack objects. Collection uses
heap victim pairs with static retained/foreign boundary rows; the reset sequence
uses heap rows/edges. Initial successful heap objects are constructed with
`__CPROVER_allocate`, and the possible-leak pointer is recorded in the same way
as the pinned [CBMC allocation model](https://github.com/diffblue/cbmc/blob/cbmc-6.9.0/src/ansi-c/library/stdlib.c).
`bv_add` and allocation wrappers are outside the claims. Initial allocation
success is a premise. Failure is enabled before production reference staging,
which retains its unchanged `malloc` calls. Actual production registry removal
and the standard `free` checks execute in the proof. Lifetime entries use
a global unwind bound of six, explicit eight-row registry bounds (nine loop
tests), two-input staging/retirement bounds, completion's three-edge bound, no
query slots, and memory-leak checks in addition to pointer/bounds/overflow checks.
The `.argv` files retain every per-loop override. Unwind assertions stay enabled.
These are
finite ownership subgraphs at validated boundaries, not arbitrary native graphs.
Descriptor population, all allocation wrappers, term decoding, borrowed
swapchain images, presentation, concurrency, and hardware destruction behavior
remain outside the formal scope.

The separate [publication harness](../geometry-publication/README.md) proves that
accepted replacement retains candidate state and all material retirement queues,
and that pure cleanup decisions preserve pending resources and active bindings.
The real replacement/failure/texture drivers cover allocation rollback, preserved
resident bytes, retry, cleanup diagnostics, and zero-object entry teardown.

## Original failure-suite bounds and assumptions

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
