import Base
import ../../src/content.bend as F
import ../../src/components.bend as C
import ../../src/model-obj.bend as Obj
import ./runtime.bend as Runtime
import ./reference.bend as Ref
import ../image-decoder/common.bend as Ck
import ../image-decoder/replace.bend as Replace

def repeats(n:Nat,+face:String) -> String:
  match n:
    case 0n:""
    case 1n+ +rest:face ++ repeats(rest,face)

def expected_vertices(n:Nat) -> List<&2,F.Vertex>:
  match n:
    case 0n:[]
    case 1n+ +rest:Ref.v(0.0,0.0,0.0) <> Ref.v(1.0,0.0,0.0) <> Ref.v(0.0,1.0,0.0) <> expected_vertices(rest)

def indices(n:Nat,+start:U32) -> List<&2,U32>:
  match n:
    case 0n:[]
    case 1n+ +rest:start <> indices(rest,U32.inc(start))

def expected(+n:Nat) -> F.SourceModel:
  F.SourceModel{[F.ModelPart{F.Mesh{expected_vertices(n),indices(Nat.mul(3n,n),0)},F.white(),F.ModelLabels{None{},[],None{}}}]}

def families(n:Nat) -> IO(Unit):
  match n:
    case 0n:IO.pure(Unit,Unit{})
    case 1n+ +rest:
      do IO<Unit>:
        +prefix:String = "v 0 0 0\nv 1 0 0\nv 0 1 0\n"
        +plain:String = prefix ++ repeats(1n+rest,"f 1 2 3\n")
        Runtime.accepted(Obj.decode(Obj.text(plain),None{}),expected(1n+rest),"positive ordered corner conservation")
        Runtime.accepted(Obj.decode(Obj.text(prefix ++ repeats(1n+rest,"f -3 -2 -1\n")),None{}),expected(1n+rest),"negative ordered corner conservation")
        Runtime.accepted(Obj.decode(Obj.text(Replace.all(Replace.all(String.trim(plain)," ","\t  "),"\n"," # comment\r\n\t")),None{}),expected(1n+rest),"whitespace CRLF inline comments and absent final LF")
        families(rest)

def bytes_rejected() -> IO(Unit):
  do IO<Unit>:
    Runtime.rejected(Obj.decode(0 <> Obj.text(Runtime.obj()),None{}),1,"NUL")
    Runtime.rejected(Obj.decode(256 <> Obj.text(Runtime.obj()),None{}),1,"nonbyte")
    Runtime.rejected(Obj.decode(239 <> 187 <> 191 <> Obj.text(Runtime.obj()),None{}),1,"BOM")
    Runtime.rejected(Obj.decode(1 <> Obj.text(Runtime.obj()),None{}),1,"control")
    Runtime.rejected(Obj.decode(Obj.text(Runtime.obj()),Some{[]}),5,"unexpected MTL")
    Runtime.rejected(Obj.decode(Obj.text("mtllib a\n" ++ Runtime.obj()),None{}),5,"missing MTL")

def material_encodings() -> IO(Unit):
  do IO<Unit>:
    Runtime.accepted(Obj.decode(Obj.text(Runtime.obj()),None{}),expected(1n),"basic")
    +prefix:String = "mtllib a\n" ++ Runtime.obj()
    Runtime.accepted(Obj.decode(Obj.text(prefix),Some{Obj.text("newmtl unused\nKd 0 0 0\nd +10.000e-1\nTr -0e2\nillum 0\n")}),expected(1n),"exact neutral unused material")
    Runtime.fail_mtl("newmtl unused\nKd 1e65 0 0",3)
    Runtime.fail_mtl("newmtl unused\nKd 0 0 0\nd 1\nd 1",5)
    Runtime.fail_obj(prefix ++ "usemtl missing",5)

def bounds() -> IO(Unit):
  do IO<Unit>:
    Runtime.accepted(Obj.decode(Obj.text("#" ++ String.repeat("x",4094n) ++ "\n" ++ Runtime.obj()),None{}),expected(1n),"physical line at bound")
    Runtime.fail_obj("#" ++ String.repeat("x",4095n) ++ "\n" ++ Runtime.obj(),7)
    Runtime.accepted(Obj.decode(Obj.text("o " ++ String.repeat("x",255n) ++ "\n" ++ Runtime.obj()),None{}),F.SourceModel{[F.ModelPart{F.Mesh{expected_vertices(1n),[0,1,2]},F.white(),F.ModelLabels{Some{String.repeat("x",255n)},[],None{}}}]},"label at bound")
    Runtime.fail_obj("o " ++ String.repeat("x",256n) ++ "\n" ++ Runtime.obj(),7)
    Runtime.accepted(Obj.decode(Obj.text("v " ++ String.repeat("0",64n) ++ " 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3"),None{}),expected(1n),"number at bound")
    Runtime.fail_obj("v " ++ String.repeat("0",65n) ++ " 0 0\nf 1 1 1",7)

def point_vertices(n:Nat) -> List<&2,F.Vertex>:
  match n:
    case 0n:[]
    case 1n+rest:Ref.v(0.0,0.0,0.0) <> point_vertices(rest)

def point_part(+faces:Nat,labels:F.ModelLabels) -> F.ModelPart:
  F.ModelPart{F.Mesh{point_vertices(Nat.mul(3n,faces)),indices(Nat.mul(3n,faces),0)},F.white(),labels}

def labels() -> IO(Unit):
  do IO<Unit>:
    Runtime.accepted(Obj.decode(Obj.text("# C:\\folder\\file\n" ++ Runtime.obj()),None{}),expected(1n),"backslashes inside comments")
    Runtime.accepted(Obj.decode(Obj.text("mtllib a\nv 0 0 0\nf 1 1 1\no item\nf 1 1 1\nusemtl white\nf 1 1 1\ng one two\nf 1 1 1\ng\nf 1 1 1\nusemtl white\nf 1 1 1\ng unused\no unused"),Some{Obj.text("newmtl white\nKd 1 1 1")}),F.SourceModel{[
      point_part(1n,F.ModelLabels{None{},[],None{}}),
      point_part(1n,F.ModelLabels{Some{"item"},[],None{}}),
      point_part(1n,F.ModelLabels{Some{"item"},[],Some{"white"}}),
      point_part(1n,F.ModelLabels{Some{"item"},["one","two"],Some{"white"}}),
      point_part(2n,F.ModelLabels{Some{"item"},[],Some{"white"}})]},"maximal contiguous labels, default/named white, bare g, no empty declaration parts")
    Runtime.accepted(Obj.decode(Obj.text("mtllib a\nv 0 0 0\nv 1 0 0\nv 0 1 0\nusemtl m\nf 1 2 3"),Some{Obj.text("newmtl m\nKd -0 0.25 1e-20")}),F.SourceModel{[F.ModelPart{F.Mesh{expected_vertices(1n),[0,1,2]},F.Basic{C.Vec3{F.float_word(2147483648),0.25,F.float_word(507307272)}},F.ModelLabels{None{},[],Some{"m"}}}]},"exact Kd words and signed zero")
    Runtime.fail_obj(Runtime.obj() ++ "v 1e65 0 0",3)

def main() -> IO(Unit):
  do IO<Unit>:
    families(64n)
    bytes_rejected()
    material_encodings()
    bounds()
    labels()
    exported:List<&2,U32> <- Ck.read("docs/verification/2026-11-04-model-obj/corpus/wedge.obj")
    Runtime.accepted(Obj.decode(exported,None{}),Ref.wedge(),"Blender closed wedge full source")
    IO.print("192 generated encoding/conservation checks; complete Blender wedge; bytes, exact opacity and reachable scalar boundaries passed.")
