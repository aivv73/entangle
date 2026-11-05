import Base
import ./check.bend as Check
import ./scenes.bend as Scenes
import ../../src/scene.bend as Scene
import ../../src/creation.bend as Create
import ../../src/scene-schema.bend as D
import ../../src/scene-hierarchy.bend as HW
import ../../src/components.bend as C
import ../../src/hierarchy.bend as H
import ../../src/scene-matrix.bend as M
import ../../deps/bendvy/src/ecs/world.bend as W
import ../../deps/bendvy/src/ecs/entity-key.bend as K
import ../verify-creation.bend as Consumer
import ../upload-boundary/scan.bend as S

def foreign(entity:W.Handle<D.Schema>) -> W.Handle<D.Schema>:
  W.Handle{namespace,key} = entity
  W.Handle{U32.inc(namespace),key}

def stale(entity:W.Handle<D.Schema>) -> W.Handle<D.Schema>:
  W.Handle{namespace,K.EntityKey{index,generation}} = entity
  W.Handle{namespace,K.EntityKey{index,U32.inc(generation)}}

def missing(entity:W.Handle<D.Schema>) -> W.Handle<D.Schema>:
  W.Handle{namespace,K.EntityKey{_,generation}} = entity
  W.Handle{namespace,K.EntityKey{99999,generation}}

def action(code:U32,app:Scene.Application(),+root:W.Handle<D.Schema>,+child:W.Handle<D.Schema>,+branch:W.Handle<D.Schema>,+other:W.Handle<D.Schema>,deep:W.Handle<D.Schema>) -> IO(Scene.Application()):
  match code:
    case 0:
      do IO<Scene.Application()>:
        app:Scene.Application() <- Check.accepted(Scene.set_parent(app,child,Some{root}),True{})
        app:Scene.Application() <- Check.accepted(Scene.set_transform(app,root,Scenes.root()),True{})
        Check.accepted(Scene.set_transform(app,child,Scenes.child()),True{})
    case 1:Check.accepted(Scene.set_transform(app,root,Scenes.pose(0.1,0.1,0.5,Scenes.rotation(),C.Vec3{0.8,0.6,0.5})),True{})
    case 2:Check.accepted(Scene.set_transform(app,root,Scenes.pose(F32.neg(0.3),0.0,0.5,C.Quat{0.0,0.0,0.6,0.8},C.Vec3{0.8,0.6,0.5})),True{})
    case 3:Check.accepted(Scene.set_transform(app,root,Scenes.pose(F32.neg(0.3),0.0,0.5,Scenes.rotation(),C.Vec3{1.2,0.4,0.8})),True{})
    case 4:Check.accepted(Scene.set_parent(app,child,Some{other}),True{})
    case 5:Check.accepted(Scene.set_parent(app,child,None{}),True{})
    case 6:Check.accepted(Scene.set_parent(app,child,Some{child}),False{})
    case 7:Check.accepted(Scene.set_parent(app,root,Some{deep}),False{})
    case 8:Check.accepted(Scene.set_parent(app,child,Some{foreign(root)}),False{})
    case 9:Check.accepted(Scene.set_transform(app,root,Scenes.pose(0.0,0.0,0.5,Scenes.rotation(),C.Vec3{0.0,1.0,1.0})),False{})
    case 10:Check.accepted(Scene.set_transform(app,root,Scenes.pose(M.float_word(2139095040),0.0,0.5,Scenes.rotation(),Scenes.unit())),False{})
    case 11:Check.accepted(Scene.set_transform(app,foreign(root),Scenes.root()),False{})
    case 12:Check.accepted(Scene.set_transform(app,branch,Scenes.pose(0.0,0.8,0.0,C.Quat{0.6,0.0,0.0,0.8},C.Vec3{0.3,0.3,0.3})),True{})
    case 13:Scene.tick(app)
    case 14:Check.accepted(Scene.set_parent(app,child,Some{stale(root)}),False{})
    case 15:Check.accepted(Scene.set_parent(app,child,Some{missing(root)}),False{})
    case _:IO.die(Scene.Application(),1,"Unknown hierarchy replay command")

def independent(before:List<&2,HW.Row>,after:List<&2,HW.Row>) -> Bool:
  match before after:
    case [_,_,_,a,_], [_,_,_,b,_]:String.eq(Check.row_words(a),Check.row_words(b))
    case _ _:False{}

def verified(+code:U32,+before:List<&2,HW.Row>,pair:Scene.Application() & List<&2,HW.Row>) -> IO(Scene.Application() & List<&2,HW.Row>):
  (app,+rows) = pair
  do IO<Scene.Application() & List<&2,HW.Row>>:
    S.require(Bool.pick(Bool,(U32.is_ge(code,6) && U32.is_le(code,11)) || U32.is_ge(code,14),String.eq(Check.state(before),Check.state(rows)),True{}),"Rejected hierarchy edit changed complete ECS state")
    S.require(U32.is_eq(code,13) || independent(before,rows),"Hierarchy edit changed independent branch")
    IO.print_err("hierarchy-step=" ++ U32.show(code) ++ " state=" ++ Check.state(rows))
    return (app,rows)

def step(+code:U32,pair:Scene.Application() & List<&2,HW.Row>) -> IO(Scene.Application() & List<&2,HW.Row>):
  (app,+before) = pair
  do IO<Scene.Application() & List<&2,HW.Row>>:
    root:W.Handle<D.Schema> <- Check.entity(Check.at(before,0n))
    child:W.Handle<D.Schema> <- Check.entity(Check.at(before,1n))
    branch:W.Handle<D.Schema> <- Check.entity(Check.at(before,2n))
    other:W.Handle<D.Schema> <- Check.entity(Check.at(before,3n))
    deep:W.Handle<D.Schema> <- Check.entity(Check.at(before,4n))
    app:Scene.Application() <- action(code,app,root,child,branch,other,deep)
    pair:Scene.Application() & List<&2,HW.Row> <- Check.observe(app)
    verified(code,before,pair)

def start(compiled:Create.Compiled) -> IO(Scene.Application() & List<&2,HW.Row>):
  Create.Compiled{seeds,_} = compiled
  do IO<Scene.Application() & List<&2,HW.Row>>:
    app:Scene.Application() <- Scene.create(seeds)
    app:Scene.Application() <- Scene.tick(app)
    Check.observe(app)

def boot() -> IO(Scene.Application() & List<&2,HW.Row>):
  do IO<Scene.Application() & List<&2,HW.Row>>:
    compiled:Create.Compiled <- Consumer.compiled(Create.compile(Scenes.showcase()))
    start(compiled)

def series(codes:List<&2,U32>,pair:Scene.Application() & List<&2,HW.Row>) -> IO(Scene.Application() & List<&2,HW.Row>):
  match codes:
    case []:IO.pure(Scene.Application() & List<&2,HW.Row>,pair)
    case code <> rest:
      do IO<Scene.Application() & List<&2,HW.Row>>:
        next:Scene.Application() & List<&2,HW.Row> <- step(code,pair)
        series(rest,next)

def codes() -> List<&2,U32>:[0,1,2,3,4,5,6,7,8,9,10,11,14,15,0,12,13]
