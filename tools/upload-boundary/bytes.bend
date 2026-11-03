import Base

def limit() -> U32:16777216

def byte_at(+index:U32) -> U32:
  U32.and(U32.xor(index,U32.xor(U32.div(index,256),U32.div(index,65536))),255)

def payload(a:Quant,remaining:Nat,+index:U32,+mask:U32) -> List<a,U32>:
  match remaining:
    case 0n:[]
    case 1n+rest:U32.xor(byte_at(index),mask) <> payload(a,rest,U32.inc(index),mask)

def matches(bytes:List<U32>,remaining:Nat,+index:U32) -> Bool:
  match bytes remaining:
    case Nil{} 0n:True{}
    case value <> rest 1n+left:U32.is_eq(value,byte_at(index)) && matches(rest,left,U32.inc(index))
    case _ _:False{}

def same(bytes:List<U32>,expected:List<U32>) -> Bool:
  match bytes expected:
    case Nil{} Nil{}:True{}
    case a <> rest b <> tail:U32.is_eq(a,b) && same(rest,tail)
    case _ _:False{}
