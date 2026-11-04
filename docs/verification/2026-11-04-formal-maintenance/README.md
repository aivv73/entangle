# Formal verification maintenance

The audit compares verification with Entangle
`71c16701a0bba33e9635624dfc916acfb87d9344` on November 4, 2026.
All existing checks are **in sync**. No product bug, semantic drift, or
intentional change to a promise was found. No property or bound was weakened.
Product code, laws, proof terms, native harnesses, and dependency pins are
unchanged.

Work is tracked by the [maintenance trail](https://entire.com/et/bend-engine/-/trails/22).
The verification change adds a repeatable Bend mutation driver and records
coverage and synchronization in the project skills. There is no product fix
in this change.

## History examined

The native skill recorded root sync
`e0dfa4b4bd9ff548447382585931484cd66be511`. Neither Bend check recorded a sync
commit. This audit therefore used the last verification-file changes:
`ea6743da89c0eaf134287dee4e3b0832ce41a6d8` for root laws and
`8a93ddde63474da13779174e8a6542bb1ae228cc` for standalone upload proofs.

The audit read every commit message after the oldest baseline and inspected
covered-code diffs, dependency pins, handler extraction boundaries, and state
writers. The native dependency remains
`a144f7dd4fb4835ca3d5ce17350fc850de049038`, Bendvy remains
`16405fbeb75cd6da1eb8c79ea48d3532ee9a30ee`, and bend-collections remains
`bc78c4f4cabb536a2a1dd6e308b6a8f0afafda7c`.

| Commit | Effect on these checks |
| --- | --- |
| `47534e7e36c866670d3920f1e8eef6a21afd9fd1` | Integrates the upload predicate into production writes. The standalone predicate, theorem, and dependency are unchanged. Root verification uses the later baseline below. |
| `12081c2f9f0417eeb64ce179898a44b33ed331f1` | Model configuration. No covered-code change. |
| `57d1f4c04e2642d37a45dae31d59625c25e47f74` | Roadmap documentation. No covered-code change. |
| `62e432151d0ea3471c005a2291fd1ae9e826d4a5` | Upload runtime and ABI verification. No standalone theorem or dependency change. |
| `d258fe351058361ec78c61492518563177dd5f46` | Dependency research documentation. No covered-code change. |
| `ea6743da89c0eaf134287dee4e3b0832ce41a6d8` | Root fallback baseline, including pure geometry laws. Native retirement is outside those laws. No standalone theorem change. |
| `b9ca65622018613de994014cd38354529a3e879e` | Moves the diagnostic span after command reset and before collection. The reset/collection sequence and all terms described by root laws are unchanged. |
| `bb565d105e86e72a228afd02bd2aeb267ec1660c` | Adds real buffer-retention verification. No engine or dependency change. |
| `e0dfa4b4bd9ff548447382585931484cd66be511` | Adds real resource-failure verification. Recorded native sync baseline. |
| `5ef97bbdcf4302170e128c43b943a260a9d4639a` | Adds the native proof skill, extraction, claims, and mutation controls. No production change. |
| `71c16701a0bba33e9635624dfc916acfb87d9344` | Adds sampled-image retention verification. No production change or new production state writer. |

Thus, root coverage examines `ea6743d..71c1670`, native coverage examines
`e0dfa4b..71c1670`, and standalone upload coverage examines
`8a93ddd..71c1670`. None of these histories changes a covered promise. There
is no old/new property wording to reconcile and no moved covered function.

## Results and sensitivity

Both Bend checks passed before editing verification. All eleven native
entries passed before editing their skill, including 18 mutations and a full
restored-source run. The table lists a negative control for each check;
the native manifest contains the complete set of 18.

| Check | Outcome | Deliberate break caught |
| --- | --- | --- |
| Root `PROOF.bend`, 95 laws | In sync; frontend pass | Rejected geometry installs the candidate; clock high-water sample regresses; byte transport drops payload bytes. Each fails at its named law. |
| Standalone upload `PROOF.bend --verdict` | In sync; kernel pass | Remove the production offset guard. The unchanged `Laws.universal` proof fails. |
| `verify_device_loss` | In sync; CBMC pass | Revive a lost device, retain stale submission storage, or invalidate another owner's command. |
| `verify_record_reset_failure` | In sync; CBMC pass | Drop recorded edges on reset failure, or leave begin/end failure in a usable phase. |
| `verify_submit_result` | In sync; CBMC pass | Treat unknown submission outcome as executable instead of uncertain. |
| `verify_synced_submission` | In sync; CBMC pass | Drop staged semaphore edges for uncertain submission. |
| `verify_uncertain_guards` | In sync; CBMC pass | Allow uncertain command reset or another submission on the uncertain device. |
| `verify_lost_guards` | In sync; CBMC pass | Return success from a lost-device command-reset guard. |
| `verify_descriptor_failure` | In sync; CBMC pass | Skip quarantine after free/reset failure or bypass its later free guard. |
| `verify_fence_reset_failure` | In sync; CBMC pass | Swallow the native fence-reset error. |
| `verify_idle_failure` | In sync; CBMC pass | Swallow unresolved completion failure during entry cleanup. |
| `verify_completion` | In sync; CBMC pass | Release recorded ownership during completion. |
| `verify_idle_success` | In sync; CBMC pass | Skip completion of active work after successful idle. |

The four Bend controls change copied production definitions while retaining
the original laws and proof terms. Each requires exit one and the expected
`Location: Laws.<name>`. Baseline and restored checks pass. Native controls
require CBMC exit ten and the expected failed assertion. Missing markers,
parser errors, timeouts, and unrelated failures do not satisfy these controls.
The deliberate breaks remain as evidence in disposable copies, never in the
production checkout.

No passing old description became a failing current description. Expected
mutation failures demonstrate sensitivity; they are neither verification
drift nor bugs in the current product. There is no product counterexample or
introducing bug commit to report.

## Verification changes

- `tools/verify-law-mutations.bend` and `proofs/law-mutations.tsv` make the
  previously manual upload mutation and three root-law controls repeatable.
  They run actual proof commands against copied production code.
- `verify-entangle/features/formal-laws.md` records code coverage, assumptions,
  exact commands, mutation expectations, and the previously missing sync
  commit. The skill and feature index link this entry.
- `verify-native-failures/SKILL.md` advances all eleven entries from
  `e0dfa4b` to `71c1670`, records the intervening verification-only changes,
  and distinguishes new sampled-image runtime evidence from CBMC coverage.

These are verification maintenance and missing-record corrections. They do
not change a model to compensate for a product failure.

## Reproduction and evidence

Follow [the Bend law recipe](../../../.agents/skills/verify-entangle/features/formal-laws.md)
and [the native failure skill](../../../.agents/skills/verify-native-failures/SKILL.md).
The maintenance run uses Bend 2.0.39, Clang 23.1.4, and CBMC 6.9.0.

Evidence is retained under
`build/verification/formal-maintenance-wOunZJVp`. It contains the revision,
dependency pins, source hashes, commit messages, covered-code diffs, logs,
and final command statuses. Baseline native evidence is
`build/verification/native-formal-zOCib86I`. Initial Bend mutation evidence is
`build/verification/law-mutations-Vzn0RKHs`. The final run logs identify their
fresh evidence directories.

The updated recipes completed successfully from the repository root.
`commands-after.log` records the commands. Every top-level stage status and
`run.status` is zero. Root proofs, the upload kernel verdict, all eleven
native entries, all 18 native mutations, and all four Bend mutations passed
their final checks. Restored sources passed again. Final Bend mutation
evidence is `build/verification/law-mutations-1Zlt9rFS`.

The native gate also runs real Vulkan upload/readback,
offscreen rendering, buffer and sampled-image retention, resource failures,
and headless checks with validation enabled. Final outcomes are recorded
in `run.status` and each stage's `.status` file.

The full native gate exited zero with no `Validation Error`, `SYNC-HAZARD`,
or `VUID-` diagnostics. Rendering, retention, rollback, and terminal teardown
reported zero live Vulkan objects. Real allocation pressure produced
`vkAllocateMemory: VkResult -2`; the driver restored its process limit,
preserved the original resident, and successfully allocated and uploaded
again. This is actual runtime failure evidence, separate from symbolic
driver-result proofs. The final native mutation run is retained in
`build/verification/native-formal-7fuY2cPy`.

## Coverage limits

The root result is a frontend check, not a root-wide BendTT kernel verdict.
The upload theorem has a kernel verdict over every U64 triple. That verdict
does not prove native ABI conversion, code generation, or driver correctness.
The four root/upload controls do not establish mutation coverage for every
root law.

Native bounds remain four linked registry rows, three dependency edges, one
lease, all 32-bit driver-result patterns, and symbolic payloads. The global
unwind is six, with the documented tighter completion/idle bounds and
unwinding assertions. The topology has no query pools or swapchain rows.
The proof does not cover arbitrary graphs, concurrency, presentation, full
entry teardown, handle decoding, Bend result tags, or foreign allocation.

New sampled-image verification in `71c1670` exercises real descriptor
ownership. It adds no general theorem for descriptor graphs or native
retirement. Other unverified paths remain unchanged: full UI behavior,
other devices/backends, and recovery from hardware device loss. No live
window session or performance benchmark is claimed by this maintenance run.
