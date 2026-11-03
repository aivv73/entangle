import Base
import ./upload-size.bend as Size
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/core.bend as Core
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W

type Buffer is Data:
  Buffer{buffer:V.Buffer,memory:V.DeviceMemory,capacity:W.U64}

def byte_length(bytes:List<&2,U32>) -> Nat:
  Size.byte_length(bytes)

def capacity_for(bytes:List<&2,U32>) -> V.Action(W.U64):
  +n = byte_length(bytes)
  do V.Action<W.U64>:
    Bool.pick(V.Action(Unit),Nat.is_le(n,16777216n),V.Action.pure(Unit,Unit{}),IO.pure(V.VkResult(Unit),Fail{(1,"Upload exceeds 16 MiB transport limit")}))
    Bool.pick(V.Action(Unit),Size.exact(n),V.Action.pure(Unit,Unit{}),IO.pure(V.VkResult(Unit),Fail{(1,"Upload byte length conversion was not exact")}))
    return Size.encode(n)

def capacity(buffer:Buffer) -> W.U64:
  Buffer{_,_,size} = buffer
  size

def handle(buffer:Buffer) -> V.Buffer:
  Buffer{b,_,_} = buffer
  b

def memory_type(found:Maybe<U32>) -> V.Action(U32):
  match found:
    case None{}:IO.pure(V.VkResult(U32),Fail{(1,"No compatible upload memory")})
    case Some{index}:V.Action.pure(U32,index)

def memory_requirements(instance:V.Instance,physical:V.PhysicalDevice,+device:V.Device,req:V.MemoryRequirements) -> V.Action(V.DeviceMemory):
  V.MemoryRequirements{size,_,bits} = req
  do V.Action<V.DeviceMemory>:
    types:List<Core.MemoryType> <- V.Instance.get_physical_device_memory_properties(instance,physical)
    index:U32 <- memory_type(Core.find_memory_type(types,bits,vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT()))
    V.Device.allocate_memory(device,size,index)

def memory(instance:V.Instance,physical:V.PhysicalDevice,+device:V.Device,buffer:V.Buffer) -> V.Action(V.DeviceMemory):
  do V.Action<V.DeviceMemory>:
    req:V.MemoryRequirements <- V.Device.get_buffer_memory_requirements(device,buffer)
    memory_requirements(instance,physical,device,req)

def low(size:W.U64) -> U32:
  W.U64{lo,_} = size
  lo

def discard(+device:V.Device,buffer:Buffer) -> V.Action(Unit):
  Buffer{b,m,_} = buffer
  do IO<V.VkResult(Unit)>:
    destroyed:V.VkResult(Unit) <- V.Device.destroy_buffer(device,b)
    freed:V.VkResult(Unit) <- V.Device.free_memory(device,m)
    return V.Entry.finish(Unit,destroyed,freed)

def bound(+device:V.Device,+buffer:V.Buffer,+memory:V.DeviceMemory,size:W.U64,result:V.VkResult(Unit)) -> V.Action(Buffer):
  match result:
    case Done{_}:V.Action.pure(Buffer,Buffer{buffer,memory,size})
    case Fail{error}:
      do IO<V.VkResult(Buffer)>:
        cleanup:V.VkResult(Unit) <- discard(device,Buffer{buffer,memory,size})
        return V.Entry.finish(Buffer,Fail{error},cleanup)

def allocated(+device:V.Device,+buffer:V.Buffer,size:W.U64,result:V.VkResult(V.DeviceMemory)) -> V.Action(Buffer):
  match result:
    case Fail{error}:
      do IO<V.VkResult(Buffer)>:
        cleanup:V.VkResult(Unit) <- V.Device.destroy_buffer(device,buffer)
        return V.Entry.finish(Buffer,Fail{error},cleanup)
    case Done{+memory}:
      do IO<V.VkResult(Buffer)>:
        result:V.VkResult(Unit) <- V.Device.bind_buffer_memory(device,buffer,memory,W.zero())
        bound(device,buffer,memory,size,result)

def allocate(+instance:V.Instance,physical:V.PhysicalDevice,+device:V.Device,+size:W.U64,usage:U32) -> V.Action(Buffer):
  do V.Action<Buffer>:
    +buffer:V.Buffer <- V.Device.create_buffer(device,V.BufferCreateInfo{size,usage})
    result:V.VkResult(V.DeviceMemory) <- V.Action.lift(V.VkResult(V.DeviceMemory),memory(instance,physical,device,buffer))
    allocated(device,buffer,size,result)

def write(device:V.Device,buffer:Buffer,+offset:W.U64,+bytes:List<&2,U32>) -> V.Action(U32):
  Buffer{_,memory,size} = buffer
  do V.Action<U32>:
    +length:W.U64 <- capacity_for(bytes)
    Bool.pick(V.Action(U32),Core.subrange_contains(size,offset,length),
      do V.Action<U32>:
        V.Device.write_memory(device,memory,offset,Size.transport(bytes))
        return low(length),
      IO.pure(V.VkResult(U32),Fail{(1,"Upload outside requested buffer capacity")}))

def read(device:V.Device,buffer:Buffer,+offset:W.U64,+length:U32) -> V.Action(List<U32>):
  Buffer{_,memory,size} = buffer
  Bool.pick(V.Action(List<U32>),Core.subrange_contains(size,offset,W.of_u32(length)),
    V.Device.read_memory(device,memory,offset,length),
    IO.pure(V.VkResult(List<U32>),Fail{(1,"Read outside requested buffer capacity")}))

def uploaded(+device:V.Device,+buffer:Buffer,result:V.VkResult(U32)) -> V.Action(Buffer):
  match result:
    case Done{_}:V.Action.pure(Buffer,buffer)
    case Fail{error}:
      do IO<V.VkResult(Buffer)>:
        cleanup:V.VkResult(Unit) <- discard(device,buffer)
        return V.Entry.finish(Buffer,Fail{error},cleanup)

def upload_new(instance:V.Instance,physical:V.PhysicalDevice,+device:V.Device,usage:U32,+bytes:List<&2,U32>) -> V.Action(Buffer):
  do V.Action<Buffer>:
    size:W.U64 <- capacity_for(bytes)
    +buffer:Buffer <- allocate(instance,physical,device,size,usage)
    result:V.VkResult(U32) <- V.Action.lift(V.VkResult(U32),write(device,buffer,W.zero(),bytes))
    uploaded(device,buffer,result)

def retire(device:V.Device,buffer:Buffer) -> V.Action(Unit):
  Buffer{b,m,_} = buffer
  V.Device.retire_buffers(device,[(b,m)])
