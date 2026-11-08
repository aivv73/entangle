import Base
import bend-window-capture@0.1.0.2/capture.bend as Capture
import ./check.bend as Check
import ./bridge.bend as Host
import ./pixels.bend as Pixels

# Every poll is bounded. The native process owner reaps/kills on all exits.
def running(status: Maybe<U32>) -> IO(Unit):
  match status:
    case None{}: IO.pure(Unit,Unit{})
    case Some{code}: IO.die(Unit,1,"Window exited during verification: " ++ U32.show(code))

def alive(pid: U32) -> IO(Unit):
  do IO<Unit>:
    status : Maybe<U32> <- IO.try(Maybe<U32>,Host.status(pid))
    running(status)

def poll_window(fuel: Nat, +pid: U32, id: U32) -> IO(U32):
  match fuel id:
    case 0n 0: IO.die(U32,1,"Timed out waiting for window creation")
    case 1n+rest 0:
      do IO<U32>:
        alive(pid)
        IO.sleep(50)
        next : U32 <- IO.try(U32,Host.find(pid))
        poll_window(rest,pid,next)
    case _ other: IO.pure(U32,other)

def wait_window(fuel: Nat, pid: U32) -> IO(U32):
  poll_window(fuel,pid,0)

type Expect is Data:
  Rendered{width: U32, height: U32}
  Changed{baseline: Pixels.Frame}
  Reset{baseline: Pixels.Frame}

def matches(expect: Expect, +frame: Pixels.Frame) -> Bool:
  match expect:
    case Rendered{w,h}: Pixels.extent(frame,w,h) && Pixels.rendered(frame)
    case Changed{baseline}: Bool.not(Pixels.equal(baseline,frame)) && Pixels.rendered(frame)
    case Reset{baseline}: Pixels.equal(baseline,frame)

def candidate(expect: Expect, +frame: Pixels.Frame) -> Maybe<Pixels.Frame>:
  Bool.pick(Maybe<Pixels.Frame>,matches(expect,frame),Some{frame},None{})

def observed(+frame: Pixels.Frame, expect: Expect) -> IO(Maybe<Pixels.Frame>):
  Pixels.Frame{w,h,pixels} = frame
  do IO<Maybe<Pixels.Frame>>:
    IO.print("Captured " ++ U32.show(w) ++ "x" ++ U32.show(h))
    return candidate(expect,frame)

def capture_frame(capture: Capture.Capture) -> Pixels.Frame:
  Capture.Capture{w,h,pixels} = capture
  Pixels.frame(w,h,pixels)

def captured(result: Result<&1,&1,U32 & String,Capture.Capture>, expect: Expect) -> IO(Maybe<Pixels.Frame>):
  match result:
    case Fail{(code,message)}:
      do IO<Maybe<Pixels.Frame>>:
        IO.print(message)
        return None{}
    case Done{capture}: observed(capture_frame(capture),expect)

def poll_frame(fuel: Nat, +deadline: Nat, +pid: U32, +id: U32, +expect: Expect, current: Maybe<Pixels.Frame>) -> IO(Pixels.Frame):
  match fuel current:
    case _ Some{frame}: IO.pure(Pixels.Frame,frame)
    case 0n None{}: IO.die(Pixels.Frame,1,"Timed out waiting for rendered pixels/camera/extent")
    case 1n+rest None{}:
      do IO<Pixels.Frame>:
        now : Nat <- IO.now()
        Check.assert(Nat.is_lt(now,deadline),"Timed out waiting for rendered pixels/camera/extent (15 seconds)")
        alive(pid)
        IO.sleep(50)
        capture : Result<&1,&1,U32 & String,Capture.Capture> <- Host.capture(id)
        next : Maybe<Pixels.Frame> <- captured(capture,expect)
        poll_frame(rest,deadline,pid,id,expect,next)

def wait_frame(fuel: Nat, pid: U32, id: U32, expect: Expect) -> IO(Pixels.Frame):
  do IO<Pixels.Frame>:
    now : Nat <- IO.now()
    poll_frame(fuel,Nat.add(now,15000n),pid,id,expect,None{})

def poll_exit(fuel: Nat, +pid: U32, status: Maybe<U32>) -> IO(Unit):
  match fuel status:
    case _ Some{+code}: Check.assert(U32.is_zero(code),"Window failed with status " ++ U32.show(code))
    case 0n None{}: IO.die(Unit,1,"Timed out waiting for clean shutdown")
    case 1n+rest None{}:
      do IO<Unit>:
        IO.sleep(50)
        next : Maybe<U32> <- IO.try(Maybe<U32>,Host.status(pid))
        poll_exit(rest,pid,next)

def wait_exit(fuel: Nat, pid: U32) -> IO(Unit):
  poll_exit(fuel,pid,None{})

def save_pixels(pair: File & Result<&1,&1,U32 & String,Unit>, pixels: List<&2,U32>) -> IO(Unit):
  (file,result) = pair
  do IO<Unit>:
    IO.pass(Unit,result)
    written : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,Pixels.bytes(pixels))
    Check.write_done(written)

def save(path: String, frame: Pixels.Frame) -> IO(Unit):
  Pixels.Frame{w,h,pixels} = frame
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    header : File & Result<&1,&1,U32 & String,Unit> <- File.write(file,"P6\n" ++ U32.show(w) ++ " " ++ U32.show(h) ++ "\n255\n")
    save_pixels(header,pixels)


