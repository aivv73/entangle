import Base
import ../../src/model-obj.bend as Obj
import ../../src/content.bend as F
import ../../src/asset.bend as Asset


def check(ok:Bool) -> IO(Unit):
  match ok:
    case True{}:IO.print("Source-only OBJ consumer ran without Creation, ECS or Vulkan.")
    case False{}:IO.die(Unit,1,"Invalid model")

def source(result:Result<&2,&2,Asset.Error,F.SourceModel>) -> IO(Unit):
  match result:
    case Done{model}:check(F.model_valid(model))
    case Fail{Asset.Error{code,message}}:IO.die(Unit,1,message)

def main() -> IO(Unit):
  do IO<Unit>:
    result:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load("docs/verification/2026-11-04-model-obj/corpus/sign.obj")
    source(result)
