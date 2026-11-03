import Base
import ./verify-headless.bend as Gate

def record() -> String:
  "docs/verification/2026-11-03-headless-runner/"

def push(word: String, words: List<&2,String>) -> List<&2,String>:
  match word:
    case SNil{}: words
    case SCon{h,t}: String.reverse(SCon{h,t}) <> words

type Scan is Data:
  Scanning{word: String, words: List<&2,String>}

def token_step(h: Char, word: String, words: List<&2,String>, blank: Bool) -> Scan:
  match blank:
    case True{}: Scanning{"",push(word,words)}
    case False{}: Scanning{SCon{h,word},words}

def tokens(s: String, state: Scan) -> List<&2,String>:
  match s state:
    case SNil{} Scanning{word,words}: List.reverse(&2,String,push(word,words))
    case SCon{+h,t} Scanning{word,words}:
      tokens(t,token_step(h,word,words,Char.is_space(h)))

def absolute(s: String) -> Bool:
  String.starts_with(s,"/")

def header(s: String) -> Bool:
  +s = s
  String.starts_with(s,"/usr/") && String.ends_with(s,".h")

def paths(text: String) -> List<&2,String>:
  List.filter(~String,~absolute,tokens(text,Scanning{"",Nil{}}))

def copy(files: List<&2,String>, +root: String) -> IO(Unit):
  match files:
    case Nil{}: IO.pure(Unit,Unit{})
    case h <> t:
      do IO<Unit>:
        Gate.command("cp",["-L","--parents",h,root])
        copy(t,root)

def programs(files: List<&2,String>, +root: String) -> IO(Unit):
  match files:
    case Nil{}: IO.pure(Unit,Unit{})
    case +h <> t:
      do IO<Unit>:
        copy([h],root)
        libraries : String <- Gate.run("ldd",[h])
        copy(paths(libraries),root)
        programs(t,root)

def effects(names: List<&2,String>, +root: String) -> IO(Unit):
  match names:
    case Nil{}: IO.pure(Unit,Unit{})
    case +h <> t:
      do IO<Unit>:
        copy(["/home/aivv/.bend/bend2/effs/" ++ h ++ ".c",
          "/home/aivv/.bend/bend2/effs/" ++ h ++ ".js"],root)
        effects(t,root)

def sources(files: List<&2,String>, +root: String) -> IO(Unit):
  match files:
    case Nil{}: IO.pure(Unit,Unit{})
    case h <> t:
      do IO<Unit>:
        Gate.command("cp",["--parents",h,root ++ "/work"])
        sources(t,root)

def emit(files: List<&2,String>, +stage: String) -> IO(Unit):
  match files:
    case Nil{}: IO.pure(Unit,Unit{})
    case +h <> t:
      do IO<Unit>:
        Gate.command("bend",[h,"-o",stage ++ "/" ++ String.take(h, Nat.sub(String.length(h),5n)) ++ ".c"])
        emit(t,stage)

def save(+name: String, content: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("tee",[record() ++ name],content,16777216,300000))
    ignored : String <- Gate.completed(name,result)
    return Unit{}

def main() -> IO(Unit):
  do IO<Unit>:
    +stage : String <- Gate.run("mktemp",["-d","/tmp/entangle-cpu-root.XXXXXX"])
    +stage : String = String.trim(stage)
    +root : String = stage ++ "/root"
    Gate.command("mkdir",["-p",root,stage ++ "/output",stage ++ "/tools",stage ++ "/examples"])
    programs(["/home/aivv/.bend/bin/bend","/usr/bin/clang","/usr/bin/ld",
      "/usr/bin/mkdir","/usr/bin/env","/usr/bin/sh"],root)
    copy(["/home/aivv/.bend/bend2/base.bend"],root)
    effects(["write","print","print_err","args","process_run","random_u32"],root)
    copy(["/usr/lib64/ld-linux-x86-64.so.2","/usr/lib/ld-linux-x86-64.so.2"],root)
    Gate.command("mkdir",["-p",root ++ "/lib64",root ++ "/usr/lib/clang/23/include",
      root ++ "/tmp",root ++ "/work/build",root ++ "/work/src",root ++ "/work/examples",
      root ++ "/work/tools",root ++ "/work/deps/bendvy",root ++ "/proc",root ++ "/dev"])
    Gate.command("cp",["-L","/usr/lib64/ld-linux-x86-64.so.2",root ++ "/lib64/ld-linux-x86-64.so.2"])
    emit(["tools/verify-headless.bend","examples/scene-headless.bend","examples/scene.bend",
      "tools/verify-headless-scene.bend"],stage)
    headers : String <- Gate.run("clang",["-std=c11","-O2","-M",
      stage ++ "/tools/verify-headless.c",stage ++ "/examples/scene-headless.c",
      stage ++ "/examples/scene.c",stage ++ "/tools/verify-headless-scene.c"])
    copy(List.sort(~String,~String.is_le,List.filter(~String,~header,paths(headers))),root)
    copy(["/usr/lib/crt1.o","/usr/lib/Scrt1.o","/usr/lib/crti.o","/usr/lib/crtn.o",
      "/usr/lib/libc.so","/usr/lib/libc_nonshared.a","/usr/lib/libpthread.a",
      "/usr/lib/libm.so","/usr/lib/libm.so.6","/usr/lib/libmvec.so.1","/usr/lib/libgcc_s.so.1"],root)
    gcc : String <- Gate.run("find",["/usr/lib/gcc/x86_64-pc-linux-gnu","-type","f","(",
      "-name","crtbegin.o","-o","-name","crtbeginS.o","-o","-name","crtend.o",
      "-o","-name","crtendS.o","-o","-name","libgcc.a","-o","-name","libgcc_eh.a",
      "-o","-name","libgcc_s.so",")"])
    copy(paths(gcc),root)
    sources(["toolchain.bend","src/headless.bend","src/scene.bend","src/scene-schema.bend",
      "src/scene-spawn.bend","src/scene-motion.bend","src/scene-step.bend","src/scene-observe.bend",
      "src/scene-draw.bend","src/components.bend","examples/scene.bend","examples/scene-headless.bend",
      "tools/verify-headless.bend","tools/verify-headless-scene.bend"],root)
    Gate.command("cp",["-r","deps/bendvy/src",root ++ "/work/deps/bendvy/"])
    manifest : String <- Gate.run("find",[root,"-type","f","-printf","/%P\n"])
    save("isolated-files.txt",String.join(List.sort(~String,~String.is_le,tokens(manifest,Scanning{"",Nil{}})),"\n") ++ "\n")
    hashes : String <- Gate.run("sha256sum",["/home/aivv/.bend/bin/bend","/usr/bin/clang","/usr/bin/ld"])
    save("toolchain.sha256",hashes)
    IO.print("stage=" ++ stage)
    revision : String <- Gate.run("git",["-C","deps/bendvy","rev-parse","HEAD"])
    IO.print("bendvy=" ++ String.trim(revision))
    IO.print("Network, IPC, PID and UTS namespaces isolated. User and cgroup isolation follow Bubblewrap's supported-namespace policy and are not separate acceptance claims.")
    IO.print("No host root, sysfs, display sockets, graphics checkout, SDK, graphics headers, graphics loader, ICDs or GPU devices mounted.")
    Gate.command("bwrap",["--unshare-all","--die-with-parent","--new-session","--clearenv",
      "--ro-bind",root,"/","--proc","/proc","--dev","/dev","--tmpfs","/tmp",
      "--bind",stage ++ "/output","/work/build","--chdir","/work",
      "--setenv","PATH","/usr/bin:/home/aivv/.bend/bin","--setenv","HOME","/tmp",
      "--setenv","TMPDIR","/tmp","/home/aivv/.bend/bin/bend","tools/verify-headless.bend"])
    IO.print("Fresh artifacts=" ++ stage ++ "/output")
