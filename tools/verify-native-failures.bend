import Base
import ./upload-boundary/scan.bend as S
import ../proofs/native-failures/extract.bend as Extract
import ../proofs/native-failures/tool.bend as Tool
import ./window-verification/check.bend as Output

def targets() -> List<&2,String>:
  ["verify_device_loss","verify_record_reset_failure","verify_submit_result","verify_synced_submission","verify_uncertain_guards","verify_lost_guards","verify_descriptor_failure","verify_fence_reset_failure","verify_idle_failure","verify_completion","verify_idle_success"]

type Suite is Data:
  Suite{label:String,template:String,claims:String,targets:List<&2,String>,controls:String}

def suites(lifetime_only:Bool) -> List<&2,Suite>:
  List.append(&2,Suite,Bool.pick(List<&2,Suite>,lifetime_only,[],
    [Suite{"handlers","proofs/native-failures/handlers.in.c","proofs/native-failures/claims.h",targets(),"proofs/native-failures/mutations.tsv"}]),
    [Suite{"lifetime","proofs/native-failures/lifetime.in.c","proofs/native-failures/lifetime-claims.h",
      ["verify_lifetime_retirement","verify_lifetime_graph","verify_lifetime_prepare","verify_lifetime_collection_00","verify_lifetime_collection_01","verify_lifetime_collection_10","verify_lifetime_collection_11","verify_lifetime_completion_reset_pending","verify_lifetime_completion_reset_uncertain"],"proofs/native-failures/lifetime-mutations.tsv"}])

def failed_unwind(lines:List<&2,String>) -> Bool:
  match lines:
    case []:False{}
    case +line <> rest:
      (String.contains(line,"unwinding assertion") && String.contains(line,": FAILURE")) || failed_unwind(rest)

def record(result:U32 & (String & String),+dest:String,+label:String,+failure:String) -> IO(Unit):
  (+status,pair) = result
  (out,err) = pair
  +log:String = out ++ err
  +negative:Bool = Bool.not(String.eq(failure,""))
  do IO<Unit>:
    Output.write(dest ++ "/" ++ label ++ ".log",log)
    Output.write(dest ++ "/" ++ label ++ ".status",U32.show(status) ++ "\n")
    S.require(Bool.not(failed_unwind(String.lines(log))),"Native proof exceeded an unwind bound: " ++ label ++ "; see " ++ dest)
    S.require(Bool.pick(Bool,negative,U32.is_eq(status,10) && String.contains(log,failure ++ ": FAILURE"),U32.is_zero(status) && String.contains(log,"VERIFICATION SUCCESSFUL")),"Unexpected native proof verdict: " ++ label ++ "; see " ++ dest)
    Bool.pick(IO(Unit),String.contains(label,"-case-"),IO.pure(Unit,Unit{}),IO.print(label ++ Bool.pick(String,negative," rejected (expected counterexample)"," proved")))

def arguments(values:List<&2,String>) -> String:
  match values:
    case []:""
    case head <> rest:head ++ "\n" ++ arguments(rest)

def owned_arguments(values:List<&2,String>) -> List<String>:
  match values:
    case []:[]
    case head <> rest:head <> owned_arguments(rest)

def compiled(result:U32 & (String & String),+source:String,+output:String,+dest:String,+label:String) -> IO(String):
  (+status,(out,err)) = result
  do IO<String>:
    Output.write(dest ++ "/" ++ label ++ "-compile.log",out ++ err)
    Output.write(dest ++ "/" ++ label ++ "-compile.status",U32.show(status) ++ "\n")
    S.require(U32.is_zero(status),"Native GOTO compilation failed: " ++ label ++ "; see " ++ dest)
    hashes:String <- S.run("sha256sum",[source,output])
    Output.write(dest ++ "/" ++ label ++ "-compile.sha256",hashes)
    return output

def compile(+source:String,+dest:String,+label:String) -> IO(String):
  do IO<String>:
    +binary:String = Tool.compiler()
    +output:String = source ++ ".goto"
    +args:List<&2,String> = [source,"-o",output]
    Output.write(dest ++ "/" ++ label ++ "-compile.argv",binary ++ "\n" ++ arguments(args))
    Output.write(dest ++ "/" ++ label ++ "-compile.status","1\n")
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(binary,owned_arguments(args),"",16777216,300000))
    compiled(result,source,output,dest,label)

def lifetime_bounds() -> String:
  "bv_get.0:9,bv_remove.0:9,bv_remove.1:4," ++
  "bv_dependency.0:3,bv_may_reach_depth.0:3,bv_sealed.0:3," ++
  "bv_complete.0:4,bv_complete.1:1,bv_complete.2:9,bv_device_result.0:9," ++
  "bv_memory_busy.0:9,bv_referenced.0:4,bv_referenced.1:9," ++
  "bv_prepare_refs.0:3,bv_prepare_refs.1:9,bv_prepare_refs.2:2,bv_prepare_refs.3:3,bv_prepare_refs.4:3,bv_prepare_refs.5:3," ++
  "bv_validate_retirement.0:9,bv_validate_retirement.1:4,bv_validate_retirement.2:9," ++
  "proof_retire.0:3,proof_retire.1:3,proof_collect.0:9,clear_registry.0:9," ++
  "verify_lifetime_prepare.0:4,verify_lifetime_prepare.1:3"

def collection_bounds() -> String:
  "bv_get.0:8,bv_remove.0:5,bv_remove.1:2,bv_dependency.0:2," ++
  "bv_referenced.0:3,bv_referenced.1:8,proof_collect.0:8,proof_destroy_boundary.0:3,proof_free_boundary.0:3"

def completion_bounds() -> String:
  "bv_get.0:8,bv_remove.0:8,bv_remove.1:3,bv_dependency.0:2,bv_may_reach_depth.0:3," ++
  "bv_complete.0:3,bv_complete.1:1,bv_complete.2:8,bv_device_result.0:8," ++
  "bv_referenced.0:3,bv_referenced.1:8,bv_validate_retirement.0:8,bv_validate_retirement.1:3,bv_validate_retirement.2:8," ++
  "proof_retire.0:3,proof_retire.1:3,proof_collect.0:8,clear_registry.0:8,proof_destroy_boundary.0:3,proof_free_boundary.0:3"

def presentation_bounds() -> String:
  "bv_dependency.0:3,bv_may_reach_depth.0:3,bv_sealed.0:3," ++
  "bv_get.0:6,bv_active.0:6,bv_uncertain.0:5,bv_uncertain.1:6,bv_image_lease.0:5," ++
  "bv_device_result.0:6,bv_referenced.0:3,bv_referenced.1:6," ++
  "bv_prepare_refs.0:2,bv_prepare_refs.1:6,bv_prepare_refs.2:3,bv_prepare_refs.3:3,bv_prepare_refs.4:3,bv_prepare_refs.5:3," ++
  "bv_complete.0:4,bv_complete.1:1,bv_complete.2:6," ++
  "proof_submit.0:3,proof_submit.1:6,proof_idle.0:2,proof_drain.0:5,proof_drain.1:6," ++
  "proof_acquire.0:5,proof_acquire.1:5,proof_lookup.0:5,proof_swapchain_destroy.0:5,proof_swapchain_destroy.2:6"

def valid_configuration(value:Maybe<&2,U32>,+text:String) -> IO(Unit):
  match value:
    case Some{+n}:S.require(U32.is_lt(n,64) && String.eq(U32.show(n),text),"Collection configuration must be a canonical number from 0 through 63")
    case None{}:IO.die(Unit,1,"Invalid collection configuration")

def check(+binary:String,+source:String,+dest:String,+label:String,+target:String,failure:String,+configuration:String) -> IO(Unit):
  do IO<Unit>:
    +lifetime:Bool = String.starts_with(target,"verify_lifetime_")
    +presentation:Bool = String.starts_with(target,"verify_presentation_")
    +collection:Bool = String.contains(target,"_collection_")
    S.require(Bool.pick(Bool,collection,Bool.not(String.is_empty(configuration)),String.is_empty(configuration)),"Collection checks require an explicit configuration; other entries do not accept one")
    Bool.pick(IO(Unit),collection,valid_configuration(U32.read(configuration),configuration),IO.pure(Unit,Unit{}))
    function:String = target ++ Bool.pick(String,collection,"_case_" ++ configuration,"")
    +bounds:String = Bool.pick(String,collection,collection_bounds(),Bool.pick(String,String.contains(target,"_completion_reset_"),completion_bounds(),lifetime_bounds()))
    +args:List<&2,String> = List.append(&2,String,[source,"--function",function,"--unwind",Bool.pick(String,presentation,"4","6"),"--unwindset",Bool.pick(String,presentation,presentation_bounds(),Bool.pick(String,lifetime,bounds,"proof_idle.0:2,bv_complete.0:4,bv_complete.1:1")),"--unwinding-assertions","--bounds-check","--pointer-check","--pointer-overflow-check","--signed-overflow-check","--object-bits","10","--drop-unused-functions","--symex-cache-dereferences","--slice-formula","--trace"],Bool.pick(List<&2,String>,lifetime || presentation,["--malloc-may-fail","--malloc-fail-null","--memory-leak-check"],["--no-array-field-sensitivity"]))
    Output.write(dest ++ "/" ++ label ++ ".argv",binary ++ "\n" ++ arguments(args))
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(binary,owned_arguments(args),"",16777216,300000))
    record(result,dest,label,failure)

def configurations(left:Nat,+n:U32,+binary:String,+source:String,+dest:String,+label:String,+target:String) -> IO(Unit):
  match left:
    case 0n:IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        check(binary,source,dest,label ++ "-case-" ++ U32.show(n),target,"",U32.show(n))
        configurations(rest,U32.inc(n),binary,source,dest,label,target)

def prove(items:List<&2,String>,+binary:String,+source:String,+dest:String,+prefix:String) -> IO(Unit):
  match items:
    case []:IO.pure(Unit,Unit{})
    case +target <> rest:
      do IO<Unit>:
        Bool.pick(IO(Unit),String.contains(target,"_collection_"),
          do IO<Unit>:
            configurations(64n,0,binary,source,dest,prefix ++ target,target)
            IO.print(prefix ++ target ++ " proved all 64 configurations"),
          check(binary,source,dest,prefix ++ target,target,"",""))
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

def configured_mutation(parts:List<&2,String>,+native:String,+binary:String,+dest:String,+template:String,+claims:String) -> IO(Unit):
  match parts:
    case [+label,target,before,after,failure,configuration]:
      do IO<Unit>:
        changed:String <- replaced(replace(String.split(native,'\n'),before,after))
        Output.write(dest ++ "/" ++ label ++ ".native.c",changed)
        Extract.harness(dest ++ "/" ++ label ++ ".native.c",template,claims,dest ++ "/" ++ label ++ ".c")
        code:String <- compile(dest ++ "/" ++ label ++ ".c",dest,label)
        check(binary,code,dest,label,target,failure,configuration)
    case _:IO.die(Unit,1,"Malformed native source mutation")

def mutation(+parts:List<&2,String>,native:String,binary:String,dest:String,template:String,claims:String) -> IO(Unit):
  match parts:
    case [label,target,before,after,failure]:configured_mutation([label,target,before,after,failure,""],native,binary,dest,template,claims)
    case _:configured_mutation(parts,native,binary,dest,template,claims)

def mutations(lines:List<&2,String>,+native:String,+binary:String,+dest:String,+template:String,+claims:String) -> IO(Unit):
  match lines:
    case []:IO.pure(Unit,Unit{})
    case line <> rest:
      do IO<Unit>:
        mutation(String.split(line,'\t'),native,binary,dest,template,claims)
        mutations(rest,native,binary,dest,template,claims)

def suite(value:Suite,+binary:String,+dest:String,negative:Bool) -> IO(Unit):
  Suite{+label,+template,+claims,+items,controls} = value
  do IO<Unit>:
    Extract.harness("deps/bend-vulkan/src/native.c",template,claims,dest ++ "/" ++ label ++ ".c")
    code:String <- compile(dest ++ "/" ++ label ++ ".c",dest,label)
    prove(items,binary,code,dest,"")
    Bool.pick(IO(Unit),negative,
      do IO<Unit>:
        native:String <- S.read("deps/bend-vulkan/src/native.c")
        cases:String <- S.read(controls)
        mutations(String.lines(String.trim(cases)),native,binary,dest,template,claims)
        Extract.harness("deps/bend-vulkan/src/native.c",template,claims,dest ++ "/restored-" ++ label ++ ".c")
        restored:String <- compile(dest ++ "/restored-" ++ label ++ ".c",dest,"restored-" ++ label)
        prove(items,binary,restored,dest,"restored-"),
      IO.pure(Unit,Unit{}))

def verify(values:List<&2,Suite>,+binary:String,+dest:String,+negative:Bool) -> IO(Unit):
  match values:
    case []:IO.pure(Unit,Unit{})
    case value <> rest:
      do IO<Unit>:
        suite(value,binary,dest,negative)
        verify(rest,binary,dest,negative)

def run(+negative:Bool,+lifetime_only:Bool) -> IO(Unit):
  do IO<Unit>:
    +binary:String <- Tool.ensure()
    +compiler:String <- Tool.ensure_compiler()
    _:String <- S.run("mkdir",["-p","build/verification"])
    directory:String <- S.run("mktemp",["-d","build/verification/native-formal-XXXXXXXX"])
    +dest:String = String.trim(directory)
    IO.print("Native formal evidence: " ++ dest)
    Output.write(dest ++ "/run.status","1\n")
    Output.write(dest ++ "/selection.txt",Bool.pick(String,lifetime_only,"lifetime","handlers lifetime") ++ "\nmutations=" ++ Bool.show(negative) ++ "\n")
    hashes:String <- S.run("sha256sum",["deps/bend-vulkan/src/native.c","proofs/native-failures/extract.bend","proofs/native-failures/tool.bend","proofs/native-failures/collection-cases.bend","proofs/native-failures/handlers.in.c","proofs/native-failures/prelude.h","proofs/native-failures/claims.h","proofs/native-failures/mutations.tsv","proofs/native-failures/lifetime.in.c","proofs/native-failures/lifetime-claims.h","proofs/native-failures/lifetime-mutations.tsv","tools/verify-native-failures.bend",binary,compiler])
    Output.write(dest ++ "/sources.sha256",hashes)
    version:String <- S.run(compiler,["--version"])
    Output.write(dest ++ "/goto-cc-version.txt",version)
    verify(suites(lifetime_only),binary,dest,negative)
    Output.write(dest ++ "/run.status","0\n")
    IO.print("Selected production native properties verified within the documented bounds.")

def args(values:List<String>) -> IO(Unit):
  match values:
    case [_]:run(False{},False{})
    case [_,"--mutations"]:run(True{},False{})
    case [_,"--lifetime"]:run(False{},True{})
    case [_,"--lifetime","--mutations"]:run(True{},True{})
    case _:IO.die(Unit,1,"usage: verify-native-failures [--lifetime] [--mutations]")

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<String> <- IO.args()
    args(values)
