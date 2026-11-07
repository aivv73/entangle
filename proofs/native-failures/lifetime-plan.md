# Native lifetime verification task

Base: root `834e23d`, bend-vulkan `a144f7dd4fb4835ca3d5ce17350fc850de049038`.
State: implementation and verification complete in the working tree.

## Accepted result

The final source-specific [receipt](../../build/verification/workflow-H51QSNBC/manifest.tsv)
selects `native-failures`. All 14 required stages pass; `state=complete`,
`run.status=0`, and the independent evidence audit has `audit.status=0`.
Current verification code matches its retained snapshot, recorded in
`checked-current-code.sha256` and `code-correspondence.status=0`.

- Native evidence is in the snapshot's
  `build/verification/native-formal-Zgxmi2dU`: 272 baseline and 272 restored
  checks pass, including all 261 new lifetime checks. All 41 native production
  controls fail their named properties, including the 23 new lifetime controls.
  No native log contains a failed unwind assertion. Baseline and restored C
  sources match byte for byte.
- Publication evidence is named in `publication.stdout`: all nine frontend
  claims, ten production controls, and restored sources pass. Root frontend
  proofs and law controls also pass in the final receipt.
- Final `retention` and `resource-failures` logs confirm validation-layer
  insertion, all uniform/sampled retention scenarios, genuine
  `vkAllocateMemory: VkResult -2`, rollback, preserved residents, successful
  retry, and zero-object teardown, without validation diagnostics.
- The initial `workflow-dWqCtj6D` retains the unaffected full native product,
  texture, rendering, upload-kernel, and upload-policy results. Product sources,
  assets, examples, native C, upload theorem, and upload-policy driver match the
  final snapshot. Its two invalid sensitivity traces remain rejected and are
  superseded by the final native evidence above. Replacement red/green/range/
  empty images were inspected.
- The native-bundle generator check, skill frontmatter validation, and
  `git diff --check` pass. Product sources and dependency pins are unchanged.

The C claims cover the documented finite graphs with at most eight scanned
registry rows. Driver destruction is an opaque effect boundary. Pure cleanup
claims are Bend frontend checks, with no finite list bound. Completion prose was
added after verification; the recorded source hashes identify the tested code.

## Implementation and verification decisions

The first complete workflow, `workflow-dWqCtj6D`, reported all 14 stages at
zero. Its final evidence audit rejected two lifetime controls: their intended
ownership assertions failed, but fixture teardown also exceeded an unwind
bound after passing a stale row to production `bv_remove`. CBMC assertions do
not stop later symbolic execution. Teardown now looks up actual survivors;
all ownership assertions and bounds remain unchanged. The runner also rejects
any failed unwind assertion, even alongside the expected counterexample. This
receipt is not accepted as final sensitivity evidence and must be superseded.

Qualification in `build/verification/lifetime-unwind-qualification` runs actual
CBMC artifacts. The stricter runner rejects the retained old trace with
`Native proof exceeded an unwind bound` (expected driver exit one). The two
affected production mutations then fail their named ownership properties with
corrected teardown, unchanged bounds, and no unwind failure (driver exit zero).
The temporary qualification driver is retained beside that directory as
`build/verification/qualify-lifetime-unwind.bend`.

The correction changes only the C fixture and the verdict gate. Following the
development workflow's instruction to rerun only invalidated checks, final
verification selects a fresh `native-failures` snapshot with Khronos validation,
synchronization checks, and loader layer diagnostics enabled. This repeats all
affected frontend/cleanup claims, native proofs and mutations, restored sources,
and real retention/failure consumers. The first snapshot's unaffected asset,
parser, texture, rendering, upload-kernel, and upload-policy evidence retains its
original source revision; it is not a pass of the corrected formal runner.

The material-error proof initially assumed that U32 literal matching reduced to
`U32.is_eq`. Exporting the extracted production module to
`build/verification/materials-normalized.bendtt` disproved that premise: literal
patterns lower to structural word-bit matches. The proof follows that production
case split, using the 32 first-differing-bit cases emitted by
`proofs/geometry-publication/error-proof.bend`, and eliminates the excluded word
with the existing Boolean contradiction lemma. The claim and its error-code
scope are unchanged. All eight publication/cleanup production controls and the
restored baseline pass in `build/verification/publication-PWLh7ezX`.
After adding direct texture-release claims, all nine frontend laws, ten
production controls, and the restored baseline pass in
`build/verification/publication-bAmIZRd9`.

Early native retirement probes exceeded the per-entry limit when initial
allocation machinery and symbolic topology construction dominated execution.
Predicate entries now use fixed explicit initial rows/edges, and the lifetime
suite retains CBMC array-field sensitivity. Collection still executes actual
heap removal. Failed/interrupted probes remain under `native-formal-nqJeWv0T`,
`native-formal-NjgTNsnU`, and `native-formal-TcbEVSqh`; none is a passing receipt.
The diagnostic `build/verification/lifetime-symex-steps.log` shows recursive
reachability expanding infeasible dependency-list paths. Explicit per-loop
bounds now distinguish the eight-row registry scan from the two-edge graph
fan-out. Unwinding assertions verify both bounds on the original production code.
The first three lifetime entries pass after representing each initial row/edge
as a distinct object instead of an indexed array of objects. This preserves the
same symbolic input choices and removes pointer ambiguity during symbolic
execution. Collection continues to use actual allocated objects.
Heap setup also fixes allocated identities before varying registry order, and
disables CBMC allocation failure only during initial-state construction (where
success was already a premise). Failure is enabled before production reference
staging. Collection's four victim objects and their binding edges are heap
allocated; retained/foreign boundary rows need no deletion. Actual production
removal/free runs for each eligible victim and each heap survivor at teardown.
Initial successful heap objects use CBMC's allocation intrinsic and its standard
possible-leak tracking policy. Production reference staging still uses unchanged
`malloc` with failures enabled. This initial-state boundary does not verify
`bv_add` or any native allocation wrapper.
Collection's six Boolean inputs (two retirement flags, two retaining-owner flags,
invalid owner, and lost device) form exactly 64 configurations. The runner checks
every configuration separately for each of the four list orders, retaining the
full C memory model in each check. This is the complete Cartesian product, not a
sample. Keeping the input bits concrete avoids merging mutually exclusive heap
histories before symbolic execution. Every configuration has its own arguments,
verdict, and log; an omitted or failed configuration prevents suite completion.

All 256 direct-C collection checks passed in the retained
`build/verification/native-formal-fBq9fCIB` probe. Its later symbolic
completion/reset attempt was interrupted and the suite is not a passing receipt.
The final runner emits the same complete case product as C entry functions,
compiles each source once, and checks the retained GOTO representation.
Qualification used the actual sampled graph: `lifetime-qualified.goto` and
`lifetime-qualified.log` under `build/verification` match the direct-C positive
verdict. The pinned compiler reports CBMC 6.9.0. Pending and uncertain completion
sequences now have separate entry functions; their combined input scope is
unchanged. Each collection order uses its exact seven-row/two-owner-edge bounds
with unwinding assertions enabled.

All nine positive lifetime groups, all 23 new production mutations, and the
restored pass succeeded in `build/verification/native-formal-unqoAMdB`.
That iteration's input hashes predate the final three leak controls; its observed
results are diagnostic evidence. The final workflow reruns the frozen inputs.
The controls include staged-reference leaks on both refusal and allocation
failure, and omitted registry-row deallocation. These must fail CBMC's actual
memory-leak property, independently of the ownership assertions.

Collection's retention oracle comes from the initial retaining-edge inputs, not
a second call to the production guard. At memory destruction it requires the
matching buffer's destruction and removal from the real registry. The loop,
guard, unlink, reference cleanup, and `free` statements remain extracted C.

The initial `native` workflow ran in `build/verification/workflow-dWqCtj6D`.
Its texture driver explicitly enables Khronos validation and synchronization
checks. Other runtime drivers inherit the environment, which did not contain
those settings at launch. A supplemental retention/resource-failure run against
the same retained snapshot is therefore required with both variables set. The
skill's primary command now includes that environment explicitly. This prose
correction did not change that frozen verification code. Its supplemental
runtime checks passed with loader-confirmed validation-layer insertion, genuine
allocation failure/retry, zero live objects, and no validation diagnostics.
The final affected-profile workflow completed in
`build/verification/workflow-H51QSNBC`; its invocation records the validation
environment and it uses the corrected C fixture and stricter verdict gate.

## Observable acceptance

Extend the existing native failure skill and runner to guard buffer retirement,
retained references, collection, and the pure material cleanup queue. Product
sources and dependency revisions remain unchanged. No traditional tests or
replacement Vulkan implementation are introduced.

The production statements checked are `bv_validate_retirement`, the validation
and sealing continuation of `bv_retire_buffers`, `bv_may_reach_depth`,
`bv_sealed`, `bv_prepare_refs`, `bv_referenced`, `bv_complete`, successful command
reset, registry removal, and the metadata/control portions of
`bv_collect_retired`. Pure publication and cleanup claims use complete extracted
declarations from `scene-geometry.bend`, `scene-materials.bend`, and
`scene-texture.bend`.

Required properties:

1. Every failed paired retirement preserves all allocation flags. Successful
   retirement seals both buffer/memory pairs. Recording references, memory
   aliases, owner/binding errors, and prior staging errors reject before sealing.
2. Transitive descriptor/view/image/memory edges retain ownership. Sealed
   descendants prevent new recording. Reference staging either installs the
   complete deduplicated set or preserves the prior recorded list.
3. Collection preserves retained, unretired, and foreign allocations. It removes
   each eligible buffer before its memory and scans past removal of the next
   registry row. Lost-device refusal leaves the registry intact.
4. Retirement followed by collection, completion, and successful resets preserves
   allocations until the last recorded owner is released. Completion alone does
   not release recorded references.
5. Pure material collection retains every unprocessed resource suffix on cleanup
   refusal and preserves the active material list. Existing publication claims
   continue to preserve candidate state and all retirement-list contributions.

## Formal boundary and bounds

CBMC checks extracted production C. Retirement begins after handle/list decoding
and staging with at most two pairs. Graphs are finite, acyclic, explicitly linked
registry topologies with two commands, descriptor paths, allocated images, views,
buffers, and memory. The topology and loop bounds are recorded with the claims.
Selected phase, error, retirement, count, and reference choices are symbolic or
completely enumerated as documented; other fields are fixed by the topology.

Collection copies its control and registry mutation statements. The two void
Vulkan destruction calls form opaque effect boundaries: the proof observes their
arguments and assumes they do not mutate the wrapper's private registry. It does
not call or substitute a Vulkan function. Actual `bv_remove` and `free` execute in
the proof. Real Vulkan checks separately establish observed destruction and zero
live objects. Presentation, borrowed swapchain images, concurrent registry access,
arbitrary graphs, term decoding, and driver correctness remain outside this task.

Each new property family needs a deliberate production-source mutation that fails
its named assertion, followed by a restored pass. Parse errors, extraction errors,
unwind failures, crashes, and timeouts are failures of the gate, not sensitivity
evidence. Pure Bend claims remain frontend checks unless separately kernel checked.

## Required evidence

- Build and inspect `tools/verify-workflow.bend --plan native`.
- Run the `native` workflow profile against its retained source snapshot. This
  includes real mesh replacement, uniform/sampled retention, texture lifetime,
  allocation failure/rollback/retry, root/publication proofs, upload kernel,
  source controls, native proofs, new lifetime controls, and restored baselines.
- Run the dependency native-bundle generator consistency check.
- Validate the revised skill's frontmatter and follow its documented commands.
- Inspect the receipt, proof verdicts, named counterexamples, native output, and
  cleanup counts. Preserve the source-specific evidence path here on completion.

Runtime evidence for rollback and entry teardown remains distinct from formal
proofs of their pure decisions and bounded native lifetime transitions. The task
does not establish an unbounded theorem for every engine allocation.
