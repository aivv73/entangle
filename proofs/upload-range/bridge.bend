import Base
import ./spec.bend as V
import ./word.bend as Algebra
import ./natural.bend as Natural
import ../../deps/bend-vulkan/src/core.bend as Core
import ../../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W
import ../../deps/bend-vulkan/deps/bend-collections/spec/math/u64.bend as U
import ../../deps/bend-vulkan/deps/bend-collections/proofs/math/u64/u64.bend as P
import ../../deps/bend-vulkan/deps/bend-collections/proofs/lib/lemmas/spec/numeric.bend as N
import ../../deps/bend-vulkan/deps/bend-collections/proofs/lib/lemmas/proofs/word_comparison.bend as C
import ../../deps/bend-vulkan/deps/bend-collections/proofs/lib/lemmas/proofs/subtraction_bounds.bend as S

def cmp_adapter(+hi:Cmp,+lo:Cmp) -> {Bool.or(Cmp.is_lt(hi),Bool.and(Cmp.is_eq(hi),Cmp.is_lt(lo))) == Cmp.is_lt(W.order(hi,lo)) : Bool}:
  match hi:
    case LT{}: {==}
    case EQ{}: {==}
    case GT{}: {==}

def less(+a:W.U64,+b:W.U64) -> {Core.size_less(a,b) == Nat.is_lt(V.value(a),V.value(b)) : Bool}:
  match a b:
    case W.U64{+al,+ah} W.U64{+bl,+bh}:
      Equal.trans(Bool,Core.size_less(W.U64{al,ah},W.U64{bl,bh}),Cmp.is_lt(Word.cmp(64n,U.bits(W.U64{al,ah}),U.bits(W.U64{bl,bh}))),Nat.is_lt(V.value(W.U64{al,ah}),V.value(W.U64{bl,bh})),
        Equal.trans(Bool,Core.size_less(W.U64{al,ah},W.U64{bl,bh}),Cmp.is_lt(W.order(U32.cmp(ah,bh),U32.cmp(al,bl))),Cmp.is_lt(Word.cmp(64n,U.bits(W.U64{al,ah}),U.bits(W.U64{bl,bh}))),cmp_adapter(U32.cmp(ah,bh),U32.cmp(al,bl)),Equal.cong(Cmp,Bool,Cmp.is_lt,W.order(U32.cmp(ah,bh),U32.cmp(al,bl)),Word.cmp(64n,U.bits(W.U64{al,ah}),U.bits(W.U64{bl,bh})),Equal.sym(Cmp,Word.cmp(64n,U.bits(W.U64{al,ah}),U.bits(W.U64{bl,bh})),W.order(U32.cmp(ah,bh),U32.cmp(al,bl)),P.cmp_pack(al,ah,bl,bh)))),
        Equal.cong(Cmp,Bool,Cmp.is_lt,Word.cmp(64n,U.bits(W.U64{al,ah}),U.bits(W.U64{bl,bh})),Nat.cmp(V.value(W.U64{al,ah}),V.value(W.U64{bl,bh})),C.refines(64n,U.bits(W.U64{al,ah}),U.bits(W.U64{bl,bh}))))

def not_less(+a:W.U64,+b:W.U64) -> {Bool.not(Core.size_less(a,b)) == Nat.is_le(V.value(b),V.value(a)) : Bool}:
  Equal.trans(Bool,Bool.not(Core.size_less(a,b)),Bool.not(Nat.is_lt(V.value(a),V.value(b))),Nat.is_le(V.value(b),V.value(a)),Equal.cong(Bool,Bool,Bool.not,Core.size_less(a,b),Nat.is_lt(V.value(a),V.value(b)),less(a,b)),Natural.not_lt_le(V.value(a),V.value(b)))

def subtraction(+a:W.U64,+b:W.U64) -> {U.bits(W.add(a,W.neg(b))) == Word.sub(64n,U.bits(a),U.bits(b)) : Word(64n)}:
  Equal.trans(Word(64n),U.bits(W.add(a,W.neg(b))),Word.add(64n,U.bits(a),U.bits(W.neg(b))),Word.sub(64n,U.bits(a),U.bits(b)),P.add(a,W.neg(b)),
    Equal.trans(Word(64n),Word.add(64n,U.bits(a),U.bits(W.neg(b))),Word.add(64n,U.bits(a),Word.inc(64n,Word.not(64n,U.bits(b)))),Word.sub(64n,U.bits(a),U.bits(b)),Equal.cong(Word(64n),Word(64n),w => Word.add(64n,U.bits(a),w),U.bits(W.neg(b)),Word.inc(64n,Word.not(64n,U.bits(b))),P.neg(b)),Algebra.add_neg_sub(64n,U.bits(a),U.bits(b))))

def exact(+a:W.U64,+b:W.U64,h:{Nat.is_le(V.value(b),V.value(a)) == True{} : Bool}) -> {V.value(W.add(a,W.neg(b))) == Nat.sub(V.value(a),V.value(b)) : Nat}:
  Equal.trans(Nat,V.value(W.add(a,W.neg(b))),N.unsigned(64n,Word.sub(64n,U.bits(a),U.bits(b))),Nat.sub(V.value(a),V.value(b)),Equal.cong(Word(64n),Nat,w => N.unsigned(64n,w),U.bits(W.add(a,W.neg(b))),Word.sub(64n,U.bits(a),U.bits(b)),subtraction(a,b)),S.exact(64n,U.bits(a),U.bits(b),h))
