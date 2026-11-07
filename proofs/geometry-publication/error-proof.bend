import Base

# Literal U32 patterns lower to structural word matches. An excluded wildcard
# does not normalize a second match. Enumerate the 32 possible first differing
# bits, then eliminate the one excluded word. This covers every U32, not samples.
def cases(left:Nat,+index:Nat,+prefix:String,+close:String) -> String:
  match left:
    case 0n:
      "    case U32{" ++ prefix ++ "WNil{}" ++ close ++ "}:\n" ++
      "      Empty.absurd({Materials.collected(T.Pending{remaining,(1610612740,message)},(rest,status)) == (remaining <> rest,V.Entry.finish(Unit,Fail{(1610612740,message)},status)) : List<&2,List<&2,T.Resource>> & V.VkResult(Unit)},Logic.true_false(other))\n"
    case 1n+rest:
      +one:Bool = U32.is_ne(U32.and((1610612740 >> index : U32),1),0)
      +bit:String = Bool.pick(String,one,"True{}","False{}")
      other:String = Bool.pick(String,one,"False{}","True{}")
      "    case U32{" ++ prefix ++ "WCon{" ++ other ++ ",_}" ++ close ++ "}:{==}\n" ++
      cases(rest,1n+index,prefix ++ "WCon{" ++ bit ++ ",","}" ++ close)

def proof() -> String:
  "\ndef Laws.material_collection_failure(remaining,code,message,rest,status,other):\n  match code:\n" ++ cases(32n,0n,"","")
