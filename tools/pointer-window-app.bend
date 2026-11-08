import Base
import ../src/vulkan-window.bend as Host
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/examples/buffer_roundtrip.bend as Check

def pointer(events:List<Event>,+seen:U32) -> V.Action(U32):
  match events:
    case []:V.Action.pure(U32,seen)
    case Press{+id,Tool.Mouse{},+x,+y,+time,+button,+down} <> rest:
      do V.Action<U32>:
        Check.require(U32.is_zero(id) && F32.is_eq(x,F32.neg(12.0)) && F32.is_eq(y,34.0) && U32.is_lt(button,3) && U32.is_eq(time,U32.add(305419897,button)),"Pointer Press ABI mismatch")
        pointer(rest,U32.or(seen,U32.shln(1,U32.to_nat(U32.add(button,Bool.pick(U32,down,0,3))))))
    case Move{+id,Tool.Mouse{},+x,+y,305419896} <> rest:
      do V.Action<U32>:
        Check.require(U32.is_zero(id) && F32.is_eq(x,F32.neg(12.0)) && F32.is_eq(y,34.0),"Pointer Move ABI mismatch")
        pointer(rest,U32.or(seen,64))
    case Scroll{+x,+y,+dx,+dy} <> rest:
      do V.Action<U32>:
        Check.require(F32.is_eq(x,F32.neg(12.0)) && F32.is_eq(y,34.0),"Pointer Scroll coordinate ABI mismatch")
        Check.require((F32.is_eq(dx,0.0) && F32.is_eq(dy,1.0)) || (F32.is_eq(dx,F32.neg(1.0)) && F32.is_eq(dy,0.0)),"Pointer Scroll delta ABI mismatch")
        pointer(rest,U32.or(seen,Bool.pick(U32,F32.is_eq(dx,0.0),128,256)))
    case _ <> rest:pointer(rest,seen)

def snapshot_events(snapshot:V.WindowSnapshot) -> List<Event>:
  V.WindowSnapshot{_,_,_,_,_,events} = snapshot
  events

def observed(fuel:Nat,+window:V.NativeWindow,seen:U32) -> V.Action(Unit):
  match fuel seen:
    case _ 511:
      do V.Action<Unit>:
        Host.close_window(window)
        V.Action.lift(Unit,IO.print("Native Press buttons/down/up, Tool.Mouse, signed F32 coordinates, timestamps, Move and Scroll verified."))
    case 0n _:
      IO.pure(V.VkResult(Unit),Fail{(1,"Pointer events did not retain all three W3C button identities and motion/scroll fields")})
    case 1n+rest _:
      do V.Action<Unit>:
        snapshot:V.WindowSnapshot <- Host.poll(window,50)
        next:U32 <- pointer(snapshot_events(snapshot),seen)
        observed(rest,window,next)

def run(entry:V.Entry) -> V.Action(Unit):
  do V.Action<Unit>:
    window:V.NativeWindow <- Host.open_window(entry,"Entangle pointer ABI",200,150)
    observed(200n,window,0)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.try(Unit,V.Entry.with(Unit,run))
    live:U32 <- IO.try(U32,V.debug_live_objects())
    IO.pass(Unit,Bool.pick(Result<&1,&1,U32 & String,Unit>,U32.is_zero(live),Done{Unit{}},Fail{(1,"Pointer window leaked native objects")}))
    IO.print("Pointer window closed; live Vulkan objects: 0")
