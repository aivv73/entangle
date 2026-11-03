import Base
import ../src/scene-buffer.bend as B
import ../src/scene-render.bend as R
import ../src/error.bend as Error
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/core.bend as Core
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W

def rejected(result:V.VkResult(U32),+fragment:String) -> V.Action(Unit):
  match result:
    case Done{_}:Error.require(False{},"Invalid upload accepted: " ++ fragment)
    case Fail{(_,+message)}:Error.require(String.contains(message,fragment),"Unexpected upload failure: " ++ message)

def same(bytes:List<U32>,expected:List<U32>) -> Bool:
  match bytes expected:
    case Nil{} Nil{}:True{}
    case a <> rest b <> tail:U32.is_eq(a,b) && same(rest,tail)
    case _ _:False{}

def unchanged(+device:V.Device,+buffer:B.Buffer) -> V.Action(Unit):
  do V.Action<Unit>:
    bytes:List<U32> <- B.read(device,buffer,W.zero(),7)
    Error.require(same(bytes,[10,11,12,13,71,72,73]),"Rejected write changed real destination")

def reject(+device:V.Device,+buffer:B.Buffer,offset:W.U64,bytes:List<&2,U32>,fragment:String) -> V.Action(Unit):
  do V.Action<Unit>:
    result:V.VkResult(U32) <- V.Action.lift(V.VkResult(U32),B.write(device,buffer,offset,bytes))
    rejected(result,fragment)
    unchanged(device,buffer)

def padding(req:V.MemoryRequirements) -> V.Action(Unit):
  V.MemoryRequirements{size,_,_} = req
  V.Action.lift(Unit,IO.print(Bool.pick(String,Core.size_less(W.of_u32(7),size),"Requested capacity 7 is smaller than actual Vulkan memory requirement padding.","Device supplied no allocation padding for capacity 7.")))

def failed_new(result:V.VkResult(B.Buffer)) -> V.Action(Unit):
  match result:
    case Done{_}:Error.require(False{},"Invalid new upload accepted")
    case Fail{(_,message)}:Error.require(String.contains(message,"byte"),"New upload lost primary native error")

def cleanup_new(instance:V.Instance,physical:V.PhysicalDevice,+device:V.Device) -> V.Action(Unit):
  do V.Action<Unit>:
    before:U32 <- V.debug_live_objects()
    result:V.VkResult(B.Buffer) <- V.Action.lift(V.VkResult(B.Buffer),B.upload_new(instance,physical,device,vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT(),[256]))
    failed_new(result)
    after:U32 <- V.debug_live_objects()
    Error.require(U32.is_eq(before,after),"Failed new upload retained resources before entry teardown")

def verify(+instance:V.Instance,+physical:V.PhysicalDevice,+device:V.Device) -> V.Action(Unit):
  do V.Action<Unit>:
    +buffer:B.Buffer <- B.allocate(instance,physical,device,W.of_u32(7),vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT())
    Error.require(Bool.not(Core.size_less(B.capacity(buffer),W.of_u32(7))) && Bool.not(Core.size_less(W.of_u32(7),B.capacity(buffer))),"Requested capacity lost")
    count:U32 <- B.write(device,buffer,W.zero(),[10,11,12,13,14,15,16])
    Error.require(U32.is_eq(count,7),"Byte diagnostics differ")
    count:U32 <- B.write(device,buffer,W.of_u32(4),[71,72,73])
    Error.require(U32.is_eq(count,3),"Offset endpoint write differs")
    count:U32 <- B.write(device,buffer,W.of_u32(7),[])
    Error.require(U32.is_zero(count),"Empty endpoint differs")
    unchanged(device,buffer)
    reject(device,buffer,W.of_u32(6),[1,2],"outside requested buffer")
    reject(device,buffer,W.of_u32(7),[1],"outside requested buffer")
    reject(device,buffer,W.of_u32(8),[],"outside requested buffer")
    reject(device,buffer,W.of_u32(8),[1],"outside requested buffer")
    reject(device,buffer,W.U64{4294967295,4294967295},[],"outside requested buffer")
    reject(device,buffer,W.U64{4294967295,4294967295},[1,2],"outside requested buffer")
    reject(device,buffer,W.zero(),[256],"byte")
    req:V.MemoryRequirements <- V.Device.get_buffer_memory_requirements(device,B.handle(buffer))
    padding(req)
    B.discard(device,buffer)
    cleanup_new(instance,physical,device)

def run(entry:V.Entry) -> V.Action(Unit):
  do V.Action<Unit>:
    +instance:V.Instance <- V.Entry.create_instance(entry,V.InstanceCreateInfo.default())
    devices:List<V.PhysicalDevice> <- V.Instance.enumerate_physical_devices(instance)
    +physical:V.PhysicalDevice <- R.first(devices)
    families:List<(U32 & U32)> <- V.Instance.get_physical_device_queue_family_properties(instance,physical)
    family:U32 <- R.choose(Core.find_queue_family(families,1),"No graphics queue")
    +device:V.Device <- V.Instance.create_device(instance,physical,V.DeviceCreateInfo{family,[]})
    verify(instance,physical,device)

def main() -> IO(Unit):
  do IO<Unit>:
    result:V.VkResult(Unit) <- V.Entry.with(Unit,run)
    V.or_exit(Unit,result)
    result:V.VkResult(U32) <- V.debug_live_objects()
    live:U32 <- V.or_exit(U32,result)
    IO.try(Unit,Error.require(U32.is_zero(live),"Upload verification leaked Vulkan objects"))
    IO.print("Production upload verified with real Vulkan writes/readback; endpoint, empty, crossing, beyond, max U64, invalid byte, unchanged rejection; live Vulkan objects=0.")
