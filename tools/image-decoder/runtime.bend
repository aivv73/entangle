import Base
import ./common.bend as C
import ./corpus.bend as Corpus
import ./probes.bend as Probes
import ../../src/asset.bend as Asset
import ../../src/content.bend as Content
import ../../src/image-png.bend as Png

def image_equal(a:Content.SourceImage,b:Content.SourceImage) -> Bool:
  Content.SourceImage{w,h,p} = a
  Content.SourceImage{x,y,q} = b
  U32.is_eq(w,x) && U32.is_eq(h,y) && C.equal(p,q)

def exact(result:Result<&2,&2,Asset.Error,Content.SourceImage>,+expected:Content.SourceImage,+label:String) -> IO(Unit):
  match result:
    case Fail{Asset.Error{code,message}}:IO.die(Unit,1,label ++ " failed " ++ U32.show(code) ++ " " ++ message)
    case Done{+image}:C.require(Content.image_valid(image) && image_equal(image,expected),label ++ " pixels differ")

def rejected(result:Result<&2,&2,Asset.Error,Content.SourceImage>,wanted:U32,label:String) -> IO(Unit):
  match result:
    case Fail{Asset.Error{+code,_}}:C.require(U32.is_eq(code,wanted),label ++ " wrong error " ++ U32.show(code))
    case Done{_}:IO.die(Unit,1,label ++ " was accepted")

def all_images(items:List<&2,Corpus.Case>) -> IO(Unit):
  match items:
    case []:IO.pure(Unit,Unit{})
    case Corpus.Case{+name,+w,+h,_} <> rest:
      do IO<Unit>:
        +bytes:List<&2,U32> <- C.read(Corpus.output() ++ "/" ++ name ++ ".png")
        reference:List<&2,U32> <- C.read(Corpus.output() ++ "/" ++ name ++ ".rgba")
        +expected:Content.SourceImage = Content.SourceImage{w,h,C.reference(reference)}
        exact(Png.decode(bytes),expected,name ++ " decode")
        result:Result<&2,&2,Asset.Error,Content.SourceImage> <- Png.load(Corpus.output() ++ "/" ++ name ++ ".png")
        exact(result,expected,name ++ " file")
        IO.print(name ++ " decode=file=all-pixels-exact")
        all_images(rest)

def error_file(+name:String,+code:U32) -> IO(Unit):
  do IO<Unit>:
    +bytes:List<&2,U32> <- C.read(Corpus.output() ++ "/" ++ name ++ ".png")
    rejected(Png.decode(bytes),code,name ++ " decode")
    result:Result<&2,&2,Asset.Error,Content.SourceImage> <- Png.load(Corpus.output() ++ "/" ++ name ++ ".png")
    rejected(result,code,name ++ " file")
    IO.print(name ++ " decode=file=error " ++ U32.show(code))

def accepted(+name:String) -> IO(Unit):
  do IO<Unit>:
    bytes:List<&2,U32> <- C.read(Corpus.output() ++ "/" ++ name ++ ".png")
    exact(Png.decode(bytes),Content.SourceImage{1,1,[287454080]},name)
    result:Result<&2,&2,Asset.Error,Content.SourceImage> <- Png.load(Corpus.output() ++ "/" ++ name ++ ".png")
    exact(result,Content.SourceImage{1,1,[287454080]},name ++ " file")
    IO.print(name ++ " tolerated=all-pixels-exact")

def state(pair:Asset.Cache<Content.SourceImage> & Maybe<&2,Asset.State<Content.SourceImage>>,+wanted:Content.SourceImage) -> IO(Asset.Cache<Content.SourceImage> & Content.SourceImage):
  match pair:
    case (cache,Some{Asset.Loaded{+image}}):
      do IO<Asset.Cache<Content.SourceImage> & Content.SourceImage>:
        C.require(image_equal(image,wanted),"Asset changed image pixels")
        return (cache,image)
    case _:IO.die(Asset.Cache<Content.SourceImage> & Content.SourceImage,1,"Image asset was not Loaded")

def absent(pair:Asset.Cache<Content.SourceImage> & Maybe<&2,Asset.State<Content.SourceImage>>) -> IO(Asset.Cache<Content.SourceImage>):
  match pair:
    case (cache,None{}):IO.pure(Asset.Cache<Content.SourceImage>,cache)
    case _:IO.die(Asset.Cache<Content.SourceImage>,1,"Released image remains present")

def shared(pair:Asset.Cache<Content.SourceImage> & Asset.Handle<Content.SourceImage>,old:Asset.Handle<Content.SourceImage>) -> IO(Asset.Cache<Content.SourceImage>):
  (cache,actual) = pair
  Asset.Handle{s,id} = actual
  Asset.Handle{t,other} = old
  do IO<Asset.Cache<Content.SourceImage>>:
    C.require(String.eq(s,t) && Nat.is_eq(id,other),"Cached request changed image identity")
    return cache

def tracked(path:String) -> IO(Result<&2,&2,Asset.Error,Content.SourceImage>):
  +path = path
  do IO<Result<&2,&2,Asset.Error,Content.SourceImage>>:
    file:File <- IO.try(File,File.open(path ++ ".reads","a"))
    pair:File & Result<&1,&1,U32 & String,Unit> <- File.write(file,"x")
    C.written(pair)
    Png.load(path)

def failed_state(pair:Asset.Cache<Content.SourceImage> & Maybe<&2,Asset.State<Content.SourceImage>>,wanted:Asset.Error) -> IO(Asset.Cache<Content.SourceImage>):
  match pair wanted:
    case (cache,Some{Asset.Failed{Asset.Error{code,message}}}) Asset.Error{c,m}:
      do IO<Asset.Cache<Content.SourceImage>>:
        C.require(U32.is_eq(code,c) && String.eq(message,m),"Cached failure changed after repair")
        return cache
    case _ _:IO.die(Asset.Cache<Content.SourceImage>,1,"Image failure was not cached")

def cache_only(pair:Asset.Cache<Content.SourceImage> & Content.SourceImage) -> Asset.Cache<Content.SourceImage>:
  (cache,_) = pair
  cache

def release_retained(pair:Asset.Cache<Content.SourceImage> & Content.SourceImage,+handle:Asset.Handle<Content.SourceImage>,expected:Content.SourceImage) -> IO(Asset.Cache<Content.SourceImage>):
  (cache,retained) = pair
  do IO<Asset.Cache<Content.SourceImage>>:
    cache:Asset.Cache<Content.SourceImage> = Asset.release(Content.SourceImage,cache,handle)
    cache:Asset.Cache<Content.SourceImage> <- absent(Asset.lookup(Content.SourceImage,cache,handle))
    C.require(image_equal(retained,expected),"Released cache damaged retained image")
    return cache

def retry(pair:Asset.Cache<Content.SourceImage> & Asset.Handle<Content.SourceImage>,old:Asset.Handle<Content.SourceImage>,+path:String,+expected:Content.SourceImage) -> IO(Unit):
  (cache,+handle) = pair
  Asset.Handle{_,id} = handle
  Asset.Handle{_,previous} = old
  do IO<Unit>:
    C.require(Bool.not(Nat.is_eq(id,previous)),"Retry revived old identity")
    cache:Asset.Cache<Content.SourceImage> <- Asset.load(Content.SourceImage,cache,handle,tracked)
    pair:Asset.Cache<Content.SourceImage> & Content.SourceImage <- state(Asset.lookup(Content.SourceImage,cache,handle),expected)
    _:Asset.Cache<Content.SourceImage> <- release_retained(pair,handle,expected)
    reads:List<&2,U32> <- C.read(path ++ ".reads")
    C.require(C.equal(reads,[120,120,120]),"Image loader invocation count differs")
    IO.print("Full image retained after release; repeated load cached; failure stable after repair; release/request/load retry recovered; actual loader calls=3.")

def failure(pair:Asset.Cache<Content.SourceImage> & Maybe<&2,Asset.State<Content.SourceImage>>,+handle:Asset.Handle<Content.SourceImage>,+path:String,bytes:List<&2,U32>,expected:Content.SourceImage) -> IO(Unit):
  match pair:
    case (cache,Some{Asset.Failed{+error}}):
      do IO<Unit>:
        C.write(path,bytes)
        cache:Asset.Cache<Content.SourceImage> <- shared(Asset.request(Content.SourceImage,cache,path),handle)
        cache:Asset.Cache<Content.SourceImage> <- Asset.load(Content.SourceImage,cache,handle,tracked)
        cache:Asset.Cache<Content.SourceImage> <- failed_state(Asset.lookup(Content.SourceImage,cache,handle),error)
        retry(Asset.request(Content.SourceImage,Asset.release(Content.SourceImage,cache,handle),path),handle,path,expected)
    case _:IO.die(Unit,1,"Corrupt file did not become Failed")

def corrupt(pair:Asset.Cache<Content.SourceImage> & Asset.Handle<Content.SourceImage>,+path:String,bytes:List<&2,U32>,expected:Content.SourceImage) -> IO(Unit):
  (cache,+handle) = pair
  do IO<Unit>:
    cache:Asset.Cache<Content.SourceImage> <- Asset.load(Content.SourceImage,cache,handle,tracked)
    failure(Asset.lookup(Content.SourceImage,cache,handle),handle,path,bytes,expected)

def loaded(pair:Asset.Cache<Content.SourceImage> & Asset.Handle<Content.SourceImage>,+path:String,+bytes:List<&2,U32>,+expected:Content.SourceImage) -> IO(Unit):
  (cache,+handle) = pair
  do IO<Unit>:
    cache:Asset.Cache<Content.SourceImage> <- Asset.load(Content.SourceImage,cache,handle,tracked)
    pair:Asset.Cache<Content.SourceImage> & Content.SourceImage <- state(Asset.lookup(Content.SourceImage,cache,handle),expected)
    cache:Asset.Cache<Content.SourceImage> = cache_only(pair)
    C.write(path,[])
    cache:Asset.Cache<Content.SourceImage> <- shared(Asset.request(Content.SourceImage,cache,path),handle)
    cache:Asset.Cache<Content.SourceImage> <- Asset.load(Content.SourceImage,cache,handle,tracked)
    pair:Asset.Cache<Content.SourceImage> & Content.SourceImage <- state(Asset.lookup(Content.SourceImage,cache,handle),expected)
    cache:Asset.Cache<Content.SourceImage> <- release_retained(pair,handle,expected)
    corrupt(Asset.request(Content.SourceImage,cache,path),path,bytes,expected)

def lifecycle() -> IO(Unit):
  do IO<Unit>:
    +bytes:List<&2,U32> <- C.read(Corpus.output() ++ "/june-rgb8.png")
    raw:List<&2,U32> <- C.read(Corpus.output() ++ "/june-rgb8.rgba")
    C.write(Corpus.output() ++ "/lifecycle.png",bytes)
    C.write(Corpus.output() ++ "/lifecycle.png.reads",[])
    loaded(Asset.request(Content.SourceImage,Asset.new(Content.SourceImage,"image-runtime"),Corpus.output() ++ "/lifecycle.png"),Corpus.output() ++ "/lifecycle.png",bytes,Content.SourceImage{320,260,C.reference(raw)})

def main() -> IO(Unit):
  do IO<Unit>:
    all_images(Corpus.cases())
    accepted("stored")
    accepted("bad-crc")
    accepted("bad-adler")
    accepted("trailing")
    error_file("duplicate-ihdr",2147483649)
    accepted("cgbi")
    accepted("input-at-limit")
    error_file("empty",2147483649)
    error_file("truncated",2147483649)
    error_file("bad-signature",2147483649)
    error_file("unsupported",2147483649)
    error_file("zero-width",2147483651)
    error_file("width4097",2147483651)
    error_file("height4097",2147483651)
    error_file("filtered-over-limit",2147483651)
    error_file("inflate-overrun",2147483653)
    error_file("inflate-short",2147483653)
    error_file("bad-filter",2147483653)
    error_file("input-over-limit",2147483651)
    rejected(Png.decode([256]),2147483650,"non-byte")
    C.require(Content.image_valid(Content.SourceImage{4097,1,List.replicate(U32,4097n,0)}),"Source validity inherited PNG side limits")
    lifecycle()
    IO.print("PNG production adapter verified.")
