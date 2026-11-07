import Base
import ../../deps/bendvy/src/ecs/owner-product.bend as Product
import ../../deps/bendvy/src/ecs/chunk-column.bend as Col
import ../../deps/bendvy/src/ecs/lifecycle.bend as Life
import ../../deps/bendvy/src/ecs/execution-state.bend as State
import ../../deps/bendvy/src/ecs/execution-lifecycle-notices.bend as Notice
import ../../deps/bendvy/src/ecs/entity-key.bend as Key
import ../../deps/bendvy/src/ecs/change-tick.bend as Tick
import ../../src/hierarchy.bend as H
import ../../src/scene-hierarchy.bend as S
import ../../src/components.bend as C
import ../../src/scene-schema.bend as D
import ../../deps/bendvy/src/ecs/world.bend as W
import ../../deps/bendvy/src/ecs/execution-layout-access.bend as Write
import ../../deps/bendvy/src/ecs/execution-composer-layout.bend as L

def length_result(result:Result<&2,&1,H.Error,List<&2,H.Spatial>>,size:Nat) -> Type:
  match result:
    case Fail{_}:Unit
    case Done{values}:{List.length(&2,H.Spatial,values) == size : Nat}

def reusable_length(result:Result<&2,&2,H.Error,List<&2,H.Spatial>>,size:Nat) -> Type:
  match result:
    case Fail{_}:Unit
    case Done{values}:{List.length(&2,H.Spatial,values) == size : Nat}

# Proof-only, duplicable storage descriptions. Every edge is checked against
# Array.get/set themselves; these trees never execute in the engine.
type Tree is Data:
  Leaf{mark:H.Mark}
  Node{left:Tree,right:Tree}

def thaw(tree:Tree) -> Array<H.Mark>:
  match tree:
    case Leaf{mark}:ALeaf{mark}
    case Node{left,right}:ANode{thaw(left),thaw(right)}

type Forest is Data:
  Root{read:Tree,local:H.Local,after:Tree,value:H.Spatial}
  Cached{read:Tree,value:H.Spatial}
  Child{read:Tree,local:H.Local,parent:U32,entered:Tree,ancestor:Forest,after:Tree,value:H.Spatial}

def final(forest:Forest) -> Tree:
  match forest:
    case Root{_,_,after,_}:after
    case Cached{read,_}:read
    case Child{_,_,_,_,_,after,_}:after

def value(forest:Forest) -> H.Spatial:
  match forest:
    case Root{_,_,_,value}:value
    case Cached{_,value}:value
    case Child{_,_,_,_,_,_,value}:value

def spatial_global(spatial:H.Spatial) -> H.GlobalTransform:
  H.Spatial{_,global,_} = spatial
  global

def global(forest:Forest) -> H.GlobalTransform:spatial_global(value(forest))

def parent(local:H.Local) -> Maybe<&2,U32>:
  H.Local{_,parent,_,_} = local
  parent

def admitted(fuel:Nat,+forest:Forest,+count:U32,+index:U32,+before:Tree) -> Type:
  match fuel forest:
    case 0n _:Empty
    case 1n+_ Root{+read,+local,+after,+spatial}:
      {U32.is_lt(index,count) == True{} : Bool} &
      ({Array.get(H.Mark,thaw(before),index) == (thaw(read),H.Pending{local}) : Array<H.Mark> & H.Mark} &
      ({parent(local) == None{} : Maybe<&2,U32>} &
      ({H.derive(local,None{},index) == Done{spatial} : Result<&2,&2,H.Error,H.Spatial>} &
       {Array.set(H.Mark,thaw(read),index,H.Finished{spatial}) == thaw(after) : Array<H.Mark>})))
    case 1n+_ Cached{+read,+spatial}:
      {U32.is_lt(index,count) == True{} : Bool} &
      {Array.get(H.Mark,thaw(before),index) == (thaw(read),H.Finished{spatial}) : Array<H.Mark> & H.Mark}
    case 1n+rest Child{+read,+local,+p,+entered,+ancestor,+after,+spatial}:
      {U32.is_lt(index,count) == True{} : Bool} &
      ({Array.get(H.Mark,thaw(before),index) == (thaw(read),H.Pending{local}) : Array<H.Mark> & H.Mark} &
      ({parent(local) == Some{p} : Maybe<&2,U32>} &
      ({Array.set(H.Mark,thaw(read),index,H.Visiting{}) == thaw(entered) : Array<H.Mark>} &
      (admitted(rest,ancestor,count,p,entered) &
      ({H.derive(local,Some{global(ancestor)},index) == Done{spatial} : Result<&2,&2,H.Error,H.Spatial>} &
       {Array.set(H.Mark,thaw(final(ancestor)),index,H.Finished{spatial}) == thaw(after) : Array<H.Mark>})))))

type Rejection is Data:
  Exhausted{}
  Outside{}
  BackEdge{read:Tree}
  Through{read:Tree,local:H.Local,parent:U32,entered:Tree,ancestor:Rejection}

def error(path:Rejection,+index:U32) -> H.Error:
  match path:
    case Exhausted{}:H.Cycle{index}
    case Outside{}:H.MissingParent{index}
    case BackEdge{_}:H.Cycle{index}
    case Through{_,_,p,_,ancestor}:error(ancestor,p)

def rejected(fuel:Nat,+path:Rejection,+count:U32,+index:U32,+before:Tree) -> Type:
  match fuel path:
    case 0n Exhausted{}:Unit
    case 1n+_ Outside{}:{U32.is_lt(index,count) == False{} : Bool}
    case 1n+_ BackEdge{+read}:
      {U32.is_lt(index,count) == True{} : Bool} &
      {Array.get(H.Mark,thaw(before),index) == (thaw(read),H.Visiting{}) : Array<H.Mark> & H.Mark}
    case 1n+rest Through{+read,+local,+p,+entered,+ancestor}:
      {U32.is_lt(index,count) == True{} : Bool} &
      ({Array.get(H.Mark,thaw(before),index) == (thaw(read),H.Pending{local}) : Array<H.Mark> & H.Mark} &
      ({parent(local) == Some{p} : Maybe<&2,U32>} &
      ({Array.set(H.Mark,thaw(read),index,H.Visiting{}) == thaw(entered) : Array<H.Mark>} &
       rejected(rest,ancestor,count,p,entered))))
    case _ _:Empty

def sequence_values(forests:List<&2,Forest>) -> List<&2,H.Spatial>:
  match forests:
    case []:[]
    case forest <> rest:value(forest) <> sequence_values(rest)

def sequence_valid(+fuel:Nat,+count:U32,+index:U32,+before:Tree,forests:List<&2,Forest>) -> Type:
  match forests:
    case []:Unit
    case +forest <> rest:admitted(fuel,forest,count,index,before) & sequence_valid(fuel,count,U32.inc(index),final(forest),rest)


def transform(spatial:H.Spatial) -> C.Transform:
  H.Spatial{H.Local{t,_,_,_},_,_} = spatial
  t

def transform_write(scope:S.Scope(),entity:W.Handle<D.Schema>,+value:C.Transform) -> S.Scope() & Maybe<&2,C.Transform>:
  Write.component_modify(~D.Schema,~D.Columns(),~D.Resources(),~D.components(),~L.InLeft{L.AtLeaf{}},~{==},_ => (value,value))(scope,entity)

def spatial_write(scope:S.Scope(),entity:W.Handle<D.Schema>,+value:H.Spatial) -> S.Scope() & Maybe<&2,H.Spatial>:
  Write.component_modify(~D.Schema,~D.Columns(),~D.Resources(),~D.components(),~L.InRight{L.InRight{L.AtLeaf{}}},~{==},_ => (value,value))(scope,entity)

type Batch is Data:
  EmptyBatch{}
  Pair{row:S.Row,value:H.Spatial,rest:Batch}

def rows(batch:Batch) -> List<&2,S.Row>:
  match batch:
    case EmptyBatch{}:[]
    case Pair{row,_,rest}:row <> rows(rest)

def values(batch:Batch) -> List<&2,H.Spatial>:
  match batch:
    case EmptyBatch{}:[]
    case Pair{_,value,rest}:value <> values(rest)

def entity(row:S.Row) -> W.Handle<D.Schema>:
  S.Row{entity,_,_,_} = row
  entity

# A certificate checks the optional results which install itself discards.
# It is NOT a theorem that read constructs this certificate.
def ready(batch:Batch,-before:S.Scope(),-after:S.Scope()) -> Type:
  match batch:
    case EmptyBatch{}:{before == after : S.Scope()}
    case Pair{+row,+value,rest}:
      Sigma<&1,&1,S.Scope(),middle => Sigma<&1,&1,S.Scope(),next =>
        {transform_write(before,entity(row),transform(value)) == (middle,Some{transform(value)}) : S.Scope() & Maybe<&2,C.Transform>} &
        ({spatial_write(middle,entity(row),value) == (next,Some{value}) : S.Scope() & Maybe<&2,H.Spatial>} & ready(rest,next,after))>>

def candidate_length(result:Result<&2,&2,H.Error,List<&2,H.Local>>,size:Nat) -> Type:
  match result:
    case Fail{_}:Unit
    case Done{items}:{List.length(&2,H.Local,items) == size : Nat}

# Real schema qualification: eight cells with a distinct replacement at slot 0.
def cells(-A:Data,+first:A,+rest:A) -> Array<Maybe<&1,L.Viewed<A,A>>>:
  ANode{ANode{ANode{ALeaf{Some{L.Viewed{first,first}}},ALeaf{Some{L.Viewed{rest,rest}}}},ANode{ALeaf{Some{L.Viewed{rest,rest}}},ALeaf{Some{L.Viewed{rest,rest}}}}},ANode{ANode{ALeaf{Some{L.Viewed{rest,rest}}},ALeaf{Some{L.Viewed{rest,rest}}}},ANode{ALeaf{Some{L.Viewed{rest,rest}}},ALeaf{Some{L.Viewed{rest,rest}}}}}}

def stamps(+first:Life.Stamp,+rest:Life.Stamp) -> Array<Life.Stamp>:
  ANode{ANode{ANode{ALeaf{first},ALeaf{rest}},ANode{ALeaf{rest},ALeaf{rest}}},ANode{ANode{ALeaf{rest},ALeaf{rest}},ANode{ALeaf{rest},ALeaf{rest}}}}

def handle() -> W.Handle<D.Schema>:W.Handle{1,Key.EntityKey{1,1}}

def scope(+old:C.Transform,+mesh:C.MeshRef,+accepted:H.Spatial,+stamp:Life.Stamp,+tick:Tick.Tick) -> S.Scope():
  State.Scope{Product.Owner{L.ColumnSlot{Col.Leaf{cells(C.Transform,old,old),stamps(stamp,stamp)}},Product.Owner{L.ColumnSlot{Col.Leaf{cells(C.MeshRef,mesh,mesh),stamps(stamp,stamp)}},L.ColumnSlot{Col.Leaf{cells(H.Spatial,accepted,accepted),stamps(stamp,stamp)}}}},Unit{},[handle()],tick,None{},Notice.View{1,[],[]}}

def changed_scope(+old:C.Transform,+mesh:C.MeshRef,+accepted:H.Spatial,+stamp:Life.Stamp,+tick:Tick.Tick,+fresh:H.Spatial,+spatial:Bool) -> S.Scope():
  State.Scope{Product.Owner{L.ColumnSlot{Col.Leaf{cells(C.Transform,transform(fresh),old),stamps(Life.written(True{},stamp,tick),stamp)}},Product.Owner{L.ColumnSlot{Col.Leaf{cells(C.MeshRef,mesh,mesh),stamps(stamp,stamp)}},L.ColumnSlot{Col.Leaf{cells(H.Spatial,Bool.pick(H.Spatial,spatial,fresh,accepted),accepted),stamps(Bool.pick(Life.Stamp,spatial,Life.written(True{},stamp,tick),stamp),stamp)}}}},Unit{},[handle()],tick,None{},Notice.View{1,[],[]}}

def one_batch(old:C.Transform,mesh:C.MeshRef,accepted:H.Spatial,fresh:H.Spatial) -> Batch:
  Pair{S.Row{handle(),old,mesh,accepted},fresh,EmptyBatch{}}

def four(a:H.Mark,b:H.Mark) -> Tree:
  Node{Node{Leaf{a},Leaf{b}},Node{Leaf{H.Visiting{}},Leaf{H.Visiting{}}}}

def forward_forest(+child:H.Local,+root:H.Local,+child_value:H.Spatial,+root_value:H.Spatial) -> Forest:
  Child{four(H.Pending{child},H.Pending{root}),child,1,four(H.Visiting{},H.Pending{root}),Root{four(H.Visiting{},H.Pending{root}),root,four(H.Visiting{},H.Finished{root_value}),root_value},four(H.Finished{child_value},H.Finished{root_value}),child_value}

def forward_sequence(+child:H.Local,+root:H.Local,+child_value:H.Spatial,+root_value:H.Spatial) -> List<&2,Forest>:
  [forward_forest(child,root,child_value,root_value),Cached{four(H.Finished{child_value},H.Finished{root_value}),root_value}]
