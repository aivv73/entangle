import Base
import ./scene-buffer.bend as B
import ./scene-geometry.bend as G
import ./error.bend as Error
import ./measurement-counters.bend as Count
import ./scene-diagnostics.bend as Diag
import ./components.bend as C
import ./scene-draw.bend as Draw
import ./scene-matrix.bend as M
import ./creation.bend as Create
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/core.bend as Core
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W
import ./scene-pipeline.bend as P
import ./scene-materials.bend as Materials
import ./scene-texture.bend as T
import ./lighting.bend as Light

type Config is Data:
  Config{width:U32,height:U32,camera:M.Mat4,light:Light.Light}
type Readback is Data:
  Readback{width:U32,height:U32,rgba:List<&2,U32>,depth:List<&2,U32>}
type InputError is Data:
  UnknownMesh{item:U32,id:U32}
  InvalidTransform{item:U32}
type Attachment is Data:
  Attachment{image:V.ImageHandle,memory:V.DeviceMemory,view:V.ImageView}
type Resources is Data:
  Resources{context:G.Context,command:V.CommandBuffer,fence:V.Fence,framebuffer:V.Framebuffer,pipeline:P.Pipelines,color:Attachment,depth:Attachment,stage:B.Buffer}
type Renderer is Type:
  Renderer{resources:Resources,config:Config,resident:G.Resident,depth_offset:W.U64,used:Bool}

def default_light() -> Light.Light:Light.default()

def choose(value:Maybe<U32>,message:String) -> V.Action(U32):
  match value:
    case Some{index}:V.Action.pure(U32,index)
    case None{}:IO.pure(V.VkResult(U32),Fail{(1,message)})

def first(devices:List<V.PhysicalDevice>) -> V.Action(V.PhysicalDevice):
  match devices:
    case device <> _:V.Action.pure(V.PhysicalDevice,device)
    case []:IO.pure(V.VkResult(V.PhysicalDevice),Fail{(1,"No Vulkan device")})

def known(value:Maybe<Create.Range>) -> Bool:
  match value:
    case None{}:False{}
    case Some{_}:True{}

def preflight_item(same:Bool,valid:Bool,other:U32,index:U32,next:Result<&2,&2,InputError,Unit>) -> Result<&2,&2,InputError,Unit>:
  match same valid:
    case False{} _:Fail{UnknownMesh{index,other}}
    case True{} False{}:Fail{InvalidTransform{index}}
    case True{} True{}:next

def normal_transform(range:Maybe<Create.Range>,transform:C.Transform) -> Bool:
  match range:
    case Some{Create.Range{_,_,_,Some{_}}}:Light.transform_valid(transform)
    case _:True{}

def preflight(+camera:M.Mat4,+ranges:List<&2,Create.Range>,items:List<&2,Draw.DrawItem>,+index:U32) -> Result<&2,&2,InputError,Unit>:
  match items:
    case []:Done{Unit{}}
    case Draw.DrawItem{+t,C.MeshRef{+other}} <> rest:
      preflight_item(known(Create.resolve(ranges,other)),Create.transform_valid(t) && normal_transform(Create.resolve(ranges,other),t) && Create.matrix_finite(M.multiply(camera,M.model(t))),other,index,preflight(camera,ranges,rest,U32.inc(index)))

def allocate(+instance:V.Instance,+physical:V.PhysicalDevice,+device:V.Device,requirements:V.MemoryRequirements,flags:U32) -> V.Action(V.DeviceMemory):
  V.MemoryRequirements{size,_,bits} = requirements
  do V.Action<V.DeviceMemory>:
    types : List<Core.MemoryType> <- V.Instance.get_physical_device_memory_properties(instance,physical)
    index : U32 <- choose(Core.find_memory_type(types,bits,flags),"No compatible memory")
    V.Device.allocate_memory(device,size,index)

def attachment(+instance:V.Instance,+physical:V.PhysicalDevice,+device:V.Device,+extent:V.Extent2D,+format:U32,+aspect:U32,+usage:U32) -> V.Action(Attachment):
  do V.Action<Attachment>:
    supported : V.ImageFormatProperties <- V.Instance.get_physical_device_image_format_properties(instance,physical,V.ImageFormatInfo{format,vk.VK_IMAGE_TYPE_2D(),vk.VK_IMAGE_TILING_OPTIMAL(),usage,0})
    +image : V.ImageHandle <- V.Device.create_image(device,V.ImageCreateInfo{format,extent,1,1,usage})
    req : V.MemoryRequirements <- V.Device.get_image_memory_requirements(device,image)
    +memory : V.DeviceMemory <- allocate(instance,physical,device,req,0)
    V.Device.bind_image_memory(device,image,memory,W.zero())
    view : V.ImageView <- V.Device.create_image_view(device,V.ImageViewCreateInfo{image,1,V.ImageSubresourceRange{aspect,0,1,0,1}})
    return Attachment{image,memory,view}

def aligned(+size:U32,alignment:W.U64) -> W.U64:
  W.U64{+lo,+hi} = alignment
  W.of_u32(U32.mul(U32.div(U32.add(size,U32.sub(lo,1)),lo),lo))

def attachment_view(a:Attachment) -> V.ImageView:
  Attachment{_,_,v} = a
  v

def geometry_barrier(command:V.CommandBuffer,buffers:Maybe<&2,G.Buffers>) -> V.Action(Unit):
  match buffers:
    case None{}:V.Action.pure(Unit,Unit{})
    case Some{G.Buffers{vertices,indices}}:
      vb = B.handle(vertices)
      ib = B.handle(indices)
      V.CommandBuffer.pipeline_barrier(command,vk.VK_PIPELINE_STAGE_HOST_BIT(),vk.VK_PIPELINE_STAGE_VERTEX_INPUT_BIT(),[],[V.BufferMemoryBarrier{vb,W.zero(),Core.whole_size(),vk.VK_ACCESS_HOST_WRITE_BIT(),vk.VK_ACCESS_VERTEX_ATTRIBUTE_READ_BIT()},V.BufferMemoryBarrier{ib,W.zero(),Core.whole_size(),vk.VK_ACCESS_HOST_WRITE_BIT(),vk.VK_ACCESS_INDEX_READ_BIT()}],[])

def bind_geometry(+command:V.CommandBuffer,buffers:Maybe<&2,G.Buffers>) -> V.Action(Unit):
  match buffers:
    case None{}:V.Action.pure(Unit,Unit{})
    case Some{G.Buffers{vertices,indices}}:
      vb = B.handle(vertices)
      ib = B.handle(indices)
      do V.Action<Unit>:
        V.CommandBuffer.bind_vertex_buffer(command,0,vb,W.zero())
        V.CommandBuffer.bind_index_buffer(command,ib,W.zero(),vk.VK_INDEX_TYPE_UINT32())

def create_limited(+instance:V.Instance,+physical:V.PhysicalDevice,family:U32,limits:V.PhysicalDeviceLimits,+config:Config,mesh:Create.Geometry) -> V.Action(Renderer):
  V.PhysicalDeviceLimits{+dimension,fw,fh,colors,push,attrs,bindings,offset,stride,allocs,atom,+alignment,row,granularity} = limits
  W.U64{+alo,ahi} = alignment
  Config{+width,+height,camera,light} = config
  Create.Geometry{+vertices,+indices,+ranges} = mesh
  do V.Action<Renderer>:
    Error.require(U32.is_le(width,dimension) && U32.is_le(height,dimension) && U32.is_le(width,fw) && U32.is_le(height,fh) && U32.is_ge(push,128) && U32.is_ge(attrs,4) && U32.is_ge(bindings,1) && U32.is_ge(offset,32) && U32.is_ge(stride,44),"Insufficient device limits")
    Error.require(U32.is_zero(ahi) && U32.is_gt(alo,0) && U32.is_le(alo,1048576),"Unsupported copy alignment")
    +device : V.Device <- V.Instance.create_device(instance,physical,V.DeviceCreateInfo{family,[]})
    +color : Attachment <- attachment(instance,physical,device,V.Extent2D{width,height},vk.VK_FORMAT_R8G8B8A8_UNORM(),vk.VK_IMAGE_ASPECT_COLOR_BIT(),U32.or(vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT(),vk.VK_IMAGE_USAGE_TRANSFER_SRC_BIT()))
    +depth : Attachment <- attachment(instance,physical,device,V.Extent2D{width,height},vk.VK_FORMAT_D32_SFLOAT(),vk.VK_IMAGE_ASPECT_DEPTH_BIT(),U32.or(vk.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT(),vk.VK_IMAGE_USAGE_TRANSFER_SRC_BIT()))
    pair: G.Resident & Diag.Probe <- G.create(G.Context{instance,physical,device},Create.Geometry{vertices,indices,ranges},Diag.Off{})
    resident:G.Resident = Pair.fst(G.Resident,Diag.Probe,pair)
    +plane : U32 = U32.mul(U32.mul(width,height),4)
    +depth_offset : W.U64 = aligned(plane,alignment)
    +stage : B.Buffer <- B.allocate(instance,physical,device,W.add(depth_offset,W.of_u32(plane)),vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT())
    +pass : V.RenderPass <- V.Device.create_render_pass(device,V.RenderPassCreateInfo{[V.AttachmentInfo{vk.VK_FORMAT_R8G8B8A8_UNORM(),vk.VK_ATTACHMENT_LOAD_OP_CLEAR(),vk.VK_ATTACHMENT_STORE_OP_STORE()}],Some{V.AttachmentInfo{vk.VK_FORMAT_D32_SFLOAT(),vk.VK_ATTACHMENT_LOAD_OP_CLEAR(),vk.VK_ATTACHMENT_STORE_OP_STORE()}}})
    pipeline:P.Pipelines <- P.create(device,pass,vk.VK_FRONT_FACE_CLOCKWISE(),vk.VK_CULL_MODE_NONE())
    framebuffer : V.Framebuffer <- V.Device.create_framebuffer(device,V.FramebufferCreateInfo{pass,[attachment_view(color),attachment_view(depth)],V.Extent2D{width,height}})
    +pool : V.CommandPool <- V.Device.create_command_pool(device)
    command : V.CommandBuffer <- V.Device.allocate_command_buffer(device,pool)
    fence : V.Fence <- V.Device.create_fence(device,False{})
    return Renderer{Resources{G.Context{instance,physical,device},command,fence,framebuffer,pipeline,color,depth,stage},config,resident,depth_offset,False{}}

def create(+entry:V.Entry,+config:Config,mesh:Create.Geometry) -> V.Action(Renderer):
  Config{+width,+height,+camera,light} = config
  Create.Geometry{+vertices,+indices,+ranges} = mesh
  do V.Action<Renderer>:
    Error.require(U32.is_gt(width,0) && U32.is_gt(height,0) && U32.is_le(width,4096) && U32.is_le(height,4096) && U32.is_le(U32.mul(width,height),4194304) && Create.matrix_finite(camera) && Light.valid(light),"Invalid target, camera or light")
    Error.require(Create.geometry_valid(Create.Geometry{vertices,indices,ranges}),"Invalid mesh")
    +instance : V.Instance <- V.Entry.create_instance(entry,V.InstanceCreateInfo.default())
    devices : List<V.PhysicalDevice> <- V.Instance.enumerate_physical_devices(instance)
    +physical : V.PhysicalDevice <- first(devices)
    families : List<(U32 & U32)> <- V.Instance.get_physical_device_queue_family_properties(instance,physical)
    family : U32 <- choose(Core.find_queue_family(families,1),"No graphics queue")
    limits : V.PhysicalDeviceLimits <- V.Instance.get_physical_device_limits(instance,physical)
    create_limited(instance,physical,family,limits,config,Create.Geometry{vertices,indices,ranges})

def with(config:Config,mesh:Create.Geometry,body:Renderer -> V.Action(Unit)) -> V.Action(Unit):
  V.Entry.with(Unit,entry => do V.Action<Unit>:
    renderer : Renderer <- create(entry,config,mesh)
    body(renderer))

def transition(+command:V.CommandBuffer,image:V.ImageHandle,aspect:U32,old:U32,new:U32,src_stage:U32,dst_stage:U32,src:U32,dst:U32) -> V.Action(Unit):
  V.CommandBuffer.pipeline_barrier(command,src_stage,dst_stage,[],[],[V.ImageMemoryBarrier{image,V.ImageSubresourceRange{aspect,0,1,0,1},old,new,src,dst}])

def sized_word(word:U32,pair:List<U32> & U32) -> List<U32> & U32:
  (rest,bytes) = pair
  (word <> rest,U32.add(bytes,4))

def payload_size(words:List<U32>) -> List<U32> & U32:
  match words:
    case []:([],0)
    case word <> rest:
      sized_word(word,payload_size(rest))

def draw_item(+command:V.CommandBuffer,range:Create.Range,+on:Bool,+counters:Count.Counters,pair:List<U32> & U32) -> V.Action(Count.Counters):
  Create.Range{_,first,count,_} = range
  (payload,bytes) = pair
  do V.Action<Count.Counters>:
    V.CommandBuffer.push_constants(command,payload)
    +counters:Count.Counters = Bool.pick(Count.Counters,on,Count.push(counters,bytes),counters)
    V.CommandBuffer.draw_indexed(command,V.IndexedDraw{count,1,first,V.BaseVertex{0},0})
    +counters:Count.Counters = Bool.pick(Count.Counters,on,Count.draw(counters),counters)
    return counters

def lit_draw(+command:V.CommandBuffer,pipelines:P.Pipelines,range:Create.Range,buffers:Maybe<&2,G.Buffers>,material:Maybe<T.Material>,camera:M.Mat4,transform:C.Transform,light:Light.Light,on:Bool,counters:Count.Counters) -> V.Action(Count.Counters):
  match material:
    case None{}:Error.failure(Count.Counters,1,"Missing resident texture")
    case Some{T.Material{set,_}}:
      do V.Action<Count.Counters>:
        V.CommandBuffer.bind_graphics_pipeline(command,P.textured(pipelines))
        bind_geometry(command,buffers)
        V.CommandBuffer.bind_descriptor_sets(command,0,[set])
        draw_item(command,range,on,counters,payload_size(Light.payload(camera,transform,light)))

def draw_range(+range:Create.Range,+command:V.CommandBuffer,pipelines:P.Pipelines,+resident:G.Resident,camera:M.Mat4,transform:C.Transform,light:Light.Light,on:Bool,counters:Count.Counters) -> V.Action(Count.Counters):
  Create.Range{id,_,_,image} = range
  match image:
    case None{}:
      do V.Action<Count.Counters>:
        V.CommandBuffer.bind_graphics_pipeline(command,P.basic(pipelines))
        bind_geometry(command,G.buffers(resident))
        draw_item(command,range,on,counters,payload_size(M.matrix_words(M.multiply(camera,M.model(transform)))))
    case Some{_}:lit_draw(command,pipelines,range,G.buffers(resident),Materials.material(G.materials(resident),id),camera,transform,light,on,counters)

def draw_resolved(range:Maybe<Create.Range>,+command:V.CommandBuffer,+pipelines:P.Pipelines,+resident:G.Resident,+camera:M.Mat4,+transform:C.Transform,light:Light.Light,on:Bool,counters:Count.Counters) -> V.Action(Count.Counters):
  match range:
    case None{}:Error.failure(Count.Counters,1,"Unresolved preflight range")
    case Some{Create.Range{_,_,0,_}}:V.Action.pure(Count.Counters,counters)
    case Some{+range}:
      draw_range(range,command,pipelines,resident,camera,transform,light,on,counters)

def draw_items_counted(+command:V.CommandBuffer,+pipelines:P.Pipelines,+camera:M.Mat4,+light:Light.Light,+resident:G.Resident,items:List<&2,Draw.DrawItem>,+on:Bool,+counters:Count.Counters) -> V.Action(Count.Counters):
  match items:
    case []:V.Action.pure(Count.Counters,counters)
    case Draw.DrawItem{+t,C.MeshRef{+id}} <> rest:
      do V.Action<Count.Counters>:
        counters:Count.Counters <- draw_resolved(Create.resolve(G.ranges(resident),id),command,pipelines,resident,camera,t,light,on,counters)
        draw_items_counted(command,pipelines,camera,light,resident,rest,on,counters)

def draw_items(command:V.CommandBuffer,pipelines:P.Pipelines,camera:M.Mat4,light:Light.Light,resident:G.Resident,items:List<&2,Draw.DrawItem>) -> V.Action(Unit):
  do V.Action<Unit>:
    counters:Count.Counters <- draw_items_counted(command,pipelines,camera,light,resident,items,False{},Count.zero())
    return Unit{}


def reusable(values:List<U32>) -> List<&2,U32>:
  match values:
    case []:[]
    case x <> rest:x <> reusable(rest)

def frame(+r:Resources,+config:Config,+resident:G.Resident,+depth_offset:W.U64,+used:Bool,items:List<&2,Draw.DrawItem>) -> V.Action(Readback):
  Resources{G.Context{_,_,+device},+command,+fence,framebuffer,pipeline,Attachment{+color,_,_},Attachment{+depth,_,_},+readback} = r
  Config{+width,+height,camera,light} = config
  +stage = B.handle(readback)
  +area : V.RenderArea = V.RenderArea{V.Offset2D{0,0},V.Extent2D{width,height}}
  +plane = U32.mul(U32.mul(width,height),4)
  +depth_stages = U32.or(vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT(),vk.VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT())
  +source_layout = Bool.pick(U32,used,vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL(),vk.VK_IMAGE_LAYOUT_UNDEFINED())
  +source_stage = Bool.pick(U32,used,vk.VK_PIPELINE_STAGE_TRANSFER_BIT(),vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT())
  +source_access = Bool.pick(U32,used,vk.VK_ACCESS_TRANSFER_READ_BIT(),0)
  do V.Action<Readback>:
    V.CommandBuffer.begin(command)
    geometry_barrier(command,G.buffers(resident))
    transition(command,color,vk.VK_IMAGE_ASPECT_COLOR_BIT(),source_layout,vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL(),source_stage,vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT(),source_access,vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT())
    transition(command,depth,vk.VK_IMAGE_ASPECT_DEPTH_BIT(),source_layout,vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL(),source_stage,depth_stages,source_access,U32.or(vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT(),vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT()))
    V.CommandBuffer.begin_render_pass(command,framebuffer,area,[V.ColorClear{V.ClearColor{0.0,0.0,1.0,1.0}},V.DepthClear{1.0}])
    V.CommandBuffer.set_viewport(command,V.Viewport{0.0,0.0,U32.to_f32(width),U32.to_f32(height),0.0,1.0})
    V.CommandBuffer.set_scissor(command,area)
    draw_items(command,pipeline,camera,light,resident,items)
    V.CommandBuffer.end_render_pass(command)
    transition(command,color,vk.VK_IMAGE_ASPECT_COLOR_BIT(),vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL(),vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL(),vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT(),vk.VK_PIPELINE_STAGE_TRANSFER_BIT(),vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT(),vk.VK_ACCESS_TRANSFER_READ_BIT())
    transition(command,depth,vk.VK_IMAGE_ASPECT_DEPTH_BIT(),vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL(),vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL(),depth_stages,vk.VK_PIPELINE_STAGE_TRANSFER_BIT(),vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT(),vk.VK_ACCESS_TRANSFER_READ_BIT())
    V.CommandBuffer.copy_image_to_buffer(command,color,vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL(),stage,[V.BufferImageCopy{W.zero(),0,0,V.ImageSubresourceLayers{vk.VK_IMAGE_ASPECT_COLOR_BIT(),0,0,1},V.Offset2D{0,0},V.Extent2D{width,height}}])
    V.CommandBuffer.copy_image_to_buffer(command,depth,vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL(),stage,[V.BufferImageCopy{depth_offset,0,0,V.ImageSubresourceLayers{vk.VK_IMAGE_ASPECT_DEPTH_BIT(),0,0,1},V.Offset2D{0,0},V.Extent2D{width,height}}])
    V.CommandBuffer.pipeline_barrier(command,vk.VK_PIPELINE_STAGE_TRANSFER_BIT(),vk.VK_PIPELINE_STAGE_HOST_BIT(),[V.MemoryBarrier{vk.VK_ACCESS_TRANSFER_WRITE_BIT(),vk.VK_ACCESS_HOST_READ_BIT()}],[],[])
    V.CommandBuffer.end(command)
    V.Device.submit(device,command,fence)
    status : U32 <- V.Fence.wait(fence,Core.whole_size())
    Error.require(U32.is_zero(status),"Frame fence incomplete")
    rgba : List<U32> <- B.read(device,readback,W.zero(),plane)
    depth : List<U32> <- B.read(device,readback,depth_offset,plane)
    V.CommandBuffer.reset(command)
    V.Device.collect_retired(device)
    V.Fence.reset(fence)
    return Readback{width,height,reusable(rgba),reusable(depth)}

def render_checked(+resources:Resources,+config:Config,+resident:G.Resident,+offset:W.U64,+used:Bool,items:List<&2,Draw.DrawItem>,result:Result<&2,&2,InputError,Unit>) -> V.Action(Renderer & Result<&2,&2,InputError,Readback>):
  match result:
    case Fail{error}:V.Action.pure(Renderer & Result<&2,&2,InputError,Readback>,(Renderer{resources,config,resident,offset,used},Fail{error}))
    case Done{_}:
      do V.Action<Renderer & Result<&2,&2,InputError,Readback>>:
        image : Readback <- frame(resources,config,resident,offset,used,items)
        return (Renderer{resources,config,resident,offset,True{}},Done{image})

def config_camera(config:Config) -> M.Mat4:
  Config{_,_,camera,_} = config
  camera

def render_collected(+resources:Resources,+config:Config,+offset:W.U64,+used:Bool,+items:List<&2,Draw.DrawItem>,pair:G.Resident & V.VkResult(Unit)) -> V.Action(Renderer & Result<&2,&2,InputError,Readback>):
  (+resident,result) = pair
  do V.Action<Renderer & Result<&2,&2,InputError,Readback>>:
    IO.pure(V.VkResult(Unit),result)
    render_checked(resources,config,resident,offset,used,items,preflight(config_camera(config),G.ranges(resident),items,0))

def render(renderer:Renderer,draws:Draw.DrawList) -> V.Action(Renderer & Result<&2,&2,InputError,Readback>):
  Renderer{+resources,config,resident,offset,used} = renderer
  Resources{G.Context{_,_,device},_,_,_,_,_,_,_} = resources
  Draw.DrawList{items} = draws
  do V.Action<Renderer & Result<&2,&2,InputError,Readback>>:
    pair:G.Resident & V.VkResult(Unit) <- V.Action.lift(G.Resident & V.VkResult(Unit),G.collect(device,resident))
    render_collected(resources,config,offset,used,items,pair)


def replaced(resources:Resources,config:Config,offset:W.U64,used:Bool,pair:G.Resident & (G.ReplaceStatus & Diag.Probe)) -> Renderer & G.ReplaceStatus:
  (resident,(status,probe)) = pair
  (Renderer{resources,config,resident,offset,used},status)

def replace_geometry(renderer:Renderer,mesh:Create.Geometry) -> IO(Renderer & G.ReplaceStatus):
  Renderer{+resources,config,resident,offset,used} = renderer
  Resources{+context,command,fence,framebuffer,pipeline,color,depth,stage} = resources
  do IO<Renderer & G.ReplaceStatus>:
    pair:G.Resident & (G.ReplaceStatus & Diag.Probe) <- G.replace(context,resident,mesh,Diag.Off{})
    return replaced(resources,config,offset,used,pair)

def collected_renderer(resources:Resources,config:Config,offset:W.U64,used:Bool,pair:G.Resident & V.VkResult(Unit)) -> Renderer & V.VkResult(Unit):
  (resident,result) = pair
  (Renderer{resources,config,resident,offset,used},result)

def collect_geometry(renderer:Renderer) -> IO(Renderer & V.VkResult(Unit)):
  Renderer{+resources,config,resident,offset,used} = renderer
  Resources{G.Context{_,_,device},_,_,_,_,_,_,_} = resources
  do IO<Renderer & V.VkResult(Unit)>:
    pair:G.Resident & V.VkResult(Unit) <- G.collect(device,resident)
    return collected_renderer(resources,config,offset,used,pair)

def set_light(renderer:Renderer,+light:Light.Light) -> Renderer & Bool:
  Renderer{resources,Config{w,h,camera,previous},resident,offset,used} = renderer
  +valid = Light.valid(light)
  (Renderer{resources,Config{w,h,camera,Bool.pick(Light.Light,valid,light,previous)},resident,offset,used},valid)

def camera_config(config:Config,matrix:Maybe<M.Mat4>) -> Config & Bool:
  Config{w,h,camera,light} = config
  match matrix:
    case None{}:(Config{w,h,camera,light},False{})
    case Some{matrix}:(Config{w,h,matrix,light},True{})

def configured(resources:Resources,resident:G.Resident,offset:W.U64,used:Bool,pair:Config & Bool) -> Renderer & Bool:
  (config,valid) = pair
  (Renderer{resources,config,resident,offset,used},valid)

def set_camera(renderer:Renderer,camera:Create.Camera) -> Renderer & Bool:
  Renderer{resources,+config,resident,offset,used} = renderer
  Config{w,h,_,_} = config
  configured(resources,resident,offset,used,camera_config(config,Create.view(camera,w,h)))
