# Presentation ownership verification

## Acceptance (recorded before implementation)

Add a discoverable project-local `verify-presentation` skill and a required
`presentation` workflow profile. Keep one owner for the coupled extractor,
assertions, mutations, source correspondence, coverage, and task state.
Production behavior and dependency revisions are outside this change.

The bounded checks must execute statements extracted from
`deps/bend-vulkan/src/native.c`, with symbolic 32-bit native return values,
and establish:

- Acquisitions have nonzero, nonrepeating device serials; a serial cannot wrap.
  Invalid/duplicate image indices quarantine the acquisition and its fence.
- Lookup, recording, submission, release, and presentation reject stale or
  mismatched identities. Reacquiring an image during its older presentation
  cannot let the old completion alter the newer lease.
- Acquisition, rendering, and presentation completion are separate. Active
  fences and binary semaphores cannot be reset, destroyed, or reused early.
- Allocation failures leave ownership retryable. Unknown acquisition, render,
  and presentation results retain ownership and block unsafe reuse.
- Resize destruction refuses unresolved work and recorded references. Close
  observes rendering and presentation separately, retains objects after an
  unresolved completion, and handles the existing terminal device-loss policy
  explicitly.

Use the existing pinned CBMC 6.9.0 tool adapter and production extractor.
Qualify the new sequence harness with an actual extracted acquire / observe /
release / reacquire sequence and an independently stated serial oracle before
expanding it. Do not substitute Vulkan dispatch. Use explicit effect boundaries
with exact source markers, unwind assertions, pointer/bounds/overflow checks,
and allocation-failure checking. Document finite topology/sequence limits.

Every property family needs a disposable production-source mutation that fails
its named ownership assertion; compilation errors, timeouts and unwind failures
do not count. Restored production must return to its original verdict. Retain
generated C, literal commands, hashes, logs and statuses in a source snapshot.

Required completion evidence: `presentation` workflow receipt, root Bend proofs,
existing native failure positive checks when their shared runner changes,
native bundle consistency, skill validation, and owned Xwayland resize/Close
with synchronization validation and replay. Report unavailable or failed
checks separately. Add a prerequisite for multiple frames in flight and
asynchronous presentation in the skill, workflow/coverage docs and roadmap.
No TLA+ model is required if extracted call sequences answer the question.

## State

Complete locally. The dedicated skill, production-extracted checks, sensitivity
controls, source correspondence, workflow prerequisite, and required evidence
are implemented and verified. This work creates no commit or publication.

Source synchronization base: root `9fc2eba1e9b4e811672f0a4ebc19eb8a7747db54`
and bend-vulkan `a144f7dd4fb4835ca3d5ce17350fc850de049038`. Product sources
and dependency pins are unchanged. Verification completion, any commit, and
publication are separate states.

## Accepted evidence

- The [`presentation` workflow receipt](../../build/verification/workflow-gNDTf1es/manifest.tsv)
  is complete: all 12 required stages, `run.status=0`, and `state=complete`.
  It includes root/publication frontend proofs and mutations, source policy,
  bundle correspondence, owned-window evidence, and the presentation suite's
  21 baseline and restored entries, 34 native controls, and 18 frontend controls.
  Its [audit](../../build/verification/workflow-gNDTf1es/evidence-audit.json)
  records every stage status.
- The [final presentation receipt](../../build/verification/presentation-9fK364sQ/run.status)
  additionally checks the issued token's numeric fields at the production
  constructor boundary. All 21 baseline entries, 21 restored entries, 35 native
  controls, and 18 frontend controls pass their required verdicts. The
  [audit](../../build/verification/presentation-9fK364sQ/evidence-audit.json)
  checks all 138 expected statuses. Source/tool checksums pass, and baseline
  and restored generated C compare byte-for-byte.
- The [source comparison](../../build/verification/presentation-9fK364sQ/profile-source-difference.patch)
  shows exactly four changes after the full workflow snapshot: the presentation
  C template, assertions, mutation registry, and reference document. The change
  adds the token observer and serial-limb control. All production, frontend,
  workflow, and shared-runner inputs match the completed workflow. The final
  focused run rechecks the affected formal stage. The earlier workflow alone
  does not certify this later proof extension; these receipts are used together.
  The comparison precedes the closing status edits in this task record, the
  skill, and the roadmap. Those edits only record the results and receipts.
- [Shared-runner compatibility](../../build/verification/native-formal-90m6XfIe/run.status)
  passes all 272 original native-handler and lifetime positive entries. All
  275 statuses, including compilation and the run status, are zero. Their
  production source and original bounds are unchanged.
- The [owned-window log](../../build/verification/workflow-gNDTf1es/source/build/verification/entangle-lsrvMHAl/window.log)
  records held/release/reset, focus loss, unmap/restore, repeated resize, Escape,
  and hidden Close. Both native exits report zero live Vulkan objects without
  validation diagnostics. Real ECS replays match 1466 live and 21 close batches
  with complete handle and transform bits. Initial/held/reset captures were
  inspected; initial and reset PPMs match byte-for-byte, and every retained
  capture hash passes. The owned display was reaped and its runtime removed.
- Root `bend PROOF.bend`, native bundle consistency, skill validation, and
  `git diff --check` pass. Root proofs are frontend checks, not kernel verdicts.

The proof scope is one command, two borrowed images, four production lease
slots with at most two active, at most five scanned rows, and the documented
sequences. Native results are symbolic, including allocation and uncertain
results; these are not observed hardware failures. Heap term allocation/tags,
arbitrary schedules, multi-device entry destruction, and asynchronous or
multiple-frame ownership remain outside the claims. Terminal device loss is
an explicit teardown exception, never described as successful completion.

Multiple frames in flight or asynchronous presentation require extending this
suite to their actual topology and completion orders, passing source controls,
and live resize/Close evidence before enablement. No product sources,
dependency pins, runtime parallelism, or rendering behavior changed.

## Harness qualification decisions

The extracted acquire/observe/release/reacquire sequence passes. An initial
retry assertion incorrectly required the second allocation to succeed; the
counterexample makes both real production `malloc` calls return null. The
oracle now requires ownership preservation on another failure and the original
identity on success. The trace is retained in
`build/verification/presentation-gZxFgVlh/qualification-recording-trace.log`.

The longer uncertainty sequence still expands heavily after using distinct
registry objects and separating successful recording from allocator failures.
Premise to test before another adjustment: the expansion comes from fixture
aliasing and registry size. Inspect the detailed CBMC symbolic-execution trace
against that premise. The interrupted runs remain unsuccessful and cannot
certify the prerequisite.

The detailed trace contradicts registry size as the main cause: it expands the
recursive `bv_may_reach_depth` edge loop to the default six tests at every
recursive level, including paths the final solver can rule out. The presentation
bound omitted the explicit edge-loop overrides already used by the lifetime
suite. Add three-test bounds for reachability, sealing, and dependency traversal
to match the at-most-two-edge topology. Keep unwind assertions enabled so this
cannot silently truncate a real path. The diagnostic trace is retained in
`build/verification/presentation-rVxMWiGr/qualification-symex.log`.

Correspondence review of `bv_create_swapchain` found required borrowed-image
dependency edges and the `lease_count=2*n` relation. The final fixture includes
both edges, two images, and four slots, with at most two active. The resize
control now uses a real retained-view topology; deleting the image-reference
guard alone is redundant when a command also reaches the swapchain. Its
maximum registry is five rows. The immutable surface/window graph tail is an
explicit contracted boundary. Three-node graph paths permit a global unwind
bound of four, with larger explicit registry and lease-loop bounds. All unwind
assertions remain required. Two controls also needed extraction markers that
survive their intended guard/result mutation; a missing marker was rejected,
not counted as a counterexample.
