import ../src/content.bend as F
import Base
import ../src/scene-buffer.bend as B
import ../src/scene-geometry.bend as G
import ../src/scene-diagnostics.bend as Diag
import ../src/measurement-counters.bend as Count
import ../src/creation.bend as Create
import ../src/components.bend as C
import ../src/scene-render.bend as R
import ../src/app.bend as Scope
import ../src/error.bend as Error
import ./verify-buffer-retention.bend as Retention
import ./process-address-limit.bend as Limit
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/core.bend as Core
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W

def rejected(-A:Type,result:V.VkResult(A),code:U32,message:String) -> V.Action(Unit):
  match result:
    case Fail{(+actual,+text)}:Error.require(U32.is_eq(actual,code) && String.eq(text,message),"Unexpected native error: " ++ U32.show(actual) ++ " " ++ text)
    case _:Error.require(False{},"Expected native failure: " ++ message)

def recording(+context:G.Context) -> V.Action(Unit):
  G.Context{instance,physical,+device} = context
  do V.Action<Unit>:
    +base:U32 <- V.debug_live_objects()
    +buffer:B.Buffer <- B.allocate(instance,physical,device,W.of_u32(4),vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT())
    +pool:V.CommandPool <- V.Device.create_command_pool(device)
    +command:V.CommandBuffer <- V.Device.allocate_command_buffer(device,pool)
    +fence:V.Fence <- V.Device.create_fence(device,True{})
    V.CommandBuffer.begin(command)
    V.CommandBuffer.fill_buffer(command,B.handle(buffer),W.zero(),W.of_u32(4),287454020)
    result:V.VkResult(Unit) <- V.Action.lift(V.VkResult(Unit),V.CommandBuffer.fill_buffer(command,B.handle(buffer),W.zero(),W.of_u32(3),0))
    rejected(Unit,result,1610612739,"invalid fill offset, size, alignment, or usage")
    Retention.reject(Unit,"Earlier recording survives rejected command",B.discard(device,buffer))
    Retention.reject(Unit,"Begin while recording",V.CommandBuffer.begin(command))
    Retention.reject(Unit,"Submit while recording",V.Device.submit(device,command,fence))
    V.CommandBuffer.pipeline_barrier(command,vk.VK_PIPELINE_STAGE_TRANSFER_BIT(),vk.VK_PIPELINE_STAGE_HOST_BIT(),[V.MemoryBarrier{vk.VK_ACCESS_TRANSFER_WRITE_BIT(),vk.VK_ACCESS_HOST_READ_BIT()}],[],[])
    V.CommandBuffer.end(command)
    Retention.reject(Unit,"End an executable command",V.CommandBuffer.end(command))
    result:V.VkResult(Unit) <- V.Action.lift(V.VkResult(Unit),V.Device.submit(device,command,fence))
    rejected(Unit,result,1610612740,"submit fence must be unsignaled")
    Retention.reject(Unit,"Rejected submit retains executable references",B.discard(device,buffer))
    V.Fence.reset(fence)
    V.Device.submit(device,command,fence)
    Retention.reject(Unit,"Reset pending command",V.CommandBuffer.reset(command))
    Retention.reject(Unit,"Reset pending fence",V.Fence.reset(fence))
    Retention.reject(Unit,"Destroy pending fence",V.Device.destroy_fence(device,fence))
    Retention.reject(Unit,"Destroy pending pool",V.Device.destroy_command_pool(device,pool))
    Retention.reject(Unit,"Resubmit pending command",V.Device.submit(device,command,fence))
    Retention.reject(List<U32>,"Read pending memory",B.read(device,buffer,W.zero(),4))
    Retention.count(U32.add(base,5),"Rejected operations preserve all native objects")
    Retention.wait(fence)
    bytes:List<U32> <- B.read(device,buffer,W.zero(),4)
    Error.require(Retention.equal_bytes(bytes,[68,51,34,17]),"Accepted GPU fill changed after rejected recording or submission")
    B.retire(device,buffer)
    Retention.retained(device,buffer,U32.add(base,5),"Completion preserves command references after failures")
    V.CommandBuffer.reset(command)
    V.Device.collect_retired(device)
    Retention.gone(device,buffer)
    Retention.count(U32.add(base,3),"Only successful reset releases the recorded allocation")
    V.Fence.reset(fence)
    V.CommandBuffer.begin(command)
    V.CommandBuffer.end(command)
    V.Device.submit(device,command,fence)
    Retention.wait(fence)
    V.CommandBuffer.reset(command)
    V.Device.destroy_command_pool(device,pool)
    V.Device.destroy_fence(device,fence)
    Retention.count(base,"Command and fence remain reusable")
    V.Action.lift(Unit,IO.print("Recording, submit and pending-reset rejections preserve native references; original GPU fill reads back exactly; successful reset permits collection and reuse."))

def indices(n:Nat) -> List<&2,U32>:
  match n:
    case 0n:[]
    case 1n+rest:0 <> 1 <> 2 <> indices(rest)

def mesh(+n:Nat) -> Create.Geometry:
  Create.Geometry{[
    F.Vertex{C.Vec3{0.0,0.0,0.0},C.Vec3{1.0,0.0,0.0}},
    F.Vertex{C.Vec3{1.0,0.0,0.0},C.Vec3{1.0,0.0,0.0}},
    F.Vertex{C.Vec3{0.0,1.0,0.0},C.Vec3{1.0,0.0,0.0}}],indices(n),[Create.Range{7,0,U32.from_nat(Nat.mul(3n,n))}]}

def counts(probe:Diag.Probe,writes:U32,bytes:U32) -> V.Action(Unit):
  match probe:
    case Diag.On{_,_,_,_,Count.Counters{actual,W.U64{lo,hi},_,_,_,_},_,_,_,_}:
      Error.require(U32.is_eq(actual,writes) && U32.is_eq(lo,bytes) && U32.is_zero(hi),"Failed preparation changed successful-upload counters")
    case _:Error.require(False{},"Failure verifier requires enabled diagnostics")

def cleanup_errors(errors:List<(U32 & String)>,expected:Nat) -> V.Action(Unit):
  match errors expected:
    case [] 0n:V.Action.pure(Unit,Unit{})
    case (code,message) <> rest 1n+n:
      do V.Action<Unit>:
        rejected(Unit,Fail{(code,message)},1610612740,"command pool still references buffer; cleanup error 1610612740: destroy bound resources before freeing memory")
        cleanup_errors(rest,n)
    case _ _:Error.require(False{},"Rollback lost or added cleanup failures")

def failed(value:G.Preparation,code:U32,message:String,errors:Nat,writes:U32,bytes:U32) -> V.Action(Diag.Probe):
  match value:
    case G.Unprepared{G.Failure{cause,cleanup},+probe}:
      do V.Action<Diag.Probe>:
        rejected(Unit,Fail{cause},code,message)
        cleanup_errors(cleanup,errors)
        counts(probe,writes,bytes)
        return probe
    case _:Error.failure(Diag.Probe,1,"Expected failed preparation")

def hold(+command:V.CommandBuffer,buffer:B.Buffer,held:Bool) -> V.Action(Unit):
  match held:
    case False{}:V.Action.pure(Unit,Unit{})
    case True{}:V.CommandBuffer.pipeline_barrier(command,vk.VK_PIPELINE_STAGE_HOST_BIT(),vk.VK_PIPELINE_STAGE_VERTEX_INPUT_BIT(),[],[V.BufferMemoryBarrier{B.handle(buffer),W.zero(),Core.whole_size(),vk.VK_ACCESS_HOST_WRITE_BIT(),vk.VK_ACCESS_INDEX_READ_BIT()}],[])

def released(+device:V.Device,+buffer:B.Buffer,held:Bool) -> V.Action(Unit):
  match held:
    case False{}:Retention.gone(device,buffer)
    case True{}:
      do V.Action<Unit>:
        req:V.MemoryRequirements <- V.Device.get_buffer_memory_requirements(device,B.handle(buffer))
        B.discard(device,buffer)

def rollback(+context:G.Context,+first:Bool,+second:Bool) -> V.Action(Unit):
  G.Context{+instance,+physical,+device} = context
  +remaining = U32.to_nat(U32.add(Bool.to_u32(first),Bool.to_u32(second)))
  do V.Action<Unit>:
    +base:U32 <- V.debug_live_objects()
    +probe:Diag.Probe <- V.Action.lift(Diag.Probe,Diag.create(device))
    +before:U32 <- V.debug_live_objects()
    +vb:B.Buffer <- B.allocate(instance,physical,device,W.of_u32(4),vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT())
    +ib:B.Buffer <- B.allocate(instance,physical,device,W.of_u32(4),vk.VK_BUFFER_USAGE_INDEX_BUFFER_BIT())
    +pool:V.CommandPool <- V.Device.create_command_pool(device)
    +command:V.CommandBuffer <- V.Device.allocate_command_buffer(device,pool)
    V.CommandBuffer.begin(command)
    hold(command,vb,first)
    hold(command,ib,second)
    value:G.Preparation <- V.Action.lift(G.Preparation,G.upload(device,G.Buffers{vb,ib},G.Payload{[1,2,3,4],[0,1,2,256],W.of_u32(4),W.of_u32(4),[]},probe))
    probe:Diag.Probe <- failed(value,1610612739,"invalid memory, byte value, or copy length",remaining,1,4)
    Retention.count(U32.add(before,U32.add(2,U32.mul(2,U32.from_nat(remaining)))),"Rollback attempts both candidate disposals")
    V.CommandBuffer.reset(command)
    released(device,vb,first)
    released(device,ib,second)
    V.Device.destroy_command_pool(device,pool)
    Diag.close(probe,device)
    Retention.count(base,"Rollback cleanup can complete after references release")
    V.Action.lift(Unit,IO.print("Partial upload rollback: retained-pairs=" ++ Nat.show(remaining) ++ " first=" ++ U32.show(Bool.to_u32(first)) ++ " second=" ++ U32.show(Bool.to_u32(second)) ++ "; primary error, every cleanup error, successful writes and exact live counts preserved."))

def vertex_data(value:Create.Geometry) -> List<&2,U32>:
  Create.Geometry{vertices,_,_} = value
  G.vertices_bytes(vertices)

def bytes_equal(a:List<U32>,b:List<&2,U32>) -> Bool:
  match a b:
    case [],[]:True{}
    case x <> xs,y <> ys:U32.is_eq(x,y) && bytes_equal(xs,ys)
    case _,_:False{}

def original(+device:V.Device,resident:G.Resident) -> V.Action(Unit):
  match resident:
    case G.Resident{Some{G.Buffers{vb,ib}},[Create.Range{7,0,3}]}:
      do V.Action<Unit>:
        vertices:List<U32> <- B.read(device,vb,W.zero(),72)
        indices:List<U32> <- B.read(device,ib,W.zero(),12)
        Error.require(bytes_equal(vertices,vertex_data(mesh(1n))) && Retention.equal_bytes(indices,[0,0,0,0,1,0,0,0,2,0,0,0]),"Failed preparation changed old resident bytes or ranges")
    case _:Error.require(False{},"Failed preparation replaced old resident")

def same_pair(a:V.Buffer & V.DeviceMemory,b:V.Buffer & V.DeviceMemory) -> Bool:
  (V.Buffer{ab},V.DeviceMemory{am}) = a
  (V.Buffer{bb},V.DeviceMemory{bm}) = b
  U32.is_eq(ab,bb) && U32.is_eq(am,bm)

def same_owner(a:G.Resident,b:G.Resident) -> Bool:
  match a b:
    case G.Resident{Some{G.Buffers{av,ai}},_} G.Resident{Some{G.Buffers{bv,bi}},_}:
      same_pair(B.allocation(av),B.allocation(bv)) && same_pair(B.allocation(ai),B.allocation(bi))
    case _ _:False{}

def retained_status(+device:V.Device,old:G.Resident,+resident:G.Resident,status:G.ReplaceStatus,+probe:Diag.Probe) -> V.Action(Unit):
  match status:
    case G.Rejected{G.Failure{(+code,+message),[]}}:
      do V.Action<Unit>:
        Error.require((U32.is_eq(code,4294967294) && String.eq(message,"vkAllocateMemory: VkResult -2")) || (U32.is_eq(code,4294967295) && String.eq(message,"vkAllocateMemory: VkResult -1")),"Expected genuine Vulkan allocation failure; got " ++ U32.show(code) ++ " " ++ message)
        counts(probe,0,0)
        Error.require(same_owner(old,resident),"Failed preparation changed native allocation identities")
        original(device,resident)
        cleanup:List<(U32 & String)> <- V.Action.lift(List<(U32 & String)>,G.dispose(device,G.buffers(resident)))
        cleanup_errors(cleanup,0n)
        Diag.close(probe,device)
        V.Action.lift(Unit,IO.print("Genuine partial preparation failure: " ++ message ++ "; first allocation rolled back; original resident and diagnostic owner returned intact."))
    case _:Error.require(False{},"Allocation pressure did not produce a clean rejected replacement")

def retained_owner(device:V.Device,old:G.Resident,pair:G.Resident & (G.ReplaceStatus & Diag.Probe)) -> V.Action(Unit):
  (resident,(status,probe)) = pair
  retained_status(device,old,resident,status,probe)

def partial(+context:G.Context,+old:G.Resident,probe:Diag.Probe,+payload:G.Payload) -> V.Action(Unit):
  G.Context{instance,physical,+device} = context
  G.Payload{_,_,vertex_size,_,_} = payload
  do V.Action<Unit>:
    +base:U32 <- V.debug_live_objects()
    +candidate:B.Buffer <- B.allocate(instance,physical,device,vertex_size,vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT())
    Retention.count(U32.add(base,2),"First candidate allocation exists before pressure")
    limit:Limit.Limit <- V.Action.lift(Limit.Limit,Limit.restrict(4096))
    value:G.Preparation <- V.Action.lift(G.Preparation,G.vertex_allocated(context,payload,probe,Done{candidate}))
    V.Action.lift(Unit,Limit.restore(limit))
    Retention.count(base,"Partial native allocation rollback immediately restores count")
    Retention.gone(device,candidate)
    pair:G.Resident & (G.ReplaceStatus & Diag.Probe) <- V.Action.lift(G.Resident & (G.ReplaceStatus & Diag.Probe),G.prepared(context,old,value))
    retained_owner(device,old,pair)

def allocated(+context:G.Context,pair:G.Resident & Diag.Probe) -> V.Action(Unit):
  (old,_) = pair
  do V.Action<Unit>:
    probe:Diag.Probe <- V.Action.lift(Diag.Probe,Diag.create(G.device(context)))
    # A valid, serialized mesh below the production 16 MiB per-buffer limit.
    payload:G.Payload <- G.payload(mesh(699050n))
    partial(context,old,probe,payload)

def recovered(+context:G.Context,pair:G.Resident & Diag.Probe) -> V.Action(Unit):
  (+resident,_) = pair
  do V.Action<Unit>:
    original(G.device(context),resident)
    cleanup:List<(U32 & String)> <- V.Action.lift(List<(U32 & String)>,G.dispose(G.device(context),G.buffers(resident)))
    cleanup_errors(cleanup,0n)
    V.Action.lift(Unit,IO.print("Allocation and upload succeed again after restoring the process limit."))

def allocation(+context:G.Context) -> V.Action(Unit):
  do V.Action<Unit>:
    +base:U32 <- V.debug_live_objects()
    pair:G.Resident & Diag.Probe <- G.create(context,mesh(1n),Diag.Off{})
    allocated(context,pair)
    Retention.count(base,"Allocation-pressure scenario restores all resources")
    pair:G.Resident & Diag.Probe <- G.create(context,mesh(1n),Diag.Off{})
    recovered(context,pair)
    Retention.count(base,"Successful retry releases all resources")

def context(entry:V.Entry) -> V.Action(G.Context):
  do V.Action<G.Context>:
    +instance:V.Instance <- V.Entry.create_instance(entry,V.InstanceCreateInfo.default())
    devices:List<V.PhysicalDevice> <- V.Instance.enumerate_physical_devices(instance)
    +physical:V.PhysicalDevice <- R.first(devices)
    families:List<(U32 & U32)> <- V.Instance.get_physical_device_queue_family_properties(instance,physical)
    family:U32 <- R.choose(Core.find_queue_family(families,1),"No graphics queue")
    +device:V.Device <- V.Instance.create_device(instance,physical,V.DeviceCreateInfo{family,[]})
    return G.Context{instance,physical,device}

def run(entry:V.Entry) -> V.Action(Unit):
  do V.Action<Unit>:
    +context:G.Context <- context(entry)
    recording(context)
    rollback(context,False{},False{})
    rollback(context,True{},False{})
    rollback(context,False{},True{})
    rollback(context,True{},True{})
    allocation(context)

def terminal_context(context:G.Context) -> V.Action(Unit):
  G.Context{+instance,+physical,+device} = context
  do V.Action<Unit>:
    +vb:B.Buffer <- B.allocate(instance,physical,device,W.of_u32(4),vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT())
    +ib:B.Buffer <- B.allocate(instance,physical,device,W.of_u32(4),vk.VK_BUFFER_USAGE_INDEX_BUFFER_BIT())
    pool:V.CommandPool <- V.Device.create_command_pool(device)
    +command:V.CommandBuffer <- V.Device.allocate_command_buffer(device,pool)
    V.CommandBuffer.begin(command)
    hold(command,vb,True{})
    hold(command,ib,True{})
    value:G.Preparation <- V.Action.lift(G.Preparation,G.upload(device,G.Buffers{vb,ib},G.Payload{[1,2,3,4],[0,1,2,256],W.of_u32(4),W.of_u32(4),[]},Diag.Off{}))
    _:G.Resident & Diag.Probe <- G.created(value)
    Error.require(False{},"Expected terminal partial-upload failure")

def terminal(entry:V.Entry) -> V.Action(Unit):
  do V.Action<Unit>:
    context:G.Context <- context(entry)
    terminal_context(context)

def terminal_finished(pair:V.VkResult(Unit) & U32) -> IO(Unit):
  (result,live) = pair
  +cleanup:String = "; cleanup error 1610612740: command pool still references buffer; cleanup error 1610612740: destroy bound resources before freeing memory"
  do IO<Unit>:
    checked:V.VkResult(Unit) <- rejected(Unit,result,1610612739,"invalid memory, byte value, or copy length" ++ cleanup ++ cleanup)
    V.or_exit(Unit,checked)
    checked:V.VkResult(Unit) <- Error.require(U32.is_zero(live),"Terminal failure leaked native resources")
    V.or_exit(Unit,checked)
    IO.print("Terminal entry teardown releases both retained candidates and commands; initiating error and both cleanup diagnostics preserved; live Vulkan objects: 0")

def finished(pair:V.VkResult(Unit) & U32) -> IO(Unit):
  (result,live) = pair
  do IO<Unit>:
    V.or_exit(Unit,result)
    V.or_exit(Unit, Bool.pick(V.VkResult(Unit),U32.is_zero(live),Done{Unit{}},Fail{(1,"Native failure verification leaked resources")}))
    IO.print("Recoverable native resource failures verified; live Vulkan objects: 0")

def main() -> IO(Unit):
  do IO<Unit>:
    pair:V.VkResult(Unit) & U32 <- Scope.with(Unit,run)
    finished(pair)
    pair:V.VkResult(Unit) & U32 <- Scope.with(Unit,terminal)
    terminal_finished(pair)
    IO.print("Native resource failure verification passed; live Vulkan objects: 0")
    IO.print("Unexercised: uncertain submission, device loss, Vulkan begin/end/reset errors, and driver-level cleanup errors.")
