import Base
import ../src/model-obj.bend as Obj
import ../src/asset.bend as Asset
import ../src/content.bend as F
import ../src/creation.bend as Create
import ../src/components.bend as C
import ./model-fit.bend as Fit
import ../src/scene-file.bend as File

def parts(values:List<&2,F.ModelPart>,+transform:C.Transform) -> List<&2,Create.Instance>:
  match values:
    case []:[]
    case F.ModelPart{mesh,material,_} <> rest:Create.Instance{mesh,material,transform} <> parts(rest,transform)

def scene(model:F.SourceModel) -> Create.Scene:
  F.SourceModel{+values} = model
  Create.Scene{parts(values,Fit.transform(values))}

def loaded(pair:Asset.Cache<F.SourceModel> & Maybe<&2,Asset.State<F.SourceModel>>,+handle:Asset.Handle<F.SourceModel>) -> IO(Result<&2,&2,Asset.Error,Create.Scene>):
  match pair:
    case (cache,Some{Asset.Loaded{model}}):
      do IO<Result<&2,&2,Asset.Error,Create.Scene>>:
        _:Asset.Cache<F.SourceModel> = Asset.release(F.SourceModel,cache,handle)
        return Done{scene(model)}
    case (_,Some{Asset.Failed{error}}):IO.pure(Result<&2,&2,Asset.Error,Create.Scene>,Fail{error})
    case _:IO.pure(Result<&2,&2,Asset.Error,Create.Scene>,Fail{Asset.Error{1,"Model loading did not settle"}})

def requested(pair:Asset.Cache<F.SourceModel> & Asset.Handle<F.SourceModel>) -> IO(Result<&2,&2,Asset.Error,Create.Scene>):
  (cache,+handle) = pair
  do IO<Result<&2,&2,Asset.Error,Create.Scene>>:
    cache:Asset.Cache<F.SourceModel> <- Asset.load(F.SourceModel,cache,handle,Obj.load)
    loaded(Asset.lookup(F.SourceModel,cache,handle),handle)

def model(path:String) -> IO(Result<&2,&2,Asset.Error,Create.Scene>):
  requested(Asset.request(F.SourceModel,Asset.new(F.SourceModel,"model-viewer"),path))

def required(result:Result<&2,&2,Asset.Error,Create.Scene>) -> IO(Create.Scene):
  match result:
    case Done{scene}:IO.pure(Create.Scene,scene)
    case Fail{Asset.Error{_,message}}:IO.die(Create.Scene,1,message)

def admitted(scene:Create.Scene,result:Result<&2,&2,Create.Error,Create.Compiled>) -> IO(Create.Scene):
  match result:
    case Done{_}:IO.pure(Create.Scene,scene)
    case Fail{_}:
      do IO<Create.Scene>:
        IO.print("Requested model does not fit scene creation. Showing bundled beacon.")
        result:Result<&2,&2,Asset.Error,Create.Scene> <- model("assets/consumers/beacon.obj")
        required(result)

def fallback(result:Result<&2,&2,Asset.Error,Create.Scene>) -> IO(Create.Scene):
  match result:
    case Done{+scene}:admitted(scene,Create.compile(scene))
    case Fail{Asset.Error{_,message}}:
      do IO<Create.Scene>:
        IO.print("Could not open requested model: " ++ message ++ ". Showing bundled beacon.")
        result:Result<&2,&2,Asset.Error,Create.Scene> <- model("assets/consumers/beacon.obj")
        required(result)

def viewer(path:String) -> IO(Create.Scene):
  do IO<Create.Scene>:
    result:Result<&2,&2,Asset.Error,Create.Scene> <- model(path)
    fallback(result)

def gameplay() -> IO(Create.Scene):
  do IO<Create.Scene>:
    result:Result<&2,&2,Asset.Error,Create.Scene> <- File.load("assets/consumers/courier.json")
    required(result)

def compiled(result:Result<&2,&2,Create.Error,Create.Compiled>) -> IO(Create.Compiled):
  match result:
    case Done{compiled}:IO.pure(Create.Compiled,compiled)
    case _:IO.die(Create.Compiled,1,"Consumer scene compilation rejected")
