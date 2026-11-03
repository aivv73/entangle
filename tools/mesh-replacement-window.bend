import Base
import ./verify-mesh-replacement.bend as Check
import ../src/scene-window.bend as Win
import ../src/scene-render.bend as R
import ../src/scene-geometry.bend as G
import ../src/scene-buffer.bend as B
import ../src/scene-diagnostics.bend as Diag
import ../src/measurement-counters.bend as Count
import ../src/creation.bend as Create
import ../src/error.bend as Error
import ../src/app.bend as Scope
import ../src/scene-matrix.bend as M
import ../src/components.bend as C
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W

type State is Type:State{renderer:Win.Renderer,id:U32}

def camera() -> M.Mat4:
  M.model(C.Transform{C.Vec3{0.0,0.0,0.0},C.Quat{0.0,0.0,0.0,1.0},C.Vec3{1.0,F32.neg(1.0),1.0}})

def replace(renderer:Win.Renderer,mesh:Create.Geometry,installed:Bool) -> V.Action(Win.Renderer):
  do V.Action<Win.Renderer>:
    pair:Win.Renderer & G.ReplaceStatus <- V.Action.lift(Win.Renderer & G.ReplaceStatus,Win.replace_geometry(renderer,mesh))
    Check.replacement(Win.Renderer,pair,installed)

def writes(probe:Diag.Probe) -> U32:
  match probe:
    case Diag.Off{}:0
    case Diag.On{owner,props,active,generation,Count.Counters{w,b,p,pb,d,s},counters,spans,outcome,gpu}:w

def counted(renderer:Win.Renderer,expected:U32) -> V.Action(Win.Renderer):
  Win.Renderer{window,target,resident,+probe} = renderer
  do V.Action<Win.Renderer>:
    Error.require(U32.is_eq(writes(probe),expected),"Successful host write count lost or fabricated")
    return Win.Renderer{window,target,resident,probe}

def recording_rejected(pair:Win.Renderer & G.ReplaceStatus) -> V.Action(Win.Renderer):
  match pair:
    case (renderer,G.Rejected{G.Failure{(1610612740,_),[]}}):V.Action.pure(Win.Renderer,renderer)
    case _:Error.failure(Win.Renderer,1,"Window active recording retirement did not reject cleanly")

def bind_index(command:V.CommandBuffer,buffers:G.Buffers) -> V.Action(Unit):
  G.Buffers{vb,ib} = buffers
  V.CommandBuffer.bind_index_buffer(command,B.handle(ib),W.zero(),vk.VK_INDEX_TYPE_UINT32())

def recording(renderer:Win.Renderer) -> V.Action(Win.Renderer):
  Win.Renderer{+window,target,+resident,+probe} = renderer
  +device = G.device(Win.geometry_context(window))
  do V.Action<Win.Renderer>:
    +buffers:G.Buffers <- Check.retained_buffers(resident)
    +pool:V.CommandPool <- V.Device.create_command_pool(device)
    +command:V.CommandBuffer <- V.Device.allocate_command_buffer(device,pool)
    +base:U32 <- V.debug_live_objects()
    V.CommandBuffer.begin(command)
    R.bind_geometry(command,None{})
    bind_index(command,buffers)
    pair:Win.Renderer & G.ReplaceStatus <- V.Action.lift(Win.Renderer & G.ReplaceStatus,Win.replace_geometry(Win.Renderer{window,target,resident,probe},Check.green()))
    renderer:Win.Renderer <- recording_rejected(pair)
    renderer:Win.Renderer <- counted(renderer,U32.add(writes(probe),2))
    Check.live(base,"Window rejected candidate disposed")
    V.CommandBuffer.reset(command)
    V.Device.destroy_command_pool(device,pool)
    return renderer

def event_key(state:State,+code:U32) -> V.Action(State):
  State{renderer,id} = state
  match code:
    case 103:
      do V.Action<State>:
        renderer:Win.Renderer <- replace(renderer,Check.green(),True{})
        return State{renderer,10}
    case 114:
      do V.Action<State>:
        renderer:Win.Renderer <- replace(renderer,Check.red(),True{})
        return State{renderer,7}
    case 101:
      do V.Action<State>:
        renderer:Win.Renderer <- replace(renderer,Check.empty(),True{})
        return State{renderer,11}
    case 105:
      do V.Action<State>:
        renderer:Win.Renderer <- replace(renderer,Check.invalid(),False{})
        return State{renderer,id}
    case 98:
      do V.Action<State>:
        renderer:Win.Renderer <- recording(renderer)
        return State{renderer,id}
    case _:V.Action.pure(State,State{renderer,id})

def events(evs:List<Event>,state:State) -> V.Action(Maybe<State>):
  match evs:
    case []:V.Action.pure(Maybe<State>,Some{state})
    case Close{} <> rest:
      State{renderer,id} = state
      do V.Action<Maybe<State>>:
        Win.close(renderer)
        return None{}
    case Key{+code,True{}} <> rest:
      do V.Action<Maybe<State>>:
        state:State <- event_key(state,code)
        V.Action.lift(Unit,IO.print_err("mesh-event=" ++ U32.show(code)))
        events(rest,state)
    case _ <> rest:events(rest,state)

def drawn(pair:Win.Renderer & Result<&2,&2,Win.InputError,Unit>,id:U32) -> V.Action(Maybe<State>):
  do V.Action<Maybe<State>>:
    renderer:Win.Renderer <- Error.owner(Win.Renderer,Win.InputError,Unit,pair,"Replacement window drawing rejected")
    return Some{State{renderer,id}}

def frame(state:Maybe<State>,snapshot:V.WindowSnapshot) -> V.Action(Maybe<State>):
  match state:
    case None{}:V.Action.pure(Maybe<State>,None{})
    case Some{State{renderer,+id}}:
      do V.Action<Maybe<State>>:
        pair:Win.Renderer & Result<&2,&2,Win.InputError,Unit> <- Win.frame(renderer,snapshot,w => h => Some{camera()},Check.draws(id))
        drawn(pair,id)

def polled(pair:Win.Renderer & V.WindowSnapshot,id:U32) -> V.Action(Maybe<State>):
  (renderer,snapshot) = pair
  V.WindowSnapshot{w,h,mapped,focus,capture,evs} = snapshot
  do V.Action<Maybe<State>>:
    state:Maybe<State> <- events(evs,State{renderer,id})
    frame(state,V.WindowSnapshot{w,h,mapped,focus,capture,[]})

def loop(fuel:Nat,state:Maybe<State>) -> V.Action(Unit):
  match fuel state:
    case _ None{}:V.Action.pure(Unit,Unit{})
    case 0n Some{State{renderer,id}}:Win.close(renderer)
    case 1n+rest Some{State{renderer,id}}:
      do V.Action<Unit>:
        pair:Win.Renderer & V.WindowSnapshot <- Win.poll(renderer)
        next:Maybe<State> <- polled(pair,id)
        loop(rest,next)

def hidden(renderer:Win.Renderer) -> V.Action(Win.Renderer):
  do V.Action<Win.Renderer>:
    +base:U32 <- V.debug_live_objects()
    renderer:Win.Renderer <- replace(renderer,Check.green(),True{})
    Check.live(U32.add(base,4),"Window publishes without collection")
    pair:Win.Renderer & Result<&2,&2,Win.InputError,Unit> <- Win.frame(renderer,V.WindowSnapshot{0,0,False{},False{},False{},[]},w => h => Some{camera()},Check.draws(10))
    renderer:Win.Renderer <- Error.owner(Win.Renderer,Win.InputError,Unit,pair,"Hidden replacement frame failed")
    Check.live(base,"Hidden frame collects without acquisition")
    renderer:Win.Renderer <- replace(renderer,Check.empty(),True{})
    pair:Win.Renderer & V.VkResult(Unit) <- V.Action.lift(Win.Renderer & V.VkResult(Unit),Win.collect_geometry(renderer))
    renderer:Win.Renderer <- Check.collected(Win.Renderer,pair)
    Check.live(U32.sub(base,4),"Empty resident collection")
    renderer:Win.Renderer <- replace(renderer,Check.red(),True{})
    counted(renderer,6)

def run(entry:V.Entry) -> V.Action(Unit):
  do V.Action<Unit>:
    renderer:Win.Renderer <- Win.open_measured(entry,"Entangle mesh replacement",Check.red())
    renderer:Win.Renderer <- hidden(renderer)
    V.Action.lift(Unit,IO.print("Hidden and empty lifecycle collection and measured successful writes verified."))
    loop(100000n,Some{State{renderer,7}})

def finished(pair:V.VkResult(Unit) & U32) -> IO(Unit):
  (result,count) = pair
  do IO<Unit>:
    V.or_exit(Unit,result)
    verified:V.VkResult(Unit) <- Error.require(U32.is_zero(count),"Replacement window leaked")
    V.or_exit(Unit,verified)
    IO.print("Mesh replacement window closed; live Vulkan objects: 0")

def main() -> IO(Unit):
  do IO<Unit>:
    pair:V.VkResult(Unit) & U32 <- Scope.with(Unit,run)
    finished(pair)
