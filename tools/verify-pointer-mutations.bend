import Base
import ./upload-boundary/scan.bend as S
import ./verify-upload-mutations.bend as Files
import ./verify-native-failures.bend as Replace

def recorded(+dest:String,+label:String,result:U32 & (String & String),negative:Bool) -> IO(Unit):
  (+status,(out,err)) = result
  do IO<Unit>:
    Files.save(dest ++ "/" ++ label ++ ".log",out ++ err)
    Files.save(dest ++ "/" ++ label ++ ".status",U32.show(status) ++ "\n")
    S.require(U32.is_eq(status,Bool.pick(U32,negative,1,0)),"Pointer qualification unexpected exit: " ++ label)

def command(+dest:String,label:String,args:List<String>,negative:Bool) -> IO(Unit):
  do IO<Unit>:
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("env","-C" <> dest <> args,"",16777216,120000))
    recorded(dest,label,result,negative)

def gate(+dest:String,+label:String,+negative:Bool) -> IO(Unit):
  do IO<Unit>:
    command(dest,label ++ "-build",["bend","tools/pointer-window-app.bend","-o","build/indexed-window"],False{})
    command(dest,label,["./build/verify-pointer-window","+RTS","--threads","1","--gpu","off"],negative)
    +log:String <- S.read(dest ++ "/build/pointer-window.log")
    Files.save(dest ++ "/" ++ label ++ "-native.log",log)
    S.require(Bool.pick(Bool,negative,String.contains(log,"Pointer Press ABI mismatch"),String.contains(log,"Pointer window closed; live Vulkan objects: 0")),"Pointer qualification did not observe its named property: " ++ label)

def main() -> IO(Unit):
  do IO<Unit>:
    _:String <- S.run("mkdir",["-p","build/verification"])
    directory:String <- S.run("mktemp",["-d","build/verification/pointer-controls-XXXXXXXX"])
    +dest:String = String.trim(directory)
    IO.print("Pointer ABI evidence: " ++ dest)
    _:String <- S.run("cp",["-R","--reflink=auto","--","tools","deps",dest])
    _:String <- S.run("mkdir",["-p",dest ++ "/build"])
    Files.save(dest ++ "/run.status","1\n")
    command(dest,"driver-build",["bend","tools/verify-pointer-window.bend","-o","build/verify-pointer-window"],False{})
    gate(dest,"baseline",False{})
    +path:String = dest ++ "/deps/bend-vulkan/src/x11.c"
    +original:String <- S.read(path)
    +changed:String <- Replace.replaced(Replace.replace(String.split(original,'\n'),
      "          value=bv_mouse_event(e,CID(Press),event.xbutton.x,event.xbutton.y,event.xbutton.time,button==Button1 ? 0 : button==Button2 ? 1 : 2,event.type==ButtonPress);",
      "          value=bv_mouse_event(e,CID(Press),event.xbutton.x,event.xbutton.y,event.xbutton.time,button==Button1 ? 0 : button==Button3 ? 1 : 2,event.type==ButtonPress);"))
    Files.save(path,changed)
    Files.save(dest ++ "/mutated-x11.c",changed)
    command(dest,"mutation-bundle",["python3","deps/bend-vulkan/tools/generate.py"],False{})
    gate(dest,"wrong-button",True{})
    Files.save(path,original)
    command(dest,"restored-bundle",["python3","deps/bend-vulkan/tools/generate.py"],False{})
    gate(dest,"restored",False{})
    Files.save(dest ++ "/run.status","0\n")
    IO.print("Native pointer ABI baseline, named W3C button regression rejection, and restored baseline passed.")
