import Base
import ./image-decoder/common.bend as C
import ./verify-upload-mutations.bend as Files

def recorded(+name:String,value:U32 & (String & String)) -> IO(Unit):
  (code,pair) = value
  (out,err) = pair
  +out:String = out
  +err:String = err
  do IO<Unit>:
    Files.save("build/hierarchy/" ++ name ++ ".log",out ++ err)
    IO.write(out)
    C.require(U32.is_zero(code),err)

def run(+name:String,args:List<String>) -> IO(Unit):
  do IO<Unit>:
    IO.print("Hierarchy stage: " ++ name)
    out:String <- C.command("bend",["tools/hierarchy/" ++ name ++ ".bend","-o","build/hierarchy/" ++ name])
    IO.write(out)
    value:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("build/hierarchy/" ++ name,List.append(&1,String,args,["+RTS","--threads","1","--gpu","off"]),"",16777216,3600000))
    recorded(name,value)

def main() -> IO(Unit):
  do IO<Unit>:
    _:String <- C.command("mkdir",["-p","build/hierarchy"])
    run("runtime",[])
    run("replay",["build/hierarchy/runtime.log"])
    run("render",[])
    run("mutations",[])
