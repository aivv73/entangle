import Base
import ../../src/content.bend as F
import ../../src/asset.bend as Asset
import ../../src/model-obj.bend as Obj
import ../image-decoder/common.bend as C
import ./reference.bend as Ref

def accepted(result:Result<&2,&2,Asset.Error,F.SourceModel>,+wanted:F.SourceModel,label:String) -> IO(Unit):
  match result:
    case Done{+actual}:C.require(F.model_valid(actual) && F.same_model(actual,wanted),label)
    case Fail{Asset.Error{code,message}}:IO.die(Unit,1,label ++ " " ++ message)

def rejected(result:Result<&2,&2,Asset.Error,F.SourceModel>,code:U32,+label:String) -> IO(Unit):
  match result:
    case Fail{Asset.Error{actual,+message}}:
      do IO<Unit>:
        C.require(U32.is_eq(actual,U32.add(2147483904,code)),label ++ " wrong error " ++ message)
        IO.print("rejected " ++ label ++ " " ++ message)
    case Done{_}:IO.die(Unit,1,label ++ " accepted")

def obj() -> String:"v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n"

def fail_obj(+token:String,code:U32) -> IO(Unit):rejected(Obj.decode(Obj.text(token),None{}),code,token)

def fail_mtl(+token:String,code:U32) -> IO(Unit):rejected(Obj.decode(Obj.text("mtllib mat\n" ++ obj()),Some{Obj.text(token)}),code,token)

def main() -> IO(Unit):
  do IO<Unit>:
    +obj_bytes:List<&2,U32> <- C.read("docs/verification/2026-11-04-model-obj/corpus/sign.obj")
    +mtl:List<&2,U32> <- C.read("docs/verification/2026-11-04-model-obj/corpus/sign.mtl")
    accepted(Obj.decode(obj_bytes,Some{mtl}),Ref.sign(),"complete sign source differs")
    result:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load("docs/verification/2026-11-04-model-obj/corpus/sign.obj")
    accepted(result,Ref.sign(),"synchronous sign source differs")
    fail_obj("v 0 0 0\nv 1 0 0\nv 0 1 0\nf 0 2 3",4)
    fail_obj("v 0 0 0\nv 1 0 0\nv 0 1 0\nf -0 2 3",4)
    fail_obj("v 0 0 0\nf 1 2 3\nv 1 0 0\nv 0 1 0",4)
    fail_obj("v 0 0 0\nv 1 0 0\nv 0 1 0\nf -4 -2 -1",4)
    fail_obj("v 1junk 0 0\nf 1 1 1",3)
    fail_obj("v .5 0 0\nf 1 1 1",3)
    fail_obj("v 1e 0 0\nf 1 1 1",3)
    fail_obj("v 1e39 0 0\nf 1 1 1",3)
    fail_obj("v 0 0 0\nf 2147483648 1 1",4)
    fail_obj("v 0 0 0\nf 1/1 1/1 1/1",4)
    fail_obj("v 0 0 0\nf 1 1 1 1",2)
    fail_obj("v 0 0 0 1\nf 1 1 1",2)
    fail_obj(obj() ++ "vn 0 0 1",2)
    fail_obj(obj() ++ "vt 0 0",2)
    fail_obj(obj() ++ "s 1",2)
    fail_obj(obj() ++ "usemtl missing",5)
    fail_obj("mtllib ../mat\n" ++ obj(),6)
    fail_obj("mtllib /mat\n" ++ obj(),6)
    fail_obj("mtllib a//b\n" ++ obj(),6)
    fail_obj("mtllib https:a\n" ++ obj(),6)
    fail_obj("mtllib a\nmtllib b\n" ++ obj(),1)
    fail_obj("# blank only",11)
    fail_obj(obj() ++ "\r",1)
    fail_obj(obj() ++ "\\\n",2)
    fail_mtl("",5)
    fail_mtl("# only",5)
    fail_mtl("newmtl a",5)
    fail_mtl("newmtl a\nKd 1 0 0\nKd 0 1 0",5)
    fail_mtl("newmtl a\nKd 1 0 0\nd 0.99999999999999999999",5)
    fail_mtl("newmtl a\nKd 1 0 0\nTr 1e-40",5)
    fail_mtl("newmtl a\nKd 1 0 0\nillum 1",5)
    fail_mtl("newmtl a\nKd 1.1 0 0",5)
    fail_mtl("newmtl a\nKd 1 0 0\nmap_Kd texture",2)
    fail_mtl("newmtl a\nKd 1 0 0\nKs 0 0 0",2)
    fail_mtl("newmtl ab\nKd 1 0 0\nnewmtl bA\nKd 0 1 0",5)
    fail_mtl("newmtl a\nKd 1 0 0\nnewmtl a\nKd 0 1 0",5)
    IO.print("Complete source fidelity and strict production rejection checks passed.")
