import Base
import ./LAWS.bend as Laws
import ./spec.bend as V
import ./bridge.bend as Bridge
import ./natural.bend as Natural
import ../../deps/bend-vulkan/src/core.bend as Core
import ../../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W
import ../../deps/bend-vulkan/deps/bend-collections/proofs/math/u64/u64.bend as P

def guarded(+guard:Bool,+c:W.U64,+o:W.U64,+l:W.U64,+h:{guard == Nat.is_le(V.value(o),V.value(c)) : Bool}) -> {Bool.and(guard,Bool.not(Core.size_less(W.add(c,W.neg(o)),l))) == Bool.and(guard,Nat.is_le(Nat.add(V.value(o),V.value(l)),V.value(c))) : Bool}:
  match guard:
    case False{}: {==}
    case True{}:
      Equal.trans(Bool,Bool.not(Core.size_less(W.add(c,W.neg(o)),l)),Nat.is_le(V.value(l),V.value(W.add(c,W.neg(o)))),Nat.is_le(Nat.add(V.value(o),V.value(l)),V.value(c)),Bridge.not_less(W.add(c,W.neg(o)),l),
        Equal.trans(Bool,Nat.is_le(V.value(l),V.value(W.add(c,W.neg(o)))),Nat.is_le(V.value(l),Nat.sub(V.value(c),V.value(o))),Nat.is_le(Nat.add(V.value(o),V.value(l)),V.value(c)),
          Equal.cong(Nat,Bool,n => Nat.is_le(V.value(l),n),V.value(W.add(c,W.neg(o))),Nat.sub(V.value(c),V.value(o)),Bridge.exact(c,o,Equal.sym(Bool,True{},Nat.is_le(V.value(o),V.value(c)),h))),
          Natural.bounded(V.value(c),V.value(o),V.value(l),Equal.sym(Bool,True{},Nat.is_le(V.value(o),V.value(c)),h))))

def Laws.universal(c,o,l):
  Equal.trans(Bool,Core.subrange_contains(c,o,l),Bool.and(Nat.is_le(V.value(o),V.value(c)),Bool.not(Core.size_less(W.add(c,W.neg(o)),l))),Bool.and(Nat.is_le(V.value(o),V.value(c)),Nat.is_le(Nat.add(V.value(o),V.value(l)),V.value(c))),
    Equal.cong(Bool,Bool,b => Bool.and(b,Bool.not(Core.size_less(W.add(c,W.neg(o)),l))),Bool.not(Core.size_less(c,o)),Nat.is_le(V.value(o),V.value(c)),Bridge.not_less(c,o)),
    guarded(Nat.is_le(V.value(o),V.value(c)),c,o,l,{==}))

def Laws.value_limbs(lo,hi):
  P.val_pack(lo,hi)
