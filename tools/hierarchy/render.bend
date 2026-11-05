import Base
import ./check.bend as Check
import ./drive.bend as Drive
import ./scenes.bend as Scenes
import ../../src/components.bend as C
import ../../src/content.bend as F
import ../../src/creation.bend as Create
import ../../src/scene.bend as Scene
import ../../src/scene-hierarchy.bend as HW
import ../../src/scene-render.bend as R
import ../../src/scene-draw.bend as Draw
import ../../src/scene-matrix.bend as M
import ../../src/lighting.bend as Light
import ../../src/error.bend as Error
import ../../src/app.bend as Scope
import ../../deps/bend-vulkan/Vulkan.bend as V
import ../../examples/scene-render.bend as Existing
import ../../examples/textured-content.bend as Texture
import ../model-obj/native.bend as Native
import ../verify-creation.bend as Consumer
import ../verify-textured-render.bend as Pixel
import ../verify-textured-transforms.bend as Transform

def unpack(p:Maybe<&2,C.Vec3>) -> C.Vec3:
  match p:
    case Some{p}:p
    case None{}:C.Vec3{0.0,0.0,0.0}

def sub(a:C.Vec3,b:C.Vec3) -> C.Vec3:
  C.Vec3{x,y,z} = a
  C.Vec3{u,v,w} = b
  C.Vec3{F32.sub(x,u),F32.sub(y,v),F32.sub(z,w)}

def cross(a:C.Vec3,b:C.Vec3) -> C.Vec3:
  C.Vec3{+x,+y,+z} = a
  C.Vec3{+u,+v,+w} = b
  C.Vec3{(y * w - z * v : F32),(z * u - x * w : F32),(x * v - y * u : F32)}

# The reference surface normal comes from independently transformed tangents,
# not the production inverse transpose or matrix multiplication.
def normal(+rows:List<&2,HW.Row>,+index:U32) -> C.Vec3:
  +fuel:Nat = 1n+List.length(&2,HW.Row,rows)
  +origin = unpack(Check.walk(fuel,rows,index,C.Vec3{0.0,0.0,0.0}))
  x = sub(unpack(Check.walk(fuel,rows,index,C.Vec3{1.0,0.0,0.0})),origin)
  y = sub(unpack(Check.walk(fuel,rows,index,C.Vec3{0.0,1.0,0.0})),origin)
  cross(x,y)

def vertices(vs:List<&2,F.Vertex>,+rows:List<&2,HW.Row>,+index:U32,+n:C.Vec3) -> List<&2,F.Vertex>:
  match vs:
    case []:[]
    case F.Vertex{p,c,uv,_} <> rest:F.Vertex{unpack(Check.walk(1n+List.length(&2,HW.Row,rows),rows,index,p)),c,uv,n} <> vertices(rest,rows,index,n)

def reference_mesh(mesh:F.Mesh,+rows:List<&2,HW.Row>,+index:U32) -> F.Mesh:
  F.Mesh{vs,is1} = mesh
  F.Mesh{vertices(vs,rows,index,normal(rows,index)),is1}

def reference_instances(items:List<&2,Create.Instance>,+rows:List<&2,HW.Row>,+index:U32) -> List<&2,Create.Instance>:
  match items:
    case []:[]
    case Create.Instance{m,c,_} <> rest:Create.Instance{reference_mesh(m,rows,index),c,C.Transform.identity()} <> reference_instances(rest,rows,U32.inc(index))
    case Create.Parented{m,c,_,_} <> rest:Create.Instance{reference_mesh(m,rows,index),c,C.Transform.identity()} <> reference_instances(rest,rows,U32.inc(index))

def reference_scene(scene:Create.Scene,rows:List<&2,HW.Row>) -> Create.Scene:
  Create.Scene{items} = scene
  Create.Scene{reference_instances(items,rows,0)}

def reference(rows:List<&2,HW.Row>) -> Create.Scene:reference_scene(Scenes.showcase(),rows)

def bytes_word(a:U32,b:U32,c:U32,d:U32) -> U32:
  U32.or(a,U32.or((b << 8n : U32),U32.or((c << 16n : U32),(d << 24n : U32))))

def depth_equal(a:List<&2,U32>,b:List<&2,U32>) -> Bool:
  match a b:
    case [],[]:True{}
    case a <> b <> c <> d <> xs,e <> f <> g <> h <> ys:F32.is_le(F32.abs(F32.sub(M.float_word(bytes_word(a,b,c,d)),M.float_word(bytes_word(e,f,g,h)))),0.000002) && depth_equal(xs,ys)
    case _ _:False{}

def colors_equal(a:List<&2,U32>,b:List<&2,U32>) -> Bool:
  match a b:
    case [],[]:True{}
    case x <> xs,y <> ys:Transform.close(x,y) && colors_equal(xs,ys)
    case _ _:False{}

def covered(depth:List<&2,U32>) -> U32:
  match depth:
    case []:0
    case a <> b <> c <> d <> rest:U32.add(Bool.to_u32(U32.is_ne(bytes_word(a,b,c,d),1065353216)),covered(rest))
    case _:0

def compare(a:R.Readback,b:R.Readback) -> V.Action(Unit):
  R.Readback{_,_,rgba,+depth} = a
  R.Readback{_,_,expected,expected_depth} = b
  Error.require(U32.is_gt(covered(depth),100) && colors_equal(rgba,expected) && depth_equal(depth,expected_depth),"Hierarchy affine rendering/lighting differs from independent baked geometry")

def reference_draws(seeds:List<&2,Create.Seed>) -> List<&2,Draw.DrawItem>:
  match seeds:
    case []:[]
    case Create.Seed{t,m,_} <> rest:Draw.DrawItem{t,m} <> reference_draws(rest)

def reference_frame(entry:V.Entry,compiled:Create.Compiled) -> V.Action(R.Readback):
  Create.Compiled{seeds,geometry} = compiled
  do V.Action<R.Readback>:
    renderer:R.Renderer <- R.create(entry,R.Config{96,96,Pixel.camera(),Light.default()},geometry)
    pair:R.Renderer & R.Readback <- Existing.frame(renderer,Draw.DrawList{reference_draws(seeds)})
    return Pair.snd(R.Renderer,R.Readback,pair)

def seeds(rows:List<&2,HW.Row>) -> List<&2,Create.Seed>:
  match rows:
    case []:[]
    case HW.Row{_,t,m,s} <> rest:Create.Seed{t,m,s} <> seeds(rest)

def original_frame(entry:V.Entry,geometry:Create.Geometry,+rows:List<&2,HW.Row>) -> V.Action(R.Readback):
  do V.Action<R.Readback>:
    Error.require(Native.same_draws(Draw.DrawList{HW.draw_rows(rows)},Draw.DrawList{Texture.draws(seeds(rows))}),"Static textured consumer discarded derived transforms")
    renderer:R.Renderer <- R.create(entry,R.Config{96,96,Pixel.camera(),Light.default()},geometry)
    pair:R.Renderer & R.Readback <- Existing.frame(renderer,Draw.DrawList{HW.draw_rows(rows)})
    return Pair.snd(R.Renderer,R.Readback,pair)

def render(+entry:V.Entry,geometry:Create.Geometry,+rows:List<&2,HW.Row>) -> V.Action(Unit):
  do V.Action<Unit>:
    expected:Create.Compiled <- V.Action.lift(Create.Compiled,Consumer.compiled(Create.compile(reference(rows))))
    actual:R.Readback <- original_frame(entry,geometry,rows)
    expected:R.Readback <- reference_frame(entry,expected)
    compare(actual,expected)

def frame_and_next(next:Scene.Application() & List<&2,HW.Row> -> V.Action(Unit),entry:V.Entry,geometry:Create.Geometry,pair:Scene.Application() & List<&2,HW.Row>) -> V.Action(Unit):
  (app,+rows) = pair
  do V.Action<Unit>:
    render(entry,geometry,rows)
    next((app,rows))

def frames(codes:List<&2,U32>,+entry:V.Entry,+geometry:Create.Geometry,pair:Scene.Application() & List<&2,HW.Row>) -> V.Action(Unit):
  match codes pair:
    case [] _ :V.Action.pure(Unit,Unit{})
    case code <> rest,(app,rows):
      do V.Action<Unit>:
        pair:Scene.Application() & List<&2,HW.Row> <- V.Action.lift(Scene.Application() & List<&2,HW.Row>,Drive.step(code,(app,rows)))
        frame_and_next(frames(rest,entry,geometry),entry,geometry,pair)

def run(+entry:V.Entry,compiled:Create.Compiled) -> V.Action(Unit):
  Create.Compiled{_,geometry} = compiled
  do V.Action<Unit>:
    pair:Scene.Application() & List<&2,HW.Row> <- V.Action.lift(Scene.Application() & List<&2,HW.Row>,Drive.boot())
    frames([0,1,2,3,4,5,0,12],entry,geometry,pair)

def finished(pair:V.VkResult(Unit) & U32) -> IO(Unit):
  (result,count) = pair
  do IO<Unit>:
    V.or_exit(Unit,result)
    IO.try(Unit,Error.require(U32.is_zero(count),"Hierarchy rendering leaked Vulkan objects"))
    IO.print("Hierarchy ECS affine/shear rendering matches independently baked geometry; complete RGBA/D32; live Vulkan objects=0")

def main() -> IO(Unit):
  do IO<Unit>:
    compiled:Create.Compiled <- Consumer.compiled(Create.compile(Scenes.showcase()))
    pair:V.VkResult(Unit) & U32 <- Scope.with(Unit,entry => run(entry,compiled))
    finished(pair)
