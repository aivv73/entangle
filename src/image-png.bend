import Base
import ./asset.bend as Asset
import ./content.bend as Content
import ../deps/jonlib-png/png.bend as Png
import ../deps/jonlib-png/codec.bend as Codec

# Engine errors use bit 31. Native errno values retain their code and message.
def decoder_error(error:Codec.Error) -> Asset.Error:
  match error:
    case Codec.BadHeader{}:Asset.Error{2147483649,"PNG BadHeader"}
    case Codec.BadByte{}:Asset.Error{2147483650,"PNG BadByte"}
    case Codec.BadSize{}:Asset.Error{2147483651,"PNG BadSize"}
    case Codec.Truncated{}:Asset.Error{2147483652,"PNG Truncated"}
    case Codec.BadStream{}:Asset.Error{2147483653,"PNG BadStream"}

# Consume the affine tree in index order, constructing reusable words.
def array_words(array:Array<U32>,tail:List<&2,U32>) -> List<&2,U32>:
  match array:
    case ALeaf{value}:value <> tail
    case ANode{left,right}:array_words(left,array_words(right,tail))

def checked(image:Content.SourceImage,valid:Bool) -> Result<&2,&2,Asset.Error,Content.SourceImage>:
  match valid:
    case True{}:Done{image}
    case False{}:Fail{Asset.Error{2147483654,"PNG output violates image storage"}}

def picture(result:Result<&1,&1,Codec.Error,Codec.Picture>) -> Result<&2,&2,Asset.Error,Content.SourceImage>:
  match result:
    case Fail{error}:Fail{decoder_error(error)}
    case Done{Codec.Picture{+width,+height,_,pixels}}:
      +image:Content.SourceImage = Content.SourceImage{width,height,List.take(&2,U32,array_words(pixels,[]),Nat.mul(U32.to_nat(width),U32.to_nat(height)))}
      checked(image,Content.image_valid(image))

def decode(+bytes:List<&2,U32>) -> Result<&2,&2,Asset.Error,Content.SourceImage>:
  picture(Png.decode(bytes))

def exact(bytes:List<&2,U32>,complete:Bool) -> Result<&2,&2,Asset.Error,Content.SourceImage>:
  match complete:
    case True{}:decode(bytes)
    case False{}:Fail{Asset.Error{2147483655,"PNG file size changed or read was incomplete"}}

def read_result(result:Result<&1,&1,U32 & String,List<&2,U32>>,size:U32) -> Result<&2,&2,Asset.Error,Content.SourceImage>:
  match result:
    case Fail{(code,message)}:Fail{Asset.Error{code,message}}
    case Done{+bytes}:exact(bytes,Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(size)))

def read_closed(pair:File & Result<&1,&1,U32 & String,List<&2,U32>>,size:U32) -> IO(Result<&2,&2,Asset.Error,Content.SourceImage>):
  (file,result) = pair
  do IO<Result<&2,&2,Asset.Error,Content.SourceImage>>:
    File.close(file)
    return read_result(result,size)

def read_bounded(file:File,+size:U32,fits:Bool) -> IO(Result<&2,&2,Asset.Error,Content.SourceImage>):
  match fits:
    case False{}:
      do IO<Result<&2,&2,Asset.Error,Content.SourceImage>>:
        File.close(file)
        return Fail{Asset.Error{2147483651,"PNG encoded input exceeds 2097152 bytes"}}
    case True{}:
      do IO<Result<&2,&2,Asset.Error,Content.SourceImage>>:
        pair:File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,U32.inc(size))
        read_closed(pair,size)

def read_sized(pair:File & Result<&1,&1,U32 & String,U32>) -> IO(Result<&2,&2,Asset.Error,Content.SourceImage>):
  match pair:
    case (file,Fail{(code,message)}):
      do IO<Result<&2,&2,Asset.Error,Content.SourceImage>>:
        File.close(file)
        return Fail{Asset.Error{code,message}}
    case (file,Done{+size}):read_bounded(file,size,U32.is_le(size,2097152))

def read_opened(result:Result<&1,&1,U32 & String,File>) -> IO(Result<&2,&2,Asset.Error,Content.SourceImage>):
  match result:
    case Fail{(code,message)}:IO.pure(Result<&2,&2,Asset.Error,Content.SourceImage>,Fail{Asset.Error{code,message}})
    case Done{file}:
      do IO<Result<&2,&2,Asset.Error,Content.SourceImage>>:
        pair:File & Result<&1,&1,U32 & String,U32> <- File.size(file)
        read_sized(pair)

def load(path:String) -> IO(Result<&2,&2,Asset.Error,Content.SourceImage>):
  do IO<Result<&2,&2,Asset.Error,Content.SourceImage>>:
    opened:Result<&1,&1,U32 & String,File> <- File.open(path,"r")
    read_opened(opened)
