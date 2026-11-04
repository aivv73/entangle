import Base
import ../image-decoder/common.bend as C
import ../image-decoder/mutations.bend as Edit
import ../verify-upload-mutations.bend as Files

def record(result:U32 & (String & String),+dest:String,+name:String,+expected:String) -> IO(Unit):
  (code,pair) = result
  (out,err) = pair
  +code:U32 = code
  +out:String = out
  +err:String = err
  do IO<Unit>:
    Files.save(dest ++ "/runtime.log",out ++ err)
    Files.save(dest ++ "/runtime.status",U32.show(code) ++ "\n")
    C.require(U32.is_eq(code,1) && String.contains(out ++ err,expected),name ++ " escaped or failed for another reason " ++ out ++ err)
    IO.print(name ++ " rejected by " ++ expected)

def mutation(+name:String,path:String,before:String,after:String,+expected:String) -> IO(Unit):
  do IO<Unit>:
    raw:String <- C.command("mktemp",["-d","build/json-scene/mutation-" ++ name ++ "-XXXXXXXX"])
    +dest:String = String.trim(raw)
    _:String <- C.command("cp",["-R","--reflink=auto","src","tools",dest])
    _:String <- C.command("mkdir",["-p",dest ++ "/deps"])
    _:String <- C.command("cp",["-R","--reflink=auto","deps/jonlib-obj","deps/jonlib-png",dest ++ "/deps/"])
    Edit.replace(dest ++ "/" ++ path,before,after)
    out:String <- C.command("bend",[dest ++ "/tools/json-scene/runtime.bend","-o",dest ++ "/runtime"])
    Files.save(dest ++ "/build.log",out)
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(dest ++ "/runtime",["+RTS","--threads","1","--gpu","off"],"",1048576,120000))
    record(result,dest,name,expected)

def main() -> IO(Unit):
  do IO<Unit>:
    mutation("duplicate","src/json-boundary.bend","J.parse.strict.unique.bytes","J.parse.strict.bytes","duplicate-root accepted")
    mutation("schema","src/json-boundary.bend","Fail{error(3,path,\"unknown field \" ++ B.to_string(key))}","Done{Unit{}}","unknown-field accepted")
    mutation("range","src/json-boundary.bend","1000000.0","2000000.0","range accepted")
    mutation("reference-kind","src/scene-file.bend","Fail{Json.error(5,path,\"image used as model \" ++ id)}","Done{Unit{}}","wrong-asset-kind wrong rejection")
    mutation("bytes","src/json-boundary.bend","65536n","65537n","bytes-over accepted")
    mutation("depth","src/json-boundary.bend","def depth_limit() -> U32:8","def depth_limit() -> U32:9","depth wrong rejection")
    IO.print("Six isolated production regressions rejected at the named boundary observations.")
