import Base
import ./upload-boundary/scan.bend as S
import ./upload-boundary/inventory.bend as I

def close(pair:File & Result<&1,&1,U32 & String,Unit>) -> IO(Unit):
  (file,result) = pair
  do IO<Unit>:
    File.close(file)
    IO.try(Unit,IO.pure(Result<&1,&1,U32 & String,Unit>,result))

def save(path:String,text:String) -> IO(Unit):
  do IO<Unit>:
    file:File <- IO.try(File,File.open(path,"w"))
    pair:File & Result<&1,&1,U32 & String,Unit> <- File.write(file,text)
    close(pair)

def copy(xs:List<&2,String>,+dest:String) -> IO(Unit):
  match xs:
    case []:IO.pure(Unit,Unit{})
    case +x <> rest:
      do IO<Unit>:
        dir:String <- S.base_dir(x)
        _:String <- S.run("mkdir",["-p",dest ++ "/" ++ dir])
        _:String <- S.run("cp",["--",x,dest ++ "/" ++ x])
        copy(rest,dest)

def record(result:U32 & (String & String),+dest:String,+label:String,+reject:Bool) -> IO(Unit):
  (+status,pair) = result
  (out,err) = pair
  +out:String = out
  +err:String = err
  do IO<Unit>:
    save(dest ++ "/" ++ label ++ ".log",out ++ err)
    save(dest ++ "/" ++ label ++ ".status",U32.show(status) ++ "\n")
    S.require(Bool.not(Bool.xor(Bool.not(U32.is_zero(status)),reject)),"Unexpected mutation verdict " ++ label ++ "\n" ++ out ++ err)
    IO.print(label ++ Bool.pick(String,reject," rejected"," passed"))

def gate(+root:String,+dest:String,+label:String,+reject:Bool) -> IO(Unit):
  do IO<Unit>:
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("env",["-C",dest,root ++ "/build/verify-upload-boundary"],"",16777216,300000))
    record(result,dest,label,reject)

def mutation(+root:String,+dest:String,+label:String,text:String) -> IO(Unit):
  do IO<Unit>:
    save(dest ++ "/src/upload-mutation.bend",text)
    gate(root,dest,label,True{})
    _:String <- S.run("rm",["--",dest ++ "/src/upload-mutation.bend"])
    return Unit{}

def main() -> IO(Unit):
  do IO<Unit>:
    cwd:String <- S.run("pwd",[])
    +root:String = String.trim(cwd)
    directory:String <- S.run("mktemp",["-d","build/verification/upload-mutations-XXXXXXXX"])
    +dest:String = String.trim(directory)
    files:List<&2,String> <- I.files()
    copy(files,dest)
    _:String <- S.run("cp",["tools/upload-boundary/dependencies.txt","tools/upload-boundary/trusted.sha256",dest ++ "/tools/upload-boundary/"])
    _:String <- S.run("ln",["-s",root ++ "/deps",dest ++ "/deps"])
    gate(root,dest,"baseline",False{})
    mutation(root,dest,"raw-alias-value","import Base\nimport ../deps/bend-vulkan/Vulkan.bend as Other\ndef attempt() -> V.Action(Unit):\n  Other.Device.write_memory\n")
    mutation(root,dest,"raw-words-value","import Base\nimport ../deps/bend-vulkan/Vulkan.bend as Other\ndef attempt() -> U32:\n  Other.Device.write_memory_words\n")
    mutation(root,dest,"forged-constructor","import Base\nimport ./scene-buffer.bend as Different\ndef attempt() -> Different.Buffer:\n  Different.Buffer{0,0,0}\n")
    mutation(root,dest,"internal-helper","import Base\nimport ./scene-buffer.bend as Different\ndef attempt() -> U32:\n  Different.uploaded\n")
    mutation(root,dest,"staging-import","import Base\nimport ../deps/bend-vulkan/src/upload.bend as Alternate\ndef attempt() -> U32:\n  Alternate.stage_valid\n")
    mutation(root,dest,"dependency-helper","import Base\nimport ../deps/bend-vulkan/examples/indexed_offscreen.bend as Alternate\ndef attempt() -> U32:\n  Alternate.buffer\n")
    mutation(root,dest,"foreign-effect","import Base\ndef attempt() -> IO(Unit):\n  import \"./upload-mutation.c\"\n")
    mutation(root,dest,"outside-scope-import","import Base\nimport ../docs/archived.bend as Outside\n")
    save(dest ++ "/src/upload-wrapper.bend","import Base\nimport ../deps/bend-vulkan/Vulkan.bend as Hidden\ndef bypass() -> U32:\n  Hidden.Device.write_memory\n")
    mutation(root,dest,"raw-hidden-wrapper","import Base\nimport ./upload-wrapper.bend as Wrapper\ndef attempt() -> U32:\n  Wrapper.bypass\n")
    _:String <- S.run("rm",["--",dest ++ "/src/upload-wrapper.bend"])
    save(dest ++ "/src/scene-buffer.bend","import Base\n")
    gate(root,dest,"trusted-capsule-change",True{})
    _:String <- S.run("cp",["src/scene-buffer.bend",dest ++ "/src/scene-buffer.bend"])
    native:String <- S.read("tools/verify-upload-native-limit.bend")
    save(dest ++ "/tools/verify-upload-native-limit.bend",native ++ "\ndef unreviewed() -> U32:0\n")
    gate(root,dest,"trusted-native-change",True{})
    _:String <- S.run("cp",["tools/verify-upload-native-limit.bend",dest ++ "/tools/verify-upload-native-limit.bend"])
    gate(root,dest,"restored",False{})
    IO.print("Isolated source mutation evidence: " ++ dest)
