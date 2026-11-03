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

def scene_expected() -> String:
  "before-tick entities=0 admitted=0\ntick=1 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted\nboundaries tick=1 start=0 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0\ntick=2 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted\nboundaries tick=2 start=100 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0\ntick=3 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted\nboundaries tick=3 start=100 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0\ntick=4 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted\nboundaries tick=4 start=100 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0\ntick=5 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted\nboundaries tick=5 start=100 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0\ntick=6 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted\nboundaries tick=6 start=100 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0\ntick=7 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted\nboundaries tick=7 start=100 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0\ntick=8 entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted\nboundaries tick=8 start=100 finish=100 receipts=100 updates=100 spawn=1 move=2 sync=0 events=4 unapplied=0\nShared mesh scene verified across 8 ticks."

def scene_checks(remaining:Nat,+split:Nat) -> String:
  match remaining:
    case 0n:"Headless production batching, zero, ownership, receipts, transform bits and detached retention verified."
    case 1n+rest:"split=" ++ Nat.show(split) ++ "+" ++ Nat.show(Nat.sub(8n,split)) ++
      " production=8 verified\n" ++ scene_checks(rest,1n+split)

def build(+source:String,+name:String,+expected:String) -> IO(Unit):
  do IO<Unit>:
    IO.print("build " ++ source ++ " -> build/headless/" ++ name)
    command("bend",[source,"-o","build/headless/" ++ name ++ ".c"])
    command("clang",["-std=c11","-O2","build/headless/" ++ name ++ ".c","-lpthread","-lm",
      "-o","build/headless/" ++ name])
    exact("env",["-u","DISPLAY","-u","WAYLAND_DISPLAY","./build/headless/" ++ name,
      "+RTS","--threads","1","--gpu","off"],expected)

def main() -> IO(Unit):
  do IO<Unit>:
    exact("bend",["version"],Pin.bend_version())
    +compiler : String <- run("clang",["--version"])
    require(String.starts_with(compiler,Pin.clang_version() ++ "\n"),"Wrong Clang version:\n" ++ compiler)
    IO.write(compiler)
    exact("clang",["-dumpmachine"],Pin.native_target())
    command("mkdir",["-p","build/headless"])
    build("examples/scene-headless.bend","scene-headless","Headless scene completed 8 production ticks.")
    build("examples/scene.bend","scene",scene_expected())
    build("tools/verify-headless-scene.bend","verify-scene",scene_checks(9n,0n))
    IO.print("Pinned CPU-only native headless verification passed.")
