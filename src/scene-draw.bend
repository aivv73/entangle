import Base
import ./components.bend as C

type DrawItem is Data:
  DrawItem{transform:C.Transform,mesh:C.MeshRef}

type DrawList is Data:
  DrawList{items:List<&2,DrawItem>}
