---
name: verify-native-failures
description: Verify production Vulkan failure handlers after changes to native command recording, submission, device health, reset, completion, descriptor cleanup, or Entry.close. Use alongside verify-entangle for resource lifecycle changes.
---

# Verify native failure handlers

Run from the Entangle root. Read `AGENTS.md`, run `bend guide`, and read
[`proofs/native-failures/README.md`](../../../proofs/native-failures/README.md).
This checks C handler statements extracted from the production dependency,
with symbolic driver results. It never dispatches a replacement Vulkan driver.

```bash
python3 deps/bend-vulkan/tools/generate.py --check
bend tools/verify-native-failures.bend -o build/verify-native-failures
./build/verify-native-failures --mutations +RTS --threads 1 --gpu off
bend PROOF.bend
bend tools/verify.bend -o build/verify
./build/verify +RTS --threads 1 --gpu off
```

The formal runner installs pinned CBMC 6.9.0 into the ignored build directory
if absent. The archive SHA-256 is checked before extraction. It needs Linux
x86-64, Vulkan headers, curl, ar, tar, and sha256sum. No system installation
or elevated privilege is used. The default native gate includes the passing
proofs; `--mutations` additionally checks disposable broken production sources
and reruns the original source. It prints the directory containing generated
C, source hashes, proof logs, counterexamples, and exit statuses.
The dependency's existing Python 3 generator check also verifies that the
window bundle embeds the same native implementation.

Coverage was synchronized against root commit
`e0dfa4b` and `deps/bend-vulkan` commit
`a144f7dd4fb4835ca3d5ce17350fc850de049038`.
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
