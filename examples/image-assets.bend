import Base
import ../src/asset.bend as Asset
import ../src/content.bend as Content
import ../src/image-png.bend as Png

def describe(state:Maybe<&2,Asset.State<Content.SourceImage>>) -> String:
  match state:
    case None{}:"Missing"
    case Some{Asset.Loading{}}:"Loading"
    case Some{Asset.Failed{Asset.Error{code,message}}}:"Failed " ++ U32.show(code) ++ " " ++ message
    case Some{Asset.Loaded{Content.SourceImage{w,h,pixels}}}:"Loaded " ++ U32.show(w) ++ "x" ++ U32.show(h) ++ " pixels=" ++ Nat.show(List.length(&2,U32,pixels))

def report(pair:Asset.Cache<Content.SourceImage> & Maybe<&2,Asset.State<Content.SourceImage>>) -> IO(Asset.Cache<Content.SourceImage>):
  (cache,state) = pair
  do IO<Asset.Cache<Content.SourceImage>>:
    IO.print(describe(state))
    return cache

def requested(pair:Asset.Cache<Content.SourceImage> & Asset.Handle<Content.SourceImage>) -> IO(Unit):
  (cache,+handle) = pair
  do IO<Unit>:
    cache:Asset.Cache<Content.SourceImage> <- report(Asset.lookup(Content.SourceImage,cache,handle))
    cache:Asset.Cache<Content.SourceImage> <- Asset.load(Content.SourceImage,cache,handle,Png.load)
    cache:Asset.Cache<Content.SourceImage> <- report(Asset.lookup(Content.SourceImage,cache,handle))
    cache:Asset.Cache<Content.SourceImage> = Asset.release(Content.SourceImage,cache,handle)
    _:Asset.Cache<Content.SourceImage> <- report(Asset.lookup(Content.SourceImage,cache,handle))
    return Unit{}

def args(values:List<String>) -> IO(Unit):
  match values:
    case _ <> path <> _:requested(Asset.request(Content.SourceImage,Asset.new(Content.SourceImage,"image-example"),path))
    case _:IO.die(Unit,1,"Usage: image-assets path.png")

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<String> <- IO.args()
    args(values)
