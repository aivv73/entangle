import Base
import ../../examples/courier-state.bend as Game
import ../../examples/consumer-world.bend as World
import ../../examples/consumer-content.bend as Content
import ../../src/creation.bend as Create
import ../../src/scene-observe.bend as Observe
import ../../src/components.bend as C
import ../../src/scene.bend as Scene
import ../../src/scene-schema.bend as D
import ../../deps/bendvy/src/ecs/world.bend as W
import ../../src/mesh-evidence.bend as Evidence
import ../../deps/bendvy/src/ecs/inspector.bend as I
import ../window-verification/check.bend as Check

def transform_words(value:C.Transform) -> String:
  C.Transform{C.Vec3{x,y,z},C.Quat{a,b,c,d},C.Vec3{u,v,w}} = value
  Evidence.words([x,y,z,a,b,c,d,u,v,w])

def expected(pose:C.Transform,actual:Observe.Row) -> Bool:
  Observe.Row{_,transform,_} = actual
  String.eq(transform_words(pose),transform_words(transform))


def captured(handles:List<&2,W.Handle<D.Schema>>,pair:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Observe.Snapshot>)) -> IO(World.World & List<&2,Observe.Row>):
  match pair:
    case (app,(_,Done{Observe.Snapshot{_,_,True{},True{},rows}})):IO.pure(World.World & List<&2,Observe.Row>,(World.World{app,handles},rows))
    case _:IO.die(World.World & List<&2,Observe.Row>,1,"Consumer runtime snapshot refused")

def capture(world:World.World) -> IO(World.World & List<&2,Observe.Row>):
  World.World{app,handles} = world
  captured(handles,Observe.snapshot(app,I.Fresh{}))

def advance(codes:List<&2,U32>,state:Game.State) -> Game.State:
  match codes:
    case []:state
    case code <> rest:advance(rest,Game.key(code,state))

def carrying(rows:List<&2,Observe.Row>) -> Bool:
  match rows:
    case [player,crystal,_,_]:expected(Game.pose(F32.neg(2.0),0.2,0.0,0.5),player) && expected(Game.pose(F32.neg(2.0),1.0,0.0,0.3),crystal)
    case _:False{}

def complete(rows:List<&2,Observe.Row>) -> Bool:
  match rows:
    case [player,crystal,pad,_]:expected(Game.pose(2.0,0.2,0.0,0.5),player) && expected(Game.pose(2.0,0.5,0.0,0.65),crystal) && expected(Game.pose(2.0,0.15,0.0,1.3),pad)
    case _:False{}


def reset(+initial:List<&2,Observe.Row>,pair:World.World & List<&2,Observe.Row>) -> IO(Unit):
  (_,rows) = pair
  do IO<Unit>:
    Check.assert(String.eq(Evidence.rows(initial),Evidence.rows(rows)),"Reset must restore every full ECS identity, mesh and transform bit from the disk scene")
    IO.print("Disk scene loaded; real ECS carried and delivered transforms match independent coordinates; full-state reset exact.")

def delivered(initial:List<&2,Observe.Row>,+state:Game.State,pair:World.World & List<&2,Observe.Row>) -> IO(Unit):
  (world,rows) = pair
  do IO<Unit>:
    Check.assert(Game.phase_equal(Game.phase(state),Game.Complete{}) && complete(rows),"Delivery must publish player, crystal and expanded pad at independent objective coordinates")
    world:World.World <- World.publish(Game.key(120,state),world)
    pair:World.World & List<&2,Observe.Row> <- capture(world)
    reset(initial,pair)

def collected(initial:List<&2,Observe.Row>,state:Game.State,pair:World.World & List<&2,Observe.Row>) -> IO(Unit):
  (world,rows) = pair
  do IO<Unit>:
    Check.assert(carrying(rows),"Carried crystal must follow the actual ECS courier at x=-2,y=1")
    +state:Game.State = advance([108,108,108,108,32],state)
    world:World.World <- World.publish(state,world)
    pair:World.World & List<&2,Observe.Row> <- capture(world)
    delivered(initial,state,pair)

def started(pair:World.World & List<&2,Observe.Row>) -> IO(Unit):
  (world,initial) = pair
  do IO<Unit>:
    +pickup:Game.State = advance([106,106,32],Game.initial())
    world:World.World <- World.publish(pickup,world)
    pair:World.World & List<&2,Observe.Row> <- capture(world)
    collected(initial,pickup,pair)

def run(compiled:Create.Compiled) -> IO(Unit):
  Create.Compiled{seeds,_} = compiled
  do IO<Unit>:
    world:World.World <- World.create(seeds)
    pair:World.World & List<&2,Observe.Row> <- capture(world)
    started(pair)

def main() -> IO(Unit):
  do IO<Unit>:
    scene:Create.Scene <- Content.gameplay()
    compiled:Create.Compiled <- Content.compiled(Create.compile(scene))
    run(compiled)
