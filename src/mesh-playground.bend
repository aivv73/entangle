import Base
import ./scene-runtime.bend as Core
import ./scene.bend as Factory
import ./scene-motion.bend as Motion
import ./scene-spawn.bend as Spawn
import ./scene-schema.bend as D
import ./scene-observe.bend as Observe
import ./scene-hierarchy.bend as Hierarchy
import ./hierarchy.bend as H
import ./components.bend as C
import ./creation.bend as Create
import ./mesh-control.bend as Move
import ./input.bend as Input
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/inspector.bend as I
import ../deps/bendvy/src/ecs/schedule.bend as Schedule

def Application() -> Type:Core.Application()
def run(app:Application()) -> Application() & Core.Report:Core.run(app)
def tick(app:Application()) -> IO(Application()):Core.tick(app)
def edit(app:Application(),request:Hierarchy.Edit) -> Application() & Result<&2,&2,H.Error,Unit>:Core.edit(app,request)
def set_parent(app:Application(),entity:W.Handle<D.Schema>,parent:Maybe<&2,W.Handle<D.Schema>>) -> Application() & Result<&2,&2,H.Error,Unit>:Core.set_parent(app,entity,parent)
def set_transform(app:Application(),entity:W.Handle<D.Schema>,value:C.Transform) -> Application() & Result<&2,&2,H.Error,Unit>:Core.set_transform(app,entity,value)

def mapped(f:Move.Control -> Move.Control,mode:Motion.Mode) -> Motion.Mode:
  match mode:
    case Motion.Controlled{control}:Motion.Controlled{f(control)}
    case mode:mode

def update(f:Move.Control -> Move.Control,app:Application()) -> Application():
  match app:
    case Core.Application{world,Schedule.Schedule{ns,name,steps,Core.Owners{left,right,user,mode}}}:
      Core.Application{world,Schedule.Schedule{ns,name,steps,Core.Owners{left,right,user,mapped(f,mode)}}}

def bound(initial:C.Transform,result:Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Observe.Snapshot>)) -> IO(Application()):
  match result:
    case (app,(_,Done{Observe.Snapshot{_,[handle,_,_,_],True{},True{},_}})):IO.pure(Application(),update(_ => Move.PlayerReady{handle,Move.empty(),initial,False{}},app))
    case _:IO.die(Application(),1,"Mesh bootstrap requires four complete admissions")

def initialized(initial:C.Transform,app:Application()) -> IO(Application()):
  do IO<Application()>:
    app:Application() <- tick(app)
    bound(initial,Observe.snapshot(app,I.Fresh{}))

def create_seeds(seeds:List<&2,Create.Seed>,pending:IO(Application())) -> IO(Application()):
  match seeds:
    case Create.Seed{initial,_,_} <> _:
      do IO<Application()>:
        app:Application() <- pending
        initialized(initial,app)
    case _:IO.die(Application(),1,"Mesh playground needs a player")

def create(seeds:List<&2,Create.Seed>) -> IO(Application()):
  +seeds:List<&2,Create.Seed> = seeds
  create_seeds(seeds,Factory.create_mode(seeds,Motion.Controlled{Move.Boot{}}))

def input(events:List<Event>,app:Application(),camera:Maybe<Create.Camera>) -> Application() & Maybe<Create.Camera>:
  match events camera:
    case _ None{}:(app,None{})
    case [] Some{c}:(app,Some{c})
    case Close{} <> _ _:(app,None{})
    case Key{27,True{}} <> _ _:(app,None{})
    case Key{+code,+down} <> rest Some{+c}:input(rest,update(Move.intent(code,down),app),Some{Bool.pick(Create.Camera,down,Input.key(code,c),c)})
    case _ <> rest Some{+c}:input(rest,app,Some{c})

def visible(active:Bool,app:Application()) -> Application():
  match active:
    case True{}:app
    case False{}:update(Move.clear,app)

def visibility(mapped:Bool,focused:Bool,app:Application()) -> Application():
  visible(mapped && focused,app)
