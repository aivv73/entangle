import Base
import ../src/error.bend as Error
import ../src/scene-render.bend as R
import ../src/scene-matrix.bend as M
import ../src/components.bend as C
import ../src/scene-draw.bend as Draw
import ../src/scene.bend as Scene
import ../src/scene-observe.bend as Observe
import ../src/scene-schema.bend as D
import ../deps/bendvy/src/ecs/inspector.bend as I
import ../deps/bendvy/src/ecs/change-tick.bend as Tick
import ../deps/bend-vulkan/Vulkan.bend as V
import ./scene.bend as Check

def camera() -> M.Mat4:
  M.Mat4{M.Vec4{0.015625,F32.neg(0.125),0.0,0.0},M.Vec4{0.0,0.0625,0.0,0.0},M.Vec4{0.0,0.0,0.00390625,0.0},M.Vec4{F32.neg(0.96875),0.25,0.5,1.0}}

def quad(+z:F32,+color:C.Vec3) -> List<&2,R.Vertex>:
  [R.Vertex{C.Vec3{F32.neg(0.515),F32.neg(F32.div(1.0,75.0)),z},color},
   R.Vertex{C.Vec3{0.035,F32.neg(0.08),z},color},
   R.Vertex{C.Vec3{0.515,F32.div(1.0,75.0),z},color},
   R.Vertex{C.Vec3{F32.neg(0.035),0.08,z},color}]

def mesh(reverse:Bool) -> R.Mesh:
  vertices = List.append(&2,R.Vertex,quad(0.03125,C.Vec3{1.0,0.0,0.0}),quad(0.09375,C.Vec3{0.0,1.0,0.0}))
  indices = Bool.pick(List<&2,U32>,reverse,[4,5,6,6,7,4,0,1,2,2,3,0],[0,1,2,2,3,0,4,5,6,6,7,4])
  R.Mesh{7,vertices,indices}

def depth_word(+numerator:U32) -> U32:
  +power = U32.log2(numerator)
  exponent = U32.add(116,U32.from_nat(power))
  mantissa = U32.sub(U32.shln(numerator,Nat.sub(23n,power)),8388608)
  U32.add(U32.shln(exponent,23n),mantissa)

def expected(+x:U32,+y:U32,+tick:U32,populated:Bool) -> U32 & U32:
  +candidate = U32.div(U32.add(x,2),8)
  +first = U32.add(2,tick)
  +row = U32.sub(160,U32.mul(12,tick))
  +inside = populated && U32.is_ge(candidate,first) && U32.is_lt(candidate,U32.add(first,100)) && U32.is_lt(U32.mod(U32.add(x,2),8),4) && U32.is_ge(y,U32.sub(row,4)) && U32.is_lt(y,U32.add(row,4))
  seed = U32.sub(candidate,first)
  (Bool.pick(U32,inside,4278190335,4294901760),Bool.pick(U32,inside,depth_word(U32.sub(U32.sub(1025,U32.mul(8,seed)),U32.mul(16,tick))),1065353216))

def word(+a:U32,+b:U32,+c:U32,+d:U32) -> U32:
  (a + b * 256 + c * 65536 + d * 16777216 : U32)

def pixel_ok(actual:U32 & U32,expected:U32 & U32) -> Bool:
  (a,b) = actual
  (c,d) = expected
  U32.is_eq(a,c) && U32.is_eq(b,d)

def pixels(rgba:List<&2,U32>,depth:List<&2,U32>,+index:U32,+tick:U32,+populated:Bool) -> Bool:
  match rgba depth:
    case [],[]:U32.is_eq(index,262144)
    case a <> b <> c <> d <> rest,e <> f <> g <> h <> tail:
      pixel_ok((word(a,b,c,d),word(e,f,g,h)),expected(U32.mod(index,1024),U32.div(index,1024),tick,populated)) && pixels(rest,tail,U32.inc(index),tick,populated)
    case _,_:False{}

def image_ok(image:R.Readback,tick:U32,populated:Bool) -> Bool:
  R.Readback{width,height,rgba,depth} = image
  U32.is_eq(width,1024) && U32.is_eq(height,256) && pixels(rgba,depth,0,tick,populated)

def equal_bytes(a:List<&2,U32>,b:List<&2,U32>) -> Bool:
  match a b:
    case [],[]:True{}
    case x <> xs,y <> ys:U32.is_eq(x,y) && equal_bytes(xs,ys)
    case _,_:False{}

def image_equal(a:R.Readback,b:R.Readback) -> Bool:
  R.Readback{w,h,c,d} = a
  R.Readback{x,y,e,f} = b
  U32.is_eq(w,x) && U32.is_eq(h,y) && equal_bytes(c,e) && equal_bytes(d,f)

def readback(result:Result<&2,&2,R.InputError,R.Readback>) -> V.Action(R.Readback):
  match result:
    case Done{image}:V.Action.pure(R.Readback,image)
    case Fail{_}:IO.pure(V.VkResult(R.Readback),Fail{(1,"Renderer rejected valid drawing")})

def rendered(pair:R.Renderer & Result<&2,&2,R.InputError,R.Readback>) -> V.Action(R.Renderer & R.Readback):
  (renderer,result) = pair
  do V.Action<R.Renderer & R.Readback>:
    image : R.Readback <- readback(result)
    return (renderer,image)

def frame(renderer:R.Renderer,list:Draw.DrawList) -> V.Action(R.Renderer & R.Readback):
  do V.Action<R.Renderer & R.Readback>:
    pair : R.Renderer & Result<&2,&2,R.InputError,R.Readback> <- R.render(renderer,list)
    rendered(pair)

def checked_frame(pair:R.Renderer & R.Readback,+tick:U32,populated:Bool) -> V.Action(R.Renderer & R.Readback):
  (renderer,+image) = pair
  do V.Action<R.Renderer & R.Readback>:
    Error.require(image_ok(image,tick,populated),"RGBA8/D32 oracle mismatch at tick " ++ U32.show(tick))
    return (renderer,image)

def verify_frame(renderer:R.Renderer,list:Draw.DrawList,tick:U32,populated:Bool) -> V.Action(R.Renderer & R.Readback):
  do V.Action<R.Renderer & R.Readback>:
    pair : R.Renderer & R.Readback <- frame(renderer,list)
    checked_frame(pair,tick,populated)

def discard_image(pair:R.Renderer & R.Readback) -> R.Renderer:
  (renderer,_) = pair
  renderer

def repeated_checked(first:R.Readback,pair:R.Renderer & R.Readback) -> V.Action(R.Renderer):
  (renderer,second) = pair
  do V.Action<R.Renderer>:
    Error.require(image_equal(first,second),"Repeated frame differs")
    return renderer

def repeat_first(pair:R.Renderer & R.Readback,+list:Draw.DrawList) -> V.Action(R.Renderer):
  (renderer,first) = pair
  do V.Action<R.Renderer>:
    second : R.Renderer & R.Readback <- frame(renderer,list)
    repeated_checked(first,second)

def repeat(renderer:R.Renderer,+list:Draw.DrawList,tick:U32) -> V.Action(R.Renderer):
  do V.Action<R.Renderer>:
    first : R.Renderer & R.Readback <- verify_frame(renderer,list,tick,True{})
    repeat_first(first,list)

def unknown_checked(pair:R.Renderer & Result<&2,&2,R.InputError,R.Readback>) -> V.Action(R.Renderer):
  match pair:
    case (renderer,Fail{R.UnknownMesh{item,id}}):
      do V.Action<R.Renderer>:
        Error.require(U32.is_eq(item,0) && U32.is_eq(id,99),"Wrong unknown-mesh diagnostic")
        return renderer
    case _:IO.pure(V.VkResult(R.Renderer),Fail{(1,"Unknown mesh accepted")})

def reject_unknown(renderer:R.Renderer) -> V.Action(R.Renderer):
  do V.Action<R.Renderer>:
    pair : R.Renderer & Result<&2,&2,R.InputError,R.Readback> <- R.render(renderer,Draw.DrawList{[Draw.DrawItem{C.Transform.identity(),C.MeshRef{99}}]})
    unknown_checked(pair)

def invalid_checked(pair:R.Renderer & Result<&2,&2,R.InputError,R.Readback>) -> V.Action(R.Renderer):
  match pair:
    case (renderer,Fail{R.InvalidTransform{item}}):
      do V.Action<R.Renderer>:
        Error.require(U32.is_eq(item,1),"Wrong invalid-transform diagnostic")
        return renderer
    case _:IO.pure(V.VkResult(R.Renderer),Fail{(1,"Invalid transform accepted")})

def invalid_recovery(values:List<C.Transform>,renderer:R.Renderer,+retained:Draw.DrawList) -> V.Action(R.Renderer):
  match values:
    case []:V.Action.pure(R.Renderer,renderer)
    case invalid <> rest:
      do V.Action<R.Renderer>:
        pair : R.Renderer & Result<&2,&2,R.InputError,R.Readback> <- R.render(renderer,Draw.DrawList{[Draw.DrawItem{C.Transform.identity(),C.MeshRef{7}},Draw.DrawItem{invalid,C.MeshRef{7}}]})
        renderer : R.Renderer <- invalid_checked(pair)
        recovery : R.Renderer & R.Readback <- verify_frame(renderer,retained,1,True{})
        invalid_recovery(rest,discard_image(recovery),retained)

def ppm_pixels(bytes:List<&2,U32>) -> String:
  match bytes:
    case []:""
    case r <> g <> b <> _ <> rest:U32.show(r) ++ " " ++ U32.show(g) ++ " " ++ U32.show(b) ++ "\n" ++ ppm_pixels(rest)
    case _:"invalid"

def write_result(pair:File & Result<&1,&1,U32 & String,Unit>) -> V.Action(Unit):
  (file,result) = pair
  do IO<V.VkResult(Unit)>:
    File.close(file)
    return result

def opened(image:R.Readback,result:Result<&1,&1,U32 & String,File>) -> V.Action(Unit):
  R.Readback{width,height,rgba,_} = image
  match result:
    case Done{file}:
      do IO<V.VkResult(Unit)>:
        written : File & Result<&1,&1,U32 & String,Unit> <- File.write(file,"P3\n" ++ U32.show(width) ++ " " ++ U32.show(height) ++ "\n255\n" ++ ppm_pixels(rgba))
        write_result(written)
    case Fail{error}:IO.pure(V.VkResult(Unit),Fail{error})

def save(image:R.Readback) -> V.Action(Unit):
  do IO<V.VkResult(Unit)>:
    opened_file : Result<&1,&1,U32 & String,File> <- File.open("build/scene-render.ppm","w")
    opened(image,opened_file)

def saved(pair:R.Renderer & R.Readback) -> V.Action(R.Renderer):
  (renderer,image) = pair
  do V.Action<R.Renderer>:
    save(image)
    return renderer

def coverage_margin() -> F32:
  +unit_roundoff : F32 = 0.000000059604644775390625
  +rounding_operations : F32 = 64.0
  coordinate_bound : F32 = 4096.0
  raster_snap_bound : F32 = 0.0625
  +gamma = (rounding_operations * unit_roundoff / (1.0 - rounding_operations * unit_roundoff) : F32)
  (gamma * coordinate_bound + raster_snap_bound : F32)

def close(+a:F32,+b:F32) -> Bool:
  F32.is_le(F32.abs(F32.sub(a,b)),0.00002)

def cross(a:C.Vec3,b:C.Vec3) -> C.Vec3:
  C.Vec3{+x,+y,+z} = a
  C.Vec3{+u,+v,+w} = b
  C.Vec3{(y * w - z * v : F32),(z * u - x * w : F32),(x * v - y * u : F32)}

def scalar_finish(+p:C.Vec3,+w:F32,+first:C.Vec3,second:C.Vec3) -> C.Vec3:
  C.Vec3{px,py,pz} = p
  C.Vec3{a,b,c} = first
  C.Vec3{d,e,f} = second
  C.Vec3{(px + 2.0 * (w * a + d) : F32),(py + 2.0 * (w * b + e) : F32),(pz + 2.0 * (w * c + f) : F32)}

def scalar_cross(+p:C.Vec3,+q:C.Vec3,w:F32,+first:C.Vec3) -> C.Vec3:
  scalar_finish(p,w,first,cross(q,first))

def scalar_rotated(+p:C.Vec3,q:C.Quat) -> C.Vec3:
  C.Quat{+x,+y,+z,w} = q
  scalar_cross(p,C.Vec3{x,y,z},w,cross(C.Vec3{x,y,z},p))

def transform_equal(actual:M.Vec4,expected:C.Vec3) -> Bool:
  M.Vec4{a,b,c,d} = actual
  C.Vec3{x,y,z} = expected
  close(a,F32.add(x,1.25)) && close(b,F32.sub(y,2.5)) && close(c,F32.add(z,3.75)) && close(d,1.0)

def transform_check(+q:C.Quat) -> Bool:
  +t : C.Transform = C.Transform{C.Vec3{1.25,F32.neg(2.5),3.75},q,C.Vec3{2.0,3.0,5.0}}
  transform_equal(M.apply(M.model(t),M.Vec4{0.25,F32.neg(0.5),0.75,1.0}),scalar_rotated(C.Vec3{0.5,F32.neg(1.5),3.75},q))

def tick_frames(renderer:R.Renderer,+list:Draw.DrawList,+retained:Draw.DrawList,+tick:U32) -> V.Action(R.Renderer):
  do V.Action<R.Renderer>:
    renderer : R.Renderer <- repeat(renderer,list,tick)
    replay : R.Renderer & R.Readback <- verify_frame(renderer,retained,1,True{})
    renderer : R.Renderer <- reject_unknown(discard_image(replay))
    recovery : R.Renderer & R.Readback <- verify_frame(renderer,retained,1,True{})
    empty : R.Renderer & R.Readback <- verify_frame(discard_image(recovery),Draw.DrawList{[]},0,False{})
    fresh : R.Renderer & R.Readback <- verify_frame(discard_image(empty),list,tick,True{})
    renderer : R.Renderer = discard_image(fresh)
    return renderer

def draw_count(list:Draw.DrawList) -> Nat:
  Draw.DrawList{items} = list
  List.length(&2,Draw.DrawItem,items)

def finish_tick(next:R.Renderer -> Scene.Application() -> I.Instance<D.Schema> -> Draw.DrawList -> V.Action(Unit),renderer:R.Renderer,+tick:U32,+retained:Draw.DrawList,pair:Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList)) -> V.Action(Unit):
  (app,(instance,list)) = pair
  +list : Draw.DrawList = list
  +first : Draw.DrawList = Bool.pick(Draw.DrawList,U32.is_eq(tick,1),list,retained)
  do V.Action<Unit>:
    Error.require(Nat.is_eq(draw_count(list),100n),"DrawList must contain all 100 entities")
    renderer : R.Renderer <- tick_frames(renderer,list,first,tick)
    V.Action.lift(Unit,IO.print("tick=" ++ U32.show(tick) ++ " all=100 rgba=exact depth=exact repeat=equal replay=equal empty=clear unknown=rejected"))
    next(renderer,app,instance,first)

def initial_empty(renderer:R.Renderer,pair:Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList),next:R.Renderer -> Scene.Application() -> I.Instance<D.Schema> -> V.Action(Unit)) -> V.Action(Unit):
  (app,(instance,list)) = pair
  +list : Draw.DrawList = list
  do V.Action<Unit>:
    Error.require(Nat.is_eq(draw_count(list),0n),"Initial ECS DrawList must be empty")
    image : R.Renderer & R.Readback <- verify_frame(renderer,list,0,False{})
    next(discard_image(image),app,instance)

def observed_key(+prior:String,clock:String,app:Scene.Application(),pair:I.Instance<D.Schema> & String,+list:Draw.DrawList) -> V.Action(Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList)):
  (instance,key) = pair
  do V.Action<Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList)>:
    Error.require(String.eq(prior,key),"Drawing changed inspector cursor")
    return (app,(instance,list))

def observed_clock(+before:String,prior:String,instance:I.Instance<D.Schema>,+list:Draw.DrawList,pair:Scene.Application() & Tick.Tick) -> V.Action(Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList)):
  (app,clock) = pair
  do V.Action<Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList)>:
    Error.require(String.eq(before,Nat.show(Tick.total(clock))),"Drawing changed application clock")
    observed_key(prior,before,app,Check.instance_key(instance),list)

def observed(before:String,prior:String,pair:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Draw.DrawList>)) -> V.Action(Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList)):
  match pair:
    case (app,(instance,Done{list})):observed_clock(before,prior,instance,list,Check.app_clock(app))
    case _:IO.pure(V.VkResult(Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList)),Fail{(1,"DrawList extraction failed")})

def observe_key(before:String,app:Scene.Application(),pair:I.Instance<D.Schema> & String) -> V.Action(Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList)):
  (instance,key) = pair
  observed(before,key,Observe.draw_list(app,instance))

def observe_clock(instance:I.Instance<D.Schema>,pair:Scene.Application() & Tick.Tick) -> V.Action(Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList)):
  (app,clock) = pair
  observe_key(Nat.show(Tick.total(clock)),app,Check.instance_key(instance))

def observe(app:Scene.Application(),instance:I.Instance<D.Schema>) -> V.Action(Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList)):
  observe_clock(instance,Check.app_clock(app))

def final_frame(renderer:R.Renderer,+retained:Draw.DrawList) -> V.Action(Unit):
  do V.Action<Unit>:
    renderer : R.Renderer <- invalid_recovery([
      C.Transform{C.Vec3{F32.div(1.0,0.0),0.0,0.0},C.Quat{0.0,0.0,0.0,1.0},C.Vec3{1.0,1.0,1.0}},
      C.Transform{C.Vec3{0.0,0.0,0.0},C.Quat{0.0,0.0,0.0,0.0},C.Vec3{1.0,1.0,1.0}},
      C.Transform{C.Vec3{0.0,0.0,0.0},C.Quat{0.0,0.0,0.0,1.0},C.Vec3{1.0,F32.div(0.0,0.0),1.0}}],renderer,retained)
    image : R.Renderer & R.Readback <- verify_frame(renderer,retained,1,True{})
    renderer : R.Renderer <- saved(image)
    return Unit{}

def ticks(remaining:Nat,+tick:U32,renderer:R.Renderer,app:Scene.Application(),instance:I.Instance<D.Schema>,retained:Draw.DrawList) -> V.Action(Unit):
  match remaining:
    case 0n:final_frame(renderer,retained)
    case 1n+rest:
      do V.Action<Unit>:
        app : Scene.Application() <- V.Action.lift(Scene.Application(),Scene.tick(app))
        pair : Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList) <- observe(app,instance)
        finish_tick(renderer => app => instance => retained => ticks(rest,U32.inc(tick),renderer,app,instance,retained),renderer,tick,retained,pair)

def run(renderer:R.Renderer) -> V.Action(Unit):
  do V.Action<Unit>:
    app : Scene.Application() <- V.Action.lift(Scene.Application(),Scene.create())
    pair : Scene.Application() & (I.Instance<D.Schema> & Draw.DrawList) <- observe(app,I.Fresh{})
    initial_empty(renderer,pair,renderer => app => instance => ticks(8n,1,renderer,app,I.Active{Some{Tick.zero()},Tick.zero()},Draw.DrawList{[]}))

def no_live() -> IO(Unit):
  do IO<Unit>:
    result : V.VkResult(U32) <- V.debug_live_objects()
    count : U32 <- V.or_exit(U32,result)
    checked : V.VkResult(Unit) <- Error.require(U32.is_zero(count),"Scope retained Vulkan objects")
    V.or_exit(Unit,checked)

def terminal_expected(result:V.VkResult(Unit)) -> IO(Unit):
  match result:
    case Fail{(code,message)}:
      do IO<Unit>:
        no_live()
        checked : V.VkResult(Unit) <- Error.require(U32.is_eq(code,1) && String.eq(message,"intentional scope termination"),"Unexpected scope failure")
        V.or_exit(Unit,checked)
    case Done{_}:IO.die(Unit,1,"Terminal scope error was lost")

def main() -> IO(Unit):
  do IO<Unit>:
    verified : V.VkResult(Unit) <- Error.require(F32.is_lt(coverage_margin(),0.25) && transform_check(C.Quat{0.18257418,0.36514837,0.5477226,0.73029673}) && transform_check(C.Quat{F32.neg(0.5),0.5,F32.neg(0.5),0.5}),"Independent transform or coverage bound failed")
    V.or_exit(Unit,verified)
    IO.print("Scalar quaternion cross-product and independent coverage bound verified.")
    IO.print("index-order=near-first")
    result : V.VkResult(Unit) <- R.with(R.Config{1024,256,camera()},mesh(False{}),run)
    V.or_exit(Unit,result)
    no_live()
    IO.print("index-order=far-first")
    reverse : V.VkResult(Unit) <- R.with(R.Config{1024,256,camera()},mesh(True{}),run)
    V.or_exit(Unit,reverse)
    no_live()
    terminal : V.VkResult(Unit) <- R.with(R.Config{1024,256,camera()},mesh(False{}),renderer => Error.require(False{},"intentional scope termination"))
    terminal_expected(terminal)
    IO.print("Terminal Action cleanup verified.")
    live : V.VkResult(U32) <- V.debug_live_objects()
    count : U32 <- V.or_exit(U32,live)
    checked : V.VkResult(Unit) <- Error.require(U32.is_zero(count),"Renderer leaked Vulkan objects")
    V.or_exit(Unit,checked)
    IO.print("Public Vulkan renderer verified in both index orders; live Vulkan objects=0; image=build/scene-render.ppm")
