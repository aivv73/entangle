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

Run `bend tools/verify.bend` for the default gate. It runs [`verify-upload-boundary.bend`](../tools/verify-upload-boundary.bend) before compiling renderers. Both the [production upload driver](../tools/verify-upload-runtime.bend) and the [standalone native driver](../tools/verify-upload-native-limit.bend) are mandatory real Vulkan checks.

The Bend source scanner enumerates every first-party `.bend` file, including untracked files and new directories. It excludes `.git`, `build`, `deps`, and historical `docs` evidence. Imports from scanned sources cannot enter an excluded directory unless the dependency module is explicitly approved. First-party symlinks outside the excluded directories are rejected. Each source must be smaller than 1 MiB, readable in full, and ASCII. Unsupported import forms fail closed. The scanner tokenizes comments, escaped strings, and character literals. It does not parse the whole language or replace Bend's compiler.

Imports resolve relative to the importing file, with lexical path normalization. Local aliases are checked against the canonical target. Bend aliases are local to their module and do not re-export nested aliases. Qualified dependency symbols, including function values, must appear in [`dependencies.txt`](../tools/upload-boundary/dependencies.txt). Approving a module does not approve all its exports. The dependency staging module is unapproved. The indexed-window dependency exposes only the reviewed target lifecycle operations used by this engine. Its geometry uploader is unapproved. Raw `write_memory` and `write_memory_words` identifier suffixes are reserved outside the trusted capsule, independent of alias spelling.

References to `scene-buffer` are limited to its documented functions and `Buffer` in conservative type-annotation positions. Constructor expressions and patterns, internal helpers, and helper function values are rejected. Some otherwise valid new type syntax may require an explicit scanner update. The error names the file and rejected symbol. First-party foreign-effect imports are rejected. The scanner checks the whole declared source scope, so an added wrapper cannot hide a forbidden operation one import away.

[`trusted.sha256`](../tools/upload-boundary/trusted.sha256) pins the complete buffer boundary, the pure size bridge, the existing native compatibility driver, and the standalone native upload verifier. The compatibility driver runs the dependency's standalone roundtrip demonstration. The native upload verifier creates, uses, and explicitly disposes its own buffer and allocation inside `run(entry)`. Only `run(entry) -> V.Action(Unit)` and `main() -> IO(Unit)` have resource arguments or results. There is no helper that accepts or returns a device, buffer, or allocation. An ordinary importer cannot provide engine memory or obtain the verifier's memory. Every source change requires full review and a new exact hash. No raw writer symbol is approved in the dependency manifest.

Dependency revisions and clean worktrees must match `toolchain.bend`. Published UI verification packages retain narrow symbol lists. The existing scalar `debug_u64_roundtrip` hook is approved separately. It accepts words and returns words without handles or mutation capability. The compiler, Base effects, package service, gate, and policy files remain trusted.

This is an ordinary repository API policy. Running `bend` directly on arbitrary code bypasses it. It does not sandbox arbitrary foreign code, subprocesses, a malicious editor changing the policy, or downstream direct Vulkan users. Such users retain responsibility for their own buffer extents.

After changing a trusted capsule, review its complete source, run proofs and real verification, then refresh its SHA256 entry. To inspect proposed dependency symbol changes, run `bend tools/upload-boundary/inventory.bend -o build/upload-inventory` and compare its sorted output with the reviewed manifest. The inventory reports observations only. It does not authorize them or update policy automatically. In particular, do not approve the raw writer symbols or standalone dependency roundtrip exports it observes in trusted exceptions.

Run `bend tools/verify-upload-mutations.bend -o build/verify-upload-mutations` after building `build/verify-upload-boundary`, then execute the resulting driver. It copies current sources to a fresh `build/verification/upload-mutations-*` directory. It requires rejection of ten existing bypass mutations and a change to the trusted native verifier, then requires a restored pass. Its dependency symlink uses the original pinned clean checkouts. Logs, statuses, and the restored copy remain as evidence. The real working source is never mutated. These structural enforcement checks are not substitute upload implementations.

## Runtime verification and limits

The production driver retains the seven-byte scenarios and compares all seven bytes after every rejected write. Empty reads and writes succeed at zero and capacity. Zero allocation and empty `upload_new` retain the original native nonzero-size error and leave the immediate live-object count unchanged. A maximum-U32 invalid byte after a valid prefix preserves the complete destination. Reads and writes reject U32-max, high-only, and U64-max offsets. Read counts include zero, one, and U32 max. These production range errors occur before native dispatch. Allocation padding and failed-upload cleanup remain checked.

Both drivers execute the actual native scalar U64 decoder and tuple encoder. Each compares low and high returned limbs for 12 boundary pairs, 64 walking-one values, and 64 walking-zero values. These cover zero, each maximum limb, U64 max, the 2^32 carry, sign bits, asymmetric reversed pairs, and alternating masks. This scalar roundtrip does not establish every Vulkan structure layout. It also cannot exclude mutually cancelling decoder and encoder errors. Reviewed pinned `src/native.c` defines decoding as `(uint64_t)hi << 32 | lo` and encoding as low word followed by high word. The standalone driver separately creates an unbound `BufferCreateInfo` with `W.U64{257,1}` and transfer-destination usage. Its distinct flattened fields are `[257,1,2]`. It requires memory size at least the requested size and a high limb of exactly one, then destroys the buffer without allocating 4 GiB. The available device reported requirements `W.U64{272,1}`. The upper bound distinguishes swapped fields on this device. It is not a universal Vulkan padding bound.

For `L=16777216`, each driver creates a real `L+2` destination with guard bytes at zero and `L+1`. Each writes exactly `L` bytes at offset one, reads exactly `L`, and consumes the readback while comparing every byte and exact list exhaustion. The expected byte is `(i xor (i / 256) xor (i / 65536)) & 255`. Payload generation occurs at each write call. No reusable expected payload copy is retained.

Both rejected `L+1` writes use the pattern XOR 255. Every proposed payload byte differs from the stored byte, so a partial write cannot hide behind identical content. The production driver requires the returned count to equal `L`. Its in-range `L+1` write must report the engine transport-limit error. Its in-range `L+1` read must report the native read-limit error. After each rejection, it checks all `L` payload bytes in 64 KiB chunks and both guards. This production write rejection does not exercise the native writer's limit branch.

The trusted standalone driver directly executes native exact-limit acceptance and native `L+1` writer rejection. The latter must report argument code `0x60000003` with `invalid memory, byte value, or copy length`. Native `L+1` reads must report limit code `0x60000005` with `read exceeds 16 MiB chunk limit`. Complete readback and both guards establish unchanged content. The standalone also checks invalid bytes after a valid prefix, native U64-max offsets with empty and nonempty operations, and U32-max read-count precedence. A zero native allocation must fail without changing the immediate live count. Both large scenarios restore live counts immediately after explicit disposal and finish with zero live objects after entry teardown.

The [ABI verification record](verification/2026-11-03-upload-abi/README.md) retains commands, selected logs, statuses, hashes, and limitations. Execution uses the pinned native lane, one CPU thread, GPU dispatch off, and the unchanged 300000 ms command deadline. Full linked byte lists and an exact-limit readback list remain necessary. Peak memory was not measured. No performance, other backend, device-loss, complete-ABI, or arbitrary foreign-code security claim follows from these checks. Dynamic replacement and broader resource lifetime remain open.

For rendering changes, also follow the [verify-entangle feature map](../.agents/skills/verify-entangle/features/README.md). Offscreen success alone does not establish native window presentation. Keep fresh logs, source and binary hashes, statuses, captures, replay results, validation diagnostics, and cleanup evidence under `build/verification`. Never overwrite historical records to report a new run.

## Design synthesis

The selected design keeps requested capacity with the handles in one engine-owned module. It uses the existing byte-list transport and the actual proven predicate. The other candidates contributed the returned byte count for diagnostics and conservative source-policy enforcement. A separate pure bridge makes the exact payload-length claims checkable without importing foreign effects into root proofs.

Dependency staging would require a submodule change, word-array conversion, cursor lifecycle, and a larger reviewed surface. Caller-side guards would spread capacity and length provenance across both renderers. A validated packet would remain forgeable because Bend has no private constructors. The chosen boundary instead recomputes size before every write and supplements its runtime check with a narrow reviewed source gate. Parallelism and GPU dispatch are unchanged.
