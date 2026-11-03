import Base
import ../../src/error.bend as Error
import ../../deps/bend-vulkan/Vulkan.bend as V
import ../../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W

def rejected(result:V.VkResult(Unit),+code:U32,+expected:String) -> V.Action(Unit):
  match result:
    case Done{_}:Error.require(False{},"Expected rejection: " ++ expected)
    case Fail{(+actual,+message)}:
      Error.require(U32.is_eq(actual,code) && String.eq(message,expected),"Wrong rejection: " ++ U32.show(actual) ++ " " ++ message ++ "; expected " ++ U32.show(code) ++ " " ++ expected)

def read_rejected(result:V.VkResult(List<U32>),code:U32,expected:String) -> V.Action(Unit):
  rejected(Result.map(&1,&1,U32 & String,List<U32>,Unit,_ => Unit{},result),code,expected)

def abi_return(pair:U32 & U32,lo:U32,hi:U32) -> V.Action(Unit):
  (actual_lo,actual_hi) = pair
  do V.Action<Unit>:
    Error.require(U32.is_eq(lo,actual_lo),"Native U64 low limb differs")
    Error.require(U32.is_eq(hi,actual_hi),"Native U64 high limb differs")

def abi_pair(+value:W.U64) -> V.Action(Unit):
  W.U64{lo,hi} = value
  do V.Action<Unit>:
    pair:U32 & U32 <- V.debug_u64_roundtrip(value)
    abi_return(pair,lo,hi)

def abi_pairs(values:List<W.U64>) -> V.Action(Unit):
  match values:
    case []:V.Action.pure(Unit,Unit{})
    case value <> rest:
      do V.Action<Unit>:
        abi_pair(value)
        abi_pairs(rest)

def abi_bits(remaining:Nat,+bit:U32) -> V.Action(Unit):
  match remaining:
    case 0n:V.Action.pure(Unit,Unit{})
    case 1n+rest:
      do V.Action<Unit>:
        abi_pair(W.U64{bit,0})
        abi_pair(W.U64{0,bit})
        abi_pair(W.U64{U32.not(bit),4294967295})
        abi_pair(W.U64{4294967295,U32.not(bit)})
        abi_bits(rest,U32.shl(bit))

def abi() -> V.Action(Unit):
  do V.Action<Unit>:
    abi_pairs([W.U64{0,0},W.U64{4294967295,0},W.U64{0,4294967295},W.U64{4294967295,4294967295},W.U64{0,1},W.U64{2147483648,0},W.U64{0,2147483648},W.U64{2147483648,2147483648},W.U64{19088743,2309737967},W.U64{2309737967,19088743},W.U64{1431655765,2863311530},W.U64{2863311530,1431655765}])
    abi_bits(32n,1)
    V.Action.lift(Unit,IO.print("Native scalar U64 ABI verified: 12 boundary pairs, 64 walking-one and 64 walking-zero values; both returned limbs compared."))
