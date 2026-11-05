import Base
import ./creation.bend as Create
import ./scene-texture.bend as T
import ./content.bend as F
import ../deps/bend-vulkan/Vulkan.bend as V

type Binding is Data:
  Binding{id:U32,material:T.Material}
type Resident is Data:
  Resident{active:List<&2,Binding>,retired:List<&2,List<&2,T.Resource>>}

def empty() -> Resident:Resident{[],[]}

def finish_release(-A:Type,result:V.VkResult(A),release:T.Release) -> V.VkResult(A):
  match release:
    case T.Released{}:result
    case T.Pending{_,error}:V.Entry.finish(A,result,Fail{error})

def created(+device:V.Device,+id:U32,+material:T.Material,result:V.VkResult(List<&2,Binding>)) -> V.Action(List<&2,Binding>):
  T.Material{_,owned} = material
  match result:
    case Done{rest}:V.Action.pure(List<&2,Binding>,Binding{id,material} <> rest)
    case Fail{error}:
      do IO<V.VkResult(List<&2,Binding>)>:
        release:T.Release <- T.release(device,owned)
        return finish_release(List<&2,Binding>,Fail{error},release)

def create(+instance:V.Instance,+physical:V.PhysicalDevice,+device:V.Device,ranges:List<&2,Create.Range>) -> V.Action(List<&2,Binding>):
  match ranges:
    case []:V.Action.pure(List<&2,Binding>,[])
    case Create.Range{_,_,_,None{}} <> rest:create(instance,physical,device,rest)
    case Create.Range{_,_,0,_} <> rest:create(instance,physical,device,rest)
    case Create.Range{+id,_,_,Some{source}} <> rest:
      do V.Action<List<&2,Binding>>:
        +material:T.Material <- T.upload(instance,physical,device,source)
        result:V.VkResult(List<&2,Binding>) <- V.Action.lift(V.VkResult(List<&2,Binding>),create(instance,physical,device,rest))
        created(device,id,material,result)

def find(bindings:List<&2,Binding>,+id:U32) -> Maybe<T.Material>:
  match bindings:
    case []:None{}
    case Binding{other,material} <> rest:Bool.pick(Maybe<T.Material>,U32.is_eq(other,id),Some{material},find(rest,id))

def material(resident:Resident,id:U32) -> Maybe<T.Material>:
  Resident{active,_} = resident
  find(active,id)

def ownership(bindings:List<&2,Binding>) -> List<&2,List<&2,T.Resource>>:
  match bindings:
    case []:[]
    case Binding{_,T.Material{_,owned}} <> rest:owned <> ownership(rest)

def retire(old:Resident,fresh:Resident) -> Resident:
  Resident{active,retired} = old
  Resident{next,pending} = fresh
  Resident{next,List.concat(&2,List<&2,T.Resource>,[ownership(active),retired,pending])}

def collected(result:T.Release,pair:List<&2,List<&2,T.Resource>> & V.VkResult(Unit)) -> List<&2,List<&2,T.Resource>> & V.VkResult(Unit):
  match result pair:
    case T.Released{}, (rest,status):(rest,status)
    case T.Pending{remaining,(1610612740,_)}, (rest,status):(remaining <> rest,status)
    case T.Pending{remaining,error}, (rest,status):(remaining <> rest,V.Entry.finish(Unit,Fail{error},status))

def collect_all(+device:V.Device,retired:List<&2,List<&2,T.Resource>>) -> IO(List<&2,List<&2,T.Resource>> & V.VkResult(Unit)):
  match retired:
    case []:IO.pure(List<&2,List<&2,T.Resource>> & V.VkResult(Unit),([],Done{Unit{}}))
    case owned <> rest:
      do IO<List<&2,List<&2,T.Resource>> & V.VkResult(Unit)>:
        result:T.Release <- T.release(device,owned)
        pair:List<&2,List<&2,T.Resource>> & V.VkResult(Unit) <- collect_all(device,rest)
        return collected(result,pair)

def collected_resident(active:List<&2,Binding>,pair:List<&2,List<&2,T.Resource>> & V.VkResult(Unit)) -> Resident & V.VkResult(Unit):
  (retired,result) = pair
  (Resident{active,retired},result)

def collect(device:V.Device,resident:Resident) -> IO(Resident & V.VkResult(Unit)):
  Resident{active,retired} = resident
  do IO<Resident & V.VkResult(Unit)>:
    pair:List<&2,List<&2,T.Resource>> & V.VkResult(Unit) <- collect_all(device,retired)
    return collected_resident(active,pair)

def disposed(pair:List<&2,List<&2,T.Resource>> & V.VkResult(Unit)) -> V.VkResult(Unit):
  match pair:
    case ([],result):result
    case (_,Fail{error}):Fail{error}
    case (_,Done{_}):Fail{(1610612740,"Material cleanup deferred by retained commands")}

def dispose(device:V.Device,resident:Resident) -> V.Action(Unit):
  Resident{active,retired} = resident
  do IO<V.VkResult(Unit)>:
    pair:List<&2,List<&2,T.Resource>> & V.VkResult(Unit) <- collect_all(device,List.append(&2,List<&2,T.Resource>,ownership(active),retired))
    return disposed(pair)
