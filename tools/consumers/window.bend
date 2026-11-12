import Base
import bend-ui-test@0.1.0.2/uitest.bend as UI
import bend-window-capture@0.1.0.2/capture.bend as Capture
import ../window-verification/bridge.bend as Host
import ../window-verification/pixels.bend as Pixels
import ../window-verification/existing.bend as Existing
import ../window-verification/check.bend as Check

def regions(values:List<&2,U32>,+warm:Bool) -> U32:
  match values:
    case []:0
    case +p <> rest:(Bool.to_u32(Bool.pick(Bool,warm,Pixels.warm_rgb(Pixels.rgb(p)),Pixels.cool_rgb(Pixels.rgb(p)))) + regions(rest,warm) : U32)

def populated(+frame:Pixels.Frame,+game:Bool) -> Bool:
  Pixels.Frame{_,_,+pixels} = frame
  Pixels.extent(frame,640,480) && U32.is_gt(regions(pixels,False{}),100) && Bool.pick(Bool,game,U32.is_gt(regions(pixels,True{}),100),True{})

def candidate(+game:Bool,result:Result<&1,&1,U32 & String,Capture.Capture>) -> Maybe<Pixels.Frame>:
  match result:
    case Fail{_}:None{}
    case Done{capture}:
      +frame:Pixels.Frame = Existing.capture_frame(capture)
      Bool.pick(Maybe<Pixels.Frame>,populated(frame,game),Some{frame},None{})

def wait(fuel:Nat,+pid:U32,+id:U32,+game:Bool,value:Maybe<Pixels.Frame>) -> IO(Pixels.Frame):
  match fuel value:
    case _ Some{frame}:IO.pure(Pixels.Frame,frame)
    case 0n _:IO.die(Pixels.Frame,1,"Consumer window lacks expected model material regions")
    case 1n+rest _:
      do IO<Pixels.Frame>:
        Existing.alive(pid)
        IO.sleep(50)
        capture:Result<&1,&1,U32 & String,Capture.Capture> <- Host.capture(id)
        wait(rest,pid,id,game,candidate(game,capture))

def frame(pid:U32,id:U32,game:Bool) -> IO(Pixels.Frame):wait(300n,pid,id,game,None{})

def tap(+display:String,+id:U32,code:U32) -> IO(Unit):
  +code:U32 = code
  do IO<Unit>:
    IO.try(Unit,UI.send_to(display,id,[Key{code,True{}},Key{code,False{}}]))
    IO.sleep(100)

def keys(+display:String,+id:U32,codes:List<&2,U32>) -> IO(Unit):
  match codes:
    case []:IO.pure(Unit,Unit{})
    case code <> rest:
      do IO<Unit>:
        tap(display,id,code)
        keys(display,id,rest)

def exercise(+display:String,+pid:U32,+id:U32,+game:Bool,+initial:Pixels.Frame) -> IO(Unit):
  do IO<Unit>:
    keys(display,id,Bool.pick(List<&2,U32>,game,[106,106,32],[100,119,113]))
    +changed:Pixels.Frame <- frame(pid,id,game)
    Check.assert(Bool.not(Pixels.equal(initial,changed)),"Actual input must change consumer pixels")
    Existing.save("build/consumer-changed.ppm",changed)
    keys(display,id,Bool.pick(List<&2,U32>,game,[108,108,108,108,32],[]))
    +completed:Pixels.Frame <- frame(pid,id,game)
    Existing.save("build/consumer-complete.ppm",completed)
    Check.assert(Bool.pick(Bool,game,Bool.not(Pixels.equal(changed,completed)),True{}),"Delivery must visibly change carried state")
    tap(display,id,Bool.pick(U32,game,120,114))
    +reset:Pixels.Frame <- frame(pid,id,game)
    Existing.save("build/consumer-reset.ppm",reset)
    Check.assert(Pixels.equal(initial,reset),"Consumer reset must restore exact initial pixels")
    IO.try(Unit,Host.control(id,0,800,600))
    IO.sleep(250)
    IO.try(Unit,Host.control(id,0,640,480))
    IO.sleep(250)
    +restored:Pixels.Frame <- frame(pid,id,game)
    Check.assert(Pixels.equal(initial,restored),"Resize restore must preserve exact consumer pixels")
    IO.try(Unit,UI.send_to(display,id,[Close{}]))
    Existing.wait_exit(300n,pid)
    +log:String <- Check.read("build/consumer-window.log")
    Check.assert(String.contains(log,"Consumer window closed; live Vulkan objects: 0") && Check.clean_diagnostics(log),"Consumer clean Vulkan teardown and validation")
    Check.assert(Bool.pick(Bool,game,String.contains(log,"courier-state 1 3 Carrying energy") && String.contains(log,"courier-state 5 3 Delivery complete!") && String.contains(log,"courier-state 3 3 Find the amber"),True{}),"Live game must record pickup, delivery and reset")
    IO.print("Consumer X11 populated pixels, real controls, exact reset, resize restore, Close and zero Vulkan objects passed.")

def run(game:Bool) -> IO(Unit):
  +game:Bool = game
  do IO<Unit>:
    +display:String <- IO.try(String,IO.get_env("DISPLAY"))
    +pid:U32 <- IO.try(U32,Host.start("build/consumer-window.log",False{}))
    +id:U32 <- Existing.wait_window(300n,pid)
    IO.try(Unit,Host.control(id,2,0,0))
    +initial:Pixels.Frame <- frame(pid,id,game)
    Existing.save("build/consumer-initial.ppm",initial)
    exercise(display,pid,id,game,initial)

def args(values:List<String>) -> IO(Unit):
  match values:
    case _ <> "game" <> _:run(True{})
    case _:run(False{})

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<String> <- IO.args()
    args(values)
