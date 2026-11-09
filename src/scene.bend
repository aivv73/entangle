import Base
import ./scene-runtime.bend as Core
import ./scene-schema.bend as D
import ./scene-spawn.bend as Spawn
import ./scene-motion.bend as Move
import ./scene-hierarchy.bend as Hierarchy
import ./hierarchy.bend as H
import ./components.bend as C
import ./creation.bend as Create
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/world-io.bend as WI

def Application() -> Type:Core.Application()
def run(app:Application()) -> Application() & Core.Report:Core.run(app)
def tick(app:Application()) -> IO(Application()):Core.tick(app)
def edit(app:Application(),request:Hierarchy.Edit) -> Application() & Result<&2,&2,H.Error,Unit>:Core.edit(app,request)
def set_parent(app:Application(),entity:W.Handle<D.Schema>,parent:Maybe<&2,W.Handle<D.Schema>>) -> Application() & Result<&2,&2,H.Error,Unit>:Core.set_parent(app,entity,parent)
def set_transform(app:Application(),entity:W.Handle<D.Schema>,value:C.Transform) -> Application() & Result<&2,&2,H.Error,Unit>:Core.set_transform(app,entity,value)

# Host namespace allocation stays outside the pure runtime/proof closure.
def created(seeds:List<&2,Create.Seed>,mode:Move.Mode,result:WI.Creation<D.Schema,D.Store,Unit,Unit>) -> IO(Application()):
  match result:
    case WI.Created{world}:Core.bootstrap(Spawn.initial(seeds),mode,Spawn.define(world))
    case _:IO.die(Application(),1,"scene schema creation refused")

def create_mode(seeds:List<&2,Create.Seed>,mode:Move.Mode) -> IO(Application()):
  do IO<Application()>:
    seeds:List<&2,Create.Seed> <- Create.check_seeds(seeds)
    world:WI.Creation<D.Schema,D.Store,Unit,Unit> <- WI.create(~D.Schema,~D.Store,~Unit,~Unit,~D.empty,Unit{})
    created(seeds,mode,world)

def create(seeds:List<&2,Create.Seed>) -> IO(Application()):create_mode(seeds,Move.Automatic{})
