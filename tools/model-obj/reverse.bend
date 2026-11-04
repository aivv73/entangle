import Base
import ../../src/model-obj.bend as Obj
import ../image-decoder/common.bend as C
import ../image-decoder/replace.bend as Replace

def reversed(source:String) -> String:
  Replace.all(Replace.all(Replace.all(Replace.all(Replace.all(Replace.all(source,"f 1 2 3","f 1 3 2"),"f 1 3 4","f 1 4 3"),"f 5 6 7","f 5 7 6"),"f 5 7 8","f 5 8 7"),"f -4 -3 -2","f -4 -2 -3"),"f -4 -2 -1","f -4 -1 -2")

def args(values:List<String>) -> IO(Unit):
  match values:
    case _ <> path <> _:
      do IO<Unit>:
        bytes:List<&2,U32> <- C.read("docs/verification/2026-11-04-model-obj/corpus/sign.obj")
        C.write(path,Obj.text(reversed(Obj.string(bytes))))
    case _:IO.die(Unit,1,"Usage: reverse destination.obj")

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<String> <- IO.args()
    args(values)
