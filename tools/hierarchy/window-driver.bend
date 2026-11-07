import Base
import ../../deps/bend-vulkan/tools/window_verification/input/uitest.bend as UI
import ../../deps/bend-vulkan/tools/window_verification/bridge.bend as Host
import ../../deps/bend-vulkan/tools/window_verification/pixels.bend as Pixels
import ../../deps/bend-vulkan/examples/verify_window.bend as Existing
import ../../deps/bend-vulkan/tools/verification.bend as Check
import ../verify-window.bend as Window
import ../verify-textured-window.bend as Texture

def acknowledged(fuel:Nat,+needle:String) -> IO(Unit):
  match fuel:
    case 0n:IO.die(Unit,1,"Hierarchy input was not acknowledged")
    case 1n+n:
      do IO<Unit>:
        log:String <- Check.read("build/window-evidence/native.log")
        IO.sleep(50)
        Bool.pick(IO(Unit),String.contains(log,needle),IO.pure(Unit,Unit{}),acknowledged(n,needle))

def invalid(keys:List<&2,U32>,+display:String,+pid:U32,+id:U32,+first:Pixels.Frame) -> IO(Unit):
  match keys:
    case []:IO.pure(Unit,Unit{})
    case +key <> rest:
      do IO<Unit>:
        Window.key(display,id,key)
        acknowledged(100n,"hierarchy-step=" ++ U32.show(U32.sub(key,48)) ++ " state=")
        frame:Pixels.Frame <- Window.wait(pid,id,Window.Exact{first})
        Window.save("rejected-" ++ U32.show(key),frame)
        invalid(rest,display,pid,id,first)

def resize(sizes:List<(U32 & U32)>,+display:String,+pid:U32,+id:U32,+seen:List<&2,Pixels.Frame>) -> IO(Unit):
  match sizes:
    case []:IO.pure(Unit,Unit{})
    case (+w,+h) <> rest:
      do IO<Unit>:
        IO.try(Unit,Host.control(id,0,w,h))
        +first:Pixels.Frame <- Window.wait(pid,id,Window.Populated{w,h})
        Window.key(display,id,49)
        +moved:Pixels.Frame <- Window.wait(pid,id,Window.Moved{first})
        Window.key(display,id,114)
        +reset:Pixels.Frame <- Window.wait(pid,id,Window.Moved{moved})
        Check.assert(Window.same_extent_replay(seen,reset),"Hierarchy revisited extent changed pixels")
        Window.save("resize-" ++ U32.show(w) ++ "x" ++ U32.show(h),reset)
        resize(rest,display,pid,id,reset <> seen)

def main() -> IO(Unit):
  do IO<Unit>:
    +display:String <- IO.try(String,IO.get_env("DISPLAY"))
    layers:String <- IO.try(String,IO.get_env("VK_INSTANCE_LAYERS"))
    sync:String <- IO.try(String,IO.get_env("VK_LAYER_VALIDATE_SYNC"))
    Check.assert(String.contains(layers,"VK_LAYER_KHRONOS_validation") && String.eq(sync,"1"),"Hierarchy window requires validation")
    +pid:U32 <- IO.try(U32,Host.start("build/window-evidence/native.log",False{}))
    +id:U32 <- Existing.wait_window(300n,pid)
    IO.try(Unit,Host.control(id,2,0,0))
    +first:Pixels.Frame <- Window.wait(pid,id,Window.Populated{640,480})
    Window.save("initial",first)
    Texture.populated(first)
    Window.controls([49,50,51,52,53],display,pid,id,first)
    invalid([54,55,56,57],display,pid,id,first)
    resize([(800,600),(480,640),(640,480)],display,pid,id,[first])
    IO.try(Unit,Host.control(id,1,0,0))
    IO.sleep(200)
    IO.try(Unit,Host.control(id,2,0,0))
    Window.key(display,id,49)
    _:Pixels.Frame <- Window.wait(pid,id,Window.Moved{first})
    Window.key(display,id,114)
    reset:Pixels.Frame <- Window.wait(pid,id,Window.Exact{first})
    Window.save("reset",reset)
    IO.try(Unit,UI.send_to(display,id,[Close{}]))
    Existing.wait_exit(300n,pid)
    +log:String <- Check.read("build/window-evidence/native.log")
    Check.assert(String.contains(log,"Hierarchy window closed; live Vulkan objects: 0") && Check.clean_diagnostics(log),"Hierarchy window validation or cleanup failed")
    IO.print("Hierarchy X11 parent translation/rotation/scale, reparent/detach, invalid edits, exact reset, resize, restore and Close passed")
