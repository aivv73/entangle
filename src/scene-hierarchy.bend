import Base
import ./hierarchy.bend as H
import ./components.bend as C
import ./scene-schema.bend as D
import ./scene-draw.bend as Draw
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/change-tick.bend as Tick

type Row is Data:
  Row{entity:W.Handle<D.Schema>,transform:C.Transform,mesh:C.MeshRef,spatial:H.Spatial}
type Edit is Data:
  Propagate{}
  SetTransform{entity:W.Handle<D.Schema>,transform:C.Transform}
  SetParent{entity:W.Handle<D.Schema>,parent:Maybe<&2,W.Handle<D.Schema>>}

def Scope() -> Type:D.World()

def mesh_read(next:Scope() -> List<&2,Row> -> Scope() & Result<&2,&2,H.Error,List<&2,Row>>,entity:W.Handle<D.Schema>,t:C.Transform,s:H.Spatial,acc:List<&2,Row>,result:Scope() & Maybe<&2,C.MeshRef>) -> Scope() & Result<&2,&2,H.Error,List<&2,Row>>:
  match result:
    case (frame,Some{m}):next(frame,Row{entity,t,m,s} <> acc)
    case (frame,_):(frame,Fail{H.MissingEntity{}})

def spatial_read(next:Scope() -> List<&2,Row> -> Scope() & Result<&2,&2,H.Error,List<&2,Row>>,+entity:W.Handle<D.Schema>,t:C.Transform,acc:List<&2,Row>,result:Scope() & Maybe<&2,H.Spatial>) -> Scope() & Result<&2,&2,H.Error,List<&2,Row>>:
  match result:
    case (frame,Some{s}):mesh_read(next,entity,t,s,acc,D.read_mesh(frame,entity))
    case (frame,_):(frame,Fail{H.MissingEntity{}})

def transform_read(next:Scope() -> List<&2,Row> -> Scope() & Result<&2,&2,H.Error,List<&2,Row>>,+entity:W.Handle<D.Schema>,acc:List<&2,Row>,result:Scope() & Maybe<&2,C.Transform>) -> Scope() & Result<&2,&2,H.Error,List<&2,Row>>:
  match result:
    case (frame,Some{t}):spatial_read(next,entity,t,acc,D.read_spatial(frame,entity))
    case (frame,_):(frame,Fail{H.MissingEntity{}})

def read_rows(entities:List<&2,W.Handle<D.Schema>>,frame:Scope(),acc:List<&2,Row>) -> Scope() & Result<&2,&2,H.Error,List<&2,Row>>:
  match entities:
    case []:(frame,Done{List.reverse(&2,Row,acc)})
    case +entity <> rest:transform_read(read_rows(rest),entity,acc,D.read_transform(frame,entity))

def read_handles(pair:D.World() & List<&2,W.Handle<D.Schema>>) -> D.World() & Result<&2,&2,H.Error,List<&2,Row>>:
  (world,handles) = pair
  read_rows(handles,world,[])

# Read canonical live components through their schema-bound families.
def read(world:D.World()) -> D.World() & Result<&2,&2,H.Error,List<&2,Row>>:
  read_handles(W.handles(~D.Schema,~D.Store,~Unit,~Unit,world))

def index(rows:List<&2,Row>,+entity:W.Handle<D.Schema>,+n:U32) -> Result<&2,&2,H.Error,U32>:
  match rows:
    case []:Fail{H.MissingEntity{}}
    case Row{other,_,_,_} <> rest:Bool.pick(Result<&2,&2,H.Error,U32>,D.same(entity,other),Done{n},index(rest,entity,U32.inc(n)))

def parent_index(parent:Maybe<&2,W.Handle<D.Schema>>,rows:List<&2,Row>) -> Result<&2,&2,H.Error,Maybe<&2,U32>>:
  match parent:
    case None{}:Done{None{}}
    case Some{entity}:
      do Result<&2,&2,H.Error,Maybe<&2,U32>>:
        n:U32 <- index(rows,entity,0)
        return Some{n}

def locals(rows:List<&2,Row>) -> List<&2,H.Local>:
  match rows:
    case []:[]
    case Row{_,t,_,s} <> rest:H.with_transform(t,s) <> locals(rest)

def replace_transform(items:List<&2,H.Local>,index:Nat,+value:C.Transform) -> List<&2,H.Local>:
  match items index:
    case H.Local{_,p,b,l} <> rest,0n:H.Local{value,p,b,l} <> rest
    case item <> rest,1n+n:item <> replace_transform(rest,n,value)
    case [] _:[]

def replace_parent(items:List<&2,H.Local>,index:Nat,+parent:Maybe<&2,U32>) -> List<&2,H.Local>:
  match items index:
    case H.Local{t,_,b,l} <> rest,0n:H.Local{t,parent,b,l} <> rest
    case item <> rest,1n+n:item <> replace_parent(rest,n,parent)
    case [] _:[]

def candidate(edit:Edit,+rows:List<&2,Row>) -> Result<&2,&2,H.Error,List<&2,H.Local>>:
  match edit:
    case Propagate{}:Done{locals(rows)}
    case SetTransform{entity,t}:
      do Result<&2,&2,H.Error,List<&2,H.Local>>:
        n:U32 <- index(rows,entity,0)
        return replace_transform(locals(rows),U32.to_nat(n),t)
    case SetParent{entity,parent}:
      do Result<&2,&2,H.Error,List<&2,H.Local>>:
        n:U32 <- index(rows,entity,0)
        p:Maybe<&2,U32> <- parent_index(parent,rows)
        return replace_parent(locals(rows),U32.to_nat(n),p)

def rollback(rows:List<&2,Row>) -> List<&2,H.Spatial>:
  match rows:
    case []:[]
    case Row{_,_,_,s} <> rest:s <> rollback(rest)

def written(pair:D.World() & Bool) -> D.World():
  (world,_) = pair
  world

def transformed(scope:Scope(),entity:W.Handle<D.Schema>,value:C.Transform) -> Scope():
  written(D.write_transform(scope,entity,value))

def spatial(scope:Scope(),entity:W.Handle<D.Schema>,value:H.Spatial) -> Scope():
  written(D.write_spatial(scope,entity,value))

# Handles and columns were read from this exclusively owned world. No structural
# operation runs between read and commit, so these canonical writes cannot miss.
def install(rows:List<&2,Row>,values:List<&2,H.Spatial>,scope:Scope()) -> Scope():
  match rows values:
    case Row{+entity,_,_,_} <> rest,+value <> tail:
      H.Spatial{H.Local{t,_,_,_},_,_} = value
      install(rest,tail,spatial(transformed(scope,entity,t),entity,value))
    case _ _:scope

def commit_scope(rows:List<&2,Row>,values:List<&2,H.Spatial>,pair:D.World() & Bool) -> D.World():
  (world,owned) = pair
  W.finish_run(~D.Schema,~D.Store,~Unit,~Unit,owned,install(rows,values,world))

def commit(world:D.World(),rows:List<&2,Row>,values:List<&2,H.Spatial>) -> D.World():
  commit_scope(rows,values,W.ensure_run(~D.Schema,~D.Store,~Unit,~Unit,world))

def rejected(edit:Edit,world:D.World(),+rows:List<&2,Row>,error:H.Error) -> D.World() & Result<&2,&2,H.Error,Unit>:
  match edit:
    case Propagate{}:(commit(world,rows,rollback(rows)),Fail{error})
    case _:(world,Fail{error})

def evaluated(edit:Edit,world:D.World(),rows:List<&2,Row>,result:Result<&2,&2,H.Error,List<&2,H.Spatial>>) -> D.World() & Result<&2,&2,H.Error,Unit>:
  match result:
    case Fail{e}:rejected(edit,world,rows,e)
    case Done{values}:(commit(world,rows,values),Done{Unit{}})

def prepared(+edit:Edit,result:D.World() & Result<&2,&2,H.Error,List<&2,Row>>) -> D.World() & Result<&2,&2,H.Error,Unit>:
  match result:
    case (world,Fail{e}):(world,Fail{e})
    case (world,Done{+rows}):evaluated(edit,world,rows,Result.bind(&2,&2,H.Error,List<&2,H.Local>,List<&2,H.Spatial>,candidate(edit,rows),xs => H.evaluate(xs)))

def update(world:D.World(),edit:Edit) -> D.World() & Result<&2,&2,H.Error,Unit>:
  prepared(edit,read(world))

def propagated(pair:D.World() & Result<&2,&2,H.Error,Unit>) -> D.World():
  (world,_) = pair
  world

def propagate(world:D.World()) -> D.World():propagated(update(world,Propagate{}))

def drawing(row:Row) -> Draw.DrawItem:
  Row{_,t,mesh,H.Spatial{H.Local{_,parent,_,_},global,_}} = row
  Draw.item(parent,t,mesh,global)

def draw_rows(rows:List<&2,Row>) -> List<&2,Draw.DrawItem>:
  match rows:
    case []:[]
    case row <> rest:drawing(row) <> draw_rows(rest)

def drawn(result:D.World() & Result<&2,&2,H.Error,List<&2,Row>>) -> D.World() & Result<&2,&2,Unit,Draw.DrawList>:
  match result:
    case (world,Fail{_}):(world,Fail{Unit{}})
    case (world,Done{rows}):(world,Done{Draw.DrawList{draw_rows(rows)}})

def draw_list(world:D.World()) -> D.World() & Result<&2,&2,Unit,Draw.DrawList>:
  drawn(read(world))
