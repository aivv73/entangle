import Base
import ../upload-boundary/scan.bend as S
import ../verify-upload-mutations.bend as Files
import ../image-decoder/common.bend as C

def selected(lines:List<&2,String>,+prefix:String) -> String:
  match lines:
    case []:""
    case +line <> rest:Bool.pick(String,String.starts_with(line,prefix),line ++ "\n","") ++ selected(rest,prefix)

def measured(+dest:String,+label:String,+count:U32,+mode:U32,+repeat:U32) -> IO(String):
  +program = Bool.pick(String,String.eq(label,"baseline"),"build/verification/hierarchy-baseline-source/build/hierarchy-benchmark-baseline","build/hierarchy-benchmark-candidate")
  do IO<String>:
    +out:String <- C.command(program,[U32.show(count),U32.show(mode),"6","+RTS","--threads","1","--gpu","off"])
    Files.save(dest ++ "/" ++ label ++ "-" ++ U32.show(count) ++ "-" ++ U32.show(mode) ++ "-" ++ U32.show(repeat) ++ ".log",out)
    IO.write(label ++ " repeat=" ++ U32.show(repeat) ++ " " ++ selected(String.lines(out),"publication"))
    IO.write(label ++ " repeat=" ++ U32.show(repeat) ++ " " ++ selected(String.lines(out),"offscreen-frame"))
    return selected(String.lines(out),"verified-")

def repeats(left:Nat,+repeat:U32,+dest:String,+count:U32,+mode:U32) -> IO(Unit):
  match left:
    case 0n:IO.pure(Unit,Unit{})
    case 1n+n:
      +even = U32.is_zero(U32.mod(repeat,2))
      do IO<Unit>:
        +first:String <- measured(dest,Bool.pick(String,even,"baseline","candidate"),count,mode,repeat)
        +second:String <- measured(dest,Bool.pick(String,even,"candidate","baseline"),count,mode,repeat)
        S.require(String.eq(first,second),"Benchmark complete ECS state or RGBA/D32 bytes changed")
        IO.print("exact state/RGBA/D32 comparison passed")
        repeats(n,U32.inc(repeat),dest,count,mode)

def main() -> IO(Unit):
  do IO<Unit>:
    path:String <- S.run("mktemp",["-d","build/verification/hierarchy-measure-XXXXXXXX"])
    +dest:String = String.trim(path)
    IO.print("Performance evidence: " ++ dest)
    metadata:String <- S.run("sha256sum",["build/verification/hierarchy-baseline-source/build/hierarchy-benchmark-baseline","build/hierarchy-benchmark-candidate","tools/hierarchy/benchmark.bend","tools/hierarchy/measure.bend","src/scene-hierarchy.bend","build/verification/hierarchy-baseline-source/src/scene-hierarchy.bend"])
    Files.save(dest ++ "/sources.sha256",metadata)
    machine:String <- S.run("sh",["-c","uname -a; lscpu; uptime; ps -eo pcpu,comm --sort=-pcpu | head -12"])
    Files.save(dest ++ "/machine.txt",machine)
    repeats(5n,0,dest,1000,0)
    repeats(5n,0,dest,256,1)
    repeats(5n,0,dest,1023,2)
    IO.print("Five alternating pairs per workload passed exact state and image comparison")
