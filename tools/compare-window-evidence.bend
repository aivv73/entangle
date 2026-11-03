import Base
import ../deps/bend-vulkan/tools/verification.bend as Check

def compare(names:List<&2,String>,+before:String,+after:String) -> IO(Unit):
  match names:
    case []:IO.pure(Unit,Unit{})
    case +name <> rest:
      do IO<Unit>:
        Check.command("cmp",["--",before ++ "/" ++ name,after ++ "/" ++ name])
        IO.print("exact=" ++ name)
        compare(rest,before,after)

def main_args(args:List<String>) -> IO(Unit):
  match args:
    case [_,+before,+after]:
      do IO<Unit>:
        compare(["replay-tick-one.ppm","key-97.ppm","key-100.ppm","key-119.ppm","key-115.ppm","key-113.ppm","key-101.ppm","resize-800x450.ppm","resize-360x640.ppm","resize-720x480.ppm","resize-640x480.ppm","restored-moved.ppm","restored-exact.ppm","replay.log","terminal.log"],before,after)
        IO.print("Window replay pixels and deterministic logs are byte-identical.")
    case _:IO.die(Unit,1,"Usage: compare-window-evidence BEFORE_DIRECTORY AFTER_DIRECTORY")

def main() -> IO(Unit):
  do IO<Unit>:
    args:List<String> <- IO.args()
    main_args(args)
