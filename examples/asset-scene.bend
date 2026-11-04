import Base
import ../src/asset.bend as Asset
import ../src/creation.bend as Create
import ./public-creation.bend as Public

def released(pair:Asset.Cache<Create.Scene> & Maybe<&2,Asset.State<Create.Scene>>,scene:Create.Scene) -> IO(Unit):
  match pair:
    case (_,None{}):Public.checked(Create.compile(scene))
    case _:IO.die(Unit,1,"Released scene handle still resolves")

def ready(pair:Asset.Cache<Create.Scene> & Maybe<&2,Asset.State<Create.Scene>>,+handle:Asset.Handle<Create.Scene>) -> IO(Unit):
  match pair:
    case (cache,Some{Asset.Loaded{scene}}):
      released(Asset.lookup(Create.Scene,Asset.release(Create.Scene,cache,handle),handle),scene)
    case _:IO.die(Unit,1,"Scene asset did not load")

def requested(pair:Asset.Cache<Create.Scene> & Asset.Handle<Create.Scene>) -> IO(Unit):
  (cache,+handle) = pair
  do IO<Unit>:
    cache:Asset.Cache<Create.Scene> <- Asset.load(Create.Scene,cache,handle,
      _ => IO.pure(Result<&2,&2,Asset.Error,Create.Scene>,Done{Public.content()}))
    ready(Asset.lookup(Create.Scene,cache,handle),handle)

def main() -> IO(Unit):
  requested(Asset.request(Create.Scene,Asset.new(Create.Scene,"scene-example"),"public-scene"))
