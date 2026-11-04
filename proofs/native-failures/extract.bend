import Base
import ../../tools/upload-boundary/scan.bend as S
import ../../deps/bend-vulkan/tools/verification.bend as Output

def drop_before(lines:List<&2,String>,+marker:String) -> IO(List<&2,String>):
  match lines:
    case []:IO.die(List<&2,String>,1,"Native proof marker missing: " ++ marker)
    case +line <> +rest:
      Bool.pick(IO(List<&2,String>),String.starts_with(line,marker),IO.pure(List<&2,String>,line <> rest),drop_before(rest,marker))

def until(lines:List<&2,String>,+marker:String) -> IO(String):
  match lines:
    case []:IO.die(String,1,"Native proof end marker missing: " ++ marker)
    case +line <> rest:
      Bool.pick(IO(String),String.starts_with(line,marker),IO.pure(String,""),
        do IO<String>:
          tail:String <- until(rest,marker)
          return line ++ "\n" ++ tail)

def section(+text:String,start:String,end:String) -> IO(String):
  do IO<String>:
    lines:List<&2,String> <- drop_before(String.split(text,'\n'),start)
    until(lines,end)

def body(lines:List<&2,String>) -> IO(String):
  match lines:
    case []:IO.die(String,1,"Native proof function has no closing brace")
    case +line <> rest:
      Bool.pick(IO(String),String.eq(line,"}"),IO.pure(String,"}\n"),
        do IO<String>:
          tail:String <- body(rest)
          return line ++ "\n" ++ tail)

def function_lines(lines:List<&2,String>) -> IO(String):
  match lines:
    case []:IO.die(String,1,"Native proof function missing")
    case +line <> rest:
      Bool.pick(IO(String),String.ends_with(line,"}"),IO.pure(String,line ++ "\n"),
        do IO<String>:
          tail:String <- body(rest)
          return line ++ "\n" ++ tail)

def function(text:String,start:String) -> IO(String):
  do IO<String>:
    lines:List<&2,String> <- drop_before(String.split(text,'\n'),start)
    function_lines(lines)

def after_call(lines:List<&2,String>,+call:String) -> IO(List<&2,String>):
  match lines:
    case []:IO.die(List<&2,String>,1,"Native proof call boundary missing")
    case line <> rest:
      do IO<List<&2,String>>:
        S.require(String.eq(line,call),"Native proof call boundary changed: " ++ call)
        return rest

# Only the driver-return boundary becomes a symbolic input. The following
# handler statements are copied verbatim from the pinned production source.
def continuation(text:String,start:String,+call:String) -> IO(String):
  do IO<String>:
    source:String <- function(text,start)
    lines:List<&2,String> <- drop_before(String.split(source,'\n'),call)
    following:List<&2,String> <- after_call(lines,call)
    body(following)

def directive(+native:String,parts:List<&2,String>) -> IO(String):
  match parts:
    case ["// @function",name]:function(native,name)
    case ["// @section",name,start,end]:
      do IO<String>:
        source:String <- function(native,name)
        section(source,start,end)
    case ["// @tail",name,call]:continuation(native,name,call)
    case ["// @types"]:section(native,"#define BV_INVALID","static void bv_unpack(")
    case _:IO.die(String,1,"Malformed native proof extraction directive")

def render(+native:String,lines:List<&2,String>) -> IO(String):
  match lines:
    case []:IO.pure(String,"")
    case +line <> rest:
      do IO<String>:
        head:String <- Bool.pick(IO(String),String.starts_with(line,"// @"),directive(native,String.split(line,'|')),IO.pure(String,line ++ "\n"))
        tail:String <- render(native,rest)
        return head ++ tail

def extract(source:String,destination:String) -> IO(Unit):
  do IO<Unit>:
    native:String <- S.read(source)
    template:String <- S.read("proofs/native-failures/handlers.in.c")
    handlers:String <- render(native,String.split(template,'\n'))
    prelude:String <- S.read("proofs/native-failures/prelude.h")
    claims:String <- S.read("proofs/native-failures/claims.h")
    Output.write(destination,prelude ++ handlers ++ claims)

def args(values:List<String>) -> IO(Unit):
  match values:
    case [_,source,destination]:extract(source,destination)
    case _:IO.die(Unit,1,"usage: extract native.c output.c")

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<String> <- IO.args()
    args(values)
