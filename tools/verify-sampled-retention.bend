import Base
import ../src/scene-geometry.bend as G
import ../src/scene-render.bend as R
import ../src/error.bend as Error
import ./verify-buffer-retention.bend as Retention
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/constants.bend as vk

type Sample is Data:
  Sample{attachment:R.Attachment,sampler:V.Sampler}

def allocate(context:G.Context) -> V.Action(Sample):
  G.Context{instance,physical,+device} = context
  do V.Action<Sample>:
    attachment:R.Attachment <- R.attachment(instance,physical,device,V.Extent2D{8,4},vk.VK_FORMAT_R8G8B8A8_UNORM(),vk.VK_IMAGE_ASPECT_COLOR_BIT(),vk.VK_IMAGE_USAGE_SAMPLED_BIT())
    sampler:V.Sampler <- V.Device.create_sampler(device,V.SamplerCreateInfo{vk.VK_FILTER_NEAREST(),vk.VK_FILTER_NEAREST(),vk.VK_SAMPLER_MIPMAP_MODE_NEAREST(),vk.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE(),vk.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE(),vk.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE(),0.0,0.0,vk.VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK()})
    return Sample{attachment,sampler}

def descriptor(sample:Sample) -> V.DescriptorImage:
  Sample{R.Attachment{_,_,view},sampler} = sample
  V.DescriptorImage{view,sampler,vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL()}

def write_pair(device:V.Device,set:V.DescriptorSet,+sample:Sample) -> V.Action(Unit):
  V.Device.update_descriptor_set(device,set,[V.SampledWrite{0,0,[descriptor(sample),descriptor(sample)]}])

def write_slot(device:V.Device,set:V.DescriptorSet,slot:U32,sample:Sample) -> V.Action(Unit):
  V.Device.update_descriptor_set(device,set,[V.SampledWrite{0,slot,[descriptor(sample)]}])

def retained(+device:V.Device,sample:Sample,expected:U32,+label:String) -> V.Action(Unit):
  Sample{R.Attachment{+image,+memory,+view},+sampler} = sample
  do V.Action<Unit>:
    Retention.reject(Unit,label ++ ": view",V.Device.destroy_image_view(device,view))
    Retention.reject(Unit,label ++ ": sampler",V.Device.destroy_sampler(device,sampler))
    Retention.reject(Unit,label ++ ": image",V.Device.destroy_image(device,image))
    Retention.reject(Unit,label ++ ": memory",V.Device.free_memory(device,memory))
    V.Device.collect_retired(device)
    Retention.count(expected,label)
    req:V.MemoryRequirements <- V.Device.get_image_memory_requirements(device,image)
    return Unit{}

def missing(-A:Type,label:String,result:V.VkResult(A)) -> V.Action(Unit):
  match result:
    case Fail{(1610612738,_)}:V.Action.pure(Unit,Unit{})
    case _:Error.require(False{},label ++ ": destroyed sampled resource remains live")

def destroy(+device:V.Device,sample:Sample) -> V.Action(Unit):
  Sample{R.Attachment{+image,+memory,+view},+sampler} = sample
  do V.Action<Unit>:
    +base:U32 <- V.debug_live_objects()
    V.Device.destroy_sampler(device,sampler)
    Retention.count(U32.sub(base,1),"Sampled sampler destroyed alone")
    V.Device.destroy_image_view(device,view)
    Retention.count(U32.sub(base,2),"Sampled view destroyed alone")
    Retention.reject(Unit,"Image still owns its bound memory after view destruction",V.Device.free_memory(device,memory))
    V.Device.destroy_image(device,image)
    Retention.count(U32.sub(base,3),"Sampled image destroyed before memory")
    V.Device.free_memory(device,memory)
    Retention.count(U32.sub(base,4),"Sampled allocation fully released")
    stale_view:V.VkResult(Unit) <- V.Action.lift(V.VkResult(Unit),V.Device.destroy_image_view(device,view))
    missing(Unit,"view",stale_view)
    stale_sampler:V.VkResult(Unit) <- V.Action.lift(V.VkResult(Unit),V.Device.destroy_sampler(device,sampler))
    missing(Unit,"sampler",stale_sampler)
    stale_image:V.VkResult(V.MemoryRequirements) <- V.Action.lift(V.VkResult(V.MemoryRequirements),V.Device.get_image_memory_requirements(device,image))
    missing(V.MemoryRequirements,"image",stale_image)
    stale_memory:V.VkResult(Unit) <- V.Action.lift(V.VkResult(Unit),V.Device.free_memory(device,memory))
    missing(Unit,"memory",stale_memory)
    Retention.count(U32.sub(base,4),"Stale sampled handles preserve live objects")

def frozen(+device:V.Device,+pool:V.DescriptorPool,+set:V.DescriptorSet,fresh:Sample,+label:String) -> V.Action(Unit):
  do V.Action<Unit>:
    Retention.reject(Unit,label ++ ": update",write_pair(device,set,fresh))
    Retention.reject(Unit,label ++ ": free",V.Device.free_descriptor_set(device,set))
    Retention.reject(Unit,label ++ ": pool reset",V.Device.reset_descriptor_pool(device,pool))
    Retention.reject(Unit,label ++ ": pool destroy",V.Device.destroy_descriptor_pool(device,pool))

def submissions(+device:V.Device,+old:Sample,+fresh:Sample,+pool:V.DescriptorPool,+a:V.DescriptorSet,+b:V.DescriptorSet,+graphics:V.GraphicsPipeline) -> V.Action(Unit):
  do V.Action<Unit>:
    +base:U32 <- V.debug_live_objects()
    +commands:V.CommandPool <- V.Device.create_command_pool(device)
    +first:V.CommandBuffer <- V.Device.allocate_command_buffer(device,commands)
    +second:V.CommandBuffer <- V.Device.allocate_command_buffer(device,commands)
    +fence_a:V.Fence <- V.Device.create_fence(device,False{})
    +fence_b:V.Fence <- V.Device.create_fence(device,False{})
    V.CommandBuffer.begin(first)
    V.CommandBuffer.bind_graphics_pipeline(first,graphics)
    V.CommandBuffer.bind_descriptor_sets(first,0,[a])
    V.CommandBuffer.bind_descriptor_sets(first,0,[b])
    frozen(device,pool,a,fresh,"Earlier sampled set remains recorded after rebinding")
    retained(device,old,U32.add(base,5),"Recording sampled descriptors")
    V.CommandBuffer.end(first)
    frozen(device,pool,b,fresh,"Executable unsubmitted sampled set")
    V.CommandBuffer.begin(second)
    V.CommandBuffer.bind_graphics_pipeline(second,graphics)
    V.CommandBuffer.bind_descriptor_sets(second,0,[a])
    V.CommandBuffer.end(second)
    V.Device.submit(device,first,fence_a)
    V.Device.submit(device,second,fence_b)
    frozen(device,pool,a,fresh,"Pending sampled set")
    Retention.reject(Unit,"Pending sampled command reset",V.CommandBuffer.reset(second))
    Retention.reject(Unit,"Pending sampled command pool destroy",V.Device.destroy_command_pool(device,commands))
    retained(device,old,U32.add(base,5),"Two unobserved sampled submissions")
    Retention.wait(fence_a)
    frozen(device,pool,b,fresh,"Completed sampled set before command reset")
    V.CommandBuffer.reset(first)
    frozen(device,pool,a,fresh,"Second sampled submission still owns the set")
    write_pair(device,b,fresh)
    retained(device,old,U32.add(base,5),"Still-recorded sampled set keeps its original slots")
    retained(device,fresh,U32.add(base,5),"Reset releases the other sampled set for rewriting")
    write_pair(device,b,old)
    retained(device,old,U32.add(base,5),"One sampled submission completed and reset")
    Retention.reject(Unit,"Second sampled submission remains unobserved",V.CommandBuffer.reset(second))
    V.Device.wait_idle(device)
    frozen(device,pool,a,fresh,"Idle preserves sampled recording")
    retained(device,old,U32.add(base,5),"Device idle preserves sampled resources")
    V.Device.destroy_command_pool(device,commands)
    retained(device,old,U32.add(base,2),"Descriptor sets survive sampled command destruction")
    V.Device.destroy_fence(device,fence_a)
    V.Device.destroy_fence(device,fence_b)
    Retention.count(base,"Sampled submissions release commands and fences only")
    V.Action.lift(Unit,IO.print("Sampled descriptors: two real submissions, rebinding, completion, reset and idle preserve recorded sets, views, samplers, images and memory until command release."))

def slots(+device:V.Device,+old:Sample,+fresh:Sample,+a:V.DescriptorSet,+b:V.DescriptorSet) -> V.Action(Unit):
  do V.Action<Unit>:
    +base:U32 <- V.debug_live_objects()
    write_slot(device,a,0,fresh)
    retained(device,old,base,"Partial sampled array rewrite preserves other slots")
    retained(device,fresh,base,"Partial sampled array rewrite owns new resources")
    write_slot(device,a,1,fresh)
    retained(device,old,base,"Independent sampled set retains old resources")
    write_slot(device,b,0,fresh)
    retained(device,old,base,"Final sampled array slot retains old resources")
    write_slot(device,b,1,fresh)
    Retention.count(base,"Final sampled rewrite does not destroy resources")
    destroy(device,old)
    retained(device,fresh,U32.sub(base,4),"Rewritten sampled slots own new resources")
    V.Device.free_descriptor_set(device,a)
    retained(device,fresh,U32.sub(base,5),"Freeing one sampled set preserves the other")
    V.Device.free_descriptor_set(device,b)
    Retention.count(U32.sub(base,6),"Final sampled set free releases only the set")
    destroy(device,fresh)
    Retention.count(U32.sub(base,10),"Sampled rewrites and free release exactly two sets and allocations")
    V.Action.lift(Unit,IO.print("Sampled descriptors: partial array rewrites and independent sets retain every resource; final overwrite and final set free permit explicit destruction; all four resource handles become stale."))

def pool_release(+context:G.Context,schema:V.DescriptorSetLayout,+pool:V.DescriptorPool,+reset:Bool) -> V.Action(Unit):
  +device = G.device(context)
  do V.Action<Unit>:
    +base:U32 <- V.debug_live_objects()
    +sample:Sample <- allocate(context)
    +set:V.DescriptorSet <- V.Device.allocate_descriptor_set(device,pool,schema)
    write_pair(device,set,sample)
    retained(device,sample,U32.add(base,5),"Unrecorded sampled set owns all resources")
    Bool.pick(V.Action(Unit),reset,V.Device.reset_descriptor_pool(device,pool),V.Device.destroy_descriptor_pool(device,pool))
    +remaining:U32 = Bool.pick(U32,reset,U32.add(base,4),U32.add(base,3))
    Retention.count(remaining,"Sampled pool release leaves resources explicitly owned")
    stale_set:V.VkResult(Unit) <- V.Action.lift(V.VkResult(Unit),write_pair(device,set,sample))
    missing(Unit,"pool-released descriptor set",stale_set)
    destroy(device,sample)
    Retention.count(U32.sub(remaining,4),"Sampled pool release permits final resource destruction")
    V.Action.lift(Unit,IO.print(Bool.pick(String,reset,"Sampled descriptors: pool reset releases set references; explicit resource cleanup restores baseline.","Sampled descriptors: pool destruction releases set references; explicit resource cleanup restores baseline.")))

def resources(+context:G.Context,+old:Sample,+fresh:Sample,+schema:V.DescriptorSetLayout,+pool:V.DescriptorPool,+a:V.DescriptorSet,+b:V.DescriptorSet,base:U32,pair:V.GraphicsPipeline & (V.PipelineLayout & V.RenderPass)) -> V.Action(Unit):
  (+graphics,(layout,pass)) = pair
  +device = G.device(context)
  do V.Action<Unit>:
    submissions(device,old,fresh,pool,a,b,graphics)
    slots(device,old,fresh,a,b)
    pool_release(context,schema,pool,True{})
    pool_release(context,schema,pool,False{})
    V.Device.destroy_graphics_pipeline(device,graphics)
    V.Device.destroy_pipeline_layout(device,layout)
    V.Device.destroy_render_pass(device,pass)
    V.Device.destroy_descriptor_set_layout(device,schema)
    Retention.count(base,"Sampled descriptor verification releases every resource")

def verify(+context:G.Context) -> V.Action(Unit):
  +device = G.device(context)
  do V.Action<Unit>:
    +base:U32 <- V.debug_live_objects()
    +old:Sample <- allocate(context)
    +fresh:Sample <- allocate(context)
    +schema:V.DescriptorSetLayout <- V.Device.create_descriptor_set_layout(device,V.DescriptorSetLayoutCreateInfo{[V.DescriptorBinding{0,V.SampledDescriptor{},2,vk.VK_SHADER_STAGE_FRAGMENT_BIT()}]})
    +pool:V.DescriptorPool <- V.Device.create_descriptor_pool(device,V.DescriptorPoolCreateInfo{2,[V.DescriptorPoolSize{V.SampledDescriptor{},4}]})
    +a:V.DescriptorSet <- V.Device.allocate_descriptor_set(device,pool,schema)
    +b:V.DescriptorSet <- V.Device.allocate_descriptor_set(device,pool,schema)
    write_pair(device,a,old)
    write_pair(device,b,old)
    pair:V.GraphicsPipeline & (V.PipelineLayout & V.RenderPass) <- Retention.pipeline(device,schema)
    resources(context,old,fresh,schema,pool,a,b,base,pair)
