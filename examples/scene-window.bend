import Base
import ../tools/window-input-check.bend as Input
import ../src/scene-window.bend as Win
import ../src/scene-render.bend as R
import ../src/scene-matrix.bend as M
import ../src/scene-draw.bend as Draw
import ../src/components.bend as C
import ../src/scene.bend as Scene
import ../src/scene-observe.bend as Observe
import ../src/scene-schema.bend as D
import ../deps/bendvy/src/ecs/inspector.bend as I
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/examples/window_scene.bend as Camera
import ./scene.bend as Check
import ./scene-render.bend as Extract

type Mode is Data:Live{} Replay{} Terminal{}
type State is Type:
  State{app:Scene.Application(),inspector:I.Instance<D.Schema>,baseline:List<&2,Check.Identity>,rows:List<&2,Observe.Row>,draws:Draw.DrawList,retained:Draw.DrawList,saved:List<&2,Observe.Row>,tick:U32,due:Nat}

def vertices(words:List<U32>) -> List<&2,R.Vertex>:
  match words:
    case a <> b <> c <> r <> g <> b1 <> rest:
      R.Vertex{C.Vec3{M.float_word(a),M.float_word(b),M.float_word(c)},C.Vec3{M.float_word(r),M.float_word(g),M.float_word(b1)}} <> vertices(rest)
    case _:[]

def indices(words:List<U32>) -> List<&2,U32>:
  match words:
    case []:[]
    case x <> rest:x <> indices(rest)

def mesh() -> R.Mesh:
  R.Mesh{7,vertices(List.take(&1,U32,Camera.vertices(),144n)),indices(List.take(&1,U32,Camera.indices(),36n))}

def tick_one_framing(width:U32,height:U32) -> M.Mat4:
  tick_one_center_x : F32 = 50.5
  tick_one_center_y : F32 = 99.5
  tick_one_center_z : F32 = F32.neg(51.5)
  +s = (3.0 * F32.min(1.0,F32.div(U32.to_f32(width),U32.to_f32(height))) / 130.0 : F32)
  M.Mat4{M.Vec4{s,0.0,0.0,0.0},M.Vec4{0.0,s,0.0,0.0},M.Vec4{0.0,0.0,s,0.0},M.Vec4{F32.neg((s * tick_one_center_x : F32)),F32.neg((s * tick_one_center_y : F32)),F32.neg((s * tick_one_center_z : F32)),1.0}}

def composed(matrix:Maybe<M.Mat4>,width:U32,height:U32) -> Maybe<M.Mat4>:
  match matrix:
    case None{}:None{}
    case Some{camera}:Some{M.multiply(camera,tick_one_framing(width,height))}

def view(camera:Camera.Camera,+width:U32,+height:U32) -> Maybe<M.Mat4>:
  composed(M.from_words(Camera.matrix(camera,width,height)),width,height)

def fold(words:List<U32>,hash:U32) -> U32:
  match words:
    case []:hash
    case word <> rest:fold(rest,U32.mul(U32.xor(hash,word),16777619))

def digest(items:List<&2,Draw.DrawItem>,hash:U32) -> U32:
  match items:
    case []:hash
    case Draw.DrawItem{C.Transform{C.Vec3{x,y,z},C.Quat{a,b,c,d},C.Vec3{sx,sy,sz}},C.MeshRef{id}} <> rest:
      digest(rest,fold([F32.bits(x),F32.bits(y),F32.bits(z),F32.bits(a),F32.bits(b),F32.bits(c),F32.bits(d),F32.bits(sx),F32.bits(sy),F32.bits(sz),id],hash))

def extracted(pair:Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList),+baseline:List<&2,Check.Identity>,+rows:List<&2,Observe.Row>,+tick:U32,due:Nat,retained:Draw.DrawList,saved:List<&2,Observe.Row>) -> V.Action(State):
  (app,(inspector,Draw.DrawList{+items})) = pair
  do V.Action<State>:
    R.require(Check.drawing_equal(items,rows),"Window extraction changed ordered drawing bits")
    V.Action.lift(Unit,IO.print("window-tick=" ++ U32.show(tick) ++ " draws=100 ordered-bits=" ++ U32.show(digest(items,2166136261)) ++ " world/inspector=preserved"))
    return State{app,inspector,baseline,rows,Draw.DrawList{items},retained,saved,tick,due}

def observed(pair:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Observe.Snapshot>),baseline:List<&2,Check.Identity>,+tick:U32,due:Nat,retained:Draw.DrawList,saved:List<&2,Observe.Row>) -> V.Action(State):
  match pair baseline:
    case (app,(inspector,Done{Observe.Snapshot{+live,+admitted,+exhausted,+clean,+rows}})), []:
      +identities = Check.identities(admitted,0)
      do V.Action<State>:
        V.Action.lift(Unit,Check.validate(tick,identities,Observe.Snapshot{live,admitted,exhausted,clean,rows}))
        pair : Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList) <- Extract.observe(app,inspector)
        extracted(pair,identities,rows,tick,due,retained,saved)
    case (app,(inspector,Done{Observe.Snapshot{+live,+admitted,+exhausted,+clean,+rows}})), +identities:
      do V.Action<State>:
        V.Action.lift(Unit,Check.validate(tick,identities,Observe.Snapshot{live,admitted,exhausted,clean,rows}))
        pair : Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList) <- Extract.observe(app,inspector)
        extracted(pair,identities,rows,tick,due,retained,saved)
    case _, _:IO.pure(V.VkResult(State),Fail{(1,"Window scene observation refused")})

def retain(state:State) -> State:
  State{app,inspector,baseline,+rows,+draws,retained,saved,tick,due} = state
  State{app,inspector,baseline,rows,draws,draws,rows,tick,due}

def advance(state:State,now:Nat) -> V.Action(State):
  State{app,inspector,baseline,+rows,Draw.DrawList{+items},Draw.DrawList{+held},+saved,+tick,due} = state
  do V.Action<State>:
    R.require(Check.drawing_equal(items,rows) && Check.drawing_equal(held,saved),"Retained original drawing bits changed")
    app : Scene.Application() <- V.Action.lift(Scene.Application(),Scene.tick(app))
    observed(Observe.snapshot(app,inspector),baseline,U32.inc(tick),Nat.add(now,250n),Draw.DrawList{held},saved)

def scheduled(ready:Bool,mode:Mode,state:State,now:Nat,mapped:Bool) -> V.Action(State):
  match ready mode:
    case True{} Live{}:
      do V.Action<State>:
        V.Action.lift(Unit,IO.print(Bool.pick(String,mapped,"window-visible-tick","window-hidden-tick")))
        advance(state,now)
    case _ _:V.Action.pure(State,state)

def update(+mode:Mode,state:State,+now:Nat,mapped:Bool) -> V.Action(State):
  State{app,inspector,baseline,rows,draws,retained,saved,tick,+due} = state
  scheduled(Nat.is_ge(now,due),mode,State{app,inspector,baseline,rows,draws,retained,saved,tick,due},now,mapped)

def rendered(pair:Win.Renderer & Result<&2,&2,Win.InputError,Unit>) -> V.Action(Win.Renderer):
  match pair:
    case (renderer,Done{_}):V.Action.pure(Win.Renderer,renderer)
    case _:IO.pure(V.VkResult(Win.Renderer),Fail{(1,"Window drawing rejected")})

def is_replay(mode:Mode) -> Bool:
  match mode:
    case Replay{}:True{}
    case _:False{}

def unchanged(draws:Draw.DrawList,rows:List<&2,Observe.Row>) -> Bool:
  Draw.DrawList{items} = draws
  Check.drawing_equal(items,rows)

def draw(state:State,renderer:Win.Renderer,snapshot:V.WindowSnapshot,+camera:Camera.Camera,mode:Mode) -> V.Action(Win.Renderer & State):
  State{app,inspector,baseline,+rows,+draws,+retained,+saved,tick,due} = state
  +list = Bool.pick(Draw.DrawList,is_replay(mode),retained,draws)
  do V.Action<Win.Renderer & State>:
    R.require(unchanged(draws,rows) && unchanged(retained,saved),"Window frame changed original or retained drawing bits")
    pair : Win.Renderer & Result<&2,&2,Win.InputError,Unit> <- Win.frame(renderer,snapshot,w => h => view(camera,w,h),list)
    renderer : Win.Renderer <- rendered(pair)
    return (renderer,State{app,inspector,baseline,rows,draws,retained,saved,tick,due})

type Running is Type:Running{renderer:Win.Renderer,state:State,camera:Camera.Camera}

def running(pair:Win.Renderer & State,camera:Camera.Camera) -> Maybe<Running>:
  (renderer,state) = pair
  Some{Running{renderer,state,camera}}

def drawn(mode:Mode,pair:Win.Renderer & State,camera:Camera.Camera) -> V.Action(Maybe<Running>):
  match mode:
    case Terminal{}:IO.pure(V.VkResult(Maybe<Running>),Fail{(1,"intentional window scope termination")})
    case _:V.Action.pure(Maybe<Running>,running(pair,camera))

def continued(camera:Maybe<Camera.Camera>,renderer:Win.Renderer,state:State,snapshot:V.WindowSnapshot,+mode:Mode,mapped:Bool) -> V.Action(Maybe<Running>):
  match camera:
    case None{}:
      do V.Action<Maybe<Running>>:
        Win.close(renderer)
        return None{}
    case Some{+camera}:
      do V.Action<Maybe<Running>>:
        now : Nat <- V.Action.lift(Nat,IO.now())
        state : State <- update(mode,state,now,mapped)
        pair : Win.Renderer & State <- draw(state,renderer,snapshot,camera,mode)
        drawn(mode,pair,camera)

def polled(pair:Win.Renderer & V.WindowSnapshot,state:State,camera:Camera.Camera,mode:Mode) -> V.Action(Maybe<Running>):
  (renderer,V.WindowSnapshot{width,height,+mapped,focused,captured,events}) = pair
  continued(Camera.events(events,Some{camera}),renderer,state,V.WindowSnapshot{width,height,mapped,focused,captured,[]},mode,mapped)

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

def replay_ready(state:State) -> V.Action(State):
  State{app,inspector,baseline,+rows,+draws,+retained,+saved,tick,due} = state
  do V.Action<State>:
    R.require(unchanged(draws,rows) && unchanged(retained,saved),"Replay changed retained tick-one drawing")
    V.Action.lift(Unit,IO.print("replay-tick=1 world-tick=2 retained=exact"))
    return State{app,inspector,baseline,rows,draws,retained,saved,tick,due}

def initialized(mode:Mode,state:State,now:Nat) -> V.Action(State):
  match mode:
    case Replay{}:
      do V.Action<State>:
        state : State <- advance(retain(state),now)
        replay_ready(state)
    case _:V.Action.pure(State,retain(state))

def run(entry:V.Entry,+mode:Mode) -> V.Action(Unit):
  do V.Action<Unit>:
    renderer : Win.Renderer <- Win.open(entry,"Entangle ECS scene",mesh())
    renderer : Win.Renderer <- Input.enabled(is_replay(mode),renderer)
    app : Scene.Application() <- V.Action.lift(Scene.Application(),Scene.create())
    app : Scene.Application() <- V.Action.lift(Scene.Application(),Scene.tick(app))
    +now : Nat <- V.Action.lift(Nat,IO.now())
    state : State <- observed(Observe.snapshot(app,I.Fresh{}),[],1,Nat.add(now,250n),Draw.DrawList{[]},[])
    state : State <- initialized(mode,state,now)
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

def main() -> IO(Unit):
  do IO<Unit>:
    Input.bits()
    environment : Result<&1,&1,U32 & String,String> <- IO.get_env("ENTANGLE_WINDOW_MODE")
    +selected : Mode = mode(environment)
    result : V.VkResult(Unit) <- V.Entry.with(Unit,entry => run(entry,selected))
    live : V.VkResult(U32) <- V.debug_live_objects()
    count : U32 <- V.or_exit(U32,live)
    checked : V.VkResult(Unit) <- R.require(U32.is_zero(count),"Window leaked objects")
    V.or_exit(Unit,checked)
    completed(selected,result)
