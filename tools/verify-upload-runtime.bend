import Base
import ../src/scene-buffer.bend as B
import ../src/scene-render.bend as R
import ../src/error.bend as Error
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/core.bend as Core
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W
import ./upload-boundary/bytes.bend as Bytes
import ./upload-boundary/checks.bend as Check

def rejected(result:V.VkResult(U32),code:U32,message:String) -> V.Action(Unit):
  Check.rejected(Result.map(&1,&1,U32 & String,U32,Unit,_ => Unit{},result),code,message)

def unchanged(+device:V.Device,+buffer:B.Buffer) -> V.Action(Unit):
  do V.Action<Unit>:
    bytes:List<U32> <- B.read(device,buffer,W.zero(),7)
    Error.require(Bytes.same(bytes,[10,11,12,13,71,72,73]),"Rejected write changed real destination")

def reject(+device:V.Device,+buffer:B.Buffer,offset:W.U64,bytes:List<&2,U32>,code:U32,message:String) -> V.Action(Unit):
  do V.Action<Unit>:
    result:V.VkResult(U32) <- V.Action.lift(V.VkResult(U32),B.write(device,buffer,offset,bytes))
    rejected(result,code,message)
    unchanged(device,buffer)

def padding(req:V.MemoryRequirements) -> V.Action(Unit):
  V.MemoryRequirements{size,_,_} = req
  V.Action.lift(Unit,IO.print(Bool.pick(String,Core.size_less(W.of_u32(7),size),"Requested capacity 7 is smaller than actual Vulkan memory requirement padding.","Device supplied no allocation padding for capacity 7.")))

def failed_new(+device:V.Device,result:V.VkResult(B.Buffer),message:String) -> V.Action(Unit):
  match result:
    case Done{buffer}:
      do V.Action<Unit>:
        B.discard(device,buffer)
        Error.require(False{},"Invalid new allocation accepted")
    case Fail{error}:Check.rejected(Fail{error},1610612739,message)

def cleanup_new(instance:V.Instance,physical:V.PhysicalDevice,+device:V.Device) -> V.Action(Unit):
  do V.Action<Unit>:
    before:U32 <- V.debug_live_objects()
    result:V.VkResult(B.Buffer) <- V.Action.lift(V.VkResult(B.Buffer),B.upload_new(instance,physical,device,vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT(),[256]))
    failed_new(device,result,"invalid memory, byte value, or copy length")
    after:U32 <- V.debug_live_objects()
    Error.require(U32.is_eq(before,after),"Failed new upload retained resources before entry teardown")

def zero_new(+instance:V.Instance,+physical:V.PhysicalDevice,+device:V.Device) -> V.Action(Unit):
  do V.Action<Unit>:
    +before:U32 <- V.debug_live_objects()
    result:V.VkResult(B.Buffer) <- V.Action.lift(V.VkResult(B.Buffer),B.allocate(instance,physical,device,W.zero(),vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT()))
    failed_new(device,result,"buffer size and usage must be nonzero")
    after:U32 <- V.debug_live_objects()
    Error.require(U32.is_eq(before,after),"Zero allocation retained objects before teardown")
    result:V.VkResult(B.Buffer) <- V.Action.lift(V.VkResult(B.Buffer),B.upload_new(instance,physical,device,vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT(),[]))
    failed_new(device,result,"buffer size and usage must be nonzero")
    after:U32 <- V.debug_live_objects()
    Error.require(U32.is_eq(before,after),"Empty upload_new retained objects before teardown")

def reject_read(+device:V.Device,+buffer:B.Buffer,offset:W.U64,count:U32) -> V.Action(Unit):
  do V.Action<Unit>:
    result:V.VkResult(List<U32>) <- V.Action.lift(V.VkResult(List<U32>),B.read(device,buffer,offset,count))
    Check.read_rejected(result,1,"Read outside requested buffer capacity")

def maximum_offsets(offsets:List<W.U64>,+device:V.Device,+buffer:B.Buffer) -> V.Action(Unit):
  match offsets:
    case []:V.Action.pure(Unit,Unit{})
    case +offset <> rest:
      do V.Action<Unit>:
        reject(device,buffer,offset,[],1,"Upload outside requested buffer capacity")
        reject(device,buffer,offset,[1,2],1,"Upload outside requested buffer capacity")
        reject_read(device,buffer,offset,0)
        reject_read(device,buffer,offset,1)
        reject_read(device,buffer,offset,4294967295)
        maximum_offsets(rest,device,buffer)

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
    count:U32 <- B.write(device,buffer,W.zero(),[])
    Error.require(U32.is_zero(count),"Empty start differs")
    bytes:List<U32> <- B.read(device,buffer,W.zero(),0)
    Error.require(Bytes.same(bytes,[]),"Empty start read differs")
    bytes:List<U32> <- B.read(device,buffer,W.of_u32(7),0)
    Error.require(Bytes.same(bytes,[]),"Empty endpoint read differs")
    unchanged(device,buffer)
    reject(device,buffer,W.of_u32(6),[1,2],1,"Upload outside requested buffer capacity")
    reject(device,buffer,W.of_u32(7),[1],1,"Upload outside requested buffer capacity")
    reject(device,buffer,W.of_u32(8),[],1,"Upload outside requested buffer capacity")
    reject(device,buffer,W.of_u32(8),[1],1,"Upload outside requested buffer capacity")
    maximum_offsets([W.U64{4294967295,0},W.U64{0,1},W.U64{0,4294967295},W.U64{4294967295,4294967295}],device,buffer)
    reject_read(device,buffer,W.of_u32(6),2)
    reject_read(device,buffer,W.of_u32(7),1)
    reject_read(device,buffer,W.of_u32(8),0)
    reject_read(device,buffer,W.zero(),4294967295)
    reject(device,buffer,W.zero(),[256],1610612739,"invalid memory, byte value, or copy length")
    reject(device,buffer,W.zero(),[90,91,4294967295],1610612739,"invalid memory, byte value, or copy length")
    req:V.MemoryRequirements <- V.Device.get_buffer_memory_requirements(device,B.handle(buffer))
    padding(req)
    B.discard(device,buffer)
    cleanup_new(instance,physical,device)
    zero_new(instance,physical,device)
    V.Action.lift(Unit,IO.print("Production small boundaries verified: empty start/end; zero allocate/upload_new; engine max-offset/read-count rejection; native invalid bytes; full unchanged destination; immediate cleanup."))

def guards(+device:V.Device,+buffer:B.Buffer) -> V.Action(Unit):
  do V.Action<Unit>:
    bytes:List<U32> <- B.read(device,buffer,W.zero(),1)
    Error.require(Bytes.same(bytes,[193]),"Production leading guard changed")
    bytes:List<U32> <- B.read(device,buffer,W.of_u32(U32.inc(Bytes.limit())),1)
    Error.require(Bytes.same(bytes,[207]),"Production trailing guard changed")

def chunks(remaining:Nat,+index:U32,+device:V.Device,+buffer:B.Buffer) -> V.Action(Unit):
  match remaining:
    case 0n:guards(device,buffer)
    case 1n+rest:
      do V.Action<Unit>:
        bytes:List<U32> <- B.read(device,buffer,W.of_u32(U32.inc(index)),65536)
        Error.require(Bytes.matches(bytes,65536n,index),"Production rejected operation changed payload chunk at " ++ U32.show(index))
        chunks(rest,(index + 65536 : U32),device,buffer)

def verify_limit(+instance:V.Instance,physical:V.PhysicalDevice,+device:V.Device) -> V.Action(Unit):
  do V.Action<Unit>:
    before:U32 <- V.debug_live_objects()
    +buffer:B.Buffer <- B.allocate(instance,physical,device,W.of_u32((Bytes.limit() + 2 : U32)),vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT())
    _:U32 <- B.write(device,buffer,W.zero(),[193])
    _:U32 <- B.write(device,buffer,W.of_u32(U32.inc(Bytes.limit())),[207])
    V.Action.lift(Unit,IO.print("Production exact-limit write/read begins: L=16777216, capacity=L+2, offset=1."))
    count:U32 <- B.write(device,buffer,W.of_u32(1),Bytes.payload(&2,U32.to_nat(Bytes.limit()),0,0))
    Error.require(U32.is_eq(count,Bytes.limit()),"Production exact-limit returned count differs")
    bytes:List<U32> <- B.read(device,buffer,W.of_u32(1),Bytes.limit())
    Error.require(Bytes.matches(bytes,U32.to_nat(Bytes.limit()),0),"Production exact-limit payload or exact list length differs")
    guards(device,buffer)
    V.Action.lift(Unit,IO.print("Production exact-limit verified: returned count=16777216; every byte and exact list exhaustion compared; both guards intact."))
    result:V.VkResult(U32) <- V.Action.lift(V.VkResult(U32),B.write(device,buffer,W.of_u32(1),Bytes.payload(&2,U32.to_nat(U32.inc(Bytes.limit())),0,255)))
    rejected(result,1,"Upload exceeds 16 MiB transport limit")
    chunks(256n,0,device,buffer)
    V.Action.lift(Unit,IO.print("Engine limit-plus-one write rejected before native dispatch; all 16777218 destination bytes unchanged in bounded chunks."))
    result:V.VkResult(List<U32>) <- V.Action.lift(V.VkResult(List<U32>),B.read(device,buffer,W.of_u32(1),U32.inc(Bytes.limit())))
    Check.read_rejected(result,1610612741,"read exceeds 16 MiB chunk limit")
    chunks(256n,0,device,buffer)
    B.discard(device,buffer)
    after:U32 <- V.debug_live_objects()
    Error.require(U32.is_eq(before,after),"Production large buffer retained objects before teardown")
    V.Action.lift(Unit,IO.print("Native limit-plus-one read rejected through production; all 16777218 destination bytes unchanged; immediate disposal count restored."))

def run(entry:V.Entry) -> V.Action(Unit):
  do V.Action<Unit>:
    Check.abi()
    +instance:V.Instance <- V.Entry.create_instance(entry,V.InstanceCreateInfo.default())
    devices:List<V.PhysicalDevice> <- V.Instance.enumerate_physical_devices(instance)
    +physical:V.PhysicalDevice <- R.first(devices)
    families:List<(U32 & U32)> <- V.Instance.get_physical_device_queue_family_properties(instance,physical)
    family:U32 <- R.choose(Core.find_queue_family(families,1),"No graphics queue")
    +device:V.Device <- V.Instance.create_device(instance,physical,V.DeviceCreateInfo{family,[]})
    verify(instance,physical,device)
    verify_limit(instance,physical,device)

def main() -> IO(Unit):
  do IO<Unit>:
    result:V.VkResult(Unit) <- V.Entry.with(Unit,run)
    V.or_exit(Unit,result)
    result:V.VkResult(U32) <- V.debug_live_objects()
    live:U32 <- V.or_exit(U32,result)
    IO.try(Unit,Error.require(U32.is_zero(live),"Upload verification leaked Vulkan objects"))
    IO.print("Production upload verified with real Vulkan writes/readback; endpoint, empty, crossing, beyond, max U64, invalid byte, unchanged rejection; live Vulkan objects=0.")
