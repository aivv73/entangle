import Base
import ../src/components.bend as C
import ../src/content.bend as F

type Bounds is Data:
  Bounds{low:C.Vec3,high:C.Vec3}

def vertex_bounds(vertex:F.Vertex,bounds:Bounds) -> Bounds:
  F.Vertex{C.Vec3{+x,+y,+z},_,_,_} = vertex
  Bounds{C.Vec3{a,b,c},C.Vec3{d,e,f}} = bounds
  Bounds{C.Vec3{F32.min(a,x),F32.min(b,y),F32.min(c,z)},C.Vec3{F32.max(d,x),F32.max(e,y),F32.max(f,z)}}

def vertices(values:List<&2,F.Vertex>,bounds:Bounds) -> Bounds:
  match values:
    case []:bounds
    case v <> rest:vertices(rest,vertex_bounds(v,bounds))

def parts(values:List<&2,F.ModelPart>,bounds:Bounds) -> Bounds:
  match values:
    case []:bounds
    case F.ModelPart{F.Mesh{vs,_},_,_} <> rest:parts(rest,vertices(vs,bounds))

def fitted(bounds:Bounds) -> C.Transform:
  Bounds{C.Vec3{+a,+b,+c},C.Vec3{+d,+e,+f}} = bounds
  +s:F32 = (2.6 / F32.max(0.000001,F32.max((d - a : F32),F32.max((e - b : F32),(f - c : F32)))) : F32)
  C.Transform{C.Vec3{F32.neg(((a + d) * 0.5 * s : F32)),F32.neg(((b + e) * 0.5 * s : F32)),F32.neg(((c + f) * 0.5 * s : F32))},C.Quat{0.0,0.0,0.0,1.0},C.Vec3{s,s,s}}

def initial(+vertex:F.Vertex,values:List<&2,F.ModelPart>) -> C.Transform:
  F.Vertex{+p,_,_,_} = vertex
  fitted(parts(values,Bounds{p,p}))

def transform(values:List<&2,F.ModelPart>) -> C.Transform:
  match values:
    case []:C.Transform.identity()
    case F.ModelPart{F.Mesh{[] ,_},_,_} <> rest:transform(rest)
    case F.ModelPart{F.Mesh{+v <> +vs,+indices},+material,+name} <> +rest:
      initial(v,F.ModelPart{F.Mesh{v <> vs,indices},material,name} <> rest)
