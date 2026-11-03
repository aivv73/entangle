import Base
import ./spec.bend as V
import ../../deps/bend-vulkan/src/core.bend as Core
import ../../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W
import ../../deps/bend-vulkan/deps/bend-collections/proofs/lib/lemmas/spec/numeric.bend as Numeric

law universal:
  for +c:W.U64
  for +o:W.U64
  for +l:W.U64
  {Core.subrange_contains(c,o,l) == Bool.and(Nat.is_le(V.value(o),V.value(c)),Nat.is_le(Nat.add(V.value(o),V.value(l)),V.value(c))) : Bool}

law value_limbs:
  for +lo:U32
  for +hi:U32
  {V.value(W.U64{lo,hi}) == Nat.add(U32.to_nat(lo),Numeric.scale_binary(32n,U32.to_nat(hi))) : Nat}
