import Base
import ./upload-boundary/scan.bend as S
import ./verify-upload-mutations.bend as Files
import ./verify-texture-mutations.bend as Mutations

def recorded(+dest:String,+name:String,result:U32 & (String & String)) -> IO(Unit):
  (+status,(out,err)) = result
  +log = out ++ err
  do IO<Unit>:
    Files.save(dest ++ "/" ++ name ++ ".log",log)
    Files.save(dest ++ "/" ++ name ++ ".status",U32.show(status) ++ "\n")
    S.require(U32.is_zero(status) && Bool.not(String.contains(log,"Validation Error") || String.contains(log,"SYNC-HAZARD") || String.contains(log,"VUID-")),"Texture verification failed " ++ name ++ ": " ++ log)
    IO.write(log)

def command(+dest:String,name:String,args:List<String>) -> IO(Unit):
  do IO<Unit>:
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("env","VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation" <> "VK_LAYER_VALIDATE_SYNC=1" <> args,"",16777216,300000))
    recorded(dest,name,result)

def drivers(+dest:String,names:List<&2,String>) -> IO(Unit):
  match names:
    case []:IO.pure(Unit,Unit{})
    case +name <> rest:
      do IO<Unit>:
        command(dest,name ++ "-build",["bend","tools/" ++ name ++ ".bend","-o",dest ++ "/" ++ name])
        command(dest,name,[dest ++ "/" ++ name,"+RTS","--threads","1","--gpu","off"])
        drivers(dest,rest)

def main() -> IO(Unit):
  do IO<Unit>:
    directory:String <- S.run("mktemp",["-d","build/verification/textures-XXXXXXXX"])
    +dest:String = String.trim(directory)
    IO.print("Texture runtime evidence: " ++ dest)
    command(dest,"shaders-build",["bend","tools/build-scene-shaders.bend","-o",dest ++ "/build-scene-shaders"])
    command(dest,"shaders",[dest ++ "/build-scene-shaders","--check"])
    drivers(dest,["verify-texture-upload","verify-textured-render","verify-textured-transforms","verify-textured-lifetime"])
    Mutations.main()
