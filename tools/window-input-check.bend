import Base
import ../src/scene-window.bend as Win
import ../src/scene-render.bend as R
import ../src/scene-draw.bend as Draw
import ../src/scene-matrix.bend as M
import ../src/components.bend as C
import ../deps/bend-vulkan/Vulkan.bend as V

def unknown(pair:Win.Renderer & Result<&2,&2,Win.InputError,Unit>) -> V.Action(Win.Renderer):
  match pair:
    case (renderer,Fail{Win.InvalidDrawing{R.UnknownMesh{1,99}}}):V.Action.pure(Win.Renderer,renderer)
    case _:IO.pure(V.VkResult(Win.Renderer),Fail{(1,"Window accepted unknown mesh or wrong item")})

def invalid(pair:Win.Renderer & Result<&2,&2,Win.InputError,Unit>) -> V.Action(Win.Renderer):
  match pair:
    case (renderer,Fail{Win.InvalidDrawing{R.InvalidTransform{1}}}):V.Action.pure(Win.Renderer,renderer)
    case _:IO.pure(V.VkResult(Win.Renderer),Fail{(1,"Window accepted invalid transform or wrong item")})

def camera(pair:Win.Renderer & Result<&2,&2,Win.InputError,Unit>) -> V.Action(Win.Renderer):
  match pair:
    case (renderer,Fail{Win.InvalidCamera{}}):V.Action.pure(Win.Renderer,renderer)
    case _:IO.pure(V.VkResult(Win.Renderer),Fail{(1,"Window accepted malformed or nonfinite camera")})

def identity() -> M.Mat4:M.model(C.Transform.identity())

def verify(renderer:Win.Renderer,snapshot:V.WindowSnapshot) -> V.Action(Win.Renderer):
  V.WindowSnapshot{+width,+height,+mapped,+focused,+captured,events} = snapshot
  +item : Draw.DrawItem = Draw.DrawItem{C.Transform.identity(),C.MeshRef{7}}
  do V.Action<Win.Renderer>:
    pair : Win.Renderer & Result<&2,&2,Win.InputError,Unit> <- Win.frame(renderer,V.WindowSnapshot{width,height,mapped,focused,captured,[]},w => h => Some{identity()},Draw.DrawList{[item,Draw.DrawItem{C.Transform.identity(),C.MeshRef{99}}]})
    renderer : Win.Renderer <- unknown(pair)
    pair : Win.Renderer & Result<&2,&2,Win.InputError,Unit> <- Win.frame(renderer,V.WindowSnapshot{width,height,mapped,focused,captured,[]},w => h => Some{identity()},Draw.DrawList{[item,Draw.DrawItem{C.Transform{C.Vec3{0.0,0.0,0.0},C.Quat{0.0,0.0,0.0,0.0},C.Vec3{1.0,1.0,1.0}},C.MeshRef{7}}]})
    renderer : Win.Renderer <- invalid(pair)
    pair : Win.Renderer & Result<&2,&2,Win.InputError,Unit> <- Win.frame(renderer,V.WindowSnapshot{width,height,mapped,focused,captured,[]},w => h => M.from_words([0]),Draw.DrawList{[]})
    renderer : Win.Renderer <- camera(pair)
    pair : Win.Renderer & Result<&2,&2,Win.InputError,Unit> <- Win.frame(renderer,V.WindowSnapshot{width,height,mapped,focused,captured,[]},w => h => Some{M.Mat4{M.Vec4{M.float_word(2143289345),0.0,0.0,0.0},M.Vec4{0.0,1.0,0.0,0.0},M.Vec4{0.0,0.0,1.0,0.0},M.Vec4{0.0,0.0,0.0,1.0}}},Draw.DrawList{[]})
    renderer : Win.Renderer <- camera(pair)
    V.Action.lift(Unit,IO.print("Window rejected unknown mesh, invalid transform, malformed and nonfinite camera; renderer recovered"))
    return renderer

def polled(pair:Win.Renderer & V.WindowSnapshot) -> V.Action(Win.Renderer):
  (renderer,snapshot) = pair
  verify(renderer,snapshot)

def enabled(replay:Bool,renderer:Win.Renderer) -> V.Action(Win.Renderer):
  match replay:
    case False{}:V.Action.pure(Win.Renderer,renderer)
    case True{}:
      do V.Action<Win.Renderer>:
        pair : Win.Renderer & V.WindowSnapshot <- Win.poll(renderer)
        polled(pair)

def native_bits(words:List<&2,U32>) -> Bool:
  match words:
    case []:True{}
    case +word <> rest:
      U32.is_eq(F32.bits(M.float_word(word)),word) && U32.is_eq(M.float_bits(M.float_word(word)),word) && native_bits(rest)

def bits() -> IO(Unit):
  do IO<Unit>:
    IO.pass(Unit,Bool.pick(Result<&1,&1,U32 & String,Unit>,native_bits([0,2147483648,1,8388607,8388608,1065353216,3212836864,2139095039,2139095040,4286578688,2143289345,4290772993,2147483647,4294967295,1056964608,1078530011]),Done{Unit{}},Fail{(1,"Native float-word bit adaptation failed")}))
    IO.print("Native float-word bits verified including signed zero, subnormal, infinity and NaN payloads")
