import Base
import ./upload-boundary/scan.bend as S
import ./verify-upload-mutations.bend as Files

def words(tokens:List<&2,String>) -> String:
  match tokens:
    case []:""
    case +token <> rest:
      Bool.pick(String,String.is_empty(token),"",token ++ ",") ++ words(rest)

def normalize(s:String) -> String:
  match s:
    case SNil{}:""
    case SCon{+c,rest}:
      SCon{Bool.pick(Char,Char.is_eq(c,'\n'), ' ',c),normalize(rest)}

def shader(+stage:String) -> IO(String):
  +binary = "build/scene-" ++ stage ++ ".spv"
  do IO<String>:
    _:String <- S.run("glslc",["--target-env=vulkan1.0","-O","-o",binary,"src/shaders/textured." ++ stage])
    _:String <- S.run("spirv-val",["--target-env","vulkan1.0",binary])
    text:String <- S.run("od",["-An","-v","-tu4",binary])
    return "def " ++ stage ++ "() -> List<U32>:\n  [" ++ words(String.split(normalize(text),' ')) ++ "]\n"

def output(check:Bool,+source:String) -> IO(Unit):
  match check:
    case False{}:Files.save("src/shaders/spirv.bend",source)
    case True{}:
      do IO<Unit>:
        current:String <- S.read("src/shaders/spirv.bend")
        S.require(String.eq(current,source),"Scene SPIR-V is stale. Run bend tools/build-scene-shaders.bend")

def check(args:List<String>) -> Bool:
  match args:
    case []:False{}
    case arg <> rest:String.eq(arg,"--check") || check(rest)

def main() -> IO(Unit):
  do IO<Unit>:
    _:String <- S.run("mkdir",["-p","build"])
    args:List<String> <- IO.args
    vertex:String <- shader("vert")
    fragment:String <- shader("frag")
    output(check(args),"import Base\n\n" ++ vertex ++ "\n" ++ fragment)
