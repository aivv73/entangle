import Base
import ../image-decoder/common.bend as C
import ../image-decoder/mutations.bend as Edit
import ../verify-upload-mutations.bend as Files

def rejected(+dest:String,result:U32 & (String & String)) -> IO(Unit):
  (+code,(out,err)) = result
  +log:String = out ++ err
  do IO<Unit>:
    Files.save(dest ++ "/mutation.log",log)
    Files.save(dest ++ "/mutation.status",U32.show(code))
    C.require(U32.is_eq(code,1) && String.contains(log,"Carried crystal must follow the actual ECS courier at x=-2,y=1"),"Consumer sensitivity failed for an unrelated reason " ++ log)

def main() -> IO(Unit):
  do IO<Unit>:
    raw:String <- C.command("mktemp",["-d","build/verification/consumer-mutation-XXXXXXXX"])
    +dest:String = String.trim(raw)
    _:String <- C.command("cp",["-R","--reflink=auto","src","tools","examples","assets","deps","toolchain.bend",dest])
    _:String <- C.command("mkdir",["-p",dest ++ "/build"])
    +before:String = "    case 1n State{x,z,Carrying{}}:pose((U32.to_f32(x) - 3.0 : F32),1.0,(U32.to_f32(z) - 3.0 : F32),0.3)"
    +after:String = "    case 1n State{x,z,Carrying{}}:pose((U32.to_f32(x) - 3.0 : F32),0.2,(U32.to_f32(z) - 3.0 : F32),0.3)"
    Edit.replace(dest ++ "/examples/courier-state.bend",before,after)
    built:String <- C.command("bend",[dest ++ "/tools/consumers/runtime.bend","-o",dest ++ "/build/runtime"])
    Files.save(dest ++ "/build.log",built)
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("env",["-C",dest,"./build/runtime","+RTS","--threads","1","--gpu","off"],"",1048576,120000))
    rejected(dest,result)
    Edit.replace(dest ++ "/examples/courier-state.bend",after,before)
    built:String <- C.command("bend",[dest ++ "/tools/consumers/runtime.bend","-o",dest ++ "/build/restored"])
    Files.save(dest ++ "/restored-build.log",built)
    output:String <- C.command("env",["-C",dest,"./build/restored","+RTS","--threads","1","--gpu","off"])
    Files.save(dest ++ "/restored.log",output)
    IO.print("Consumer source regression rejected at independent ECS coordinates; restored runtime passed. " ++ dest)
