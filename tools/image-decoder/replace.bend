import Base

def go(fuel:Nat,+text:String,+before:String,+after:String,hit:Bool) -> String:
  match fuel text hit:
    case 0n _ _:text
    case _ SNil{} _:""
    case 1n+p _ True{}:after ++ go(p,String.drop(text,String.length(before)),before,after,String.starts_with(String.drop(text,String.length(before)),before))
    case 1n+p SCon{h,t} False{}:SCon{h,go(p,t,before,after,String.starts_with(t,before))}

def all(+text:String,+before:String,after:String) -> String:
  go(String.length(text),text,before,after,String.starts_with(text,before))
