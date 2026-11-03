import Base
import ../../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W
import ../../deps/bend-vulkan/deps/bend-collections/spec/math/u64.bend as U
import ../../deps/bend-vulkan/deps/bend-collections/proofs/lib/lemmas/spec/numeric.bend as N

def value(a:W.U64) -> Nat:
  N.unsigned(64n,U.bits(a))
