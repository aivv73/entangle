import Base
import ./measurement-counters.bend as Count
import ./scene-diagnostics.bend as Diag
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
  Renderer{window:Indexed.Renderer,target:Maybe<Indexed.Target>,mesh_id:U32,index_count:U32,probe:Diag.Probe}
type InputError is Data:
  InvalidCamera{}
  InvalidDrawing{error:R.InputError}

def bound(buffer:R.Buffer) -> Mesh.BoundBuffer:
  R.Buffer{buffer,memory} = buffer
  Mesh.BoundBuffer{buffer,memory}

def check_limits(limits:V.PhysicalDeviceLimits) -> V.Action(Unit):
  V.PhysicalDeviceLimits{dimension,fw,fh,colors,push,attrs,bindings,offset,stride,allocs,atom,alignment,row,granularity} = limits
  R.require(U32.is_ge(push,64) && U32.is_ge(attrs,2) && U32.is_ge(bindings,1) && U32.is_ge(offset,12) && U32.is_ge(stride,24),"Insufficient mesh device limits")

def diagnostics(on:Bool,device:V.Device) -> V.Action(Diag.Probe):
  match on:
    case False{}:V.Action.pure(Diag.Probe,Diag.Off{})
    case True{}:V.Action.lift(Diag.Probe,Diag.create(device))

def uploaded(result:List<U32> & U32,+device:V.Device,memory:V.DeviceMemory,+probe:Diag.Probe,name:String) -> V.Action(Diag.Probe):
  (bytes,count) = result
  do V.Action<Diag.Probe>:
    start:Diag.Metric<&2,W.U64> <- V.Action.lift(Diag.Metric<&2,W.U64>,Diag.now(Diag.enabled(probe)))
    V.Device.write_memory(device,memory,W.zero(),bytes)
    probe:Diag.Probe = Diag.upload(probe,U32.div(count,4))
    V.Action.lift(Diag.Probe,Diag.span(probe,name,start))

def upload(device:V.Device,memory:V.DeviceMemory,bytes:List<U32>,probe:Diag.Probe,name:String) -> V.Action(Diag.Probe):
  uploaded(R.payload_size(bytes),device,memory,probe,name)

def render_span(probe:Diag.Probe,start:Diag.Metric<&2,W.U64>,end:Diag.Metric<&2,W.U64>) -> Diag.Probe:
  match probe:
    case Diag.Off{}:Diag.Off{}
    case Diag.On{owner,props,active,generation,startup,counters,spans,outcome,gpu}:
      Diag.On{owner,props,active,generation,startup,counters,Diag.Span{"render_wait",Diag.elapsed(start,end)} <> spans,outcome,gpu}

def create(+context:Host.Context,mesh:R.Mesh,+measured:Bool) -> V.Action(Renderer):
  Host.Context{window,+instance,+physical,surface,+device,g,p} = context
  R.Mesh{id,+vertices,+indices} = mesh
  do V.Action<Renderer>:
    limits : V.PhysicalDeviceLimits <- V.Instance.get_physical_device_limits(instance,physical)
    check_limits(limits)
    +vb : R.Buffer <- R.buffer(instance,physical,device,W.of_u32(U32.mul(U32.from_nat(List.length(&2,R.Vertex,vertices)),24)),vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT())
    +ib : R.Buffer <- R.buffer(instance,physical,device,W.of_u32(U32.mul(U32.from_nat(List.length(&2,U32,indices)),4)),vk.VK_BUFFER_USAGE_INDEX_BUFFER_BIT())
    probe:Diag.Probe <- diagnostics(measured,device)
    probe:Diag.Probe <- upload(device,R.buffer_memory(vb),R.vertices_bytes(vertices),probe,"mesh_vertex_host_write")
    probe:Diag.Probe <- upload(device,R.buffer_memory(ib),R.indices_bytes(indices),probe,"mesh_index_host_write")
    +pool : V.CommandPool <- V.Device.create_command_pool(device)
    command : V.CommandBuffer <- V.Device.allocate_command_buffer(device,pool)
    acquire : V.Fence <- V.Device.create_fence(device,False{})
    render : V.Fence <- V.Device.create_fence(device,False{})
    present : V.Fence <- V.Device.create_fence(device,False{})
    finished : V.Semaphore <- V.Device.create_semaphore(device)
    return Renderer{Indexed.Renderer{context,bound(vb),bound(ib),pool,command,acquire,render,present,finished},None{},id,U32.from_nat(List.length(&2,U32,indices)),probe}

# The window pipeline culls back faces. Supply a closed, consistently wound mesh.
def open(entry:V.Entry,title:String,+mesh:R.Mesh) -> V.Action(Renderer):
  do V.Action<Renderer>:
    R.require(R.mesh_valid(mesh),"Invalid mesh")
    context : Host.Context <- Host.open(entry,title,False{})
    create(context,mesh,False{})

def open_measured(entry:V.Entry,title:String,+mesh:R.Mesh) -> V.Action(Renderer):
  do V.Action<Renderer>:
    R.require(R.mesh_valid(mesh),"Invalid mesh")
    context:Host.Context <- Host.open(entry,title,False{})
    create(context,mesh,True{})

def poll(renderer:Renderer) -> V.Action(Renderer & V.WindowSnapshot):
  Renderer{+window,target,id,count,probe} = renderer
  Indexed.Renderer{Host.Context{native,instance,physical,surface,device,g,p},vertices,indices,pool,command,acquire,render,present,finished} = window
  do V.Action<Renderer & V.WindowSnapshot>:
    snapshot : V.WindowSnapshot <- V.NativeWindow.poll(native,16)
    return (Renderer{window,target,id,count,probe},snapshot)

def record(renderer: Indexed.Renderer, target: Indexed.Target, frame: Indexed.Frame, +lease: V.Acquisition, camera: M.Mat4, count:U32, items:List<&2,Draw.DrawItem>,+probe:Diag.Probe) -> V.Action(Diag.Probe):
  Indexed.Renderer{Host.Context{window,instance,physical,surface,+device,g,p},Mesh.BoundBuffer{+vertices,vm},Mesh.BoundBuffer{+indices,im},pool,+command,acquire,+render,+present,+finished} = renderer
  Indexed.Target{swapchain,+w,+h,rw,rh,Mesh.Attachment{depth,dm,dv},pass,layout,pipeline,frames} = target
  Indexed.Frame{+image,view,framebuffer} = frame
  +depth_stages : U32 = U32.or(vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT(),vk.VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT())
  +area : V.RenderArea = V.RenderArea{V.Offset2D{0,0},V.Extent2D{w,h}}
  +on = Diag.enabled(probe)
  do V.Action<Diag.Probe>:
    start:Diag.Metric<&2,W.U64> <- V.Action.lift(Diag.Metric<&2,W.U64>,Diag.now(on))
    V.CommandBuffer.begin(command)
    V.CommandBuffer.use_acquisition(command,lease)
    probe:Diag.Probe <- V.Action.lift(Diag.Probe,Diag.top(probe,command))
    V.CommandBuffer.pipeline_barrier(command,vk.VK_PIPELINE_STAGE_HOST_BIT(),vk.VK_PIPELINE_STAGE_VERTEX_INPUT_BIT(),[],[V.BufferMemoryBarrier{vertices,W.zero(),Core.whole_size(),vk.VK_ACCESS_HOST_WRITE_BIT(),vk.VK_ACCESS_VERTEX_ATTRIBUTE_READ_BIT()},V.BufferMemoryBarrier{indices,W.zero(),Core.whole_size(),vk.VK_ACCESS_HOST_WRITE_BIT(),vk.VK_ACCESS_INDEX_READ_BIT()}],[])
    Mesh.transition(command,image,vk.VK_IMAGE_ASPECT_COLOR_BIT(),vk.VK_IMAGE_LAYOUT_UNDEFINED(),vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL(),vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT(),vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT(),0,vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT())
    Mesh.transition(command,depth,vk.VK_IMAGE_ASPECT_DEPTH_BIT(),vk.VK_IMAGE_LAYOUT_UNDEFINED(),vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL(),depth_stages,depth_stages,0,U32.or(vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT(),vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT()))
    V.CommandBuffer.begin_render_pass(command,framebuffer,area,[V.ColorClear{V.ClearColor{0.055,0.075,0.12,1.0}},V.DepthClear{1.0}])
    V.CommandBuffer.bind_graphics_pipeline(command,pipeline)
    V.CommandBuffer.set_viewport(command,V.Viewport{0.0,0.0,U32.to_f32(w),U32.to_f32(h),0.0,1.0})
    V.CommandBuffer.set_scissor(command,area)
    V.CommandBuffer.bind_vertex_buffer(command,0,vertices,W.zero())
    V.CommandBuffer.bind_index_buffer(command,indices,W.zero(),vk.VK_INDEX_TYPE_UINT32())
    counters:Count.Counters <- R.draw_items_counted(command,camera,count,items,on,Count.zero())
    probe:Diag.Probe = Diag.counts(probe,counters)
    V.CommandBuffer.end_render_pass(command)
    Mesh.transition(command,image,vk.VK_IMAGE_ASPECT_COLOR_BIT(),vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL(),vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR(),vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT(),vk.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT(),vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT(),0)
    probe:Diag.Probe <- V.Action.lift(Diag.Probe,Diag.bottom(probe,command))
    V.CommandBuffer.end(command)
    probe:Diag.Probe <- V.Action.lift(Diag.Probe,Diag.span(probe,"record",start))
    +before_submit:Diag.Metric<&2,W.U64> <- V.Action.lift(Diag.Metric<&2,W.U64>,Diag.now(on))
    V.Device.submit_synced(device,command,render,[],[finished])
    probe:Diag.Probe = Diag.submit(probe)
    probe:Diag.Probe <- V.Action.lift(Diag.Probe,Diag.span(probe,"submit",before_submit))
    start:Diag.Metric<&2,W.U64> <- V.Action.lift(Diag.Metric<&2,W.U64>,Diag.now(on))
    status:U32 <- V.Fence.wait(render,Core.whole_size())
    R.require(U32.is_zero(status),"Window render fence did not complete")
    +after_wait:Diag.Metric<&2,W.U64> <- V.Action.lift(Diag.Metric<&2,W.U64>,Diag.now(on))
    probe:Diag.Probe = render_span(probe,start,after_wait)
    start:Diag.Metric<&2,W.U64> <- V.Action.lift(Diag.Metric<&2,W.U64>,Diag.now(on))
    probe:Diag.Probe <- V.Action.lift(Diag.Probe,Diag.read(probe,device,Diag.elapsed(before_submit,after_wait)))
    probe:Diag.Probe <- V.Action.lift(Diag.Probe,Diag.span(probe,"query_read_and_conversion",start))
    start:Diag.Metric<&2,W.U64> <- V.Action.lift(Diag.Metric<&2,W.U64>,Diag.now(on))
    V.Fence.reset(render)
    probe:Diag.Probe <- V.Action.lift(Diag.Probe,Diag.span(probe,"render_fence_reset",start))
    start:Diag.Metric<&2,W.U64> <- V.Action.lift(Diag.Metric<&2,W.U64>,Diag.now(on))
    V.CommandBuffer.reset(command)
    V.Action.lift(Diag.Probe,Diag.span(probe,"command_reset",start))

def acquired(outcome: V.AcquireOutcome, +renderer: Indexed.Renderer, +target: Indexed.Target, camera: M.Mat4, count:U32, items:List<&2,Draw.DrawItem>,+probe:Diag.Probe) -> V.Action(Bool & Diag.Probe):
  match outcome:
    case V.AcquireOutOfDate{}: V.Action.pure(Bool & Diag.Probe,(True{},Diag.outcome(probe,Diag.Skipped{"acquire out of date"})))
    case V.AcquireNotReady{}: V.Action.pure(Bool & Diag.Probe,(False{},Diag.outcome(probe,Diag.Skipped{"acquire not ready"})))
    case V.AcquireTimeout{}: V.Action.pure(Bool & Diag.Probe,(False{},Diag.outcome(probe,Diag.Skipped{"acquire timeout"})))
    case V.AcquireSurfaceLost{}: IO.pure(V.VkResult(Bool & Diag.Probe),Fail{(1610612739,"Acquisition surface lost")})
    case V.Acquired{+lease,index,+suboptimal}:
      Indexed.Renderer{Host.Context{window,instance,physical,surface,device,g,p},vertices,indices,pool,command,acquire,render,+present,finished} = renderer
      Indexed.Target{swapchain,w,h,rw,rh,depth,pass,layout,pipeline,frames} = target
      +on = Diag.enabled(probe)
      do V.Action<Bool & Diag.Probe>:
        start:Diag.Metric<&2,W.U64> <- V.Action.lift(Diag.Metric<&2,W.U64>,Diag.now(on))
        Indexed.wait(acquire)
        probe:Diag.Probe <- V.Action.lift(Diag.Probe,Diag.span(probe,"acquire_wait_and_reset",start))
        frame : Indexed.Frame <- Indexed.frame_at(frames,index)
        probe:Diag.Probe <- record(renderer,target,frame,lease,camera,count,items,probe)
        start:Diag.Metric<&2,W.U64> <- V.Action.lift(Diag.Metric<&2,W.U64>,Diag.now(on))
        +outcome : V.PresentOutcome <- V.Device.present(device,lease,finished,present)
        probe:Diag.Probe <- V.Action.lift(Diag.Probe,Diag.span(probe,"present_call",start))
        start:Diag.Metric<&2,W.U64> <- V.Action.lift(Diag.Metric<&2,W.U64>,Diag.now(on))
        Indexed.wait(present)
        probe:Diag.Probe <- V.Action.lift(Diag.Probe,Diag.span(probe,"present_wait_and_reset",start))
        rebuild:Bool <- Indexed.presented(outcome,suboptimal)
        return (rebuild,Diag.outcome(probe,Diag.Completed{outcome,suboptimal}))

def draw(+renderer: Indexed.Renderer, +target: Indexed.Target, camera: M.Mat4, count:U32, items:List<&2,Draw.DrawItem>,+probe:Diag.Probe) -> V.Action(Bool & Diag.Probe):
  Indexed.Renderer{Host.Context{window,instance,physical,surface,device,g,p},vertices,indices,pool,command,acquire,render,present,finished} = renderer
  Indexed.Target{swapchain,w,h,rw,rh,depth,pass,layout,pipeline,frames} = target
  do V.Action<Bool & Diag.Probe>:
    start:Diag.Metric<&2,W.U64> <- V.Action.lift(Diag.Metric<&2,W.U64>,Diag.now(Diag.enabled(probe)))
    outcome : V.AcquireOutcome <- V.Device.acquire(device,swapchain,acquire,W.of_u32(16000000))
    probe:Diag.Probe <- V.Action.lift(Diag.Probe,Diag.span(probe,"acquire_call",start))
    acquired(outcome,renderer,target,camera,count,items,probe)

def retired(pair:Bool & Diag.Probe,window:Indexed.Renderer,value:Indexed.Target,+device:V.Device,id:U32,count:U32) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  (rebuild,+probe) = pair
  do V.Action<Renderer & Result<&2,&2,InputError,Unit>>:
    start:Diag.Metric<&2,W.U64> <- V.Action.lift(Diag.Metric<&2,W.U64>,Diag.now(Diag.enabled(probe)))
    next:Maybe<Indexed.Target> <- Indexed.retire(rebuild,value,device)
    probe:Diag.Probe <- V.Action.lift(Diag.Probe,Diag.span(probe,"retirement",start))
    return (Renderer{window,next,id,count,probe},Done{Unit{}})

def checked(result:Result<&2,&2,R.InputError,Unit>,renderer:Renderer,+camera:M.Mat4,items:List<&2,Draw.DrawItem>) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  match result:
    case Fail{error}:V.Action.pure(Renderer & Result<&2,&2,InputError,Unit>,(renderer,Fail{InvalidDrawing{error}}))
    case Done{_}:
      Renderer{+window,target,id,+count,probe} = renderer
      Indexed.Renderer{Host.Context{native,instance,physical,surface,+device,g,p},vertices,indices,pool,command,acquire,render,present,finished} = window
      match target:
        case None{}:V.Action.pure(Renderer & Result<&2,&2,InputError,Unit>,(Renderer{window,None{},id,count,probe},Done{Unit{}}))
        case Some{+value}:
          do V.Action<Renderer & Result<&2,&2,InputError,Unit>>:
            pair:Bool & Diag.Probe <- draw(window,value,camera,count,items,probe)
            retired(pair,window,value,device,id,count)

def visible(valid:Bool,drawable:Bool,renderer:Renderer,+camera:M.Mat4,draws:Draw.DrawList) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  match valid drawable:
    case False{} _:V.Action.pure(Renderer & Result<&2,&2,InputError,Unit>,(renderer,Fail{InvalidCamera{}}))
    case True{} False{}:V.Action.pure(Renderer & Result<&2,&2,InputError,Unit>,(renderer,Done{Unit{}}))
    case True{} True{}:
      Renderer{window,target,+id,count,probe} = renderer
      Draw.DrawList{+items} = draws
      checked(R.preflight(camera,id,items,0),Renderer{window,target,id,count,probe},camera,items)

def close(renderer:Renderer) -> V.Action(Unit):
  Renderer{window,target,id,count,probe} = renderer
  Indexed.Renderer{Host.Context{native,instance,physical,surface,+device,g,p},vertices,indices,pool,command,acquire,render,present,finished} = window
  do V.Action<Unit>:
    V.CommandBuffer.reset(command)
    Diag.close(probe,device)
    Indexed.destroy(target,device)

def target_extent(window:Indexed.Renderer,id:U32,count:U32,+value:Indexed.Target,probe:Diag.Probe) -> Renderer & (U32 & U32):
  Indexed.Target{swapchain,w,h,rw,rh,depth,pass,layout,pipeline,frames} = value
  (Renderer{window,Some{value},id,count,probe},(w,h))

def extent_visible(drawable:Bool,renderer:Renderer,+width:U32,+height:U32) -> V.Action(Renderer & (U32 & U32)):
  match drawable:
    case False{}:V.Action.pure(Renderer & (U32 & U32),(renderer,(U32.max(1,width),U32.max(1,height))))
    case True{}:
      Renderer{+window,current,id,count,probe} = renderer
      Indexed.Renderer{+context,vertices,indices,pool,command,acquire,render,present,finished} = window
      do V.Action<Renderer & (U32 & U32)>:
        value : Indexed.Target <- Indexed.ensure(current,context,width,height)
        return target_extent(window,id,count,value,probe)


def adapted(matrix:Maybe<M.Mat4>,renderer:Renderer,drawable:Bool,draws:Draw.DrawList) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  match matrix:
    case None{}:V.Action.pure(Renderer & Result<&2,&2,InputError,Unit>,(renderer,Fail{InvalidCamera{}}))
    case Some{+camera}:visible(R.matrix_finite(camera),drawable,renderer,camera,draws)

def preflight_measured(result:Result<&2,&2,R.InputError,Unit>,renderer:Renderer,camera:M.Mat4,items:List<&2,Draw.DrawItem>,start:Diag.Metric<&2,W.U64>) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  Renderer{window,target,id,count,probe} = renderer
  do V.Action<Renderer & Result<&2,&2,InputError,Unit>>:
    probe:Diag.Probe <- V.Action.lift(Diag.Probe,Diag.span(probe,"view_preflight",start))
    checked(result,Renderer{window,target,id,count,probe},camera,items)

def camera_items(renderer:Renderer,+camera:M.Mat4,id:U32,+items:List<&2,Draw.DrawItem>,start:Diag.Metric<&2,W.U64>) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  preflight_measured(R.preflight(camera,id,items,0),renderer,camera,items,start)

def camera_measured(valid:Bool,renderer:Renderer,+camera:M.Mat4,+id:U32,items:List<&2,Draw.DrawItem>,start:Diag.Metric<&2,W.U64>) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  match valid:
    case False{}:V.Action.pure(Renderer & Result<&2,&2,InputError,Unit>,(renderer,Fail{InvalidCamera{}}))
    case True{}:camera_items(renderer,camera,id,items,start)

def view_measured(renderer:Renderer,draws:Draw.DrawList,matrix:Maybe<M.Mat4>,drawable:Bool,start:Diag.Metric<&2,W.U64>) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  Renderer{window,target,+id,count,probe} = renderer
  Draw.DrawList{+items} = draws
  match matrix drawable:
    case Some{+camera} True{}:
      camera_measured(R.matrix_finite(camera),Renderer{window,target,id,count,probe},camera,id,items,start)
    case _ _:adapted(matrix,Renderer{window,target,id,count,probe},drawable,Draw.DrawList{items})

def framed(pair:Renderer & (U32 & U32),drawable:Bool,view:U32 -> U32 -> Maybe<M.Mat4>,draws:Draw.DrawList) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  (Renderer{window,target,id,count,+probe},(width,height)) = pair
  do V.Action<Renderer & Result<&2,&2,InputError,Unit>>:
    start:Diag.Metric<&2,W.U64> <- V.Action.lift(Diag.Metric<&2,W.U64>,Diag.now(Diag.enabled(probe)))
    view_measured(Renderer{window,target,id,count,probe},draws,view(width)(height),drawable,start)

def extent_measured(pair:Renderer & (U32 & U32),drawable:Bool,view:U32 -> U32 -> Maybe<M.Mat4>,draws:Draw.DrawList,start:Diag.Metric<&2,W.U64>) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  (Renderer{window,target,id,count,probe},extent) = pair
  do V.Action<Renderer & Result<&2,&2,InputError,Unit>>:
    probe:Diag.Probe <- V.Action.lift(Diag.Probe,Diag.span(probe,"target_upkeep",start))
    framed((Renderer{window,target,id,count,probe},extent),drawable,view,draws)

def frame_started(renderer:Renderer,+drawable:Bool,width:U32,height:U32,view:U32 -> U32 -> Maybe<M.Mat4>,draws:Draw.DrawList) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  Renderer{window,target,id,count,probe} = renderer
  +probe = Diag.begin(probe)
  do V.Action<Renderer & Result<&2,&2,InputError,Unit>>:
    start:Diag.Metric<&2,W.U64> <- V.Action.lift(Diag.Metric<&2,W.U64>,Diag.now(Diag.enabled(probe)))
    pair:Renderer & (U32 & U32) <- extent_visible(drawable,Renderer{window,target,id,count,probe},width,height)
    extent_measured(pair,drawable,view,draws,start)

# Build the view at the actual target extent. Rejected input never acquires an image.
# Target replacement by ensure precedes validation and is retained on rejection.
def frame(renderer:Renderer,snapshot:V.WindowSnapshot,view:U32 -> U32 -> Maybe<M.Mat4>,draws:Draw.DrawList) -> V.Action(Renderer & Result<&2,&2,InputError,Unit>):
  V.WindowSnapshot{+width,+height,+mapped,focused,captured,events} = snapshot
  frame_started(renderer,Core.drawable(mapped,width,height),width,height,view,draws)

def probe_spans(probe:Diag.Probe) -> List<&2,Diag.Span>:
  match probe:
    case Diag.Off{}:[]
    case Diag.On{owner,props,active,generation,startup,counters,spans,outcome,gpu}:spans

def setup_spans(renderer:Renderer) -> Renderer & List<&2,Diag.Span>:
  Renderer{window,target,id,count,+probe} = renderer
  (Renderer{window,target,id,count,probe},probe_spans(probe))

def device_info(renderer:Renderer) -> V.Action(Renderer & (V.PhysicalDeviceProperties & (U32 & U32))):
  Renderer{+window,target,id,count,probe} = renderer
  Indexed.Renderer{Host.Context{native,+instance,+physical,surface,device,+g,+p},vertices,indices,pool,command,acquire,render,present,finished} = window
  do V.Action<Renderer & (V.PhysicalDeviceProperties & (U32 & U32))>:
    props:V.PhysicalDeviceProperties <- V.Instance.get_physical_device_properties(instance,physical)
    return (Renderer{window,target,id,count,probe},(props,(g,p)))

def target_stable(value:Maybe<Indexed.Target>,+accepted:U32) -> Bool:
  match value:
    case None{}:U32.is_zero(accepted)
    case Some{Indexed.Target{swapchain,w,h,rw,rh,depth,pass,layout,pipeline,frames}}:
      U32.is_eq(w,640) && U32.is_eq(h,480) && U32.is_eq(rw,640) && U32.is_eq(rh,480)

def require_stable(renderer:Renderer,+accepted:U32) -> V.Action(Renderer):
  Renderer{window,target,id,count,probe} = renderer
  match target:
    case None{}:
      do V.Action<Renderer>:
        R.require(U32.is_zero(accepted),"Baseline target retired; repeat invalid; partial counters unavailable")
        return Renderer{window,None{},id,count,probe}
    case Some{+value}:
      do V.Action<Renderer>:
        R.require(target_stable(Some{value},accepted),"Baseline target rebuilt; repeat invalid; partial counters unavailable")
        return Renderer{window,Some{value},id,count,probe}
