import Base
import ./image-decoder/common.bend as C
import ./verify-upload-mutations.bend as Files

def recorded(+label:String,result:U32 & (String & String)) -> IO(Unit):
  (code,pair) = result
  (out,err) = pair
  +code:U32 = code
  +out:String = out
  +err:String = err
  do IO<Unit>:
    Files.save("build/jonmath/" ++ label ++ ".log",out)
    Files.save("build/jonmath/" ++ label ++ ".stderr",err)
    Files.save("build/jonmath/" ++ label ++ ".status",U32.show(code) ++ "\n")
    IO.write(out)
    IO.write(err)
    C.require(U32.is_zero(code),label ++ " failed")
    C.require(Bool.not(String.contains(out ++ err,"Validation Error") || String.contains(out ++ err,"SYNC-HAZARD") || String.contains(out ++ err,"VUID-")),label ++ " validation failed")

def run(+label:String,+program:String,args:List<String>) -> IO(Unit):
  do IO<Unit>:
    IO.print(label)
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(program,args,"",16777216,300000))
    recorded(label,result)

def retained(+label:String,suffixes:List<&2,String>) -> IO(Unit):
  match suffixes:
    case []:IO.pure(Unit,Unit{})
    case +suffix <> rest:
      do IO<Unit>:
        root:String = Bool.pick(String,String.eq(suffix,".packed.txt"),"docs/verification/2026-11-07-bend-2.0.40/baseline-2.0.39/","docs/verification/2026-11-04-model-obj/")
        run("retained-" ++ label ++ suffix,"cmp",[root ++ label ++ suffix,"build/model-obj/" ++ label ++ suffix])
        retained(label,rest)

def main() -> IO(Unit):
  do IO<Unit>:
    _:String <- C.command("mkdir",["-p","build/jonmath","build/model-obj","build/qualification/jonlib"])
    run("download","curl",["--fail","--location","--silent","--show-error","https://codeload.github.com/jonathanperis/jonlib/tar.gz/5e49707e346453f7d36c27d5ca0cb286e431973d","--output","build/qualification/jonlib.tar.gz"])
    run("archive-pin","sha256sum",["-c","tools/jonmath/archive.sha256"])
    run("unpack","tar",["-xzf","build/qualification/jonlib.tar.gz","--strip-components=1","-C","build/qualification/jonlib"])
    run("adapter-source","cp",["tools/jonmath/adapter.bend.in","build/jonmath/adapter.bend"])
    run("probe-source","cp",["tools/jonmath/qualify.bend.in","build/jonmath/qualify.bend"])
    run("qualification-build","bend",["build/jonmath/qualify.bend","-o","build/jonmath/qualify"])
    run("qualification","build/jonmath/qualify",["+RTS","--threads","1","--gpu","off"])
    run("mutations-build","bend",["tools/jonmath/mutations.bend","-o","build/jonmath/mutations"])
    run("mutations","build/jonmath/mutations",["+RTS","--threads","1","--gpu","off"])
    run("restored-qualification","build/jonmath/qualify",["+RTS","--threads","1","--gpu","off"])
    run("creation-build","bend",["tools/verify-creation.bend","-o","build/jonmath/creation"])
    run("creation","env",["VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation","VK_LAYER_VALIDATE_SYNC=1","build/jonmath/creation","+RTS","--threads","1","--gpu","off"])
    run("quaternion-scene-build","bend",["examples/scene-render.bend","-o","build/jonmath/quaternion-scene"])
    run("quaternion-scene","env",["VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation","VK_LAYER_VALIDATE_SYNC=1","build/jonmath/quaternion-scene","+RTS","--threads","1","--gpu","off"])
    run("scene-build","bend",["tools/model-obj/native.bend","-o","build/jonmath/scene"])
    run("scene","env",["VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation","VK_LAYER_VALIDATE_SYNC=1","build/jonmath/scene","+RTS","--threads","1","--gpu","off"])
    retained("sign",[".state.txt",".packed.txt",".rgba",".d32"])
    retained("wedge",[".state.txt",".packed.txt",".rgba",".d32"])
    IO.print("S41 adapters qualified against exact scene inputs. Retained ECS state, geometry, RGBA and D32 are byte-identical. Production math retained.")
