import Base
import ./scene-hierarchy.bend as Hierarchy
import ./hierarchy.bend as H
import ./scene-draw.bend as Draw
import ./components.bend as C
import ./creation.bend as Create
import ./scene-schema.bend as D
import ./scene-runtime.bend as Scene
import ./scene-spawn.bend as Spawn
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/inspector.bend as I
import ../deps/bendvy/src/ecs/schedule.bend as Schedule
import ../deps/bendvy/src/ecs/change-tick.bend as Tick
import ../deps/bendvy/src/ecs/inspector-query.bend as Query
import ../deps/bendvy/src/ecs/inspector-query-projection.bend as Rows
import ../deps/bendvy/src/ecs/component.bend as Component
import ../deps/bendvy/src/ecs/capabilities.bend as Cap

type Reads<-H:Type> is Type:
  Reads{transforms:Query.ReadQuery<H,D.Schema,C.Transform>,mesh:I.Lookup<H,D.Schema,C.MeshRef>}

type Row is Data:Row{handle:W.Handle<D.Schema>,transform:C.Transform,mesh:C.MeshRef}

type Snapshot is Data:
  Snapshot{live:List<&2,W.Handle<D.Schema>>,admitted:List<&2,W.Handle<D.Schema>>,exhausted:Bool,clean:Bool,rows:List<&2,Row>}

def Ops(H:Type) -> Type:Reads<H>

def plan() -> I.Plan<D.Schema,D.Store,Unit,Unit,Ops>:
  I.Plan{Reads{Query.grant(~D.Schema,~D.Store,~Unit,~Unit,~D.TransformRest(),~C.Transform,~C.Transform,~D.TransformToken,~D.take_transform,~D.put_transform,~D.transform,~D.transform_family(),~Rows.Required{}),I.read_family(~D.Schema,~D.Store,~Unit,~Unit,~D.MeshRest(),~C.MeshRef,~C.MeshRef,~D.MeshToken,~D.take_mesh,~D.put_mesh,~D.mesh,~D.mesh_family())}}

def mesh_read(~H:Type,caps:Ops(H)) -> H -> W.Handle<D.Schema> -> H & I.Value<C.MeshRef>:
  match caps:
    case Reads{_,I.Lookup{read}}:read

def transform_rows(~H:Type,caps:Ops(H)) -> H -> H & List<&2,Rows.Row<D.Schema,C.Transform>>:
  match caps:
    case Reads{Query.ReadQuery{Cap.ValueRead{read},_,_},_}:read

def row(handle:W.Handle<D.Schema>,value:C.Transform,mesh:C.MeshRef) -> Row:Row{handle,value,mesh}

def found_mesh(~Out:Data,~project:W.Handle<D.Schema> -> C.Transform -> C.MeshRef -> Out,~H:Type,
  next:H -> List<&2,Out> -> H & Result<&2,&2,Unit,List<&2,Out>>,handle:W.Handle<D.Schema>,
  value:C.Transform,rows:List<&2,Out>,result:H & I.Value<C.MeshRef>) -> H & Result<&2,&2,Unit,List<&2,Out>>:
  match result:
    case (frame,I.Value{Component.Found{mesh},_,_}):next(frame,project(handle,value,mesh) <> rows)
    case (frame,_):(frame,Fail{Unit{}})

def values(~Out:Data,~project:W.Handle<D.Schema> -> C.Transform -> C.MeshRef -> Out,~H:Type,
  ~get:H -> W.Handle<D.Schema> -> H & I.Value<C.MeshRef>,rows:List<&2,Rows.Row<D.Schema,
  C.Transform>>,frame:H,acc:List<&2,Out>) -> H & Result<&2,&2,Unit,List<&2,Out>>:
  match rows:
    case []:(frame,Done{List.reverse(&2,Out,acc)})
    case Rows.Row{+handle,I.Value{Component.Found{value},_,_}} <> rest:found_mesh(~Out,~project,~H,
      values(~Out,~project,~H,~get,rest),handle,value,acc,get(frame,handle))
    case _:(frame,Fail{Unit{}})

def selected(~Out:Data,~project:W.Handle<D.Schema> -> C.Transform -> C.MeshRef -> Out,~H:Type,
  ~get:H -> W.Handle<D.Schema> -> H & I.Value<C.MeshRef>,result:H & List<&2,Rows.Row<D.Schema,
  C.Transform>>) -> H & Result<&2,&2,Unit,List<&2,Out>>:
  match result:
    case (frame,rows):values(~Out,~project,~H,~get,rows,frame,[])

def body(~Out:Data,~project:W.Handle<D.Schema> -> C.Transform -> C.MeshRef -> Out,~H:Type,~caps:Ops(H),
  _:Unit,frame:H) -> H & Result<&2,&2,Unit,List<&2,Out>>:
  selected(~Out,~project,~H,~mesh_read(~H,caps),transform_rows(~H,caps)(frame))

# Passive extraction uses canonical Inspector grants and preserves both clocks
# and the caller's cursor. I.run is the separate advancing inspector operation.
def passive_returned(instance:I.Instance<D.Schema>,pair:I.Frame<D.Schema,D.Store,Unit,Unit> & Result<&2,&2,Unit,List<&2,Row>>) -> I.Observed<D.Schema,D.Store,Unit,Unit,Unit,List<&2,Row>>:
  (I.Frame{world,_},result) = pair
  I.Observed{world,instance,result}

def passive_frame(instance:I.Instance<D.Schema>,world:D.World(),cursor:Maybe<&2,Tick.Tick>) -> I.Observed<D.Schema,D.Store,Unit,Unit,Unit,List<&2,Row>>:
  passive_returned(instance,Cap.invoke(~Ops,~Unit,~Result<&2,&2,Unit,List<&2,Row>>,~body(~Row,~row),~I.Frame<D.Schema,D.Store,Unit,Unit>,~I.plan_caps(~D.Schema,~D.Store,~Unit,~Unit,~Ops,plan()),Unit{},I.Frame{world,cursor}))

def passive(instance:I.Instance<D.Schema>,world:D.World()) -> I.Observed<D.Schema,D.Store,Unit,Unit,Unit,List<&2,Row>>:
  match instance:
    case I.Fresh{}:passive_frame(I.Fresh{},world,None{})
    case I.Active{+cursor,registered}:passive_frame(I.Active{cursor,registered},world,cursor)

def observed(rebuild:D.World() -> Scene.Application(),admitted:List<&2,W.Handle<D.Schema>>,exhausted:Bool,clean:Bool,live:List<&2,W.Handle<D.Schema>>,result:I.Observed<D.Schema,D.Store,Unit,Unit,Unit,List<&2,Row>>) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Snapshot>):
  match result:
    case I.Observed{world,instance,Done{rows}}:(rebuild(world),(instance,Done{Snapshot{live,admitted,exhausted,clean,rows}}))
    case I.Observed{world,instance,Fail{error}}:(rebuild(world),(instance,Fail{error}))

def live_observed(rebuild:D.World() -> Scene.Application(),admitted:List<&2,W.Handle<D.Schema>>,exhausted:Bool,clean:Bool,instance:I.Instance<D.Schema>,pair:D.World() & List<&2,W.Handle<D.Schema>>) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Snapshot>):
  (world,live) = pair
  observed(rebuild,admitted,exhausted,clean,live,passive(instance,world))

def exhausted(seeds:List<&2,Create.Seed>) -> Bool:
  match seeds:
    case []:True{}
    case _:False{}

def drained(world:D.World()) -> D.World() & Bool:
  match world:
    case W.World{ns,a,c,r,e,[],regs,next,clock}:(W.World{ns,a,c,r,e,[],regs,next,clock},True{})
    case world:(world,False{})

def checked_pending(rebuild:D.World() -> Scene.Application(),admitted:List<&2,W.Handle<D.Schema>>,done:Bool,clean:Bool,instance:I.Instance<D.Schema>,pair:D.World() & Bool) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Snapshot>):
  (world,empty) = pair
  +done:Bool = done
  live_observed(rebuild,admitted,done,done && clean && empty,instance,W.handles(~D.Schema,~D.Store,~Unit,~Unit,world))

def snapshot(app:Scene.Application(),instance:I.Instance<D.Schema>) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Snapshot>):
  match app:
    case Scene.Application{world,Schedule.Schedule{ns,name,steps,Scene.Owners{left,right,Spawn.User{+seeds,+handles,+returned},mode}}}:
      checked_pending(world => Scene.Application{world,Schedule.Schedule{ns,name,steps,Scene.Owners{left,right,Spawn.User{seeds,handles,returned},mode}}},handles,exhausted(seeds),exhausted(returned),instance,drained(world))

def draw_item(_:W.Handle<D.Schema>,value:C.Transform,mesh:C.MeshRef) -> Draw.DrawItem:
  Draw.DrawItem{value,mesh}

def drawn(rebuild:D.World() -> Scene.Application(),instance:I.Instance<D.Schema>,result:D.World() & Result<&2,&2,Unit,Draw.DrawList>) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Draw.DrawList>):
  (world,result) = result
  (rebuild(world),(instance,result))

def draw_list(app:Scene.Application(),instance:I.Instance<D.Schema>) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Draw.DrawList>):
  Scene.Application{world,schedule} = app
  drawn(world => Scene.Application{world,schedule},instance,Hierarchy.draw_list(world))

def spatial_read(rebuild:D.World() -> Scene.Application(),pair:D.World() & Result<&2,&2,H.Error,List<&2,Hierarchy.Row>>) -> Scene.Application() & Result<&2,&2,H.Error,List<&2,Hierarchy.Row>>:
  (world,result) = pair
  (rebuild(world),result)

def spatial(app:Scene.Application()) -> Scene.Application() & Result<&2,&2,H.Error,List<&2,Hierarchy.Row>>:
  Scene.Application{world,schedule} = app
  spatial_read(world => Scene.Application{world,schedule},Hierarchy.read(world))
