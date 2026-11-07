---
name: verify-native-failures
description: Verify production Vulkan failures and resource lifetime after changes to buffer retirement, reference graphs, collection, command recording/submission/reset/completion, descriptor cleanup, material retirement queues, or Entry.close. Use alongside verify-entangle for renderer lifecycle changes.
---

# Verify native failures and resource lifetime

Presentation ownership has a separate
[verify-presentation skill](../verify-presentation/SKILL.md). Use it for lease
serials, WSI completion, binary semaphore reuse, resize, and close. This skill's
existing scopes do not imply presentation verification.

Use the `native` profile in [the development workflow](../../../docs/development.md) for retirement, collection, replacement, or material lifetime changes. It retains the source snapshot and combines bounded C proofs, pure Bend publication/cleanup proofs, production mutations, and real Vulkan retention, texture, rollback/retry, and teardown checks. The narrower `native-failures` profile runs native proofs and mutations with real mesh/descriptor retention and resource-failure drivers. Preserve the evidence kinds and limits separately.

Run from the Entangle root. Read `AGENTS.md`, run `bend guide`, and read
[`proofs/native-failures/README.md`](../../../proofs/native-failures/README.md).
This checks C handler statements extracted from the production dependency,
with symbolic driver results. It never dispatches a replacement Vulkan driver.

```bash
mkdir -p build
bend tools/verify-workflow.bend -o build/verify-workflow
./build/verify-workflow --plan native
VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation \
VK_LAYER_VALIDATE_SYNC=1 ./build/verify-workflow native +RTS --threads 1 --gpu off
python3 deps/bend-vulkan/tools/generate.py --check
```

Require the Khronos validation layer to be installed. The texture driver sets
these variables itself; other native drivers inherit them. Retain the validation
environment with the runtime evidence and reject validation diagnostics.

For a focused iteration, build `tools/verify-native-failures.bend` and run
`./build/verify-native-failures --lifetime --mutations +RTS --threads 1 --gpu off`.
This selects the lifetime suite only. Omit `--lifetime` to check both suites.
Run `tools/verify-publication.bend --mutations` natively for the pure material
queue claims. Focused checks do not replace the selected workflow profile.

The formal runner installs pinned CBMC 6.9.0 into the ignored build directory
if absent. The archive SHA-256 is checked before extraction. It needs Linux
x86-64, Vulkan headers, curl, ar, tar, and sha256sum. No system installation
or elevated privilege is used. The default native gate includes the passing
proofs; `--mutations` additionally checks disposable broken production sources
and reruns the original source. It prints the directory containing generated
C, source hashes, proof logs, counterexamples, and exit statuses.
The dependency's existing Python 3 generator check also verifies that the
window bundle embeds the same native implementation.

The original eleven failure entries were synchronized against root commit
`94665a580af130b7d13ae1b29228eec14d032ccd` on November 7, 2026, and `deps/bend-vulkan` commit
`a144f7dd4fb4835ca3d5ce17350fc850de049038`.
Their outcome is **in sync**. The production dependency is unchanged since
the previous root sync, `71c16701a0bba33e9635624dfc916acfb87d9344`.
Every commit in `71c1670..94665a5` was reviewed. New texture/material lifetime
callers and hierarchy paths change no extracted C handler, assertion, or
bound. All positive proofs, all 18 production mutations, and the restored
proofs pass. The [maintenance record](../../../proofs/maintenance/2026-11-07/README.md)
lists the commits, runtime evidence, and limits. Their pure publication policy
and material cleanup queues have a separate
[frontend proof](../../../proofs/geometry-publication/README.md).
The authoritative function/region list is
[`handlers.in.c`](../../../proofs/native-failures/handlers.in.c).
It covers begin/end/reset return handling, submission and synced semaphore
ownership, sticky device loss, uncertain-operation guards, descriptor
free/reset quarantine, failed fence reset, failed idle/entry cleanup, and
completion retaining recorded edges. The exact claims and registry topology
are in [`claims.h`](../../../proofs/native-failures/claims.h).

The bounds are four scanned registry rows (three commands across two owners
and one resource), three dependency edges, one acquisition lease, all 32-bit
driver result patterns, and symbolic payload fields. Loop unwind assertions
are enabled. This is a bounded C proof, not an unbounded lifetime theorem or
a proof of the Vulkan driver. Read the detailed assumptions before extending
the claim. `LAWS.bend` remains the formal source for the pure Bend policies;
the native C properties require CBMC.

The lifetime extension is based on root `834e23d` and the same native dependency.
Its outcome is **in sync** for the retained working-tree snapshot
[`workflow-H51QSNBC`](../../../build/verification/workflow-H51QSNBC/manifest.tsv).
All 14 selected stages and the evidence audit pass, including both native
suites, all 41 native controls, restored sources, publication/cleanup controls,
and validation-enabled retention and resource-failure checks. The task record
separates the unchanged product checks from the earlier native snapshot.
Its nine logical entries (five property families) and production regions are in
[`lifetime.in.c`](../../../proofs/native-failures/lifetime.in.c) and
[`lifetime-claims.h`](../../../proofs/native-failures/lifetime-claims.h).
They cover atomic two-pair retirement, allocated sampled-resource ownership and
destruction refusal, atomic/deduplicated reference staging, collection, and
two-command completion/reset followed by final descriptor release. Each of four
collection orders checks all 64 combinations of retirement, retaining owners,
invalid owner, and device loss. The pending/uncertain sequences run separately.
The topology
has at most eight scanned rows and eight initial edges, with at most three
recorded references after staging. The global unwind bound is six; explicit
registry bounds allow eight rows (nine loop tests), staging/retirement bounds
allow two inputs, and completion keeps its three-edge/no-query-slot bounds.
Literal per-entry options are retained in `.argv` files. Allocation failure and memory-leak
checks are enabled for these entries. This does not extend the original
failure suite's four-row bound.

Collection observes two void native destruction boundaries and assumes those
calls do not mutate the wrapper's private registry. It runs the actual extracted
registry removal and `free` statements. No Vulkan entry point is replaced or
dispatched. Term decoding, the retirement staging allocator, borrowed swapchain
images, arbitrary graphs, and driver behavior are excluded. Review those
boundaries and the entry callers whenever the covered code changes.

The runner compiles each extracted source once with pinned `goto-cc` 6.9.0,
then runs CBMC against that retained GOTO file. The generated case entries select
the complete finite input space; they do not implement lifecycle transitions.
Require all 64 configuration statuses for every selected collection order,
alongside the other selected entry statuses and `run.status=0`.
No negative control may contain a failed unwind assertion, even if its named
ownership property also fails. Fixture teardown must consult the actual registry
after assertions, because CBMC continues through a violated assertion.

The [task record](../../../proofs/native-failures/lifetime-plan.md) records
acceptance, current verification state, and the source-specific receipt. Advance
the lifetime synchronization revision only after successful checks and source
correspondence review; keep the original failure-suite synchronization separate.

On failure, read the named assertion and its counterexample. A violated
ownership/error property in extracted production statements is a finding;
an invalid proof object, changed extraction marker, or insufficient unwind
bound is a harness issue. Do not weaken a property to make production pass.
Keep native checks intact and reproduce reachable cases through real Vulkan
when practical. Preserve the failing evidence.

When production changes, inspect the extracted region and the code around
each symbolic boundary. A missing marker must fail the run. Update boundary
bindings only when they still match the real native call and normalization.
Rerun every proof and the mutations, then the real-runtime gate. Advance the
sync commit only after this comparison. Use `/maintain-formal-verification-skill`
when changes were merged without rechecking these properties.
