import Base
import ../image-decoder/common.bend as C
import ../image-decoder/mutations.bend as Edit
import ../verify-upload-mutations.bend as Files

def record(result:U32 & (String & String),+dest:String,+expected:String) -> IO(Unit):
  (code,pair) = result
  (out,err) = pair
  +code:U32 = code
  +log:String = out ++ err
  do IO<Unit>:
    Files.save(dest ++ "/runtime.log",log)
    Files.save(dest ++ "/runtime.status",U32.show(code) ++ "\n")
    C.require(U32.is_eq(code,1) && String.contains(log,expected),"Math sensitivity control failed for another reason " ++ log)
    IO.print("Mutation rejected by " ++ expected ++ ". Evidence " ++ dest)

def mutation(name:String,path:String,before:String,after:String,expected:String) -> IO(Unit):
  do IO<Unit>:
    raw:String <- C.command("mktemp",["-d","build/jonmath/mutation-" ++ name ++ "-XXXXXXXX"])
    +dest:String = String.trim(raw)
    _:String <- C.command("cp",["-R","--reflink=auto","src","tools","examples","deps",dest])
    _:String <- C.command("mkdir",["-p",dest ++ "/build/jonmath",dest ++ "/build/qualification"])
    _:String <- C.command("cp",["build/jonmath/adapter.bend","build/jonmath/qualify.bend",dest ++ "/build/jonmath/"])
    _:String <- C.command("cp",["-R","--reflink=auto","build/qualification/jonlib",dest ++ "/build/qualification/"])
    Edit.replace(dest ++ "/" ++ path,before,after)
    out:String <- C.command("bend",[dest ++ "/build/jonmath/qualify.bend","-o",dest ++ "/qualify"])
    Files.save(dest ++ "/build.log",out)
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(dest ++ "/qualify",["+RTS","--threads","1","--gpu","off"],"",1048576,120000))
    record(result,dest,expected)

def main() -> IO(Unit):
  do IO<Unit>:
    mutation("operand-order","build/jonmath/adapter.bend","J.Matrix.multiply(to_jon(right),to_jon(left))","J.Matrix.multiply(to_jon(left),to_jon(right))","adapted left-times-right order differs")
    mutation("projection-depth","src/creation.bend","+a : F32 = (far / (far - near) : F32)","+a : F32 = ((far + near) / (far - near) : F32)","Vulkan near plane must be z=0,w=1")
