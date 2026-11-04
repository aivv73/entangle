import Base
import ../../src/json-boundary.bend as Json
import ../../src/scene-file.bend as S
import ../../src/asset.bend as Asset
import ../../src/creation.bend as Create
import ../../src/content.bend as F
import ../../src/components.bend as Comp
import ../model-obj/reference.bend as Ref
import ../image-decoder/common.bend as C
import ../image-decoder/replace.bend as Replace
import ../verify-upload-mutations.bend as Files


def read_text(path:String) -> IO(String):
  do IO<String>:
    bytes:List<&2,U32> <- C.read(path)
    return Json.string(bytes)

def corpus() -> String:"docs/verification/2026-11-04-json-scene/corpus/"
def folder() -> String:"build/json-scene/files/"

def pose(+x:F32,+s:F32) -> Comp.Transform:
  Comp.Transform{Comp.Vec3{x,0.0,0.0},Comp.Quat{0.0,0.0,0.0,1.0},Comp.Vec3{s,s,s}}

def expected_parts(parts:List<&2,F.ModelPart>,+t:Comp.Transform) -> List<&2,Create.Instance>:
  match parts:
    case []:[]
    case F.ModelPart{m,c,_} <> rest:Create.Instance{m,c,t} <> expected_parts(rest,t)

def expected(model:F.SourceModel) -> Create.Scene:
  F.SourceModel{+parts} = model
  Create.Scene{List.append(&2,Create.Instance,expected_parts(parts,pose(0.0,1.0)),expected_parts(parts,pose(2.0,0.5)))}

def same_pose(a:Comp.Transform,b:Comp.Transform) -> Bool:
  Comp.Transform{p,Comp.Quat{x,y,z,w},s} = a
  Comp.Transform{q,Comp.Quat{u,v,r,t},h} = b
  F.same_vec(p,q) && F.same_vec(s,h) && F.same_indices([F32.bits(x),F32.bits(y),F32.bits(z),F32.bits(w)],[F32.bits(u),F32.bits(v),F32.bits(r),F32.bits(t)])

def same_instances(a:List<&2,Create.Instance>,b:List<&2,Create.Instance>) -> Bool:
  match a b:
    case [],[]:True{}
    case Create.Instance{m,c,t} <> xs,Create.Instance{n,d,u} <> ys:F.same_mesh(m,n) && F.same_material(c,d) && same_pose(t,u) && same_instances(xs,ys)
    case _,_:False{}

def same_scene(a:Create.Scene,b:Create.Scene) -> Bool:
  Create.Scene{xs} = a
  Create.Scene{ys} = b
  same_instances(xs,ys)

def compiled(result:Result<&2,&2,Create.Error,Create.Compiled>) -> IO(Unit):
  match result:
    case Fail{_}:IO.die(Unit,1,"real Creation rejected loaded scene")
    case Done{Create.Compiled{seeds,Create.Geometry{vs,is1,rs}}}:
      C.require(Nat.is_eq(List.length(&2,Create.Seed,seeds),6n) && Nat.is_eq(List.length(&2,F.Vertex,vs),18n) && Nat.is_eq(List.length(&2,U32,is1),18n) && Nat.is_eq(List.length(&2,Create.Range,rs),3n),"scene compilation changed sharing or geometry")

def good(result:Result<&2,&2,Asset.Error,Create.Scene>) -> IO(Unit):
  match result:
    case Fail{Asset.Error{_,message}}:IO.die(Unit,1,"valid scene rejected " ++ message)
    case Done{+scene}:
      do IO<Unit>:
        C.require(same_scene(scene,expected(Ref.sign())),"complete scene source differs")
        compiled(Create.compile(scene))

def rejected(-A:Data,result:Result<&2,&2,Asset.Error,A>,+label:String,+code:U32,+needle:String) -> IO(Unit):
  match result:
    case Done{_}:IO.die(Unit,1,label ++ " accepted")
    case Fail{Asset.Error{actual,+message}}:
      do IO<Unit>:
        C.require(U32.is_eq(actual,U32.add(2147484160,code)) && String.contains(message,needle),label ++ " wrong rejection " ++ message)
        IO.print(label ++ " rejected " ++ message)

def write_scene(text:String) -> IO(Unit):Files.save(folder() ++ "scene.json",text)

def bad_scene(+label:String,text:String,code:U32,needle:String) -> IO(Unit):
  do IO<Unit>:
    write_scene(text)
    result:Result<&2,&2,Asset.Error,Create.Scene> <- S.load(folder() ++ "scene.json")
    rejected(Create.Scene,result,label,code,needle)

def changes(cases:List<&1,(String & String & String & U32 & String)>,+original:String) -> IO(Unit):
  match cases:
    case []:IO.pure(Unit,Unit{})
    case (label,before,after,code,needle) <> rest:
      do IO<Unit>:
        bad_scene(label,Replace.all(original,before,after),code,needle)
        changes(rest,original)

def manifest_change(+label:String,text:String,code:U32,needle:String) -> IO(Unit):
  do IO<Unit>:
    Files.save(folder() ++ "manifest.json",text)
    result:Result<&2,&2,Asset.Error,List<&2,S.Source>> <- S.load_manifest(folder() ++ "manifest.json")
    rejected(List<&2,S.Source>,result,label,code,needle)

def manifest_changes(cases:List<&1,(String & String & String & U32 & String)>,+original:String) -> IO(Unit):
  match cases:
    case []:IO.pure(Unit,Unit{})
    case (label,before,after,code,needle) <> rest:
      do IO<Unit>:
        manifest_change(label,Replace.all(original,before,after),code,needle)
        manifest_changes(rest,original)

def syntax(+scene:String) -> IO(Unit):
  do IO<Unit>:
    changes([
      ("duplicate-root","\"version\":1","\"version\":1,\"version\":1",1,"invalid UTF-8 JSON"),
      ("duplicate-escaped","\"version\":1","\"version\":1,\"\\u0076ersion\":1",1,"invalid UTF-8 JSON"),
      ("duplicate-nested","\"model\":\"sign\"","\"model\":\"sign\",\"model\":\"sign\"",1,"invalid UTF-8 JSON"),
      ("unknown-field","\"version\":1","\"version\":1,\"extra\":0",3,"unknown field extra"),
      ("missing-field","\"version\":1,","",3,"missing field version"),
      ("wrong-type","\"version\":1","\"version\":\"1\"",3,"version must be integer 1"),
      ("version-rounded","\"version\":1","\"version\":1.0000000001",3,"version must be integer 1"),
      ("wrong-version","\"version\":1","\"version\":2",3,"version must be integer 1"),
      ("null-transform","[0,0,0]","null",3,"expected exactly three numbers"),
      ("short-vector","[0,0,0]","[0,0]",3,"expected exactly three numbers"),
      ("long-vector","[0,0,0]","[0,0,0,0]",3,"expected exactly three numbers"),
      ("string-number","[0,0,0]","[\"0\",0,0]",3,"expected number"),
      ("range","[0,0,0]","[1000001,0,0]",4,"finite in"),
      ("overflow","[0,0,0]","[1e39,0,0]",4,"number"),
      ("zero-quaternion","[0,0,0,1]","[0,0,0,0]",4,"unit quaternion"),
      ("long-number","[0,0,0]","[0." ++ String.repeat("0",64n) ++ "1,0,0]",2,"number exceeds"),
      ("unresolved-reference","\"model\":\"sign\"","\"model\":\"absent\"",5,"unresolved model"),
      ("wrong-asset-kind","\"model\":\"sign\"","\"model\":\"image\"",5,"image used as model"),
      ("manifest-traversal","manifest.json","../manifest.json",5,"relative ASCII"),
      ("manifest-absolute","manifest.json","/manifest.json",5,"relative ASCII"),
      ("manifest-uri","manifest.json","file:manifest.json",5,"relative ASCII"),
      ("manifest-nul","manifest.json","manifest\\u0000.json",5,"relative ASCII"),
      ("manifest-long","manifest.json",String.repeat("x",256n),2,"string exceeds"),
      ("surrogate","manifest.json","\\ud800",1,"invalid UTF-8 JSON"),
      ("depth-at-limit","\"version\":1","\"version\":1,\"extra\":" ++ String.repeat("[",7n) ++ "0" ++ String.repeat("]",7n),3,"unknown field extra"),
      ("depth","\"version\":1","\"version\":1,\"extra\":" ++ String.repeat("[",8n) ++ "0" ++ String.repeat("]",8n),1,"nesting exceeds")],scene)
    bad_scene("trailing",scene ++ " false",1,"invalid UTF-8 JSON")
    bad_scene("empty","",1,"invalid UTF-8 JSON")
    bad_scene("root-array","[]",3,"expected object")
    bad_scene("bytes-over",scene ++ String.repeat(" ",Nat.sub(65537n,String.length(scene))),2,"65536")
    write_scene(scene ++ String.repeat(" ",Nat.sub(65536n,String.length(scene))))
    result:Result<&2,&2,Asset.Error,Create.Scene> <- S.load(folder() ++ "scene.json")
    good(result)
    IO.print("Exact 65536-byte scene accepted.")

def repeat_items(n:Nat,+item:String) -> String:
  match n:
    case 0n:""
    case 1n+0n:item
    case 1n+p:item ++ "," ++ repeat_items(p,item)

def asset_items(n:Nat) -> String:
  match n:
    case 0n:""
    case 1n+p:
      +p:Nat = p
      "{\"id\":\"a" ++ Nat.show(p) ++ "\",\"kind\":\"obj\",\"path\":\"sign.obj\"}" ++ Bool.pick(String,Nat.is_eq(p,0n),"",",") ++ asset_items(p)

def counts() -> IO(Unit):
  do IO<Unit>:
    +item:String = "{\"model\":\"sign\",\"transform\":{\"position\":[0,0,0],\"rotation\":[0,0,0,1],\"scale\":[1,1,1]}}"
    bad_scene("instance-count","{\"version\":1,\"manifest\":\"manifest.json\",\"instances\":[" ++ repeat_items(257n,item) ++ "]}",2,"256 instances")
    manifest_change("asset-count","{\"version\":1,\"assets\":[" ++ asset_items(65n) ++ "]}",2,"64 assets")

def missing(result:Result<&2,&2,Asset.Error,Create.Scene>,needle:String) -> IO(Unit):
  match result:
    case Done{_}:IO.die(Unit,1,"missing asset accepted")
    case Fail{Asset.Error{_,+message}}:C.require(String.contains(message,needle),"missing asset lost its path " ++ message)

def main() -> IO(Unit):
  do IO<Unit>:
    _:String <- C.command("mkdir",["-p",folder()])
    _:String <- C.command("cp",[corpus() ++ "sign.obj",corpus() ++ "sign.mtl",corpus() ++ "image.png",folder()])
    +scene:String <- read_text(corpus() ++ "scene.json")
    +manifest:String <- read_text(corpus() ++ "manifest.json")
    Files.save(folder() ++ "manifest.json",manifest)
    write_scene(scene)
    result:Result<&2,&2,Asset.Error,Create.Scene> <- S.load(folder() ++ "scene.json")
    good(result)
    IO.print("Complete scene matches authored reference, including transforms, mesh/material words and part order. Creation shares three ranges across six instances.")
    syntax(scene)
    manifest_changes([
      ("manifest-duplicate","\"version\":1","\"version\":1,\"version\":1",1,"invalid UTF-8 JSON"),
      ("asset-id-duplicate","\"id\":\"image\"","\"id\":\"sign\"",5,"duplicate asset id"),
      ("asset-path-traversal","sign.obj","../sign.obj",5,"relative ASCII"),
      ("asset-kind","\"obj\"","\"glb\"",3,"kind must be"),
      ("asset-schema","\"id\":\"sign\"","\"id\":\"sign\",\"extra\":1",3,"unknown field extra")],manifest)
    counts()
    Files.save(folder() ++ "manifest.json",manifest)
    write_scene(Replace.all(scene,"manifest.json","absent.json"))
    result:Result<&2,&2,Asset.Error,Create.Scene> <- S.load(folder() ++ "scene.json")
    missing(result,"absent.json")
    Files.save(folder() ++ "manifest.json",Replace.all(manifest,"sign.obj","absent.obj"))
    write_scene(scene)
    result:Result<&2,&2,Asset.Error,Create.Scene> <- S.load(folder() ++ "scene.json")
    missing(result,"absent.obj")
    Files.save(folder() ++ "manifest.json",Replace.all(manifest,"image.png","absent.png"))
    result:Result<&2,&2,Asset.Error,Create.Scene> <- S.load(folder() ++ "scene.json")
    missing(result,"absent.png")
    Files.save(folder() ++ "manifest.json",manifest)
    C.write(folder() ++ "scene.json",[123,34,120,34,58,34,192,175,34,125])
    result:Result<&2,&2,Asset.Error,Create.Scene> <- S.load(folder() ++ "scene.json")
    rejected(Create.Scene,result,"invalid-utf8",1,"invalid UTF-8 JSON")
    write_scene(scene)
    result:Result<&2,&2,Asset.Error,Create.Scene> <- S.load(folder() ++ "scene.json")
    good(result)
    IO.print("Real JSON file rejection matrix and restored scene pass.")
