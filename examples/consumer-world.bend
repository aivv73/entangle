import Base
import ./courier-state.bend as Game
import ../src/scene.bend as Scene
import ../src/scene-motion.bend as Motion
import ../src/mesh-control.bend as Control
import ../src/scene-observe.bend as Observe
import ../src/scene-schema.bend as D
import ../src/creation.bend as Create
import ../src/hierarchy.bend as H
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/inspector.bend as I

type World is Type:
  World{app:Scene.Application(),handles:List<&2,W.Handle<D.Schema>>}

def observed(pair:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Observe.Snapshot>)) -> IO(World):
  match pair:
    case (app,(_,Done{Observe.Snapshot{_,handles,True{},True{},_}})):IO.pure(World,World{app,handles})
    case _:IO.die(World,1,"Consumer ECS bootstrap refused")

def create(seeds:List<&2,Create.Seed>) -> IO(World):
  do IO<World>:
    app:Scene.Application() <- Scene.create_mode(seeds,Motion.Controlled{Control.Boot{}})
    app:Scene.Application() <- Scene.tick(app)
    observed(Observe.snapshot(app,I.Fresh{}))

def edited(pair:Scene.Application() & Result<&2,&2,H.Error,Unit>) -> IO(Scene.Application()):
  match pair:
    case (app,Done{_}):IO.pure(Scene.Application(),app)
    case _:IO.die(Scene.Application(),1,"Gameplay transform publication rejected")

def apply(handles:List<&2,W.Handle<D.Schema>>,+index:Nat,+state:Game.State,app:Scene.Application()) -> IO(Scene.Application()):
  match handles:
    case []:IO.pure(Scene.Application(),app)
    case handle <> rest:
      do IO<Scene.Application()>:
        app:Scene.Application() <- edited(Scene.set_transform(app,handle,Game.transform(index,state)))
        apply(rest,1n+index,state,app)

def publish(state:Game.State,world:World) -> IO(World):
  World{app,+handles} = world
  do IO<World>:
    app:Scene.Application() <- apply(handles,0n,state,app)
    return World{app,handles}
