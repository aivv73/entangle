import Base
import ./components.bend as C

type Vertex is Data:
  Vertex{position:C.Vec3,color:C.Vec3}
type Mesh is Data:
  Mesh{vertices:List<&2,Vertex>,indices:List<&2,U32>}
type Material is Data:
  Basic{tint:C.Vec3}

def finite(x:F32) -> Bool:
  U32.is_ne(U32.and(F32.bits(x),2139095040),2139095040)

def vec_finite(v:C.Vec3) -> Bool:
  C.Vec3{x,y,z} = v
  finite(x) && finite(y) && finite(z)

def vertices_valid(vertices:List<&2,Vertex>) -> Bool:
  match vertices:
    case []:True{}
    case Vertex{p,c} <> rest:vec_finite(p) && vec_finite(c) && vertices_valid(rest)

def indices_valid(indices:List<&2,U32>,+count:U32) -> Bool:
  match indices:
    case []:True{}
    case i <> rest:U32.is_lt(i,count) && indices_valid(rest,count)

def mesh_fits(vertices:Nat,indices:Nat) -> Bool:
  Nat.is_le(vertices,699050n) && Nat.is_le(indices,3000000n)

def mesh_valid(mesh:Mesh) -> Bool:
  Mesh{+vertices,+indices} = mesh
  +vc = List.length(&2,Vertex,vertices)
  +ic = List.length(&2,U32,indices)
  mesh_fits(vc,ic) && U32.is_zero(U32.mod(U32.from_nat(ic),3)) && vertices_valid(vertices) && indices_valid(indices,U32.from_nat(vc))

def channel(+x:F32) -> Bool:
  finite(x) && F32.is_ge(x,0.0) && F32.is_le(x,1.0)

def material_valid(material:Material) -> Bool:
  Basic{C.Vec3{r,g,b}} = material
  channel(r) && channel(g) && channel(b)

# Structural conversion keeps white identity reducible for every F32 payload.
def float_bits(value:F32) -> U32:
  F32{bits} = value
  U32{bits}

def float_word(value:U32) -> F32:
  U32{bits} = value
  F32{bits}

def white() -> Material:
  Basic{C.Vec3{float_word(1065353216),float_word(1065353216),float_word(1065353216)}}

def tint_channel(+value:F32,+tint:F32) -> F32:
  Bool.pick(F32,U32.is_eq(float_bits(tint),1065353216),value,F32.mul(value,tint))

def tint(vertex:Vertex,material:Material) -> Vertex:
  Vertex{p,C.Vec3{r,g,b}} = vertex
  Basic{C.Vec3{x,y,z}} = material
  Vertex{p,C.Vec3{tint_channel(r,x),tint_channel(g,y),tint_channel(b,z)}}

def bake(vertices:List<&2,Vertex>,+material:Material) -> List<&2,Vertex>:
  match vertices:
    case []:[]
    case v <> rest:tint(v,material) <> bake(rest,material)

def same_vec(a:C.Vec3,b:C.Vec3) -> Bool:
  C.Vec3{x,y,z} = a
  C.Vec3{u,v,w} = b
  U32.is_eq(F32.bits(x),F32.bits(u)) && U32.is_eq(F32.bits(y),F32.bits(v)) && U32.is_eq(F32.bits(z),F32.bits(w))

def same_vertices(a:List<&2,Vertex>,b:List<&2,Vertex>) -> Bool:
  match a b:
    case [], []:True{}
    case Vertex{p,c} <> xs, Vertex{q,d} <> ys:same_vec(p,q) && same_vec(c,d) && same_vertices(xs,ys)
    case _, _:False{}

def same_indices(a:List<&2,U32>,b:List<&2,U32>) -> Bool:
  match a b:
    case [], []:True{}
    case x <> xs, y <> ys:U32.is_eq(x,y) && same_indices(xs,ys)
    case _, _:False{}

def same_mesh(a:Mesh,b:Mesh) -> Bool:
  Mesh{v,i} = a
  Mesh{w,j} = b
  same_vertices(v,w) && same_indices(i,j)

def same_material(a:Material,b:Material) -> Bool:
  Basic{x} = a
  Basic{y} = b
  same_vec(x,y)

type SourceImage is Data:
  SourceImage{width:U32,height:U32,pixels:List<&2,U32>}

# Positive dimensions and exact storage are source rules, independent of PNG.
def image_valid(image:SourceImage) -> Bool:
  SourceImage{+width,+height,+pixels} = image
  U32.is_gt(width,0) && U32.is_gt(height,0) && Nat.is_eq(List.length(&2,U32,pixels),Nat.mul(U32.to_nat(width),U32.to_nat(height)))

type ModelLabels is Data:
  ModelLabels{object_name:Maybe<&2,String>,group_names:List<&2,String>,material_name:Maybe<&2,String>}
type ModelPart is Data:
  ModelPart{mesh:Mesh,material:Material,labels:ModelLabels}
type SourceModel is Data:
  SourceModel{parts:List<&2,ModelPart>}

def same_name(a:Maybe<&2,String>,b:Maybe<&2,String>) -> Bool:
  match a b:
    case None{},None{}:True{}
    case Some{x},Some{y}:String.eq(x,y)
    case _,_:False{}

def same_names(a:List<&2,String>,b:List<&2,String>) -> Bool:
  match a b:
    case [],[]:True{}
    case x <> xs,y <> ys:String.eq(x,y) && same_names(xs,ys)
    case _,_:False{}

def same_labels(a:ModelLabels,b:ModelLabels) -> Bool:
  ModelLabels{o,g,m} = a
  ModelLabels{p,h,n} = b
  same_name(o,p) && same_names(g,h) && same_name(m,n)

def same_parts(a:List<&2,ModelPart>,b:List<&2,ModelPart>) -> Bool:
  match a b:
    case [],[]:True{}
    case ModelPart{m,c,l} <> xs,ModelPart{n,d,k} <> ys:
      same_mesh(m,n) && same_material(c,d) && same_labels(l,k) && same_parts(xs,ys)
    case _,_:False{}

def same_model(a:SourceModel,b:SourceModel) -> Bool:
  SourceModel{a} = a
  SourceModel{b} = b
  same_parts(a,b)

def add_counts(vertices:Nat,indices:Nat,counts:Nat & Nat) -> Nat & Nat:
  (vc,ic) = counts
  (Nat.add(vertices,vc),Nat.add(indices,ic))

def model_counts(parts:List<&2,ModelPart>) -> Nat & Nat:
  match parts:
    case []:(0n,0n)
    case ModelPart{Mesh{vs,is1},_,_} <> rest:
      add_counts(List.length(&2,Vertex,vs),List.length(&2,U32,is1),model_counts(rest))

def parts_valid(parts:List<&2,ModelPart>) -> Bool:
  match parts:
    case []:True{}
    case ModelPart{mesh,material,_} <> rest:mesh_valid(mesh) && material_valid(material) && parts_valid(rest)

def counts_fit(counts:Nat & Nat) -> Bool:
  (vc,ic) = counts
  mesh_fits(vc,ic)

def model_valid(model:SourceModel) -> Bool:
  SourceModel{+parts} = model
  parts_valid(parts) && counts_fit(model_counts(parts))
