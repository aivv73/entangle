import Base
import ./components.bend as C
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/execution-composer-layout.bend as L
import ../deps/bendvy/src/ecs/execution-resource-policy.bend as Policy
import ../deps/bendvy/src/ecs/execution-composer-schema.bend as Setup

type Schema is Data: Schema{}

def transform(value:C.Transform) -> C.Transform & C.Transform:
  +value : C.Transform = value
  (value,value)

def mesh(value:C.MeshRef) -> C.MeshRef & C.MeshRef:
  +value : C.MeshRef = value
  (value,value)

def components() -> L.Layout:
  L.LayoutPair{L.LayoutLeaf{C.Transform,C.Transform,transform,"transform",Policy.Ordinary{}},L.LayoutLeaf{C.MeshRef,C.MeshRef,mesh,"mesh-ref",Policy.Ordinary{}}}

def resources() -> L.Layout:L.EmptyLayout{}

def Columns() -> Type:L.columns(~Schema,components())

def Resources() -> Type:L.resources(~Schema,resources())

def World() -> Type:W.World<Schema,Columns(),Resources(),Unit>

def create(factory:W.Factory) -> Setup.Initialized<Schema,components(),resources(),Unit>:
  Setup.create(~Schema,~components(),~resources(),~Unit,factory,Unit{})
