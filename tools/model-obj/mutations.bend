import Base
import ./inventory.bend as Inventory
import ../image-decoder/common.bend as C
import ../image-decoder/mutations.bend as Edit

def failed(+name:String,+expected:String,result:U32 & (String & String)) -> IO(Unit):
  (+code,(out,err)) = result
  +output:String = out ++ err
  do IO<Unit>:
    C.require(U32.is_ne(code,0) && String.contains(output,expected),name ++ " mutation escaped or failed for another reason " ++ output)
    IO.print(name ++ " mutation detected by actual production decode, native status=" ++ U32.show(code) ++ ", expected observation=" ++ expected)

def extra_edit(extra:Bool,dest:String) -> IO(Unit):
  match extra:
    case False{}:IO.pure(Unit,Unit{})
    case True{}:Edit.replace(dest ++ "/src/model-obj.bend","case _,_:Fail{error(9,\"OBJ\",line,\"upstream name table lost selection\")}","case _,_:Done{Unit{}}")

def run(+name:String,before:String,after:String,extra:Bool,expected:String) -> IO(Unit):
  do IO<Unit>:
    +dest:String <- C.command("mktemp",["-d","build/model-obj/mutation-" ++ name ++ "-XXXXXXXX"])
    +dest:String = String.trim(dest)
    Inventory.copy(dest,List.append(&1,String,Inventory.sources(),["tools/model-obj/runtime.bend","tools/model-obj/reference.bend","tools/image-decoder/common.bend"]))
    Edit.replace(dest ++ "/src/model-obj.bend",before,after)
    extra_edit(extra,dest)
    _:String <- C.command("bend",[dest ++ "/tools/model-obj/runtime.bend","-o",dest ++ "/runtime"])
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(dest ++ "/runtime",["+RTS","--threads","1","--gpu","off"],"",1048576,60000))
    failed(name,expected,result)

def main() -> IO(Unit):
  do IO<Unit>:
    run("winding","c <> b <> a <> tail","a <> b <> c <> tail",False{},"complete sign source differs")
    run("raw-zero"," && U32.is_gt(value,0)","",False{},"f 0 2 3 accepted")
    run("material-fallback","case []:Fail{error(5,\"OBJ\",line,\"unresolved usemtl \" ++ name)}","case []:Done{Selected{4294967295,F.white()}}",True{},"usemtl missing accepted")
    run("unsupported-fields","case _,_:Fail{error(2,\"MTL\",line,\"unsupported property or field count\")}","case _,_:Done{head}",False{},"Ks 0 0 0 accepted")
    IO.print("Winding, raw-zero, silent material fallback and ignored unsupported MTL mutations each failed the native verifier as intended.")
