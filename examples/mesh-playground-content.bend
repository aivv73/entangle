import Base
import ../src/creation.bend as Create
import ../src/components.bend as C

def vertex(x:F32,y:F32,z:F32) -> Create.Vertex:Create.Vertex{C.Vec3{x,y,z},C.Vec3{1.0,1.0,1.0}}

def octahedron() -> Create.Mesh:
  Create.Mesh{[vertex(0.0,0.65,0.0),
    vertex(0.65,0.0,0.0),
    vertex(0.0,0.0,0.65),
    vertex(F32.neg(0.65),0.0,0.0),
    vertex(0.0,0.0,F32.neg(0.65)),
    vertex(0.0,F32.neg(0.65),0.0)],
    [0,2,1,0,3,2,0,4,3,0,1,4,5,1,2,5,2,3,5,3,4,5,4,1]}

def tetrahedron() -> Create.Mesh:
  Create.Mesh{[vertex(0.0,0.7,0.0),
    vertex(F32.neg(0.65),F32.neg(0.4),0.5),
    vertex(0.65,F32.neg(0.4),0.5),
    vertex(0.0,F32.neg(0.4),F32.neg(0.65))],
    [0,1,2,0,2,3,0,3,1,1,3,2]}

def prism() -> Create.Mesh:
  Create.Mesh{[vertex(F32.neg(0.55),F32.neg(0.45),F32.neg(0.45)),
    vertex(0.55,F32.neg(0.45),F32.neg(0.45)),
    vertex(0.0,0.65,F32.neg(0.45)),
    vertex(F32.neg(0.55),F32.neg(0.45),0.45),
    vertex(0.55,F32.neg(0.45),0.45),
    vertex(0.0,0.65,0.45)],
    [0,2,1,3,4,5,0,1,4,0,4,3,1,2,5,1,5,4,2,0,3,2,3,5]}

def platform() -> Create.Mesh:
  Create.Mesh{[vertex(F32.neg(3.0),F32.neg(0.12),F32.neg(1.5)),
    vertex(3.0,F32.neg(0.12),F32.neg(1.5)),
    vertex(3.0,0.12,F32.neg(1.5)),
    vertex(F32.neg(3.0),0.12,F32.neg(1.5)),
    vertex(F32.neg(3.0),F32.neg(0.12),1.5),
    vertex(3.0,F32.neg(0.12),1.5),
    vertex(3.0,0.12,1.5),
    vertex(F32.neg(3.0),0.12,1.5)],
    [0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,3,7,6,3,6,2,0,4,7,0,7,3,1,2,6,1,6,5]}

def pose(x:F32,y:F32,z:F32) -> C.Transform:
  C.Transform{C.Vec3{x,y,z},C.Quat{0.0,0.0,0.0,1.0},C.Vec3{1.0,1.0,1.0}}

def scene() -> Create.Scene:
  Create.Scene{[
    Create.Instance{octahedron(),Create.Basic{C.Vec3{1.0,0.45,0.05}},pose(0.0,0.65,0.0)},
    Create.Instance{tetrahedron(),Create.Basic{C.Vec3{0.0,0.85,0.9}},pose(F32.neg(1.8),0.5,0.0)},
    Create.Instance{prism(),Create.Basic{C.Vec3{0.9,0.15,0.7}},pose(1.8,0.5,0.0)},
    Create.Instance{platform(),Create.Basic{C.Vec3{0.45,0.48,0.53}},pose(0.0,F32.neg(0.3),0.0)}]}
