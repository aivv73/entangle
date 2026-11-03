import Base
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W

def byte_length(bytes:List<&2,U32>) -> Nat:
  List.length(&2,U32,bytes)

def transport(bytes:List<&2,U32>) -> List<U32>:
  match bytes:
    case []:[]
    case x <> rest:x <> transport(rest)

def encode(n:Nat) -> W.U64:
  W.of_u32(U32.from_nat(n))

def exact(+n:Nat) -> Bool:
  Nat.is_eq(U32.to_nat(U32.from_nat(n)),n)
