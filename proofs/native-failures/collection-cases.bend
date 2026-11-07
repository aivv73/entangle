import Base

# Enumerate the entire six-bit input space for each registry order. These entry
# functions choose proof inputs only; the collection algorithm is extracted C.
def cases(left:Nat,+n:U32,+name:String,+first:String,+second:String) -> String:
  match left:
    case 0n:""
    case 1n+rest:
      "void " ++ name ++ "_case_" ++ U32.show(n) ++ "(void) {collection_case(" ++ first ++ "," ++ second ++ "," ++ U32.show(n) ++ ");}\n" ++
      cases(rest,U32.inc(n),name,first,second)

def wrappers() -> String:
  "\n" ++ cases(64n,0,"verify_lifetime_collection_00","false","false") ++
  cases(64n,0,"verify_lifetime_collection_01","false","true") ++
  cases(64n,0,"verify_lifetime_collection_10","true","false") ++
  cases(64n,0,"verify_lifetime_collection_11","true","true")
