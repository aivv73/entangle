import Base
import emerging-ezimg@1.3.0.0/main.bend as Ezimg
import ./common.bend as C

def pixels(values:List<&2,U32>) -> List<&2,U32>:
  match values:
    case []:[]
    case +word <> rest:((word << 8n) .|. (word >> 24n) : U32) <> pixels(rest)

def report(result:Maybe<&2,Ezimg.Raster>,width:U32,height:U32,expected:List<&2,U32>) -> String:
  match result:
    case None{}:"rejected None"
    case Some{Ezimg.Raster{w,h,px}}:C.checked(w,h,pixels(px),width,height,expected)

def args(values:List<String>) -> IO(Unit):
  match values:
    case _ <> +path <> raw <> width <> height <> _:
      do IO<Unit>:
        bytes:List<&2,U32> <- C.read(path)
        expected:List<&2,U32> <- C.read(raw)
        IO.print(report(Ezimg.decode_png(C.probe_input(path,bytes)),C.number(width),C.number(height),C.reference(expected)))
    case _:IO.die(Unit,1,"Usage: ezimg-probe image.png reference.rgba width height")

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<String> <- IO.args()
    args(values)
