import Base
import ../src/scene-render.bend as R
import ../src/error.bend as Error
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/core.bend as Core
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W
import ./upload-boundary/bytes.bend as Bytes
import ./upload-boundary/checks.bend as Check

def size(req:V.MemoryRequirements) -> W.U64:
  V.MemoryRequirements{value,_,_} = req
  value

def bits(req:V.MemoryRequirements) -> U32:
  V.MemoryRequirements{_,_,value} = req
  value

def large_requirement(req:V.MemoryRequirements) -> V.Action(Unit):
  V.MemoryRequirements{+value,_,_} = req
  W.U64{+lo,+hi} = value
  do V.Action<Unit>:
    Error.require(Bool.not(Core.size_less(value,W.U64{257,1})) && U32.is_eq(hi,1),"Flattened high-limb buffer requirement differs")
    V.Action.lift(Unit,IO.print("Flattened BufferCreateInfo ABI verified: requested lo=257 hi=1; requirements lo=" ++ U32.show(lo) ++ " hi=" ++ U32.show(hi) ++ "; unbound buffer only, no large allocation."))

def run(entry:V.Entry) -> V.Action(Unit):
  do V.Action<Unit>:
    Check.abi()
    +instance:V.Instance <- V.Entry.create_instance(entry,V.InstanceCreateInfo.default())
    devices:List<V.PhysicalDevice> <- V.Instance.enumerate_physical_devices(instance)
    +physical:V.PhysicalDevice <- R.first(devices)
    families:List<(U32 & U32)> <- V.Instance.get_physical_device_queue_family_properties(instance,physical)
    family:U32 <- R.choose(Core.find_queue_family(families,1),"No graphics queue")
    +device:V.Device <- V.Instance.create_device(instance,physical,V.DeviceCreateInfo{family,[]})
    +before:U32 <- V.debug_live_objects()
    +large:V.Buffer <- V.Device.create_buffer(device,V.BufferCreateInfo{W.U64{257,1},vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT()})
    req:V.MemoryRequirements <- V.Device.get_buffer_memory_requirements(device,large)
    large_requirement(req)
    V.Device.destroy_buffer(device,large)
    after:U32 <- V.debug_live_objects()
    Error.require(U32.is_eq(before,after),"Unbound high-limb buffer retained objects")
    +buffer:V.Buffer <- V.Device.create_buffer(device,V.BufferCreateInfo{W.of_u32((Bytes.limit() + 2 : U32)),vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT()})
    +req:V.MemoryRequirements <- V.Device.get_buffer_memory_requirements(device,buffer)
    types:List<Core.MemoryType> <- V.Instance.get_physical_device_memory_properties(instance,physical)
    +index:U32 <- R.choose(Core.find_memory_type(types,bits(req),vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT()),"No host-visible memory")
    before_zero:U32 <- V.debug_live_objects()
    allocated:V.VkResult(V.DeviceMemory) <- V.Action.lift(V.VkResult(V.DeviceMemory),V.Device.allocate_memory(device,W.zero(),index))
    Check.rejected(Result.map(&1,&1,U32 & String,V.DeviceMemory,Unit,_ => Unit{},allocated),1610612739,"invalid allocation size or memory type")
    count:U32 <- V.debug_live_objects()
    Error.require(U32.is_eq(count,before_zero),"Zero native allocation changed live count")
    +memory:V.DeviceMemory <- V.Device.allocate_memory(device,size(req),index)
    V.Device.bind_buffer_memory(device,buffer,memory,W.zero())
    V.Device.write_memory(device,memory,W.zero(),[193])
    V.Device.write_memory(device,memory,W.of_u32(U32.inc(Bytes.limit())),[207])
    V.Action.lift(Unit,IO.print("Native exact-limit write/read begins: L=16777216, capacity=L+2, offset=1."))
    V.Device.write_memory(device,memory,W.of_u32(1),Bytes.payload(&1,U32.to_nat(Bytes.limit()),0,0))
    bytes:List<U32> <- V.Device.read_memory(device,memory,W.of_u32(1),Bytes.limit())
    Error.require(Bytes.matches(bytes,U32.to_nat(Bytes.limit()),0),"Native exact-limit payload or exact list length differs")
    bytes:List<U32> <- V.Device.read_memory(device,memory,W.zero(),1)
    Error.require(Bytes.same(bytes,[193]),"Native exact-limit leading guard changed")
    bytes:List<U32> <- V.Device.read_memory(device,memory,W.of_u32(U32.inc(Bytes.limit())),1)
    Error.require(Bytes.same(bytes,[207]),"Native exact-limit trailing guard changed")
    V.Action.lift(Unit,IO.print("Native exact-limit verified: every byte and exact list exhaustion compared; both guards intact."))
    result:V.VkResult(Unit) <- V.Action.lift(V.VkResult(Unit),V.Device.write_memory(device,memory,W.of_u32(1),Bytes.payload(&1,U32.to_nat(U32.inc(Bytes.limit())),0,255)))
    Check.rejected(result,1610612739,"invalid memory, byte value, or copy length")
    bytes:List<U32> <- V.Device.read_memory(device,memory,W.of_u32(1),Bytes.limit())
    Error.require(Bytes.matches(bytes,U32.to_nat(Bytes.limit()),0),"Native over-limit write changed payload")
    bytes:List<U32> <- V.Device.read_memory(device,memory,W.zero(),1)
    Error.require(Bytes.same(bytes,[193]),"Native over-limit write changed leading guard")
    bytes:List<U32> <- V.Device.read_memory(device,memory,W.of_u32(U32.inc(Bytes.limit())),1)
    Error.require(Bytes.same(bytes,[207]),"Native over-limit write changed trailing guard")
    V.Action.lift(Unit,IO.print("Native limit-plus-one writer rejected with argument code/message; all 16777218 destination bytes unchanged."))
    result:V.VkResult(List<U32>) <- V.Action.lift(V.VkResult(List<U32>),V.Device.read_memory(device,memory,W.of_u32(1),U32.inc(Bytes.limit())))
    Check.read_rejected(result,1610612741,"read exceeds 16 MiB chunk limit")
    result:V.VkResult(Unit) <- V.Action.lift(V.VkResult(Unit),V.Device.write_memory(device,memory,W.of_u32(1),[90,91,4294967295]))
    Check.rejected(result,1610612739,"invalid memory, byte value, or copy length")
    result:V.VkResult(Unit) <- V.Action.lift(V.VkResult(Unit),V.Device.write_memory(device,memory,W.U64{4294967295,4294967295},[]))
    Check.rejected(result,1610612739,"write needs host-visible memory and an in-bounds range")
    result:V.VkResult(Unit) <- V.Action.lift(V.VkResult(Unit),V.Device.write_memory(device,memory,W.U64{4294967295,4294967295},[1]))
    Check.rejected(result,1610612739,"write needs host-visible memory and an in-bounds range")
    result:V.VkResult(List<U32>) <- V.Action.lift(V.VkResult(List<U32>),V.Device.read_memory(device,memory,W.U64{4294967295,4294967295},0))
    Check.read_rejected(result,1610612739,"read needs host-visible memory and an in-bounds range")
    result:V.VkResult(List<U32>) <- V.Action.lift(V.VkResult(List<U32>),V.Device.read_memory(device,memory,W.U64{4294967295,4294967295},1))
    Check.read_rejected(result,1610612739,"read needs host-visible memory and an in-bounds range")
    result:V.VkResult(List<U32>) <- V.Action.lift(V.VkResult(List<U32>),V.Device.read_memory(device,memory,W.U64{4294967295,4294967295},4294967295))
    Check.read_rejected(result,1610612741,"read exceeds 16 MiB chunk limit")
    bytes:List<U32> <- V.Device.read_memory(device,memory,W.of_u32(1),Bytes.limit())
    Error.require(Bytes.matches(bytes,U32.to_nat(Bytes.limit()),0),"Native read/byte/offset rejection changed payload")
    bytes:List<U32> <- V.Device.read_memory(device,memory,W.zero(),1)
    Error.require(Bytes.same(bytes,[193]),"Native read/byte/offset rejection changed leading guard")
    bytes:List<U32> <- V.Device.read_memory(device,memory,W.of_u32(U32.inc(Bytes.limit())),1)
    Error.require(Bytes.same(bytes,[207]),"Native read/byte/offset rejection changed trailing guard")
    V.Device.destroy_buffer(device,buffer)
    V.Device.free_memory(device,memory)
    after:U32 <- V.debug_live_objects()
    Error.require(U32.is_eq(before,after),"Native explicit disposal retained objects before teardown")
    V.Action.lift(Unit,IO.print("Native negative boundaries verified: read limit, invalid byte after prefix, U64max empty/nonempty offsets, U32max count precedence; all destination bytes unchanged; zero allocation and immediate disposal counts restored."))

def main() -> IO(Unit):
  do IO<Unit>:
    result:V.VkResult(Unit) <- V.Entry.with(Unit,run)
    V.or_exit(Unit,result)
    result:V.VkResult(U32) <- V.debug_live_objects()
    live:U32 <- V.or_exit(U32,result)
    IO.try(Unit,Error.require(U32.is_zero(live),"Native upload verification leaked Vulkan objects"))
    IO.print("Standalone native upload verified; live Vulkan objects=0.")
