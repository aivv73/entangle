import Base
import ./common.bend as C
import ../../deps/jonlib-png/png.bend as Png
import ../../deps/jonlib-png/codec.bend as Codec

def error(value:Codec.Error) -> String:
  match value:
    case Codec.BadHeader{}:"BadHeader"
    case Codec.BadByte{}:"BadByte"
    case Codec.BadSize{}:"BadSize"
    case Codec.Truncated{}:"Truncated"
    case Codec.BadStream{}:"BadStream"

def report(result:Result<&1,&1,Codec.Error,Codec.Picture>,width:U32,height:U32,expected:List<&2,U32>) -> String:
  match result:
    case Fail{value}:"rejected " ++ error(value)
    case Done{Codec.Picture{+w,+h,_,pixels}}:C.checked(w,h,List.take(&2,U32,C.array_words(pixels,[]),Nat.mul(U32.to_nat(w),U32.to_nat(h))),width,height,expected)

def args(values:List<String>) -> IO(Unit):
  match values:
    case _ <> +path <> raw <> width <> height <> _:
      do IO<Unit>:
        bytes:List<&2,U32> <- C.read(path)
        expected:List<&2,U32> <- C.read(raw)
        IO.print(report(Png.decode(C.probe_input(path,bytes)),C.number(width),C.number(height),C.reference(expected)))
    case _:IO.die(Unit,1,"Usage: jonlib-probe image.png reference.rgba width height")

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<String> <- IO.args()
    args(values)
