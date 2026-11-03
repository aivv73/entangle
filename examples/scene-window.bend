import ../src/creation.bend as Create
import Base
import ../src/modules.bend as Modules
import ./scene-window-modules.bend as Recipe
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
def scheduled(steps:Nat,state:SceneApp.State,mapped:Bool,dropped:Nat,remainder:Nat) -> V.Action(SceneApp.State):
  match steps:
    case 0n:V.Action.pure(SceneApp.State,state)
    case 1n++rest:
      do V.Action<SceneApp.State>:
        V.Action.lift(Unit,IO.print(Bool.pick(String,mapped,"window-visible-tick","window-hidden-tick")))
        V.Action.lift(Unit,IO.print("fixed-batch steps=" ++ Nat.show(1n+rest) ++ " dropped=" ++ Nat.show(dropped) ++ " remainder-ms=" ++ Nat.show(remainder)))
        SceneApp.steps(1n+rest,state)

def batch(pair:SceneApp.State & Time.Batch,mapped:Bool) -> V.Action(SceneApp.State):
  (state,Time.Batch{Time.Clock{sample,remainder},steps,dropped}) = pair
  scheduled(steps,state,mapped,dropped,remainder)

def update(mode:Mode,state:SceneApp.State,now:Nat,mapped:Bool) -> V.Action(SceneApp.State):
  match mode:
    case Live{}:
      batch(SceneApp.schedule(state,now),mapped)
    case _:V.Action.pure(SceneApp.State,state)

def is_replay(mode:Mode) -> Bool:
  match mode:
    case Replay{}:True{}
    case _:False{}

type Running is Type:Running{renderer:Win.Renderer,state:SceneApp.State,camera:Create.Camera}

def running(pair:Win.Renderer & SceneApp.State,camera:Create.Camera) -> Maybe<Running>:
  (renderer,state) = pair
  Some{Running{renderer,state,camera}}

def drawn(mode:Mode,pair:Win.Renderer & SceneApp.State,camera:Create.Camera) -> V.Action(Maybe<Running>):
  match mode:
    case Terminal{}:IO.pure(V.VkResult(Maybe<Running>),Fail{(1,"intentional window scope termination")})
    case _:V.Action.pure(Maybe<Running>,running(pair,camera))

def continued(camera:Maybe<Create.Camera>,renderer:Win.Renderer,state:SceneApp.State,snapshot:V.WindowSnapshot,+mode:Mode,mapped:Bool) -> V.Action(Maybe<Running>):
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

def polled_ready(pair:Maybe<Create.Camera> & V.WindowSnapshot,renderer:Win.Renderer,state:SceneApp.State,mode:Mode) -> V.Action(Maybe<Running>):
  (camera,V.WindowSnapshot{width,height,+mapped,focused,captured,events}) = pair
  continued(camera,renderer,state,V.WindowSnapshot{width,height,mapped,focused,captured,events},mode,mapped)

def polled(pair:Win.Renderer & V.WindowSnapshot,state:SceneApp.State,camera:Create.Camera,mode:Mode) -> V.Action(Maybe<Running>):
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

def initialized(mode:Mode,state:SceneApp.State) -> V.Action(SceneApp.State):
  match mode:
    case Replay{}:
      do V.Action<SceneApp.State>:
        state : SceneApp.State <- SceneApp.advance(SceneApp.retain(state))
        SceneApp.replay_ready(state)
    case _:V.Action.pure(SceneApp.State,SceneApp.retain(state))

def run_compiled(compiled:Create.Compiled,core:Modules.Core<Scene.Application()>,input:Modules.Input,render:Modules.Render,entry:V.Entry,+mode:Mode) -> V.Action(Unit):
  Create.Compiled{seeds,geometry} = compiled
  Modules.Core{start} = core
  Modules.Input{initial} = input
  Modules.Render{open} = render
  do V.Action<Unit>:
    renderer : Win.Renderer <- open(entry,geometry)
    renderer : Win.Renderer <- Input.enabled(is_replay(mode),renderer)
    app : Scene.Application() <- V.Action.lift(Scene.Application(),start(seeds))
    now : Nat <- V.Action.lift(Nat,IO.now())
    state : SceneApp.State <- SceneApp.observed(Observe.snapshot(app,I.Fresh{}),[],1,Time.start(now),Draw.DrawList{[]},[])
    state : SceneApp.State <- initialized(mode,state)
    loop(U32.to_nat(4294967295),Some{Running{renderer,state,initial(Unit{})}},mode)

def run(modules:Modules.Registration<Scene.Application()>,entry:V.Entry,mode:Mode) -> V.Action(Unit):
  Modules.Registration{core,input,Modules.Assets{load},render} = modules
  do V.Action<Unit>:
    compiled:Create.Compiled <- Modules.compile(Create.compile(load(Unit{})))
    run_compiled(compiled,core,input,render,entry,mode)

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
    scoped : V.VkResult(Unit) & U32 <- Scope.with(Unit,entry => run(Recipe.defaults(),entry,selected))
    finished(selected,scoped)
