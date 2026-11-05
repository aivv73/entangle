import ../src/content.bend as F
import Base
import ../src/hierarchy.bend as Hierarchy
import ../src/creation.bend as Create
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
import ../src/input.bend as Camera
import ../src/time.bend as Time
import ../src/error.bend as Error
import ../deps/bend-vulkan/examples/window_scene.bend as Geometry
import ./scene.bend as Check
import ./scene-render.bend as Extract


type State is Type:
  State{app:Scene.Application(),inspector:I.Instance<D.Schema>,baseline:List<&2,Check.Identity>,rows:List<&2,Observe.Row>,draws:Draw.DrawList,retained:Draw.DrawList,saved:List<&2,Observe.Row>,tick:U32,clock:Time.Clock}

def vertices(words:List<U32>) -> List<&2,F.Vertex>:
  match words:
    case a <> b <> c <> r <> g <> b1 <> rest:
      F.Vertex{C.Vec3{M.float_word(a),M.float_word(b),M.float_word(c)},C.Vec3{M.float_word(r),M.float_word(g),M.float_word(b1)},F.UV{0.0,0.0},C.Vec3{0.0,0.0,1.0}} <> vertices(rest)
    case _:[]

def indices(words:List<U32>) -> List<&2,U32>:
  match words:
    case []:[]
    case x <> rest:x <> indices(rest)

def mesh() -> Create.Geometry:
  Create.Geometry{vertices(List.take(&1,U32,Geometry.vertices(),144n)),indices(List.take(&1,U32,Geometry.indices(),36n)),[Create.Range{7,0,36,None{}}]}

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

def view(camera:Create.Camera,+width:U32,+height:U32) -> Maybe<M.Mat4>:
  composed(Create.view(camera,width,height),width,height)

def fold(words:List<U32>,hash:U32) -> U32:
  match words:
    case []:hash
    case word <> rest:fold(rest,U32.mul(U32.xor(hash,word),16777619))

def digest(items:List<&2,Draw.DrawItem>,hash:U32) -> U32:
  match items:
    case []:hash
    case Draw.DrawItem{C.Transform{C.Vec3{x,y,z},C.Quat{a,b,c,d},C.Vec3{sx,sy,sz}},C.MeshRef{id}} <> rest:
      digest(rest,fold([F32.bits(x),F32.bits(y),F32.bits(z),F32.bits(a),F32.bits(b),F32.bits(c),F32.bits(d),F32.bits(sx),F32.bits(sy),F32.bits(sz),id],hash))
    case Draw.GlobalItem{global,C.MeshRef{id}} <> rest:digest(rest,fold(id <> M.matrix_words(Hierarchy.matrix(global)),hash))

def extracted(pair:Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList),+baseline:List<&2,Check.Identity>,+rows:List<&2,Observe.Row>,+tick:U32,clock:Time.Clock,retained:Draw.DrawList,saved:List<&2,Observe.Row>) -> V.Action(State):
  (app,(inspector,Draw.DrawList{+items})) = pair
  do V.Action<State>:
    Error.require(Check.drawing_equal(items,rows),"Window extraction changed ordered drawing bits")
    V.Action.lift(Unit,IO.print("window-tick=" ++ U32.show(tick) ++ " draws=100 ordered-bits=" ++ U32.show(digest(items,2166136261)) ++ " world/inspector=preserved"))
    return State{app,inspector,baseline,rows,Draw.DrawList{items},retained,saved,tick,clock}

def observed(pair:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Observe.Snapshot>),baseline:List<&2,Check.Identity>,+tick:U32,clock:Time.Clock,retained:Draw.DrawList,saved:List<&2,Observe.Row>) -> V.Action(State):
  match pair baseline:
    case (app,(inspector,Done{Observe.Snapshot{+live,+admitted,+exhausted,+clean,+rows}})), []:
      +identities = Check.identities(admitted,0)
      do V.Action<State>:
        V.Action.lift(Unit,Check.validate(tick,identities,Observe.Snapshot{live,admitted,exhausted,clean,rows}))
        pair : Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList) <- Extract.observe(app,inspector)
        extracted(pair,identities,rows,tick,clock,retained,saved)
    case (app,(inspector,Done{Observe.Snapshot{+live,+admitted,+exhausted,+clean,+rows}})), +identities:
      do V.Action<State>:
        V.Action.lift(Unit,Check.validate(tick,identities,Observe.Snapshot{live,admitted,exhausted,clean,rows}))
        pair : Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList) <- Extract.observe(app,inspector)
        extracted(pair,identities,rows,tick,clock,retained,saved)
    case _, _:IO.pure(V.VkResult(State),Fail{(1,"Window scene observation refused")})

def retain(state:State) -> State:
  State{app,inspector,baseline,+rows,+draws,retained,saved,tick,clock} = state
  State{app,inspector,baseline,rows,draws,draws,rows,tick,clock}

def advance(state:State) -> V.Action(State):
  State{app,inspector,baseline,+rows,Draw.DrawList{+items},Draw.DrawList{+held},+saved,+tick,clock} = state
  do V.Action<State>:
    Error.require(Check.drawing_equal(items,rows) && Check.drawing_equal(held,saved),"Retained original drawing bits changed")
    app : Scene.Application() <- V.Action.lift(Scene.Application(),Scene.tick(app))
    observed(Observe.snapshot(app,inspector),baseline,U32.inc(tick),clock,Draw.DrawList{held},saved)

def steps(remaining:Nat,state:State) -> V.Action(State):
  match remaining:
    case 0n:V.Action.pure(State,state)
    case 1n+rest:
      do V.Action<State>:
        state:State <- advance(state)
        steps(rest,state)

def schedule(state:State,now:Nat) -> State & Time.Batch:
  State{app,inspector,baseline,rows,draws,retained,saved,tick,clock} = state
  +batch = Time.poll(Time.defaults(),clock,now)
  (State{app,inspector,baseline,rows,draws,retained,saved,tick,Time.clock(batch)},batch)

def unchanged(draws:Draw.DrawList,rows:List<&2,Observe.Row>) -> Bool:
  Draw.DrawList{items} = draws
  Check.drawing_equal(items,rows)

def draw(state:State,renderer:Win.Renderer,snapshot:V.WindowSnapshot,+camera:Create.Camera,replay:Bool) -> V.Action(Win.Renderer & State):
  State{app,inspector,baseline,+rows,+draws,+retained,+saved,tick,clock} = state
  +list = Bool.pick(Draw.DrawList,replay,retained,draws)
  do V.Action<Win.Renderer & State>:
    Error.require(unchanged(draws,rows) && unchanged(retained,saved),"Window frame changed original or retained drawing bits")
    pair : Win.Renderer & Result<&2,&2,Win.InputError,Unit> <- Win.frame(renderer,snapshot,w => h => view(camera,w,h),list)
    renderer : Win.Renderer <- Error.owner(Win.Renderer,Win.InputError,Unit,pair,"Window drawing rejected")
    return (renderer,State{app,inspector,baseline,rows,draws,retained,saved,tick,clock})

def replay_ready(state:State) -> V.Action(State):
  State{app,inspector,baseline,+rows,+draws,+retained,+saved,tick,clock} = state
  do V.Action<State>:
    Error.require(unchanged(draws,rows) && unchanged(retained,saved),"Replay changed retained tick-one drawing")
    V.Action.lift(Unit,IO.print("replay-tick=1 world-tick=2 retained=exact"))
    return State{app,inspector,baseline,rows,draws,retained,saved,tick,clock}
