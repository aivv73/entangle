import Base
import ./content.bend as F
import ./render-format.bend as Format
import ./scene-buffer.bend as B
import ./error.bend as Error
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/core.bend as Core
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W

type Resource is Data:
  Image{value:V.ImageHandle}
  Memory{value:V.DeviceMemory}
  Allocation{image:V.ImageHandle,memory:V.DeviceMemory}
  View{value:V.ImageView}
  Sampler{value:V.Sampler}
  Pool{value:V.DescriptorPool}
  Schema{value:V.DescriptorSetLayout}
  Commands{value:V.CommandPool}
  Fence{value:V.Fence}
  Staging{value:B.Buffer}
type Material is Data:
  Material{set:V.DescriptorSet,owned:List<&2,Resource>}
type Release is Type:
  Released{}
  Pending{remaining:List<&2,Resource>,error:U32 & String}

def destroy(+device:V.Device,resource:Resource) -> V.Action(Unit):
  match resource:
    case Image{x}:V.Device.destroy_image(device,x)
    case Memory{x}:V.Device.free_memory(device,x)
    case Allocation{image,memory}:
      do V.Action<Unit>:
        V.Device.destroy_image(device,image)
        V.Device.free_memory(device,memory)
    case View{x}:V.Device.destroy_image_view(device,x)
    case Sampler{x}:V.Device.destroy_sampler(device,x)
    case Pool{x}:V.Device.destroy_descriptor_pool(device,x)
    case Schema{x}:V.Device.destroy_descriptor_set_layout(device,x)
    case Commands{x}:V.Device.destroy_command_pool(device,x)
    case Fence{x}:V.Device.destroy_fence(device,x)
    case Staging{x}:B.discard(device,x)

def guarded(-A:Type,device:V.Device,resource:Resource,result:V.VkResult(A)) -> V.Action(A):
  match result:
    case Done{value}:V.Action.pure(A,value)
    case Fail{error}:
      do IO<V.VkResult(A)>:
        cleanup:V.VkResult(Unit) <- destroy(device,resource)
        return V.Entry.finish(A,Fail{error},cleanup)

def guard(-A:Type,+device:V.Device,resource:Resource,action:V.Action(A)) -> V.Action(A):
  do IO<V.VkResult(A)>:
    result:V.VkResult(A) <- action
    guarded(A,device,resource,result)

def releasing(resource:Resource,rest:List<&2,Resource>,result:V.VkResult(Unit),next:IO(Release)) -> IO(Release):
  match result:
    case Fail{error}:IO.pure(Release,Pending{resource <> rest,error})
    case Done{_}:next

def release(+device:V.Device,resources:List<&2,Resource>) -> IO(Release):
  match resources:
    case []:IO.pure(Release,Released{})
    case +resource <> +rest:
      do IO<Release>:
        result:V.VkResult(Unit) <- destroy(device,resource)
        releasing(resource,rest,result,release(device,rest))

def schema(device:V.Device) -> V.Action(V.DescriptorSetLayout):
  V.Device.create_descriptor_set_layout(device,V.DescriptorSetLayoutCreateInfo{[V.DescriptorBinding{0,V.SampledDescriptor{},1,vk.VK_SHADER_STAGE_FRAGMENT_BIT()}]})

def transition(+command:V.CommandBuffer,image:V.ImageHandle,old:U32,new:U32,src_stage:U32,dst_stage:U32,src:U32,dst:U32) -> V.Action(Unit):
  V.CommandBuffer.pipeline_barrier(command,src_stage,dst_stage,[],[],[V.ImageMemoryBarrier{image,V.ImageSubresourceRange{vk.VK_IMAGE_ASPECT_COLOR_BIT(),0,1,0,1},old,new,src,dst}])

def copy(+device:V.Device,+image:V.ImageHandle,+extent:V.Extent2D,+staging:B.Buffer) -> V.Action(Unit):
  do V.Action<Unit>:
    +pool:V.CommandPool <- V.Device.create_command_pool(device)
    guard(Unit,device,Commands{pool},do V.Action<Unit>:
      +command:V.CommandBuffer <- V.Device.allocate_command_buffer(device,pool)
      +fence:V.Fence <- V.Device.create_fence(device,False{})
      guard(Unit,device,Fence{fence},do V.Action<Unit>:
        V.CommandBuffer.begin(command)
        V.CommandBuffer.pipeline_barrier(command,vk.VK_PIPELINE_STAGE_HOST_BIT(),vk.VK_PIPELINE_STAGE_TRANSFER_BIT(),[],[V.BufferMemoryBarrier{B.handle(staging),W.zero(),Core.whole_size(),vk.VK_ACCESS_HOST_WRITE_BIT(),vk.VK_ACCESS_TRANSFER_READ_BIT()}],[])
        transition(command,image,vk.VK_IMAGE_LAYOUT_UNDEFINED(),vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL(),vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT(),vk.VK_PIPELINE_STAGE_TRANSFER_BIT(),0,vk.VK_ACCESS_TRANSFER_WRITE_BIT())
        V.CommandBuffer.copy_buffer_to_image(command,B.handle(staging),image,vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL(),[V.BufferImageCopy{W.zero(),0,0,V.ImageSubresourceLayers{vk.VK_IMAGE_ASPECT_COLOR_BIT(),0,0,1},V.Offset2D{0,0},extent}])
        transition(command,image,vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL(),vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL(),vk.VK_PIPELINE_STAGE_TRANSFER_BIT(),vk.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT(),vk.VK_ACCESS_TRANSFER_WRITE_BIT(),vk.VK_ACCESS_SHADER_READ_BIT())
        V.CommandBuffer.end(command)
        V.Device.submit(device,command,fence)
        status:U32 <- V.Fence.wait(fence,Core.whole_size())
        Error.require(U32.is_zero(status),"Texture upload fence incomplete")
        V.CommandBuffer.reset(command)
        V.Device.destroy_fence(device,fence))
      V.Device.destroy_command_pool(device,pool))

def memory_type(found:Maybe<U32>) -> V.Action(U32):
  match found:
    case None{}:Error.failure(U32,1,"No compatible texture memory")
    case Some{value}:V.Action.pure(U32,value)

def allocate(instance:V.Instance,physical:V.PhysicalDevice,+device:V.Device,requirements:V.MemoryRequirements) -> V.Action(V.DeviceMemory):
  V.MemoryRequirements{size,_,bits} = requirements
  do V.Action<V.DeviceMemory>:
    types:List<Core.MemoryType> <- V.Instance.get_physical_device_memory_properties(instance,physical)
    index:U32 <- memory_type(Core.find_memory_type(types,bits,0))
    V.Device.allocate_memory(device,size,index)

def limits(properties:V.ImageFormatProperties,w:U32,h:U32) -> V.Action(Unit):
  V.ImageFormatProperties{mw,mh,_,mips,layers,samples,_} = properties
  Error.require(U32.is_le(w,mw) && U32.is_le(h,mh) && U32.is_gt(mips,0) && U32.is_gt(layers,0) && U32.is_ne(U32.and(samples,1),0),"Texture exceeds device image limits")

def allocated(+instance:V.Instance,+physical:V.PhysicalDevice,+device:V.Device,+image:V.ImageHandle,+extent:V.Extent2D,pixels:List<&2,U32>,result:V.VkResult(V.DeviceMemory)) -> V.Action(Material):
  match result:
    case Fail{error}:guarded(Material,device,Image{image},Fail{error})
    case Done{+memory}:
      guard(Material,device,Allocation{image,memory},do V.Action<Material>:
        V.Device.bind_image_memory(device,image,memory,W.zero())
        +view:V.ImageView <- V.Device.create_image_view(device,V.ImageViewCreateInfo{image,1,V.ImageSubresourceRange{vk.VK_IMAGE_ASPECT_COLOR_BIT(),0,1,0,1}})
        guard(Material,device,View{view},do V.Action<Material>:
          +sampler:V.Sampler <- V.Device.create_sampler(device,V.SamplerCreateInfo{vk.VK_FILTER_NEAREST(),vk.VK_FILTER_NEAREST(),vk.VK_SAMPLER_MIPMAP_MODE_NEAREST(),vk.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE(),vk.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE(),vk.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE(),0.0,0.0,vk.VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK()})
          guard(Material,device,Sampler{sampler},do V.Action<Material>:
            +layout:V.DescriptorSetLayout <- schema(device)
            guard(Material,device,Schema{layout},do V.Action<Material>:
              +pool:V.DescriptorPool <- V.Device.create_descriptor_pool(device,V.DescriptorPoolCreateInfo{1,[V.DescriptorPoolSize{V.SampledDescriptor{},1}]})
              guard(Material,device,Pool{pool},do V.Action<Material>:
                +set:V.DescriptorSet <- V.Device.allocate_descriptor_set(device,pool,layout)
                +staging:B.Buffer <- B.upload_new(instance,physical,device,vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT(),Format.pixels_bytes(pixels))
                guard(Material,device,Staging{staging},do V.Action<Material>:
                  copy(device,image,extent,staging)
                  V.Device.update_descriptor_set(device,set,[V.SampledWrite{0,0,[V.DescriptorImage{view,sampler,vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL()}]}])
                  B.discard(device,staging)
                  return Material{set,[Pool{pool},Sampler{sampler},View{view},Image{image},Memory{memory},Schema{layout}]}))))))

def memory(+instance:V.Instance,+physical:V.PhysicalDevice,+device:V.Device,+image:V.ImageHandle) -> V.Action(V.DeviceMemory):
  do V.Action<V.DeviceMemory>:
    requirements:V.MemoryRequirements <- V.Device.get_image_memory_requirements(device,image)
    allocate(instance,physical,device,requirements)

def upload(+instance:V.Instance,+physical:V.PhysicalDevice,+device:V.Device,+source:F.SourceImage) -> V.Action(Material):
  F.SourceImage{+w,+h,pixels} = source
  +extent:V.Extent2D = V.Extent2D{w,h}
  +usage = U32.or(vk.VK_IMAGE_USAGE_TRANSFER_DST_BIT(),vk.VK_IMAGE_USAGE_SAMPLED_BIT())
  do V.Action<Material>:
    Error.require(F.texture_valid(source),"Invalid texture source")
    properties:V.ImageFormatProperties <- V.Instance.get_physical_device_image_format_properties(instance,physical,V.ImageFormatInfo{vk.VK_FORMAT_R8G8B8A8_UNORM(),vk.VK_IMAGE_TYPE_2D(),vk.VK_IMAGE_TILING_OPTIMAL(),usage,0})
    limits(properties,w,h)
    +image:V.ImageHandle <- V.Device.create_image(device,V.ImageCreateInfo{vk.VK_FORMAT_R8G8B8A8_UNORM(),extent,1,1,usage})
    result:V.VkResult(V.DeviceMemory) <- V.Action.lift(V.VkResult(V.DeviceMemory),memory(instance,physical,device,image))
    allocated(instance,physical,device,image,extent,pixels,result)
