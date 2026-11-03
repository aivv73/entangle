import Base
import ./measurement-counters.bend as Count
import ./scene-diagnostics.bend as D
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W

def escape(chars:List<&2,Char>) -> String:
  match chars:
    case []:""
    case '"' <> rest:"\\\"" ++ escape(rest)
    case '\\' <> rest:"\\\\" ++ escape(rest)
    case '\n' <> rest:"\\n" ++ escape(rest)
    case '\r' <> rest:"\\r" ++ escape(rest)
    case '\t' <> rest:"\\t" ++ escape(rest)
    case c <> rest:String.from_list([c]) ++ escape(rest)

def quote(s:String) -> String:
  "\"" ++ escape(String.to_list(s)) ++ "\""

def wide(value:W.U64) -> String:
  W.U64{lo,hi} = value
  "{\"lo\":" ++ U32.show(lo) ++ ",\"hi\":" ++ U32.show(hi) ++ "}"

def ns(value:D.Metric<&2,W.U64>) -> String:
  match value:
    case D.Available{v}:"{\"value\":" ++ wide(v) ++ "}"
    case D.Unavailable{reason}:"{\"value\":null,\"reason\":" ++ quote(reason) ++ "}"

def float(value:D.Metric<&2,F32>) -> String:
  match value:
    case D.Available{+v}:"{\"ns_f32\":" ++ F32.show(v) ++ ",\"bits\":" ++ U32.show(F32.bits(v)) ++ "}"
    case D.Unavailable{reason}:"{\"ns_f32\":null,\"reason\":" ++ quote(reason) ++ "}"

def tail_spans(values:List<&2,D.Span>,next:Unit -> String) -> String:
  match values:
    case []:""
    case _: "," ++ next(Unit{})

def spans(values:List<&2,D.Span>) -> String:
  match values:
    case []:""
    case D.Span{name,value} <> +rest:quote(name) ++ ":" ++ ns(value) ++ tail_spans(rest,_ => spans(rest))

def counters(value:Count.Counters) -> String:
  Count.Counters{writes,bytes,pushes,payload,draws,submits} = value
  "{\"host_mesh_write_calls\":" ++ U32.show(writes) ++ ",\"host_mesh_write_bytes\":" ++ wide(bytes) ++ ",\"push_calls\":" ++ U32.show(pushes) ++ ",\"push_payload_bytes\":" ++ wide(payload) ++ ",\"draw_indexed_calls\":" ++ U32.show(draws) ++ ",\"submit_calls\":" ++ U32.show(submits) ++ "}"

def present(value:V.PresentOutcome) -> String:
  match value:
    case V.Presented{}:"presented"
    case V.PresentSuboptimal{}:"suboptimal"
    case V.PresentOutOfDate{}:"out_of_date"
    case V.PresentSurfaceLost{}:"surface_lost"

def boolean(value:Bool) -> String:
  Bool.pick(String,value,"true","false")

def outcome(value:D.FrameOutcome) -> String:
  match value:
    case D.Skipped{reason}:"{\"kind\":\"skipped\",\"reason\":" ++ quote(reason) ++ "}"
    case D.Submitted{}:"{\"kind\":\"submitted\"}"
    case D.Completed{status,suboptimal}:"{\"kind\":\"completed\",\"present\":" ++ quote(present(status)) ++ ",\"acquire_suboptimal\":" ++ boolean(suboptimal) ++ "}"

def tail_timestamps(values:List<&2,V.Timestamp>,next:Unit -> String) -> String:
  match values:
    case []:""
    case _: "," ++ next(Unit{})

def timestamps(values:List<&2,V.Timestamp>) -> String:
  match values:
    case []:""
    case V.Timestamp{value,available} <> +rest:"{\"value\":" ++ wide(value) ++ ",\"available\":" ++ boolean(available) ++ "}" ++ tail_timestamps(rest,_ => timestamps(rest))

def raw(value:D.Metric<&2,List<&2,V.Timestamp>>) -> String:
  match value:
    case D.Available{values}:"{\"value\":[" ++ timestamps(values) ++ "]}"
    case D.Unavailable{reason}:"{\"value\":null,\"reason\":" ++ quote(reason) ++ "}"

def properties(value:D.Metric<&2,V.TimestampProperties>) -> String:
  match value:
    case D.Available{V.TimestampProperties{bits,+period}}:"{\"valid_bits\":" ++ U32.show(bits) ++ ",\"period_ns_f32\":" ++ F32.show(period) ++ ",\"period_bits\":" ++ U32.show(F32.bits(period)) ++ "}"
    case D.Unavailable{reason}:"{\"value\":null,\"reason\":" ++ quote(reason) ++ "}"

def probe(value:D.Probe) -> String:
  match value:
    case D.Off{}:"\"diagnostics\":null"
    case D.On{owner,props,active,+generation,startup,c,phases,result,D.Gpu{gpu_generation,timestamps,bound,duration}}:
      "\"generation\":" ++ U32.show(generation) ++ ",\"gpu_generation\":" ++ U32.show(gpu_generation) ++ ",\"outcome\":" ++ outcome(result) ++ ",\"startup_counters\":" ++ counters(startup) ++ ",\"counters\":" ++ counters(c) ++ ",\"renderer_cpu_ns\":{" ++ spans(phases) ++ "},\"gpu\":{\"properties\":" ++ properties(props) ++ ",\"timestamps\":" ++ raw(timestamps) ++ ",\"cpu_bound_ns\":" ++ ns(bound) ++ ",\"duration\":" ++ float(duration) ++ "}"

def nat(value:W.U64) -> Nat:
  W.U64{lo,hi} = value
  Nat.add(U32.to_nat(lo),Nat.mul(U32.to_nat(hi),Nat.add(U32.to_nat(4294967295),1n)))

def lookup_found(found:Bool,value:D.Metric<&2,W.U64>,next:Unit -> D.Metric<&2,W.U64>) -> D.Metric<&2,W.U64>:
  match found:
    case True{}:value
    case False{}:next(Unit{})

def lookup(+name:String,values:List<&2,D.Span>) -> D.Metric<&2,W.U64>:
  match values:
    case []:D.Unavailable{"not executed"}
    case D.Span{key,value} <> rest:lookup_found(String.eq(name,key),value,_ => lookup(name,rest))

def insert_order(before:Bool,value:Nat,+x:Nat,rest:List<&2,Nat>,next:Unit -> List<&2,Nat>) -> List<&2,Nat>:
  match before:
    case True{}:value <> x <> rest
    case False{}:x <> next(Unit{})

def insert(+value:Nat,values:List<&2,Nat>) -> List<&2,Nat>:
  match values:
    case []:[value]
    case +x <> +rest:insert_order(Nat.is_le(value,x),value,x,rest,_ => insert(value,rest))

def nth(values:List<&2,Nat>,index:Nat) -> Nat:
  match values index:
    case [] _:0n
    case x <> rest 0n:x
    case x <> rest 1n+p:nth(rest,p)

def half(+value:Nat) -> String:
  Nat.show(Nat.div(value,2n)) ++ Bool.pick(String,Nat.is_eq(Nat.mod(value,2n),0n),"",".5")

def summary_count(+count:Nat,+values:List<&2,Nat>,missing:Nat) -> String:
  match count:
    case 0n:"{\"count\":0,\"unavailable\":" ++ Nat.show(missing) ++ ",\"median_ns\":null}"
    case _:
      +lo = nth(values,Nat.div(Nat.sub(count,1n),2n))
      +hi = nth(values,Nat.div(count,2n))
      "{\"count\":" ++ Nat.show(count) ++ ",\"unavailable\":" ++ Nat.show(missing) ++ ",\"median_ns\":" ++ half(Nat.add(lo,hi)) ++ ",\"p95_ns\":" ++ Nat.show(nth(values,Nat.sub(Nat.div(Nat.add(Nat.mul(count,95n),99n),100n),1n))) ++ ",\"min_ns\":" ++ Nat.show(nth(values,0n)) ++ ",\"max_ns\":" ++ Nat.show(nth(values,Nat.sub(count,1n))) ++ "}"

def summary(+values:List<&2,Nat>,+missing:Nat) -> String:
  +count = List.length(&2,Nat,values)
  summary_count(count,values,missing)
