import Base
import ./components.bend as C
import ./scene-matrix.bend as M
import ./content.bend as F

type Instance is Data:
  Instance{mesh:F.Mesh,material:F.Material,transform:C.Transform}
type Scene is Data:
  Scene{instances:List<&2,Instance>}
type Seed is Data:
  Seed{transform:C.Transform,mesh:C.MeshRef}
type Range is Data:
  Range{id:U32,first_index:U32,index_count:U32}
type Geometry is Data:
  Geometry{vertices:List<&2,F.Vertex>,indices:List<&2,U32>,ranges:List<&2,Range>}
type Compiled is Data:
  Compiled{seeds:List<&2,Seed>,geometry:Geometry}
type Error is Data:
  BadMesh{instance:U32}
  BadMaterial{instance:U32}
  BadTransform{instance:U32}
  TooLarge{}
type Used is Data:
  Used{mesh:F.Mesh,material:F.Material,id:U32}

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

def rebase(indices:List<&2,U32>,+offset:U32) -> List<&2,U32>:
  match indices:
    case []:[]
    case i <> rest:U32.add(i,offset) <> rebase(rest,offset)

def lookup(pairs:List<&2,Used>,+mesh:F.Mesh,+material:F.Material) -> Maybe<U32>:
  match pairs:
    case []:None{}
    case Used{other,tint,id} <> rest:
      Bool.pick(Maybe<U32>,F.same_material(tint,material) && F.same_mesh(other,mesh),Some{id},lookup(rest,mesh,material))

def resolve(ranges:List<&2,Range>,+id:U32) -> Maybe<Range>:
  match ranges:
    case []:None{}
    case +range <> rest:
      Range{other,_,_} = range
      Bool.pick(Maybe<Range>,U32.is_eq(other,id),Some{range},resolve(rest,id))

def prepend(seed:Seed,result:Result<&2,&2,Error,Compiled>) -> Result<&2,&2,Error,Compiled>:
  match result:
    case Fail{error}:Fail{error}
    case Done{Compiled{seeds,geometry}}:Done{Compiled{seed <> seeds,geometry}}

def validate(mesh:Bool,material:Bool,transform:Bool,number:U32) -> Result<&2,&2,Error,Unit>:
  match mesh material transform:
    case False{} _ _:Fail{BadMesh{number}}
    case _ False{} _:Fail{BadMaterial{number}}
    case _ _ False{}:Fail{BadTransform{number}}
    case True{} True{} True{}:Done{Unit{}}

def capacity(valid:Bool) -> Result<&2,&2,Error,Unit>:
  match valid:
    case True{}:Done{Unit{}}
    case False{}:Fail{TooLarge{}}

type Plan is Data:
  Plan{pairs:List<&2,Used>,geometry:Geometry,id:U32,next:U32}

def compile_pair(found:Maybe<U32>,+mesh:F.Mesh,+material:F.Material,pairs:List<&2,Used>,geometry:Geometry,+next:U32) -> Result<&2,&2,Error,Plan>:
  match found:
    case Some{id}:Done{Plan{pairs,geometry,id,next}}
    case None{}:
      F.Mesh{+vertices,+indices} = mesh
      Geometry{+vs,+packed_indices,ranges} = geometry
      +vc = List.length(&2,F.Vertex,vs)
      +ic = List.length(&2,U32,packed_indices)
      do Result<&2,&2,Error,Plan>:
        checked:Unit <- capacity(F.mesh_fits(Nat.add(vc,List.length(&2,F.Vertex,vertices)),Nat.add(ic,List.length(&2,U32,indices))))
        return Plan{Used{mesh,material,next} <> pairs,
          Geometry{List.append(&2,F.Vertex,vs,F.bake(vertices,material)),List.append(&2,U32,packed_indices,rebase(indices,U32.from_nat(vc))),List.append(&2,Range,ranges,[Range{next,U32.from_nat(ic),U32.from_nat(List.length(&2,U32,indices))}])},next,U32.inc(next)}

def apply_plan(-A:Data,plan:Plan,next:List<&2,Used> -> Geometry -> U32 -> U32 -> Result<&2,&2,Error,A>) -> Result<&2,&2,Error,A>:
  Plan{pairs,geometry,id,index} = plan
  next(pairs)(geometry)(id)(index)

def compile_items(items:List<&2,Instance>,+pairs:List<&2,Used>,+geometry:Geometry,+number:U32,+next:U32) -> Result<&2,&2,Error,Compiled>:
  match items:
    case []:Done{Compiled{[],geometry}}
    case Instance{+mesh,+material,+transform} <> rest:
      do Result<&2,&2,Error,Compiled>:
        checked:Unit <- validate(F.mesh_valid(mesh),F.material_valid(material),transform_valid(transform),number)
        plan:Plan <- compile_pair(lookup(pairs,mesh,material),mesh,material,pairs,geometry,next)
        apply_plan(Compiled,plan,pairs => geometry => id => next => prepend(Seed{transform,C.MeshRef{id}},compile_items(rest,pairs,geometry,U32.inc(number),next)))

def compile(scene:Scene) -> Result<&2,&2,Error,Compiled>:
  Scene{+items} = scene
  do Result<&2,&2,Error,Compiled>:
    checked:Unit <- capacity(Nat.is_le(List.length(&2,Instance,items),100000n))
    compile_items(items,[],Geometry{[],[],[]},0,7)

def unique(ranges:List<&2,Range>,+id:U32) -> Bool:
  match ranges:
    case []:True{}
    case Range{other,_,_} <> rest:U32.is_ne(id,other) && unique(rest,id)

def ranges_valid(ranges:List<&2,Range>,+count:U32) -> Bool:
  match ranges:
    case []:True{}
    case Range{+id,+first,+size} <> +rest:
      U32.is_le(first,count) && U32.is_le(size,U32.sub(count,first)) && U32.is_zero(U32.mod(size,3)) && unique(rest,id) && ranges_valid(rest,count)

def geometry_valid(geometry:Geometry) -> Bool:
  Geometry{+vertices,+indices,ranges} = geometry
  F.mesh_valid(F.Mesh{vertices,indices}) && ranges_valid(ranges,U32.from_nat(List.length(&2,U32,indices)))

type Projection is Data:
  Perspective{scale:F32,near:F32,far:F32}
type Camera is Data:
  Camera{target:C.Vec3,yaw:F32,pitch:F32,distance:F32,projection:Projection}

def default_camera() -> Camera:
  Camera{C.Vec3{0.0,0.0,0.0},0.65,0.45,7.0,Perspective{1.7320508,0.1,100.0}}

def camera_valid(camera:Camera) -> Bool:
  Camera{target,yaw,pitch,+distance,Perspective{+scale,+near,+far}} = camera
  F.vec_finite(target) && F.finite(yaw) && F.finite(pitch) && F.finite(distance) && F32.is_gt(distance,0.0) && F.finite(scale) && F32.is_gt(scale,0.0) && F.finite(near) && F.finite(far) && F32.is_gt(near,0.0) && F32.is_gt(far,near)

def camera(camera:Camera) -> Maybe<Camera>:
  +camera = camera
  Bool.pick(Maybe<Camera>,camera_valid(camera),Some{camera},None{})

def target_view(target:C.Vec3,+matrix:M.Mat4) -> M.Mat4:
  C.Vec3{+x,+y,+z} = target
  Bool.pick(M.Mat4,F32.is_eq(x,0.0) && F32.is_eq(y,0.0) && F32.is_eq(z,0.0),matrix,
    M.multiply(matrix,M.model(C.Transform{C.Vec3{F32.neg(x),F32.neg(y),F32.neg(z)},C.Quat{0.0,0.0,0.0,1.0},C.Vec3{1.0,1.0,1.0}})))

def orbit(camera:Camera,+width:U32,+height:U32) -> M.Mat4:
  Camera{target,+yaw,+pitch,+distance,Perspective{+f,+near,+far}} = camera
  +sy +cy +sp +cp = F32.sin(yaw) F32.cos(yaw) F32.sin(pitch) F32.cos(pitch)
  +fx : F32 = (f * U32.to_f32(height) / U32.to_f32(width) : F32)
  +a : F32 = (far / (far - near) : F32)
  target_view(target,M.Mat4{
    M.Vec4{(fx * cy : F32),(f * sy * sp : F32),F32.neg((a * sy * cp : F32)),F32.neg((sy * cp : F32))},
    M.Vec4{0.0,F32.neg((f * cp : F32)),F32.neg((a * sp : F32)),F32.neg(sp)},
    M.Vec4{F32.neg((fx * sy : F32)),(f * cy * sp : F32),F32.neg((a * cy * cp : F32)),F32.neg((cy * cp : F32))},
    M.Vec4{0.0,0.0,(a * distance - far * near / (far - near) : F32),distance}})

def view_valid(valid:Bool,camera:Camera,width:U32,height:U32) -> Maybe<M.Mat4>:
  match valid:
    case False{}:None{}
    case True{}:
      +matrix = orbit(camera,width,height)
      Bool.pick(Maybe<M.Mat4>,matrix_finite(matrix),Some{matrix},None{})

def view(+camera:Camera,+width:U32,+height:U32) -> Maybe<M.Mat4>:
  view_valid(camera_valid(camera) && U32.is_gt(width,0) && U32.is_gt(height,0),camera,width,height)
