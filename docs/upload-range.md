# Universal upload-range containment

The root `upload_range_universal` law proves the following Boolean equality for every triple of production `W.U64` values:

```text
Core.subrange_contains(c,o,l)
  == Bool.and(V(o) <= V(c), V(o) + V(l) <= V(c))
```

Addition and comparison on the right use unbounded natural numbers. There is no offset-bound or no-overflow premise. The theorem references the actual implementation in `deps/bend-vulkan/src/core.bend`.

`V(a)` is `numeric.unsigned(64n, spec/math/u64.bits(a))`. The standalone `value_limbs` law proves `V(W.U64{lo,hi}) = U32.to_nat(lo) + scale_binary(32n,U32.to_nat(hi))` through the existing `val_pack` theorem. `scale_binary(0n,x) = x` and `scale_binary(1n+n,x) = Nat.double(scale_binary(n,x))`, so the second term is exactly `2^32 * U32.to_nat(hi)`. This interpretation includes all limb bit patterns without signed interpretation or sentinel handling.

The proof modules are in [`proofs/upload-range`](../proofs/upload-range/PROOF.bend):

- `word.bend` derives negation as subtraction from zero and derives addition of a negated word as subtraction. It uses existing modular increment, complement, associativity, subtraction cancellation, zero, and Base commutativity proofs.
- `natural.bend` proves the Boolean comparison complement and cancellation of a common addition prefix. With `o <= c`, it derives `l <= c - o` exactly when `o + l <= c`.
- `bridge.bend` connects production unsigned comparisons and wrapping arithmetic to words and natural values. The existing `subtraction_bounds.exact` establishes exact subtraction under the first bound.
- `PROOF.bend` splits on the first bound with an equality witness. A false bound rejects independently of the wrapped difference. A true bound permits exact subtraction and natural-number cancellation.

The equivalence covers empty ranges, maximum values, and machine sums that would overflow. It proves numeric containment of the half-open byte range. It does not depend on scene sizes or short-circuit evaluation.

The design comparison selected the existing generic word algebra as its base. A separate review replaced the proposed commutativity helper with Base's existing `Word.add_comm`. The final proof retains the unsigned-comparison and natural-number containment steps shared by the other designs. A fresh ripple-carry induction and a separate modular carry-accounting proof were rejected because the existing algebra and exact-subtraction theorem cover those obligations.

The [original verification record](verification/2026-11-03-upload-range/README.md) describes the theorem before production integration. Its historical evidence is unchanged.

## Production buffer boundary

Both renderers now upload through [`scene-buffer.bend`](../src/scene-buffer.bend). Its `Buffer` stores Vulkan handles and the exact requested `W.U64` capacity. `allocate` uses the same capacity in `V.BufferCreateInfo` and the returned buffer. Vulkan memory requirements may be larger. They do not enlarge the requested capacity.

`write(device,buffer,offset,bytes)` derives length from the actual reusable byte list. One U32 element carries one byte. The path rejects lengths above 16777216 before U32 conversion and checks the conversion round trip. It then calls the unchanged `Core.subrange_contains` before selecting the sole raw writer action. Both the predicate and dispatch are in the same body. There is no public Boolean switch, memory accessor, caller-supplied length, or unchecked write helper. A successful write returns the exact U32 byte count.

Bend requires `match` to head a definition body. The writer therefore uses `Bool.pick` to choose an IO action after obtaining the checked length. Constructing an IO action does not execute it. Only the selected action runs. Rejection never dispatches the native writer, including for an empty list beyond capacity. An empty list at capacity succeeds. Native byte-value validation still runs before mapping and writing.

Both geometry paths allocate from serialized payload lengths. They no longer multiply truncated U32 vertex or index counts. Window diagnostics use the writer's returned count directly, with the existing host-write timing scope. `payload_size` still counts push-constant words and is unrelated to upload bytes. Barriers, binds, and copies use `handle`. Readback uses the checked `read` operation. Cleanup of resources acquired within the new boundary preserves the primary error, even if cleanup also fails. Device and entry ownership still govern renderer teardown.

The pure [`upload-size.bend`](../src/upload-size.bend) bridge keeps foreign effects out of the proof import closure. `upload_transport_length` proves that adapting the reusable list to the native transport preserves length. `upload_conversion_exact` proves that the checked round trip implies the U64 interpretation equals the original natural length. The runtime checks that premise rather than relying on an additional large closed-bound theorem. The universal range theorem is unchanged.

These are numeric and structural claims. They do not prove Vulkan IO semantics, allocation provenance, lifetime, synchronization, ABI layout, or geometry correctness. Those depend on reviewed source and real execution.

## Enforced repository API

Run `bend tools/verify.bend` for the default gate. It compiles and runs [`verify-upload-boundary.bend`](../tools/verify-upload-boundary.bend) before compiling renderers, and runs [`verify-upload-runtime.bend`](../tools/verify-upload-runtime.bend) against actual Vulkan resources.

The Bend source scanner enumerates every first-party `.bend` file, including untracked files and new directories. It excludes `.git`, `build`, `deps`, and historical `docs` evidence. Imports from scanned sources cannot enter an excluded directory unless the dependency module is explicitly approved. First-party symlinks outside the excluded directories are rejected. Each source must be smaller than 1 MiB, readable in full, and ASCII. Unsupported import forms fail closed. The scanner tokenizes comments, escaped strings, and character literals. It does not parse the whole language or replace Bend's compiler.

Imports resolve relative to the importing file, with lexical path normalization. Local aliases are checked against the canonical target. Bend aliases are local to their module and do not re-export nested aliases. Qualified dependency symbols, including function values, must appear in [`dependencies.txt`](../tools/upload-boundary/dependencies.txt). Approving a module does not approve all its exports. The dependency staging module is unapproved. The indexed-window dependency exposes only the reviewed target lifecycle operations used by this engine. Its geometry uploader is unapproved. Raw `write_memory` and `write_memory_words` identifier suffixes are reserved outside the trusted capsule, independent of alias spelling.

References to `scene-buffer` are limited to its documented functions and `Buffer` in conservative type-annotation positions. Constructor expressions and patterns, internal helpers, and helper function values are rejected. Some otherwise valid new type syntax may require an explicit scanner update. The error names the file and rejected symbol. First-party foreign-effect imports are rejected. The scanner checks the whole declared source scope, so an added wrapper cannot hide a forbidden operation one import away.

[`trusted.sha256`](../tools/upload-boundary/trusted.sha256) pins the complete buffer boundary, the pure size bridge, and the existing native compatibility driver. The compatibility driver is a reviewed exception that runs the dependency's standalone roundtrip demonstration. It cannot supply buffers or memory to the engine. Dependency revisions and clean worktrees must match `toolchain.bend`. Published UI verification packages are approved by their existing versioned paths and narrow symbol lists. The compiler, Base effects, package service, gate, and policy files remain trusted.

This is an ordinary repository API policy. Running `bend` directly on arbitrary code bypasses it. It does not sandbox arbitrary foreign code, subprocesses, a malicious editor changing the policy, or downstream direct Vulkan users. Such users retain responsibility for their own buffer extents.

After changing a trusted capsule, review its complete source, run proofs and real verification, then refresh its SHA256 entry. To inspect proposed dependency symbol changes, run `bend tools/upload-boundary/inventory.bend -o build/upload-inventory` and compare its sorted output with the reviewed manifest. The inventory reports observations only. It does not authorize them or update policy automatically. In particular, do not approve the raw writer symbols or standalone dependency roundtrip exports it observes in trusted exceptions.

Run `bend tools/verify-upload-mutations.bend -o build/verify-upload-mutations` after building `build/verify-upload-boundary`, then execute the resulting driver. It copies current sources to a fresh `build/verification/upload-mutations-*` directory, introduces isolated source-policy violations, requires rejection, restores them, and requires a final pass. Its dependency symlink uses the original pinned clean checkouts. Logs, statuses, and the restored copy remain as evidence. The real working source is never mutated. These structural enforcement checks are not substitute upload implementations.

## Runtime verification and limits

The production runtime driver allocates a seven-byte buffer, writes real bytes at zero and at a nonzero offset ending at capacity, and accepts the empty endpoint. It rejects crossing, nonempty endpoint, beyond-capacity empty and nonempty ranges, maximum-U64 offsets, and a native invalid byte. After every rejection it reads the destination through the production API and compares all seven bytes. A rejected `upload_new` must preserve the native byte error and restore the live-object count before entry teardown. The driver also reports whether the actual memory requirement exceeds requested capacity and requires zero live Vulkan objects after scoped cleanup.

The driver intentionally does not construct a 16 MiB linked byte list or execute the exact-limit and limit-plus-one transfers. Those cases have substantial transport and natural-number traversal cost. The source capsule enforces the same 16777216 cap as the pinned native writer, and the conversion proof is general. Exact-limit native execution remains an explicit verification gap. No performance, other backend, device-loss, or arbitrary foreign-code security claim follows from these checks.

For rendering changes, also follow the [verify-entangle feature map](../.agents/skills/verify-entangle/features/README.md). Offscreen success alone does not establish native window presentation. Keep fresh logs, source and binary hashes, statuses, captures, replay results, validation diagnostics, and cleanup evidence under `build/verification`. Never overwrite historical records to report a new run.

## Design synthesis

The selected design keeps requested capacity with the handles in one engine-owned module. It uses the existing byte-list transport and the actual proven predicate. The other candidates contributed the returned byte count for diagnostics and conservative source-policy enforcement. A separate pure bridge makes the exact payload-length claims checkable without importing foreign effects into root proofs.

Dependency staging would require a submodule change, word-array conversion, cursor lifecycle, and a larger reviewed surface. Caller-side guards would spread capacity and length provenance across both renderers. A validated packet would remain forgeable because Bend has no private constructors. The chosen boundary instead recomputes size before every write and supplements its runtime check with a narrow reviewed source gate. Parallelism and GPU dispatch are unchanged.
