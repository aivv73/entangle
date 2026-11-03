import Base
import ./components.bend as C

# Unit requests one movement invocation; Unit output means no gameplay events.
def step(input:Unit,state:C.Transform) -> C.Transform & Unit:
  match state:
    case C.Transform{C.Vec3{x,y,z},rotation,scale}:
      moved : C.Vec3 = C.Vec3{F32.add(x,1.0),F32.add(y,0.5),F32.sub(z,2.0)}
      (C.Transform{moved,rotation,scale},Unit{})
