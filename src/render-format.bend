import Base
import ./content.bend as F
import ./components.bend as C
import ../deps/bend-vulkan/src/core.bend as Core

def vertex_words(v:F.Vertex) -> List<U32>:
  F.Vertex{C.Vec3{x,y,z},C.Vec3{r,g,b},F.UV{u,v},C.Vec3{nx,ny,nz}} = v
  [F32.bits(x),F32.bits(y),F32.bits(z),F32.bits(r),F32.bits(g),F32.bits(b),F32.bits(u),F32.bits(v),F32.bits(nx),F32.bits(ny),F32.bits(nz)]

def pixel_bytes(+pixel:U32) -> List<&2,U32>:
  [Core.word_byte(pixel,3),Core.word_byte(pixel,2),Core.word_byte(pixel,1),Core.word_byte(pixel,0)]

def pixels_bytes(pixels:List<&2,U32>) -> List<&2,U32>:
  match pixels:
    case []:[]
    case pixel <> rest:List.append(&2,U32,pixel_bytes(pixel),pixels_bytes(rest))
