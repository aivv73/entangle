---
name: verify-presentation
description: Verify Vulkan acquisition leases, render and presentation completion, fence and binary semaphore reuse, and resize/close ownership with production-extracted CBMC sequences and live window evidence. Required before multiple frames in flight or asynchronous presentation.
---

# Verify presentation ownership

Run this alongside `verify-entangle` after changes to acquisition, borrowed
swapchain images, recording lease identity, synced submission, WSI fences,
semaphore states, presentation draining, target replacement, or Entry.close.
Use `verify-native-failures` as well when the resource graph or command lifetime
changes. Presentation has separate completion ownership from rendering.

Read [the development workflow](../../../docs/development.md), run `bend guide`,
and read the [coverage and boundaries](../../../proofs/presentation/README.md).
Run from the Entangle root:

```bash
mkdir -p build
bend tools/verify-workflow.bend -o build/verify-workflow
./build/verify-workflow --plan presentation
VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation \
VK_LAYER_VALIDATE_SYNC=1 ./build/verify-workflow presentation +RTS --threads 1 --gpu off
```

The profile requires root/publication proofs, source policy, live mesh window
controls with resize/restore/Close and replay, bundle consistency, presentation
proofs, native mutations, frontend ordering controls, and restored passes.
Window profiles also require the presentation suite. Missing window prerequisites
or an unexecuted required stage cannot produce a pass. The owned Xwayland recipe
and pixel/trace inspection requirements are in `verify-entangle`.

For a focused iteration:

```bash
bend tools/verify-presentation.bend -o build/verify-presentation
./build/verify-presentation --mutations +RTS --threads 1 --gpu off
```

Require every selected entry, native control, restored entry, frontend status,
and `run.status` to pass. Each native control must exit 10 with its named
assertion failure. Any failed unwind assertion rejects the control. A timeout,
parse error, or unrelated failure provides no sensitivity evidence.

The runner uses the existing checksum-pinned CBMC/goto-cc 6.9.0 adapter. It
extracts native statements fresh and retains generated C, GOTO objects, source
and tool hashes, literal arguments, counterexamples, and statuses. It does not
replace or dispatch a Vulkan driver. C assertions describe the foreign C
ownership claims; they are not BendTT verdicts or claims of hardware behavior.
The native bound has at most five scanned rows, one command, two images,
four lease slots (at most two active), three fences, and one binary semaphore.
It covers the documented call
sequences and symbolic native results, with initial metadata success as a
premise. The detailed graph and per-loop bounds are in the coverage reference.

## Interpret failures

A violated named property in unchanged extracted native code is a production
finding. Preserve its counterexample and describe the call sequence. A changed
marker, inadequate bound, invalid fixture, or wrong symbolic binding is a
harness issue. Fix the correspondence or oracle without weakening the contract.
Follow each symbolic boundary back to its production call and normalization.

Rendering completion must leave a rendered lease and a signaled binary
semaphore. Presentation completion releases the presentation lease and its
binary wait. Allocation failures preserve retry identity. Unknown results retain
ownership until completion is actually observed. Device loss has an explicit
terminal teardown exception and is not proof of successful completion.

## Maintain correspondence and prerequisites

The production sync base is root `9fc2eba1e9b4e811672f0a4ebc19eb8a7747db54`
and bend-vulkan `a144f7dd4fb4835ca3d5ce17350fc850de049038`.
The [task record](../../../proofs/presentation/plan.md) records the source-specific
verification state. The authoritative production-region list is
[`handlers.in.c`](../../../proofs/presentation/handlers.in.c); the assertions are
[`claims.h`](../../../proofs/presentation/claims.h). The renderer ordering check
reads `scene-window.bend:record`, `acquired`, and `close`, and
`scene-target.bend:wait` and `replace` on every run.

The outcome is **in sync** for the production base and recorded working-tree
proof hashes. The task record links the complete 12-stage workflow and final
token-field extension: 21 baseline/restored native entries, 35 production
controls, 18 frontend controls, and validation-enabled resize/Close and replay.
It also records the shared runner's 272 unchanged positive checks and the
source comparison supporting reuse of the unchanged runtime evidence.

Review all changed extracted helpers, surrounding validation, native call lines,
result normalization, and frontend operation ordering. Rerun the controls and
real-window profile before advancing the sync revision. Use
`/maintain-formal-verification-skill` for changes merged without this check.

Multiple frames in flight or asynchronous presentation must first extend these
proofs to the proposed ownership topology, completion orders, and reuse policy.
Require passing production controls and real resize/Close evidence for that
design before enabling it. The current two-lease sequences protect the existing
synchronous renderer; they do not certify arbitrary concurrent frames.
