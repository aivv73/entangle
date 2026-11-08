import Base
import bend-window-capture@0.1.0.2/capture.bend as Capture
import ./window-verification/input/uitest.bend as UI
import ./window-verification/check.bend as Check
import ./window-verification/bridge.bend as Host
import ./window-verification/pixels.bend as Pixels
import ./window-verification/existing.bend as Existing

type Expect is Data:
  Populated{width:U32,height:U32}
  Moved{baseline:Pixels.Frame}
  Exact{baseline:Pixels.Frame}

def geometry(+pixel:U32) -> Bool:
  Pixels.warm_rgb(Pixels.rgb(pixel)) || Pixels.cool_rgb(Pixels.rgb(pixel))

def count(pixels:List<&2,U32>) -> U32:
  match pixels:
    case []:0
    case pixel <> rest:U32.add(Bool.to_u32(geometry(pixel)),count(rest))

def changed(left:List<&2,U32>,right:List<&2,U32>) -> U32:
  match left right:
    case +x <> xs,+y <> ys:
      U32.add(Bool.to_u32((geometry(x) || geometry(y)) && U32.is_ne(x,y)),changed(xs,ys))
    case _,_:0

def movement(first:Pixels.Frame,last:Pixels.Frame) -> Bool:
  Pixels.Frame{+w,+h,a} = first
  Pixels.Frame{x,y,b} = last
  U32.is_eq(w,x) && U32.is_eq(h,y) && U32.is_gt(changed(a,b),5)

def populated(frame:Pixels.Frame) -> Bool:
  Pixels.Frame{w,h,pixels} = frame
  U32.is_gt(count(pixels),50)

def matches(expect:Expect,+frame:Pixels.Frame) -> Bool:
  match expect:
    case Populated{w,h}:Pixels.extent(frame,w,h) && populated(frame)
    case Moved{baseline}:populated(frame) && movement(baseline,frame)
    case Exact{baseline}:populated(frame) && Pixels.equal(baseline,frame)

def selected(+frame:Pixels.Frame,expect:Expect) -> IO(Maybe<Pixels.Frame>):
  IO.pure(Maybe<Pixels.Frame>,Bool.pick(Maybe<Pixels.Frame>,matches(expect,frame),Some{frame},None{}))

def candidate(result:Result<&1,&1,U32 & String,Capture.Capture>,expect:Expect) -> IO(Maybe<Pixels.Frame>):
  match result:
    case Fail{(code,message)}:IO.pure(Maybe<Pixels.Frame>,None{})
    case Done{capture}:selected(Existing.capture_frame(capture),expect)

def poll(fuel:Nat,+deadline:Nat,+pid:U32,+id:U32,+expect:Expect,current:Maybe<Pixels.Frame>) -> IO(Pixels.Frame):
  match fuel current:
    case _ Some{frame}:IO.pure(Pixels.Frame,frame)
    case 0n None{}:IO.die(Pixels.Frame,1,"Window pixels did not satisfy expectation")
    case 1n+rest None{}:
      do IO<Pixels.Frame>:
        now : Nat <- IO.now()
        Check.assert(Nat.is_lt(now,deadline),"Window pixel deadline exceeded")
        Existing.alive(pid)
        IO.sleep(50)
        capture : Result<&1,&1,U32 & String,Capture.Capture> <- Host.capture(id)
        next : Maybe<Pixels.Frame> <- candidate(capture,expect)
        poll(rest,deadline,pid,id,expect,next)

def wait(pid:U32,id:U32,expect:Expect) -> IO(Pixels.Frame):
  do IO<Pixels.Frame>:
    now : Nat <- IO.now()
    poll(300n,Nat.add(now,15000n),pid,id,expect,None{})

def save(+name:String,+frame:Pixels.Frame) -> IO(Unit):
  Pixels.Frame{w,h,pixels} = frame
  do IO<Unit>:
    Existing.save("build/window-evidence/" ++ name ++ ".ppm",frame)
    IO.print(name ++ " " ++ U32.show(w) ++ "x" ++ U32.show(h) ++ " geometry-pixels=" ++ U32.show(count(pixels)))

def key(+display:String,+id:U32,+code:U32) -> IO(Unit):
  IO.try(Unit,UI.send_to(display,id,[Key{code,True{}},Key{code,False{}}]))

def controls(codes:List<&2,U32>,+display:String,+pid:U32,+id:U32,+baseline:Pixels.Frame) -> IO(Unit):
  match codes:
    case []:IO.pure(Unit,Unit{})
    case +code <> rest:
      do IO<Unit>:
        key(display,id,code)
        +moved : Pixels.Frame <- wait(pid,id,Moved{baseline})
        save("key-" ++ U32.show(code),moved)
        key(display,id,114)
        reset : Pixels.Frame <- wait(pid,id,Exact{baseline})
        IO.print("key=" ++ U32.show(code) ++ " geometry-moved=true R=exact")
        controls(rest,display,pid,id,baseline)

def compare_extent(same:Bool,previous:Pixels.Frame,current:Pixels.Frame,next:Bool) -> Bool:
  match same:
    case True{}:Pixels.equal(previous,current) && next
    case False{}:next

def same_extent_replay(frames:List<&2,Pixels.Frame>,+current:Pixels.Frame) -> Bool:
  match frames:
    case []:True{}
    case +previous <> rest:
      Pixels.Frame{width,height,pixels} = previous
      compare_extent(Pixels.extent(current,width,height),previous,current,same_extent_replay(rest,current))

def resize(sizes:List<(U32 & U32)>,+display:String,+pid:U32,+id:U32,+seen:List<&2,Pixels.Frame>) -> IO(Unit):
  match sizes:
    case []:IO.pure(Unit,Unit{})
    case (+w,+h) <> rest:
      do IO<Unit>:
        IO.try(Unit,Host.control(id,0,w,h))
        +first : Pixels.Frame <- wait(pid,id,Populated{w,h})
        key(display,id,100)
        +moved : Pixels.Frame <- wait(pid,id,Moved{first})
        key(display,id,114)
        +reset : Pixels.Frame <- wait(pid,id,Moved{moved})
        Check.assert(same_extent_replay(seen,reset),"Revisited extent changed exact replay pixels")
        save("resize-" ++ U32.show(w) ++ "x" ++ U32.show(h),reset)
        resize(rest,display,pid,id,reset <> seen)

def occurrences(text:String,+needle:String) -> U32:
  match text:
    case SNil{}:0
    case SCon{+c,+rest}:U32.add(Bool.to_u32(String.starts_with(SCon{c,rest},needle)),occurrences(rest,needle))

def clean(+suffix:String) -> IO(Unit):
  do IO<Unit>:
    +output : String <- Check.read("build/window-evidence/" ++ suffix ++ ".log")
    Check.assert(String.contains(output,"Entangle window closed; live Vulkan objects: 0"),"Missing zero-live-object shutdown")
    Check.assert(Check.clean_diagnostics(output),"Vulkan validation diagnostics in " ++ suffix)

type TimingEvent is Data:
  Batch{steps:Nat,dropped:Nat}
  Tick{number:Nat}
  Other{}

def timing_word(is_tick:Bool,word:String) -> Maybe<&2,TimingEvent>:
  match is_tick:
    case False{}:Some{Other{}}
    case True{}:
      do Maybe<&2,TimingEvent>:
        number:Nat <- Nat.read(String.drop(word,12n))
        return Tick{number}

def timing_event(words:List<&2,String>) -> Maybe<&2,TimingEvent>:
  match words:
    case "fixed-batch" <> steps <> dropped <> rest:
      do Maybe<&2,TimingEvent>:
        steps:Nat <- Nat.read(String.drop(steps,6n))
        dropped:Nat <- Nat.read(String.drop(dropped,8n))
        return Batch{steps,dropped}
    case +word <> rest:timing_word(String.starts_with(word,"window-tick="),word)
    case []:Some{Other{}}

def timing_checked(event:Maybe<&2,TimingEvent>,+pending:Nat,expected:Nat,caught:Bool,next:Nat -> Nat -> Bool -> IO(Unit)) -> IO(Unit):
  match event:
    case None{}:IO.die(Unit,1,"Malformed timing evidence")
    case Some{Other{}}:next(pending)(expected)(caught)
    case Some{Tick{+number}}:
      do IO<Unit>:
        Check.assert(Nat.is_gt(pending,0n) && Nat.is_eq(number,expected),"World tick disagrees with bounded batch")
        next(Nat.sub(pending,1n))(1n+number)(caught)
    case Some{Batch{+steps,+dropped}}:
      do IO<Unit>:
        Check.assert(Nat.is_eq(pending,0n) && Nat.is_gt(steps,0n) && Nat.is_le(steps,4n),"Catch-up batch exceeded four steps or left work unfinished")
        next(steps)(expected)(caught || (Nat.is_eq(steps,4n) && Nat.is_gt(dropped,0n)))

def timing_audit(lines:List<&2,String>,pending:Nat,expected:Nat,caught:Bool) -> IO(Unit):
  match lines:
    case []:Check.assert(Nat.is_eq(pending,0n) && caught,"Missing complete four-step catch-up with excess dropped")
    case line <> rest:timing_checked(timing_event(String.split(line,' ')),pending,expected,caught,p => e => c => timing_audit(rest,p,e,c))

def live(+display:String,validation:Bool) -> IO(Unit):
  do IO<Unit>:
    +pid : U32 <- IO.try(U32,Host.start("build/window-evidence/live.log",validation))
    +id : U32 <- Existing.wait_window(300n,pid)
    IO.try(Unit,Host.control(id,2,0,0))
    +first : Pixels.Frame <- wait(pid,id,Populated{640,480})
    save("live-first",first)
    IO.sleep(750)
    +second : Pixels.Frame <- wait(pid,id,Moved{first})
    save("live-successive-ticks",second)
    Check.command("kill",["-STOP",U32.show(pid)])
    IO.sleep(1600)
    Check.command("kill",["-CONT",U32.show(pid)])
    IO.sleep(150)
    IO.try(Unit,Host.control(id,1,0,0))
    IO.sleep(800)
    Existing.alive(pid)
    IO.try(Unit,UI.send_to(display,id,[Close{}]))
    Existing.wait_exit(300n,pid)
    clean("live")
    +output : String <- Check.read("build/window-evidence/live.log")
    timing_audit(String.split(output,'\n'),1n,1n,False{})
    Check.assert(U32.is_ge(occurrences(output,"window-tick="),3),"No genuine successive ECS ticks")
    Check.assert(U32.is_ge(occurrences(output,"window-hidden-tick"),2),"Hidden window stopped ECS ticks or polling")
    IO.print("Successive ECS geometry movement, hidden ticks and hidden Close passed")

def replay(+display:String,validation:Bool) -> IO(Unit):
  do IO<Unit>:
    +pid : U32 <- IO.try(U32,Host.start("build/window-evidence/replay.log",validation))
    +id : U32 <- Existing.wait_window(300n,pid)
    IO.try(Unit,Host.control(id,2,0,0))
    +baseline : Pixels.Frame <- wait(pid,id,Populated{640,480})
    save("replay-tick-one",baseline)
    controls([97,100,119,115,113,101],display,pid,id,baseline)
    resize([(800,450),(360,640),(720,480),(360,640),(800,450),(640,480)],display,pid,id,[baseline])
    returned : Pixels.Frame <- wait(pid,id,Exact{baseline})
    IO.try(Unit,Host.control(id,1,0,0))
    IO.sleep(300)
    Existing.alive(pid)
    IO.try(Unit,Host.control(id,2,0,0))
    key(display,id,100)
    +moved : Pixels.Frame <- wait(pid,id,Moved{baseline})
    save("restored-moved",moved)
    key(display,id,114)
    restored : Pixels.Frame <- wait(pid,id,Exact{baseline})
    save("restored-exact",restored)
    key(display,id,27)
    Existing.wait_exit(300n,pid)
    clean("replay")
    +output : String <- Check.read("build/window-evidence/replay.log")
    Check.assert(String.contains(output,"replay-tick=1 world-tick=2 retained=exact"),"Missing retained ECS replay evidence")
    Check.assert(String.contains(output,"renderer recovered"),"Missing rejected-input recovery evidence")
    IO.print("Retained ECS camera replay, repeated resize, unmap/restore and Escape passed")

def terminal(validation:Bool) -> IO(Unit):
  do IO<Unit>:
    pid : U32 <- IO.try(U32,Host.start("build/window-evidence/terminal.log",validation))
    Existing.wait_exit(300n,pid)
    +output : String <- Check.read("build/window-evidence/terminal.log")
    Check.assert(String.contains(output,"Window terminal Action cleanup verified; live Vulkan objects: 0"),"Missing terminal cleanup evidence")
    Check.assert(Check.clean_diagnostics(output),"Terminal validation diagnostics")

def select(name:String,display:String,validation:Bool) -> IO(Unit):
  match name:
    case "live":live(display,validation)
    case "replay":replay(display,validation)
    case "terminal":terminal(validation)
    case _:IO.die(Unit,1,"Unknown window scenario")

def scenario(+name:String,validation:Bool) -> IO(Unit):
  do IO<Unit>:
    +display : String <- IO.try(String,IO.get_env("DISPLAY"))
    select(name,display,validation)

def invoke(+name:String,+validation:String) -> IO(Unit):
  Check.command("env",["ENTANGLE_WINDOW_MODE=" ++ name,"./build/verify-window",name,validation])

def discovered(output:Check.Output) -> IO(Unit):
  Check.Output{+out,err} = output
  +validation = Bool.pick(String,String.contains(out,"Layer: VK_LAYER_KHRONOS_validation\n"),"validation","plain")
  do IO<Unit>:
    Check.write("build/window-evidence/discovery.log",out ++ err)
    IO.print("Window validation=" ++ validation)
    invoke("live",validation)
    invoke("replay",validation)
    invoke("terminal",validation)
    IO.print("Entangle actual executable native window verification passed.")

def main_args(args:List<String>) -> IO(Unit):
  match args:
    case [_,name,"validation"]:scenario(name,True{})
    case [_,name,"plain"]:scenario(name,False{})
    case _:
      do IO<Unit>:
        Check.setup()
        Check.command("mkdir",["-p","build/window-evidence"])
        Check.command("bend",["examples/scene-window.bend","-o","build/indexed-window"])
        Check.command("bend",["tools/verify-window.bend","-o","build/verify-window"])
        Check.command("bend",["deps/bend-vulkan/examples/discover.bend","-o","build/window-discover"])
        output : Check.Output <- Check.run("./build/window-discover",[],60000)
        discovered(output)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    main_args(args)
