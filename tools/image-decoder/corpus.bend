import Base
import ./common.bend as C

type Case is Data:
  Case{name:String,width:U32,height:U32,depth:U32}

def root() -> String:"docs/verification/2026-11-04-image-decoder/corpus"
def output() -> String:"build/image-corpus"

def cases() -> List<&2,Case>:
  [Case{"june-rgb8",320,260,8},Case{"june-adam7",320,260,8},Case{"tabby-rgb8",192,256,8},Case{"tabby-palette4",192,256,4},
   Case{"cat-gray8",37,29,8},Case{"cat-ga8",37,29,8},Case{"cat-rgba8",37,29,8},Case{"cat-palette-trns",37,29,8},
   Case{"cat-gray1",37,29,1},Case{"cat-gray2",37,29,2},Case{"cat-gray4",37,29,4},Case{"cat-palette1",37,29,1},Case{"cat-palette2",37,29,2},
   Case{"cat-gray16",37,29,16},Case{"cat-ga16",37,29,16},Case{"cat-rgb16",37,29,16},Case{"cat-rgba16",37,29,16},Case{"cat-rgba-adam7",37,29,8},
   Case{"layout",3,2,8},Case{"width4096",4096,1,8},Case{"height4096",1,4096,8},
   Case{"mesh-palette4",640,480,4},Case{"materials-palette2",640,480,2},Case{"scene-palette1",1024,256,1},Case{"survivors-rgb8",800,394,8}]

def cat(+name:String,+depth:U32,color:U32,options:List<String>) -> IO(Unit):
  do IO<Unit>:
    _:String <- C.command("magick",List.append(&1,String,[root() ++ "/source/june.jpg","-resize","37x29!","-strip"],List.append(&1,String,options,["-depth",U32.show(depth),"-define","png:bit-depth=" ++ U32.show(depth),"-define","png:color-type=" ++ U32.show(color),output() ++ "/" ++ name ++ ".png"])))
    return Unit{}

def reference(+item:Case) -> IO(Unit):
  Case{+name,+w,+h,+depth} = item
  do IO<Unit>:
    +info:String <- C.command("magick",["identify","-format","%w %h %z %[png:IHDR.color-type-orig] %[png:IHDR.interlace_method]",output() ++ "/" ++ name ++ ".png"])
    IO.print(name ++ " " ++ String.trim(info))
    _:String <- C.command("magick",[output() ++ "/" ++ name ++ ".png","-depth",Bool.pick(String,U32.is_eq(depth,16),"16","8"),"-endian","MSB","rgba:" ++ output() ++ "/" ++ name ++ ".raw"])
    +raw:List<&2,U32> <- C.read(output() ++ "/" ++ name ++ ".raw")
    C.write(output() ++ "/" ++ name ++ ".rgba",Bool.pick(List<&2,U32>,U32.is_eq(depth,16),C.high_bytes(raw),raw))
    +pixels:List<&2,U32> <- C.read(output() ++ "/" ++ name ++ ".rgba")
    C.require(Nat.is_eq(List.length(&2,U32,pixels),Nat.mul(4n,Nat.mul(U32.to_nat(w),U32.to_nat(h)))),"Reference dimensions changed for " ++ name)

def references(items:List<&2,Case>) -> IO(Unit):
  match items:
    case []:IO.pure(Unit,Unit{})
    case item <> rest:
      do IO<Unit>:
        reference(item)
        references(rest)

def generate() -> IO(Unit):
  do IO<Unit>:
    _:String <- C.command("mkdir",["-p",output()])
    _:String <- C.command("magick",[root() ++ "/source/june.jpg","-resize","320x260!","-strip","-depth","8","-define","png:color-type=2",output() ++ "/june-rgb8.png"])
    _:String <- C.command("magick",[output() ++ "/june-rgb8.png","-interlace","PNG",output() ++ "/june-adam7.png"])
    _:String <- C.command("magick",[root() ++ "/source/tabby.jpg","-resize","192x256!","-strip","-depth","8","-define","png:color-type=2",output() ++ "/tabby-rgb8.png"])
    _:String <- C.command("magick",[output() ++ "/tabby-rgb8.png","-colors","16","-type","Palette","-define","png:bit-depth=4","-define","png:color-type=3",output() ++ "/tabby-palette4.png"])
    cat("cat-gray8",8,0,["-colorspace","Gray"])
    cat("cat-ga8",8,4,["-colorspace","Gray","-alpha","set","-channel","A","-evaluate","set","53%","+channel"])
    cat("cat-rgba8",8,6,["-alpha","set","-channel","A","-evaluate","set","53%","+channel"])
    cat("cat-palette-trns",8,3,["-alpha","set","-channel","A","-evaluate","set","53%","+channel","-colors","64","-type","PaletteAlpha"])
    cat("cat-gray1",1,0,["-colorspace","Gray"])
    cat("cat-gray2",2,0,["-colorspace","Gray"])
    cat("cat-gray4",4,0,["-colorspace","Gray"])
    cat("cat-palette1",1,3,["-colors","2","-type","Palette"])
    cat("cat-palette2",2,3,["-colors","4","-type","Palette"])
    cat("cat-gray16",16,0,["-colorspace","Gray"])
    cat("cat-ga16",16,4,["-colorspace","Gray","-alpha","set","-channel","A","-evaluate","set","53%","+channel"])
    cat("cat-rgb16",16,2,[])
    cat("cat-rgba16",16,6,["-alpha","set","-channel","A","-evaluate","set","53%","+channel"])
    cat("cat-rgba-adam7",8,6,["-alpha","set","-channel","A","-evaluate","set","53%","+channel","-interlace","PNG"])
    C.write(output() ++ "/layout.raw",[1,17,129,0,31,63,127,1,255,128,7,127,12,34,56,128,65,43,21,254,200,150,100,255])
    _:String <- C.command("magick",["-size","3x2","-depth","8","rgba:" ++ output() ++ "/layout.raw","-define","png:color-type=6",output() ++ "/layout.png"])
    _:String <- C.command("magick",["-size","4096x1","xc:#113377","-depth","8","-define","png:color-type=2",output() ++ "/width4096.png"])
    _:String <- C.command("magick",["-size","1x4096","xc:#773311","-depth","8","-define","png:color-type=2",output() ++ "/height4096.png"])
    _:String <- C.command("cp",[root() ++ "/png/mesh-palette4.png",root() ++ "/png/materials-palette2.png",root() ++ "/png/scene-palette1.png",root() ++ "/png/survivors-rgb8.png",output()])
    references(cases())

def copy_cases(items:List<&2,Case>) -> IO(Unit):
  match items:
    case []:IO.pure(Unit,Unit{})
    case Case{+name,_,_,_} <> rest:
      do IO<Unit>:
        _:String <- C.command("cp",[root() ++ "/png/" ++ name ++ ".png",output() ++ "/" ++ name ++ ".png"])
        copy_cases(rest)

def main() -> IO(Unit):
  do IO<Unit>:
    _:String <- C.command("mkdir",["-p",output()])
    copy_cases(cases())
    references(cases())
