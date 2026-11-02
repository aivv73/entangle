import Base
import ./components.bend as C

type Vec4 is Data:
  Vec4{x:F32,y:F32,z:F32,w:F32}
type Mat4 is Data:
  Mat4{a:Vec4,b:Vec4,c:Vec4,d:Vec4}

def apply(+m:Mat4,v:Vec4) -> Vec4:
  Mat4{Vec4{+a,+b,+c,+d},Vec4{+e,+f,+g,+h},Vec4{+i,+j,+k,+l},Vec4{+n,+o,+p,+q}} = m
  Vec4{+x,+y,+z,+w} = v
  Vec4{(a * x + e * y + i * z + n * w : F32),(b * x + f * y + j * z + o * w : F32),(c * x + g * y + k * z + p * w : F32),(d * x + h * y + l * z + q * w : F32)}

def multiply(+left:Mat4,right:Mat4) -> Mat4:
  Mat4{a,b,c,d} = right
  Mat4{apply(left,a),apply(left,b),apply(left,c),apply(left,d)}

def model(t:C.Transform) -> Mat4:
  C.Transform{C.Vec3{tx,ty,tz},C.Quat{+x,+y,+z,+w},C.Vec3{+sx,+sy,+sz}} = t
  Mat4{
    Vec4{((1.0 - 2.0 * (y * y + z * z)) * sx : F32),(2.0 * (x * y + z * w) * sx : F32),(2.0 * (x * z - y * w) * sx : F32),0.0},
    Vec4{(2.0 * (x * y - z * w) * sy : F32),((1.0 - 2.0 * (x * x + z * z)) * sy : F32),(2.0 * (y * z + x * w) * sy : F32),0.0},
    Vec4{(2.0 * (x * z + y * w) * sz : F32),(2.0 * (y * z - x * w) * sz : F32),((1.0 - 2.0 * (x * x + y * y)) * sz : F32),0.0},
    Vec4{tx,ty,tz,1.0}}

def column_words(v:Vec4) -> List<U32>:
  Vec4{x,y,z,w} = v
  [F32.bits(x),F32.bits(y),F32.bits(z),F32.bits(w)]

def matrix_words(m:Mat4) -> List<U32>:
  Mat4{a,b,c,d} = m
  List.concat(&1,U32,[column_words(a),column_words(b),column_words(c),column_words(d)])

