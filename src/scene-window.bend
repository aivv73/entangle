import Base
import ./scene-render.bend as R
import ./scene-draw.bend as Draw
import ./scene-matrix.bend as M
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/core.bend as Core
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W
import ../deps/bend-vulkan/examples/window.bend as Host
import ../deps/bend-vulkan/examples/indexed_window.bend as Indexed
import ../deps/bend-vulkan/examples/indexed_offscreen.bend as Mesh

type Renderer is Type:
  Renderer{window:Indexed.Renderer,target:Maybe<Indexed.Target>,mesh_id:U32,index_count:U32}
type InputError is Data:
  InvalidCamera{}
  InvalidDrawing{error:R.InputError}

def bound(buffer:R.Buffer) -> Mesh.BoundBuffer:
  R.Buffer{buffer,memory} = buffer
  Mesh.BoundBuffer{buffer,memory}

def check_limits(limits:V.PhysicalDeviceLimits) -> V.Action(Unit):
  V.PhysicalDeviceLimits{dimension,fw,fh,colors,push,attrs,bindings,offset,stride,allocs,atom,alignment,row,granularity} = limits
  R.require(U32.is_ge(push,64) && U32.is_ge(attrs,2) && U32.is_ge(bindings,1) && U32.is_ge(offset,12) && U32.is_ge(stride,24),"Insufficient mesh device limits")

def create(+context:Host.Context,mesh:R.Mesh) -> V.Action(Renderer):
  Host.Context{window,+instance,+physical,surface,+device,g,p} = context
  R.Mesh{id,+vertices,+indices} = mesh
  do V.Action<Renderer>:
    limits : V.PhysicalDeviceLimits <- V.Instance.get_physical_device_limits(instance,physical)
    check_limits(limits)
    +vb : R.Buffer <- R.buffer(instance,physical,device,W.of_u32(U32.mul(U32.from_nat(List.length(&2,R.Vertex,vertices)),24)),vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT())
    +ib : R.Buffer <- R.buffer(instance,physical,device,W.of_u32(U32.mul(U32.from_nat(List.length(&2,U32,indices)),4)),vk.VK_BUFFER_USAGE_INDEX_BUFFER_BIT())
    V.Device.write_memory(device,R.buffer_memory(vb),W.zero(),R.vertices_bytes(vertices))
    V.Device.write_memory(device,R.buffer_memory(ib),W.zero(),R.indices_bytes(indices))
    +pool : V.CommandPool <- V.Device.create_command_pool(device)
    command : V.CommandBuffer <- V.Device.allocate_command_buffer(device,pool)
    acquire : V.Fence <- V.Device.create_fence(device,False{})
    render : V.Fence <- V.Device.create_fence(device,False{})
    present : V.Fence <- V.Device.create_fence(device,False{})
    finished : V.Semaphore <- V.Device.create_semaphore(device)
    return Renderer{Indexed.Renderer{context,bound(vb),bound(ib),pool,command,acquire,render,present,finished},None{},id,U32.from_nat(List.length(&2,U32,indices))}

# The window pipeline culls back faces. Supply a closed, consistently wound mesh.
def open(entry:V.Entry,title:String,+mesh:R.Mesh) -> V.Action(Renderer):
  do V.Action<Renderer>:
    R.require(R.mesh_valid(mesh),"Invalid mesh")
    context : Host.Context <- Host.open(entry,title,False{})
    create(context,mesh)

def poll(renderer:Renderer) -> V.Action(Renderer & V.WindowSnapshot):
  Renderer{+window,target,id,count} = renderer
  Indexed.Renderer{Host.Context{native,instance,physical,surface,device,g,p},vertices,indices,pool,command,acquire,render,present,finished} = window
  do V.Action<Renderer & V.WindowSnapshot>:
    snapshot : V.WindowSnapshot <- V.NativeWindow.poll(native,16)
    return (Renderer{window,target,id,count},snapshot)

def record(renderer: Indexed.Renderer, target: Indexed.Target, frame: Indexed.Frame, +lease: V.Acquisition, camera: M.Mat4, count:U32, items:List<&2,Draw.DrawItem>) -> V.Action(Unit):
  Indexed.Renderer{Host.Context{window,instance,physical,surface,+device,g,p},Mesh.BoundBuffer{+vertices,vm},Mesh.BoundBuffer{+indices,im},pool,+command,acquire,+render,+present,+finished} = renderer
  Indexed.Target{swapchain,+w,+h,rw,rh,Mesh.Attachment{depth,dm,dv},pass,layout,pipeline,frames} = target
  Indexed.Frame{+image,view,framebuffer} = frame
  +depth_stages : U32 = U32.or(vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT(),vk.VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT())
  +area : V.RenderArea = V.RenderArea{V.Offset2D{0,0},V.Extent2D{w,h}}
  do V.Action<Unit>:
    V.CommandBuffer.begin(command)
    V.CommandBuffer.use_acquisition(command,lease)
    V.CommandBuffer.pipeline_barrier(command,vk.VK_PIPELINE_STAGE_HOST_BIT(),vk.VK_PIPELINE_STAGE_VERTEX_INPUT_BIT(),[],[V.BufferMemoryBarrier{vertices,W.zero(),Core.whole_size(),vk.VK_ACCESS_HOST_WRITE_BIT(),vk.VK_ACCESS_VERTEX_ATTRIBUTE_READ_BIT()},V.BufferMemoryBarrier{indices,W.zero(),Core.whole_size(),vk.VK_ACCESS_HOST_WRITE_BIT(),vk.VK_ACCESS_INDEX_READ_BIT()}],[])
    Mesh.transition(command,image,vk.VK_IMAGE_ASPECT_COLOR_BIT(),vk.VK_IMAGE_LAYOUT_UNDEFINED(),vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL(),vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT(),vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT(),0,vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT())
    Mesh.transition(command,depth,vk.VK_IMAGE_ASPECT_DEPTH_BIT(),vk.VK_IMAGE_LAYOUT_UNDEFINED(),vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL(),depth_stages,depth_stages,0,U32.or(vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT(),vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT()))
    V.CommandBuffer.begin_render_pass(command,framebuffer,area,[V.ColorClear{V.ClearColor{0.055,0.075,0.12,1.0}},V.DepthClear{1.0}])
    V.CommandBuffer.bind_graphics_pipeline(command,pipeline)
    V.CommandBuffer.set_viewport(command,V.Viewport{0.0,0.0,U32.to_f32(w),U32.to_f32(h),0.0,1.0})
    V.CommandBuffer.set_scissor(command,area)
    V.CommandBuffer.bind_vertex_buffer(command,0,vertices,W.zero())
    V.CommandBuffer.bind_index_buffer(command,indices,W.zero(),vk.VK_INDEX_TYPE_UINT32())
    R.draw_items(command,camera,count,items)
    V.CommandBuffer.end_render_pass(command)
    Mesh.transition(command,image,vk.VK_IMAGE_ASPECT_COLOR_BIT(),vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL(),vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR(),vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT(),vk.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT(),vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT(),0)
    V.CommandBuffer.end(command)
    V.Device.submit_synced(device,command,render,[],[finished])
    Indexed.wait(render)
    V.CommandBuffer.reset(command)

def acquired(outcome: V.AcquireOutcome, +renderer: Indexed.Renderer, +target: Indexed.Target, camera: M.Mat4, count:U32, items:List<&2,Draw.DrawItem>) -> V.Action(Bool):
  match outcome:
    case V.AcquireOutOfDate{}: V.Action.pure(Bool,True{})
    case V.AcquireNotReady{}: V.Action.pure(Bool,False{})
    case V.AcquireTimeout{}: V.Action.pure(Bool,False{})
    case V.AcquireSurfaceLost{}: IO.pure(V.VkResult(Bool),Fail{(1610612739,"Acquisition surface lost")})
    case V.Acquired{+lease,index,suboptimal}:
      Indexed.Renderer{Host.Context{window,instance,physical,surface,device,g,p},vertices,indices,pool,command,acquire,render,+present,finished} = renderer
      Indexed.Target{swapchain,w,h,rw,rh,depth,pass,layout,pipeline,frames} = target
      do V.Action<Bool>:
        Indexed.wait(acquire)
        frame : Indexed.Frame <- Indexed.frame_at(frames,index)
        record(renderer,target,frame,lease,camera,count,items)
        outcome : V.PresentOutcome <- V.Device.present(device,lease,finished,present)
        Indexed.wait(present)
        Indexed.presented(outcome,suboptimal)

def draw(+renderer: Indexed.Renderer, +target: Indexed.Target, camera: M.Mat4, count:U32, items:List<&2,Draw.DrawItem>) -> V.Action(Bool):
  Indexed.Renderer{Host.Context{window,instance,physical,surface,device,g,p},vertices,indices,pool,command,acquire,render,present,finished} = renderer
  Indexed.Target{swapchain,w,h,rw,rh,depth,pass,layout,pipeline,frames} = target
  do V.Action<Bool>:
    outcome : V.AcquireOutcome <- V.Device.acquire(device,swapchain,acquire,W.of_u32(16000000))
    acquired(outcome,renderer,target,camera,count,items)

def checked(result:Result<&2,&2,R.InputError,Unit>,renderer:Renderer,+camera:M.Mat4,items:List<&2,Draw.DrawItem>) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  match result:
    case Fail{error}:V.Action.pure(Renderer & Result<&2,&2,InputError,Unit>,(renderer,Fail{InvalidDrawing{error}}))
    case Done{_}:
      Renderer{+window,target,id,+count} = renderer
      Indexed.Renderer{Host.Context{native,instance,physical,surface,+device,g,p},vertices,indices,pool,command,acquire,render,present,finished} = window
      match target:
        case None{}:V.Action.pure(Renderer & Result<&2,&2,InputError,Unit>,(Renderer{window,None{},id,count},Done{Unit{}}))
        case Some{+value}:
          do V.Action<Renderer & Result<&2,&2,InputError,Unit>>:
            rebuild : Bool <- draw(window,value,camera,count,items)
            next : Maybe<Indexed.Target> <- Indexed.retire(rebuild,value,device)
            return (Renderer{window,next,id,count},Done{Unit{}})

def visible(valid:Bool,drawable:Bool,renderer:Renderer,+camera:M.Mat4,draws:Draw.DrawList) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  match valid drawable:
    case False{} _:V.Action.pure(Renderer & Result<&2,&2,InputError,Unit>,(renderer,Fail{InvalidCamera{}}))
    case True{} False{}:V.Action.pure(Renderer & Result<&2,&2,InputError,Unit>,(renderer,Done{Unit{}}))
    case True{} True{}:
      Renderer{window,target,+id,count} = renderer
      Draw.DrawList{+items} = draws
      checked(R.preflight(camera,id,items,0),Renderer{window,target,id,count},camera,items)

def close(renderer:Renderer) -> V.Action(Unit):
  Renderer{window,target,id,count} = renderer
  Indexed.Renderer{Host.Context{native,instance,physical,surface,device,g,p},vertices,indices,pool,command,acquire,render,present,finished} = window
  Indexed.destroy(target,device)

def target_extent(window:Indexed.Renderer,id:U32,count:U32,+value:Indexed.Target) -> Renderer & (U32 & U32):
  Indexed.Target{swapchain,w,h,rw,rh,depth,pass,layout,pipeline,frames} = value
  (Renderer{window,Some{value},id,count},(w,h))

def extent_visible(drawable:Bool,renderer:Renderer,+width:U32,+height:U32) -> V.Action(Renderer & (U32 & U32)):
  match drawable:
    case False{}:V.Action.pure(Renderer & (U32 & U32),(renderer,(U32.max(1,width),U32.max(1,height))))
    case True{}:
      Renderer{+window,current,id,count} = renderer
      Indexed.Renderer{+context,vertices,indices,pool,command,acquire,render,present,finished} = window
      do V.Action<Renderer & (U32 & U32)>:
        value : Indexed.Target <- Indexed.ensure(current,context,width,height)
        return target_extent(window,id,count,value)


def adapted(matrix:Maybe<M.Mat4>,renderer:Renderer,drawable:Bool,draws:Draw.DrawList) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  match matrix:
    case None{}:V.Action.pure(Renderer & Result<&2,&2,InputError,Unit>,(renderer,Fail{InvalidCamera{}}))
    case Some{+camera}:visible(R.matrix_finite(camera),drawable,renderer,camera,draws)

def framed(pair:Renderer & (U32 & U32),drawable:Bool,view:U32 -> U32 -> Maybe<M.Mat4>,draws:Draw.DrawList) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  (renderer,(width,height)) = pair
  adapted(view(width)(height),renderer,drawable,draws)

# Build the view at the actual target extent. Rejected input never acquires an image.
# Target replacement by ensure precedes validation and is retained on rejection.
def frame(renderer:Renderer,snapshot:V.WindowSnapshot,view:U32 -> U32 -> Maybe<M.Mat4>,draws:Draw.DrawList) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  V.WindowSnapshot{+width,+height,+mapped,focused,captured,events} = snapshot
  do V.Action<Renderer & Result<&2,&2,InputError,Unit>>:
    pair : Renderer & (U32 & U32) <- extent_visible(Core.drawable(mapped,width,height),renderer,width,height)
    framed(pair,Core.drawable(mapped,width,height),view,draws)
