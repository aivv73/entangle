import Base
import ./components.bend as C
import ./hierarchy.bend as H

type DrawItem is Data:
  DrawItem{transform:C.Transform,mesh:C.MeshRef}
  GlobalItem{transform:H.GlobalTransform,mesh:C.MeshRef}

type DrawList is Data:
  DrawList{items:List<&2,DrawItem>}

def item(parent:Maybe<&2,U32>,local:C.Transform,mesh:C.MeshRef,global:H.GlobalTransform) -> DrawItem:
  match parent:
    case None{}:DrawItem{local,mesh}
    case Some{_}:GlobalItem{global,mesh}
