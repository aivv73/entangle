import Base
import ./components.bend as C
import ./content.bend as F
import ./scene-matrix.bend as M
import ./hierarchy.bend as H

type Light is Data:
  Directional{toward:C.Vec3,color:C.Vec3,ambient:F32,intensity:F32}

def default() -> Light:
  Directional{C.Vec3{0.4,0.7,1.0},C.Vec3{1.0,1.0,1.0},0.2,0.8}

def valid(light:Light) -> Bool:
  Directional{direction,color,ambient,intensity} = light
  F.normal_valid(direction) && F.tint_valid(color) && F.channel(ambient) && F.channel(intensity)

def scale_valid(scale:C.Vec3) -> Bool:
  H.flat_scale_valid(scale)

def transform_valid(transform:C.Transform) -> Bool:
  C.Transform{_,_,scale} = transform
  scale_valid(scale)

def normal_words(matrix:M.Mat4,light:Light) -> List<U32>:
  M.Mat4{M.Vec4{a,b,c,_},M.Vec4{d,e,f,_},M.Vec4{g,h,i,_},_} = matrix
  Directional{C.Vec3{dx,dy,dz},C.Vec3{r,g1,b1},ambient,+intensity} = light
  [F32.bits(a),F32.bits(b),F32.bits(c),F32.bits(dx),
   F32.bits(d),F32.bits(e),F32.bits(f),F32.bits(dy),
   F32.bits(g),F32.bits(h),F32.bits(i),F32.bits(dz),
   F32.bits(F32.mul(r,intensity)),F32.bits(F32.mul(g1,intensity)),F32.bits(F32.mul(b1,intensity)),F32.bits(ambient)]

def normal_payload(camera:M.Mat4,global:H.GlobalTransform,light:Light,normal:Maybe<&2,M.Mat4>) -> List<U32>:
  match normal:
    case None{}:[]
    case Some{matrix}:List.append(&1,U32,M.matrix_words(M.multiply(camera,H.matrix(global))),normal_words(matrix,light))

def global_payload(camera:M.Mat4,+global:H.GlobalTransform,light:Light) -> List<U32>:
  normal_payload(camera,global,light,H.normal(global))

def payload(camera:M.Mat4,transform:C.Transform,light:Light) -> List<U32>:
  global_payload(camera,H.compose(None{},transform),light)
