import Base
import ./measurement-counters.bend as Count
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W

type Metric<a,-A:Kind(a)> is Kind(a):
  Available{value:A}
  Unavailable{reason:String}
type Span is Data:Span{name:String,ns:Metric<&2,W.U64>}
type FrameOutcome is Data:
  Skipped{reason:String}
  Submitted{}
  Completed{present:V.PresentOutcome,suboptimal:Bool}
type Gpu is Data:
  Gpu{generation:U32,raw:Metric<&2,List<&2,V.Timestamp>>,bound:Metric<&2,W.U64>,duration:Metric<&2,F32>}
type Probe is Data:
  Off{}
  On{owner:Metric<&2,V.QueryPool>,properties:Metric<&2,V.TimestampProperties>,active:Metric<&2,V.QueryPool>,generation:U32,startup:Count.Counters,counters:Count.Counters,spans:List<&2,Span>,outcome:FrameOutcome,gpu:Gpu}


def absent_gpu(generation:U32,+reason:String) -> Gpu:
  Gpu{generation,Unavailable{reason},Unavailable{reason},Unavailable{reason}}

def metric(a,-A:Kind(a),result:V.VkResult(A)) -> Metric<a,A>:
  match result:
    case Done{value}:Available{value}
    case Fail{(code,message)}:Unavailable{U32.show(code) ++ " " ++ message}

def enabled(probe:Probe) -> Bool:
  match probe:
    case Off{}:False{}
    case _:True{}

def now(on:Bool) -> IO(Metric<&2,W.U64>):
  match on:
    case False{}:IO.pure(Metric<&2,W.U64>,Unavailable{"diagnostics off"})
    case True{}:
      do IO<Metric<&2,W.U64>>:
        result:V.VkResult(W.U64) <- V.monotonic_ns()
        return metric(&2,W.U64,result)

def elapsed(start:Metric<&2,W.U64>,end:Metric<&2,W.U64>) -> Metric<&2,W.U64>:
  match start end:
    case Available{a} Available{b}:Available{W.add(b,W.neg(a))}
    case Unavailable{reason} _:Unavailable{reason}
    case _ Unavailable{reason}:Unavailable{reason}

def span(probe:Probe,name:String,start:Metric<&2,W.U64>) -> IO(Probe):
  match probe:
    case Off{}:IO.pure(Probe,Off{})
    case On{owner,props,active,generation,startup,counters,spans,outcome,gpu}:
      do IO<Probe>:
        end:Metric<&2,W.U64> <- now(True{})
        return On{owner,props,active,generation,startup,counters,Span{name,elapsed(start,end)} <> spans,outcome,gpu}

def create(+device:V.Device) -> IO(Probe):
  do IO<Probe>:
    props:V.VkResult(V.TimestampProperties) <- V.Device.timestamp_properties(device)
    pool:V.VkResult(V.QueryPool) <- V.Device.create_timestamp_pool(device,2)
    return On{metric(&2,V.QueryPool,pool),metric(&2,V.TimestampProperties,props),Unavailable{"not armed"},0,Count.zero(),Count.zero(),[],Skipped{"not attempted"},absent_gpu(0,"not attempted")}

def begin(probe:Probe) -> Probe:
  match probe:
    case Off{}:Off{}
    case On{owner,props,active,+generation,startup,counters,spans,outcome,gpu}:
      On{owner,props,Unavailable{"not armed"},U32.inc(generation),startup,Count.zero(),[],Skipped{"no target or hidden"},absent_gpu(U32.inc(generation),"not submitted")}

def outcome(probe:Probe,value:FrameOutcome) -> Probe:
  match probe:
    case Off{}:Off{}
    case On{owner,props,active,generation,startup,counters,spans,old,gpu}:On{owner,props,active,generation,startup,counters,spans,value,gpu}

def upload(probe:Probe,bytes:U32) -> Probe:
  match probe:
    case Off{}:Off{}
    case On{owner,props,active,generation,Count.Counters{w,b,p,pb,d,s},counters,spans,outcome,gpu}:
      On{owner,props,active,generation,Count.Counters{U32.inc(w),W.add(b,W.of_u32(bytes)),p,pb,d,s},counters,spans,outcome,gpu}



def counts(probe:Probe,value:Count.Counters) -> Probe:
  match probe:
    case Off{}:Off{}
    case On{owner,props,active,generation,startup,counters,spans,outcome,gpu}:On{owner,props,active,generation,startup,value,spans,outcome,gpu}

def submit(probe:Probe) -> Probe:
  match probe:
    case Off{}:Off{}
    case On{owner,props,active,generation,startup,Count.Counters{w,b,p,pb,d,s},spans,outcome,gpu}:On{owner,props,active,generation,startup,Count.Counters{w,b,p,pb,d,U32.inc(s)},spans,Submitted{},gpu}

def armed(probe:Probe,active:Metric<&2,V.QueryPool>) -> Probe:
  match probe:
    case Off{}:Off{}
    case On{owner,props,old,generation,startup,counters,spans,outcome,gpu}:On{owner,props,active,generation,startup,counters,spans,outcome,gpu}

def accepted_pool(pool:V.QueryPool,result:V.VkResult(Unit)) -> Metric<&2,V.QueryPool>:
  match result:
    case Done{_}:Available{pool}
    case Fail{(code,message)}:Unavailable{U32.show(code) ++ " " ++ message}

def write(command:V.CommandBuffer,+pool:V.QueryPool,result:V.VkResult(Unit)) -> IO(Metric<&2,V.QueryPool>):
  match result:
    case Fail{(code,message)}:IO.pure(Metric<&2,V.QueryPool>,Unavailable{U32.show(code) ++ " " ++ message})
    case Done{_}:
      do IO<Metric<&2,V.QueryPool>>:
        result:V.VkResult(Unit) <- V.CommandBuffer.write_timestamp(command,pool,0,vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT())
        return accepted_pool(pool,result)

def top(+probe:Probe,+command:V.CommandBuffer) -> IO(Probe):
  match probe:
    case Off{}:IO.pure(Probe,Off{})
    case On{+owner,props,active,generation,startup,counters,spans,outcome,gpu}:
      match owner:
        case Unavailable{reason}:IO.pure(Probe,armed(probe,Unavailable{reason}))
        case Available{+pool}:
          do IO<Probe>:
            result:V.VkResult(Unit) <- V.CommandBuffer.reset_timestamp_queries(command,pool,0,2)
            active:Metric<&2,V.QueryPool> <- write(command,pool,result)
            return armed(probe,active)

def bottom(+probe:Probe,command:V.CommandBuffer) -> IO(Probe):
  match probe:
    case Off{}:IO.pure(Probe,Off{})
    case On{owner,props,active,generation,startup,counters,spans,outcome,gpu}:
      match active:
        case Unavailable{reason}:IO.pure(Probe,probe)
        case Available{+pool}:
          do IO<Probe>:
            result:V.VkResult(Unit) <- V.CommandBuffer.write_timestamp(command,pool,1,vk.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT())
            return armed(probe,accepted_pool(pool,result))

def timestamps(values:List<V.Timestamp>) -> List<&2,V.Timestamp>:
  match values:
    case []:[]
    case x <> xs:x <> timestamps(xs)

def duration(device:V.Device,raw:Metric<&2,List<&2,V.Timestamp>>,bound:Metric<&2,W.U64>) -> IO(Metric<&2,F32>):
  match raw bound:
    case Available{V.Timestamp{start,True{}} <> V.Timestamp{end,True{}} <> []} Available{cpu}:
      do IO<Metric<&2,F32>>:
        result:V.VkResult(F32) <- V.Device.timestamp_duration(device,start,end,cpu)
        return metric(&2,F32,result)
    case Unavailable{reason} _:IO.pure(Metric<&2,F32>,Unavailable{reason})
    case _ Unavailable{reason}:IO.pure(Metric<&2,F32>,Unavailable{reason})
    case _ _:IO.pure(Metric<&2,F32>,Unavailable{"timestamp results unavailable"})

def results(result:V.VkResult(List<V.Timestamp>)) -> Metric<&2,List<&2,V.Timestamp>>:
  match result:
    case Done{values}:Available{timestamps(values)}
    case Fail{(code,message)}:Unavailable{U32.show(code) ++ " " ++ message}

def read_active(active:Metric<&2,V.QueryPool>,device:V.Device) -> IO(Metric<&2,List<&2,V.Timestamp>>):
  match active:
    case Unavailable{reason}:IO.pure(Metric<&2,List<&2,V.Timestamp>>,Unavailable{reason})
    case Available{pool}:
      do IO<Metric<&2,List<&2,V.Timestamp>>>:
        result:V.VkResult(List<V.Timestamp>) <- V.Device.timestamp_results(device,pool,0,2)
        return results(result)

def read(probe:Probe,+device:V.Device,+bound:Metric<&2,W.U64>) -> IO(Probe):
  match probe:
    case Off{}:IO.pure(Probe,Off{})
    case On{owner,props,+active,+generation,startup,counters,spans,outcome,gpu}:
      do IO<Probe>:
        +raw:Metric<&2,List<&2,V.Timestamp>> <- read_active(active,device)
        value:Metric<&2,F32> <- duration(device,raw,bound)
        return On{owner,props,Unavailable{"observed before command reset"},generation,startup,counters,spans,outcome,Gpu{generation,raw,bound,value}}

def close(probe:Probe,device:V.Device) -> V.Action(Unit):
  match probe:
    case Off{}:V.Action.pure(Unit,Unit{})
    case On{Available{pool},props,active,generation,startup,counters,spans,outcome,gpu}:V.Device.destroy_query_pool(device,pool)
    case _:V.Action.pure(Unit,Unit{})
