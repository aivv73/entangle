import Base
import ./scene-pipeline.bend as P
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/core.bend as Core
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W
import ./vulkan-window.bend as Host
import ../deps/bend-vulkan/examples/indexed_offscreen.bend as Mesh
import ./scene-texture.bend as T
import ./error.bend as Error

type Frame is Data:
  Frame{image: V.ImageHandle, view: V.ImageView, framebuffer: V.Framebuffer}
type Target is Data:
  Target{swapchain: V.Swapchain, width: U32, height: U32, requested_width: U32, requested_height: U32, depth: Mesh.Attachment, pass: V.RenderPass, pipelines: P.Pipelines, frames: List<&2,Frame>}

def format(value: Maybe<(U32 & U32)>) -> V.Action(U32 & U32):
  match value:
    case Some{pair}: V.Action.pure(U32 & U32,pair)
    case None{}: IO.pure(V.VkResult(U32 & U32),Fail{(1610612739,"No supported surface format")})

def depth(+context: Host.Context, +extent: V.Extent2D) -> V.Action(Mesh.Attachment):
  Host.Context{window,+instance,+physical,surface,+device,g,p} = context
  do V.Action<Mesh.Attachment>:
    +image : V.ImageHandle <- V.Device.create_image(device,V.ImageCreateInfo{vk.VK_FORMAT_D32_SFLOAT(),extent,1,1,vk.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT()})
    requirements : V.MemoryRequirements <- V.Device.get_image_memory_requirements(device,image)
    +memory : V.DeviceMemory <- T.allocate(instance,physical,device,requirements)
    V.Device.bind_image_memory(device,image,memory,W.zero())
    view : V.ImageView <- V.Device.create_image_view(device,V.ImageViewCreateInfo{image,1,V.ImageSubresourceRange{vk.VK_IMAGE_ASPECT_DEPTH_BIT(),0,1,0,1}})
    return Mesh.Attachment{image,memory,view}

def frames(images: List<V.ImageHandle>, +device: V.Device, +pass: V.RenderPass, +depth_view: V.ImageView, +extent: V.Extent2D) -> V.Action(List<&2,Frame>):
  match images:
    case Nil{}: V.Action.pure(List<&2,Frame>,Nil{})
    case Con{+image,rest}:
      do V.Action<List<&2,Frame>>:
        +view : V.ImageView <- V.Device.create_image_view(device,V.ImageViewCreateInfo{image,1,V.ImageSubresourceRange{vk.VK_IMAGE_ASPECT_COLOR_BIT(),0,1,0,1}})
        framebuffer : V.Framebuffer <- V.Device.create_framebuffer(device,V.FramebufferCreateInfo{pass,[view,depth_view],extent})
        next : List<&2,Frame> <- frames(rest,device,pass,depth_view,extent)
        return Frame{image,view,framebuffer} <> next

def target_frames(images: List<V.ImageHandle>, device: V.Device, pass: V.RenderPass, attachment: Mesh.Attachment, extent: V.Extent2D) -> V.Action(List<&2,Frame>):
  Mesh.Attachment{image,memory,view} = attachment
  frames(images,device,pass,view,extent)

def build_extent(+context: Host.Context, +width: U32, +height: U32, +color_format: U32, space: U32, count: U32, transform: U32, alpha: U32, size: U32 & U32) -> V.Action(Target):
  Host.Context{window,instance,physical,surface,+device,g,p} = context
  (+w,+h) = size
  +extent : V.Extent2D = V.Extent2D{w,h}
  do V.Action<Target>:
    +swapchain : V.Swapchain <- V.Device.create_swapchain(device,V.SwapchainCreateInfo{surface,count,color_format,space,extent,vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT(),transform,alpha,vk.VK_PRESENT_MODE_FIFO_KHR()})
    +attachment : Mesh.Attachment <- depth(context,extent)
    +pass : V.RenderPass <- V.Device.create_render_pass(device,V.RenderPassCreateInfo{[V.AttachmentInfo{color_format,vk.VK_ATTACHMENT_LOAD_OP_CLEAR(),vk.VK_ATTACHMENT_STORE_OP_STORE()}],Some{V.AttachmentInfo{vk.VK_FORMAT_D32_SFLOAT(),vk.VK_ATTACHMENT_LOAD_OP_CLEAR(),vk.VK_ATTACHMENT_STORE_OP_STORE()}}})
    pipelines:P.Pipelines <- P.create(device,pass,vk.VK_FRONT_FACE_COUNTER_CLOCKWISE(),vk.VK_CULL_MODE_BACK_BIT())
    images : List<V.ImageHandle> <- V.Device.swapchain_images(device,swapchain)
    views : List<&2,Frame> <- target_frames(images,device,pass,attachment,extent)
    return Target{swapchain,w,h,width,height,attachment,pass,pipelines,views}

def build_target(+context: Host.Context, +width: U32, +height: U32, caps: V.SurfaceCapabilities, pair: U32 & U32) -> V.Action(Target):
  V.SurfaceCapabilities{minimum,maximum,cw,ch,lw,lh,hw,hh,transforms,transform,+alpha,usage} = caps
  (color_format,space) = pair
  build_extent(context,width,height,color_format,space,Core.present_image_count(minimum,maximum),transform,U32.and(alpha,U32.sub(0,alpha)),Core.surface_extent(cw,ch,lw,lh,hw,hh,width,height))

def target(+context: Host.Context, +width: U32, +height: U32) -> V.Action(Target):
  Host.Context{window,+instance,+physical,+surface,+device,g,p} = context
  do V.Action<Target>:
    caps : V.SurfaceCapabilities <- V.Instance.surface_capabilities(instance,physical,surface)
    formats : List<(U32 & U32)> <- V.Instance.surface_formats(instance,physical,surface)
    pair : U32 & U32 <- format(Core.surface_format(formats))
    build_target(context,width,height,caps,pair)

def destroy_frames(xs: List<&2,Frame>, +device: V.Device) -> V.Action(Unit):
  match xs:
    case Nil{}: V.Action.pure(Unit,Unit{})
    case Con{Frame{image,view,framebuffer},rest}:
      do V.Action<Unit>:
        V.Device.destroy_framebuffer(device,framebuffer)
        V.Device.destroy_image_view(device,view)
        destroy_frames(rest,device)

def destroy(value: Maybe<Target>, +device: V.Device) -> V.Action(Unit):
  match value:
    case None{}: V.Action.pure(Unit,Unit{})
    case Some{Target{swapchain,w,h,rw,rh,Mesh.Attachment{image,memory,view},pass,pipelines,frames}}:
      do V.Action<Unit>:
        destroy_frames(frames,device)
        P.destroy(device,pipelines)
        V.Device.destroy_render_pass(device,pass)
        V.Device.destroy_image_view(device,view)
        V.Device.destroy_image(device,image)
        V.Device.free_memory(device,memory)
        V.Device.destroy_swapchain(device,swapchain)

def wait(+fence: V.Fence) -> V.Action(Unit):
  do V.Action<Unit>:
    status : U32 <- V.Fence.wait(fence,Core.whole_size())
    Error.require(U32.is_zero(status),"Window fence did not complete")
    V.Fence.reset(fence)

def frame_at(xs: List<&2,Frame>, index: U32) -> V.Action(Frame):
  match xs index:
    case Nil{} _: IO.pure(V.VkResult(Frame),Fail{(1610612739,"Swapchain image index out of range")})
    case Con{frame,rest} 0: V.Action.pure(Frame,frame)
    case Con{frame,rest} _: frame_at(rest,U32.sub(index,1))

# One frame in flight. Observe both render and presentation fences before reuse.

def presented(outcome: V.PresentOutcome, suboptimal: Bool) -> V.Action(Bool):
  match outcome:
    case V.Presented{}: V.Action.pure(Bool,suboptimal)
    case V.PresentSuboptimal{}: V.Action.pure(Bool,True{})
    case V.PresentOutOfDate{}: V.Action.pure(Bool,True{})
    case V.PresentSurfaceLost{}: IO.pure(V.VkResult(Bool),Fail{(1610612739,"Presentation surface lost")})

def replace(changed: Bool, value: Target, +context: Host.Context, width: U32, height: U32) -> V.Action(Target):
  match changed:
    case False{}: V.Action.pure(Target,value)
    case True{}:
      Host.Context{window,instance,physical,surface,device,g,p} = context
      do V.Action<Target>:
        destroy(Some{value},device)
        target(context,width,height)

def ensure(current: Maybe<Target>, +context: Host.Context, +width: U32, +height: U32) -> V.Action(Target):
  match current:
    case None{}: target(context,width,height)
    case Some{+value}:
      Target{swapchain,w,h,rw,rh,depth,pass,pipelines,frames} = value
      replace(U32.is_ne(rw,width) || U32.is_ne(rh,height),value,context,width,height)

def retire(rebuild: Bool, value: Target, device: V.Device) -> V.Action(Maybe<Target>):
  match rebuild:
    case False{}: V.Action.pure(Maybe<Target>,Some{value})
    case True{}:
      do V.Action<Maybe<Target>>:
        destroy(Some{value},device)
        return None{}
