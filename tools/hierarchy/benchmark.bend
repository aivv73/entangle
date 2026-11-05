import Base
import ./check.bend as Check
import ./scenes.bend as Scenes
import ./render.bend as Evidence
import ../../src/components.bend as C
import ../../src/content.bend as F
import ../../src/creation.bend as Create
import ../../src/scene.bend as Scene
import ../../src/scene-hierarchy.bend as HW
import ../../src/hierarchy.bend as H
import ../../src/scene-render.bend as R
import ../../src/scene-draw.bend as Draw
import ../../src/scene-matrix.bend as M
import ../../src/lighting.bend as Light
import ../../src/app.bend as Scope
import ../../src/scene-schema.bend as D
import ../../deps/bendvy/src/ecs/world.bend as W
import ../../deps/bend-vulkan/Vulkan.bend as V
import ../../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as U
import ../../examples/scene-render.bend as Existing
import ../verify-creation.bend as Consumer
import ../upload-boundary/scan.bend as S

def position(+mode:U32,+index:U32) -> C.Vec3:
  Bool.pick(C.Vec3,U32.is_zero(mode),C.Vec3{F32.mul(U32.to_f32(U32.mod(index,32)),1.5),F32.mul(U32.to_f32(U32.div(index,32)),1.5),0.0},C.Vec3{0.25,0.125,0.0})

def instances(count:Nat,+mode:U32,+index:U32) -> List<&2,Create.Instance>:
  match count:
    case 0n:[]
    case 1n+n:Create.parent(Create.Instance{Scenes.mesh(),F.white(),Scenes.before_tick(C.Transform{position(mode,index),Scenes.rotation(),Scenes.unit()})},Scenes.parent(mode,index)) <> instances(n,mode,U32.inc(index))

def depth(fuel:Nat,+mode:U32,index:U32) -> U32:
  match fuel index:
    case _ 0:0
    case 0n _:0
    case 1n+n,+i:U32.inc(depth(n,mode,Bool.pick(U32,U32.is_eq(mode,1),U32.sub(i,1),U32.div(U32.sub(i,1),2))))

def expected(+mode:U32,+count:U32,+index:U32,+root:F32) -> C.Vec3:
  +level = U32.to_f32(depth(U32.to_nat(count),mode,index))
  Bool.pick(C.Vec3,U32.is_zero(mode),Bool.pick(C.Vec3,U32.is_zero(index),C.Vec3{root,0.125,0.0},position(mode,index)),C.Vec3{F32.add(root,F32.mul(level,0.25)),F32.mul(F32.add(level,1.0),0.125),0.0})

def verify(rows:List<&2,HW.Row>,+mode:U32,+count:U32,+index:U32,+root:F32) -> IO(Unit):
  match rows:
    case []:S.require(U32.is_eq(index,count),"Benchmark missing ECS rows")
    case HW.Row{_,_,_,H.Spatial{_,global,bounds}} <> rest:
      +p = expected(mode,count,index,root)
      do IO<Unit>:
        S.require(Check.vec(H.point(H.matrix(global),C.Vec3{0.0,0.0,0.0}),p),"Benchmark hierarchy state differs from analytic translation forest")
        S.require(Check.bounds(Some{H.transformed(H.corners(H.Bounds{C.Vec3{F32.neg(0.5),F32.neg(0.5),0.0},C.Vec3{0.5,0.5,0.0}}),M.model(C.Transform{p,Scenes.rotation(),Scenes.unit()}),H.Empty{})},bounds),"Benchmark world bounds differ")
        verify(rest,mode,count,U32.inc(index),root)

def time() -> IO(U.U64):
  do IO<U.U64>:
    result:V.VkResult(U.U64) <- V.monotonic_ns()
    V.or_exit(U.U64,result)

def milliseconds(value:U.U64) -> F32:
  U.U64{lo,hi} = value
  ((U32.to_f32(hi) * 4294967296.0 + U32.to_f32(lo)) / 1000000.0 : F32)

def mutation(app:Scene.Application(),root:W.Handle<D.Schema>,+step:U32) -> IO(Scene.Application()):
  Check.accepted(Scene.set_transform(app,root,Scenes.pose(Bool.pick(F32,U32.is_zero(U32.mod(step,2)),0.5,0.75),0.125,0.0,Scenes.rotation(),Scenes.unit())),True{})

def update_loop(fuel:Nat,+root:W.Handle<D.Schema>,+step:U32,app:Scene.Application()) -> IO(Scene.Application()):
  match fuel:
    case 0n:IO.pure(Scene.Application(),app)
    case 1n+n:
      do IO<Scene.Application()>:
        app:Scene.Application() <- mutation(app,root,step)
        update_loop(n,root,U32.inc(step),app)

def report(label:String,mode:U32,count:U32,steps:U32,elapsed:U.U64) -> IO(Unit):
  IO.print(label ++ " mode=" ++ U32.show(mode) ++ " nodes=" ++ U32.show(count) ++ " updates=" ++ U32.show(steps) ++ " errors=0 total_ms=" ++ F32.show(milliseconds(elapsed)))

def verify_capture(pair:Scene.Application() & List<&2,HW.Row>,mode:U32,count:U32,root:F32) -> IO(Scene.Application()):
  (app,+rows) = pair
  do IO<Scene.Application()>:
    verify(rows,mode,count,0,root)
    IO.print("verified-state=" ++ Check.state(rows))
    return app

def verified(app:Scene.Application(),mode:U32,count:U32,root:F32) -> IO(Scene.Application()):
  do IO<Scene.Application()>:
    pair:Scene.Application() & List<&2,HW.Row> <- Check.capture(app)
    verify_capture(pair,mode,count,root)

def cpu(app:Scene.Application(),+root:W.Handle<D.Schema>,+mode:U32,+count:U32,+steps:U32) -> IO(Scene.Application()):
  do IO<Scene.Application()>:
    app:Scene.Application() <- mutation(app,root,0)
    start:U.U64 <- time()
    app:Scene.Application() <- update_loop(U32.to_nat(steps),root,0,app)
    end:U.U64 <- time()
    app:Scene.Application() <- verified(app,mode,count,Bool.pick(F32,U32.is_zero(U32.mod(steps,2)),0.75,0.5))
    report("publication",mode,count,steps,U.add(end,U.neg(start)))
    return app

def camera(+mode:U32,+count:U32) -> M.Mat4:
  +span = Bool.pick(F32,U32.is_zero(mode),50.0,Bool.pick(F32,U32.is_eq(mode,1),F32.mul(U32.to_f32(count),0.3),4.0))
  +s = F32.div(1.8,span)
  M.Mat4{M.Vec4{s,0.0,0.0,0.0},M.Vec4{0.0,s,0.0,0.0},M.Vec4{0.0,0.0,0.1,0.0},M.Vec4{F32.neg(0.8),F32.neg(0.8),0.5,1.0}}

def observed_frame(pair:Scene.Application() & List<&2,HW.Row>,renderer:R.Renderer) -> V.Action(Scene.Application() & R.Renderer):
  (app,rows) = pair
  do V.Action<Scene.Application() & R.Renderer>:
    pair:R.Renderer & R.Readback <- Existing.frame(renderer,Draw.DrawList{HW.draw_rows(rows)})
    return (app,Pair.fst(R.Renderer,R.Readback,pair))

def continue_frames(next:Scene.Application() -> R.Renderer -> V.Action(Scene.Application() & R.Renderer),pair:Scene.Application() & R.Renderer) -> V.Action(Scene.Application() & R.Renderer):
  (app,renderer) = pair
  next(app,renderer)

def frame_loop(fuel:Nat,+root:W.Handle<D.Schema>,+step:U32,app:Scene.Application(),renderer:R.Renderer) -> V.Action(Scene.Application() & R.Renderer):
  match fuel:
    case 0n:V.Action.pure(Scene.Application() & R.Renderer,(app,renderer))
    case 1n+n:
      do V.Action<Scene.Application() & R.Renderer>:
        app:Scene.Application() <- V.Action.lift(Scene.Application(),mutation(app,root,step))
        observed:Scene.Application() & List<&2,HW.Row> <- V.Action.lift(Scene.Application() & List<&2,HW.Row>,Check.capture(app))
        pair:Scene.Application() & R.Renderer <- observed_frame(observed,renderer)
        continue_frames(frame_loop(n,root,U32.inc(step)),pair)

def words(values:List<&2,U32>) -> String:
  match values:
    case []:""
    case x <> rest:U32.show(x) ++ "," ++ words(rest)

def verified_image(pair:R.Renderer & R.Readback) -> V.Action(Unit):
  (renderer,R.Readback{w,h,rgba,+depth}) = pair
  do V.Action<Unit>:
    V.Action.lift(Unit,S.require(U32.is_eq(w,256) && U32.is_eq(h,256) && U32.is_gt(Evidence.covered(depth),100),"Benchmark render was empty"))
    V.Action.lift(Unit,IO.print("verified-rgba=" ++ words(rgba)))
    V.Action.lift(Unit,IO.print("verified-depth=" ++ words(depth)))

def capture_image(pair:Scene.Application() & List<&2,HW.Row>,renderer:R.Renderer) -> V.Action(Unit):
  (app,rows) = pair
  do V.Action<Unit>:
    pair:R.Renderer & R.Readback <- Existing.frame(renderer,Draw.DrawList{HW.draw_rows(rows)})
    verified_image(pair)

def rendered(pair:Scene.Application() & R.Renderer,+mode:U32,+count:U32,+steps:U32,start:U.U64) -> V.Action(Unit):
  (app,renderer) = pair
  do V.Action<Unit>:
    end:U.U64 <- V.Action.lift(U.U64,time())
    app:Scene.Application() <- V.Action.lift(Scene.Application(),verified(app,mode,count,Bool.pick(F32,U32.is_zero(U32.mod(steps,2)),0.75,0.5)))
    V.Action.lift(Unit,report("offscreen-frame",mode,count,steps,U.add(end,U.neg(start))))
    pair:Scene.Application() & List<&2,HW.Row> <- V.Action.lift(Scene.Application() & List<&2,HW.Row>,Check.capture(app))
    capture_image(pair,renderer)

def measure_frames(pair:Scene.Application() & R.Renderer,root:W.Handle<D.Schema>,mode:U32,count:U32,+steps:U32) -> V.Action(Unit):
  (app,renderer) = pair
  do V.Action<Unit>:
    start:U.U64 <- V.Action.lift(U.U64,time())
    pair:Scene.Application() & R.Renderer <- frame_loop(U32.to_nat(steps),root,0,app,renderer)
    rendered(pair,mode,count,steps,start)

def measured(entry:V.Entry,geometry:Create.Geometry,pair:Scene.Application() & List<&2,HW.Row>,+mode:U32,+count:U32,+steps:U32) -> V.Action(Unit):
  (app,rows) = pair
  do V.Action<Unit>:
    +root:W.Handle<D.Schema> <- V.Action.lift(W.Handle<D.Schema>,Check.entity(Check.at(rows,0n)))
    app:Scene.Application() <- V.Action.lift(Scene.Application(),cpu(app,root,mode,count,steps))
    renderer:R.Renderer <- R.create(entry,R.Config{256,256,camera(mode,count),Light.default()},geometry)
    warmed:Scene.Application() & R.Renderer <- frame_loop(1n,root,0,app,renderer)
    measure_frames(warmed,root,mode,count,steps)

def run(entry:V.Entry,compiled:Create.Compiled,mode:U32,count:U32,steps:U32) -> V.Action(Unit):
  Create.Compiled{seeds,geometry} = compiled
  do V.Action<Unit>:
    app:Scene.Application() <- V.Action.lift(Scene.Application(),Scene.create(seeds))
    app:Scene.Application() <- V.Action.lift(Scene.Application(),Scene.tick(app))
    pair:Scene.Application() & List<&2,HW.Row> <- V.Action.lift(Scene.Application() & List<&2,HW.Row>,Check.capture(app))
    measured(entry,geometry,pair,mode,count,steps)

def finished(pair:V.VkResult(Unit) & U32) -> IO(Unit):
  (result,count) = pair
  do IO<Unit>:
    V.or_exit(Unit,result)
    S.require(U32.is_zero(count),"Benchmark leaked Vulkan resources")

def numbers(count:Maybe<&2,U32>,mode:Maybe<&2,U32>,steps:Maybe<&2,U32>) -> IO(Unit):
  match count mode steps:
    case Some{+count} Some{+mode} Some{+steps}:
      do IO<Unit>:
        S.require(U32.is_gt(count,0) && U32.is_le(count,4096) && U32.is_le(mode,2) && U32.is_gt(steps,0),"Invalid benchmark workload")
        compiled:Create.Compiled <- Consumer.compiled(Create.compile(Create.Scene{instances(U32.to_nat(count),mode,0)}))
        pair:V.VkResult(Unit) & U32 <- Scope.with(Unit,entry => run(entry,compiled,mode,count,steps))
        finished(pair)
    case _ _ _:IO.die(Unit,1,"Invalid benchmark arguments")

def arguments(args:List<String>) -> IO(Unit):
  match args:
    case [_,count,mode,steps]:numbers(U32.read(count),U32.read(mode),U32.read(steps))
    case _:IO.die(Unit,1,"Usage: hierarchy-benchmark count mode steps")

def main() -> IO(Unit):
  do IO<Unit>:
    args:List<String> <- IO.args
    arguments(args)
