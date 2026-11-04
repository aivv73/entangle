import ../src/content.bend as F
import Base
import ../src/creation.bend as Create
import ../src/components.bend as C
import ../src/scene.bend as Scene
import ../src/scene-observe.bend as Observe
import ../src/scene-schema.bend as D
import ../src/scene-draw.bend as Draw
import ../src/scene-matrix.bend as M
import ../src/scene-step.bend as Step
import ../src/scene-render.bend as R
import ../src/error.bend as Error
import ../src/input.bend as Input
import ../examples/scene.bend as ECS
import ../examples/scene-render.bend as Render
import ../deps/bendvy/src/ecs/inspector.bend as I
import ../deps/bend-vulkan/Vulkan.bend as V

def vertices() -> List<&2,F.Vertex>:
  [F.Vertex{C.Vec3{F32.neg(0.6),F32.neg(0.6),0.25},C.Vec3{1.0,1.0,1.0}},
   F.Vertex{C.Vec3{0.6,F32.neg(0.6),0.25},C.Vec3{1.0,1.0,1.0}},
   F.Vertex{C.Vec3{0.6,0.6,0.25},C.Vec3{1.0,1.0,1.0}},
   F.Vertex{C.Vec3{F32.neg(0.6),0.6,0.25},C.Vec3{1.0,1.0,1.0}}]

def transform(x:F32) -> C.Transform:
  C.Transform{C.Vec3{x,0.0,0.0},C.Quat{0.0,0.0,0.0,1.0},C.Vec3{1.0,1.0,1.0}}

def content(+white:Bool) -> Create.Scene:
  +triangle:F.Mesh = F.Mesh{vertices(),[0,1,2]}
  quad:F.Mesh = F.Mesh{vertices(),[0,1,2,2,3,0]}
  Create.Scene{[
    Create.Instance{triangle,Bool.pick(F.Material,white,F.white(),F.Basic{C.Vec3{1.0,0.0,0.0}}),transform(F32.neg(2.0))},
    Create.Instance{triangle,Bool.pick(F.Material,white,F.white(),F.Basic{C.Vec3{0.0,1.0,0.0}}),transform(0.0)},
    Create.Instance{quad,F.white(),transform(2.0)},
    Create.Instance{triangle,Bool.pick(F.Material,white,F.white(),F.Basic{C.Vec3{1.0,0.0,0.0}}),transform(F32.neg(2.0))}]}

def compiled(result:Result<&2,&2,Create.Error,Create.Compiled>) -> IO(Create.Compiled):
  match result:
    case Done{value}:IO.pure(Create.Compiled,value)
    case Fail{_}:IO.die(Create.Compiled,1,"Public scene compilation refused")

def move_seed(pair:C.Transform & Unit,mesh:C.MeshRef) -> Create.Seed:
  (transform,_) = pair
  Create.Seed{transform,mesh}

def move_once(seeds:List<&2,Create.Seed>) -> List<&2,Create.Seed>:
  match seeds:
    case []:[]
    case Create.Seed{transform,mesh} <> rest:move_seed(Step.step(Unit{},transform),mesh) <> move_once(rest)

def moved(+ticks:Nat,seeds:List<&2,Create.Seed>) -> List<&2,Create.Seed>:
  match ticks:
    case 0n:seeds
    case 1n+rest:moved(rest,move_once(seeds))

def rows_equal(rows:List<&2,Observe.Row>,seeds:List<&2,Create.Seed>) -> Bool:
  match rows seeds:
    case [], []:True{}
    case Observe.Row{_,t,C.MeshRef{id}} <> rest,Create.Seed{u,C.MeshRef{other}} <> tail:
      U32.is_eq(id,other) && Render.equal_bytes(R.reusable(M.matrix_words(M.model(t))),R.reusable(M.matrix_words(M.model(u)))) && rows_equal(rest,tail)
    case _,_:False{}

def draw_items(rows:List<&2,Observe.Row>) -> List<&2,Draw.DrawItem>:
  match rows:
    case []:[]
    case Observe.Row{_,t,m} <> rest:Draw.DrawItem{t,m} <> draw_items(rest)

def draws(rows:List<&2,Observe.Row>) -> Draw.DrawList:
  Draw.DrawList{draw_items(rows)}

def snapshot(+seeds:List<&2,Create.Seed>,tick:Nat,pair:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Observe.Snapshot>)) -> IO(Scene.Application() & Draw.DrawList):
  match pair:
    case (app,(_,Done{Observe.Snapshot{+live,+admitted,exhausted,clean,+rows}})):
      do IO<Scene.Application() & Draw.DrawList>:
        ECS.require(Nat.is_eq(List.length(&2,Observe.Row,rows),List.length(&2,Create.Seed,seeds)) && ECS.distinct(live) && ECS.same(live,admitted) && exhausted && clean && rows_equal(rows,moved(tick,seeds)),"Created ECS instances, publication or movement differs")
        return (app,draws(rows))
    case _:IO.die(Scene.Application() & Draw.DrawList,1,"Creation snapshot refused")

def camera() -> M.Mat4:
  M.Mat4{M.Vec4{0.25,0.0,0.0,0.0},M.Vec4{0.0,0.5,0.0,0.0},M.Vec4{0.0,0.0,0.125,0.0},M.Vec4{F32.neg(0.25),F32.neg(0.25),0.5,1.0}}

def colors(bytes:List<&2,U32>,+r:U32,+g:U32,+b:U32) -> U32:
  match bytes:
    case a <> c <> d <> _ <> rest:U32.add(Bool.to_u32(U32.is_eq(a,r) && U32.is_eq(c,g) && U32.is_eq(d,b)),colors(rest,r,g,b))
    case _:0

def frame(renderer:R.Renderer,list:Draw.DrawList) -> V.Action(R.Renderer & R.Readback):Render.frame(renderer,list)

def replayed(pair:R.Renderer & R.Readback,+first:R.Readback) -> V.Action(R.Readback):
  (renderer,second) = pair
  do V.Action<R.Readback>:
    Error.require(Render.image_equal(first,second),"Creation retained replay or rejection recovery changed pixels")
    return first

def replay(renderer:R.Renderer,+list:Draw.DrawList,+first:R.Readback) -> V.Action(R.Readback):
  do V.Action<R.Readback>:
    renderer:R.Renderer <- Render.reject_unknown(renderer)
    pair:R.Renderer & R.Readback <- frame(renderer,list)
    replayed(pair,first)

def image_colors(image:R.Readback) -> Bool:
  R.Readback{_,_,+rgba,_} = image
  U32.is_gt(colors(rgba,255,0,0),30) && U32.is_gt(colors(rgba,0,255,0),30) && U32.is_gt(colors(rgba,255,255,255),60)

def render_first(pair:R.Renderer & R.Readback,list:Draw.DrawList,check:Bool) -> V.Action(R.Readback):
  (renderer,+image) = pair
  do V.Action<R.Readback>:
    Error.require(Bool.not(check) || image_colors(image),"Creation color coverage missing")
    replay(renderer,list,image)

def render_geometry(geometry:Create.Geometry,+list:Draw.DrawList,check:Bool) -> V.Action(R.Readback):
  V.Entry.with(R.Readback,entry => do V.Action<R.Readback>:
    renderer:R.Renderer <- R.create(entry,R.Config{128,64,camera()},geometry)
    pair:R.Renderer & R.Readback <- frame(renderer,list)
    render_first(pair,list,check))

def compare_depth(tinted:R.Readback,white:R.Readback) -> IO(Unit):
  R.Readback{_,_,_,a} = tinted
  R.Readback{_,_,_,b} = white
  ECS.require(Render.equal_bytes(a,b),"Tint changed actual D32 geometry")

def return_lists(retained:Draw.DrawList,second:Scene.Application() & Draw.DrawList) -> IO(Draw.DrawList & Draw.DrawList):
  (_,list) = second
  IO.pure(Draw.DrawList & Draw.DrawList,(retained,list))

def list_pair(first:Scene.Application() & Draw.DrawList,seeds:List<&2,Create.Seed>) -> IO(Draw.DrawList & Draw.DrawList):
  (app,retained) = first
  do IO<Draw.DrawList & Draw.DrawList>:
    app:Scene.Application() <- Scene.tick(app)
    second:Scene.Application() & Draw.DrawList <- snapshot(seeds,2n,Observe.snapshot(app,I.Fresh{}))
    return_lists(retained,second)

def lists(seeds:List<&2,Create.Seed>) -> IO(Draw.DrawList & Draw.DrawList):
  +seeds = seeds
  do IO<Draw.DrawList & Draw.DrawList>:
    app:Scene.Application() <- Scene.create(seeds)
    app:Scene.Application() <- Scene.tick(app)
    first:Scene.Application() & Draw.DrawList <- snapshot(seeds,1n,Observe.snapshot(app,I.Fresh{}))
    list_pair(first,seeds)

def plan_ok(geometry:Create.Geometry) -> Bool:
  match geometry:
    case Create.Geometry{vs,is1,[Create.Range{7,0,3},Create.Range{8,3,3},Create.Range{9,6,6}]}:Nat.is_eq(List.length(&2,F.Vertex,vs),12n) && Nat.is_eq(List.length(&2,U32,is1),12n)
    case _:False{}

def geometry_depth(rgba:List<&2,U32>,depth:List<&2,U32>,+expected:U32) -> Bool:
  match rgba depth:
    case [],[]:True{}
    case +r <> +g <> +b <> _ <> rest,a <> c <> d <> e <> tail:
      (Bool.not(U32.is_eq(r,255) || U32.is_eq(g,255)) || U32.is_eq(Render.word(a,c,d,e),expected)) && geometry_depth(rest,tail,expected)
    case _,_:False{}

def exact_depth(image:R.Readback,expected:F32) -> IO(Unit):
  R.Readback{_,_,rgba,depth} = image
  ECS.require(geometry_depth(rgba,depth,F32.bits(expected)),"Rendered geometry D32 differs from exact expected plane")

def images(+geometry:Create.Geometry,white_geometry:Create.Geometry,pair:Draw.DrawList & Draw.DrawList,white_pair:Draw.DrawList & Draw.DrawList) -> IO(Unit):
  (+first,+second) = pair
  (white_first,_) = white_pair
  do IO<Unit>:
    tinted:V.VkResult(R.Readback) <- render_geometry(geometry,first,True{})
    +tinted:R.Readback <- V.or_exit(R.Readback,tinted)
    white:V.VkResult(R.Readback) <- render_geometry(white_geometry,white_first,False{})
    white:R.Readback <- V.or_exit(R.Readback,white)
    compare_depth(tinted,white)
    exact_depth(tinted,0.28125)
    later:V.VkResult(R.Readback) <- render_geometry(geometry,second,True{})
    +later:R.Readback <- V.or_exit(R.Readback,later)
    exact_depth(later,0.03125)
    ECS.require(Bool.not(Render.image_equal(tinted,later)),"Real ECS tick did not change rendered geometry")
    Render.no_live()
    IO.print("Public creation verified: 4 distinct ECS entities; 3 used pairs; shared pair reused; ranges=3,3,6; two ticks; D32=0.28125/0.03125; red/green/white pixels; tint depth=white depth; retained replay; rejection recovery; live Vulkan objects=0.")

def run(tinted:Create.Compiled,white:Create.Compiled) -> IO(Unit):
  Create.Compiled{+seeds,+geometry} = tinted
  Create.Compiled{white_seeds,white_geometry} = white
  do IO<Unit>:
    ECS.require(plan_ok(geometry),"Used pair order, sharing or packed ranges differ")
    pair:Draw.DrawList & Draw.DrawList <- lists(seeds)
    white_pair:Draw.DrawList & Draw.DrawList <- lists(white_seeds)
    images(geometry,white_geometry,pair,white_pair)

def empty_scene(instance:Bool) -> Create.Scene:
  Create.Scene{Bool.pick(List<&2,Create.Instance>,instance,[Create.Instance{F.Mesh{[],[]},F.white(),C.Transform.identity()}],[])}

def clear_depth(bytes:List<&2,U32>) -> Bool:
  match bytes:
    case []:True{}
    case 0 <> 0 <> 128 <> 63 <> rest:clear_depth(rest)
    case _:False{}

def empty_image(image:R.Readback) -> IO(Unit):
  R.Readback{w,h,rgba,depth} = image
  do IO<Unit>:
    ECS.require(U32.is_eq(colors(rgba,0,0,255),U32.mul(w,h)) && clear_depth(depth),"Absent geometry failed clear-only rendering")

def empty_render(geometry:Create.Geometry,pair:Draw.DrawList & Draw.DrawList) -> IO(Unit):
  (first,_) = pair
  do IO<Unit>:
    result:V.VkResult(R.Readback) <- render_geometry(geometry,first,False{})
    image:R.Readback <- V.or_exit(R.Readback,result)
    empty_image(image)
    Render.no_live()

def empty_compiled(compiled:Create.Compiled) -> IO(Unit):
  Create.Compiled{seeds,geometry} = compiled
  do IO<Unit>:
    pair:Draw.DrawList & Draw.DrawList <- lists(seeds)
    empty_render(geometry,pair)

def empty(instance:Bool) -> IO(Unit):
  do IO<Unit>:
    compiled:Create.Compiled <- compiled(Create.compile(empty_scene(instance)))
    empty_compiled(compiled)

def rejected(result:Result<&2,&2,Create.Error,Create.Compiled>) -> Bool:
  match result:
    case Fail{_}:True{}
    case Done{_}:False{}

def boundary_checks() -> IO(Unit):
  +bad:Create.Scene = Create.Scene{[Create.Instance{F.Mesh{vertices(),[0,1,8]},F.white(),C.Transform.identity()}]}
  +bad_tint:Create.Scene = Create.Scene{[Create.Instance{F.Mesh{vertices(),[0,1,2]},F.Basic{C.Vec3{1.01,0.0,0.0}},C.Transform.identity()}]}
  +bad_transform:Create.Scene = Create.Scene{[Create.Instance{F.Mesh{vertices(),[0,1,2]},F.white(),C.Transform{C.Vec3{0.0,0.0,0.0},C.Quat{0.0,0.0,0.0,0.0},C.Vec3{1.0,1.0,1.0}}}]}
  do IO<Unit>:
    ECS.require(rejected(Create.compile(bad)) && rejected(Create.compile(bad_tint)) && rejected(Create.compile(bad_transform)),"Creation boundary accepted invalid description")
    empty(False{})
    empty(True{})
    IO.print("Empty scene and empty-mesh ECS instance render clear-only with absent buffers; invalid index, tint and transform rejected.")

def camera_kept(camera:Create.Camera) -> Bool:
  match camera:
    case Create.Camera{C.Vec3{x,y,z},_,_,_,Create.Perspective{scale,near,far}}:
      F32.is_eq(x,2.0) && F32.is_eq(y,3.0) && F32.is_eq(z,4.0) && F32.is_eq(scale,2.0) && F32.is_eq(near,0.25) && F32.is_eq(far,32.0)

def camera_keys(codes:List<&2,U32>,+camera:Create.Camera) -> Bool:
  match codes:
    case []:True{}
    case code <> rest:camera_kept(Input.key(code,camera)) && camera_keys(rest,camera)

def some_view(value:Maybe<M.Mat4>) -> Bool:
  match value:
    case Some{_}:True{}
    case None{}:False{}

def camera_checks() -> IO(Unit):
  +camera:Create.Camera = Create.Camera{C.Vec3{2.0,3.0,4.0},0.8,0.3,9.0,Create.Perspective{2.0,0.25,32.0}}
  do IO<Unit>:
    ECS.require(camera_keys([97,100,119,115,113,101,114],camera) && some_view(Create.view(camera,640,480)) && Bool.not(some_view(Create.view(camera,0,480))),"Camera configuration, reset or zero-extent rejection differs")
    ECS.require(Bool.not(some_view(Create.view(Create.Camera{C.Vec3{0.0,0.0,0.0},0.0,0.0,1.0,Create.Perspective{1.0,2.0,1.0}},640,480))),"Invalid camera projection accepted")
    IO.print("Configured camera target and lens survive six controls and reset; configured view accepted; zero extent and invalid lens rejected.")

def main() -> IO(Unit):
  do IO<Unit>:
    tinted:Create.Compiled <- compiled(Create.compile(content(False{})))
    white:Create.Compiled <- compiled(Create.compile(content(True{})))
    run(tinted,white)
    boundary_checks()
    camera_checks()
