import Base
import ../src/scene-geometry.bend as G
import ../src/scene-buffer.bend as B
import ../src/scene-render.bend as R
import ../src/scene-draw.bend as Draw
import ../src/scene-matrix.bend as M
import ../src/creation.bend as Create
import ../src/components.bend as C
import ../src/error.bend as Error
import ../src/app.bend as Scope
import ../examples/scene-render.bend as Existing
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/core.bend as Core
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W

def camera() -> M.Mat4:M.model(C.Transform.identity())

def vertices(+color:C.Vec3) -> List<&2,Create.Vertex>:
  [Create.Vertex{C.Vec3{F32.neg(0.75),F32.neg(0.75),0.25},color},
   Create.Vertex{C.Vec3{0.75,F32.neg(0.75),0.25},color},
   Create.Vertex{C.Vec3{0.75,0.75,0.25},color},
   Create.Vertex{C.Vec3{F32.neg(0.75),0.75,0.25},color}]

def red() -> Create.Geometry:
  Create.Geometry{vertices(C.Vec3{1.0,0.0,0.0}),[0,1,2,2,3,0],[Create.Range{7,0,6}]}

def green() -> Create.Geometry:
  Create.Geometry{vertices(C.Vec3{0.0,1.0,0.0}),[0,1,2,2,3,0],[Create.Range{9,3,3},Create.Range{10,0,6}]}

def empty() -> Create.Geometry:Create.Geometry{[],[],[Create.Range{11,0,0}]}

def invalid() -> Create.Geometry:
  Create.Geometry{vertices(C.Vec3{0.0,1.0,0.0}),[0,1,99],[Create.Range{9,0,3}]}

def draws(id:U32) -> Draw.DrawList:
  Draw.DrawList{[Draw.DrawItem{C.Transform.identity(),C.MeshRef{id}}]}

def status(value:G.ReplaceStatus,installed:Bool) -> V.Action(Unit):
  match value installed:
    case G.Installed{} True{}:V.Action.pure(Unit,Unit{})
    case G.Rejected{G.Failure{_,[]}} False{}:V.Action.pure(Unit,Unit{})
    case G.Rejected{error} _:IO.pure(V.VkResult(Unit),Fail{G.failure(error)})
    case _ _:Error.require(False{},"Unexpected mesh replacement status")

def replacement(-A:Type,pair:A & G.ReplaceStatus,installed:Bool) -> V.Action(A):
  (owner,value) = pair
  do V.Action<A>:
    status(value,installed)
    return owner

def replace(renderer:R.Renderer,mesh:Create.Geometry,installed:Bool) -> V.Action(R.Renderer):
  do V.Action<R.Renderer>:
    pair:R.Renderer & G.ReplaceStatus <- V.Action.lift(R.Renderer & G.ReplaceStatus,R.replace_geometry(renderer,mesh))
    replacement(R.Renderer,pair,installed)

def collected(-A:Type,pair:A & V.VkResult(Unit)) -> V.Action(A):
  (owner,result) = pair
  do V.Action<A>:
    value:Unit <- IO.pure(V.VkResult(Unit),result)
    return owner

def collect(renderer:R.Renderer) -> V.Action(R.Renderer):
  do V.Action<R.Renderer>:
    pair:R.Renderer & V.VkResult(Unit) <- V.Action.lift(R.Renderer & V.VkResult(Unit),R.collect_geometry(renderer))
    collected(R.Renderer,pair)

def equal_checked(pair:R.Renderer & R.Readback,expected:R.Readback) -> V.Action(R.Renderer):
  (renderer,image) = pair
  do V.Action<R.Renderer>:
    Error.require(Existing.image_equal(image,expected),"Rejected replacement changed exact RGBA or D32 readback")
    return renderer

def equal_frame(renderer:R.Renderer,id:U32,expected:R.Readback) -> V.Action(R.Renderer):
  do V.Action<R.Renderer>:
    pair:R.Renderer & R.Readback <- Existing.frame(renderer,draws(id))
    equal_checked(pair,expected)

def pixels(bytes:List<&2,U32>,+r:U32,+g:U32,+b:U32) -> U32:
  match bytes:
    case x <> y <> z <> _ <> rest:U32.add(Bool.to_u32(U32.is_eq(x,r) && U32.is_eq(y,g) && U32.is_eq(z,b)),pixels(rest,r,g,b))
    case _:0

def save(+name:String,image:R.Readback) -> V.Action(Unit):
  do IO<V.VkResult(Unit)>:
    opened:Result<&1,&1,U32 & String,File> <- File.open("build/replacement-" ++ name ++ ".ppm","w")
    Existing.opened(image,opened)

def colored(pair:R.Renderer & R.Readback,+r:U32,+g:U32,+b:U32,+expected:U32) -> V.Action(R.Renderer):
  (renderer,+image) = pair
  R.Readback{w,h,rgba,depth} = image
  do V.Action<R.Renderer>:
    Error.require(U32.is_eq(pixels(rgba,r,g,b),expected),"Replacement range coverage or color differs from exact pixel count")
    save(U32.show(r) ++ "-" ++ U32.show(g) ++ "-" ++ U32.show(b) ++ "-" ++ U32.show(expected),image)
    return renderer

def color_frame(renderer:R.Renderer,id:U32,r:U32,g:U32,b:U32,expected:U32) -> V.Action(R.Renderer):
  do V.Action<R.Renderer>:
    pair:R.Renderer & R.Readback <- Existing.frame(renderer,draws(id))
    colored(pair,r,g,b,expected)

def removed_checked(pair:R.Renderer & Result<&2,&2,R.InputError,R.Readback>,+id:U32) -> V.Action(R.Renderer):
  match pair:
    case (renderer,Fail{R.UnknownMesh{0,other}}):
      do V.Action<R.Renderer>:
        Error.require(U32.is_eq(other,id),"Wrong removed mesh identifier")
        return renderer
    case _:Error.failure(R.Renderer,1,"Removed mesh reference accepted")

def removed(renderer:R.Renderer,+id:U32) -> V.Action(R.Renderer):
  do V.Action<R.Renderer>:
    pair:R.Renderer & Result<&2,&2,R.InputError,R.Readback> <- R.render(renderer,draws(id))
    removed_checked(pair,id)

def live(+expected:U32,label:String) -> V.Action(Unit):
  do V.Action<Unit>:
    +actual:U32 <- V.debug_live_objects()
    Error.require(U32.is_eq(actual,expected),label ++ " live allocation count expected=" ++ U32.show(expected) ++ " actual=" ++ U32.show(actual))

def alive(device:V.Device,buffer:B.Buffer) -> V.Action(Unit):
  do V.Action<Unit>:
    req:V.MemoryRequirements <- V.Device.get_buffer_memory_requirements(device,B.handle(buffer))
    return Unit{}

def gone_result(-A:Type,result:V.VkResult(A)) -> V.Action(Unit):
  match result:
    case Fail{(1610612738,_)}:V.Action.pure(Unit,Unit{})
    case _:Error.require(False{},"Collected old handle still exists or failed for an unexpected reason")

def gone(device:V.Device,buffer:B.Buffer) -> V.Action(Unit):
  do V.Action<Unit>:
    result:V.VkResult(V.MemoryRequirements) <- V.Action.lift(V.VkResult(V.MemoryRequirements),V.Device.get_buffer_memory_requirements(device,B.handle(buffer)))
    gone_result(V.MemoryRequirements,result)

def retained_buffers(resident:G.Resident) -> V.Action(G.Buffers):
  G.Resident{value,ranges} = resident
  match value:
    case Some{buffers}:V.Action.pure(G.Buffers,buffers)
    case None{}:Error.failure(G.Buffers,1,"Expected resident allocations")

def atomic_rejection(pair:R.Renderer & G.ReplaceStatus) -> V.Action(R.Renderer):
  match pair:
    case (renderer,G.Rejected{G.Failure{(1610612740,message),[]}}):
      do V.Action<R.Renderer>:
        Error.require(String.contains(message,"complete allocation set before sealing"),"Unexpected retirement rejection")
        return renderer
    case _:Error.failure(R.Renderer,1,"Active recording did not reject paired retirement cleanly")

def bytes_equal(actual:List<U32>,expected:List<&2,U32>) -> Bool:
  Existing.equal_bytes(R.reusable(actual),expected)

def readable(+device:V.Device,+buffers:G.Buffers) -> V.Action(Unit):
  G.Buffers{vb,ib} = buffers
  do V.Action<Unit>:
    a:List<U32> <- B.read(device,vb,W.zero(),96)
    b:List<U32> <- B.read(device,ib,W.zero(),24)
    Error.require(bytes_equal(a,G.vertices_bytes(vertices(C.Vec3{1.0,0.0,0.0}))) && bytes_equal(b,G.indices_bytes([0,1,2,2,3,0])),"Retirement rejection sealed or altered part of the old allocation pair")

def repeat(fuel:Nat,renderer:R.Renderer) -> V.Action(R.Renderer):
  match fuel:
    case 0n:V.Action.pure(R.Renderer,renderer)
    case 1n+rest:
      do V.Action<R.Renderer>:
        renderer:R.Renderer <- replace(renderer,green(),True{})
        renderer:R.Renderer <- color_frame(renderer,10,0,255,0,2304)
        renderer:R.Renderer <- replace(renderer,empty(),True{})
        renderer:R.Renderer <- color_frame(renderer,11,0,0,255,4096)
        renderer:R.Renderer <- removed(renderer,10)
        renderer:R.Renderer <- replace(renderer,red(),True{})
        renderer:R.Renderer <- color_frame(renderer,7,255,0,0,2304)
        repeat(rest,renderer)

def lifetime(renderer:R.Renderer,+first:R.Readback,+buffers:G.Buffers) -> V.Action(Unit):
  R.Renderer{+resources,config,+resident,offset,used} = renderer
  R.Resources{+context,command,fence,framebuffer,+pipeline,color,depth,stage} = resources
  G.Buffers{+vb,+ib} = buffers
  +device = G.device(context)
  do V.Action<Unit>:
    +pool:V.CommandPool <- V.Device.create_command_pool(device)
    +extra:V.CommandBuffer <- V.Device.allocate_command_buffer(device,pool)
    +wait:V.Fence <- V.Device.create_fence(device,False{})
    +base:U32 <- V.debug_live_objects()
    V.CommandBuffer.begin(extra)
    V.CommandBuffer.bind_index_buffer(extra,B.handle(ib),W.zero(),vk.VK_INDEX_TYPE_UINT32())
    pair:R.Renderer & G.ReplaceStatus <- V.Action.lift(R.Renderer & G.ReplaceStatus,R.replace_geometry(R.Renderer{resources,config,resident,offset,used},green()))
    renderer:R.Renderer <- atomic_rejection(pair)
    live(base,"Rejected candidate disposed")
    readable(device,buffers)
    renderer:R.Renderer <- equal_frame(renderer,7,first)
    V.CommandBuffer.reset(extra)
    V.CommandBuffer.begin(extra)
    R.geometry_barrier(extra,G.buffers(resident))
    V.CommandBuffer.bind_graphics_pipeline(extra,pipeline)
    R.bind_geometry(extra,G.buffers(resident))
    V.CommandBuffer.end(extra)
    V.Device.submit(device,extra,wait)
    completed:U32 <- V.Fence.wait(wait,Core.whole_size())
    Error.require(U32.is_zero(completed),"Retaining command did not complete")
    renderer:R.Renderer <- replace(renderer,green(),True{})
    live(U32.add(base,4),"Published before collection")
    renderer:R.Renderer <- collect(renderer)
    live(U32.add(base,4),"Completed executable command retains both pairs")
    alive(device,vb)
    alive(device,ib)
    renderer:R.Renderer <- removed(renderer,7)
    renderer:R.Renderer <- color_frame(renderer,10,0,255,0,2304)
    renderer:R.Renderer <- color_frame(renderer,9,0,255,0,1128)
    live(U32.add(base,4),"Ordinary frames cannot collect retained allocations")
    V.CommandBuffer.reset(extra)
    live(U32.add(base,4),"Reset releases references without implicit collection")
    renderer:R.Renderer <- collect(renderer)
    live(base,"Collection removes exactly two buffers and two memories")
    gone(device,vb)
    gone(device,ib)
    renderer:R.Renderer <- repeat(3n,renderer)
    renderer:R.Renderer <- collect(renderer)
    live(base,"Repeated nonempty and empty replacement")
    V.Device.destroy_command_pool(device,pool)
    V.Device.destroy_fence(device,wait)
    V.Action.lift(Unit,IO.print("Real recording rejection cleaned candidate; both old allocations readable. Completed executable command retained both old buffers and memories until reset plus collection. Changed ranges, removed IDs, repeated empty transitions and exact RGBA passed."))

def invalid_checked(renderer:R.Renderer,+first:R.Readback) -> V.Action(Unit):
  R.Renderer{+resources,+config,+resident,+offset,+used} = renderer
  do V.Action<Unit>:
    +base:U32 <- V.debug_live_objects()
    renderer:R.Renderer <- replace(R.Renderer{resources,config,resident,offset,used},invalid(),False{})
    live(base,"Invalid candidate allocated nothing")
    renderer:R.Renderer <- equal_frame(renderer,7,first)
    buffers:G.Buffers <- retained_buffers(resident)
    lifetime(renderer,first,buffers)

def baseline(pair:R.Renderer & R.Readback) -> V.Action(Unit):
  (renderer,+first) = pair
  R.Readback{w,h,+rgba,depth} = first
  do V.Action<Unit>:
    Error.require(U32.is_eq(pixels(rgba,255,0,0),2304),"Initial red square coverage differs")
    invalid_checked(renderer,first)

def run(entry:V.Entry) -> V.Action(Unit):
  do V.Action<Unit>:
    renderer:R.Renderer <- R.create(entry,R.Config{64,64,camera()},red())
    pair:R.Renderer & R.Readback <- Existing.frame(renderer,draws(7))
    baseline(pair)

def finished(pair:V.VkResult(Unit) & U32) -> IO(Unit):
  (result,count) = pair
  do IO<Unit>:
    V.or_exit(Unit,result)
    Check:V.VkResult(Unit) <- Error.require(U32.is_zero(count),"Replacement leaked native resources")
    V.or_exit(Unit,Check)
    IO.print("Mesh replacement offscreen and native retention verified; live Vulkan objects: 0")

def main() -> IO(Unit):
  do IO<Unit>:
    pair:V.VkResult(Unit) & U32 <- Scope.with(Unit,run)
    finished(pair)
