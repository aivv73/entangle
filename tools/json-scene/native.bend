import Base
import ../../src/scene-file.bend as S
import ../../src/creation.bend as Create
import ../../src/asset.bend as Asset
import ../model-obj/native.bend as Native
import ../model-obj/reference.bend as Ref
import ../verify-creation.bend as Consumer
import ../image-decoder/common.bend as C
import ./runtime.bend as Check

def loaded(result:Result<&2,&2,Asset.Error,Create.Scene>) -> IO(Unit):
  match result:
    case Fail{Asset.Error{_,message}}:IO.die(Unit,1,message)
    case Done{scene}:
      do IO<Unit>:
        actual:Create.Compiled <- Consumer.compiled(Create.compile(scene))
        expected:Create.Compiled <- Consumer.compiled(Create.compile(Check.expected(Ref.sign())))
        Native.compiled(actual,expected,"json-scene",False{})

def main() -> IO(Unit):
  do IO<Unit>:
    _:String <- C.command("mkdir",["-p","build/model-obj"])
    result:Result<&2,&2,Asset.Error,Create.Scene> <- S.load(Check.corpus() ++ "scene.json")
    loaded(result)
