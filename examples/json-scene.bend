import Base
import ../src/scene-file.bend as SceneFile
import ../src/asset.bend as Asset
import ../src/creation.bend as Create
import ../src/content.bend as F

def checked(result:Result<&2,&2,Create.Error,Create.Compiled>) -> IO(Unit):
  match result:
    case Fail{_}:IO.die(Unit,1,"Loaded scene failed compilation")
    case Done{Create.Compiled{seeds,Create.Geometry{vertices,indices,ranges}}}:
      IO.print("Loaded JSON scene. instances=" ++ Nat.show(List.length(&2,Create.Seed,seeds)) ++ " vertices=" ++ Nat.show(List.length(&2,F.Vertex,vertices)) ++ " indices=" ++ Nat.show(List.length(&2,U32,indices)) ++ " ranges=" ++ Nat.show(List.length(&2,Create.Range,ranges)))

def loaded(result:Result<&2,&2,Asset.Error,Create.Scene>) -> IO(Unit):
  match result:
    case Fail{Asset.Error{code,message}}:IO.die(Unit,1,U32.show(code) ++ " " ++ message)
    case Done{scene}:checked(Create.compile(scene))

def run(args:List<String>) -> IO(Unit):
  match args:
    case [_,path]:
      do IO<Unit>:
        result:Result<&2,&2,Asset.Error,Create.Scene> <- SceneFile.load(path)
        loaded(result)
    case _:IO.die(Unit,1,"Usage: json-scene SCENE.json")

def main() -> IO(Unit):
  do IO<Unit>:
    args:List<String> <- IO.args()
    run(args)
