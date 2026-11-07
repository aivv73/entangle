# Hierarchy formal verification

Source baseline: `601ac1f1422a6c3fb869d20a22f357ffae438c54`.

## Observable acceptance

Add `verify-hierarchy-formal` and a single Bend driver. Prove properties of the
actual `src/hierarchy.bend` and `src/scene-hierarchy.bend` definitions, without
changing product behavior or introducing a replacement ECS implementation.

Required obligations, in order:

1. Every successful `evaluate` result has the input cardinality. Output positions
   follow the ascending traversal, including forward parent references.
2. Candidate edits and rollback preserve row cardinality. An equal-length commit
   consumes every row/value pair. Its checked writes require captured-live
   identities, an addressable physical index, and present transform/spatial cells;
   these preconditions must not be silently assumed to follow from list length.
3. Forest evaluation resolves roots and ancestors, reuses completed ancestors,
   and rejects cycles and missing parents. State numerical admission separately
   from the graph obligations and distinguish conditional witnesses from a
   theorem constructing those witnesses for every supported forest.
4. Rejected public edits preserve the incoming world. Failed propagation restores
   accepted spatial payloads through `commit`, retaining schedule administration
   and the resulting write-clock/stamp progress. Do not claim total-world rollback.

## Required evidence and limits

- Direct Bend proofs; kernel verdict only if the actual dependency closure admits
  it. Frontend and kernel results must be reported separately.
- Production mutations with the expected named law failure; compiler/parse errors,
  timeouts and unrelated failures do not count. Restored baseline must pass.
- Source-specific workflow receipt, root `PROOF.bend`, pinned toolchain, feature-map
  and roadmap updates, and the generated skill followed once from its commands.
- No performance, GPU, native renderer or window claim. Product code is unchanged;
  existing runtime hierarchy checks remain complementary to the formal scope.

State: first proof layer implemented and verified. The
all-forest contract remains incomplete under the explicit obligations below.

## Implemented proof scope

The 22 frontend laws import production modules directly. Four symbolic hierarchy
laws additionally require a kernel verdict, using verbatim selected proof
declarations and direct production imports. `evaluate_length` and
`publication_lengths` are unconditional successful-result cardinality theorems.
`candidate_length`, replacement/rollback lengths, and `pair_lists` close the
canonical publication path's list-length assumption without a size bound.

`forest_visit` and `rejection_visit` prove the production walk from certificates
that include actual array read/write equalities, explicit fuel, and, for success,
separate numerical `derive` premises. `sequence_order` proves ascending traversal
publication. `forward_certificate` and `forward_evaluate` instantiate the actual
initial array and fill path for a parametric child-before-parent forest. The
cycle and missing-parent entry laws hold for arbitrary transforms/bounds/lit
flags, independent of numerical admission.

`install_complete` proves that every certified row/value pair reaches the supplied
final scope. `ready` requires success from **both** transform and spatial optional
write results at every intermediate scope. `commit_administration` retains the
supplied administration and invocation. `one_row_read` and `one_row_ready` qualify
actual checked access through the production schema, lenses, columns and stamps
at physical slot zero, with arbitrary component payloads, stamps and ticks. This
is a concrete schema qualification, not a mock or a proof of every column tree.

`propagation_rejection` restores accepted checkpoints through canonical commit.
`scheduled_write_clock` retains administrative time and the active execution tick.
Root public rejection laws remain required by the workflow. Rejection-branch
world equality is distinct from proving whole-world preservation across `read`.

## Remaining obligations

The full requested all-forest atomic publication contract remains **incomplete**.

- Construct traversal certificates for every supported forest from the initial
  `fill` array. Prove array capacity/no aliasing, U32 index conversions, mark
  preservation, fuel sufficiency and the retained-local invariant. Cached values
  must be linked to the input locals, not merely accepted from arbitrary arrays.
- Construct `ready` from every successful `read`: prove captured-live identity
  retention, unique handles, physical addressability, column presence, preservation
  across each canonical write, and full read preservation before a public rejection.
- Combine those constructions with the existing theorems. Conditional soundness
  and a nonempty qualification do not imply general certificate existence.

The recommended next work is the retained-access bridge. It discharges the exact
reason `install` can discard optional results and supports the broader publication
contract. Do not redesign product code or weaken this obligation merely to obtain
an unconditional-looking proof. Numerically admissible acyclic forests remain
separate from a theorem of floating-point accuracy.

## Tool qualification

`bend guide` was read and the pinned Bend 2.0.39 frontend checks the direct import
closure. A direct `--verdict` probe fails because the kernel adapter cannot export
runtime-dependent ECS template arguments. This is a tooling limit, not a passing
kernel verdict. The full diagnostic is retained at
`build/verification/hierarchy-kernel-scope.log`.
The first schema probe exposed canonical `Owner`/`ColumnSlot`/`Viewed` wrappers;
qualification now constructs those actual production types and runs the actual
checked readers and modifiers. No simplified store was substituted.

## Validation record

The standalone suite observed all 16 intended production proof failures and a
restored passing baseline in `build/verification/hierarchy-formal-oVvAyPQZ`.
Its executable claims predate only the final import ordering cleanup.

The first workflow attempt, `build/verification/workflow-JS3TlXRG`, failed its
source-policy stage on the new direct ECS imports. Later stages were `not_run`.
The existing dependency inventory identified the exact additional symbols.
Only the reviewed pure ECS constructors and `clock-state.write`/`lifecycle.written`
were added to the policy. Existing trusted raw-upload entries reported by the
inventory were not approved. The policy-validation run selects `hierarchy-formal upload` to
require the upload policy mutations and real upload consumers as well as the new
formal gate. No dependency source or pin changed.

A pure production `hierarchy.bend` qualification passed `--verdict`. The kernel
limit comes from coupling the ECS publication closure to these proofs, so the
runner now selects exact proof declarations into a separate generated kernel
entry point. It imports the copied production hierarchy directly and changes no
production body. The four symbolic laws (`evaluate_length`, `forest_visit`,
`rejection_visit`, `sequence_order`) pass the proven kernel. All 22 maintained laws
still require the frontend. An eight-law core probe failed on `cycle_evaluate`
with kernel reduction fuel exhaustion, retained in
`build/verification/hierarchy-formal-XKrLDQFd/core-kernel.log`; the concrete entry
claims remain required frontend checks, not omitted or weakened claims.

The final standalone suite passed in
`build/verification/hierarchy-formal-58JKlDTU`: four kernel claims, 22 frontend
claims, 18 distinct production mutations, eight additional mutation rejections
through the kernel entry, and both restored baselines. New controls specifically
break read-stamp preservation and leave the schedule during commit. The initial
16-control runs are diagnostic evidence of the earlier verifier revision.

## Final receipts

- **Final focused workflow:** `build/verification/workflow-Nl5iuAAw`.
  `state=complete`, `run.status=0`, and all six manifest stages have status zero.
  It contains toolchain and source-policy checks, the root frontend proof gate,
  and the final hierarchy verifier. Its nested
  `source/build/verification/hierarchy-formal-c5bIq7Yu` retains four kernel
  claims, all 22 frontend claims, 18 distinct production mutations, eight
  additional rejections through the kernel entry, and restored frontend/kernel
  passes. Both kernel baseline logs contain `ALL PROOFS CHECK`.
- **Upload/policy validation:** `build/verification/workflow-LEmO4OWE`.
  `state=complete`, `run.status=0`, and all 17 manifest stages have status zero.
  This earlier snapshot contains the frontend-only 16-control hierarchy driver;
  that stage is superseded by the focused receipt above. Its root/publication
  proofs, law controls, upload kernel, real Vulkan upload boundaries and readback,
  cleanup, and source-policy mutation cycles all passed. Both runtime drivers
  report zero live Vulkan objects.
- `build/verification/hierarchy-receipt-changes.txt` compares the two source
  fingerprint manifests. Only hierarchy verification, workflow selection and
  explanatory documents differ. All product sources, dependency sources/pins,
  root laws/proofs, upload policy, upload proof files and upload drivers match.
  The older receipt is retained for those unchanged checks, not reused as a pass
  of the new hierarchy verifier.
- Skill frontmatter validation and `git diff --check` pass. No product source,
  dependency, renderer, or window behavior changed. Hierarchy runtime/window
  profiles were not rerun for this proof-only addition. No performance claim is
  made. The final record adds receipt paths after the snapshots; executable
  verification inputs are unchanged.

The generated skill was followed through its exact focused workflow command.
The broader all-forest/atomic publication task is not closed by these receipts.
The remaining construction obligations above are the next acceptance gate.
