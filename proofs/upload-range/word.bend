import Base
import ../../deps/bend-vulkan/deps/bend-collections/proofs/lib/u32alg.bend as A
import ../../deps/bend-vulkan/deps/bend-collections/proofs/lib/lemmas/proofs/modular_addition.bend as M
import ../../deps/bend-vulkan/deps/bend-collections/proofs/lib/lemmas/proofs/word_subtraction.bend as S
import ../../deps/bend-vulkan/deps/bend-collections/proofs/lib/lemmas/spec/numeric.bend as N

def neg_as_sub_zero(+n:Nat,+b:Word(n)) -> {Word.inc(n,Word.not(n,b)) == Word.sub(n,Word.zero(n),b) : Word(n)}:
  %Equal.sym(Word(n),Word.sub(n,Word.zero(n),b),N.from_nat(n,1n+Nat.add(N.unsigned(n,Word.zero(n)),N.unsigned(n,Word.not(n,b)))),S.complement_form(n,Word.zero(n),b)) : {Word.inc(n,Word.not(n,b)) == _ : Word(n)}
  %Equal.sym(Nat,A.uw(n,Word.zero(n)),0n,A.uw_zero(n)) : {Word.inc(n,Word.not(n,b)) == N.from_nat(n,1n+Nat.add(_,N.unsigned(n,Word.not(n,b)))) : Word(n)}
  M.increment_refines(n,Word.not(n,b))

def add_neg_sub(+n:Nat,+a:Word(n),+b:Word(n)) -> {Word.add(n,a,Word.inc(n,Word.not(n,b))) == Word.sub(n,a,b) : Word(n)}:
  +d = Word.sub(n,a,b)
  +z = Word.zero(n)
  +nb = Word.sub(n,z,b)
  Equal.trans(Word(n),Word.add(n,a,Word.inc(n,Word.not(n,b))),Word.add(n,a,nb),d,
    Equal.cong(Word(n),Word(n),w => Word.add(n,a,w),Word.inc(n,Word.not(n,b)),nb,neg_as_sub_zero(n,b)),
    Equal.trans(Word(n),Word.add(n,a,nb),Word.add(n,Word.add(n,d,b),nb),d,
      Equal.cong(Word(n),Word(n),w => Word.add(n,w,nb),a,Word.add(n,d,b),Equal.sym(Word(n),Word.add(n,d,b),a,A.w_sub_add(n,a,b))),
      Equal.trans(Word(n),Word.add(n,Word.add(n,d,b),nb),Word.add(n,d,Word.add(n,b,nb)),d,A.w_assoc(n,d,b,nb),
        Equal.trans(Word(n),Word.add(n,d,Word.add(n,b,nb)),Word.add(n,d,z),d,
          Equal.cong(Word(n),Word(n),w => Word.add(n,d,w),Word.add(n,b,nb),z,
            Equal.trans(Word(n),Word.add(n,b,nb),Word.add(n,nb,b),z,Word.add_comm(n,b,nb),A.w_sub_add(n,z,b))),
          Equal.trans(Word(n),Word.add(n,d,z),Word.add(n,z,d),d,Word.add_comm(n,d,z),A.w_zero_add(n,d))))))
