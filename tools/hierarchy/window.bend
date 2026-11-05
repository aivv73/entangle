import Base
import ./drive.bend as Drive
import ./scenes.bend as Scenes
import ./render.bend as Render
import ../../src/scene.bend as Scene
import ../../src/scene-hierarchy.bend as HW
import ../../src/creation.bend as Create
import ../../src/scene-window.bend as Win
import ../../src/scene-draw.bend as Draw
import ../../src/scene-matrix.bend as M
import ../../src/app.bend as Scope
import ../../src/error.bend as Error
import ../../deps/bend-vulkan/Vulkan.bend as V
import ../verify-creation.bend as Consumer
import ../verify-textured-render.bend as Pixel

type State is Type:
  State{app:Scene.Application(),rows:List<&2,HW.Row>}
type Running is Type:
  Running{renderer:Win.Renderer,state:State}

def camera() -> M.Mat4:
  M.Mat4{M.Vec4{1.0,0.0,0.0,0.0},M.Vec4{0.0,F32.neg(1.0),0.0,0.0},M.Vec4{0.0,0.0,1.0,0.0},M.Vec4{0.0,0.0,0.0,1.0}}

def initial(pair:Scene.Application() & List<&2,HW.Row>) -> State:
  (app,rows) = pair
  State{app,rows}

def code(key:U32) -> Maybe<&2,U32>:
  match key:
    case 49:Some{1}
    case 50:Some{2}
    case 51:Some{3}
    case 52:Some{4}
    case 53:Some{5}
    case 54:Some{6}
    case 55:Some{7}
    case 56:Some{8}
    case 57:Some{9}
    case 114:Some{0}
    case 98:Some{12}
    case _:None{}

def applied(action:Maybe<&2,U32>,state:State) -> IO(State):
  match action state:
    case None{} state:IO.pure(State,state)
    case Some{code} State{app,rows}:
      do IO<State>:
        pair:Scene.Application() & List<&2,HW.Row> <- Drive.step(code,(app,rows))
        return initial(pair)

def input(events:List<Event>,state:State) -> IO(Maybe<State>):
  match events:
    case []:IO.pure(Maybe<State>,Some{state})
    case Close{} <> _:IO.pure(Maybe<State>,None{})
    case Key{27,True{}} <> _:IO.pure(Maybe<State>,None{})
    case Key{key,True{}} <> rest:
      do IO<Maybe<State>>:
        state:State <- applied(code(key),state)
        input(rest,state)
    case _ <> rest:input(rest,state)

def frame(renderer:Win.Renderer,snapshot:V.WindowSnapshot,state:Maybe<State>) -> V.Action(Maybe<Running>):
  match state:
    case None{}:
      do V.Action<Maybe<Running>>:
        Win.close(renderer)
        return None{}
    case Some{State{app,+rows}}:
      do V.Action<Maybe<Running>>:
        pair:Win.Renderer & Result<&2,&2,Win.InputError,Unit> <- Win.frame(renderer,snapshot,_ => _ => Some{camera()},Draw.DrawList{HW.draw_rows(rows)})
        renderer:Win.Renderer <- Error.owner(Win.Renderer,Win.InputError,Unit,pair,"Hierarchy window frame rejected")
        return Some{Running{renderer,State{app,rows}}}

def polled(pair:Win.Renderer & V.WindowSnapshot,state:State) -> V.Action(Maybe<Running>):
  (renderer,snapshot) = pair
  V.WindowSnapshot{w,h,mapped,focused,captured,events} = snapshot
  do V.Action<Maybe<Running>>:
    state:Maybe<State> <- V.Action.lift(Maybe<State>,input(events,state))
    frame(renderer,V.WindowSnapshot{w,h,mapped,focused,captured,[]},state)

def loop(fuel:Nat,running:Maybe<Running>) -> V.Action(Unit):
  match fuel running:
    case _ None{}:V.Action.pure(Unit,Unit{})
    case 0n Some{Running{renderer,_}}:Win.close(renderer)
    case 1n+n Some{Running{renderer,state}}:
      do V.Action<Unit>:
        pair:Win.Renderer & V.WindowSnapshot <- Win.poll(renderer)
        next:Maybe<Running> <- polled(pair,state)
        loop(n,next)

def run(entry:V.Entry,compiled:Create.Compiled) -> V.Action(Unit):
  Create.Compiled{_,geometry} = compiled
  do V.Action<Unit>:
    pair:Scene.Application() & List<&2,HW.Row> <- V.Action.lift(Scene.Application() & List<&2,HW.Row>,Drive.boot())
    pair:Scene.Application() & List<&2,HW.Row> <- V.Action.lift(Scene.Application() & List<&2,HW.Row>,Drive.step(0,pair))
    renderer:Win.Renderer <- Win.open(entry,"Entangle scene hierarchy",geometry)
    loop(100000n,Some{Running{renderer,initial(pair)}})

def main() -> IO(Unit):
  do IO<Unit>:
    compiled:Create.Compiled <- Consumer.compiled(Create.compile(Scenes.showcase()))
    pair:V.VkResult(Unit) & U32 <- Scope.with(Unit,entry => run(entry,compiled))
    Render.finished(pair)
    IO.print("Hierarchy window closed; live Vulkan objects: 0")
