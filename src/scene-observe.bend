import Base
import ./components.bend as C
import ./scene-schema.bend as D
import ./scene.bend as Scene
import ./scene-spawn.bend as Spawn
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/inspector.bend as I
import ../deps/bendvy/src/ecs/inspector-query.bend as Query
import ../deps/bendvy/src/ecs/inspector-query-projection.bend as Rows
import ../deps/bendvy/src/ecs/execution-inspector-component.bend as Columns
import ../deps/bendvy/src/ecs/execution-composer-layout.bend as L
import ../deps/bendvy/src/ecs/component.bend as Component
import ../deps/bendvy/src/ecs/capabilities.bend as Cap
import ../deps/bendvy/src/ecs/execution-schedule.bend as Scheduled
import ../deps/bendvy/src/ecs/dependency-application.bend as App
import ../deps/bendvy/src/ecs/dependency-registration.bend as Reg
import ../deps/bendvy/src/ecs/execution-retained-system.bend as Retained
import ../deps/bendvy/src/ecs/execution-command-system.bend as Cmd
import ../deps/bendvy/src/ecs/execution-system.bend as Sys
import ../deps/bendvy/src/ecs/execution-command-local.bend as Local
import ../deps/bendvy/src/ecs/execution-command-buffer.bend as Buffer
import ../deps/bendvy/src/ecs/execution-command-removed.bend as Removed
import ../deps/bendvy/src/ecs/owner-product.bend as Product

type Reads<-H:Type> is Type:
  Reads{transforms:Query.ReadQuery<H,D.Schema,C.Transform>,mesh:I.Lookup<H,D.Schema,C.MeshRef>}

type Row is Data:Row{handle:W.Handle<D.Schema>,transform:C.Transform,mesh:C.MeshRef}

type Snapshot is Data:
  Snapshot{live:List<&2,W.Handle<D.Schema>>,admitted:List<&2,W.Handle<D.Schema>>,exhausted:Bool,clean:Bool,rows:List<&2,Row>}

def Ops(H:Type) -> Type:Reads<H>

def plan() -> I.Plan<D.Schema,D.Columns(),D.Resources(),Unit,Ops>:
  I.Plan{Reads{Columns.query(~D.Schema,~D.Columns(),~D.Resources(),~Unit,~D.components(),~L.InLeft{L.AtLeaf{}},
    ~{==},~{==},~Rows.Required{}),Columns.lookup(~D.Schema,~D.Columns(),~D.Resources(),~Unit,~D.components(),
    ~L.InRight{L.AtLeaf{}},~{==},~{==})}}

def mesh_read(~H:Type,caps:Ops(H)) -> H -> W.Handle<D.Schema> -> H & I.Value<C.MeshRef>:
  match caps:
    case Reads{_,I.Lookup{read}}:read

def transform_rows(~H:Type,caps:Ops(H)) -> H -> H & List<&2,Rows.Row<D.Schema,C.Transform>>:
  match caps:
    case Reads{Query.ReadQuery{Cap.ValueRead{read},_,_},_}:read

def found_mesh(~H:Type,next:H -> List<&2,Row> -> H & Result<&2,&2,Unit,List<&2,Row>>,handle:W.Handle<D.Schema>,
  value:C.Transform,rows:List<&2,Row>,result:H & I.Value<C.MeshRef>) -> H & Result<&2,&2,Unit,List<&2,Row>>:
  match result:
    case (frame,I.Value{Component.Found{mesh},_,_}):next(frame,Row{handle,value,mesh} <> rows)
    case (frame,_):(frame,Fail{Unit{}})

def values(~H:Type,~get:H -> W.Handle<D.Schema> -> H & I.Value<C.MeshRef>,rows:List<&2,Rows.Row<D.Schema,
  C.Transform>>,frame:H,acc:List<&2,Row>) -> H & Result<&2,&2,Unit,List<&2,Row>>:
  match rows:
    case []:(frame,Done{List.reverse(&2,Row,acc)})
    case Rows.Row{+handle,I.Value{Component.Found{value},_,_}} <> rest:found_mesh(~H,values(~H,~get,rest),
      handle,value,acc,get(frame,handle))
    case _:(frame,Fail{Unit{}})

def selected(~H:Type,~get:H -> W.Handle<D.Schema> -> H & I.Value<C.MeshRef>,result:H & List<&2,Rows.Row<D.Schema,
  C.Transform>>) -> H & Result<&2,&2,Unit,List<&2,Row>>:
  match result:
    case (frame,rows):values(~H,~get,rows,frame,[])

def body(~H:Type,~caps:Ops(H),_:Unit,frame:H) -> H & Result<&2,&2,Unit,List<&2,Row>>:
  selected(~H,~mesh_read(~H,caps),transform_rows(~H,caps)(frame))

def Receipt() -> Type:Buffer.Receipt<D.Schema,C.Transform,Removed.Removed(D.components())>

def receipt_tail(head:Receipt(),result:List<Receipt()> & Bool) -> List<Receipt()> & Bool:
  match result:
    case (rest,ok):(head <> rest,ok)

def receipts(values:List<Receipt()>) -> List<Receipt()> & Bool:
  match values:
    case []:([],True{})
    case Buffer.Spawned{handle,Product.Owner{None{},None{}}} <> rest:receipt_tail(Buffer.Spawned{handle,
      Product.Owner{None{},None{}}},receipts(rest))
    case head <> tail:(head <> tail,False{})

def receipt_checked(restore:List<Receipt()> -> Scene.Owner(),handles:List<&2,W.Handle<D.Schema>>,result:List<Receipt()> & Bool) -> Scene.Owner() & (List<&2,
  W.Handle<D.Schema>> & (Bool & Bool)):
  match result:
    case (applied,ok):(restore(applied),(handles,(True{},ok)))

def bootstrap(owner:Scene.Owner()) -> Scene.Owner() & (List<&2,W.Handle<D.Schema>> & (Bool & Bool)):
  match owner:
    case Cmd.Owner{Sys.Owner{ns,id,name,access,cursor,Local.Local{Spawn.User{[],+handles,[]},Buffer.Buffer{[],applied},permission}}}:
      receipt_checked(applied => Cmd.Owner{Sys.Owner{ns,id,name,access,cursor,Local.Local{Spawn.User{[],
        handles,[]},Buffer.Buffer{[],applied},permission}}},handles,receipts(applied))
    case Cmd.Owner{Sys.Owner{ns,id,name,access,cursor,Local.Local{Spawn.User{seeds,+handles,returned},commands,permission}}}:
      (Cmd.Owner{Sys.Owner{ns,id,name,access,cursor,Local.Local{Spawn.User{seeds,handles,returned},commands,
        permission}}},(handles,(False{},False{})))

def observed(rebuild:D.World() -> Scene.Application(),live:List<&2,W.Handle<D.Schema>>,admitted:List<&2,
  W.Handle<D.Schema>>,exhausted:Bool,clean:Bool,result:I.Observed<D.Schema,D.Columns(),D.Resources(),
  Unit,Unit,List<&2,Row>>) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Snapshot>):
  match result:
    case I.Observed{world,instance,Done{rows}}:(rebuild(world),(instance,Done{Snapshot{live,admitted,
      exhausted,clean,rows}}))
    case I.Observed{world,instance,Fail{error}}:(rebuild(world),(instance,Fail{error}))

def live_observed(rebuild:D.World() -> Scene.Application(),admitted:List<&2,W.Handle<D.Schema>>,exhausted:Bool,
  clean:Bool,instance:I.Instance<D.Schema>,result:D.World() & List<&2,W.Handle<D.Schema>>) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,
  &2,Unit,Snapshot>):
  match result:
    case (world,live):observed(rebuild,live,admitted,exhausted,clean,I.passive(~D.Schema,~D.Columns(),
      ~D.Resources(),~Unit,~Ops,~Unit,~Unit,~(List<&2,Row>),~plan(),~body,instance,Unit{},world))

def bootstrap_observed(rebuild:Spawn.Node() -> D.World() -> Scene.Application(),world:D.World(),instance:I.Instance<D.Schema>,
  result:Spawn.Node() & (List<&2,W.Handle<D.Schema>> & (Bool & Bool))) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,
  &2,Unit,Snapshot>):
  match result:
    case (left,(admitted,(exhausted,clean))):live_observed(rebuild(left),admitted,exhausted,clean,instance,
      W.handles(~D.Schema,~D.Columns(),~D.Resources(),~Unit,world))

def snapshot(app:Scene.Application(),instance:I.Instance<D.Schema>) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,
  &2,Unit,Snapshot>):
  match app:
    case Scheduled.Scheduled{App.State{world,Reg.Product{left,right,routing},guards,handler,stateBindings},settings,bindings,deferred}:
      bootstrap_observed(left => world => Scheduled.Scheduled{App.State{world,Reg.Product{left,right,
        routing},guards,handler,stateBindings},settings,bindings,deferred},world,instance,Retained.map_owner(Scene.Compilation(),
        Scene.Owner(),List<&2,W.Handle<D.Schema>> & (Bool & Bool),bootstrap,left))
