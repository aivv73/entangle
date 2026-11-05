import ../src/mesh-control.bend as Control
import Base
import ../src/mesh-evidence.bend as Evidence
import ../src/scene-observe.bend as Old
import ./mesh-playground-content.bend as Content
import ../src/creation.bend as Create
import ../src/mesh-playground.bend as Play
import ../src/mesh-observe.bend as Observe
import ../src/scene-draw.bend as Draw
import ../src/scene-window.bend as Win
import ../src/scene-schema.bend as D
import ../src/app.bend as Scope
import ../src/error.bend as Error
import ../src/time.bend as Time
import ../deps/bendvy/src/ecs/inspector.bend as I
import ../deps/bend-vulkan/Vulkan.bend as V

type Running is Type:
  Running{renderer:Win.Renderer,app:Play.Application(),inspector:I.Instance<D.Schema>,camera:Create.Camera,clock:Time.Clock,trace:Bool}

def trace_observed(pair:Play.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Old.Snapshot>)) -> IO(Play.Application()):
  match pair:
    case (app,(_,Done{Old.Snapshot{_,_,_,_,rows}})):
      do IO<Play.Application()>:
        IO.print("mesh-tick-state " ++ Evidence.rows(rows))
        return app
    case _:IO.die(Play.Application(),1,"Mesh tick evidence observation refused")

def trace_tick(enabled:Bool,app:Play.Application()) -> IO(Play.Application()):
  match enabled:
    case False{}:IO.pure(Play.Application(),app)
    case True{}:trace_observed(Observe.snapshot(app,I.Fresh{}))

def steps(n:Nat,app:Play.Application(),+trace:Bool) -> IO(Play.Application()):
  match n:
    case 0n:IO.pure(Play.Application(),app)
    case 1n+rest:
      do IO<Play.Application()>:
        Evidence.print(trace,"mesh-tick")
        app:Play.Application() <- Play.tick(app)
        app:Play.Application() <- trace_tick(trace,app)
        steps(rest,app,trace)

def drawing(renderer:Win.Renderer,snapshot:V.WindowSnapshot,+camera:Create.Camera,clock:Time.Clock,trace:Bool,pair:Play.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Draw.DrawList>)) -> V.Action(Maybe<Running>):
  match pair:
    case (app,(inspector,Done{draws})):
      do V.Action<Maybe<Running>>:
        rendered:Win.Renderer & Result<&2,&2,Win.InputError,Unit> <- Win.frame(renderer,snapshot,w => h => Create.view(camera,w,h),draws)
        renderer:Win.Renderer <- Error.owner(Win.Renderer,Win.InputError,Unit,rendered,"Mesh frame refused")
        return Some{Running{renderer,app,inspector,camera,clock,trace}}
    case _:IO.pure(V.VkResult(Maybe<Running>),Fail{(1,"Mesh drawing extraction refused")})

def extracted(renderer:Win.Renderer,snapshot:V.WindowSnapshot,+camera:Create.Camera,clock:Time.Clock,+trace:Bool,pair:Play.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Old.Snapshot>)) -> V.Action(Maybe<Running>):
  match pair:
    case (app,(inspector,Done{Old.Snapshot{_,_,_,_,+rows}})):
      do V.Action<Maybe<Running>>:
        V.Action.lift(Unit,Evidence.print(trace,"mesh-state " ++ Evidence.rows(rows)))
        drawing(renderer,snapshot,camera,clock,trace,Observe.draw_list(app,inspector))
    case _:IO.pure(V.VkResult(Maybe<Running>),Fail{(1,"Mesh extraction refused")})

def scheduled(renderer:Win.Renderer,app:Play.Application(),inspector:I.Instance<D.Schema>,camera:Create.Camera,snapshot:V.WindowSnapshot,+trace:Bool,batch:Time.Batch) -> V.Action(Maybe<Running>):
  Time.Batch{clock,+n,_} = batch
  do V.Action<Maybe<Running>>:
    V.Action.lift(Unit,Evidence.print(trace,"mesh-step " ++ Nat.show(n)))
    app:Play.Application() <- V.Action.lift(Play.Application(),steps(n,app,trace))
    extracted(renderer,snapshot,camera,clock,trace,Observe.snapshot(app,inspector))

def simulate(renderer:Win.Renderer,app:Play.Application(),inspector:I.Instance<D.Schema>,camera:Create.Camera,clock:Time.Clock,snapshot:V.WindowSnapshot,+active:Bool,+trace:Bool,+now:Nat) -> V.Action(Maybe<Running>):
  batch:Time.Batch = Control.clock_batch(active,clock,now)
  scheduled(renderer,app,inspector,camera,snapshot,trace,batch)

def input_ready(renderer:Win.Renderer,inspector:I.Instance<D.Schema>,clock:Time.Clock,snapshot:V.WindowSnapshot,+active:Bool,+trace:Bool,pair:Play.Application() & Maybe<Create.Camera>) -> V.Action(Maybe<Running>):
  match pair:
    case (app,None{}):
      do V.Action<Maybe<Running>>:
        Win.close(renderer)
        return None{}
    case (app,Some{camera}):
      do V.Action<Maybe<Running>>:
        V.Action.lift(Unit,Evidence.print(trace,"mesh-active " ++ U32.show(Bool.to_u32(active))))
        now:Nat <- V.Action.lift(Nat,IO.now())
        simulate(renderer,Play.visible(active,app),inspector,camera,clock,snapshot,active,trace,now)

def native_events(renderer:Win.Renderer,app:Play.Application(),inspector:I.Instance<D.Schema>,camera:Create.Camera,clock:Time.Clock,+trace:Bool,+width:U32,+height:U32,+mapped:Bool,+focused:Bool,captured:Bool,pair:List<Event> & Bool) -> V.Action(Maybe<Running>):
  (events,+lost) = pair
  do V.Action<Maybe<Running>>:
    V.Action.lift(Unit,Evidence.print(trace && focused && lost,"mesh-focus-burst-cleared"))
    events:List<Event> <- V.Action.lift(List<Event>,Evidence.events(trace,events))
    input_ready(renderer,inspector,clock,V.WindowSnapshot{width,height,mapped,focused,captured,[]},mapped && focused && Bool.not(lost),trace,Play.input(events,app,Some{camera}))

def polled(app:Play.Application(),inspector:I.Instance<D.Schema>,camera:Create.Camera,clock:Time.Clock,+trace:Bool,pair:Win.Renderer & V.WindowSnapshot) -> V.Action(Maybe<Running>):
  (renderer,V.WindowSnapshot{width,height,+mapped,+focused,captured,events}) = pair
  native_events(renderer,app,inspector,camera,clock,trace,width,height,mapped,focused,captured,Control.focus_boundary(events))

def step(running:Running) -> V.Action(Maybe<Running>):
  Running{renderer,app,inspector,camera,clock,trace} = running
  do V.Action<Maybe<Running>>:
    pair:Win.Renderer & V.WindowSnapshot <- Win.poll(renderer)
    polled(app,inspector,camera,clock,trace,pair)

def loop(fuel:Nat,running:Maybe<Running>) -> V.Action(Unit):
  match fuel running:
    case _ None{}:V.Action.pure(Unit,Unit{})
    case 0n Some{Running{renderer,_,_,_,_,_}}:Win.close(renderer)
    case 1n+rest Some{running}:
      do V.Action<Unit>:
        next:Maybe<Running> <- step(running)
        V.Action.lift(Unit,IO.sleep(2))
        loop(rest,next)

def run(entry:V.Entry,compiled:Create.Compiled,trace:Bool) -> V.Action(Unit):
  Create.Compiled{seeds,geometry} = compiled
  do V.Action<Unit>:
    app:Play.Application() <- V.Action.lift(Play.Application(),Play.create(seeds))
    renderer:Win.Renderer <- Win.open(entry,"Mesh playground | IJKL UO move | Space reset | WASD QE camera | R reset | Esc",geometry)
    now:Nat <- V.Action.lift(Nat,IO.now())
    loop(U32.to_nat(4294967295),Some{Running{renderer,app,I.Fresh{},Create.default_camera(),Time.start(now),trace}})

def compiled(result:Result<&2,&2,Create.Error,Create.Compiled>) -> IO(Create.Compiled):
  match result:
    case Done{value}:IO.pure(Create.Compiled,value)
    case _:IO.die(Create.Compiled,1,"Mesh content refused")

def finished(pair:V.VkResult(Unit) & U32) -> IO(Unit):
  (result,count) = pair
  do IO<Unit>:
    V.or_exit(Unit,result)
    checked:V.VkResult(Unit) <- Error.require(U32.is_zero(count),"Mesh window leaked Vulkan objects")
    V.or_exit(Unit,checked)
    IO.print("Mesh playground closed; live Vulkan objects: 0")

def tracing(value:Result<&1,&1,U32 & String,String>) -> Bool:
  match value:
    case Done{"1"}:True{}
    case _:False{}

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Orange octahedron: hold I/K (-Z/+Z), J/L (-X/+X), U/O (+Y/-Y). Space resets player and stops. WASD orbit, QE zoom, R resets camera. Escape or Close exits.")
    compiled:Create.Compiled <- compiled(Create.compile(Content.scene()))
    env:Result<&1,&1,U32 & String,String> <- IO.get_env("ENTANGLE_MESH_EVIDENCE")
    result:V.VkResult(Unit) & U32 <- Scope.with(Unit,entry => run(entry,compiled,tracing(env)))
    finished(result)
