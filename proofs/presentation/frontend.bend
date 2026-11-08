import Base
import ../native-failures/extract.bend as Extract
import ../../tools/verify-native-failures.bend as Native
import ../../tools/upload-boundary/scan.bend as S
import ../../tools/window-verification/check.bend as Output

def ordered(wanted:List<&2,String>,lines:List<&2,String>) -> Bool:
  match wanted lines:
    case Nil{} _:True{}
    case Con{_,_} Nil{}:False{}
    case Con{+head,+rest} Con{+line,+tail}:
      Bool.pick(Bool,String.eq(head,line),ordered(rest,tail),ordered(head <> rest,tail))

def unique(items:List<&2,String>,+lines:List<&2,String>) -> Bool:
  match items:
    case []:True{}
    case item <> rest:Nat.is_eq(Extract.exact_line(lines,item),1n) && unique(rest,lines)

def valid(+source:String,+markers:List<&2,String>) -> Bool:
  ordered(markers,String.split(source,'\n')) && unique(markers,String.split(source,'\n'))

def controls(items:List<&2,String>,+source:String,+markers:List<&2,String>,+dest:String,+label:String,+n:U32) -> IO(Unit):
  match items:
    case []:IO.pure(Unit,Unit{})
    case item <> rest:
      do IO<Unit>:
        +changed:String <- Native.replaced(Native.replace(String.split(source,'\n'),item,"    # Removed production operation for sensitivity control"))
        Output.write(dest ++ "/frontend-" ++ label ++ "-" ++ U32.show(n) ++ ".bend",changed)
        S.require(Bool.not(valid(changed,markers)),"Presentation frontend control missed: " ++ label)
        Output.write(dest ++ "/frontend-" ++ label ++ "-" ++ U32.show(n) ++ ".status","0\n")
        controls(rest,source,markers,dest,label,U32.inc(n))

def check(+source:String,+markers:List<&2,String>,+dest:String,+label:String,negative:Bool) -> IO(Unit):
  do IO<Unit>:
    Output.write(dest ++ "/frontend-" ++ label ++ ".bend",source)
    S.require(valid(source,markers),"Presentation frontend call ordering changed: " ++ label)
    Bool.pick(IO(Unit),negative,controls(markers,source,markers,dest,label,0),IO.pure(Unit,Unit{}))
    S.require(valid(source,markers),"Restored presentation frontend failed: " ++ label)
    Output.write(dest ++ "/frontend-" ++ label ++ ".status","0\n")

def run(+dest:String,+negative:Bool) -> IO(Unit):
  do IO<Unit>:
    +window:String <- S.read("src/scene-window.bend")
    +target:String <- S.read("src/scene-target.bend")
    record:String <- Extract.section(window,"def record(","def acquired(")
    check(record,["    V.CommandBuffer.use_acquisition(command,lease)","    V.Device.submit_synced(device,command,render,[],[finished])","    status:U32 <- V.Fence.wait(render,Core.whole_size())","    Error.require(U32.is_zero(status),\"Window render fence did not complete\")","    V.Fence.reset(render)","    V.CommandBuffer.reset(command)"],dest,"render",negative)
    acquired:String <- Extract.section(window,"def acquired(","def draw(")
    check(acquired,["        Indexed.wait(acquire)","        probe:Diag.Probe <- record(renderer,target,frame,lease,camera,resident,items,probe)","        +outcome : V.PresentOutcome <- V.Device.present(device,lease,finished,present)","        Indexed.wait(present)","        rebuild:Bool <- Indexed.presented(outcome,suboptimal)"],dest,"present",negative)
    wait:String <- Extract.section(target,"def wait(","def frame_at(")
    check(wait,["    status : U32 <- V.Fence.wait(fence,Core.whole_size())","    Error.require(U32.is_zero(status),\"Window fence did not complete\")","    V.Fence.reset(fence)"],dest,"wait",negative)
    close:String <- Extract.section(window,"def close(","def target_extent(")
    check(close,["    V.CommandBuffer.reset(command)","    Indexed.destroy(target,device)"],dest,"close",negative)
    replace:String <- Extract.section(target,"def replace(","def ensure(")
    check(replace,["        destroy(Some{value},device)","        target(context,width,height)"],dest,"replace",negative)
