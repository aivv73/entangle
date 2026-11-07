import bend-window-capture@0.1.0.2/capture.bend as Capture
import Base
import ../deps/bend-vulkan/tools/window_verification/input/uitest.bend as UI
import ../deps/bend-vulkan/tools/window_verification/bridge.bend as Host
import ../deps/bend-vulkan/tools/window_verification/pixels.bend as Pixels
import ../deps/bend-vulkan/examples/verify_window.bend as Existing
import ../deps/bend-vulkan/tools/verification.bend as Check
import ./verify-window.bend as WindowCheck
import ./mesh-x11-focus.bend as Focus

def save(name:String,frame:Pixels.Frame) -> IO(Unit):
  Existing.save("docs/verification/2026-11-03-mesh-playground/" ++ name ++ ".ppm",frame)

def key(+port:U32,+id:U32,code:U32,down:Bool) -> IO(Unit):
  Focus.key(port,id,code,down)

def convert(result:Result<&1,&1,U32 & String,Capture.Capture>) -> Result<&1,&1,U32 & String,Pixels.Frame>:
  match result:
    case Done{value}:Done{Existing.capture_frame(value)}
    case Fail{error}:Fail{error}

def capture_result(id:U32) -> IO(Result<&1,&1,U32 & String,Pixels.Frame>):
  do IO<Result<&1,&1,U32 & String,Pixels.Frame>>:
    result:Result<&1,&1,U32 & String,Capture.Capture> <- Host.capture(id)
    return convert(result)

def capture(id:U32) -> IO(Pixels.Frame):
  do IO<Pixels.Frame>:
    IO.sleep(120)
    result:Result<&1,&1,U32 & String,Pixels.Frame> <- capture_result(id)
    IO.pass(Pixels.Frame,result)

def stable(id:U32,+baseline:Pixels.Frame) -> IO(Unit):
  do IO<Unit>:
    later:Pixels.Frame <- capture(id)
    Check.assert(Pixels.equal(baseline,later),"Held cancellation, release or inactive clearing did not stop native motion")

def clean(+name:String) -> IO(Unit):
  do IO<Unit>:
    +log:String <- Check.read("docs/verification/2026-11-03-mesh-playground/" ++ name ++ ".log")
    Check.assert(String.contains(log,"Mesh playground closed; live Vulkan objects: 0") && Check.clean_diagnostics(log),"Mesh native cleanup or Vulkan validation failed")

def burst_state(next:String -> Maybe<&2,String> -> IO(Unit),+previous:String,expected:Maybe<&2,String>,+actual:String,is_state:Bool) -> IO(Unit):
  match expected is_state:
    case expected False{}:next(previous,expected)
    case None{} True{}:next(actual,None{})
    case Some{+expected} True{}:
      do IO<Unit>:
        Check.assert(String.eq(expected,"") || String.eq(expected,actual),"Queued focus loss changed authoritative ECS state")
        next(actual,None{})

def burst_ended(expected:Maybe<&2,String>) -> IO(Unit):
  match expected:
    case None{}:IO.pure(Unit,Unit{})
    case Some{_}:IO.die(Unit,1,"Native trace ended before focused-loss state observation")

def burst_states(lines:List<&2,String>,+previous:String,expected:Maybe<&2,String>) -> IO(Unit):
  match lines:
    case []:burst_ended(expected)
    case +head <> rest:
      match head:
        case "mesh-focus-burst-cleared":burst_states(rest,previous,Some{previous})
        case _:burst_state(value => pending => burst_states(rest,value,pending),previous,expected,String.drop(head,11n),String.starts_with(head,"mesh-state "))

def validate_bursts(+log:String) -> IO(Unit):
  +marker:String = "mesh-focus-burst-cleared\n"
  zero:String = marker ++ "mesh-key 119 0\nmesh-key 115 0\nmesh-key 97 0\nmesh-key 100 0\nmesh-key 113 0\nmesh-key 101 0\nmesh-active 0\nmesh-step 0\nmesh-state "
  do IO<Unit>:
    Check.assert(U32.is_gt(WindowCheck.occurrences(log,marker),0) && U32.is_eq(WindowCheck.occurrences(log,marker),WindowCheck.occurrences(log,zero)),"Queued focus loss must announce zero simulation steps with final focus restored")
    burst_states(String.lines(log),"",None{})

def marker_required(+log:String,value:Result<&1,&1,U32 & String,String>) -> IO(Unit):
  match value:
    case Done{"1"}:
      do IO<Unit>:
        Check.assert(String.contains(log,"mesh-step 4\nmesh-tick\n"),"Native pause did not exercise four-step bounded catch-up")
        validate_bursts(log)
        IO.print("Traced queued focus-loss batches executed zero steps and preserved authoritative ECS state.")
    case _:IO.pure(Unit,Unit{})

def focus_and_unmap(+display:String,+pid:U32,+id:U32,+baseline:Pixels.Frame,+port:U32) -> IO(Unit):
  do IO<Unit>:
    key(port,id,106,True{})
    moved:Pixels.Frame <- WindowCheck.wait(pid,id,WindowCheck.Moved{baseline})
    Focus.set(port,0)
    +inactive:Pixels.Frame <- capture(id)
    stable(id,inactive)
    Focus.set(port,id)
    stable(id,inactive)
    save("focus-restored",inactive)
    key(port,id,106,False{})
    key(port,id,106,True{})
    burst_before:Pixels.Frame <- WindowCheck.wait(pid,id,WindowCheck.Moved{inactive})
    Check.command("kill",["-STOP",U32.show(pid)])
    +frozen:Pixels.Frame <- capture(id)
    Focus.burst(port,id)
    IO.sleep(100)
    Check.command("kill",["-CONT",U32.show(pid)])
    +burst_after:Pixels.Frame <- capture(id)
    save("focus-paused",frozen)
    stable(id,burst_after)
    save("focus-burst",burst_after)
    IO.print("Queued FocusOut/FocusIn stopped held movement; post-resume pixels stayed stable.")
    key(port,id,106,False{})
    key(port,id,108,True{})
    moved:Pixels.Frame <- WindowCheck.wait(pid,id,WindowCheck.Moved{burst_after})
    IO.try(Unit,Host.control(id,1,0,0))
    IO.sleep(150)
    IO.try(Unit,Host.control(id,2,0,0))
    Focus.set(port,id)
    +restored:Pixels.Frame <- capture(id)
    stable(id,restored)
    save("unmap-restored",restored)
    key(port,id,108,False{})
    WindowCheck.key(display,id,32)
    +reset:Pixels.Frame <- WindowCheck.wait(pid,id,WindowCheck.Exact{baseline})
    WindowCheck.resize([(800,600),(480,640),(640,480),(800,600),(640,480)],display,pid,id,[reset])
    Focus.set(port,0)
    WindowCheck.key(display,id,27)
    Existing.wait_exit(300n,pid)
    clean("native-live")
    log:String <- Check.read("docs/verification/2026-11-03-mesh-playground/native-live.log")
    env:Result<&1,&1,U32 & String,String> <- IO.get_env("ENTANGLE_MESH_EVIDENCE")
    marker_required(log,env)

def released(+display:String,+pid:U32,+id:U32,+baseline:Pixels.Frame,+port:U32) -> IO(Unit):
  do IO<Unit>:
    key(port,id,106,False{})
    +right:Pixels.Frame <- WindowCheck.wait(pid,id,WindowCheck.Moved{baseline})
    key(port,id,108,False{})
    +stopped:Pixels.Frame <- capture(id)
    stable(id,stopped)
    save("released",stopped)
    WindowCheck.key(display,id,32)
    +reset:Pixels.Frame <- WindowCheck.wait(pid,id,WindowCheck.Exact{baseline})
    stable(id,reset)
    save("reset",reset)
    WindowCheck.controls([97,100,119,115,113,101],display,pid,id,reset)
    focus_and_unmap(display,pid,id,reset,port)

def held(+display:String,+pid:U32,+id:U32,+baseline:Pixels.Frame,+port:U32) -> IO(Unit):
  do IO<Unit>:
    key(port,id,106,True{})
    +first:Pixels.Frame <- WindowCheck.wait(pid,id,WindowCheck.Moved{baseline})
    Check.command("kill",["-STOP",U32.show(pid)])
    IO.sleep(120)
    Check.command("kill",["-CONT",U32.show(pid)])
    +second:Pixels.Frame <- WindowCheck.wait(pid,id,WindowCheck.Moved{first})
    save("held",second)
    key(port,id,106,True{})
    +repeated:Pixels.Frame <- WindowCheck.wait(pid,id,WindowCheck.Moved{second})
    key(port,id,108,True{})
    +opposite:Pixels.Frame <- capture(id)
    stable(id,opposite)
    save("opposite",opposite)
    released(display,pid,id,baseline,port)

def axes(codes:List<&2,U32>,+display:String,+pid:U32,+id:U32,+baseline:Pixels.Frame,+port:U32) -> IO(Unit):
  match codes:
    case []:IO.pure(Unit,Unit{})
    case +code <> rest:
      do IO<Unit>:
        key(port,id,code,True{})
        moved:Pixels.Frame <- WindowCheck.wait(pid,id,WindowCheck.Moved{baseline})
        key(port,id,code,False{})
        +released:Pixels.Frame <- capture(id)
        stable(id,released)
        WindowCheck.key(display,id,32)
        reset:Pixels.Frame <- WindowCheck.wait(pid,id,WindowCheck.Exact{baseline})
        IO.print("player-axis=" ++ U32.show(code) ++ " held=moved release=stable Space=exact")
        axes(rest,display,pid,id,baseline,port)

def color_count(pixels:List<&2,U32>,+color:U32) -> U32:
  match pixels:
    case []:0
    case x <> rest:U32.add(Bool.to_u32(U32.is_eq(U32.and(x,16777215),color)),color_count(rest,color))

def colors(frame:Pixels.Frame) -> IO(Unit):
  Pixels.Frame{_,_,+pixels} = frame
  Check.assert(U32.is_gt(color_count(pixels,16741133),100) && U32.is_gt(color_count(pixels,55781),100) && U32.is_gt(color_count(pixels,15017650),100) && U32.is_gt(color_count(pixels,7568007),100),"Native capture must contain all four mesh materials")

def live(+display:String,+port:U32) -> IO(Unit):
  do IO<Unit>:
    +pid:U32 <- IO.try(U32,Host.start("docs/verification/2026-11-03-mesh-playground/native-live.log",False{}))
    +id:U32 <- Existing.wait_window(300n,pid)
    IO.try(Unit,Host.control(id,2,0,0))
    Focus.set(port,id)
    +baseline:Pixels.Frame <- WindowCheck.wait(pid,id,WindowCheck.Populated{640,480})
    colors(baseline)
    save("initial",baseline)
    axes([105,107,106,108,117,111],display,pid,id,baseline,port)
    held(display,pid,id,baseline,port)
    IO.print("Native held/repeat/opposite/release/reset, six camera controls, real focus loss, unmap/restore, repeated resize and unfocused Escape passed.")

def recorded_batches(lines:List<&2,String>) -> U32:
  match lines:
    case []:0
    case line <> rest:U32.add(Bool.to_u32(String.starts_with(line,"mesh-state ")),recorded_batches(rest))

def wait_close_batches(fuel:Nat) -> IO(Unit):
  match fuel:
    case 0n:IO.die(Unit,1,"Hidden Close did not record enough completed batches for replay")
    case 1n+n:
      do IO<Unit>:
        log:String <- Check.read("docs/verification/2026-11-03-mesh-playground/native-close.log")
        IO.sleep(50)
        Bool.pick(IO(Unit),U32.is_gt(recorded_batches(String.lines(log)),10),IO.pure(Unit,Unit{}),wait_close_batches(n))

def hidden_close(+display:String,+port:U32) -> IO(Unit):
  do IO<Unit>:
    +pid:U32 <- IO.try(U32,Host.start("docs/verification/2026-11-03-mesh-playground/native-close.log",False{}))
    +id:U32 <- Existing.wait_window(300n,pid)
    Focus.set(port,id)
    frame:Pixels.Frame <- WindowCheck.wait(pid,id,WindowCheck.Populated{640,480})
    IO.try(Unit,Host.control(id,1,0,0))
    wait_close_batches(100n)
    IO.try(Unit,UI.send_to(display,id,[Close{}]))
    Existing.wait_exit(300n,pid)
    clean("native-close")
    IO.print("Hidden native Close passed; both exits have clean validation and zero live Vulkan objects.")

def parsed_port(value:Maybe<&2,U32>) -> IO(U32):
  match value:
    case Some{port}:IO.pure(U32,port)
    case _:IO.die(U32,1,"ENTANGLE_X11_PORT must name the owned Xwayland TCP port")

def native() -> IO(Unit):
  do IO<Unit>:
    +layers:String <- IO.try(String,IO.get_env("VK_INSTANCE_LAYERS"))
    sync:String <- IO.try(String,IO.get_env("VK_LAYER_VALIDATE_SYNC"))
    Check.assert(String.contains(layers,"VK_LAYER_KHRONOS_validation") && String.eq(sync,"1"),"Native mesh gate requires Khronos and synchronization validation")
    +display:String <- IO.try(String,IO.get_env("DISPLAY"))
    text:String <- IO.try(String,IO.get_env("ENTANGLE_X11_PORT"))
    +port:U32 <- parsed_port(U32.read(text))
    live(display,port)
    hidden_close(display,port)

def main_args(args:List<String>) -> IO(Unit):
  match args:
    case [_,"focus-log",path]:
      do IO<Unit>:
        log:String <- Check.read(path)
        validate_bursts(log)
        IO.print("Recorded focused-loss batches have zero steps and unchanged authoritative ECS state.")
    case _:native()

def main() -> IO(Unit):
  do IO<Unit>:
    args:List<String> <- IO.args()
    main_args(args)
