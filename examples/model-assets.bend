import Base
import ../src/content.bend as F
import ../src/components.bend as C
import ../src/model-obj.bend as Obj
import ../src/asset.bend as Asset
import ../src/creation.bend as Create
import ../src/scene.bend as Scene

def instances(parts:List<&2,F.ModelPart>,+transform:C.Transform) -> List<&2,Create.Instance>:
  match parts:
    case []:[]
    case F.ModelPart{mesh,material,_} <> rest:Create.Instance{mesh,material,transform} <> instances(rest,transform)

def content(model:F.SourceModel) -> Create.Scene:
  F.SourceModel{parts} = model
  Create.Scene{instances(parts,C.Transform.identity())}

def run(result:Result<&2,&2,Create.Error,Create.Compiled>) -> IO(Unit):
  match result:
    case Fail{_}:IO.die(Unit,1,"Model does not fit scene creation")
    case Done{Create.Compiled{seeds,_}}:
      do IO<Unit>:
        app:Scene.Application() <- Scene.create(seeds)
        app:Scene.Application() <- Scene.tick(app)
        _:Scene.Application() <- Scene.tick(app)
        IO.print("Imported model parts completed two production ECS ticks after cache release.")

def retained(pair:Asset.Cache<F.SourceModel> & Maybe<&2,Asset.State<F.SourceModel>>,handle:Asset.Handle<F.SourceModel>) -> IO(Unit):
  match pair:
    case (cache,Some{Asset.Loaded{model}}):
      do IO<Unit>:
        _:Asset.Cache<F.SourceModel> = Asset.release(F.SourceModel,cache,handle)
        run(Create.compile(content(model)))
    case (_,Some{Asset.Failed{Asset.Error{code,message}}}):IO.die(Unit,1,message)
    case _:IO.die(Unit,1,"Synchronous model load did not settle")

def requested(pair:Asset.Cache<F.SourceModel> & Asset.Handle<F.SourceModel>) -> IO(Unit):
  (cache,+handle) = pair
  do IO<Unit>:
    cache:Asset.Cache<F.SourceModel> <- Asset.load(F.SourceModel,cache,handle,Obj.load)
    retained(Asset.lookup(F.SourceModel,cache,handle),handle)

def args(values:List<String>) -> IO(Unit):
  match values:
    case _ <> path <> _:requested(Asset.request(F.SourceModel,Asset.new(F.SourceModel,"model-example"),path))
    case _:IO.die(Unit,1,"Usage: model-assets path-to-triangulated-OBJ")

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<String> <- IO.args()
    args(values)
