import Base
import ./upload-boundary/scan.bend as S
import ./verify-native-failures.bend as Native
import ./verify-upload-mutations.bend as Files

# Mutate copies of production definitions, leaving laws and proofs unchanged.
# Each rejected run must identify the expected law, not just exit nonzero.
def record(result:U32 & (String & String),+dest:String,+label:String,+failure:String) -> IO(Unit):
  (+status,pair) = result
  (out,err) = pair
  +log:String = out ++ err
  +negative:Bool = Bool.not(String.eq(failure,""))
  do IO<Unit>:
    Files.save(dest ++ "/" ++ label ++ ".log",log)
    Files.save(dest ++ "/" ++ label ++ ".status",U32.show(status) ++ "\n")
    S.require(Bool.pick(Bool,negative,
      U32.is_eq(status,1) && String.contains(log,"SOME PROOFS FAIL") && String.contains(log,"Location: Laws." ++ failure ++ "\n"),
      U32.is_zero(status) && String.contains(log,"ALL PROOFS CHECK")),
      "Unexpected law mutation verdict: " ++ label ++ "; see " ++ dest)
    IO.print(label ++ Bool.pick(String,negative," rejected by " ++ failure," passed"))

def gate(+dest:String,+label:String,proof:String,failure:String) -> IO(Unit):
  do IO<Unit>:
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("env",["-C",dest,"bend",proof],"",16777216,300000))
    record(result,dest,label,failure)

def mutation(+dest:String,parts:List<&2,String>) -> IO(Unit):
  match parts:
    case [+label,+path,+proof,before,after,failure]:
      do IO<Unit>:
        +original:String <- S.read(path)
        +changed:String <- Native.replaced(Native.replace(String.split(original,'\n'),before,after))
        Files.save(dest ++ "/" ++ label ++ ".source",changed)
        Files.save(dest ++ "/" ++ path,changed)
        gate(dest,label,proof,failure)
        Files.save(dest ++ "/" ++ path,original)
    case _:IO.die(Unit,1,"Malformed Bend law mutation")

def mutations(+dest:String,lines:List<&2,String>) -> IO(Unit):
  match lines:
    case []:IO.pure(Unit,Unit{})
    case line <> rest:
      do IO<Unit>:
        mutation(dest,String.split(line,'\t'))
        mutations(dest,rest)

def main() -> IO(Unit):
  do IO<Unit>:
    _:String <- S.run("mkdir",["-p","build/verification"])
    directory:String <- S.run("mktemp",["-d","build/verification/law-mutations-XXXXXXXX"])
    +dest:String = String.trim(directory)
    IO.print("Bend law mutation evidence: " ++ dest)
    _:String <- S.run("cp",["-R","--reflink=auto","--","src","proofs","tools","examples","deps","LAWS.bend","PROOF.bend","toolchain.bend",dest])
    hashes:String <- S.run("sha256sum",["src/asset.bend","src/scene-geometry-policy.bend","src/time.bend","src/upload-size.bend","src/hierarchy.bend","src/scene-hierarchy.bend","src/scene-draw.bend","src/json-boundary.bend","src/scene-file.bend","src/scene-matrix.bend","src/render-format.bend","src/content.bend","deps/bend-vulkan/src/core.bend","LAWS.bend","PROOF.bend","proofs/upload-range/LAWS.bend","proofs/upload-range/PROOF.bend","proofs/law-mutations.tsv","tools/verify-law-mutations.bend"])
    Files.save(dest ++ "/sources.sha256",hashes)
    gate(dest,"baseline-root","PROOF.bend","")
    gate(dest,"baseline-upload","proofs/upload-range/PROOF.bend","")
    cases:String <- S.read("proofs/law-mutations.tsv")
    mutations(dest,String.lines(String.trim(cases)))
    gate(dest,"restored-root","PROOF.bend","")
    gate(dest,"restored-upload","proofs/upload-range/PROOF.bend","")
    IO.print("Production Bend law mutations rejected; original sources restored in the evidence copy.")
