import Base
import ./components.bend as C
import ./scene-matrix.bend as M
import ./content.bend as F

type Bounds is Data:
  Empty{}
  Bounds{minimum:C.Vec3,maximum:C.Vec3}
type GlobalTransform is Data:
  GlobalTransform{matrix:M.Mat4}
type Local is Data:
  Local{transform:C.Transform,parent:Maybe<&2,U32>,bounds:Bounds,lit:Bool}
type Spatial is Data:
  Spatial{accepted:Local,global:GlobalTransform,bounds:Bounds}
type Error is Data:
  MissingParent{index:U32}
  Cycle{index:U32}
  InvalidTransform{index:U32}
  MissingEntity{}
type Mark is Data:
  Pending{local:Local}
  Visiting{}
  Finished{value:Spatial}

def matrix(global:GlobalTransform) -> M.Mat4:
  GlobalTransform{matrix} = global
  matrix

def col_finite(v:M.Vec4) -> Bool:
  M.Vec4{x,y,z,w} = v
  F.finite(x) && F.finite(y) && F.finite(z) && F.finite(w)

def matrix_finite(m:M.Mat4) -> Bool:
  M.Mat4{a,b,c,d} = m
  col_finite(a) && col_finite(b) && col_finite(c) && col_finite(d)

def transform_valid(t:C.Transform) -> Bool:
  C.Transform{p,C.Quat{+x,+y,+z,+w},s} = t
  +n = (x * x + y * y + z * z + w * w : F32)
  F.vec_finite(p) && F.vec_finite(s) && F.finite(x) && F.finite(y) && F.finite(z) && F.finite(w) && F32.is_ge(n,0.9999) && F32.is_le(n,1.0001)

def flat_scale_valid(scale:C.Vec3) -> Bool:
  C.Vec3{+x,+y,+z} = scale
  F32.is_ge(F32.abs(x),0.000001) && F32.is_ge(F32.abs(y),0.000001) && F32.is_ge(F32.abs(z),0.000001) && F32.is_le(F32.abs(x),1000000.0) && F32.is_le(F32.abs(y),1000000.0) && F32.is_le(F32.abs(z),1000000.0)

def root_draw_valid(parent:Maybe<&2,U32>,transform:C.Transform) -> Bool:
  match parent transform:
    case None{} C.Transform{_,_,scale}:flat_scale_valid(scale)
    case Some{_} _:True{}

def cross(a:C.Vec3,b:C.Vec3) -> C.Vec3:
  C.Vec3{+x,+y,+z} = a
  C.Vec3{+u,+v,+w} = b
  C.Vec3{(y * w - z * v : F32),(z * u - x * w : F32),(x * v - y * u : F32)}

def dot(a:C.Vec3,b:C.Vec3) -> F32:
  C.Vec3{x,y,z} = a
  C.Vec3{u,v,w} = b
  (x * u + y * v + z * w : F32)

def xyz(v:M.Vec4) -> C.Vec3:
  M.Vec4{x,y,z,_} = v
  C.Vec3{x,y,z}

def divide(v:C.Vec3,+d:F32) -> M.Vec4:
  C.Vec3{x,y,z} = v
  M.Vec4{F32.div(x,d),F32.div(y,d),F32.div(z,d),0.0}

def normal_checked(ok:Bool,+matrix:M.Mat4) -> Maybe<&2,M.Mat4>:
  match ok:
    case True{}:Some{matrix}
    case False{}:None{}

def inverse_columns(+a:C.Vec3,+b:C.Vec3,+c:C.Vec3) -> Maybe<&2,M.Mat4>:
  +x = cross(b,c)
  +det = dot(a,x)
  +matrix:M.Mat4 = M.Mat4{divide(x,det),divide(cross(c,a),det),divide(cross(a,b),det),M.Vec4{0.0,0.0,0.0,1.0}}
  normal_checked(F32.is_ge(F32.abs(det),0.000000000000000000000000000001) && matrix_finite(matrix),matrix)

def normal(global:GlobalTransform) -> Maybe<&2,M.Mat4>:
  GlobalTransform{M.Mat4{a,b,c,_}} = global
  inverse_columns(xyz(a),xyz(b),xyz(c))

def usable_normal(value:Maybe<&2,M.Mat4>) -> Bool:
  match value:
    case None{}:False{}
    case Some{M.Mat4{+a,+b,+c,_}}:
      +x = dot(xyz(a),xyz(a))
      +y = dot(xyz(b),xyz(b))
      +z = dot(xyz(c),xyz(c))
      F32.is_ge(x,0.000000000000000000000001) && F32.is_le(x,1000000000000000000000000.0) && F32.is_ge(y,0.000000000000000000000001) && F32.is_le(y,1000000000000000000000000.0) && F32.is_ge(z,0.000000000000000000000001) && F32.is_le(z,1000000000000000000000000.0)

def affine(global:GlobalTransform) -> Bool:
  GlobalTransform{+m} = global
  M.Mat4{M.Vec4{_,_,_,a},M.Vec4{_,_,_,b},M.Vec4{_,_,_,c},M.Vec4{_,_,_,d}} = m
  matrix_finite(m) && F32.is_eq(a,0.0) && F32.is_eq(b,0.0) && F32.is_eq(c,0.0) && F32.is_eq(d,1.0)

def compose(parent:Maybe<&2,GlobalTransform>,local:C.Transform) -> GlobalTransform:
  match parent:
    case None{}:GlobalTransform{M.model(local)}
    case Some{GlobalTransform{matrix}}:GlobalTransform{M.multiply(matrix,M.model(local))}

def include(bounds:Bounds,+point:C.Vec3) -> Bounds:
  match bounds:
    case Empty{}:Bounds{point,point}
    case Bounds{C.Vec3{a,b,c},C.Vec3{d,e,f}}:
      C.Vec3{+x,+y,+z} = point
      Bounds{C.Vec3{F32.min(a,x),F32.min(b,y),F32.min(c,z)},C.Vec3{F32.max(d,x),F32.max(e,y),F32.max(f,z)}}

def vertex_bounds(vertices:List<&2,F.Vertex>,bounds:Bounds) -> Bounds:
  match vertices:
    case []:bounds
    case F.Vertex{point,_,_,_} <> rest:vertex_bounds(rest,include(bounds,point))

def mesh_bounds(mesh:F.Mesh) -> Bounds:
  F.Mesh{vertices,_} = mesh
  vertex_bounds(vertices,Empty{})

def corners(bounds:Bounds) -> List<&2,C.Vec3>:
  match bounds:
    case Empty{}:[]
    case Bounds{C.Vec3{+a,+b,+c},C.Vec3{+d,+e,+f}}:
      [C.Vec3{a,b,c},C.Vec3{a,b,f},C.Vec3{a,e,c},C.Vec3{a,e,f},C.Vec3{d,b,c},C.Vec3{d,b,f},C.Vec3{d,e,c},C.Vec3{d,e,f}]

def point(matrix:M.Mat4,p:C.Vec3) -> C.Vec3:
  C.Vec3{x,y,z} = p
  xyz(M.apply(matrix,M.Vec4{x,y,z,1.0}))

def transformed_valid(valid:Bool,+world:C.Vec3,bounds:Bounds,next:Bounds -> Bounds) -> Bounds:
  match valid:
    case False{}:Bounds{world,world}
    case True{}:next(include(bounds,world))

def transformed(points:List<&2,C.Vec3>,+matrix:M.Mat4,bounds:Bounds) -> Bounds:
  match points:
    case []:bounds
    case p <> rest:
      +world = point(matrix,p)
      transformed_valid(F.vec_finite(world),world,bounds,b => transformed(rest,matrix,b))

def world_bounds(global:GlobalTransform,bounds:Bounds) -> Bounds:
  GlobalTransform{matrix} = global
  transformed(corners(bounds),matrix,Empty{})

def bounds_valid(bounds:Bounds) -> Bool:
  match bounds:
    case Empty{}:True{}
    case Bounds{+a,+b}:
      C.Vec3{x,y,z} = a
      C.Vec3{u,v,w} = b
      F.vec_finite(a) && F.vec_finite(b) && F32.is_le(x,u) && F32.is_le(y,v) && F32.is_le(z,w)

def derived(ok:Bool,number:U32,local:Local,global:GlobalTransform,bounds:Bounds) -> Result<&2,&2,Error,Spatial>:
  match ok:
    case False{}:Fail{InvalidTransform{number}}
    case True{}:Done{Spatial{local,global,bounds}}

def derive(+local:Local,parent:Maybe<&2,GlobalTransform>,number:U32) -> Result<&2,&2,Error,Spatial>:
  Local{+t,parent_index,+bounds,+lit} = local
  +global = compose(parent,t)
  +world = world_bounds(global,bounds)
  derived(transform_valid(t) && affine(global) && bounds_valid(bounds) && bounds_valid(world) && (Bool.not(lit) || (root_draw_valid(parent_index,t) && usable_normal(normal(global)))),number,local,global,world)

def initialized(+local:Local) -> Spatial:
  Local{t,_,bounds,_} = local
  +global = compose(None{},t)
  Spatial{local,global,world_bounds(global,bounds)}

def with_transform(t:C.Transform,spatial:Spatial) -> Local:
  Spatial{Local{_,parent,bounds,lit},_,_} = spatial
  Local{t,parent,bounds,lit}

def save(array:Array<Mark>,+index:U32,result:Result<&2,&2,Error,Spatial>) -> Result<&2,&1,Error,Array<Mark> & Spatial>:
  match result:
    case Fail{e}:Fail{e}
    case Done{+value}:Done{(Array.set(Mark,array,index,Finished{value}),value)}

def parent_done(local:Local,+index:U32,result:Result<&2,&1,Error,Array<Mark> & Spatial>) -> Result<&2,&1,Error,Array<Mark> & Spatial>:
  match result:
    case Fail{e}:Fail{e}
    case Done{(array,Spatial{_,global,_})}:save(array,index,derive(local,Some{global},index))

def visit_parent(parent:Maybe<&2,U32>,local:Local,+index:U32,array:Array<Mark>,next:U32 -> Array<Mark> -> Result<&2,&1,Error,Array<Mark> & Spatial>) -> Result<&2,&1,Error,Array<Mark> & Spatial>:
  match parent:
    case None{}:save(array,index,derive(local,None{},index))
    case Some{parent}:parent_done(local,index,next(parent,Array.set(Mark,array,index,Visiting{})))

def visit_mark(result:Array<Mark> & Mark,+index:U32,next:U32 -> Array<Mark> -> Result<&2,&1,Error,Array<Mark> & Spatial>) -> Result<&2,&1,Error,Array<Mark> & Spatial>:
  match result:
    case (array,Visiting{}):Fail{Cycle{index}}
    case (array,Finished{+value}):Done{(array,value)}
    case (array,Pending{+local}):
      Local{_,parent,_,_} = local
      visit_parent(parent,local,index,array,next)

def visit_checked(valid:Bool,+index:U32,array:Array<Mark>,next:U32 -> Array<Mark> -> Result<&2,&1,Error,Array<Mark> & Spatial>) -> Result<&2,&1,Error,Array<Mark> & Spatial>:
  match valid:
    case False{}:Fail{MissingParent{index}}
    case True{}:visit_mark(Array.get(Mark,array,index),index,next)

def visit(fuel:Nat,+count:U32,+index:U32,array:Array<Mark>) -> Result<&2,&1,Error,Array<Mark> & Spatial>:
  match fuel:
    case 0n:Fail{Cycle{index}}
    case 1n+rest:visit_checked(U32.is_lt(index,count),index,array,p => a => visit(rest,count,p,a))

def fill(items:List<&2,Local>,+index:U32,array:Array<Mark>) -> Array<Mark>:
  match items:
    case []:array
    case item <> rest:fill(rest,U32.inc(index),Array.set(Mark,array,index,Pending{item}))

def evaluated(next:Array<Mark> -> List<&2,Spatial> -> Result<&2,&1,Error,List<&2,Spatial>>,acc:List<&2,Spatial>,result:Result<&2,&1,Error,Array<Mark> & Spatial>) -> Result<&2,&1,Error,List<&2,Spatial>>:
  match result:
    case Fail{e}:Fail{e}
    case Done{(array,value)}:next(array,value <> acc)

def evaluate_each(left:Nat,+fuel:Nat,+count:U32,+index:U32,array:Array<Mark>,acc:List<&2,Spatial>) -> Result<&2,&1,Error,List<&2,Spatial>>:
  match left:
    case 0n:Done{List.reverse(&2,Spatial,acc)}
    case 1n+rest:evaluated(evaluate_each(rest,fuel,count,U32.inc(index)),acc,visit(fuel,count,index,array))

def reusable(result:Result<&2,&1,Error,List<&2,Spatial>>) -> Result<&2,&2,Error,List<&2,Spatial>>:
  match result:
    case Fail{e}:Fail{e}
    case Done{values}:Done{values}

def evaluate(+items:List<&2,Local>) -> Result<&2,&2,Error,List<&2,Spatial>>:
  +count = List.length(&2,Local,items)
  +size = U32.from_nat(count)
  reusable(evaluate_each(count,1n+count,size,0,fill(items,0,Array.new(Mark,U32.log2(U32.max(1,U32.mul(size,2))),Visiting{})),[]))

