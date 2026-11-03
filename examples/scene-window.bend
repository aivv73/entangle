import Base
import ./scene-window-app.bend as SceneApp
import ../src/app.bend as Scope
import ../src/time.bend as Time
import ../src/error.bend as Error
import ../src/input.bend as Camera
import ../tools/window-input-check.bend as Input
import ../src/scene-window.bend as Win
import ../src/scene-draw.bend as Draw
import ../src/scene.bend as Scene
import ../src/scene-observe.bend as Observe
import ../deps/bendvy/src/ecs/inspector.bend as I
import ../deps/bend-vulkan/Vulkan.bend as V

type Mode is Data:Live{} Replay{} Terminal{}
def scheduled(ready:Bool,mode:Mode,state:SceneApp.State,now:Nat,mapped:Bool) -> V.Action(SceneApp.State):
  match ready mode:
    case True{} Live{}:
      do V.Action<SceneApp.State>:
        V.Action.lift(Unit,IO.print(Bool.pick(String,mapped,"window-visible-tick","window-hidden-tick")))
        SceneApp.advance(state,now)
    case _ _:V.Action.pure(SceneApp.State,state)

def update(+mode:Mode,state:SceneApp.State,+now:Nat,mapped:Bool) -> V.Action(SceneApp.State):
  SceneApp.State{app,inspector,baseline,rows,draws,retained,saved,tick,+due} = state
  scheduled(Time.ready(now,due),mode,SceneApp.State{app,inspector,baseline,rows,draws,retained,saved,tick,due},now,mapped)

def is_replay(mode:Mode) -> Bool:
  match mode:
    case Replay{}:True{}
    case _:False{}

type Running is Type:Running{renderer:Win.Renderer,state:SceneApp.State,camera:Camera.Camera}

def running(pair:Win.Renderer & SceneApp.State,camera:Camera.Camera) -> Maybe<Running>:
  (renderer,state) = pair
  Some{Running{renderer,state,camera}}

def drawn(mode:Mode,pair:Win.Renderer & SceneApp.State,camera:Camera.Camera) -> V.Action(Maybe<Running>):
  match mode:
    case Terminal{}:IO.pure(V.VkResult(Maybe<Running>),Fail{(1,"intentional window scope termination")})
    case _:V.Action.pure(Maybe<Running>,running(pair,camera))

def continued(camera:Maybe<Camera.Camera>,renderer:Win.Renderer,state:SceneApp.State,snapshot:V.WindowSnapshot,+mode:Mode,mapped:Bool) -> V.Action(Maybe<Running>):
  match camera:
    case None{}:
      do V.Action<Maybe<Running>>:
        Win.close(renderer)
        return None{}
    case Some{+camera}:
      do V.Action<Maybe<Running>>:
        now : Nat <- V.Action.lift(Nat,IO.now())
        state : SceneApp.State <- update(mode,state,now,mapped)
        pair : Win.Renderer & SceneApp.State <- SceneApp.draw(state,renderer,snapshot,camera,is_replay(mode))
        drawn(mode,pair,camera)

def polled_ready(pair:Maybe<Camera.Camera> & V.WindowSnapshot,renderer:Win.Renderer,state:SceneApp.State,mode:Mode) -> V.Action(Maybe<Running>):
  (camera,V.WindowSnapshot{width,height,+mapped,focused,captured,events}) = pair
  continued(camera,renderer,state,V.WindowSnapshot{width,height,mapped,focused,captured,events},mode,mapped)

def polled(pair:Win.Renderer & V.WindowSnapshot,state:SceneApp.State,camera:Camera.Camera,mode:Mode) -> V.Action(Maybe<Running>):
  (renderer,V.WindowSnapshot{width,height,mapped,focused,captured,pending}) = pair
  polled_ready(Camera.snapshot(V.WindowSnapshot,events => V.WindowSnapshot{width,height,mapped,focused,captured,events},pending,Some{camera}),renderer,state,mode)

def step(running:Running,+mode:Mode) -> V.Action(Maybe<Running>):
  Running{renderer,state,camera} = running
  do V.Action<Maybe<Running>>:
    pair : Win.Renderer & V.WindowSnapshot <- Win.poll(renderer)
    polled(pair,state,camera,mode)

def loop(fuel:Nat,running:Maybe<Running>,+mode:Mode) -> V.Action(Unit):
  match fuel running:
    case _ None{}:V.Action.pure(Unit,Unit{})
    case 0n Some{Running{renderer,state,camera}}:Win.close(renderer)
    case 1n+rest Some{value}:
      do V.Action<Unit>:
        next : Maybe<Running> <- step(value,mode)
        loop(rest,next,mode)

def initialized(mode:Mode,state:SceneApp.State,now:Nat) -> V.Action(SceneApp.State):
  match mode:
    case Replay{}:
      do V.Action<SceneApp.State>:
        state : SceneApp.State <- SceneApp.advance(SceneApp.retain(state),now)
        SceneApp.replay_ready(state)
    case _:V.Action.pure(SceneApp.State,SceneApp.retain(state))

def run(entry:V.Entry,+mode:Mode) -> V.Action(Unit):
  do V.Action<Unit>:
    renderer : Win.Renderer <- Win.open(entry,"Entangle ECS scene",SceneApp.mesh())
    renderer : Win.Renderer <- Input.enabled(is_replay(mode),renderer)
    app : Scene.Application() <- V.Action.lift(Scene.Application(),Scene.create())
    app : Scene.Application() <- V.Action.lift(Scene.Application(),Scene.tick(app))
    +now : Nat <- V.Action.lift(Nat,IO.now())
    state : SceneApp.State <- SceneApp.observed(Observe.snapshot(app,I.Fresh{}),[],1,Time.next_due(now,250n),Draw.DrawList{[]},[])
    state : SceneApp.State <- initialized(mode,state,now)
    loop(U32.to_nat(4294967295),Some{Running{renderer,state,Camera.initial()}},mode)

def mode(result:Result<&1,&1,U32 & String,String>) -> Mode:
  match result:
    case Done{"replay"}:Replay{}
    case Done{"terminal"}:Terminal{}
    case _:Live{}

def completed(mode:Mode,result:V.VkResult(Unit)) -> IO(Unit):
  match mode result:
    case Terminal{} Fail{(1,"intentional window scope termination")}:
      IO.print("Window terminal Action cleanup verified; live Vulkan objects: 0")
    case Terminal{} _:IO.die(Unit,1,"Expected window terminal error")
    case _ other:
      do IO<Unit>:
        V.or_exit(Unit,other)
        IO.print("Entangle window closed; live Vulkan objects: 0")

def finished(selected:Mode,pair:V.VkResult(Unit) & U32) -> IO(Unit):
  (result,count) = pair
  do IO<Unit>:
    checked : V.VkResult(Unit) <- Error.require(U32.is_zero(count),"Window leaked objects")
    V.or_exit(Unit,checked)
    completed(selected,result)

def main() -> IO(Unit):
  do IO<Unit>:
    Input.bits()
    environment : Result<&1,&1,U32 & String,String> <- IO.get_env("ENTANGLE_WINDOW_MODE")
    +selected : Mode = mode(environment)
    scoped : V.VkResult(Unit) & U32 <- Scope.with(Unit,entry => run(entry,selected))
    finished(selected,scoped)
