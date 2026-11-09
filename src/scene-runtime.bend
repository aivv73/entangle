import Base
import ./hierarchy.bend as H
import ./components.bend as Value
import ./scene-hierarchy.bend as Hierarchy
import ./creation.bend as Create
import ./scene-schema.bend as D
import ./scene-spawn.bend as Spawn
import ./scene-motion.bend as Move
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/system.bend as Sys
import ../deps/bendvy/src/ecs/ordinary-system.bend as Ordinary
import ../deps/bendvy/src/ecs/schedule.bend as Schedule
import ../deps/bendvy/src/ecs/transaction.bend as T

type Owners is Type:
  Owners{bootstrap:Spawn.Registry(),movement:Move.Owner(),user:Spawn.User,mode:Move.Mode}

def Nodes() -> Type:Owners
def ScheduleOwner() -> Type:Schedule.Schedule<D.Schema,D.Store,Unit,Unit,Owners>

type ApplicationState is Type:
  Application{world:D.World(),schedule:ScheduleOwner()}
def Application() -> Type:ApplicationState

type Report is Data:
  Finished{events:List<&2,Schedule.Observation>}
  Stopped{error:String,events:List<&2,Schedule.Observation>}
  Invalid{}

def spawned(right:Move.Owner(),backup:Spawn.User,mode:Move.Mode,result:Sys.RunResult<D.Schema,D.Store,Unit,Unit,Spawn.User,String,Spawn.User,Spawn.runner>) -> Owners & Sys.Outcome<D.World(),String,Unit>:
  match result:
    case Sys.Completed{left,Sys.Succeeded{world,user}}:(Owners{left,right,user,mode},Sys.Succeeded{world,Unit{}})
    case Sys.Completed{left,Sys.Failed{world,error}}:(Owners{left,right,backup,mode},Sys.Failed{world,error})
    case Sys.RegistrationRejected{left,world,user}:(Owners{left,right,user,mode},Sys.Failed{world,"bootstrap registration refused"})

def moved(left:Spawn.Registry(),user:Spawn.User,mode:Move.Mode,result:Move.Execution) -> Owners & Sys.Outcome<D.World(),String,Unit>:
  match result:
    case Move.Execution{right,world,T.Success{}}:(Owners{left,right,user,Move.consumed(mode)},Sys.Succeeded{world,Unit{}})
    case Move.Execution{right,world,T.Failure{error}}:(Owners{left,right,user,mode},Sys.Failed{world,error})

def selected(spawn:Bool,move:Bool,owners:Owners,world:D.World()) -> Owners & Sys.Outcome<D.World(),String,Unit>:
  match spawn move owners:
    case True{} _ Owners{left,right,+user,mode}:spawned(right,user,mode,Spawn.run(left,world,user))
    case False{} True{} Owners{left,right,user,+mode}:moved(left,user,mode,Move.run(right,world,mode))
    case _ _ owners:(owners,Sys.Failed{world,"unknown scene system"})

def dispatch(owners:Owners,world:D.World(),id:U32) -> Owners & Sys.Outcome<D.World(),String,Unit>:
  match owners:
    case Owners{Sys.Registry{ln,+lid,lname,la,lc},Ordinary.Owner{Sys.Registry{rn,+rid,rname,ra,rc},slot,clauses},user,mode}:
      +id:U32 = id
      selected(U32.is_eq(id,lid),U32.is_eq(id,rid),Owners{Sys.Registry{ln,lid,lname,la,lc},Ordinary.Owner{Sys.Registry{rn,rid,rname,ra,rc},slot,clauses},user,mode},world)

def condition(world:D.World(),_:U32) -> D.World() & Bool:(world,True{})

# Explicit barriers publish bootstrap before movement and drain the final queue.
def steps(spawn:U32,move:U32) -> List<&2,Schedule.Step>:
  [Schedule.System{spawn,0},Schedule.Barrier{},Schedule.System{move,0},Schedule.Barrier{}]

def settled(result:Schedule.RunResult<D.Schema,D.Store,Unit,Unit,Owners,String>) -> Application() & Report:
  match result:
    case Schedule.Finished{schedule,world,events}:(Application{Hierarchy.propagate(world),schedule},Finished{events})
    case Schedule.Failed{schedule,world,error,events}:(Application{Hierarchy.propagate(world),schedule},Stopped{error,events})
    case Schedule.Rejected{schedule,world}:(Application{world,schedule},Invalid{})

def run(app:Application()) -> Application() & Report:
  Application{world,schedule} = app
  settled(Schedule.run(~D.Schema,~D.Store,~Unit,~Unit,~Owners,~String,~dispatch,~condition,schedule,world))

def edited(rebuild:D.World() -> Application(),pair:D.World() & Result<&2,&2,H.Error,Unit>) -> Application() & Result<&2,&2,H.Error,Unit>:
  (world,result) = pair
  (rebuild(world),result)

def edit(app:Application(),request:Hierarchy.Edit) -> Application() & Result<&2,&2,H.Error,Unit>:
  Application{world,schedule} = app
  edited(world => Application{world,schedule},Hierarchy.update(world,request))

def set_parent(app:Application(),entity:W.Handle<D.Schema>,parent:Maybe<&2,W.Handle<D.Schema>>) -> Application() & Result<&2,&2,H.Error,Unit>:
  edit(app,Hierarchy.SetParent{entity,parent})

def set_transform(app:Application(),entity:W.Handle<D.Schema>,transform:Value.Transform) -> Application() & Result<&2,&2,H.Error,Unit>:
  edit(app,Hierarchy.SetTransform{entity,transform})

def built(world:D.World(),result:Schedule.Build<D.Schema,D.Store,Unit,Unit,Owners>) -> IO(Application()):
  match result:
    case Schedule.Built{schedule}:IO.pure(Application(),Application{world,schedule})
    case _:IO.die(Application(),1,"scene schedule refused")

def build(world:D.World(),owners:Owners) -> IO(Application()):
  match owners:
    case Owners{Sys.Registry{+ns,+lid,lname,la,lc},Ordinary.Owner{Sys.Registry{rn,+rid,rname,ra,rc},slot,clauses},user,mode}:
      built(world,Schedule.build(~D.Schema,~D.Store,~Unit,~Unit,~Owners,ns,"Entangle scene",steps(lid,rid),[lid,rid],Owners{Sys.Registry{ns,lid,lname,la,lc},Ordinary.Owner{Sys.Registry{rn,rid,rname,ra,rc},slot,clauses},user,mode}))

def movement(left:Spawn.Registry(),user:Spawn.User,mode:Move.Mode,result:Ordinary.Defined<D.Schema,D.World(),Move.Registry()>) -> IO(Application()):
  match result:
    case Ordinary.Defined{world,right}:build(world,Owners{left,right,user,mode})
    case _:IO.die(Application(),1,"scene movement registration refused")

def bootstrap(user:Spawn.User,mode:Move.Mode,result:Sys.RegistrationResult<D.Schema,D.Store,Unit,Unit,Spawn.User,String,Spawn.User,Spawn.runner>) -> IO(Application()):
  match result:
    case Sys.Registered{world,left}:movement(left,user,mode,Move.define(world))
    case _:IO.die(Application(),1,"scene bootstrap registration refused")

def distinct_systems(same:Bool) -> IO(Unit):
  match same:
    case False{}:IO.pure(Unit,Unit{})
    case True{}:IO.die(Unit,1,"scene schedule repeated a system")

def require_success(events:List<&2,Schedule.Observation>) -> IO(Unit):
  match events:
    case [Schedule.Ran{left},Schedule.Applied{},Schedule.Ran{right},Schedule.Applied{}]:distinct_systems(U32.is_eq(left,right))
    case _:IO.die(Unit,1,"scene schedule must report exactly two successful invocations and two barriers")

def checked(result:Application() & Report) -> IO(Application()):
  match result:
    case (app,Finished{events}):
      do IO<Application()>:
        require_success(events)
        return app
    case _:IO.die(Application(),1,"scene schedule refused")

def tick(app:Application()) -> IO(Application()):checked(run(app))
