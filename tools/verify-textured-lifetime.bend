import Base
import ./verify-textured-render.bend as Check
import ./verify-buffer-retention.bend as Retain
import ../examples/textured-content.bend as Content
import ../src/content.bend as F
import ../src/components.bend as C
import ../src/creation.bend as Create
import ../src/scene-render.bend as R
import ../src/scene-geometry.bend as G
import ../src/scene-pipeline.bend as P
import ../src/scene-materials.bend as Materials
import ../src/scene-texture.bend as T
import ../src/error.bend as Error
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/core.bend as Core

def material(value:Maybe<T.Material>) -> V.Action(T.Material):
  match value:
    case Some{value}:V.Action.pure(T.Material,value)
    case None{}:Error.failure(T.Material,1,"Missing texture material")

def record_material(+command:V.CommandBuffer,pipelines:P.Pipelines,resident:G.Resident,value:T.Material) -> V.Action(Unit):
  T.Material{set,_} = value
  do V.Action<Unit>:
    V.CommandBuffer.begin(command)
    V.CommandBuffer.bind_graphics_pipeline(command,P.textured(pipelines))
    R.bind_geometry(command,G.buffers(resident))
    V.CommandBuffer.bind_descriptor_sets(command,0,[set])
    V.CommandBuffer.end(command)

def recorded(+command:V.CommandBuffer,pipelines:P.Pipelines,+resident:G.Resident) -> V.Action(Unit):
  do V.Action<Unit>:
    value:T.Material <- material(Materials.material(G.materials(resident),7))
    record_material(command,pipelines,resident,value)


def installed(pair:R.Renderer & G.ReplaceStatus) -> V.Action(R.Renderer):
  match pair:
    case (renderer,G.Installed{}):V.Action.pure(R.Renderer,renderer)
    case _:Error.failure(R.Renderer,1,"Texture geometry replacement rejected")

def replace(renderer:R.Renderer,geometry:Create.Geometry) -> V.Action(R.Renderer):
  do V.Action<R.Renderer>:
    pair:R.Renderer & G.ReplaceStatus <- V.Action.lift(R.Renderer & G.ReplaceStatus,R.replace_geometry(renderer,geometry))
    installed(pair)

def collected(pair:R.Renderer & V.VkResult(Unit)) -> V.Action(R.Renderer):
  (renderer,result) = pair
  do V.Action<R.Renderer>:
    IO.pure(V.VkResult(Unit),result)
    return renderer

def collect(renderer:R.Renderer) -> V.Action(R.Renderer):
  do V.Action<R.Renderer>:
    pair:R.Renderer & V.VkResult(Unit) <- V.Action.lift(R.Renderer & V.VkResult(Unit),R.collect_geometry(renderer))
    collected(pair)

def run_renderer(renderer:R.Renderer,+replacement:Create.Geometry) -> V.Action(Unit):
  R.Renderer{+resources,config,+resident,offset,used} = renderer
  R.Resources{G.Context{_,_,+device},_,_,_,+pipelines,_,_,_} = resources
  do V.Action<Unit>:
    +pool:V.CommandPool <- V.Device.create_command_pool(device)
    +a:V.CommandBuffer <- V.Device.allocate_command_buffer(device,pool)
    +b:V.CommandBuffer <- V.Device.allocate_command_buffer(device,pool)
    +fence:V.Fence <- V.Device.create_fence(device,False{})
    +before:U32 <- V.debug_live_objects()
    recorded(a,pipelines,resident)
    recorded(b,pipelines,resident)
    V.Device.submit(device,a,fence)
    renderer:R.Renderer <- replace(R.Renderer{resources,config,resident,offset,used},replacement)
    renderer:R.Renderer <- collect(renderer)
    Retain.count(U32.add(before,11),"Pending commands retain texture, descriptor set and geometry")
    status:U32 <- V.Fence.wait(fence,Core.whole_size())
    Error.require(U32.is_zero(status),"Textured submission incomplete")
    renderer:R.Renderer <- collect(renderer)
    Retain.count(U32.add(before,11),"Completion preserves recorded texture ownership")
    V.CommandBuffer.reset(a)
    renderer:R.Renderer <- collect(renderer)
    Retain.count(U32.add(before,11),"Second executable command retains texture")
    V.CommandBuffer.reset(b)
    renderer:R.Renderer <- collect(renderer)
    Retain.count(before,"Reset and collection release old texture and geometry")
    renderer:R.Renderer <- replace(renderer,replacement)
    renderer:R.Renderer <- collect(renderer)
    Retain.count(before,"Repeated textured replacement does not grow resources")
    V.Device.destroy_fence(device,fence)
    V.Device.destroy_command_pool(device,pool)
    V.Action.lift(Unit,IO.print("Textured material lifetime verified across pending, completed and unsubmitted commands, replacement, reset and collection."))

def run(entry:V.Entry,compiled:Create.Compiled) -> V.Action(Unit):
  Create.Compiled{_,+geometry} = compiled
  do V.Action<Unit>:
    renderer:R.Renderer <- R.create(entry,R.Config{64,64,Check.camera(),Check.light()},geometry)
    run_renderer(renderer,geometry)

def main() -> IO(Unit):
  do IO<Unit>:
    image:F.SourceImage <- Content.load("assets/checker.png")
    compiled:Create.Compiled <- Content.compiled(Create.compile(Content.scene(image,C.Vec3{0.0,0.0,1.0})))
    IO.try(Unit,V.Entry.with(Unit,entry => run(entry,compiled)))
    IO.try(Unit,Retain.count(0,"Texture lifetime terminal cleanup"))
