import Base
import ./components.bend as C
import ./content.bend as F
import ./scene-matrix.bend as M

type Light is Data:
  Directional{toward:C.Vec3,color:C.Vec3,ambient:F32,intensity:F32}

def default() -> Light:
  Directional{C.Vec3{0.4,0.7,1.0},C.Vec3{1.0,1.0,1.0},0.2,0.8}

def valid(light:Light) -> Bool:
  Directional{direction,color,ambient,intensity} = light
  F.normal_valid(direction) && F.tint_valid(color) && F.channel(ambient) && F.channel(intensity)

def scale_valid(scale:C.Vec3) -> Bool:
  C.Vec3{+x,+y,+z} = scale
  F32.is_ge(F32.abs(x),0.000001) && F32.is_ge(F32.abs(y),0.000001) && F32.is_ge(F32.abs(z),0.000001) && F32.is_le(F32.abs(x),1000000.0) && F32.is_le(F32.abs(y),1000000.0) && F32.is_le(F32.abs(z),1000000.0)

def transform_valid(transform:C.Transform) -> Bool:
  C.Transform{_,_,scale} = transform
  scale_valid(scale)

def payload(camera:M.Mat4,+transform:C.Transform,light:Light) -> List<U32>:
  C.Transform{_,C.Quat{x,y,z,w},C.Vec3{sx,sy,sz}} = transform
  Directional{C.Vec3{dx,dy,dz},C.Vec3{r,g,b},ambient,intensity} = light
  List.append(&1,U32,M.matrix_words(M.multiply(camera,M.model(transform))),[
    F32.bits(x),F32.bits(y),F32.bits(z),F32.bits(w),
    F32.bits(F32.div(1.0,sx)),F32.bits(F32.div(1.0,sy)),F32.bits(F32.div(1.0,sz)),0,
    F32.bits(dx),F32.bits(dy),F32.bits(dz),F32.bits(ambient),
    F32.bits(r),F32.bits(g),F32.bits(b),F32.bits(intensity)])
