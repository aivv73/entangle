import Base
import ../../src/scene-file.bend as S
import ../../src/creation.bend as Create
import ../../src/asset.bend as Asset
import ../../src/json-boundary.bend as Json
import ../image-decoder/common.bend as C
import ../verify-upload-mutations.bend as Files
import ./runtime.bend as Check

def scene_count(result:Result<&2,&2,Asset.Error,Create.Scene>,count:Nat) -> IO(Unit):
  match result:
    case Done{Create.Scene{items}}:C.require(Nat.is_eq(List.length(&2,Create.Instance,items),count),"boundary scene instance count differs")
    case Fail{Asset.Error{_,message}}:IO.die(Unit,1,"boundary scene rejected " ++ message)

def asset_count(result:Result<&2,&2,Asset.Error,List<&2,S.Source>>,count:Nat) -> IO(Unit):
  match result:
    case Done{items}:C.require(Nat.is_eq(List.length(&2,S.Source,items),count),"boundary manifest count differs")
    case Fail{Asset.Error{_,message}}:IO.die(Unit,1,"boundary manifest rejected " ++ message)

def scene(n:Nat) -> String:
  "{\"version\":1,\"manifest\":\"manifest.json\",\"instances\":[" ++ Check.repeat_items(n,"{\"model\":\"sign\",\"transform\":{\"position\":[0,0,0],\"rotation\":[0,0,0,1],\"scale\":[1,1,1]}}") ++ "]}"

def parts(n:Nat) -> String:
  match n:
    case 0n:""
    case 1n+p:
      +p:Nat = p
      "g part" ++ Nat.show(p) ++ "\nf 1 2 3\n" ++ parts(p)

def main() -> IO(Unit):
  do IO<Unit>:
    +manifest:String <- Check.read_text(Check.corpus() ++ "manifest.json")
    +original:String <- Check.read_text(Check.corpus() ++ "scene.json")
    Files.save(Check.folder() ++ "manifest.json",manifest)
    Check.write_scene(scene(256n))
    result:Result<&2,&2,Asset.Error,Create.Scene> <- S.load(Check.folder() ++ "scene.json")
    scene_count(result,768n)
    Files.save(Check.folder() ++ "manifest.json","{\"version\":1,\"assets\":[" ++ Check.asset_items(64n) ++ "]}")
    result:Result<&2,&2,Asset.Error,List<&2,S.Source>> <- S.load_manifest(Check.folder() ++ "manifest.json")
    asset_count(result,64n)
    Files.save(Check.folder() ++ "parts.obj","v 0 0 0\nv 1 0 0\nv 0 1 0\n" ++ parts(17n))
    Files.save(Check.folder() ++ "manifest.json","{\"version\":1,\"assets\":[{\"id\":\"sign\",\"kind\":\"obj\",\"path\":\"parts.obj\"}]}")
    Check.write_scene(scene(240n))
    result:Result<&2,&2,Asset.Error,Create.Scene> <- S.load(Check.folder() ++ "scene.json")
    scene_count(result,4080n)
    Check.bad_scene("expanded-count",scene(241n),2,"4096 parts")
    result:Result<&2,&2,Asset.Error,Create.Scene> <- S.load("")
    Check.rejected(Create.Scene,result,"empty-root",5,"root path")
    result:Result<&2,&2,Asset.Error,Create.Scene> <- S.load("bad\0path")
    Check.rejected(Create.Scene,result,"nul-root",5,"root path")
    Check.rejected(S.Description,S.decode_scene([256],"supplied"),"non-byte",1,"non-byte")
    Files.save(Check.folder() ++ "manifest.json",manifest)
    Check.write_scene(original)
    IO.print("Real files accept 64 assets, 256 placements and 4080 expanded parts, reject expansion above 4096, and enforce root path and byte-word rules.")
