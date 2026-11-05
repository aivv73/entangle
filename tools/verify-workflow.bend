import Base
import ./upload-boundary/scan.bend as S
import ./verify-upload-mutations.bend as Files
import ../toolchain.bend as Pin

type Step is Data:
  Step{name:String,kind:String,program:String,args:List<&2,String>}

def native(+name:String,kind:String,path:String,args:List<&2,String>) -> List<&2,Step>:
  +binary:String = Bool.pick(String,String.eq(name,"boundary"),"build/verify-upload-boundary","build/workflow-" ++ name)
  [Step{name ++ "-build","build","bend",[path,"-o",binary]},
   Step{name,kind,"./" ++ binary,List.append(&2,String,args,["+RTS","--threads","1","--gpu","off"])}]

def known(name:String) -> Bool:
  S.has(["toolchain","proofs","assets","images","json","math","textures","upload","native-failures","native","window","textured-window","all"],name)

def valid(names:List<&2,String>) -> Bool:
  match names:
    case []:True{}
    case +name <> rest:known(name) && valid(rest)

def selected(+names:List<&2,String>,+name:String) -> Bool:
  S.has(names,name) || S.has(names,"all")

def add(ok:Bool,steps:List<&2,Step>) -> List<&2,Step>:
  Bool.pick(List<&2,Step>,ok,steps,[])

def plan(+names:List<&2,String>) -> List<&2,Step>:
  +baseline:Bool = selected(names,"native")
  +proofs:Bool = selected(names,"proofs")
  +assets:Bool = selected(names,"assets") || selected(names,"images") || selected(names,"json")
  +upload:Bool = selected(names,"upload") || baseline
  +failures:Bool = selected(names,"native-failures") || selected(names,"textures") || baseline
  +laws:Bool = proofs || assets || upload || failures || selected(names,"math")
  List.concat(&2,Step,[
    [Step{"toolchain","precondition","bend",["tools/verify-toolchain.bend"]}],
    add(laws || selected(names,"window") || selected(names,"textured-window"),native("boundary","source-policy","tools/verify-upload-boundary.bend",[])),
    add(laws && Bool.not(baseline),[Step{"frontend","frontend","bend",["PROOF.bend"]}]),
    add(assets && Bool.not(baseline),native("assets","runtime","tools/verify-assets.bend",[])),
    add(selected(names,"images") && Bool.not(baseline),native("images","runtime-and-sensitivity","tools/verify-images.bend",[])),
    add(selected(names,"json") && Bool.not(baseline),native("json","runtime-and-sensitivity","tools/verify-json.bend",[])),
    add(selected(names,"math"),native("math","qualification-and-retained-scenes","tools/verify-math.bend",[])),
    add(selected(names,"textures") && Bool.not(baseline),native("textures","runtime-and-sensitivity","tools/verify-textures.bend",[])),
    add(upload && Bool.not(baseline),native("upload-runtime","runtime","tools/verify-upload-runtime.bend",[])),
    add(upload && Bool.not(baseline),native("upload-native-limit","runtime","tools/verify-upload-native-limit.bend",[])),
    add(failures && Bool.not(baseline),native("resource-failures","runtime","tools/verify-resource-failures.bend",[])),
    add(baseline,native("native","native-baseline","tools/verify.bend",[])),
    add(selected(names,"window") && Bool.not(selected(names,"textured-window")),[Step{"window","mesh-window-and-replay","bash",["tools/verify-window-session.sh"]}]),
    add(selected(names,"textured-window"),[Step{"textured-window","all-renderer-windows-and-replay","bash",["tools/verify-window-session.sh","extended"]}]),
    add(proofs || upload,[Step{"upload-kernel","kernel","bend",["proofs/upload-range/PROOF.bend","--verdict"]}]),
    add(laws,native("law-mutations","sensitivity","tools/verify-law-mutations.bend",[])),
    add(upload,native("upload-mutations","sensitivity","tools/verify-upload-mutations.bend",[])),
    add(failures,native("native-failures","bounded-proof-and-sensitivity","tools/verify-native-failures.bend",["--mutations"]))])

def inputs() -> List<&2,String>:
  ["src","tools","examples","assets","proofs","deps","docs",".agents","LAWS.bend","PROOF.bend","toolchain.bend",".gitmodules","AGENTS.md","README.md"]

def linear(values:List<&2,String>) -> List<String>:
  match values:
    case []:[]
    case head <> rest:head <> linear(rest)

def reusable(values:List<String>) -> List<&2,String>:
  match values:
    case []:[]
    case head <> rest:head <> reusable(rest)

def raw(cwd:String,program:String,args:List<&2,String>,input:String) -> IO(Result<&1,&1,U32 & String,U32 & (String & String)>):
  Process.run("env",linear(List.append(&2,String,["-C",cwd,program],args)),input,16777216,3600000)

def output(value:Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(String):
  do IO<String>:
    result:U32 & (String & String) <- IO.try(U32 & (String & String),IO.pure(Result<&1,&1,U32 & String,U32 & (String & String)>,value))
    S.finished("Verification setup",result)

def command(cwd:String,program:String,args:List<&2,String>) -> IO(String):
  do IO<String>:
    result:Result<&1,&1,U32 & String,U32 & (String & String)> <- raw(cwd,program,args,"")
    output(result)

def fingerprint(+cwd:String) -> IO(String):
  do IO<String>:
    hashes:String <- command(cwd,"find",List.append(&2,String,inputs(),["-name",".git","-prune","-o","-type","f","-exec","sha256sum","--","{}","+"]))
    sorted:Result<&1,&1,U32 & String,U32 & (String & String)> <- raw(cwd,"sort",[],hashes)
    output(sorted)

def lines(values:List<&2,String>) -> String:
  match values:
    case []:""
    case head <> rest:head ++ "\n" ++ lines(rest)

def manifest(steps:List<&2,Step>) -> String:
  match steps:
    case []:""
    case Step{+name,kind,_,_} <> rest:
      name ++ "\t" ++ kind ++ "\t" ++ name ++ ".argv\t" ++ name ++ ".stdout\t" ++ name ++ ".stderr\t" ++ name ++ ".status\n" ++ manifest(rest)

def preview(steps:List<&2,Step>) -> IO(Unit):
  match steps:
    case []:IO.pure(Unit,Unit{})
    case Step{name,kind,program,args} <> rest:
      do IO<Unit>:
        IO.print(name ++ " [" ++ kind ++ "]")
        IO.write(lines(program <> args))
        preview(rest)

def prepare(+dest:String,steps:List<&2,Step>) -> IO(Unit):
  match steps:
    case []:IO.pure(Unit,Unit{})
    case Step{+name,_,program,args} <> rest:
      do IO<Unit>:
        Files.save(dest ++ "/" ++ name ++ ".argv",lines(program <> args))
        Files.save(dest ++ "/" ++ name ++ ".status","not_run\n")
        prepare(dest,rest)

def recorded(+dest:String,+name:String,result:Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(Bool):
  match result:
    case Fail{(code,message)}:
      do IO<Bool>:
        Files.save(dest ++ "/" ++ name ++ ".stderr",message)
        Files.save(dest ++ "/" ++ name ++ ".status","process_error:" ++ U32.show(code) ++ "\n")
        return False{}
    case Done{(+status,(out,err))}:
      do IO<Bool>:
        Files.save(dest ++ "/" ++ name ++ ".stdout",out)
        Files.save(dest ++ "/" ++ name ++ ".stderr",err)
        Files.save(dest ++ "/" ++ name ++ ".status",U32.show(status) ++ "\n")
        IO.print(name ++ " exit=" ++ U32.show(status))
        return U32.is_zero(status)

def execute(+dest:String,steps:List<&2,Step>) -> IO(Bool):
  match steps:
    case []:IO.pure(Bool,True{})
    case Step{+name,_,program,args} <> rest:
      do IO<Bool>:
        IO.print("Running " ++ name)
        Files.save(dest ++ "/" ++ name ++ ".status","running\n")
        result:Result<&1,&1,U32 & String,U32 & (String & String)> <- raw(dest ++ "/source",program,args,"")
        ok:Bool <- recorded(dest,name,result)
        Bool.pick(IO(Bool),ok,execute(dest,rest),IO.pure(Bool,False{}))

def metadata(+root:String,+dest:String,+name:String,program:String,args:List<&2,String>) -> IO(Unit):
  do IO<Unit>:
    text:String <- command(root,program,args)
    Files.save(dest ++ "/" ++ name,text)

def repository(+root:String,+dest:String,+path:String) -> IO(Unit):
  do IO<Unit>:
    +copy:String = dest ++ "/source/" ++ path
    +temporary:String = dest ++ "/repository-metadata"
    _:String <- command(root,"git",["clone","--local","--no-hardlinks","--no-checkout","--",root ++ "/" ++ path,temporary])
    _:String <- command(root,"rm",["-rf","--",copy ++ "/.git"])
    _:String <- command(root,"mv",["--",temporary ++ "/.git",copy ++ "/.git"])
    _:String <- command(root,"rmdir",["--",temporary])
    _:String <- command(copy,"git",["read-tree","HEAD"])
    return Unit{}

def repositories(+root:String,+dest:String,dependencies:List<(String & String)>) -> IO(Unit):
  match dependencies:
    case []:IO.pure(Unit,Unit{})
    case (path,_) <> rest:
      do IO<Unit>:
        repository(root,dest,path)
        repositories(root,dest,rest)

def run(+names:List<&2,String>) -> IO(Unit):
  do IO<Unit>:
    cwd:String <- S.run("pwd",[])
    +root:String = String.trim(cwd)
    _:String <- command(root,"mkdir",["-p","build/verification"])
    path:String <- command(root,"mktemp",["-d",root ++ "/build/verification/workflow-XXXXXXXX"])
    +dest:String = String.trim(path)
    IO.print("Evidence: " ++ dest)
    Files.save(dest ++ "/run.status","1\n")
    Files.save(dest ++ "/state","preparing\n")
    Files.save(dest ++ "/profiles.txt",lines(names))
    Files.save(dest ++ "/manifest.tsv","stage\tkind\targv\tstdout\tstderr\tstatus\n" ++ manifest(plan(names)))
    prepare(dest,plan(names))
    metadata(root,dest,"started.txt","date",["-u","+%Y-%m-%dT%H:%M:%SZ"])
    metadata(root,dest,"revision.txt","git",["rev-parse","HEAD"])
    metadata(root,dest,"worktree.txt","git",["status","--short"])
    metadata(root,dest,"worktree.patch","git",["diff","--binary","HEAD"])
    metadata(root,dest,"dependencies.txt","git",["submodule","status","--recursive"])
    metadata(root,dest,"platform.txt","uname",["-a"])
    metadata(root,dest,"bend.txt","bend",["version"])
    metadata(root,dest,"clang.txt","clang",["--version"])
    +before:String <- fingerprint(root)
    Files.save(dest ++ "/sources.sha256",before)
    _:String <- command(root,"mkdir",["-p",dest ++ "/source"])
    _:String <- command(root,"cp",List.append(&2,String,["-a","--reflink=auto","--"],List.append(&2,String,inputs(),[dest ++ "/source"])))
    repository(root,dest,".")
    repositories(root,dest,Pin.dependencies())
    +snapshot:String <- fingerprint(dest ++ "/source")
    +after:String <- fingerprint(root)
    Files.save(dest ++ "/snapshot.sha256",snapshot)
    S.require(String.eq(before,snapshot) && String.eq(before,after),"Sources changed while copying; evidence is incomplete. Run again from stable sources.")
    _:String <- command(root,"mkdir",["-p",dest ++ "/source/build/verification"])
    Files.save(dest ++ "/state","running\n")
    +ok:Bool <- execute(dest,plan(names))
    metadata(root,dest,"finished.txt","date",["-u","+%Y-%m-%dT%H:%M:%SZ"])
    Files.save(dest ++ "/state",Bool.pick(String,ok,"complete\n","failed\n"))
    Files.save(dest ++ "/run.status",Bool.pick(String,ok,"0\n","1\n"))
    IO.print("Evidence: " ++ dest)
    S.require(ok,"Required verification failed; inspect manifest.tsv and per-stage logs.")

def usage() -> String:
  "Usage: verify-workflow [--plan] PROFILE...\nProfiles: toolchain proofs assets images json math textures upload native-failures native window textured-window all\nEvery selected stage is required; stop on first failure. No arguments runs native.\nwindow covers mesh controls and replay; textured-window also covers cube, creation, replacement and textured scenes."

def choose(names:List<&2,String>,dry:Bool) -> IO(Unit):
  +names:List<&2,String> = names
  do IO<Unit>:
    S.require(valid(names) && Bool.not(String.eq(lines(names),"")),usage())
    Bool.pick(IO(Unit),dry,preview(plan(names)),run(names))

def args(values:List<&2,String>) -> IO(Unit):
  match values:
    case [_]:run(["native"])
    case [_,"--help"]:IO.print(usage())
    case _ <> "--plan" <> names:choose(names,True{})
    case _ <> names:choose(names,False{})
    case _:IO.die(Unit,1,usage())

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<String> <- IO.args()
    args(reusable(values))
