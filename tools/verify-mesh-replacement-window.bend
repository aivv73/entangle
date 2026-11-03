import Base
import bend-window-capture@0.1.0.2/capture.bend as Capture
import bend-ui-test@0.1.0.1/uitest.bend as UI
import ../deps/bend-vulkan/tools/window_verification/bridge.bend as Host
import ../deps/bend-vulkan/tools/window_verification/pixels.bend as Pixels
import ../deps/bend-vulkan/examples/verify_window.bend as Existing
import ../deps/bend-vulkan/tools/verification.bend as Check
import ./verify-window.bend as WindowCheck
import ./verify-creation-window.bend as Creation

type Expect is Data:
  Color{color:U32}
  Empty{}
  Exact{frame:Pixels.Frame}

def matches(+frame:Pixels.Frame,expect:Expect) -> Bool:
  Pixels.Frame{w,h,+pixels} = frame
  match expect:
    case Color{color}:U32.is_gt(Creation.colors(pixels,color),10000)
    case Empty{}:U32.is_zero(Creation.colors(pixels,16711680)) && U32.is_zero(Creation.colors(pixels,65280))
    case Exact{previous}:Pixels.equal(frame,previous)

def candidate(result:Result<&1,&1,U32 & String,Capture.Capture>,expect:Expect) -> Maybe<Pixels.Frame>:
  match result:
    case Fail{_}:None{}
    case Done{capture}:
      +frame = Existing.capture_frame(capture)
      Bool.pick(Maybe<Pixels.Frame>,matches(frame,expect) && Pixels.extent(frame,640,480),Some{frame},None{})

def poll(fuel:Nat,+pid:U32,+id:U32,+expect:Expect,current:Maybe<Pixels.Frame>) -> IO(Pixels.Frame):
  match fuel current:
    case _ Some{frame}:IO.pure(Pixels.Frame,frame)
    case 0n None{}:IO.die(Pixels.Frame,1,"Replacement X11 pixels did not reach expected state")
    case 1n+rest None{}:
      do IO<Pixels.Frame>:
        Existing.alive(pid)
        IO.sleep(50)
        result:Result<&1,&1,U32 & String,Capture.Capture> <- Host.capture(id)
        poll(rest,pid,id,expect,candidate(result,expect))

def wait(pid:U32,id:U32,expect:Expect) -> IO(Pixels.Frame):poll(300n,pid,id,expect,None{})

def seen(next:IO(Unit),ok:Bool) -> IO(Unit):
  match ok:
    case True{}:IO.pure(Unit,Unit{})
    case False{}:
      do IO<Unit>:
        IO.sleep(50)
        next

def event_seen(fuel:Nat,+pid:U32,+code:U32,+count:U32) -> IO(Unit):
  match fuel:
    case 0n:IO.die(Unit,1,"Replacement window did not acknowledge key")
    case 1n+rest:
      do IO<Unit>:
        Existing.alive(pid)
        log:String <- Check.read("build/replacement-window.log")
        seen(event_seen(rest,pid,code,count),U32.is_ge(WindowCheck.occurrences(log,"mesh-event=" ++ U32.show(code)),count))

def key(+display:String,+pid:U32,+id:U32,+code:U32,count:U32,expect:Expect,+name:String) -> IO(Pixels.Frame):
  do IO<Pixels.Frame>:
    WindowCheck.key(display,id,code)
    event_seen(300n,pid,code,count)
    +frame:Pixels.Frame <- wait(pid,id,expect)
    Existing.save("build/window-evidence/" ++ name ++ ".ppm",frame)
    IO.print("replacement-action=" ++ U32.show(code) ++ " capture=" ++ name)
    return frame

def run(+display:String,+pid:U32,+id:U32) -> IO(Unit):
  do IO<Unit>:
    IO.try(Unit,Host.control(id,2,0,0))
    +first:Pixels.Frame <- wait(pid,id,Color{16711680})
    Existing.save("build/window-evidence/red.ppm",first)
    invalid:Pixels.Frame <- key(display,pid,id,105,1,Exact{first},"invalid-preserved")
    rejected:Pixels.Frame <- key(display,pid,id,98,1,Exact{first},"recording-rejected-preserved")
    green:Pixels.Frame <- key(display,pid,id,103,1,Color{65280},"green")
    empty:Pixels.Frame <- key(display,pid,id,101,1,Empty{},"empty")
    red:Pixels.Frame <- key(display,pid,id,114,1,Exact{first},"red-restored")
    green:Pixels.Frame <- key(display,pid,id,103,2,Color{65280},"green-repeat")
    empty:Pixels.Frame <- key(display,pid,id,101,2,Empty{},"empty-repeat")
    red:Pixels.Frame <- key(display,pid,id,114,2,Exact{first},"red-repeat")
    IO.try(Unit,Host.control(id,1,0,0))
    IO.sleep(100)
    IO.try(Unit,Host.control(id,2,0,0))
    restored:Pixels.Frame <- wait(pid,id,Exact{first})
    IO.try(Unit,UI.send_to(display,id,[Close{}]))
    Existing.wait_exit(300n,pid)
    +log:String <- Check.read("build/replacement-window.log")
    Check.assert(Check.clean_diagnostics(log) && String.contains(log,"Mesh replacement window closed; live Vulkan objects: 0") && String.contains(log,"Hidden and empty lifecycle collection and measured successful writes verified."),"Replacement window validation, collection, writes or cleanup failed")
    IO.print("X11 replacement visuals, invalid preservation, recording rejection, repeated empty transitions, hide/restore and zero live resources passed with validation.")

def main() -> IO(Unit):
  do IO<Unit>:
    +display:String <- IO.try(String,IO.get_env("DISPLAY"))
    layers:String <- IO.try(String,IO.get_env("VK_INSTANCE_LAYERS"))
    sync:String <- IO.try(String,IO.get_env("VK_LAYER_VALIDATE_SYNC"))
    Check.assert(String.contains(layers,"VK_LAYER_KHRONOS_validation") && String.eq(sync,"1"),"Replacement gate requires Khronos and synchronization validation")
    +pid:U32 <- IO.try(U32,Host.start("build/replacement-window.log",False{}))
    +id:U32 <- Existing.wait_window(300n,pid)
    run(display,pid,id)
