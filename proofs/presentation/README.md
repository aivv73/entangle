# Production presentation ownership verification

`verify-presentation` checks ownership through native acquisition, recording,
submission, rendering completion, presentation, and target teardown. Rendering
and presentation have separate completion fences. A render-idle result alone
cannot release a presentation lease or its binary semaphore.

The [skill](../../.agents/skills/verify-presentation/SKILL.md) gives the required
workflow command. The focused command is:

```bash
bend tools/verify-presentation.bend -o build/verify-presentation
./build/verify-presentation --mutations +RTS --threads 1 --gpu off
```

## Production correspondence

`handlers.in.c` names complete helpers and contiguous native regions copied
verbatim from `deps/bend-vulkan/src/native.c` on every run. The shared Bend
extractor rejects missing function markers or changed exact call boundaries.
Wrappers bind validated objects and symbolic native results at those boundaries.
They do not implement ownership transitions, replace Vulkan entry points, or
dispatch a substitute driver. The C assertions operate on the production types.

| Extracted operation | Native code and symbolic boundary |
| --- | --- |
| Acquire | `bv_acquire` after validated object arguments; both fence status and `AcquireNextImageKHR` results, returned image index, and initial device serial are symbolic. Serial selection, lease installation, and issued numeric token fields are production statements. A constructor-boundary observer checks the emitted key, both serial limbs, index, and suboptimal flag. Bend heap allocation and constructor tags remain outside the proof. |
| Identity lookup | `bv_acquisition` after Bend term unpacking; production child lookup and full U64 serial reconstruction execute unchanged. The token's key and serial are symbolic. |
| Record acquisition | `bv_use_acquisition` after command/lease lookup; complete validation, `bv_prepare_refs`, and allocation failure behavior execute. |
| Submit and signal | `bv_submit_core_impl` guards and return continuation, plus `bv_submit_synced`'s commit/rollback continuation. Fence status and queue results are supplied separately. One already staged signal edge is a premise. |
| Observe | `bv_fence_observe` guards and native result continuation, with production `bv_complete` and `bv_finish_wsi_fence`. Wait/status mode and result are symbolic. |
| Present | `bv_present` after lookups; complete ownership guards, fence-status handling, and `QueuePresentKHR` continuation. |
| Release | `bv_release_acquired` after lookups; phase validation and `ReleaseSwapchainImagesEXT` continuation. |
| Reset | `bv_reset_command_buffer` guards and native continuation; `bv_reset_fence_core` guards up to dispatch. |
| Destroy | `bv_destroy_fence`, `bv_destroy_semaphore`, and `bv_destroy_swapchain` guards up to their destruction boundary. Actual hardware destruction is outside the proof. |
| Reuse a binary signal | The exact semaphore phase guard in `bv_submit_synced`, specialized to its signal-list branch. List decoding, duplicate/stage validation, and staging allocation remain outside this branch check. |
| Render idle | `bv_idle`, with symbolic `DeviceWaitIdle` result; the active-command completion loop executes unchanged. |
| Drain presentation | `bv_drain_presentation`, with independent symbolic `WaitForFences` results for its two active lease slots. Ownership validation, early exit, and completion execute unchanged. |
| Close one device | `bv_entry_close`'s idle, drain, and error-handling sequence up to `bv_destroy_device`. A separate boundary-observation flag avoids collisions with arbitrary numeric error codes. |

The five frontend regions are extracted from actual Bend source. Their source
policy requires each listed ownership operation exactly once and in order:
recording binds the lease, submits, checks render completion, then resets;
`acquired` waits for acquisition, records, presents, waits for presentation,
then handles rebuilding. Fence waits check success before reset. Close resets
recorded references before target destruction. Replacement destroys the old
target before building its replacement. These are source-policy checks, not
formal execution of Bend effects. Removal controls demonstrate sensitivity.

## Claims and call sequences

The independently stated assertions in `claims.h` cover these entry groups:

| Entry suffix after `verify_presentation_` | Claim |
| --- | --- |
| `serial_sequence`, `serial_exhaustion` | Acquire/observe/release/reacquire advances the full serial, stale tokens cannot resolve the reused slot, and exhaustion refuses before wrap. The first sequence also qualifies the extracted harness. |
| `acquire_results` | Every result bit pattern and returned image index has the correct lease/fence disposition. A valid issued token contains that exact lease identity. Invalid or duplicate indices retain uncertain ownership without issuing a token. A still-presenting older lease can coexist with reacquisition. |
| `identity`, `recording`, `borrowed_recording` | The owner, swapchain key, and full serial identify one lease. Stale tokens cannot record, release, or present; stale recordings cannot submit. Borrowed-image recording requires the matching completed lease. Recording allocation failure is atomic and retryable, including repeated failure. |
| `submit_results`, `uncertain_render_sequence` | Submission errors retain or preserve ownership correctly. Unknown submission requires idle; completion quarantines its semaphore and preserves recorded references. Allocation failure can retry the original acquisition. |
| `fence_status`, `reuse_guards` | Unsignaled fence status is required. Active acquisition/render/presentation fences cannot reset or destroy. Only an unused binary semaphore can receive another signal. |
| `frame_sequence` | Acquire, observe, enter the successfully recorded boundary, submit, observe rendering, reset the command, present, idle, observe presentation, and target destruction preserve separate completion ownership. Command reset preserves the rendered lease and signal needed by presentation. |
| `present_results`, `present_identity` | A matching rendered lease, producer serial, signal, and free fence are required. Allocation failure preserves retry identity; unknown results retain the presentation fence, image, and semaphore. |
| `observation`, `stale_completion` | Only successful matching completion advances or releases the lease. Timeout/error preserves ownership. Old WSI or command serials cannot alter a newer lease. |
| `reacquire_overlap` | Completing an older presentation cannot release the newer acquisition of that image. Borrowed-image lookup selects the current acquisition. |
| `release_results`, `resize_guards` | Release clears ownership only after completed success. Resize refuses unresolved phases and recorded references, with the existing terminal device-loss exception explicit. |
| `drain_sequence`, `close_sequence`, `broken_association` | Independent acquire/present waits preserve the first error. Close cannot destroy after unresolved rendering or presentation. Failed completion remains retryable; missing or stale completion ownership blocks close. |

`mutations.tsv` changes exact production lines in disposable copies. Every
control must fail its named property with CBMC status 10. Failed unwind
assertions invalidate a control, even if the named property also fails.
The original source is extracted and all entries run again after the controls.
The dependency is never edited. A failed baseline is a finding or a harness
issue to investigate, not a passing prerequisite.

## Bounds and assumptions

CBMC and goto-cc are pinned to 6.9.0 through the existing checksum-verified
native tool adapter. The topology has four scanned registry rows: a swapchain,
command, and two distinct borrowed images. The resize reference entry adds one
retaining image view, so the maximum scanned row count is five. Two devices, a command pool, three
fences, and one binary semaphore are validated boundary objects outside the
scanned list, with no outgoing reference edges. The swapchain has four lease
slots for two images, matching production's `lease_count=2*n`; at most two slots
are active in these entries. Both borrowed-image-to-swapchain dependency edges
are present. The immutable surface/window tail of the swapchain graph is
contracted at a validated boundary: it has no retired nodes or paths back to
the protocol rows. Reference
paths have at most one recorded swapchain/image edge plus one staged/committed signal
edge. Completion sequences enter submission at a successful end-recording
boundary with an allocated recorded edge. Separate recording entries execute
production staging, symbolic allocation failure, and retry. They do not assume
that an allocation retry must succeed. This decomposition avoids combining
independent allocator choices with every downstream completion path. The earlier
acquisition and later native completion operations execute unchanged. Recording
command validation has separate native coverage.

All 32-bit result patterns, full-width serials, token keys, returned image
indices, selected phase/identity mismatches, and allocation success/failure at
production reference staging are symbolic where the entry uses them. Initial
metadata and staged-signal allocation success are premises. Out-of-memory is
distinguished from an uncertain native result. The loss path preserves the
existing wrapper policy: lost devices permit terminal teardown, which is not
evidence that their work completed successfully.
Identity-mismatch fixtures include deliberate overapproximations of reachable
states. The extracted operation still has to reject or retain ownership under
the stated boundary assumptions.

The global unwind bound is four, covering the graph's maximum three-node
reachability path. Registry traversals allow five rows and six loop tests.
Four-slot lease traversals allow five tests. The reference/completion
bounds permit the stated edges; query-slot traversal is empty because this
registry contains no query pool. Per-loop options are retained in every `.argv`
file. Unwind assertions, pointer/bounds/overflow checks, malloc failure, and
memory-leak checking remain enabled. Fixture cleanup frees the actual current
command reference list after assertions.

This is bounded verification of the listed production operations and sequences,
not an exhaustive scheduler, arbitrary registry theorem, concurrent execution
proof, term-decoder proof, allocation-wrapper proof, Vulkan implementation
proof, hardware failure injection, other-backend result, or device-recovery
claim. Whole-entry multi-device destruction and actual swapchain deallocation
are outside the close boundary. Live synchronization validation, resize/Close,
zero-object teardown, populated pixels, and deterministic replay are separate
required evidence in the `presentation` workflow profile.

Multiple frames in flight and asynchronous presentation require an extended
production proof for their actual frame/semaphore topology and completion
orders before enablement. A small TLA+ model may supplement future schedule
exploration, but it cannot replace this production correspondence or establish
properties of transitions it does not faithfully represent.

The [task record](plan.md) retains acceptance, synchronization base, results,
counterexamples, and source-specific evidence paths.
