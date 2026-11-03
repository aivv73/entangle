import Base
import ../../deps/bend-vulkan/deps/bend-collections/proofs/lib/nat.bend as N

def not_lt_le(+a:Nat,+b:Nat) -> {Bool.not(Nat.is_lt(a,b)) == Nat.is_le(b,a) : Bool}:
  match a b:
    case 0n 0n: {==}
    case 0n 1n+q: {==}
    case 1n+p 0n: {==}
    case 1n+p 1n+q: not_lt_le(p,q)

def cancel(+a:Nat,+b:Nat,+c:Nat) -> {Nat.is_le(Nat.add(a,b),Nat.add(a,c)) == Nat.is_le(b,c) : Bool}:
  match a:
    case 0n: {==}
    case 1n+p: cancel(p,b,c)

def bounded(+c:Nat,+o:Nat,+l:Nat,h:{Nat.is_le(o,c) == True{} : Bool}) -> {Nat.is_le(l,Nat.sub(c,o)) == Nat.is_le(Nat.add(o,l),c) : Bool}:
  Equal.trans(Bool,Nat.is_le(l,Nat.sub(c,o)),Nat.is_le(Nat.add(o,l),Nat.add(o,Nat.sub(c,o))),Nat.is_le(Nat.add(o,l),c),
    Equal.sym(Bool,Nat.is_le(Nat.add(o,l),Nat.add(o,Nat.sub(c,o))),Nat.is_le(l,Nat.sub(c,o)),cancel(o,l,Nat.sub(c,o))),
    Equal.cong(Nat,Bool,n => Nat.is_le(Nat.add(o,l),n),Nat.add(o,Nat.sub(c,o)),c,N.sub_add(c,o,h)))
