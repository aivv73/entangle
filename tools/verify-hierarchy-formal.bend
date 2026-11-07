import Base
import ./upload-boundary/scan.bend as S
import ./verify-upload-mutations.bend as Files
import ./verify-native-failures.bend as Mutate
import ./verify-publication.bend as Extract

# Isolate the pure hierarchy closure from unsupported ECS templates. Declarations
# are selected verbatim from the maintained laws/proofs; production imports stay
# direct, and no evaluator or arithmetic operation is replaced.
def core(+dest:String) -> IO(Unit):
  do IO<Unit>:
    _:String <- S.run("mkdir",[dest ++ "/kernel"])
    spec_source:String <- S.read("proofs/hierarchy/spec.bend")
    spec:String <- Extract.regions(spec_source,["def length_result(","def reusable_length(","type Tree ","def thaw(","type Forest ","def final(","def value(","def spatial_global(","def global(","def parent(","def admitted(","type Rejection ","def error(","def rejected(","def sequence_values(","def sequence_valid("],"hierarchy spec")
    Files.save(dest ++ "/kernel/spec.bend","import Base\nimport ../src/hierarchy.bend as H\n\n" ++ spec)
    law_source:String <- S.read("proofs/hierarchy/LAWS.bend")
    laws:String <- Extract.regions(law_source,["law evaluate_length:","law forest_visit:","law rejection_visit:","law sequence_order:"],"hierarchy laws")
    Files.save(dest ++ "/kernel/LAWS.bend","import Base\nimport ./spec.bend as V\nimport ../src/hierarchy.bend as H\nimport ../src/components.bend as C\n\n" ++ laws)
    proof_source:String <- S.read("proofs/hierarchy/PROOF.bend")
    proof:String <- Extract.regions(proof_source,["def through_rejected(","def Laws.rejection_visit(","def saved(","def parent_saved(","def root_done(","def child_done(","def Laws.forest_visit(","def append_nil(","def append_assoc(","def reverse_tail(","def prepend_order(","def Laws.sequence_order(","def plus_right(","def zero_right(","def reverse_length(","def step_length(","def each_length(","def reuse_length(","def result_length(","def Laws.evaluate_length("],"hierarchy proofs")
    Files.save(dest ++ "/kernel/PROOF.bend","import Base\nimport ./LAWS.bend as Laws\nimport ./spec.bend as V\nimport ../src/hierarchy.bend as H\n\n" ++ proof)

# Run the original proofs unchanged against copies of full production modules.
def record(+dest:String,+label:String,+expected:String,result:U32 & (String & String)) -> IO(Unit):
  (+status,(out,err)) = result
  +log:String = out ++ err
  do IO<Unit>:
    Files.save(dest ++ "/" ++ label ++ ".log",log)
    Files.save(dest ++ "/" ++ label ++ ".status",U32.show(status) ++ "\n")
    S.require(Bool.pick(Bool,String.is_empty(expected),
      U32.is_zero(status) && String.contains(log,"ALL PROOFS CHECK"),
      U32.is_eq(status,1) && String.contains(log,"SOME PROOFS FAIL") && String.contains(log,"Location: " ++ expected ++ "\n") && String.contains(log,"- expected :") && String.contains(log,"- observed :")),
      "Unexpected hierarchy formal verdict: " ++ label ++ "; see " ++ dest)
    IO.print(label ++ Bool.pick(String,String.is_empty(expected)," proved"," rejected by " ++ expected))

def gate(+dest:String,+label:String,+expected:String) -> IO(Unit):
  do IO<Unit>:
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("env",["-C",dest,"bend","proofs/hierarchy/PROOF.bend"],"",16777216,300000))
    record(dest,label,expected,result)

def kernel_gate(+dest:String,+label:String,expected:String) -> IO(Unit):
  do IO<Unit>:
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("env",["-C",dest,"bend","kernel/PROOF.bend","--verdict"],"",16777216,300000))
    record(dest,label,expected,result)

def kernel_failure(+label:String,expected:String) -> String:
  Bool.pick(String,String.eq(label,"missing-parent-accepted") || String.eq(label,"cycle-misclassified"),"Laws.rejection_visit",Bool.pick(String,String.eq(label,"visiting-mark-omitted"),"through_rejected",expected))

def mutation(+dest:String,parts:List<&2,String>) -> IO(Unit):
  match parts:
    case [+label,+path,before,after,+expected]:
      do IO<Unit>:
        +source:String <- S.read(path)
        +changed:String <- Mutate.replaced(Mutate.replace(String.split(source,'\n'),before,after))
        Files.save(dest ++ "/" ++ path,changed)
        Files.save(dest ++ "/" ++ label ++ ".source",changed)
        gate(dest,label,expected)
        Bool.pick(IO(Unit),String.eq(path,"src/hierarchy.bend"),kernel_gate(dest,label ++ "-kernel",kernel_failure(label,expected)),IO.pure(Unit,Unit{}))
        Files.save(dest ++ "/" ++ path,source)
    case _:IO.die(Unit,1,"Malformed hierarchy formal mutation")

def mutations(+dest:String,lines:List<&2,String>) -> IO(Unit):
  match lines:
    case []:IO.pure(Unit,Unit{})
    case line <> rest:
      do IO<Unit>:
        mutation(dest,String.split(line,'\t'))
        mutations(dest,rest)

def fingerprint() -> IO(String):
  S.run("sha256sum",["src/hierarchy.bend","src/scene-hierarchy.bend","src/scene-schema.bend","deps/bendvy/src/ecs/execution-access.bend","deps/bendvy/src/ecs/execution-layout-access.bend","deps/bendvy/src/ecs/execution-query-identity.bend","deps/bendvy/src/ecs/chunk-column.bend","deps/bendvy/src/ecs/clock-state.bend","proofs/hierarchy/spec.bend","proofs/hierarchy/LAWS.bend","proofs/hierarchy/PROOF.bend","proofs/hierarchy/mutations.tsv","tools/verify-hierarchy-formal.bend","tools/verify-publication.bend"])

def main() -> IO(Unit):
  do IO<Unit>:
    _:String <- S.run("mkdir",["-p","build/verification"])
    directory:String <- S.run("mktemp",["-d","build/verification/hierarchy-formal-XXXXXXXX"])
    +dest:String = String.trim(directory)
    IO.print("Hierarchy formal evidence: " ++ dest)
    Files.save(dest ++ "/run.status","1\n")
    +hashes:String <- fingerprint()
    Files.save(dest ++ "/sources.sha256",hashes)
    version:String <- S.run("bend",["version"])
    Files.save(dest ++ "/bend.txt",version)
    _:String <- S.run("cp",["-R","--reflink=auto","--","src","proofs","deps",dest])
    gate(dest,"baseline","")
    core(dest)
    kernel_gate(dest,"core-kernel","")
    cases:String <- S.read("proofs/hierarchy/mutations.tsv")
    mutations(dest,String.lines(String.trim(cases)))
    gate(dest,"restored","")
    kernel_gate(dest,"restored-kernel","")
    after:String <- fingerprint()
    S.require(String.eq(hashes,after),"Sources changed during hierarchy formal verification")
    Files.save(dest ++ "/run.status","0\n")
    IO.print("Hierarchy formal kernel core, frontend publication proofs and production sensitivity controls passed.")
    IO.print("Scope: universal lengths; certified traversal/order/commit; concrete schema qualification. General witness construction remains open; ECS publication is frontend-only.")
