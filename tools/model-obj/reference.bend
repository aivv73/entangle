import Base
import ../../src/content.bend as F
import ../../src/components.bend as C

def v(x:F32,y:F32,z:F32) -> F.Vertex:
  F.Vertex{C.Vec3{x,y,z},C.Vec3{1.0,1.0,1.0}}

def quad(+a:F.Vertex,+b:F.Vertex,+c:F.Vertex,d:F.Vertex,material:F.Material,groups:List<&2,String>,name:Maybe<&2,String>) -> F.ModelPart:
  F.ModelPart{F.Mesh{[a,b,c,a,c,d],[0,1,2,3,4,5]},material,F.ModelLabels{Some{"sign"},groups,name}}

# The authored panel specification supplies these values independently of OBJ.
def sign() -> F.SourceModel:
  F.SourceModel{[
    quad(v(F32.neg(3.0),F32.neg(1.0),0.0),v(F32.neg(1.0),F32.neg(1.0),0.0),v(F32.neg(1.0),1.0,0.0),v(F32.neg(3.0),1.0,0.0),F.white(),["left"],None{}),
    quad(v(F32.neg(1.0),F32.neg(1.0),0.0),v(1.0,F32.neg(1.0),0.0),v(1.0,1.0,0.0),v(F32.neg(1.0),1.0,0.0),F.Basic{C.Vec3{1.0,0.0,0.0}},["middle","face"],Some{"red"}),
    quad(v(1.0,F32.neg(1.0),F.float_word(2147483648)),v(3.0,F32.neg(1.0),0.0),v(3.0,1.0,0.0),v(1.0,1.0,0.0),F.Basic{C.Vec3{0.0,1.0,0.0}},["right"],Some{"green"})]}

def wedge() -> F.SourceModel:
  +a = v(F32.neg(1.0),F32.neg(1.0),0.0)
  +b = v(1.0,F32.neg(1.0),0.0)
  +c = v(1.0,1.0,0.0)
  +d = v(F32.neg(1.0),1.0,0.0)
  +e = v(F32.neg(1.0),F32.neg(1.0),1.0)
  +f = v(1.0,F32.neg(1.0),2.0)
  F.SourceModel{[F.ModelPart{F.Mesh{[a,c,b,a,d,c,a,b,f,a,f,e,b,c,f,c,d,e,c,e,f,d,a,e],[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23]},F.white(),F.ModelLabels{Some{"wedge"},[],None{}}}]}

def blue_parts(parts:List<&2,F.ModelPart>) -> List<&2,F.ModelPart>:
  match parts:
    case []:[]
    case F.ModelPart{mesh,+material,+labels} <> rest:
      F.ModelLabels{_,_,name} = labels
      F.ModelPart{mesh,Bool.pick(F.Material,F.same_name(name,Some{"red"}),F.Basic{C.Vec3{0.0,0.0,1.0}},material),labels} <> blue_parts(rest)

def blue_parts_list(model:F.SourceModel) -> List<&2,F.ModelPart>:
  F.SourceModel{parts} = model
  blue_parts(parts)

def blue_sign() -> F.SourceModel:
  F.SourceModel{blue_parts_list(sign())}
