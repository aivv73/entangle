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

The [verification record](verification/2026-11-03-upload-range/README.md) records standard checks, the successful standalone kernel check, and a controlled mutation. No runtime changed, so this work adds no runtime tests.

Production integration remains open. Entangle's ordinary upload path must enforce the check using exact byte quantities before this theorem protects those uploads. Earlier U32 size arithmetic, ABI layout, alignment, synchronization, handle validity, and resource lifetime remain separate obligations. The standalone theorem passed `--verdict`; the root passed the standard check. Native compilation and production enforcement remain outside that result. See the verification record for exact commands and trust limits.
