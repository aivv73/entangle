import Base
import ./upload-boundary/scan.bend as S
import ../proofs/native-failures/extract.bend as Extract
import ../proofs/native-failures/tool.bend as Tool
import ../deps/bend-vulkan/tools/verification.bend as Output

def targets() -> List<&2,String>:
  ["verify_device_loss","verify_record_reset_failure","verify_submit_result","verify_synced_submission","verify_uncertain_guards","verify_lost_guards","verify_descriptor_failure","verify_fence_reset_failure","verify_idle_failure","verify_completion","verify_idle_success"]

def record(result:U32 & (String & String),+dest:String,+label:String,+failure:String) -> IO(Unit):
  (+status,pair) = result
  (out,err) = pair
  +log:String = out ++ err
  +negative:Bool = Bool.not(String.eq(failure,""))
  do IO<Unit>:
    Output.write(dest ++ "/" ++ label ++ ".log",log)
    Output.write(dest ++ "/" ++ label ++ ".status",U32.show(status) ++ "\n")
    S.require(Bool.pick(Bool,negative,U32.is_eq(status,10) && String.contains(log,failure ++ ": FAILURE"),U32.is_zero(status) && String.contains(log,"VERIFICATION SUCCESSFUL")),"Unexpected native proof verdict: " ++ label ++ "; see " ++ dest)
    IO.print(label ++ Bool.pick(String,negative," rejected (expected counterexample)"," proved"))

def check(+binary:String,+source:String,+dest:String,+label:String,target:String,failure:String) -> IO(Unit):
  do IO<Unit>:
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(binary,[source,"--function",target,"--unwind","6","--unwindset","proof_idle.0:2,bv_complete.0:4,bv_complete.1:1","--unwinding-assertions","--bounds-check","--pointer-check","--pointer-overflow-check","--signed-overflow-check","--object-bits","10","--drop-unused-functions","--symex-cache-dereferences","--no-array-field-sensitivity","--slice-formula","--trace"],"",16777216,300000))
    record(result,dest,label,failure)

def prove(items:List<&2,String>,+binary:String,+source:String,+dest:String,+prefix:String) -> IO(Unit):
  match items:
    case []:IO.pure(Unit,Unit{})
    case +target <> rest:
      do IO<Unit>:
        check(binary,source,dest,prefix ++ target,target,"")
        prove(rest,binary,source,dest,prefix)

def replace_line(value:Nat & String,+line:String,before:String,after:String) -> Nat & String:
  (count,tail) = value
  +found:Bool = String.eq(line,before)
  (Nat.add(count,Bool.pick(Nat,found,1n,0n)),Bool.pick(String,found,after,line) ++ "\n" ++ tail)

def replace(lines:List<&2,String>,+before:String,+after:String) -> Nat & String:
  match lines:
    case []:(0n,"")
    case +line <> rest:
      replace_line(replace(rest,before,after),line,before,after)

def replaced(value:Nat & String) -> IO(String):
  (count,text) = value
  do IO<String>:
    S.require(Nat.is_eq(count,1n),"Mutation must match exactly one production source line")
    return text

def mutation(parts:List<&2,String>,+native:String,+binary:String,+dest:String) -> IO(Unit):
  match parts:
    case [+label,target,before,after,failure]:
      do IO<Unit>:
        changed:String <- replaced(replace(String.split(native,'\n'),before,after))
        Output.write(dest ++ "/" ++ label ++ ".native.c",changed)
        Extract.extract(dest ++ "/" ++ label ++ ".native.c",dest ++ "/" ++ label ++ ".c")
        check(binary,dest ++ "/" ++ label ++ ".c",dest,label,target,failure)
    case _:IO.die(Unit,1,"Malformed native source mutation")

def mutations(lines:List<&2,String>,+native:String,+binary:String,+dest:String) -> IO(Unit):
  match lines:
    case []:IO.pure(Unit,Unit{})
    case line <> rest:
      do IO<Unit>:
        mutation(String.split(line,'\t'),native,binary,dest)
        mutations(rest,native,binary,dest)

def run(negative:Bool) -> IO(Unit):
  do IO<Unit>:
    +binary:String <- Tool.ensure()
    _:String <- S.run("mkdir",["-p","build/verification"])
    directory:String <- S.run("mktemp",["-d","build/verification/native-formal-XXXXXXXX"])
    +dest:String = String.trim(directory)
    IO.print("Native formal evidence: " ++ dest)
    Extract.extract("deps/bend-vulkan/src/native.c",dest ++ "/handlers.c")
    hashes:String <- S.run("sha256sum",["deps/bend-vulkan/src/native.c","proofs/native-failures/extract.bend","proofs/native-failures/handlers.in.c","proofs/native-failures/prelude.h","proofs/native-failures/claims.h","proofs/native-failures/mutations.tsv","tools/verify-native-failures.bend",binary])
    Output.write(dest ++ "/sources.sha256",hashes)
    prove(targets(),binary,dest ++ "/handlers.c",dest,"")
    Bool.pick(IO(Unit),negative,
      do IO<Unit>:
        native:String <- S.read("deps/bend-vulkan/src/native.c")
        cases:String <- S.read("proofs/native-failures/mutations.tsv")
        mutations(String.lines(String.trim(cases)),native,binary,dest)
        Extract.extract("deps/bend-vulkan/src/native.c",dest ++ "/restored.c")
        prove(targets(),binary,dest ++ "/restored.c",dest,"restored-"),
      IO.pure(Unit,Unit{}))
    IO.print("Production native failure properties verified within the documented bounds.")

def args(values:List<String>) -> IO(Unit):
  match values:
    case [_]:run(False{})
    case [_,"--mutations"]:run(True{})
    case _:IO.die(Unit,1,"usage: verify-native-failures [--mutations]")

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<String> <- IO.args()
    args(values)
