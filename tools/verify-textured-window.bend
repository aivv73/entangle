import Base
import bend-ui-test@0.1.0.2/uitest.bend as UI
import ./window-verification/bridge.bend as Host
import ./window-verification/pixels.bend as Pixels
import ./window-verification/existing.bend as Existing
import ./window-verification/check.bend as Check
import ./verify-window.bend as Window

def colors(pixels:List<&2,U32>,+channel:U32) -> U32:
  match pixels:
    case []:0
    case +p <> rest:
      +r = U32.and((p >> 16n : U32),255)
      +g = U32.and((p >> 8n : U32),255)
      +b = U32.and(p,255)
      +bright = Bool.pick(U32,U32.is_zero(channel),r,Bool.pick(U32,U32.is_eq(channel,1),g,b))
      +others = Bool.pick(U32,U32.is_zero(channel),U32.max(g,b),Bool.pick(U32,U32.is_eq(channel,1),U32.max(r,b),U32.max(r,g)))
      U32.add(Bool.to_u32(U32.is_gt(bright,40) && U32.is_lt(others,8)),colors(rest,channel))

def populated(frame:Pixels.Frame) -> IO(Unit):
  Pixels.Frame{_,_,+pixels} = frame
  Check.assert(U32.is_gt(colors(pixels,0),200) && U32.is_gt(colors(pixels,1),200) && U32.is_gt(colors(pixels,2),200),"Textured window lacks sampled red, green or blue regions")

def main() -> IO(Unit):
  do IO<Unit>:
    +display:String <- IO.try(String,IO.get_env("DISPLAY"))
    layers:String <- IO.try(String,IO.get_env("VK_INSTANCE_LAYERS"))
    sync:String <- IO.try(String,IO.get_env("VK_LAYER_VALIDATE_SYNC"))
    Check.assert(String.contains(layers,"VK_LAYER_KHRONOS_validation") && String.eq(sync,"1"),"Textured window requires validation")
    +pid:U32 <- IO.try(U32,Host.start("build/window-evidence/native.log",False{}))
    +id:U32 <- Existing.wait_window(300n,pid)
    IO.try(Unit,Host.control(id,2,0,0))
    +first:Pixels.Frame <- Window.wait(pid,id,Window.Populated{640,480})
    populated(first)
    Window.save("initial",first)
    Window.controls([97,100,119,115,113,101],display,pid,id,first)
    +reset:Pixels.Frame <- Window.wait(pid,id,Window.Exact{first})
    Window.save("reset",reset)
    Window.resize([(800,600),(480,640),(640,480),(480,640),(640,480)],display,pid,id,[first])
    IO.try(Unit,Host.control(id,1,0,0))
    IO.sleep(200)
    IO.try(Unit,Host.control(id,2,0,0))
    Window.key(display,id,100)
    _:Pixels.Frame <- Window.wait(pid,id,Window.Moved{first})
    Window.key(display,id,114)
    _:Pixels.Frame <- Window.wait(pid,id,Window.Exact{first})
    IO.try(Unit,UI.send_to(display,id,[Close{}]))
    Existing.wait_exit(300n,pid)
    +log:String <- Check.read("build/window-evidence/native.log")
    Check.assert(String.contains(log,"Textured window closed; live Vulkan objects: 0") && Check.clean_diagnostics(log),"Textured window validation or cleanup failed")
    IO.print("Textured X11 sampling, six camera controls, exact reset, repeated resize, restore and Close passed; live Vulkan objects=0.")
