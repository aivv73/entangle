import Base
import ./textured-content.bend as Content
import ../src/content.bend as F
import ../src/creation.bend as Create
import ../src/scene-window.bend as Win
import ../src/scene-draw.bend as Draw
import ../src/input.bend as Input
import ../src/error.bend as Error
import ../src/app.bend as Scope
import ../deps/bend-vulkan/Vulkan.bend as V

type Running is Type:
  Running{renderer:Win.Renderer,camera:Create.Camera}

def drawn(pair:Win.Renderer & Result<&2,&2,Win.InputError,Unit>,camera:Create.Camera) -> V.Action(Maybe<Running>):
  do V.Action<Maybe<Running>>:
    renderer:Win.Renderer <- Error.owner(Win.Renderer,Win.InputError,Unit,pair,"Textured window frame rejected")
    return Some{Running{renderer,camera}}

def checked(camera:Maybe<Create.Camera>,renderer:Win.Renderer,snapshot:V.WindowSnapshot,list:Draw.DrawList) -> V.Action(Maybe<Running>):
  match camera:
    case None{}:
      do V.Action<Maybe<Running>>:
        Win.close(renderer)
        return None{}
    case Some{+camera}:
      do V.Action<Maybe<Running>>:
        pair:Win.Renderer & Result<&2,&2,Win.InputError,Unit> <- Win.frame(renderer,snapshot,w => h => Create.view(camera,w,h),list)
        drawn(pair,camera)

def polled(pair:Win.Renderer & V.WindowSnapshot,camera:Create.Camera,list:Draw.DrawList) -> V.Action(Maybe<Running>):
  (renderer,snapshot) = pair
  V.WindowSnapshot{width,height,mapped,focused,captured,events} = snapshot
  checked(Input.events(events,Some{camera}),renderer,V.WindowSnapshot{width,height,mapped,focused,captured,[]},list)

def loop(fuel:Nat,running:Maybe<Running>,+list:Draw.DrawList) -> V.Action(Unit):
  match fuel running:
    case _ None{}:V.Action.pure(Unit,Unit{})
    case 0n Some{Running{renderer,_}}:Win.close(renderer)
    case 1n+rest Some{Running{renderer,camera}}:
      do V.Action<Unit>:
        pair:Win.Renderer & V.WindowSnapshot <- Win.poll(renderer)
        next:Maybe<Running> <- polled(pair,camera,list)
        loop(rest,next,list)

def run(entry:V.Entry,compiled:Create.Compiled) -> V.Action(Unit):
  Create.Compiled{seeds,geometry} = compiled
  do V.Action<Unit>:
    renderer:Win.Renderer <- Win.open(entry,"Entangle textured lighting",geometry)
    loop(100000n,Some{Running{renderer,Create.default_camera()}},Draw.DrawList{Content.draws(seeds)})

def finished(pair:V.VkResult(Unit) & U32) -> IO(Unit):
  (result,count) = pair
  do IO<Unit>:
    V.or_exit(Unit,result)
    IO.try(Unit,Error.require(U32.is_zero(count),"Textured window leaked Vulkan objects"))
    IO.print("Textured window closed; live Vulkan objects: 0")

def main() -> IO(Unit):
  do IO<Unit>:
    image:F.SourceImage <- Content.load("assets/checker.png")
    compiled:Create.Compiled <- Content.compiled(Create.compile(Content.showcase(image)))
    result:V.VkResult(Unit) & U32 <- Scope.with(Unit,entry => run(entry,compiled))
    finished(result)
