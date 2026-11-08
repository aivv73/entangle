import Base

# XYZ position + RGB color, six F32 words per vertex.
def vertex(x: F32, y: F32, z: F32, +r: F32, +g: F32, +b: F32) -> List<U32>:
  [F32.bits(x),F32.bits(y),F32.bits(z),F32.bits(r),F32.bits(g),F32.bits(b)]

def vertices() -> List<U32>:
  +lo = F32.neg(1.0)
  front back left right top bottom ground =
    List.concat(&1,U32,[vertex(lo,lo,1.0,0.9,0.3,0.15),vertex(1.0,lo,1.0,0.9,0.3,0.15),vertex(1.0,1.0,1.0,0.9,0.3,0.15),vertex(lo,1.0,1.0,0.9,0.3,0.15)])
    List.concat(&1,U32,[vertex(1.0,lo,lo,0.3,0.5,0.9),vertex(lo,lo,lo,0.3,0.5,0.9),vertex(lo,1.0,lo,0.3,0.5,0.9),vertex(1.0,1.0,lo,0.3,0.5,0.9)])
    List.concat(&1,U32,[vertex(lo,lo,lo,0.5,0.3,0.8),vertex(lo,lo,1.0,0.5,0.3,0.8),vertex(lo,1.0,1.0,0.5,0.3,0.8),vertex(lo,1.0,lo,0.5,0.3,0.8)])
    List.concat(&1,U32,[vertex(1.0,lo,1.0,0.2,0.7,0.65),vertex(1.0,lo,lo,0.2,0.7,0.65),vertex(1.0,1.0,lo,0.2,0.7,0.65),vertex(1.0,1.0,1.0,0.2,0.7,0.65)])
    List.concat(&1,U32,[vertex(lo,1.0,1.0,0.95,0.75,0.25),vertex(1.0,1.0,1.0,0.95,0.75,0.25),vertex(1.0,1.0,lo,0.95,0.75,0.25),vertex(lo,1.0,lo,0.95,0.75,0.25)])
    List.concat(&1,U32,[vertex(lo,lo,lo,0.4,0.4,0.45),vertex(1.0,lo,lo,0.4,0.4,0.45),vertex(1.0,lo,1.0,0.4,0.4,0.45),vertex(lo,lo,1.0,0.4,0.4,0.45)])
    List.concat(&1,U32,[vertex(F32.neg(3.0),F32.neg(1.05),3.0,0.25,0.3,0.38),vertex(3.0,F32.neg(1.05),3.0,0.25,0.3,0.38),vertex(3.0,F32.neg(1.05),F32.neg(3.0),0.25,0.3,0.38),vertex(F32.neg(3.0),F32.neg(1.05),F32.neg(3.0),0.25,0.3,0.38)])
  List.concat(&1,U32,[front,back,left,right,top,bottom,ground])

def quad(+base: U32) -> List<U32>:
  [base,U32.inc(base),(base + 2 : U32),(base + 2 : U32),(base + 3 : U32),base]

def indices() -> List<U32>:
  List.concat(&1,U32,[quad(0),quad(4),quad(8),quad(12),quad(16),quad(20),quad(24)])

