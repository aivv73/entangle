import ./content.bend as F
import Base
import ./scene-buffer.bend as B
import ./scene-geometry-policy.bend as Policy
import ./creation.bend as Create
import ./components.bend as C
import ./error.bend as Error
import ./scene-diagnostics.bend as Diag
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/core.bend as Core
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W

type Context is Data:
  Context{instance:V.Instance,physical:V.PhysicalDevice,device:V.Device}
type Buffers is Data:
  Buffers{vertices:B.Buffer,indices:B.Buffer}
type Resident is Data:
  Resident{buffers:Maybe<&2,Buffers>,ranges:List<&2,Create.Range>}
type Failure is Type:
  Failure{cause:U32 & String,cleanup:List<(U32 & String)>}
type ReplaceStatus is Type:
  Installed{}
  Rejected{error:Failure}
type Preparation is Type:
  Prepared{resident:Resident,probe:Diag.Probe}
  Unprepared{error:Failure,probe:Diag.Probe}
type Payload is Data:
  Payload{vertices:List<&2,U32>,indices:List<&2,U32>,vertex_size:W.U64,index_size:W.U64,ranges:List<&2,Create.Range>}

def device(context:Context) -> V.Device:
  Context{_,_,device} = context
  device

def buffers(resident:Resident) -> Maybe<&2,Buffers>:
  Resident{buffers,_} = resident
  buffers

def ranges(resident:Resident) -> List<&2,Create.Range>:
  Resident{_,ranges} = resident
  ranges

def word_bytes(+word:U32) -> List<&2,U32>:
  [Core.word_byte(word,0),Core.word_byte(word,1),Core.word_byte(word,2),Core.word_byte(word,3)]

def bytes(words:List<U32>) -> List<&2,U32>:
  match words:
    case []:[]
    case word <> rest:List.append(&2,U32,word_bytes(word),bytes(rest))

def vertex_words(v:F.Vertex) -> List<U32>:
  F.Vertex{C.Vec3{x,y,z},C.Vec3{r,g,b}} = v
  [F32.bits(x),F32.bits(y),F32.bits(z),F32.bits(r),F32.bits(g),F32.bits(b)]

def vertices_bytes(vertices:List<&2,F.Vertex>) -> List<&2,U32>:
  match vertices:
    case []:[]
    case v <> rest:List.append(&2,U32,bytes(vertex_words(v)),vertices_bytes(rest))

def indices_bytes(indices:List<&2,U32>) -> List<&2,U32>:
  match indices:
    case []:[]
    case i <> rest:List.append(&2,U32,word_bytes(i),indices_bytes(rest))

def payload(+mesh:Create.Geometry) -> V.Action(Payload):
  Create.Geometry{vertices,indices,ranges} = mesh
  do V.Action<Payload>:
    Error.require(Create.geometry_valid(mesh),"Invalid mesh")
    +vb:List<&2,U32> = vertices_bytes(vertices)
    +ib:List<&2,U32> = indices_bytes(indices)
    vs:W.U64 <- B.capacity_for(vb)
    isz:W.U64 <- B.capacity_for(ib)
    return Payload{vb,ib,vs,isz,ranges}

def allocations(value:Maybe<&2,Buffers>) -> List<(V.Buffer & V.DeviceMemory)>:
  match value:
    case None{}:Policy.allocations((V.Buffer & V.DeviceMemory),None{})
    case Some{Buffers{vertices,indices}}:Policy.allocations((V.Buffer & V.DeviceMemory),Some{(B.allocation(vertices),B.allocation(indices))})

def errors(result:V.VkResult(Unit)) -> List<(U32 & String)>:
  match result:
    case Done{_}:[]
    case Fail{error}:[error]

def dispose(+device:V.Device,value:Maybe<&2,Buffers>) -> IO(List<(U32 & String)>):
  match value:
    case None{}:IO.pure(List<(U32 & String)>,[])
    case Some{Buffers{vertices,indices}}:
      do IO<List<(U32 & String)>>:
        a:V.VkResult(Unit) <- B.discard(device,vertices)
        b:V.VkResult(Unit) <- B.discard(device,indices)
        return List.append(&1,(U32 & String),errors(a),errors(b))

def failed(+device:V.Device,value:Maybe<&2,Buffers>,cause:U32 & String,probe:Diag.Probe) -> IO(Preparation):
  do IO<Preparation>:
    cleanup:List<(U32 & String)> <- dispose(device,value)
    return Unprepared{Failure{cause,cleanup},probe}

def written(result:V.VkResult(U32),+probe:Diag.Probe,name:String,start:Diag.Metric<&2,W.U64>) -> IO(V.VkResult(U32) & Diag.Probe):
  match result:
    case Fail{error}:IO.pure(V.VkResult(U32) & Diag.Probe,(Fail{error},probe))
    case Done{+count}:
      do IO<V.VkResult(U32) & Diag.Probe>:
        probe:Diag.Probe <- Diag.span(Diag.upload(probe,count),name,start)
        return (Done{count},probe)

def write(+device:V.Device,buffer:B.Buffer,bytes:List<&2,U32>,+probe:Diag.Probe,name:String) -> IO(V.VkResult(U32) & Diag.Probe):
  do IO<V.VkResult(U32) & Diag.Probe>:
    start:Diag.Metric<&2,W.U64> <- Diag.now(Diag.enabled(probe))
    result:V.VkResult(U32) <- B.write(device,buffer,W.zero(),bytes)
    written(result,probe,name,start)

def uploaded(device:V.Device,+value:Buffers,ranges:List<&2,Create.Range>,pair:V.VkResult(U32) & Diag.Probe) -> IO(Preparation):
  match pair:
    case (Fail{cause},probe):failed(device,Some{value},cause,probe)
    case (Done{_},probe):IO.pure(Preparation,Prepared{Resident{Some{value},ranges},probe})

def vertex_uploaded(+device:V.Device,+value:Buffers,payload:Payload,pair:V.VkResult(U32) & Diag.Probe) -> IO(Preparation):
  Buffers{vb,+ib} = value
  Payload{vertices,indices,vs,isz,ranges} = payload
  match pair:
    case (Fail{cause},probe):failed(device,Some{value},cause,probe)
    case (Done{_},probe):
      do IO<Preparation>:
        pair:V.VkResult(U32) & Diag.Probe <- write(device,ib,indices,probe,"mesh_index_host_write")
        uploaded(device,value,ranges,pair)

def upload(+device:V.Device,+value:Buffers,+payload:Payload,probe:Diag.Probe) -> IO(Preparation):
  Buffers{+vb,ib} = value
  Payload{+vertices,indices,vs,isz,ranges} = payload
  do IO<Preparation>:
    pair:V.VkResult(U32) & Diag.Probe <- write(device,vb,vertices,probe,"mesh_vertex_host_write")
    vertex_uploaded(device,value,payload,pair)

def index_allocated(+device:V.Device,+vb:B.Buffer,payload:Payload,probe:Diag.Probe,result:V.VkResult(B.Buffer)) -> IO(Preparation):
  match result:
    case Fail{cause}:
      do IO<Preparation>:
        cleanup:V.VkResult(Unit) <- B.discard(device,vb)
        return Unprepared{Failure{cause,errors(cleanup)},probe}
    case Done{ib}:upload(device,Buffers{vb,ib},payload,probe)

def vertex_allocated(context:Context,+payload:Payload,probe:Diag.Probe,result:V.VkResult(B.Buffer)) -> IO(Preparation):
  Context{instance,physical,+device} = context
  Payload{vertices,indices,vs,+isz,ranges} = payload
  match result:
    case Fail{cause}:IO.pure(Preparation,Unprepared{Failure{cause,[]},probe})
    case Done{+vb}:
      do IO<Preparation>:
        result:V.VkResult(B.Buffer) <- B.allocate(instance,physical,device,isz,vk.VK_BUFFER_USAGE_INDEX_BUFFER_BIT())
        index_allocated(device,vb,payload,probe,result)

def allocate(+context:Context,+payload:Payload,probe:Diag.Probe) -> IO(Preparation):
  Context{instance,physical,device} = context
  Payload{vertices,indices,vs,isz,ranges} = payload
  do IO<Preparation>:
    result:V.VkResult(B.Buffer) <- B.allocate(instance,physical,device,vs,vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT())
    vertex_allocated(context,payload,probe,result)

def validated(context:Context,probe:Diag.Probe,result:V.VkResult(Payload)) -> IO(Preparation):
  match result:
    case Fail{cause}:IO.pure(Preparation,Unprepared{Failure{cause,[]},probe})
    case Done{+value}:
      Payload{vertices,indices,vs,isz,+ranges} = value
      match indices:
        case []:IO.pure(Preparation,Prepared{Resident{None{},ranges},probe})
        case _:allocate(context,value,probe)

def prepare(context:Context,mesh:Create.Geometry,probe:Diag.Probe) -> IO(Preparation):
  do IO<Preparation>:
    result:V.VkResult(Payload) <- payload(mesh)
    validated(context,probe,result)

def retire_pairs(device:V.Device,pairs:List<(V.Buffer & V.DeviceMemory)>) -> V.Action(Unit):
  match pairs:
    case []:V.Action.pure(Unit,Unit{})
    case pairs:V.Device.retire_buffers(device,pairs)

def retire(device:V.Device,resident:Resident) -> V.Action(Unit):
  retire_pairs(device,allocations(buffers(resident)))

def sealed(+device:V.Device,+old:Resident,+fresh:Resident,result:V.VkResult(Unit)) -> IO(Resident & ReplaceStatus):
  match result:
    # Publication must be the next effect after successful paired retirement.
    case Done{_}:IO.pure(Resident & ReplaceStatus,(Policy.select(Resident,old,fresh,True{}),Installed{}))
    case Fail{cause}:
      do IO<Resident & ReplaceStatus>:
        cleanup:List<(U32 & String)> <- dispose(device,buffers(fresh))
        return (Policy.select(Resident,old,fresh,False{}),Rejected{Failure{cause,cleanup}})

def install(+device:V.Device,+old:Resident,+fresh:Resident) -> IO(Resident & ReplaceStatus):
  do IO<Resident & ReplaceStatus>:
    result:V.VkResult(Unit) <- retire(device,old)
    sealed(device,old,fresh,result)

def installed(pair:Resident & ReplaceStatus,probe:Diag.Probe) -> Resident & (ReplaceStatus & Diag.Probe):
  (resident,status) = pair
  (resident,(status,probe))

def prepared(context:Context,old:Resident,value:Preparation) -> IO(Resident & (ReplaceStatus & Diag.Probe)):
  match value:
    case Unprepared{error,probe}:IO.pure(Resident & (ReplaceStatus & Diag.Probe),(old,(Rejected{error},probe)))
    case Prepared{fresh,probe}:
      do IO<Resident & (ReplaceStatus & Diag.Probe)>:
        pair:Resident & ReplaceStatus <- install(device(context),old,fresh)
        return installed(pair,probe)

def replace(+context:Context,old:Resident,mesh:Create.Geometry,probe:Diag.Probe) -> IO(Resident & (ReplaceStatus & Diag.Probe)):
  do IO<Resident & (ReplaceStatus & Diag.Probe)>:
    value:Preparation <- prepare(context,mesh,probe)
    prepared(context,old,value)

def append_error(cause:U32 & String,code:U32,message:String) -> U32 & String:
  (original,text) = cause
  (original,text ++ "; cleanup error " ++ U32.show(code) ++ ": " ++ message)

def append_cleanup(cleanup:List<(U32 & String)>,cause:U32 & String) -> U32 & String:
  match cleanup:
    case []:cause
    case (code,message) <> rest:
      append_cleanup(rest,append_error(cause,code,message))

def failure(error:Failure) -> U32 & String:
  Failure{cause,cleanup} = error
  append_cleanup(cleanup,cause)

def created(value:Preparation) -> V.Action(Resident & Diag.Probe):
  match value:
    case Prepared{resident,probe}:V.Action.pure(Resident & Diag.Probe,(resident,probe))
    case Unprepared{error,_}:IO.pure(V.VkResult(Resident & Diag.Probe),Fail{failure(error)})

def create(context:Context,mesh:Create.Geometry,probe:Diag.Probe) -> V.Action(Resident & Diag.Probe):
  do IO<V.VkResult(Resident & Diag.Probe)>:
    value:Preparation <- prepare(context,mesh,probe)
    created(value)
