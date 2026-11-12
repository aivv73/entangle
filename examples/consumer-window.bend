import Base
import ./courier-state.bend as Game
import ./consumer-world.bend as World
import ./consumer-content.bend as Content
import ../src/creation.bend as Create
import ../src/scene-window.bend as Win
import ../src/scene-observe.bend as Observe
import ../src/scene-draw.bend as Draw
import ../src/scene-schema.bend as D
import ../src/scene.bend as Scene
import ../deps/bendvy/src/ecs/world.bend as W
import ../src/input.bend as Input
import ../src/error.bend as Error
import ../src/app.bend as Scope
import ../deps/bendvy/src/ecs/inspector.bend as I
import ../deps/bend-vulkan/Vulkan.bend as V

type Consumer is Data:
  Viewer{}
  Courier{}

type Running is Type:
  Running{renderer:Win.Renderer,world:World.World,state:Game.State,camera:Create.Camera}

def title(kind:Consumer) -> String:
  match kind:
    case Viewer{}:"Entangle model viewer | WASD orbit | QE zoom | R reset | Esc"
    case Courier{}:"Energy courier | IJKL move | Space collect/deliver | X restart | WASD QE camera | Esc"

def changed(kind:Consumer,code:U32,state:Game.State) -> Game.State:
  match kind:
    case Viewer{}:state
    case Courier{}:Game.key(code,state)

def events(+kind:Consumer,values:List<Event>,state:Game.State,camera:Maybe<Create.Camera>) -> Game.State & Maybe<Create.Camera>:
  match values camera:
    case _ None{}:(state,None{})
    case [] camera:(state,camera)
    case Close{} <> _ _:(state,None{})
    case Key{27,True{}} <> _ _:(state,None{})
    case Key{+code,True{}} <> rest Some{camera}:events(kind,rest,changed(kind,code,state),Some{Input.key(code,camera)})
    case _ <> rest camera:events(kind,rest,state,camera)

def published(kind:Consumer,state:Game.State,world:World.World) -> IO(World.World):
  match kind:
    case Viewer{}:IO.pure(World.World,world)
    case Courier{}:World.publish(state,world)

def update(same:Bool,kind:Consumer,state:Game.State,world:World.World) -> IO(World.World):
  match same:
    case True{}:IO.pure(World.World,world)
    case False{}:published(kind,state,world)

def log(kind:Consumer,+state:Game.State) -> IO(Unit):
  match kind state:
    case Courier{} Game.State{x,z,p}:IO.print("courier-state " ++ U32.show(x) ++ " " ++ U32.show(z) ++ " " ++ Game.label(p))
    case _ _:IO.pure(Unit,Unit{})

def drawn(renderer:Win.Renderer,handles:List<&2,W.Handle<D.Schema>>,state:Game.State,+camera:Create.Camera,snapshot:V.WindowSnapshot,pair:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Draw.DrawList>)) -> V.Action(Maybe<Running>):
  match pair:
    case (app,(_,Done{list})):
      do V.Action<Maybe<Running>>:
        rendered:Win.Renderer & Result<&2,&2,Win.InputError,Unit> <- Win.frame(renderer,snapshot,w => h => Create.view(camera,w,h),list)
        renderer:Win.Renderer <- Error.owner(Win.Renderer,Win.InputError,Unit,rendered,"Consumer frame rejected")
        return Some{Running{renderer,World.World{app,handles},state,camera}}
    case _:IO.pure(V.VkResult(Maybe<Running>),Fail{(1,"Consumer drawing extraction refused")})


def ready(renderer:Win.Renderer,world:World.World,state:Game.State,camera:Create.Camera,snapshot:V.WindowSnapshot) -> V.Action(Maybe<Running>):
  World.World{app,handles} = world
  drawn(renderer,handles,state,camera,snapshot,Observe.draw_list(app,I.Fresh{}))

def input(+kind:Consumer,+old:Game.State,renderer:Win.Renderer,world:World.World,snapshot:V.WindowSnapshot,result:Game.State & Maybe<Create.Camera>) -> V.Action(Maybe<Running>):
  match result:
    case (_,None{}):
      do V.Action<Maybe<Running>>:
        Win.close(renderer)
        return None{}
    case (+state,Some{camera}):
      do V.Action<Maybe<Running>>:
        V.Action.lift(Unit,Bool.pick(IO(Unit),Game.equal(old,state),IO.pure(Unit,Unit{}),log(kind,state)))
        world:World.World <- V.Action.lift(World.World,update(Game.equal(old,state),kind,state,world))
        ready(renderer,world,state,camera,snapshot)

def poll(+kind:Consumer,world:World.World,+state:Game.State,camera:Create.Camera,pair:Win.Renderer & V.WindowSnapshot) -> V.Action(Maybe<Running>):
  (renderer,V.WindowSnapshot{w,h,mapped,focused,captured,values}) = pair
  input(kind,state,renderer,world,V.WindowSnapshot{w,h,mapped,focused,captured,[]},events(kind,values,state,Some{camera}))

def loop(fuel:Nat,+kind:Consumer,running:Maybe<Running>) -> V.Action(Unit):
  match fuel running:
    case _ None{}:V.Action.pure(Unit,Unit{})
    case 0n Some{Running{renderer,_,_,_}}:Win.close(renderer)
    case 1n+rest Some{Running{renderer,world,state,camera}}:
      do V.Action<Unit>:
        pair:Win.Renderer & V.WindowSnapshot <- Win.poll(renderer)
        next:Maybe<Running> <- poll(kind,world,state,camera,pair)
        V.Action.lift(Unit,IO.sleep(15))
        loop(rest,kind,next)

def run(entry:V.Entry,+kind:Consumer,compiled:Create.Compiled) -> V.Action(Unit):
  Create.Compiled{seeds,geometry} = compiled
  do V.Action<Unit>:
    world:World.World <- V.Action.lift(World.World,World.create(seeds))
    renderer:Win.Renderer <- Win.open(entry,title(kind),geometry)
    loop(U32.to_nat(4294967295),kind,Some{Running{renderer,world,Game.initial(),Create.default_camera()}})

def finished(pair:V.VkResult(Unit) & U32) -> IO(Unit):
  (result,count) = pair
  do IO<Unit>:
    V.or_exit(Unit,result)
    checked:V.VkResult(Unit) <- Error.require(U32.is_zero(count),"Consumer window leaked Vulkan objects")
    V.or_exit(Unit,checked)
    IO.print("Consumer window closed; live Vulkan objects: 0")

def open(kind:Consumer,scene:Create.Scene) -> IO(Unit):
  do IO<Unit>:
    compiled:Create.Compiled <- Content.compiled(Create.compile(scene))
    result:V.VkResult(Unit) & U32 <- Scope.with(Unit,entry => run(entry,kind,compiled))
    finished(result)
