import Base
import ../toolchain.bend as Pin

def require(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}: IO.pure(Unit,Unit{})
    case False{}: IO.die(Unit,1,message)

def completed(label: String, result: U32 & (String & String)) -> IO(String):
  (status,pair) = result
  (out,err) = pair
  +out : String = out
  +err : String = err
  do IO<String>:
    require(U32.is_zero(status),label ++ " failed:\n" ++ out ++ err)
    IO.write(err)
    return out

def run(+program: String, args: List<String>) -> IO(String):
  do IO<String>:
    IO.print("+ " ++ program)
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(program,args,"",16777216,300000))
    completed(program,result)

def command(program: String, args: List<String>) -> IO(Unit):
  do IO<Unit>:
    output : String <- run(program,args)
    IO.write(output)

def exact(program: String, args: List<String>, +expected: String) -> IO(Unit):
  do IO<Unit>:
    +actual : String <- run(program,args)
    require(String.eq(String.trim(actual),expected),"Expected " ++ expected ++ "; found " ++ actual)
    IO.write(actual)

def revisions(pins: List<(String & String)>) -> IO(Unit):
  match pins:
    case Nil{}: IO.pure(Unit,Unit{})
    case pair <> rest:
      (path,revision) = pair
      +path : String = path
      do IO<Unit>:
        exact("git",["-C",path,"rev-parse","HEAD"],revision)
        exact("git",["-C",path,"status","--porcelain","--untracked-files=all"],"")
        revisions(rest)

def expected() -> String:
  "before-barrier=\ntick=1 health=5,5\ntick=2 health=2.5,1.25\ntick=3 health=1.25,0.3125\ntick=4 health=0.625,0.078125\ntick=5 health=0.3125,0.01953125\ntick=6 health=0.15625,0.0048828125\nuntouched=30\nHost roundtrip and GPU buffer fill verified\nBendvy + Vulkan native compatibility verified; live Vulkan objects: 0"

def scene_expected() -> String:
  "before-tick entities=0 admitted=0\ntick=1 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted\nboundaries tick=1 start=0 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0\ntick=2 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted\nboundaries tick=2 start=100 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0\ntick=3 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted\nboundaries tick=3 start=100 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0\ntick=4 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted\nboundaries tick=4 start=100 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0\ntick=5 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted\nboundaries tick=5 start=100 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0\ntick=6 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted\nboundaries tick=6 start=100 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0\ntick=7 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted\nboundaries tick=7 start=100 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0\ntick=8 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted\nboundaries tick=8 start=100 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0\nShared mesh scene verified across 8 ticks."

def render_ticks(remaining:Nat,+tick:U32) -> String:
  match remaining:
    case 0n:""
    case 1n+rest:
      "tick=" ++ U32.show(tick) ++ " all=100 rgba=exact depth=exact repeat=equal replay=equal empty=clear unknown=rejected\n" ++ render_ticks(rest,U32.inc(tick))

def render_expected() -> String:
  "Scalar quaternion cross-product and independent coverage bound verified.\nindex-order=near-first\n" ++
  render_ticks(8n,1) ++ "index-order=far-first\n" ++ render_ticks(8n,1) ++
  "Terminal Action cleanup verified.\nPublic Vulkan renderer verified in both index orders; live Vulkan objects=0; image=build/scene-render.ppm"

def main() -> IO(Unit):
  do IO<Unit>:
    exact("bend",["version"],Pin.bend_version())
    +compiler : String <- run("clang",["--version"])
    require(String.starts_with(compiler,Pin.clang_version() ++ "\n"),"Wrong Clang version:\n" ++ compiler)
    exact("clang",["-dumpmachine"],Pin.native_target())
    exact("uname",["-sm"],"Linux x86_64")
    revisions(Pin.dependencies())
    command("mkdir",["-p","build"])
    command("bend",["PROOF.bend"])
    command("bend",["examples/native_compatibility.bend","-o","build/native-compatibility.c"])
    command("clang",["-std=c11","-O2","build/native-compatibility.c","-lpthread","-lm","-ldl","-o","build/native-compatibility"])
    exact("env",["-u","DISPLAY","-u","WAYLAND_DISPLAY","./build/native-compatibility","--threads","1","--gpu","off"],expected())
    command("bend",["examples/components.bend","-o","build/components.c"])
    command("clang",["-std=c11","-O2","build/components.c","-lpthread","-lm","-ldl","-o","build/components"])
    exact("env",["-u","DISPLAY","-u","WAYLAND_DISPLAY","./build/components","--threads","1","--gpu","off"],"Project component fields and defaults verified.")
    command("bend",["examples/scene.bend","-o","build/scene.c"])
    command("clang",["-std=c11","-O2","build/scene.c","-lpthread","-lm","-ldl","-o","build/scene"])
    exact("env",["-u","DISPLAY","-u","WAYLAND_DISPLAY","./build/scene","--threads","1","--gpu","off"],scene_expected())
    command("bend",["examples/scene-render.bend","-o","build/scene-render.c"])
    command("clang",["-std=c11","-O2","build/scene-render.c","-lpthread","-lm","-ldl","-o","build/scene-render"])
    exact("env",["-u","DISPLAY","-u","WAYLAND_DISPLAY","./build/scene-render","--threads","1","--gpu","off"],render_expected())
    IO.print("Pinned native toolchain and dependency compatibility verified.")
