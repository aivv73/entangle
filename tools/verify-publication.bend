import Base
import ./upload-boundary/scan.bend as S
import ./verify-upload-mutations.bend as Files
import ./verify-native-failures.bend as Mutate
import ../proofs/geometry-publication/error-proof.bend as ErrorProof

type Module is Data:
  Module{output:String,source:String,imports:String,regions:List<&2,String>}

# Only imports change. Every selected declaration is copied verbatim, including
# native handle layouts. No effect or replacement transition is admitted.
def modules() -> List<&2,Module>:
  [Module{"native.bend","deps/bend-vulkan/Vulkan.bend","import Base\n",
    ["type Buffer ","type DeviceMemory ","type CommandPool ","type Fence ","type ImageHandle ","type ImageView ","type DescriptorSetLayout ","type DescriptorPool ","type DescriptorSet ","type Sampler ","def VkResult(","def Entry.finish("]},
   Module{"buffer.bend","src/scene-buffer.bend","import Base\nimport ./native.bend as V\nimport ../../../../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W\n",["type Buffer "]},
   Module{"texture.bend","src/scene-texture.bend","import Base\nimport ./native.bend as V\nimport ./buffer.bend as B\n",["type Resource ","type Material ","type Release ","def releasing("]},
   Module{"materials.bend","src/scene-materials.bend","import Base\nimport ./texture.bend as T\nimport ./native.bend as V\n",["type Binding ","type Resident ","def ownership(","def retire(","def collected(","def collected_resident(","def disposed("]},
   Module{"production.bend","src/scene-geometry.bend","import Base\nimport ./buffer.bend as B\nimport ./materials.bend as Materials\nimport ../../../../src/creation.bend as Create\n",["type Buffers ","type Resident ","def published("]}]

def matches(lines:List<&2,String>,+prefix:String) -> Nat:
  match lines:
    case []:0n
    case line <> rest:Nat.add(Bool.pick(Nat,String.starts_with(line,prefix),1n,0n),matches(rest,prefix))

def body(lines:List<&2,String>) -> String:
  match lines:
    case []:""
    case +line <> rest:
      Bool.pick(String,String.is_empty(line) || String.starts_with(line," "),line ++ "\n" ++ body(rest),"")

def declaration(lines:List<&2,String>,+prefix:String) -> String:
  match lines:
    case []:""
    case +line <> +rest:Bool.pick(String,String.starts_with(line,prefix),line ++ "\n" ++ body(rest),declaration(rest,prefix))

def regions(+source:String,names:List<&2,String>,+origin:String) -> IO(String):
  match names:
    case []:IO.pure(String,"")
    case +name <> rest:
      do IO<String>:
        S.require(Nat.is_eq(matches(String.split(source,'\n'),name),1n),"Publication proof requires one declaration: " ++ origin ++ " " ++ name)
        tail:String <- regions(source,rest,origin)
        return declaration(String.split(source,'\n'),name) ++ "\n" ++ tail

def extract(items:List<&2,Module>,+dest:String,+changed_path:String,+changed:String) -> IO(Unit):
  match items:
    case []:IO.pure(Unit,Unit{})
    case Module{output,+path,imports,names} <> rest:
      do IO<Unit>:
        source:String <- Bool.pick(IO(String),String.eq(path,changed_path),IO.pure(String,changed),S.read(path))
        text:String <- regions(source,names,path)
        Files.save(dest ++ "/" ++ output,imports ++ "\n" ++ text)
        extract(rest,dest,changed_path,changed)

def record(result:U32 & (String & String),+dest:String,+label:String,+failure:String) -> IO(Unit):
  (+status,(out,err)) = result
  +log:String = out ++ err
  do IO<Unit>:
    Files.save(dest ++ "/" ++ label ++ ".log",log)
    Files.save(dest ++ "/" ++ label ++ ".status",U32.show(status) ++ "\n")
    S.require(Bool.pick(Bool,String.is_empty(failure),
      U32.is_zero(status) && String.contains(log,"ALL PROOFS CHECK"),
      U32.is_eq(status,1) && String.contains(log,"SOME PROOFS FAIL") && String.contains(log,"Location: Laws." ++ failure ++ "\n")),"Unexpected publication proof verdict: " ++ label ++ "; see " ++ dest)
    IO.print(label ++ Bool.pick(String,String.is_empty(failure)," proved"," rejected by " ++ failure))

def check(+dest:String,+label:String,path:String,source:String,failure:String) -> IO(Unit):
  do IO<Unit>:
    +copy:String = dest ++ "/" ++ label
    _:String <- S.run("mkdir",[copy])
    extract(modules(),copy,path,source)
    _:String <- S.run("cp",["proofs/geometry-publication/LAWS.bend.in",copy ++ "/LAWS.bend"])
    proof:String <- S.read("proofs/geometry-publication/PROOF.bend.in")
    Files.save(copy ++ "/PROOF.bend",proof ++ ErrorProof.proof())
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("bend",[copy ++ "/PROOF.bend"],"",16777216,300000))
    record(result,dest,label,failure)

def mutation(+dest:String,parts:List<&2,String>) -> IO(Unit):
  match parts:
    case [+label,+path,before,after,failure]:
      do IO<Unit>:
        source:String <- S.read(path)
        +changed:String <- Mutate.replaced(Mutate.replace(String.split(source,'\n'),before,after))
        Files.save(dest ++ "/" ++ label ++ ".source",changed)
        check(dest,label,path,changed,failure)
    case _:IO.die(Unit,1,"Malformed publication mutation")

def mutations(+dest:String,lines:List<&2,String>) -> IO(Unit):
  match lines:
    case []:IO.pure(Unit,Unit{})
    case line <> rest:
      do IO<Unit>:
        mutation(dest,String.split(line,'\t'))
        mutations(dest,rest)

def run(negative:Bool) -> IO(Unit):
  do IO<Unit>:
    _:String <- S.run("mkdir",["-p","build/verification"])
    directory:String <- S.run("mktemp",["-d","build/verification/publication-XXXXXXXX"])
    +dest:String = String.trim(directory)
    IO.print("Publication proof evidence: " ++ dest)
    hashes:String <- S.run("sha256sum",["deps/bend-vulkan/Vulkan.bend","src/scene-buffer.bend","src/scene-texture.bend","src/scene-materials.bend","src/scene-geometry.bend","proofs/geometry-publication/LAWS.bend.in","proofs/geometry-publication/PROOF.bend.in","proofs/geometry-publication/error-proof.bend","proofs/geometry-publication/mutations.tsv","tools/verify-publication.bend"])
    Files.save(dest ++ "/sources.sha256",hashes)
    check(dest,"baseline","","","")
    Bool.pick(IO(Unit),negative,
      do IO<Unit>:
        cases:String <- S.read("proofs/geometry-publication/mutations.tsv")
        mutations(dest,String.lines(String.trim(cases)))
        check(dest,"restored","","",""),IO.pure(Unit,Unit{}))

def args(values:List<String>) -> IO(Unit):
  match values:
    case [_]:run(False{})
    case [_,"--mutations"]:run(True{})
    case _:IO.die(Unit,1,"usage: verify-publication [--mutations]")

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<String> <- IO.args()
    args(values)
