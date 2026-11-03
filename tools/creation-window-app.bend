import Base
import ./verify-creation.bend as Creation
import ../src/creation.bend as Create
import ../src/scene-window.bend as Win
import ../src/scene-draw.bend as Draw
import ../src/scene-matrix.bend as M
import ../src/input.bend as Input
import ../src/error.bend as Error
import ../src/app.bend as Scope
import ../deps/bend-vulkan/Vulkan.bend as V


def window_matrix() -> M.Mat4:
  M.Mat4{M.Vec4{0.25,0.0,0.0,0.0},M.Vec4{0.0,F32.neg(0.5),0.0,0.0},M.Vec4{0.0,0.0,0.125,0.0},M.Vec4{F32.neg(0.25),0.25,0.5,1.0}}

def checked(camera:Maybe<Create.Camera>,renderer:Win.Renderer,snapshot:V.WindowSnapshot,+list:Draw.DrawList) -> V.Action(Maybe<Win.Renderer>):
  match camera:
    case None{}:
      do V.Action<Maybe<Win.Renderer>>:
        Win.close(renderer)
        return None{}
    case Some{_}:
      do V.Action<Maybe<Win.Renderer>>:
        pair:Win.Renderer & Result<&2,&2,Win.InputError,Unit> <- Win.frame(renderer,snapshot,w => h => Some{window_matrix()},list)
        renderer:Win.Renderer <- Error.owner(Win.Renderer,Win.InputError,Unit,pair,"Public window drawing rejected")
        return Some{renderer}

def polled(pair:Win.Renderer & V.WindowSnapshot,+list:Draw.DrawList) -> V.Action(Maybe<Win.Renderer>):
  (renderer,snapshot) = pair
  V.WindowSnapshot{width,height,mapped,focused,captured,events} = snapshot
  checked(Input.events(events,Some{Create.default_camera()}),renderer,V.WindowSnapshot{width,height,mapped,focused,captured,[]},list)

def loop(fuel:Nat,renderer:Maybe<Win.Renderer>,+list:Draw.DrawList) -> V.Action(Unit):
  match fuel renderer:
    case _ None{}:V.Action.pure(Unit,Unit{})
    case 0n Some{renderer}:Win.close(renderer)
    case 1n+rest Some{renderer}:
      do V.Action<Unit>:
        pair:Win.Renderer & V.WindowSnapshot <- Win.poll(renderer)
        next:Maybe<Win.Renderer> <- polled(pair,list)
        loop(rest,next,list)

def opened(entry:V.Entry,geometry:Create.Geometry,pair:Draw.DrawList & Draw.DrawList) -> V.Action(Unit):
  (first,_) = pair
  do V.Action<Unit>:
    renderer:Win.Renderer <- Win.open(entry,"Entangle public creation",geometry)
    loop(100000n,Some{renderer},first)

def run(entry:V.Entry,compiled:Create.Compiled) -> V.Action(Unit):
  Create.Compiled{seeds,geometry} = compiled
  do V.Action<Unit>:
    pair:Draw.DrawList & Draw.DrawList <- V.Action.lift(Draw.DrawList & Draw.DrawList,Creation.lists(seeds))
    opened(entry,geometry,pair)

def finished(pair:V.VkResult(Unit) & U32) -> IO(Unit):
  (result,count) = pair
  do IO<Unit>:
    V.or_exit(Unit,result)
    checked:V.VkResult(Unit) <- Error.require(U32.is_zero(count),"Public window leaked Vulkan objects")
    V.or_exit(Unit,checked)
    IO.print("Public creation window closed; live Vulkan objects: 0")

def main() -> IO(Unit):
  do IO<Unit>:
    compiled:Create.Compiled <- Creation.compiled(Create.compile(Creation.content(False{})))
    result:V.VkResult(Unit) & U32 <- Scope.with(Unit,entry => run(entry,compiled))
    finished(result)
