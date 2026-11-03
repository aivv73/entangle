import Base
import bend-ui-test@0.1.0.1/uitest.bend as UI
import ../deps/bend-vulkan/tools/window_verification/bridge.bend as Host
import ../deps/bend-vulkan/tools/window_verification/pixels.bend as Pixels
import ../deps/bend-vulkan/examples/verify_window.bend as Existing
import ../deps/bend-vulkan/tools/verification.bend as Check
import ./verify-window.bend as WindowCheck

def colors(pixels:List<&2,U32>,+color:U32) -> U32:
  match pixels:
    case []:0
    case p <> rest:U32.add(Bool.to_u32(U32.is_eq(U32.and(p,16777215),color)),colors(rest,color))

def validate(frame:Pixels.Frame) -> IO(Unit):
  Pixels.Frame{_,_,+pixels} = frame
  do IO<Unit>:
    Check.assert(U32.is_gt(colors(pixels,16711680),100) && U32.is_gt(colors(pixels,65280),100) && U32.is_gt(colors(pixels,16777215),200),"Public window missing red, green or white range geometry")
    IO.print("Actual X11 capture contains red, green and white geometry from ranges 3,3,6.")

def main() -> IO(Unit):
  do IO<Unit>:
    +display:String <- IO.try(String,IO.get_env("DISPLAY"))
    +pid:U32 <- IO.try(U32,Host.start("build/public-creation-window.log",True{}))
    +id:U32 <- Existing.wait_window(300n,pid)
    IO.try(Unit,Host.control(id,2,0,0))
    +frame:Pixels.Frame <- WindowCheck.wait(pid,id,WindowCheck.Populated{640,480})
    validate(frame)
    Existing.save("docs/verification/2026-11-03-public-creation/materials.ppm",frame)
    IO.try(Unit,UI.send_to(display,id,[Close{}]))
    Existing.wait_exit(300n,pid)
    +log:String <- Check.read("build/public-creation-window.log")
    Check.assert(String.contains(log,"Public creation window closed; live Vulkan objects: 0") && Check.clean_diagnostics(log),"Public X11 cleanup or validation failed")
    IO.print("Public creation X11 gate passed with validation and zero live Vulkan objects.")
