import Base
import ../../src/scene-file.bend as S
import ../../src/creation.bend as Create
import ../../src/asset.bend as Asset
import ../image-decoder/common.bend as C
import ../verify-upload-mutations.bend as Files
import ./runtime.bend as Check

def expect(pair:Asset.Cache<Create.Scene> & Maybe<&2,Asset.State<Create.Scene>>,wanted:U32) -> IO(Asset.Cache<Create.Scene>):
  match pair:
    case (cache,Some{Asset.Loaded{+scene}}):
      do IO<Asset.Cache<Create.Scene>>:
        C.require(U32.is_eq(wanted,0),"cache unexpectedly loaded")
        Check.good(Done{scene})
        return cache
    case (cache,Some{Asset.Failed{_}}):
      do IO<Asset.Cache<Create.Scene>>:
        C.require(U32.is_eq(wanted,1),"cache unexpectedly failed")
        return cache
    case (cache,None{}):
      do IO<Asset.Cache<Create.Scene>>:
        C.require(U32.is_eq(wanted,2),"cache unexpectedly released")
        return cache
    case _:IO.die(Asset.Cache<Create.Scene>,1,"cache left Loading")

def retried(pair:Asset.Cache<Create.Scene> & Asset.Handle<Create.Scene>,+old:Asset.Handle<Create.Scene>) -> IO(Unit):
  (cache,+handle) = pair
  do IO<Unit>:
    cache:Asset.Cache<Create.Scene> <- expect(Asset.lookup(Create.Scene,cache,old),2)
    cache:Asset.Cache<Create.Scene> <- Asset.load(Create.Scene,cache,handle,S.load)
    cache:Asset.Cache<Create.Scene> <- expect(Asset.lookup(Create.Scene,cache,handle),0)
    _:Asset.Cache<Create.Scene> <- expect(Asset.lookup(Create.Scene,Asset.release(Create.Scene,cache,handle),handle),2)
    IO.print("JSON source cache preserves success and failure, releases handles, and retries with fresh identity.")

def failed(pair:Asset.Cache<Create.Scene> & Asset.Handle<Create.Scene>,scene:String) -> IO(Unit):
  (cache,+handle) = pair
  do IO<Unit>:
    cache:Asset.Cache<Create.Scene> <- Asset.load(Create.Scene,cache,handle,S.load)
    cache:Asset.Cache<Create.Scene> <- expect(Asset.lookup(Create.Scene,cache,handle),1)
    Check.write_scene(scene)
    cache:Asset.Cache<Create.Scene> <- Asset.load(Create.Scene,cache,handle,S.load)
    cache:Asset.Cache<Create.Scene> <- expect(Asset.lookup(Create.Scene,cache,handle),1)
    retried(Asset.request(Create.Scene,Asset.release(Create.Scene,cache,handle),Check.folder() ++ "scene.json"),handle)

def retained(pair:Asset.Cache<Create.Scene> & Maybe<&2,Asset.State<Create.Scene>>,+handle:Asset.Handle<Create.Scene>,scene:String) -> IO(Unit):
  match pair:
    case (cache,Some{Asset.Loaded{value}}):
      do IO<Unit>:
        cache:Asset.Cache<Create.Scene> <- expect(Asset.lookup(Create.Scene,Asset.release(Create.Scene,cache,handle),handle),2)
        Check.good(Done{value})
        failed(Asset.request(Create.Scene,cache,Check.folder() ++ "scene.json"),scene)
    case _:IO.die(Unit,1,"retained scene unavailable")

def loaded(pair:Asset.Cache<Create.Scene> & Asset.Handle<Create.Scene>,scene:String) -> IO(Unit):
  (cache,+handle) = pair
  do IO<Unit>:
    cache:Asset.Cache<Create.Scene> <- Asset.load(Create.Scene,cache,handle,S.load)
    cache:Asset.Cache<Create.Scene> <- expect(Asset.lookup(Create.Scene,cache,handle),0)
    Check.write_scene("{")
    cache:Asset.Cache<Create.Scene> <- Asset.load(Create.Scene,cache,handle,S.load)
    cache:Asset.Cache<Create.Scene> <- expect(Asset.lookup(Create.Scene,cache,handle),0)
    retained(Asset.lookup(Create.Scene,cache,handle),handle,scene)

def main() -> IO(Unit):
  do IO<Unit>:
    +scene:String <- Check.read_text(Check.corpus() ++ "scene.json")
    Check.write_scene(scene)
    loaded(Asset.request(Create.Scene,Asset.new(Create.Scene,"json-scene-runtime"),Check.folder() ++ "scene.json"),scene)
