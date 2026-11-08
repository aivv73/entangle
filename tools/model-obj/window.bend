import Base
import bend-ui-test@0.1.0.2/uitest.bend as UI
import bend-window-capture@0.1.0.2/capture.bend as Capture
import ../window-verification/bridge.bend as Host
import ../window-verification/pixels.bend as Pixels
import ../window-verification/existing.bend as Existing
import ../window-verification/check.bend as Check
import ../verify-creation-window.bend as Colors

def matches(+frame:Pixels.Frame,+mode:String) -> Bool:
  Pixels.Frame{_,_,+pixels} = frame
  +white = Colors.colors(pixels,16777215)
  +red = Colors.colors(pixels,16711680)
  +green = Colors.colors(pixels,65280)
  Pixels.extent(frame,640,480) && Bool.pick(Bool,String.eq(mode,"reversed"),U32.is_zero(white) && U32.is_zero(red) && U32.is_zero(green) && U32.is_gt(Colors.colors(pixels,922399),300000),
    Bool.pick(Bool,String.eq(mode,"wedge"),U32.is_gt(white,100),U32.is_gt(white,100) && U32.is_gt(red,100) && U32.is_gt(green,100)))

def candidate(+frame:Pixels.Frame,mode:String) -> Maybe<Pixels.Frame>:
  Bool.pick(Maybe<Pixels.Frame>,matches(frame,mode),Some{frame},None{})

def captured(result:Result<&1,&1,U32 & String,Capture.Capture>,+mode:String) -> Maybe<Pixels.Frame>:
  match result:
    case Fail{_}:None{}
    case Done{capture}:candidate(Existing.capture_frame(capture),mode)

def wait(fuel:Nat,+pid:U32,+id:U32,+mode:String,current:Maybe<Pixels.Frame>) -> IO(Pixels.Frame):
  match fuel current:
    case _,Some{frame}:IO.pure(Pixels.Frame,frame)
    case 0n,None{}:IO.die(Pixels.Frame,1,"Imported window pixels did not satisfy " ++ mode)
    case 1n+rest,None{}:
      do IO<Pixels.Frame>:
        Existing.alive(pid)
        IO.sleep(50)
        capture:Result<&1,&1,U32 & String,Capture.Capture> <- Host.capture(id)
        wait(rest,pid,id,mode,captured(capture,mode))

def run(+mode:String) -> IO(Unit):
  do IO<Unit>:
    +display:String <- IO.try(String,IO.get_env("DISPLAY"))
    layers:String <- IO.try(String,IO.get_env("VK_INSTANCE_LAYERS"))
    sync:String <- IO.try(String,IO.get_env("VK_LAYER_VALIDATE_SYNC"))
    Check.assert(String.contains(layers,"VK_LAYER_KHRONOS_validation") && String.eq(sync,"1"),"Imported X11 gate requires validation")
    +pid:U32 <- IO.try(U32,Host.start("build/model-window.log",False{}))
    +id:U32 <- Existing.wait_window(300n,pid)
    IO.try(Unit,Host.control(id,2,0,0))
    +frame:Pixels.Frame <- wait(300n,pid,id,mode,None{})
    Existing.save("build/model-window.ppm",frame)
    IO.print("Imported X11 " ++ mode ++ " expected material regions or reversed-face culling observed.")
    IO.try(Unit,UI.send_to(display,id,[Close{}]))
    Existing.wait_exit(300n,pid)
    +log:String <- Check.read("build/model-window.log")
    Check.assert(String.contains(log,"Imported model window closed; live Vulkan objects: 0") && Check.clean_diagnostics(log),"Imported X11 cleanup or validation failed")
    IO.print("Imported X11 " ++ mode ++ " passed; actual Close; zero live Vulkan objects; no validation diagnostics.")

def args(values:List<String>) -> IO(Unit):
  match values:
    case _ <> mode <> _:run(mode)
    case _:run("sign")

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<String> <- IO.args()
    args(values)
