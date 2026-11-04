# Native failure-path closure evidence

This work continues [trail 20](https://entire.com/et/bend-engine/-/trails/20)
from root commit `e0dfa4b`. The user selected **formal verification of
production handlers plus real-runtime checks** as the closure criterion.
Mocked dispatch and injected Vulkan runtime results are excluded.

The production engine and `deps/bend-vulkan` remain unchanged. The dependency
is pinned at `a144f7dd4fb4835ca3d5ce17350fc850de049038`. The native checks that
reject invalid handles, lifetimes, ranges and states remain in place.

## Evidence design

The [formal checker](../../../proofs/native-failures/README.md) extracts real
C statements from `native.c` on each run. CBMC 6.9.0 checks symbolic driver
results at native return boundaries. It does not invoke or substitute a
Vulkan implementation. Eleven proof entries cover recording/reset failure,
submission uncertainty and semaphore ownership, sticky device loss,
uncertain-operation guards, descriptor cleanup quarantine, fence reset,
failed completion/entry cleanup, and successful completion retaining
recorded references.

The scope is explicit: at most four scanned registry rows, three dependency
edges, one acquisition lease, and all 32-bit result patterns. Unwind
assertions and memory-safety checks are enabled. The complete assumptions,
boundary projections and exclusions are in the formal checker's README.
Eighteen disposable mutations of actual native statements exercise the
assertions. Each must produce its named counterexample; compiler errors and
timeouts cannot pass a negative control. The original source is checked again
afterward.

The existing [real Vulkan driver](../2026-11-03-native-failures/README.md)
provides genuine allocation failure, partial rollback, unchanged resident
identities and bytes, retry, recording/submission/pending-reset rejection,
cleanup diagnostics and terminal teardown. The full native gate also checks
retaining references, actual rendered output, upload boundaries and headless
scene behavior. These checks use the validation layer with synchronization
validation enabled.

## Final run

Local evidence: `build/verification/native-failure-closure-wN6VT5tB`.
The complete run exited with status `0`.

| Gate | Result |
| --- | --- |
| CBMC production-handler proofs | All 11 entries pass; all 18 deliberate source regressions fail their named assertions; all 11 original entries pass again. |
| Root `bend PROOF.bend` | Pass. |
| Full `bend tools/verify.bend` | Pass, including formal checks, native upload/ABI checks, headless scenes, exact offscreen rendering, mesh retention, and native failure recovery. |
| Upload-policy controls | All 11 regressions reject; baseline and restored copies pass. |
| Native/window generated bundle | Existing generator `--check` passes; dependency remains clean. |
| CBMC package | Pinned archive checksum passes; fresh extraction reports 6.9.0 and matches the checked executable. |

The formal evidence is `build/verification/native-formal-EvlmPb0q`; the
default gate's independent formal run is
`build/verification/native-formal-SnrAkij6`. The upload-policy evidence is
`build/verification/upload-mutations-piFDDj5H`. Their logs, generated sources,
named counterexamples, statuses and source hashes are retained locally.
Both formal source-hash manifests match the final proof code and unchanged
production native source.

Real Vulkan returned `vkAllocateMemory: VkResult -2`. The process limit was
restored; the first candidate was rolled back, the old resident and diagnostic
owner were preserved, and allocation/upload then succeeded. All four partial
rollback retention combinations passed. Recoverable and terminal paths
reported zero live Vulkan objects. Exact RGBA/depth/replay checks passed, and
the native log contains no validation errors, VUIDs or synchronization hazards.
The runtime driver's `Unexercised` footer describes hardware events; those
rare handler paths are covered separately by the bounded proof.

The roadmap failure-handling item is closed under the approved criterion.
The [verification skill](../../../.agents/skills/verify-native-failures/SKILL.md)
records reproducible commands and the source synchronization revision.

## Limits

This closes an error-handling verification item under the selected evidence
standard, not an unbounded native lifetime theorem. Rare uncertain-submit,
device-loss, and native reset/free failures are formally checked, not claimed
as observed hardware events. The driver, compiler, Bend result-constructor
encoding, error-string formatter, arbitrary registry graphs and presentation
or query behavior remain outside the C proof. Real runtime evidence covers
the selected native lane. Sampled-image retention remains a separate open
roadmap item. No X11 rerun is claimed because renderer and window behavior
are unchanged.
