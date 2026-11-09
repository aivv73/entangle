---
name: verify-hierarchy-formal
description: Kernel-check production Bend hierarchy cardinality and certified traversal/order, and frontend-check certified ECS publication and rollback contracts. Use after hierarchy, scene-hierarchy, schema, or checked ECS access changes; read the remaining proof gaps before claiming all-forest atomicity.
---

Run from the repository root with `toolchain.bend` pins. Use alongside
`verify-entangle` for product changes; this skill adds no native/window coverage.

```sh
bend guide
mkdir -p build
bend tools/verify-workflow.bend -o build/verify-workflow
./build/verify-workflow --plan hierarchy-formal
./build/verify-workflow hierarchy-formal +RTS --threads 1 --gpu off
```

The `hierarchy` profile also requires this gate. The focused profile runs
toolchain, source policy, root frontend proofs
and this hierarchy gate. For production changes, select `hierarchy` as well to
require the runtime consumers and existing root/publication mutation gates.
Require `state=complete`, `run.status=0`, and every manifest stage status zero in
the printed workflow receipt.
Inside its source snapshot, `build/verification/hierarchy-formal-*` retains the
baseline, production mutations, restored baseline, exact changed sources and
source hashes. Require `core-kernel.status` and `restored-kernel.status` zero.
Mutation statuses are **1**, with the expected proof location;
the enclosing driver succeeds only after observing each intended rejection.
Crashes, parse errors, missing targets and timeouts are failures, not controls.

For proof iteration: `bend proofs/hierarchy/PROOF.bend`. To run the same controls
outside the source snapshot, build `tools/verify-hierarchy-formal.bend` natively
and run it with `+RTS --threads 1 --gpu off`. It mutates only a fresh evidence
copy. The complete source-specific receipt comes from the workflow command.

Read [the proof contract and current result](../../../proofs/hierarchy/plan.md)
before interpreting a pass. Claims live exclusively in
`proofs/hierarchy/LAWS.bend`; `spec.bend` holds witness types and
`PROOF.bend` fills the claims. All imports use actual production definitions.
No replacement evaluator, ECS store, or native adapter is admitted.
The runner copies the four symbolic hierarchy claims and their proof declarations
verbatim into `kernel/`, with direct imports of the copied production hierarchy.
The generated files are retained for inspection and require `--verdict`.

Original coverage baseline: `601ac1f1422a6c3fb869d20a22f357ffae438c54`.
Current working-tree synchronization for Bendvy `59833ad` is retained in the
[ECS migration record](../../../docs/verification/2026-11-09-ecs-migration/README.md)
with the migrated publication witnesses and fresh mutation/kernel receipts.
Move the baseline only after checking that the proofs still describe the new
production revision.

| Production definitions | Proven scope |
| --- | --- |
| `hierarchy.evaluate`, `evaluate_each`, `evaluated`, `reusable` | Unconditional successful-result cardinality for arbitrary input lists and accumulator lengths. |
| `scene-hierarchy.locals`, replacements, `candidate`, `rollback` | Length preservation; successful candidate/evaluate pipeline has exactly one value per row. Equal-length lists admit a complete paired batch. |
| `hierarchy.visit`, `visit_checked`, `visit_mark`, `visit_parent`, `parent_done`, `save` | Any admitted finite forest certificate resolves the specified ancestor globals; any admitted rejection path yields the specified cycle/missing-parent error. Every certificate includes exact production `Array.get/set` equalities and explicit fuel. |
| `hierarchy.evaluate_each` | Certified visits are published in ascending index order. A parametric child-before-parent forest connects the certificate to the actual `fill/new/evaluate` entry path. |
| `scene-hierarchy.install`, transformed/spatial writes, `commit_scope` | Every pair in a certified batch is written, with **both** canonical write results `True`; commit finishes only the run scope it owns. A real eight-cell schema qualification proves read preservation and successful writes for live entity slot one (payload cell zero), for arbitrary payloads and stamps, using the current `World`, default indexed `Column`, and component families. |
| `scene-hierarchy.rejected`, `clock-state.write` and root public-rejection laws | Propagation rejection commits accepted spatial checkpoints; scheduled writes retain administrative time and captured execution tick. Public rejection returns the world passed to the rejection branch. |

**A pass does not prove all-forest atomic publication.** General construction of
forest certificates from a supported parent forest and construction of `ready`
from every successful `read` remain open. The concrete schema qualification does
not generalize to arbitrary handles, branch-shaped columns, or whole-world read
preservation. Do not turn those gaps into assumptions hidden behind “exclusive
ownership.” Keep them visible until the retained-handle, column-presence and
array-capacity bridges have proofs.

Numerical admission is the explicit `derive(...) == Done{...}` premise of a
success certificate. Rejection-path proofs need no numeric premise. This is no
theorem of floating-point accuracy, normal invertibility or numerical admission
for all acyclic graphs. Certificates check production array operations directly;
they do not yet establish the general `fill` invariant or U32/capacity bounds.

All 22 claims require the frontend. Four additionally require the pinned Bend
kernel: `evaluate_length`, `forest_visit`, `rejection_visit`, and `sequence_order`.
All eight production hierarchy mutations must also reject through that kernel
entry point, followed by a restored kernel pass.

ECS publication remains **frontend-only** in the current receipt. The selected
kernel entry point certifies only the four extracted hierarchy claims; it makes
no full ECS kernel claim. Concrete entry laws also require the frontend. The
original pre-migration kernel probes and their template/reduction limits remain
historical in the task record. Do not call unexecuted kernel checks a pass or
weaken the claims to silence a failure.

For intended behavior changes, revise laws and certificates together, then add a
production mutation for each changed property family. Follow this skill once on
the changed sources and require restored success. Use
`/maintain-formal-verification-skill` after intervening unverified source changes.
