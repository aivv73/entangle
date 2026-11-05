import Base
import ../../src/model-obj.bend as Obj
import ../../src/content.bend as F
import ../../src/components.bend as C
import ../../src/asset.bend as Asset
import ./runtime.bend as Runtime
import ./properties.bend as P
import ../image-decoder/common.bend as Check
import ../../deps/jonlib-obj/obj.bend as J

def material_name(fuel:Nat,found:Maybe<&2,String>,+slot:U32,+candidate:U32) -> String:
  match fuel found:
    case _,Some{name}:name
    case 0n,None{}:"exhausted-name-search"
    case 1n+rest,None{}:
      +name = "m" ++ U32.show(candidate)
      material_name(rest,Bool.pick(Maybe<&2,String>,U32.is_eq(J.h64.mod(J.djb2(Obj.text(name)),160),slot),Some{name},None{}),slot,U32.inc(candidate))

def materials(n:Nat) -> String:
  match n:
    case 0n:""
    case 1n+ +rest:"newmtl " ++ material_name(10000n,None{},U32.from_nat(rest),0) ++ "\nKd 0 0 0\n" ++ materials(rest)

def parts(n:Nat) -> String:
  match n:
    case 0n:""
    case 1n+ +rest:"g p" ++ Nat.show(rest) ++ "\nf 1 1 1\n" ++ parts(rest)

def accepted(result:Result<&2,&2,Asset.Error,F.SourceModel>,wanted:Nat) -> IO(Unit):
  match result:
    case Done{F.SourceModel{+parts}}:Check.require(Nat.is_eq(List.length(&2,F.ModelPart,parts),wanted) && F.model_valid(F.SourceModel{parts}),"Bounded production source failed")
    case Fail{Asset.Error{code,message}}:IO.die(Unit,1,"At-limit source refused " ++ message)

def indices(values:List<&2,U32>,+next:U32) -> Bool:
  match values:
    case []:True{}
    case i <> rest:U32.is_eq(i,next) && indices(rest,U32.inc(next))

def vertices(values:List<&2,F.Vertex>) -> Bool:
  match values:
    case []:True{}
    case value <> rest:F.same_vertices([value],[F.Vertex{C.Vec3{0.0,0.0,0.0},C.Vec3{1.0,1.0,1.0},F.UV{0.0,0.0},C.Vec3{0.0,0.0,1.0}}]) && vertices(rest)

def geometry_words(model:F.SourceModel) -> Bool:
  match model:
    case F.SourceModel{[F.ModelPart{F.Mesh{+vs,+is1},m,l}]}:
      Nat.is_eq(List.length(&2,F.Vertex,vs),381300n) && Nat.is_eq(List.length(&2,U32,is1),381300n) && vertices(vs) && indices(is1,0) && F.same_material(m,F.white()) && F.same_labels(l,F.ModelLabels{None{},[],None{}})
    case _:False{}

def geometry(result:Result<&2,&2,Asset.Error,F.SourceModel>) -> IO(Unit):
  match result:
    case Done{+model}:
      Check.require(F.model_valid(model) && geometry_words(model),"Expanded geometry limit conservation failed")
    case Fail{Asset.Error{code,message}}:IO.die(Unit,1,message)

def padding(n:Nat) -> String:
  match n:
    case 0n:""
    case 1n+rest:"#" ++ String.repeat("x",4094n) ++ "\n" ++ padding(rest)

def exact_bytes(+prefix:String,+limit:Nat) -> String:
  prefix ++ String.take(padding(512n),Nat.sub(limit,String.length(prefix)))

def main() -> IO(Unit):
  do IO<Unit>:
    +obj:String = Runtime.obj()
    Runtime.accepted(Obj.decode(Obj.text("mtllib a\n" ++ obj),Some{Obj.text(materials(128n))}),P.expected(1n),"128 unused materials")
    Runtime.rejected(Obj.decode(Obj.text("mtllib a\n" ++ obj),Some{Obj.text(materials(129n))}),7,"129 materials")
    accepted(Obj.decode(Obj.text("v 0 0 0\n" ++ parts(4096n)),None{}),4096n)
    Runtime.rejected(Obj.decode(Obj.text("v 0 0 0\n" ++ parts(4097n)),None{}),7,"4097 parts")
    Check.require(Nat.is_eq(String.length(exact_bytes(obj,Obj.obj_limit())),Obj.obj_limit()),"OBJ byte oracle length")
    Runtime.accepted(Obj.decode(Obj.text(exact_bytes(obj,Obj.obj_limit())),None{}),P.expected(1n),"OBJ at 2 MiB")
    Runtime.rejected(Obj.decode(Obj.text(exact_bytes(obj,Obj.obj_limit()) ++ "x"),None{}),7,"OBJ over 2 MiB")
    Runtime.accepted(Obj.decode(Obj.text("mtllib a\n" ++ obj),Some{Obj.text(exact_bytes("newmtl a\nKd 0 0 0\n",Obj.mtl_limit()))}),P.expected(1n),"MTL at 256 KiB")
    Runtime.rejected(Obj.decode(Obj.text("mtllib a\n" ++ obj),Some{Obj.text(exact_bytes("newmtl a\nKd 0 0 0\n",Obj.mtl_limit()) ++ "x")}),7,"MTL over 256 KiB")
    geometry(Obj.decode(Obj.text("v 0 0 0\n" ++ P.repeats(127100n,"f 1 1 1\n")),None{}))
    Runtime.rejected(Obj.decode(Obj.text("v 0 0 0\n" ++ P.repeats(127101n,"f 1 1 1\n")),None{}),7,"expanded geometry over 381300 vertices")
    path:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(String.repeat("x",4097n))
    Runtime.rejected(path,6,"root path over 4096 UTF-8 bytes")
    path:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(SCon{Char.from_u32(0),"x"})
    Runtime.rejected(path,6,"root path NUL")
    IO.print("Production byte/material/part/expanded-geometry bounds checked at and over admission limits; every one of 381300 emitted vertices and indices checked.")
