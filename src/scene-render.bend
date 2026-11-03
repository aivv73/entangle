import Base
import ./measurement-counters.bend as Count
import ./scene-diagnostics.bend as Diag
import ./components.bend as C
import ./scene-draw.bend as Draw
import ./scene-matrix.bend as M
import ./scene-mesh.bend as Mesh
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/core.bend as Core
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W
import ../deps/bend-vulkan/shaders/spirv.bend as Shaders

type Vertex is Data:
  Vertex{position:C.Vec3,color:C.Vec3}
type Mesh is Data:
  Mesh{id:U32,vertices:List<&2,Vertex>,indices:List<&2,U32>}
type Config is Data:
  Config{width:U32,height:U32,camera:M.Mat4}
type Readback is Data:
  Readback{width:U32,height:U32,rgba:List<&2,U32>,depth:List<&2,U32>}
type InputError is Data:
  UnknownMesh{item:U32,id:U32}
  InvalidTransform{item:U32}
type Attachment is Data:
  Attachment{image:V.ImageHandle,memory:V.DeviceMemory,view:V.ImageView}
type Buffer is Data:
  Buffer{buffer:V.Buffer,memory:V.DeviceMemory}
type Resources is Data:
  Resources{device:V.Device,command:V.CommandBuffer,fence:V.Fence,framebuffer:V.Framebuffer,pipeline:V.GraphicsPipeline,color:Attachment,depth:Attachment,vertices:Buffer,indices:Buffer,stage:Buffer}
type Renderer is Type:
  Renderer{resources:Resources,config:Config,mesh_id:U32,index_count:U32,depth_offset:W.U64,used:Bool}

def require(ok:Bool,message:String) -> V.Action(Unit):
  match ok:
    case True{}:V.Action.pure(Unit,Unit{})
    case False{}:IO.pure(V.VkResult(Unit),Fail{(1,message)})

def choose(value:Maybe<U32>,message:String) -> V.Action(U32):
  match value:
    case Some{index}:V.Action.pure(U32,index)
    case None{}:IO.pure(V.VkResult(U32),Fail{(1,message)})

def first(devices:List<V.PhysicalDevice>) -> V.Action(V.PhysicalDevice):
  match devices:
    case device <> _:V.Action.pure(V.PhysicalDevice,device)
    case []:IO.pure(V.VkResult(V.PhysicalDevice),Fail{(1,"No Vulkan device")})

def finite(x:F32) -> Bool:
  U32.is_ne(U32.and(F32.bits(x),2139095040),2139095040)

def vec_finite(v:C.Vec3) -> Bool:
  C.Vec3{x,y,z} = v
  finite(x) && finite(y) && finite(z)

def col_finite(v:M.Vec4) -> Bool:
  M.Vec4{x,y,z,w} = v
  finite(x) && finite(y) && finite(z) && finite(w)

def matrix_finite(m:M.Mat4) -> Bool:
  M.Mat4{a,b,c,d} = m
  col_finite(a) && col_finite(b) && col_finite(c) && col_finite(d)

def transform_valid(t:C.Transform) -> Bool:
  C.Transform{p,C.Quat{+x,+y,+z,+w},s} = t
  +n = (x * x + y * y + z * z + w * w : F32)
  vec_finite(p) && vec_finite(s) && finite(x) && finite(y) && finite(z) && finite(w) && F32.is_ge(n,0.9999) && F32.is_le(n,1.0001)

def preflight_item(same:Bool,valid:Bool,other:U32,index:U32,next:Result<&2,&2,InputError,Unit>) -> Result<&2,&2,InputError,Unit>:
  match same valid:
    case False{} _:Fail{UnknownMesh{index,other}}
    case True{} False{}:Fail{InvalidTransform{index}}
    case True{} True{}:next

def preflight(+camera:M.Mat4,+id:U32,items:List<&2,Draw.DrawItem>,+index:U32) -> Result<&2,&2,InputError,Unit>:
  match items:
    case []:Done{Unit{}}
    case Draw.DrawItem{+t,C.MeshRef{+other}} <> rest:
      preflight_item(U32.is_eq(id,other),transform_valid(t) && matrix_finite(M.multiply(camera,M.model(t))),other,index,preflight(camera,id,rest,U32.inc(index)))

def word_bytes(+word:U32) -> List<U32>:
  [Core.word_byte(word,0),Core.word_byte(word,1),Core.word_byte(word,2),Core.word_byte(word,3)]

def bytes(words:List<U32>) -> List<U32>:
  match words:
    case []:[]
    case word <> rest:List.append(&1,U32,word_bytes(word),bytes(rest))

def vertex_words(v:Vertex) -> List<U32>:
  Vertex{C.Vec3{x,y,z},C.Vec3{r,g,b}} = v
  [F32.bits(x),F32.bits(y),F32.bits(z),F32.bits(r),F32.bits(g),F32.bits(b)]

def vertices_bytes(vertices:List<&2,Vertex>) -> List<U32>:
  match vertices:
    case []:[]
    case v <> rest:List.append(&1,U32,bytes(vertex_words(v)),vertices_bytes(rest))

def indices_bytes(indices:List<&2,U32>) -> List<U32>:
  match indices:
    case []:[]
    case i <> rest:List.append(&1,U32,word_bytes(i),indices_bytes(rest))

def vertices_valid(vertices:List<&2,Vertex>) -> Bool:
  match vertices:
    case []:True{}
    case Vertex{p,c} <> rest:vec_finite(p) && vec_finite(c) && vertices_valid(rest)

def mesh_valid(mesh:Mesh) -> Bool:
  Mesh{_,+vertices,+indices} = mesh
  +vc = U32.from_nat(List.length(&2,Vertex,vertices))
  +ic = U32.from_nat(List.length(&2,U32,indices))
  U32.is_gt(vc,0) && U32.is_gt(ic,0) && U32.is_zero(U32.mod(ic,3)) && Nat.is_le(List.length(&2,Vertex,vertices),U32.to_nat(U32.div(16777216,24))) && Nat.is_le(List.length(&2,U32,indices),3000000n) && vertices_valid(vertices) && Mesh.indices_valid(indices,vc)

def allocate(+instance:V.Instance,+physical:V.PhysicalDevice,+device:V.Device,requirements:V.MemoryRequirements,flags:U32) -> V.Action(V.DeviceMemory):
  V.MemoryRequirements{size,_,bits} = requirements
  do V.Action<V.DeviceMemory>:
    types : List<Core.MemoryType> <- V.Instance.get_physical_device_memory_properties(instance,physical)
    index : U32 <- choose(Core.find_memory_type(types,bits,flags),"No compatible memory")
    V.Device.allocate_memory(device,size,index)

def buffer(+instance:V.Instance,+physical:V.PhysicalDevice,+device:V.Device,size:W.U64,usage:U32) -> V.Action(Buffer):
  do V.Action<Buffer>:
    +buffer : V.Buffer <- V.Device.create_buffer(device,V.BufferCreateInfo{size,usage})
    req : V.MemoryRequirements <- V.Device.get_buffer_memory_requirements(device,buffer)
    +memory : V.DeviceMemory <- allocate(instance,physical,device,req,vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT())
    V.Device.bind_buffer_memory(device,buffer,memory,W.zero())
    return Buffer{buffer,memory}

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

def buffer_memory(b:Buffer) -> V.DeviceMemory:
  Buffer{_,m} = b
  m

def attachment_view(a:Attachment) -> V.ImageView:
  Attachment{_,_,v} = a
  v

def create_limited(+instance:V.Instance,+physical:V.PhysicalDevice,family:U32,limits:V.PhysicalDeviceLimits,+config:Config,mesh:Mesh) -> V.Action(Renderer):
  V.PhysicalDeviceLimits{+dimension,fw,fh,colors,push,attrs,bindings,offset,stride,allocs,atom,+alignment,row,granularity} = limits
  W.U64{+alo,ahi} = alignment
  Config{+width,+height,camera} = config
  Mesh{+id,+vertices,+indices} = mesh
  +vc = U32.from_nat(List.length(&2,Vertex,vertices))
  +ic = U32.from_nat(List.length(&2,U32,indices))
  do V.Action<Renderer>:
    require(U32.is_le(width,dimension) && U32.is_le(height,dimension) && U32.is_le(width,fw) && U32.is_le(height,fh) && U32.is_ge(push,64) && U32.is_ge(attrs,2) && U32.is_ge(bindings,1) && U32.is_ge(offset,12) && U32.is_ge(stride,24),"Insufficient device limits")
    require(U32.is_zero(ahi) && U32.is_gt(alo,0) && U32.is_le(alo,1048576),"Unsupported copy alignment")
    +device : V.Device <- V.Instance.create_device(instance,physical,V.DeviceCreateInfo{family,[]})
    +color : Attachment <- attachment(instance,physical,device,V.Extent2D{width,height},vk.VK_FORMAT_R8G8B8A8_UNORM(),vk.VK_IMAGE_ASPECT_COLOR_BIT(),U32.or(vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT(),vk.VK_IMAGE_USAGE_TRANSFER_SRC_BIT()))
    +depth : Attachment <- attachment(instance,physical,device,V.Extent2D{width,height},vk.VK_FORMAT_D32_SFLOAT(),vk.VK_IMAGE_ASPECT_DEPTH_BIT(),U32.or(vk.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT(),vk.VK_IMAGE_USAGE_TRANSFER_SRC_BIT()))
    +vb : Buffer <- buffer(instance,physical,device,W.of_u32(U32.mul(vc,24)),vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT())
    +ib : Buffer <- buffer(instance,physical,device,W.of_u32(U32.mul(ic,4)),vk.VK_BUFFER_USAGE_INDEX_BUFFER_BIT())
    +plane : U32 = U32.mul(U32.mul(width,height),4)
    +depth_offset : W.U64 = aligned(plane,alignment)
    +stage : Buffer <- buffer(instance,physical,device,W.add(depth_offset,W.of_u32(plane)),vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT())
    V.Device.write_memory(device,buffer_memory(vb),W.zero(),vertices_bytes(vertices))
    V.Device.write_memory(device,buffer_memory(ib),W.zero(),indices_bytes(indices))
    +vertex : V.ShaderModule <- V.Device.create_shader_module(device,Shaders.vertex_words())
    +fragment : V.ShaderModule <- V.Device.create_shader_module(device,Shaders.fragment_words())
    +layout : V.PipelineLayout <- V.Device.create_pipeline_layout(device,V.PipelineLayoutCreateInfo{[],Some{V.PushConstantRange{vk.VK_SHADER_STAGE_VERTEX_BIT(),64}}})
    +pass : V.RenderPass <- V.Device.create_render_pass(device,V.RenderPassCreateInfo{[V.AttachmentInfo{vk.VK_FORMAT_R8G8B8A8_UNORM(),vk.VK_ATTACHMENT_LOAD_OP_CLEAR(),vk.VK_ATTACHMENT_STORE_OP_STORE()}],Some{V.AttachmentInfo{vk.VK_FORMAT_D32_SFLOAT(),vk.VK_ATTACHMENT_LOAD_OP_CLEAR(),vk.VK_ATTACHMENT_STORE_OP_STORE()}}})
    pipeline : V.GraphicsPipeline <- V.Device.create_graphics_pipeline(device,V.GraphicsPipelineCreateInfo{layout,pass,vertex,fragment,[V.VertexInputBinding{0,24,vk.VK_VERTEX_INPUT_RATE_VERTEX()}],[V.VertexInputAttribute{0,0,vk.VK_FORMAT_R32G32B32_SFLOAT(),0},V.VertexInputAttribute{1,0,vk.VK_FORMAT_R32G32B32_SFLOAT(),12}],vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST(),V.RasterState{vk.VK_CULL_MODE_NONE(),vk.VK_FRONT_FACE_CLOCKWISE()},Some{V.DepthState{True{},True{},vk.VK_COMPARE_OP_LESS()}},15})
    V.Device.destroy_shader_module(device,vertex)
    V.Device.destroy_shader_module(device,fragment)
    framebuffer : V.Framebuffer <- V.Device.create_framebuffer(device,V.FramebufferCreateInfo{pass,[attachment_view(color),attachment_view(depth)],V.Extent2D{width,height}})
    +pool : V.CommandPool <- V.Device.create_command_pool(device)
    command : V.CommandBuffer <- V.Device.allocate_command_buffer(device,pool)
    fence : V.Fence <- V.Device.create_fence(device,False{})
    return Renderer{Resources{device,command,fence,framebuffer,pipeline,color,depth,vb,ib,stage},config,id,ic,depth_offset,False{}}

def create(+entry:V.Entry,+config:Config,mesh:Mesh) -> V.Action(Renderer):
  Config{+width,+height,+camera} = config
  Mesh{+id,+vertices,+indices} = mesh
  +vc = U32.from_nat(List.length(&2,Vertex,vertices))
  +ic = U32.from_nat(List.length(&2,U32,indices))
  do V.Action<Renderer>:
    require(U32.is_gt(width,0) && U32.is_gt(height,0) && U32.is_le(width,4096) && U32.is_le(height,4096) && U32.is_le(U32.mul(width,height),4194304) && matrix_finite(camera),"Invalid target or camera")
    require(mesh_valid(Mesh{id,vertices,indices}),"Invalid mesh")
    +instance : V.Instance <- V.Entry.create_instance(entry,V.InstanceCreateInfo.default())
    devices : List<V.PhysicalDevice> <- V.Instance.enumerate_physical_devices(instance)
    +physical : V.PhysicalDevice <- first(devices)
    families : List<(U32 & U32)> <- V.Instance.get_physical_device_queue_family_properties(instance,physical)
    family : U32 <- choose(Core.find_queue_family(families,1),"No graphics queue")
    limits : V.PhysicalDeviceLimits <- V.Instance.get_physical_device_limits(instance,physical)
    create_limited(instance,physical,family,limits,config,Mesh{id,vertices,indices})

def with(config:Config,mesh:Mesh,body:Renderer -> V.Action(Unit)) -> V.Action(Unit):
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

def draw_item(+command:V.CommandBuffer,+count:U32,+on:Bool,+counters:Count.Counters,pair:List<U32> & U32) -> V.Action(Count.Counters):
  (payload,bytes) = pair
  do V.Action<Count.Counters>:
    V.CommandBuffer.push_constants(command,payload)
    +counters:Count.Counters = Bool.pick(Count.Counters,on,Count.push(counters,bytes),counters)
    V.CommandBuffer.draw_indexed(command,V.IndexedDraw{count,1,0,V.BaseVertex{0},0})
    +counters:Count.Counters = Bool.pick(Count.Counters,on,Count.draw(counters),counters)
    return counters

def draw_items_counted(+command:V.CommandBuffer,+camera:M.Mat4,+count:U32,items:List<&2,Draw.DrawItem>,+on:Bool,+counters:Count.Counters) -> V.Action(Count.Counters):
  match items:
    case []:V.Action.pure(Count.Counters,counters)
    case Draw.DrawItem{t,_} <> rest:
      do V.Action<Count.Counters>:
        counters:Count.Counters <- draw_item(command,count,on,counters,payload_size(M.matrix_words(M.multiply(camera,M.model(t)))))
        draw_items_counted(command,camera,count,rest,on,counters)


def draw_items(command:V.CommandBuffer,camera:M.Mat4,count:U32,items:List<&2,Draw.DrawItem>) -> V.Action(Unit):
  do V.Action<Unit>:
    counters:Count.Counters <- draw_items_counted(command,camera,count,items,False{},Count.zero())
    return Unit{}

def reusable(values:List<U32>) -> List<&2,U32>:
  match values:
    case []:[]
    case x <> rest:x <> reusable(rest)

def frame(+r:Resources,+config:Config,+count:U32,+depth_offset:W.U64,+used:Bool,items:List<&2,Draw.DrawItem>) -> V.Action(Readback):
  Resources{+device,+command,+fence,framebuffer,pipeline,Attachment{+color,_,_},Attachment{+depth,_,_},Buffer{vb,_},Buffer{ib,_},Buffer{+stage,+memory}} = r
  Config{+width,+height,camera} = config
  +area : V.RenderArea = V.RenderArea{V.Offset2D{0,0},V.Extent2D{width,height}}
  +plane = U32.mul(U32.mul(width,height),4)
  +depth_stages = U32.or(vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT(),vk.VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT())
  +source_layout = Bool.pick(U32,used,vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL(),vk.VK_IMAGE_LAYOUT_UNDEFINED())
  +source_stage = Bool.pick(U32,used,vk.VK_PIPELINE_STAGE_TRANSFER_BIT(),vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT())
  +source_access = Bool.pick(U32,used,vk.VK_ACCESS_TRANSFER_READ_BIT(),0)
  do V.Action<Readback>:
    V.CommandBuffer.begin(command)
    V.CommandBuffer.pipeline_barrier(command,vk.VK_PIPELINE_STAGE_HOST_BIT(),vk.VK_PIPELINE_STAGE_VERTEX_INPUT_BIT(),[],[V.BufferMemoryBarrier{vb,W.zero(),Core.whole_size(),vk.VK_ACCESS_HOST_WRITE_BIT(),vk.VK_ACCESS_VERTEX_ATTRIBUTE_READ_BIT()},V.BufferMemoryBarrier{ib,W.zero(),Core.whole_size(),vk.VK_ACCESS_HOST_WRITE_BIT(),vk.VK_ACCESS_INDEX_READ_BIT()}],[])
    transition(command,color,vk.VK_IMAGE_ASPECT_COLOR_BIT(),source_layout,vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL(),source_stage,vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT(),source_access,vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT())
    transition(command,depth,vk.VK_IMAGE_ASPECT_DEPTH_BIT(),source_layout,vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL(),source_stage,depth_stages,source_access,U32.or(vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT(),vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT()))
    V.CommandBuffer.begin_render_pass(command,framebuffer,area,[V.ColorClear{V.ClearColor{0.0,0.0,1.0,1.0}},V.DepthClear{1.0}])
    V.CommandBuffer.bind_graphics_pipeline(command,pipeline)
    V.CommandBuffer.set_viewport(command,V.Viewport{0.0,0.0,U32.to_f32(width),U32.to_f32(height),0.0,1.0})
    V.CommandBuffer.set_scissor(command,area)
    V.CommandBuffer.bind_vertex_buffer(command,0,vb,W.zero())
    V.CommandBuffer.bind_index_buffer(command,ib,W.zero(),vk.VK_INDEX_TYPE_UINT32())
    draw_items(command,camera,count,items)
    V.CommandBuffer.end_render_pass(command)
    transition(command,color,vk.VK_IMAGE_ASPECT_COLOR_BIT(),vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL(),vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL(),vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT(),vk.VK_PIPELINE_STAGE_TRANSFER_BIT(),vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT(),vk.VK_ACCESS_TRANSFER_READ_BIT())
    transition(command,depth,vk.VK_IMAGE_ASPECT_DEPTH_BIT(),vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL(),vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL(),depth_stages,vk.VK_PIPELINE_STAGE_TRANSFER_BIT(),vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT(),vk.VK_ACCESS_TRANSFER_READ_BIT())
    V.CommandBuffer.copy_image_to_buffer(command,color,vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL(),stage,[V.BufferImageCopy{W.zero(),0,0,V.ImageSubresourceLayers{vk.VK_IMAGE_ASPECT_COLOR_BIT(),0,0,1},V.Offset2D{0,0},V.Extent2D{width,height}}])
    V.CommandBuffer.copy_image_to_buffer(command,depth,vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL(),stage,[V.BufferImageCopy{depth_offset,0,0,V.ImageSubresourceLayers{vk.VK_IMAGE_ASPECT_DEPTH_BIT(),0,0,1},V.Offset2D{0,0},V.Extent2D{width,height}}])
    V.CommandBuffer.pipeline_barrier(command,vk.VK_PIPELINE_STAGE_TRANSFER_BIT(),vk.VK_PIPELINE_STAGE_HOST_BIT(),[V.MemoryBarrier{vk.VK_ACCESS_TRANSFER_WRITE_BIT(),vk.VK_ACCESS_HOST_READ_BIT()}],[],[])
    V.CommandBuffer.end(command)
    V.Device.submit(device,command,fence)
    status : U32 <- V.Fence.wait(fence,Core.whole_size())
    require(U32.is_zero(status),"Frame fence incomplete")
    rgba : List<U32> <- V.Device.read_memory(device,memory,W.zero(),plane)
    depth : List<U32> <- V.Device.read_memory(device,memory,depth_offset,plane)
    V.CommandBuffer.reset(command)
    V.Fence.reset(fence)
    return Readback{width,height,reusable(rgba),reusable(depth)}

def render_checked(+resources:Resources,+config:Config,+id:U32,+count:U32,+offset:W.U64,+used:Bool,items:List<&2,Draw.DrawItem>,result:Result<&2,&2,InputError,Unit>) -> V.Action(Renderer & Result<&2,&2,InputError,Readback>):
  match result:
    case Fail{error}:V.Action.pure(Renderer & Result<&2,&2,InputError,Readback>,(Renderer{resources,config,id,count,offset,used},Fail{error}))
    case Done{_}:
      do V.Action<Renderer & Result<&2,&2,InputError,Readback>>:
        image : Readback <- frame(resources,config,count,offset,used,items)
        return (Renderer{resources,config,id,count,offset,True{}},Done{image})

def config_camera(config:Config) -> M.Mat4:
  Config{_,_,camera} = config
  camera

def render(renderer:Renderer,draws:Draw.DrawList) -> V.Action(Renderer & Result<&2,&2,InputError,Readback>):
  Renderer{+resources,+config,+id,+count,+offset,+used} = renderer
  Draw.DrawList{+items} = draws
  render_checked(resources,config,id,count,offset,used,items,preflight(config_camera(config),id,items,0))

