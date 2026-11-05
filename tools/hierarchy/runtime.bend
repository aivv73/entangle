import Base
import ./check.bend as Check
import ./drive.bend as Drive
import ./scenes.bend as Scenes
import ../../src/scene.bend as Scene
import ../../src/scene-schema.bend as D
import ../../src/scene-hierarchy.bend as HW
import ../../src/hierarchy.bend as H
import ../../src/creation.bend as Create
import ../../src/components.bend as C
import ../../src/content.bend as F
import ../../src/scene-file.bend as Json
import ../../src/asset.bend as Asset
import ../../deps/bendvy/src/ecs/world.bend as W
import ../verify-creation.bend as Consumer
import ../verify-upload-mutations.bend as Files
import ../upload-boundary/scan.bend as S

def forest_moved(pair:Scene.Application() & List<&2,HW.Row>) -> IO(Unit):
  (app,+rows) = pair
  do IO<Unit>:
    root:W.Handle<D.Schema> <- Check.entity(Check.at(rows,0n))
    app:Scene.Application() <- Check.accepted(Scene.set_transform(app,root,Scenes.pose(0.5,0.25,0.0,C.Quat{0.0,0.0,0.6,0.8},C.Vec3{2.0,0.5,1.0})),True{})
    checked:Scene.Application() & List<&2,HW.Row> <- Check.observe(app)
    return Unit{}

def forest(mode:U32,count:Nat) -> IO(Unit):
  do IO<Unit>:
    compiled:Create.Compiled <- Consumer.compiled(Create.compile(Create.Scene{Scenes.forest(count,mode,0)}))
    pair:Scene.Application() & List<&2,HW.Row> <- Drive.start(compiled)
    forest_moved(pair)

def compile_rejected(result:Result<&2,&2,Create.Error,Create.Compiled>) -> Bool:
  match result:
    case Fail{Create.BadHierarchy{_}}:True{}
    case _:False{}

def rejects() -> IO(Unit):
  do IO<Unit>:
    S.require(compile_rejected(Create.compile(Create.Scene{[Create.Parented{Scenes.mesh(),F.white(),C.Transform.identity(),0}]})),"Creation self-parent accepted")
    S.require(compile_rejected(Create.compile(Create.Scene{[Create.Parented{Scenes.mesh(),F.white(),C.Transform.identity(),9}]})),"Creation missing parent accepted")
    S.require(compile_rejected(Create.compile(Create.Scene{[Create.Parented{Scenes.mesh(),F.white(),C.Transform.identity(),1},Create.Parented{Scenes.mesh(),F.white(),C.Transform.identity(),0}]})),"Creation cycle accepted")
    return Unit{}

def placement(parent:String) -> String:
  "{\"model\":\"sign\",\"parent\":" ++ parent ++ ",\"transform\":{\"position\":[0,0,0],\"rotation\":[0,0,0,1],\"scale\":[1,1,1]}}"

def document(a:String,b:String,c:String) -> String:
  "{\"version\":1,\"manifest\":\"manifest.json\",\"instances\":[" ++ placement(a) ++ "," ++ placement(b) ++ "," ++ placement(c) ++ "]}"

def parents(values:List<&2,H.Local>) -> String:
  match values:
    case []:""
    case H.Local{_,p,_,_} <> rest:Check.parent_words(p) ++ "," ++ parents(rest)

def loaded(result:Result<&2,&2,Asset.Error,Create.Scene>,valid:Bool,expected:String) -> IO(Unit):
  match result:
    case Fail{_}:S.require(Bool.not(valid),"Valid hierarchy JSON rejected")
    case Done{+scene}:
      Create.Scene{+items} = scene
      do IO<Unit>:
        S.require(valid,"Invalid hierarchy JSON accepted")
        S.require(String.eq(parents(Create.locals(items)),expected),"Hierarchy JSON placement parents or model anchors differ")
        compiled:Create.Compiled <- Consumer.compiled(Create.compile(Create.Scene{items}))
        pair:Scene.Application() & List<&2,HW.Row> <- Drive.start(compiled)
        return Unit{}

def json_case(+dir:String,+a:String,b:String,c:String,valid:Bool) -> IO(Unit):
  do IO<Unit>:
    Files.save(dir ++ "/scene.json",document(a,b,c))
    result:Result<&2,&2,Asset.Error,Create.Scene> <- Json.load(dir ++ "/scene.json")
    loaded(result,valid,Bool.pick(String,String.eq(a,"2"),"6,0,0,0,3,3,root,6,6,","root,0,0,0,3,3,3,6,6,"))

def json() -> IO(Unit):
  do IO<Unit>:
    _:String <- S.run("mkdir",["-p","build/verification"])
    path:String <- S.run("mktemp",["-d","build/verification/hierarchy-json-XXXXXXXX"])
    +dir:String = String.trim(path)
    _:String <- S.run("cp",["docs/verification/2026-11-04-json-scene/corpus/manifest.json","docs/verification/2026-11-04-json-scene/corpus/sign.obj","docs/verification/2026-11-04-json-scene/corpus/sign.mtl","docs/verification/2026-11-04-json-scene/corpus/image.png",dir])
    json_case(dir,"2","0","null",True{})
    json_case(dir,"0","null","null",False{})
    json_case(dir,"1","2","0",False{})
    json_case(dir,"3","null","null",False{})
    json_case(dir,"1.0","null","null",False{})
    json_case(dir,"-1","null","null",False{})
    json_case(dir,"null","0","1",True{})
    IO.print("Hierarchy JSON forward references, model-part anchors and invalid graph rejection passed")

def finish(pair:Scene.Application() & List<&2,HW.Row>) -> IO(Unit):
  (app,rows) = pair
  IO.print("Hierarchy ECS complete-state verification passed")

def unchanged_local(rows:List<&2,HW.Row>) -> Bool:
  match rows:
    case []:True{}
    case HW.Row{_,C.Transform{position,_,_},_,_} <> rest:Check.vec(position,C.Vec3{0.0,0.0,0.0}) && unchanged_local(rest)

def rollback_equal(before:List<&2,HW.Row>,pair:Scene.Application() & List<&2,HW.Row>) -> IO(Unit):
  (app,after) = pair
  S.require(String.eq(Check.state(before),Check.state(after)),"Repeated invalid scheduled propagation changed accepted state")

def detached_preserved(pair:Scene.Application() & List<&2,HW.Row>) -> IO(Unit):
  (app,+rows) = pair
  do IO<Unit>:
    child:W.Handle<D.Schema> <- Check.entity(Check.at(rows,1n))
    app:Scene.Application() <- Check.accepted(Scene.set_parent(app,child,None{}),False{})
    pair:Scene.Application() & List<&2,HW.Row> <- Check.observe(app)
    rollback_equal(rows,pair)

def tiny_child(pair:Scene.Application() & List<&2,HW.Row>) -> IO(Unit):
  (app,rows) = pair
  do IO<Unit>:
    child:W.Handle<D.Schema> <- Check.entity(Check.at(rows,1n))
    app:Scene.Application() <- Check.accepted(Scene.set_transform(app,child,Scenes.pose(0.0,0.0,0.0,Scenes.rotation(),C.Vec3{0.0000001,0.0000001,0.0000001})),True{})
    pair:Scene.Application() & List<&2,HW.Row> <- Check.observe(app)
    detached_preserved(pair)

def rollback_rows(pair:Scene.Application() & List<&2,HW.Row>) -> IO(Unit):
  (app,+rows) = pair
  do IO<Unit>:
    S.require(unchanged_local(rows),"Invalid scheduled propagation did not restore local transforms")
    app:Scene.Application() <- Scene.tick(app)
    pair:Scene.Application() & List<&2,HW.Row> <- Check.observe(app)
    rollback_equal(rows,pair)

def scheduled_rollback() -> IO(Unit):
  +root:C.Transform = C.Transform{C.Vec3{0.0,0.0,0.0},Scenes.rotation(),C.Vec3{300000000000000000000000000000000000000.0,300000000000000000000000000000000000000.0,300000000000000000000000000000000000000.0}}
  do IO<Unit>:
    compiled:Create.Compiled <- Consumer.compiled(Create.compile(Create.Scene{[Create.Instance{F.Mesh{[],[]},F.white(),root},Create.Parented{F.Mesh{[],[]},F.white(),C.Transform.identity(),0}]}))
    pair:Scene.Application() & List<&2,HW.Row> <- Drive.start(compiled)
    rollback_rows(pair)
    IO.print("Invalid scheduled derived state restores accepted local/global/bounds state")

def main() -> IO(Unit):
  do IO<Unit>:
    rejects()
    forest(0,32n)
    forest(1,128n)
    forest(2,63n)
    scheduled_rollback()
    tiny:Scene.Application() & List<&2,HW.Row> <- Drive.boot()
    tiny_child(tiny)
    IO.print("Flat, deep and branching real ECS point/bounds oracle passed")
    pair:Scene.Application() & List<&2,HW.Row> <- Drive.boot()
    pair:Scene.Application() & List<&2,HW.Row> <- Drive.series(Drive.codes(),pair)
    finish(pair)
    json()
