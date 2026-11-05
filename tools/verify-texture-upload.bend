import Base
import ../src/scene-texture.bend as T
import ../src/content.bend as F
import ../src/error.bend as Error
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/core.bend as Core
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W

def first(devices:List<V.PhysicalDevice>) -> V.Action(V.PhysicalDevice):
  match devices:
    case device <> _:V.Action.pure(V.PhysicalDevice,device)
    case []:Error.failure(V.PhysicalDevice,1,"No Vulkan device")

def choose(value:Maybe<U32>) -> V.Action(U32):
  match value:
    case Some{value}:V.Action.pure(U32,value)
    case None{}:Error.failure(U32,1,"No graphics queue")

def released(result:T.Release) -> V.Action(Unit):
  match result:
    case T.Released{}:V.Action.pure(Unit,Unit{})
    case T.Pending{_,error}:IO.pure(V.VkResult(Unit),Fail{error})

def release_material(+device:V.Device,material:T.Material,before:U32) -> V.Action(Unit):
  T.Material{_,owned} = material
  do V.Action<Unit>:
    result:T.Release <- V.Action.lift(T.Release,T.release(device,owned))
    released(result)
    after:U32 <- V.debug_live_objects()
    Error.require(U32.is_eq(before,after),"Texture upload/disposal leaked resources")
    V.Action.lift(Unit,IO.print("Real RGBA8 upload and immediate resource release verified."))

def upload(+instance:V.Instance,+physical:V.PhysicalDevice,+device:V.Device) -> V.Action(Unit):
  do V.Action<Unit>:
    +before:U32 <- V.debug_live_objects()
    material:T.Material <- T.upload(instance,physical,device,F.SourceImage{2,2,[4278190335,4278255360,4294901760,4294967295]})
    release_material(device,material,before)


def rejected(result:V.VkResult(T.Material)) -> V.Action(Unit):
  match result:
    case Fail{(1610612739,_)}:V.Action.pure(Unit,Unit{})
    case _:Error.failure(Unit,1,"Partial texture preparation did not report native binding rejection")

def small_memory(instance:V.Instance,physical:V.PhysicalDevice,device:V.Device,requirements:V.MemoryRequirements) -> V.Action(V.DeviceMemory):
  V.MemoryRequirements{size,_,bits} = requirements
  do V.Action<V.DeviceMemory>:
    Error.require(Bool.not(Core.subrange_contains(W.of_u32(1),W.zero(),size)),"Texture unexpectedly requires at most one byte")
    T.allocate(instance,physical,device,V.MemoryRequirements{W.of_u32(1),W.of_u32(1),bits})

def rollback(+instance:V.Instance,+physical:V.PhysicalDevice,+device:V.Device) -> V.Action(Unit):
  do V.Action<Unit>:
    +before:U32 <- V.debug_live_objects()
    +image:V.ImageHandle <- V.Device.create_image(device,V.ImageCreateInfo{vk.VK_FORMAT_R8G8B8A8_UNORM(),V.Extent2D{2,2},1,1,U32.or(vk.VK_IMAGE_USAGE_TRANSFER_DST_BIT(),vk.VK_IMAGE_USAGE_SAMPLED_BIT())})
    requirements:V.MemoryRequirements <- V.Device.get_image_memory_requirements(device,image)
    memory:V.DeviceMemory <- small_memory(instance,physical,device,requirements)
    result:V.VkResult(T.Material) <- V.Action.lift(V.VkResult(T.Material),T.allocated(instance,physical,device,image,V.Extent2D{2,2},[4278190335,16711935,65535,4294967295],Done{memory}))
    rejected(result)
    after:U32 <- V.debug_live_objects()
    Error.require(U32.is_eq(before,after),"Partial texture preparation did not release image and memory")
    V.Action.lift(Unit,IO.print("Native image binding rejection releases both candidate resources; original error preserved."))

def run(entry:V.Entry) -> V.Action(Unit):
  do V.Action<Unit>:
    +instance:V.Instance <- V.Entry.create_instance(entry,V.InstanceCreateInfo.default())
    devices:List<V.PhysicalDevice> <- V.Instance.enumerate_physical_devices(instance)
    +physical:V.PhysicalDevice <- first(devices)
    families:List<(U32 & U32)> <- V.Instance.get_physical_device_queue_family_properties(instance,physical)
    family:U32 <- choose(Core.find_queue_family(families,1))
    +device:V.Device <- V.Instance.create_device(instance,physical,V.DeviceCreateInfo{family,[]})
    rollback(instance,physical,device)
    upload(instance,physical,device)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.try(Unit,V.Entry.with(Unit,run))
    live:U32 <- IO.try(U32,V.debug_live_objects())
    IO.try(Unit,Error.require(U32.is_zero(live),"Texture terminal cleanup leaked"))
    IO.print("Texture terminal live objects=0")
