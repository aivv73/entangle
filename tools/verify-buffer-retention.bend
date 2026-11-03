import Base
import ../src/scene-buffer.bend as B
import ../src/scene-geometry.bend as G
import ../src/error.bend as Error
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/core.bend as Core
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/shaders/spirv.bend as Shaders
import ../deps/bend-vulkan/examples/indexed_offscreen.bend as Indexed
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W

def rejected(-A:Type,label:String,result:V.VkResult(A)) -> V.Action(Unit):
  match result:
    case Fail{(1610612740,_)}:V.Action.pure(Unit,Unit{})
    case _:Error.require(False{},label ++ ": expected a lifetime rejection")

def reject(-A:Type,label:String,action:V.Action(A)) -> V.Action(Unit):
  do V.Action<Unit>:
    result:V.VkResult(A) <- V.Action.lift(V.VkResult(A),action)
    rejected(A,label,result)

def count(expected:U32,label:String) -> V.Action(Unit):
  do V.Action<Unit>:
    actual:U32 <- V.debug_live_objects()
    Error.require(U32.is_eq(actual,expected),label ++ ": live object count differs")

def missing(result:V.VkResult(V.MemoryRequirements)) -> V.Action(Unit):
  match result:
    case Fail{(1610612738,_)}:V.Action.pure(Unit,Unit{})
    case _:Error.require(False{},"Collected buffer handle remains live")

def gone(device:V.Device,buffer:B.Buffer) -> V.Action(Unit):
  do V.Action<Unit>:
    result:V.VkResult(V.MemoryRequirements) <- V.Action.lift(V.VkResult(V.MemoryRequirements),V.Device.get_buffer_memory_requirements(device,B.handle(buffer)))
    missing(result)

def retained(+device:V.Device,buffer:B.Buffer,expected:U32,label:String) -> V.Action(Unit):
  do V.Action<Unit>:
    V.Device.collect_retired(device)
    count(expected,label)
    req:V.MemoryRequirements <- V.Device.get_buffer_memory_requirements(device,B.handle(buffer))
    return Unit{}

def allocate(context:G.Context) -> V.Action(B.Buffer):
  G.Context{instance,physical,device} = context
  B.allocate(instance,physical,device,W.of_u32(16),vk.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT())

def descriptor(buffer:B.Buffer) -> V.DescriptorBuffer:
  V.DescriptorBuffer{B.handle(buffer),W.zero(),W.of_u32(16)}

def write_pair(+device:V.Device,set:V.DescriptorSet,+buffer:B.Buffer) -> V.Action(Unit):
  V.Device.update_descriptor_set(device,set,[V.UniformWrite{0,0,[descriptor(buffer),descriptor(buffer)]}])

def write_slot(device:V.Device,set:V.DescriptorSet,slot:U32,buffer:B.Buffer) -> V.Action(Unit):
  V.Device.update_descriptor_set(device,set,[V.UniformWrite{0,slot,[descriptor(buffer)]}])

def wait(fence:V.Fence) -> V.Action(Unit):
  do V.Action<Unit>:
    status:U32 <- V.Fence.wait(fence,Core.whole_size())
    Error.require(U32.is_zero(status),"Retaining submission did not complete")

def memory(buffer:B.Buffer) -> V.DeviceMemory:
  Pair.snd(V.Buffer,V.DeviceMemory,B.allocation(buffer))

def equal_bytes(a:List<U32>,b:List<U32>) -> Bool:
  match a b:
    case [],[]:True{}
    case x <> xs,y <> ys:U32.is_eq(x,y) && equal_bytes(xs,ys)
    case _,_:False{}

def aliases(+context:G.Context) -> V.Action(Unit):
  +device = G.device(context)
  do V.Action<Unit>:
    +base:U32 <- V.debug_live_objects()
    +buffer:B.Buffer <- allocate(context)
    +memory:V.DeviceMemory = memory(buffer)
    +alias:V.Buffer <- V.Device.create_buffer(device,V.BufferCreateInfo{W.of_u32(16),vk.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT()})
    V.Device.bind_buffer_memory(device,alias,memory,W.zero())
    reject(Unit,"Retire memory with another bound buffer",B.retire(device,buffer))
    reject(Unit,"Free memory with bound buffers",V.Device.free_memory(device,memory))
    written:U32 <- B.write(device,buffer,W.zero(),[1,2,3,4])
    bytes:List<U32> <- B.read(device,buffer,W.zero(),4)
    Error.require(equal_bytes(bytes,[1,2,3,4]),"Rejected alias retirement sealed or changed memory")
    retained(device,buffer,U32.add(base,3),"Alias rejection preserves both buffers and memory")
    V.Device.destroy_buffer(device,alias)
    B.retire(device,buffer)
    +later:V.Buffer <- V.Device.create_buffer(device,V.BufferCreateInfo{W.of_u32(16),vk.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT()})
    reject(Unit,"Bind new alias after retirement",V.Device.bind_buffer_memory(device,later,memory,W.zero()))
    V.Device.destroy_buffer(device,later)
    V.Device.collect_retired(device)
    gone(device,buffer)
    count(base,"Dedicated memory collected after alias destruction")
    V.Action.lift(Unit,IO.print("Memory aliases reject retirement without sealing; sealed memory rejects new aliases; final collection returns to baseline."))

def pipeline(+device:V.Device,schema:V.DescriptorSetLayout) -> V.Action(V.GraphicsPipeline & (V.PipelineLayout & V.RenderPass)):
  do V.Action<V.GraphicsPipeline & (V.PipelineLayout & V.RenderPass)>:
    +layout:V.PipelineLayout <- V.Device.create_pipeline_layout(device,V.PipelineLayoutCreateInfo{[schema],Some{V.PushConstantRange{vk.VK_SHADER_STAGE_VERTEX_BIT(),64}}})
    +pass:V.RenderPass <- V.Device.create_render_pass(device,V.RenderPassCreateInfo{[V.AttachmentInfo{vk.VK_FORMAT_R8G8B8A8_UNORM(),vk.VK_ATTACHMENT_LOAD_OP_CLEAR(),vk.VK_ATTACHMENT_STORE_OP_STORE()}],Some{V.AttachmentInfo{vk.VK_FORMAT_D32_SFLOAT(),vk.VK_ATTACHMENT_LOAD_OP_CLEAR(),vk.VK_ATTACHMENT_STORE_OP_STORE()}}})
    +vertex:V.ShaderModule <- V.Device.create_shader_module(device,Shaders.vertex_words())
    +fragment:V.ShaderModule <- V.Device.create_shader_module(device,Shaders.fragment_words())
    graphics:V.GraphicsPipeline <- V.Device.create_graphics_pipeline(device,Indexed.pipeline_info(layout,pass,vertex,fragment,vk.VK_FRONT_FACE_CLOCKWISE()))
    V.Device.destroy_shader_module(device,vertex)
    V.Device.destroy_shader_module(device,fragment)
    return (graphics,(layout,pass))

def submissions(+device:V.Device,+old:B.Buffer,+fresh:B.Buffer,+pool:V.DescriptorPool,+a:V.DescriptorSet,+b:V.DescriptorSet,+graphics:V.GraphicsPipeline) -> V.Action(Unit):
  do V.Action<Unit>:
    +commands:V.CommandPool <- V.Device.create_command_pool(device)
    +first:V.CommandBuffer <- V.Device.allocate_command_buffer(device,commands)
    +second:V.CommandBuffer <- V.Device.allocate_command_buffer(device,commands)
    +fence_a:V.Fence <- V.Device.create_fence(device,False{})
    +fence_b:V.Fence <- V.Device.create_fence(device,False{})
    +base:U32 <- V.debug_live_objects()
    V.CommandBuffer.begin(first)
    V.CommandBuffer.bind_graphics_pipeline(first,graphics)
    V.CommandBuffer.bind_descriptor_sets(first,0,[a])
    V.CommandBuffer.bind_descriptor_sets(first,0,[b])
    reject(Unit,"Retire through a recording descriptor",B.retire(device,old))
    reject(Unit,"Update an earlier recorded descriptor after rebinding",write_pair(device,a,fresh))
    V.CommandBuffer.end(first)
    V.CommandBuffer.begin(second)
    V.CommandBuffer.bind_graphics_pipeline(second,graphics)
    V.CommandBuffer.bind_descriptor_sets(second,0,[a])
    V.CommandBuffer.end(second)
    V.Device.submit(device,first,fence_a)
    V.Device.submit(device,second,fence_b)
    reject(List<U32>,"Read memory through pending descriptor references",B.read(device,old,W.zero(),4))
    B.retire(device,old)
    retained(device,old,base,"Two submissions before completion observation")
    reject(Unit,"Reset pending command",V.CommandBuffer.reset(second))
    reject(Unit,"Destroy a pool with pending commands",V.Device.destroy_command_pool(device,commands))
    reject(Unit,"Free a pending descriptor",V.Device.free_descriptor_set(device,a))
    reject(Unit,"Reset a pool with pending descriptors",V.Device.reset_descriptor_pool(device,pool))
    wait(fence_a)
    V.CommandBuffer.reset(first)
    retained(device,old,base,"One submission completed and reset")
    reject(Unit,"Second submission still unobserved",V.CommandBuffer.reset(second))
    V.Device.wait_idle(device)
    retained(device,old,base,"Device idle preserves recorded and descriptor references")
    reject(Unit,"Update a completed but recorded descriptor",write_pair(device,a,fresh))
    reject(Unit,"Destroy a pool with completed recorded sets",V.Device.destroy_descriptor_pool(device,pool))
    V.Device.destroy_command_pool(device,commands)
    retained(device,old,U32.sub(base,3),"Destroy commands preserves descriptor references")
    V.Device.destroy_fence(device,fence_a)
    V.Device.destroy_fence(device,fence_b)
    V.Action.lift(Unit,IO.print("Two real submissions retain descriptor memory; completion of one, device idle, and command pool destruction preserve the remaining owners. Rebinding preserves earlier recorded references."))

def slots(+device:V.Device,+old:B.Buffer,+fresh:B.Buffer,+pool:V.DescriptorPool,+a:V.DescriptorSet,+b:V.DescriptorSet,+graphics:V.GraphicsPipeline) -> V.Action(Unit):
  do V.Action<Unit>:
    +base:U32 <- V.debug_live_objects()
    reject(Unit,"Add a descriptor reference to a retired buffer",write_pair(device,b,old))
    +commands:V.CommandPool <- V.Device.create_command_pool(device)
    +command:V.CommandBuffer <- V.Device.allocate_command_buffer(device,commands)
    V.CommandBuffer.begin(command)
    V.CommandBuffer.bind_graphics_pipeline(command,graphics)
    reject(Unit,"Record a descriptor reaching retired memory",V.CommandBuffer.bind_descriptor_sets(command,0,[a]))
    V.Device.destroy_command_pool(device,commands)
    retained(device,old,base,"Rejected references leave descriptors unchanged")
    write_pair(device,a,fresh)
    retained(device,old,base,"Another descriptor set retains the old buffer")
    write_slot(device,b,0,fresh)
    retained(device,old,base,"The final array slot alone retains the old buffer")
    V.Device.free_descriptor_set(device,b)
    count(U32.sub(base,1),"Descriptor free does not collect implicitly")
    V.Device.collect_retired(device)
    gone(device,old)
    count(U32.sub(base,3),"Last descriptor release collects exactly one pair")
    B.retire(device,fresh)
    retained(device,fresh,U32.sub(base,3),"Rewritten descriptors retain the new allocation")
    V.Device.reset_descriptor_pool(device,pool)
    count(U32.sub(base,4),"Pool reset removes the remaining set")
    V.Device.collect_retired(device)
    gone(device,fresh)
    count(U32.sub(base,6),"Pool reset releases the final allocation")
    V.Action.lift(Unit,IO.print("Descriptor array slots and independent sets retain retired buffers after commands disappear; partial rewrites preserve other slots; free and pool reset release the final owners."))

def destroy_pool(+context:G.Context,schema:V.DescriptorSetLayout,+pool:V.DescriptorPool) -> V.Action(Unit):
  +device = G.device(context)
  do V.Action<Unit>:
    +base:U32 <- V.debug_live_objects()
    +buffer:B.Buffer <- allocate(context)
    +set:V.DescriptorSet <- V.Device.allocate_descriptor_set(device,pool,schema)
    write_pair(device,set,buffer)
    B.retire(device,buffer)
    retained(device,buffer,U32.add(base,3),"Unrecorded descriptor set retains retired memory")
    V.Device.destroy_descriptor_pool(device,pool)
    count(U32.add(base,1),"Destroy descriptor pool removes the pool and its set")
    V.Device.collect_retired(device)
    gone(device,buffer)
    count(U32.sub(base,1),"Destroy descriptor pool releases the last allocation")

def descriptor_resources(+context:G.Context,+old:B.Buffer,+fresh:B.Buffer,+schema:V.DescriptorSetLayout,+pool:V.DescriptorPool,+a:V.DescriptorSet,+b:V.DescriptorSet,base:U32,pair:V.GraphicsPipeline & (V.PipelineLayout & V.RenderPass)) -> V.Action(Unit):
  (+graphics,(layout,pass)) = pair
  +device = G.device(context)
  do V.Action<Unit>:
    submissions(device,old,fresh,pool,a,b,graphics)
    slots(device,old,fresh,pool,a,b,graphics)
    destroy_pool(context,schema,pool)
    V.Device.destroy_graphics_pipeline(device,graphics)
    V.Device.destroy_pipeline_layout(device,layout)
    V.Device.destroy_render_pass(device,pass)
    V.Device.destroy_descriptor_set_layout(device,schema)
    count(base,"Descriptor verification releases every resource")

def descriptors(+context:G.Context) -> V.Action(Unit):
  +device = G.device(context)
  do V.Action<Unit>:
    +base:U32 <- V.debug_live_objects()
    +old:B.Buffer <- allocate(context)
    +fresh:B.Buffer <- allocate(context)
    +schema:V.DescriptorSetLayout <- V.Device.create_descriptor_set_layout(device,V.DescriptorSetLayoutCreateInfo{[V.DescriptorBinding{0,V.UniformDescriptor{},2,vk.VK_SHADER_STAGE_VERTEX_BIT()}]})
    +pool:V.DescriptorPool <- V.Device.create_descriptor_pool(device,V.DescriptorPoolCreateInfo{2,[V.DescriptorPoolSize{V.UniformDescriptor{},4}]})
    +a:V.DescriptorSet <- V.Device.allocate_descriptor_set(device,pool,schema)
    +b:V.DescriptorSet <- V.Device.allocate_descriptor_set(device,pool,schema)
    write_pair(device,a,old)
    write_pair(device,b,old)
    pair:V.GraphicsPipeline & (V.PipelineLayout & V.RenderPass) <- pipeline(device,schema)
    descriptor_resources(context,old,fresh,schema,pool,a,b,base,pair)

def verify(+context:G.Context) -> V.Action(Unit):
  do V.Action<Unit>:
    aliases(context)
    descriptors(context)
