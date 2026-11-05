import Base
import ./upload-boundary/scan.bend as S
import ./verify-upload-mutations.bend as Files
import ./verify-native-failures.bend as Replace

def recorded(+dest:String,+label:String,result:U32 & (String & String),+failure:String) -> IO(Unit):
  (+status,(out,err)) = result
  +log = out ++ err
  do IO<Unit>:
    Files.save(dest ++ "/" ++ label ++ ".log",log)
    Files.save(dest ++ "/" ++ label ++ ".status",U32.show(status) ++ "\n")
    S.require(Bool.pick(Bool,String.is_empty(failure),U32.is_zero(status),U32.is_eq(status,1) && String.contains(log,failure)) && Bool.not(String.contains(log,"Validation Error") || String.contains(log,"SYNC-HAZARD") || String.contains(log,"VUID-")),"Texture control has unexpected result " ++ label ++ ": " ++ log)

def command(+dest:String,label:String,args:List<String>,failure:String) -> IO(Unit):
  do IO<Unit>:
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("env","-C" <> dest <> "VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation" <> "VK_LAYER_VALIDATE_SYNC=1" <> args,"",16777216,300000))
    recorded(dest,label,result,failure)

def gate(+dest:String,+label:String,+driver:String,failure:String) -> IO(Unit):
  do IO<Unit>:
    command(dest,label ++ "-build",["bend","tools/" ++ driver ++ ".bend","-o","build/" ++ label],"")
    command(dest,label,["./build/" ++ label,"+RTS","--threads","1","--gpu","off"],failure)

def mutation(+dest:String,+label:String,+path:String,before:String,after:String,+driver:String,failure:String) -> IO(Unit):
  do IO<Unit>:
    +original:String <- S.read(path)
    changed:String <- Replace.replaced(Replace.replace(String.split(original,'\n'),before,after))
    Files.save(dest ++ "/" ++ path,changed)
    command(dest,label ++ "-shaders",["bend","tools/build-scene-shaders.bend"],"")
    gate(dest,label,driver,failure)
    Files.save(dest ++ "/" ++ path,original)
    command(dest,label ++ "-restore-shaders",["bend","tools/build-scene-shaders.bend"],"")
    gate(dest,label ++ "-restored",driver,"")
    IO.print(label ++ " rejected at its named property; restored source passed")

def main() -> IO(Unit):
  do IO<Unit>:
    _:String <- S.run("mkdir",["-p","build/verification"])
    directory:String <- S.run("mktemp",["-d","build/verification/texture-controls-XXXXXXXX"])
    +dest:String = String.trim(directory)
    IO.print("Texture sensitivity evidence: " ++ dest)
    _:String <- S.run("cp",["-R","--reflink=auto","--","src","tools","examples","deps","assets","proofs","LAWS.bend","PROOF.bend","toolchain.bend",dest])
    _:String <- S.run("mkdir",["-p",dest ++ "/build"])
    gate(dest,"baseline-pixels","verify-textured-render","")
    gate(dest,"baseline-transforms","verify-textured-transforms","")
    gate(dest,"baseline-lifetime","verify-textured-lifetime","")
    gate(dest,"baseline-rollback","verify-texture-upload","")
    mutation(dest,"upload-rollback","src/scene-texture.bend",
      "        V.Device.destroy_image(device,image)","        V.Action.pure(Unit,Unit{})",
      "verify-texture-upload","Partial texture preparation did not release image and memory")
    mutation(dest,"byte-order","src/render-format.bend",
      "  [Core.word_byte(pixel,3),Core.word_byte(pixel,2),Core.word_byte(pixel,1),Core.word_byte(pixel,0)]",
      "  [Core.word_byte(pixel,0),Core.word_byte(pixel,1),Core.word_byte(pixel,2),Core.word_byte(pixel,3)]",
      "verify-textured-render","Texture orientation and sampling: full RGBA/D32 differs")
    mutation(dest,"normal-scale","src/shaders/textured.vert",
      "    vec3 n = normal * drawing.inverse_scale.xyz;","    vec3 n = normal;",
      "verify-textured-transforms","Nonuniform inverse scale: normal transform irradiance differs")
    mutation(dest,"diffuse","src/shaders/textured.frag",
      "    float diffuse = max(dot(normal, normalize(drawing.light_direction_ambient.xyz)), 0.0);","    float diffuse = 1.0;",
      "verify-textured-render","Back-facing normals receive no diffuse light: full RGBA/D32 differs")
    mutation(dest,"normal-magnitude","src/shaders/textured.frag",
      "    vec3 normal = world_normal * inversesqrt(normal_squared > 0.0 ? normal_squared : 1.0);",
      "    vec3 normal = world_normal * inversesqrt(max(normal_squared, 1e-20));",
      "verify-textured-transforms","Small valid normals at maximum scale: normal transform irradiance differs")
    mutation(dest,"retirement","src/scene-materials.bend",
      "  Resident{next,List.concat(&2,List<&2,T.Resource>,[ownership(active),retired,pending])}",
      "  Resident{next,List.concat(&2,List<&2,T.Resource>,[retired,pending])}",
      "verify-textured-lifetime","Reset and collection release old texture and geometry: live object count differs")
    mutation(dest,"camera","src/scene-render.bend",
      "    case Some{matrix}:(Config{w,h,matrix,light},True{})","    case Some{matrix}:(Config{w,h,camera,light},True{})",
      "verify-textured-transforms","Camera move/reset did not change and restore exact RGBA/D32")
