import Base
import ./components.bend as C
import ./hierarchy.bend as H
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/entity-key.bend as Key
import ../deps/bendvy/src/ecs/column.bend as Col
import ../deps/bendvy/src/ecs/component.bend as Component
import ../deps/bendvy/src/ecs/transaction.bend as Tx
import ../deps/bendvy/src/ecs/ordinary-declaration.bend as Identity

type Schema is Data: Schema{}
type Store is Type:
  Store{transform:Col.Column<Schema,C.Transform>,mesh:Col.Column<Schema,C.MeshRef>,spatial:Col.Column<Schema,H.Spatial>}

def Columns() -> Type:Store
def Resources() -> Type:Unit
def World() -> Type:W.World<Schema,Store,Unit,Unit>

def same(left:W.Handle<Schema>,right:W.Handle<Schema>) -> Bool:
  W.Handle{ln,lk} = left
  W.Handle{rn,rk} = right
  U32.is_eq(ln,rn) && Key.equal(lk,rk)

def empty(_:Unit) -> Store:
  Store{Col.empty_indexed(~Schema,~C.Transform),Col.empty_indexed(~Schema,~C.MeshRef),Col.empty_indexed(~Schema,~H.Spatial)}

def create(factory:W.Factory) -> W.Creation<Schema,Store,Unit,Unit>:
  W.create(~Schema,~Store,~Unit,~Unit,~empty,factory,Unit{})

def accessed(-V:Data,result:World() & Component.Access<V>) -> World() & Maybe<&2,V>:
  match result:
    case (world,Component.Found{value}):(world,Some{value})
    case (world,_):(world,None{})

def replaced(-V:Data,result:Component.Replacement<World(),V>) -> World() & Bool:
  match result:
    case Component.Replaced{world,_}:(world,True{})
    case Component.ReplaceRejected{world,_,_}:(world,False{})

type TransformToken is Data:TransformToken{}
def TransformRest() -> Type:Col.Column<Schema,C.MeshRef> & Col.Column<Schema,H.Spatial>
def take_transform(store:Store) -> TransformRest() & Col.Column<Schema,C.Transform>:
  Store{column,mesh,spatial} = store
  ((mesh,spatial),column)
def put_transform(rest:TransformRest(),column:Col.Column<Schema,C.Transform>) -> Store:
  (mesh,spatial) = rest
  Store{column,mesh,spatial}
def transform(value:C.Transform) -> C.Transform & C.Transform:
  +value:C.Transform = value
  (value,value)
def transform_id() -> Identity.Declaration<Schema,C.Transform>:Identity.component(~Schema,~C.Transform,"transform")
def transform_family() -> Component.Family<Schema,Store,TransformRest(),C.Transform,C.Transform,TransformToken,take_transform,put_transform,transform>:Component.Family{"transform"}
def read_transform(world:World(),entity:W.Handle<Schema>) -> World() & Maybe<&2,C.Transform>:
  accessed(C.Transform,Component.get(~Schema,~Store,~Unit,~Unit,~TransformRest(),~C.Transform,~C.Transform,~TransformToken,~take_transform,~put_transform,~transform,transform_family(),world,entity))
def write_transform(world:World(),entity:W.Handle<Schema>,value:C.Transform) -> World() & Bool:
  replaced(C.Transform,Component.replace(~Schema,~Store,~Unit,~Unit,~TransformRest(),~C.Transform,~C.Transform,~TransformToken,~take_transform,~put_transform,~transform,transform_family(),world,entity,Some{value}))
def install_transform(world:World(),entity:W.Handle<Schema>,value:C.Transform) -> World() & Bool:
  replaced(C.Transform,Component.structural_replace(~Schema,~Store,~Unit,~Unit,~TransformRest(),~C.Transform,~C.Transform,~TransformToken,~take_transform,~put_transform,~transform,transform_family(),world,entity,Some{value}))
def tx_transform(tx:Tx.Tx<World(),Unit>,entity:W.Handle<Schema>,value:C.Transform) -> Component.SetResult<Tx.Tx<World(),Unit>,C.Transform>:
  Component.tx_set(~Schema,~Store,~Unit,~Unit,~TransformRest(),~C.Transform,~C.Transform,~TransformToken,~take_transform,~put_transform,~transform,transform_family(),tx,entity,value)

type MeshToken is Data:MeshToken{}
def MeshRest() -> Type:Col.Column<Schema,C.Transform> & Col.Column<Schema,H.Spatial>
def take_mesh(store:Store) -> MeshRest() & Col.Column<Schema,C.MeshRef>:
  Store{transform,column,spatial} = store
  ((transform,spatial),column)
def put_mesh(rest:MeshRest(),column:Col.Column<Schema,C.MeshRef>) -> Store:
  (transform,spatial) = rest
  Store{transform,column,spatial}
def mesh(value:C.MeshRef) -> C.MeshRef & C.MeshRef:
  +value:C.MeshRef = value
  (value,value)
def mesh_id() -> Identity.Declaration<Schema,C.MeshRef>:Identity.component(~Schema,~C.MeshRef,"mesh-ref")
def mesh_family() -> Component.Family<Schema,Store,MeshRest(),C.MeshRef,C.MeshRef,MeshToken,take_mesh,put_mesh,mesh>:Component.Family{"mesh-ref"}
def read_mesh(world:World(),entity:W.Handle<Schema>) -> World() & Maybe<&2,C.MeshRef>:
  accessed(C.MeshRef,Component.get(~Schema,~Store,~Unit,~Unit,~MeshRest(),~C.MeshRef,~C.MeshRef,~MeshToken,~take_mesh,~put_mesh,~mesh,mesh_family(),world,entity))
def write_mesh(world:World(),entity:W.Handle<Schema>,value:C.MeshRef) -> World() & Bool:
  replaced(C.MeshRef,Component.replace(~Schema,~Store,~Unit,~Unit,~MeshRest(),~C.MeshRef,~C.MeshRef,~MeshToken,~take_mesh,~put_mesh,~mesh,mesh_family(),world,entity,Some{value}))
def install_mesh(world:World(),entity:W.Handle<Schema>,value:C.MeshRef) -> World() & Bool:
  replaced(C.MeshRef,Component.structural_replace(~Schema,~Store,~Unit,~Unit,~MeshRest(),~C.MeshRef,~C.MeshRef,~MeshToken,~take_mesh,~put_mesh,~mesh,mesh_family(),world,entity,Some{value}))
def tx_mesh(tx:Tx.Tx<World(),Unit>,entity:W.Handle<Schema>,value:C.MeshRef) -> Component.SetResult<Tx.Tx<World(),Unit>,C.MeshRef>:
  Component.tx_set(~Schema,~Store,~Unit,~Unit,~MeshRest(),~C.MeshRef,~C.MeshRef,~MeshToken,~take_mesh,~put_mesh,~mesh,mesh_family(),tx,entity,value)

type SpatialToken is Data:SpatialToken{}
def SpatialRest() -> Type:Col.Column<Schema,C.Transform> & Col.Column<Schema,C.MeshRef>
def take_spatial(store:Store) -> SpatialRest() & Col.Column<Schema,H.Spatial>:
  Store{transform,mesh,column} = store
  ((transform,mesh),column)
def put_spatial(rest:SpatialRest(),column:Col.Column<Schema,H.Spatial>) -> Store:
  (transform,mesh) = rest
  Store{transform,mesh,column}
def spatial(value:H.Spatial) -> H.Spatial & H.Spatial:
  +value:H.Spatial = value
  (value,value)
def spatial_id() -> Identity.Declaration<Schema,H.Spatial>:Identity.component(~Schema,~H.Spatial,"spatial")
def spatial_family() -> Component.Family<Schema,Store,SpatialRest(),H.Spatial,H.Spatial,SpatialToken,take_spatial,put_spatial,spatial>:Component.Family{"spatial"}
def read_spatial(world:World(),entity:W.Handle<Schema>) -> World() & Maybe<&2,H.Spatial>:
  accessed(H.Spatial,Component.get(~Schema,~Store,~Unit,~Unit,~SpatialRest(),~H.Spatial,~H.Spatial,~SpatialToken,~take_spatial,~put_spatial,~spatial,spatial_family(),world,entity))
def write_spatial(world:World(),entity:W.Handle<Schema>,value:H.Spatial) -> World() & Bool:
  replaced(H.Spatial,Component.replace(~Schema,~Store,~Unit,~Unit,~SpatialRest(),~H.Spatial,~H.Spatial,~SpatialToken,~take_spatial,~put_spatial,~spatial,spatial_family(),world,entity,Some{value}))
def install_spatial(world:World(),entity:W.Handle<Schema>,value:H.Spatial) -> World() & Bool:
  replaced(H.Spatial,Component.structural_replace(~Schema,~Store,~Unit,~Unit,~SpatialRest(),~H.Spatial,~H.Spatial,~SpatialToken,~take_spatial,~put_spatial,~spatial,spatial_family(),world,entity,Some{value}))
def tx_spatial(tx:Tx.Tx<World(),Unit>,entity:W.Handle<Schema>,value:H.Spatial) -> Component.SetResult<Tx.Tx<World(),Unit>,H.Spatial>:
  Component.tx_set(~Schema,~Store,~Unit,~Unit,~SpatialRest(),~H.Spatial,~H.Spatial,~SpatialToken,~take_spatial,~put_spatial,~spatial,spatial_family(),tx,entity,value)
