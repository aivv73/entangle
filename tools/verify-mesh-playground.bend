import ../src/content.bend as F
import ../deps/bend-vulkan/tools/verification.bend as Native
import ../src/scene-render.bend as Render
import ../examples/scene-render.bend as RenderCheck
import ../deps/bend-vulkan/Vulkan.bend as V
import ./mesh-topology.bend as Topology
import ../src/mesh-evidence.bend as Evidence
import Base
import ../src/mesh-playground.bend as Play
import ../src/mesh-control.bend as Control
import ../src/mesh-observe.bend as Observe
import ../src/scene-observe.bend as Old
import ../src/scene-schema.bend as D
import ../src/creation.bend as Create
import ../src/components.bend as C
import ../examples/mesh-playground-content.bend as Content
import ../examples/scene.bend as Check
import ./verify-creation.bend as Creation
import ../deps/bendvy/src/ecs/inspector.bend as I

def observed(pair:Play.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Old.Snapshot>)) -> IO(Play.Application() & List<&2,Old.Row>):
  match pair:
    case (app,(_,Done{Old.Snapshot{+live,+admitted,exhausted,clean,+rows}})):
      do IO<Play.Application() & List<&2,Old.Row>>:
        Check.require(exhausted && clean && Check.same(live,admitted) && Check.distinct(live) && Nat.is_eq(List.length(&2,Old.Row,rows),4n),"Mesh bootstrap identity/publication differs")
        return (app,rows)
    case _:IO.die(Play.Application() & List<&2,Old.Row>,1,"Mesh inspector refused")

def snapshot(app:Play.Application()) -> IO(Play.Application() & List<&2,Old.Row>):observed(Observe.snapshot(app,I.Fresh{}))

def unchanged(a:List<&2,Old.Row>,b:List<&2,Old.Row>) -> Bool:
  match a b:
    case [],[]:True{}
    case Old.Row{h,t,C.MeshRef{id}} <> xs,Old.Row{j,u,C.MeshRef{jd}} <> ys:
      Check.same([h],[j]) && Check.transform_equal(t,u) && U32.is_eq(id,jd) && unchanged(xs,ys)
    case _,_:False{}

def selective(a:List<&2,Old.Row>,b:List<&2,Old.Row>) -> Bool:
  match a b:
    case Old.Row{h,t,C.MeshRef{id}} <> xs,Old.Row{j,u,C.MeshRef{jd}} <> ys:
      Check.same([h],[j]) && U32.is_eq(id,jd) && Bool.not(Check.transform_equal(t,u)) && unchanged(xs,ys)
    case _,_:False{}

def advance(n:Nat,app:Play.Application()) -> IO(Play.Application()):
  match n:
    case 0n:IO.pure(Play.Application(),app)
    case 1n+rest:
      do IO<Play.Application()>:
        app:Play.Application() <- Play.tick(app)
        advance(rest,app)

def check_stopped(+rows:List<&2,Old.Row>,pair:Play.Application() & List<&2,Old.Row>) -> IO(Unit):
  (app,later) = pair
  do IO<Unit>:
    Check.require(unchanged(rows,later),"Release did not stop real ECS")
    IO.print("Mesh real ECS bootstrap=4 complete; retained handle movement=selective; static identities/transforms=preserved; release=stable")

def stopped(+baseline:List<&2,Old.Row>,pair:Play.Application() & List<&2,Old.Row>) -> IO(Unit):
  (app,+rows) = pair
  do IO<Unit>:
    Check.require(selective(baseline,rows),"Player did not move selectively in real ECS")
    app:Play.Application() <- advance(4n,Play.update(Control.intent(106,False{}),app))
    stopped_pair:Play.Application() & List<&2,Old.Row> <- snapshot(app)
    check_stopped(rows,stopped_pair)

def moving(pair:Play.Application() & List<&2,Old.Row>) -> IO(Unit):
  (app,rows) = pair
  do IO<Unit>:
    app:Play.Application() <- advance(4n,Play.update(Control.intent(106,True{}),app))
    later:Play.Application() & List<&2,Old.Row> <- snapshot(app)
    stopped(rows,later)


def initial_rows(+seeds:List<&2,Create.Seed>,pair:Play.Application() & List<&2,Old.Row>) -> IO(Play.Application() & List<&2,Old.Row>):
  (app,+rows) = pair
  do IO<Play.Application() & List<&2,Old.Row>>:
    Check.require(Creation.rows_equal(rows,seeds),"Bootstrap changed content transforms or mesh order")
    return (app,rows)

def run(compiled:Create.Compiled) -> IO(Unit):
  Create.Compiled{+seeds,_} = compiled
  do IO<Unit>:
    app:Play.Application() <- Play.create(seeds)
    first:Play.Application() & List<&2,Old.Row> <- snapshot(app)
    first:Play.Application() & List<&2,Old.Row> <- initial_rows(seeds,first)
    moving(first)
type Action is Data:
  Hold{code:U32,down:Bool}
  Active{value:Bool}
  Ticks{count:Nat}
  Stable{count:Nat}
  Changed{count:Nat}
  Origin{}

def within(transform:C.Transform) -> Bool:
  C.Transform{C.Vec3{+x,+y,+z},_,_} = transform
  F32.is_ge(x,F32.neg(3.0)) && F32.is_le(x,3.0) && F32.is_ge(y,F32.neg(0.2)) && F32.is_le(y,2.5) && F32.is_ge(z,F32.neg(3.0)) && F32.is_le(z,3.0)

def invariant_player(h:Control.Handle(),j:Control.Handle(),mesh:C.MeshRef,id:U32,r:C.Quat,s:C.Vec3,+t:C.Transform) -> Bool:
  C.MeshRef{expected} = mesh
  C.Transform{_,u,v} = t
  Check.same([h],[j]) && U32.is_eq(expected,id) && Check.transform_equal(C.Transform{C.Vec3{0.0,0.0,0.0},r,s},C.Transform{C.Vec3{0.0,0.0,0.0},u,v}) && within(t)


def invariant(baseline:List<&2,Old.Row>,current:List<&2,Old.Row>) -> Bool:
  match baseline current:
    case Old.Row{h,C.Transform{_,r,s},m} <> rest,Old.Row{j,+t,C.MeshRef{id}} <> tail:
      invariant_player(h,j,m,id,r,s,t) && unchanged(rest,tail)
    case _,_:False{}


def tick_checked(+baseline:List<&2,Old.Row>,pair:Play.Application() & List<&2,Old.Row>) -> IO(Play.Application() & List<&2,Old.Row>):
  (app,+rows) = pair
  do IO<Play.Application() & List<&2,Old.Row>>:
    Check.require(invariant(baseline,rows),"Real tick changed a static entity, identity, mesh, player pose or bounds")
    return (app,rows)

def step_continue(next:Play.Application() -> IO(Play.Application() & List<&2,Old.Row>),pair:Play.Application() & List<&2,Old.Row>) -> IO(Play.Application() & List<&2,Old.Row>):
  (app,_) = pair
  next(app)

def checked_steps(n:Nat,+baseline:List<&2,Old.Row>,app:Play.Application()) -> IO(Play.Application() & List<&2,Old.Row>):
  match n:
    case 0n:snapshot(app)
    case 1n+rest:
      do IO<Play.Application() & List<&2,Old.Row>>:
        app:Play.Application() <- Play.tick(app)
        pair:Play.Application() & List<&2,Old.Row> <- snapshot(app)
        next:Play.Application() & List<&2,Old.Row> <- tick_checked(baseline,pair)
        step_continue(checked_steps(rest,baseline),next)

def action_result(+kind:U32,+before:List<&2,Old.Row>,+baseline:List<&2,Old.Row>,pair:Play.Application() & List<&2,Old.Row>) -> IO(Play.Application() & List<&2,Old.Row>):
  (app,+after) = pair
  do IO<Play.Application() & List<&2,Old.Row>>:
    Check.require(Bool.pick(Bool,U32.is_eq(kind,1),unchanged(before,after),Bool.pick(Bool,U32.is_eq(kind,2),selective(before,after),unchanged(baseline,after))),"Held/release/opposite/reset property failed in real ECS")
    return (app,after)

def apply_action(action:Action,+baseline:List<&2,Old.Row>,pair:Play.Application() & List<&2,Old.Row>) -> IO(Play.Application() & List<&2,Old.Row>):
  match action pair:
    case Hold{+code,+down}, (app,+rows):IO.pure(Play.Application() & List<&2,Old.Row>,(Play.update(Control.intent(code,down),app),rows))
    case Active{active}, (app,+rows):IO.pure(Play.Application() & List<&2,Old.Row>,(Play.visible(active,app),rows))
    case Ticks{n}, (app,+rows):checked_steps(n,baseline,app)
    case Stable{n}, (app,+rows):
      do IO<Play.Application() & List<&2,Old.Row>>:
        after:Play.Application() & List<&2,Old.Row> <- checked_steps(n,baseline,app)
        action_result(1,rows,baseline,after)
    case Changed{n}, (app,+rows):
      do IO<Play.Application() & List<&2,Old.Row>>:
        after:Play.Application() & List<&2,Old.Row> <- checked_steps(n,baseline,app)
        action_result(2,rows,baseline,after)
    case Origin{}, (app,+rows):action_result(0,rows,baseline,(app,rows))

def result_rows(pair:Play.Application() & List<&2,Old.Row>) -> IO(String):
  (_,rows) = pair
  IO.pure(String,Evidence.rows(rows))


def actions(xs:List<&2,Action>,+baseline:List<&2,Old.Row>,pair:Play.Application() & List<&2,Old.Row>) -> IO(String):
  match xs:
    case []:result_rows(pair)
    case action <> rest:
      do IO<String>:
        next:Play.Application() & List<&2,Old.Row> <- apply_action(action,baseline,pair)
        actions(rest,baseline,next)


def script() -> List<&2,Action>:
  [Hold{106,True{}},Changed{4n},Hold{106,True{}},Changed{2n},Hold{108,True{}},Stable{4n},Hold{106,False{}},Changed{2n},Hold{108,False{}},Stable{4n},
   Hold{32,True{}},Ticks{0n},Hold{32,False{}},Ticks{0n},Ticks{1n},Origin{},Stable{3n},
   Hold{105,True{}},Changed{2n},Hold{107,True{}},Stable{2n},Hold{105,False{}},Changed{2n},Hold{107,False{}},Stable{2n},
   Hold{117,True{}},Changed{2n},Hold{111,True{}},Stable{2n},Hold{117,False{}},Changed{2n},Hold{111,False{}},Stable{2n},
   Hold{32,True{}},Hold{106,True{}},Ticks{0n},Ticks{1n},Origin{},Stable{4n},Hold{106,True{}},Changed{2n},Active{False{}},Stable{4n},Active{True{}},Stable{4n},
   Hold{108,True{}},Hold{117,True{}},Hold{107,True{}},Ticks{200n},Stable{4n},Hold{32,True{}},Ticks{1n},Origin{},Stable{4n}]

def replay_started(pair:Play.Application() & List<&2,Old.Row>) -> IO(String):
  (app,+rows) = pair
  actions(script(),rows,(app,rows))

def replay(+seeds:List<&2,Create.Seed>) -> IO(String):
  do IO<String>:
    app:Play.Application() <- Play.create(seeds)
    pair:Play.Application() & List<&2,Old.Row> <- snapshot(app)
    pair:Play.Application() & List<&2,Old.Row> <- initial_rows(seeds,pair)
    replay_started(pair)

def topology() -> IO(Unit):
  do IO<Unit>:
    Check.require(Topology.valid(Content.octahedron()) && Topology.valid(Content.tetrahedron()) && Topology.valid(Content.prism()) && Topology.valid(Content.platform()),"Actual mesh topology is not closed, outward, nondegenerate and connected")
    IO.print("Actual meshes: closed opposite edge incidence, distinct nondegenerate outward faces, connected vertices.")

def shape_counts(mesh:F.Mesh,vertices:Nat,triangles:Nat) -> Bool:
  F.Mesh{vs,indices} = mesh
  Nat.is_eq(List.length(&2,F.Vertex,vs),vertices) && Nat.is_eq(List.length(&2,U32,indices),Nat.mul(triangles,3n))

def ranges(geometry:Create.Geometry) -> Bool:
  match geometry:
    case Create.Geometry{_,_,[Create.Range{7,0,24},Create.Range{8,24,12},Create.Range{9,36,24},Create.Range{10,60,36}]}:True{}
    case _:False{}

def retained_unchanged(+later:List<&2,Old.Row>,pair:Play.Application() & List<&2,Old.Row>) -> IO(Unit):
  (_,rows) = pair
  Check.require(unchanged(later,rows),"Rendering retained earlier draws mutated later authoritative world")

def retained_render(+geometry:Create.Geometry,+first:List<&2,Old.Row>,pair:Play.Application() & List<&2,Old.Row>) -> IO(Unit):
  (app,+later) = pair
  do IO<Unit>:
    a:V.VkResult(Render.Readback) <- Creation.render_geometry(geometry,Creation.draws(first),False{})
    +a:Render.Readback <- V.or_exit(Render.Readback,a)
    b:V.VkResult(Render.Readback) <- Creation.render_geometry(geometry,Creation.draws(first),False{})
    b:Render.Readback <- V.or_exit(Render.Readback,b)
    Check.require(RenderCheck.image_equal(a,b),"Retained mesh replay changed exact pixels")
    current:V.VkResult(Render.Readback) <- Creation.render_geometry(geometry,Creation.draws(later),False{})
    current:Render.Readback <- V.or_exit(Render.Readback,current)
    Check.require(Bool.not(RenderCheck.image_equal(a,current)),"Selective real ECS motion did not change current render")
    final:Play.Application() & List<&2,Old.Row> <- snapshot(app)
    retained_unchanged(later,final)
    RenderCheck.no_live()
    IO.print("Actual retained mesh rendering replayed exact pixels after selective ECS motion; later world remained bit-exact; live Vulkan objects=0.")

def retained_started(geometry:Create.Geometry,pair:Play.Application() & List<&2,Old.Row>) -> IO(Unit):
  (app,first) = pair
  do IO<Unit>:
    app:Play.Application() <- advance(4n,Play.update(Control.intent(106,True{}),app))
    later:Play.Application() & List<&2,Old.Row> <- snapshot(app)
    retained_render(geometry,first,later)

def retained(seeds:List<&2,Create.Seed>,geometry:Create.Geometry) -> IO(Unit):
  do IO<Unit>:
    app:Play.Application() <- Play.create(seeds)
    first:Play.Application() & List<&2,Old.Row> <- snapshot(app)
    retained_started(geometry,first)

def verified(compiled:Create.Compiled) -> IO(Unit):
  Create.Compiled{+seeds,+geometry} = compiled
  do IO<Unit>:
    Check.require(Create.geometry_valid(geometry) && ranges(geometry) && shape_counts(Content.octahedron(),6n,8n) && shape_counts(Content.tetrahedron(),4n,4n) && shape_counts(Content.prism(),6n,8n) && shape_counts(Content.platform(),8n,12n),"Compiled geometry invalid")
    +first:String <- replay(seeds)
    second:String <- replay(seeds)
    Check.require(String.eq(first,second),"Real ECS replay changed full identities or bits")
    retained(seeds,geometry)
    IO.print("Real ECS per-tick invariants and deterministic replay passed: held, repeat, release, opposites on all axes, zero-step pending reset, one-shot reset, focus clear, bounds, static transforms/identities/mesh and player rotation/scale.")

def native() -> IO(Unit):
  do IO<Unit>:
    topology()
    +compiled:Create.Compiled <- Creation.compiled(Create.compile(Content.scene()))
    run(compiled)
    verified(compiled)

def main_args(args:List<String>) -> IO(Unit):
  match args:
    case [_,"native"]:native()
    case _:
      do IO<Unit>:
        Native.command("bend",["tools/verify-mesh-playground.bend","-o","build/verify-mesh-playground"])
        Native.command("./build/verify-mesh-playground",["native"])

def main() -> IO(Unit):
  do IO<Unit>:
    args:List<String> <- IO.args()
    main_args(args)
