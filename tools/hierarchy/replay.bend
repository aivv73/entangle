import Base
import ./check.bend as Check
import ./drive.bend as Drive
import ../../src/scene.bend as Scene
import ../../src/scene-hierarchy.bend as HW
import ../upload-boundary/scan.bend as S

def compared(expected:String,pair:Scene.Application() & List<&2,HW.Row>) -> IO(Scene.Application() & List<&2,HW.Row>):
  (app,+rows) = pair
  do IO<Scene.Application() & List<&2,HW.Row>>:
    S.require(String.eq(expected,Check.state(rows)),"Hierarchy replay differs in full local/parent/global/bounds state")
    return (app,rows)

def command(code:Maybe<&2,U32>,expected:String,pair:Scene.Application() & List<&2,HW.Row>) -> IO(Scene.Application() & List<&2,HW.Row>):
  match code:
    case None{}:IO.die(Scene.Application() & List<&2,HW.Row>,1,"Malformed hierarchy replay command")
    case Some{code}:
      do IO<Scene.Application() & List<&2,HW.Row>>:
        pair:Scene.Application() & List<&2,HW.Row> <- Drive.step(code,pair)
        compared(expected,pair)

def line(fields:List<&2,String>,pair:Scene.Application() & List<&2,HW.Row>) -> IO(Scene.Application() & List<&2,HW.Row>):
  match fields:
    case [code,expected]:command(U32.read(String.drop(code,15n)),String.drop(expected,6n),pair)
    case _:IO.die(Scene.Application() & List<&2,HW.Row>,1,"Malformed hierarchy state record")

def selected(yes:Bool,head:String,pair:Scene.Application() & List<&2,HW.Row>) -> IO(Scene.Application() & List<&2,HW.Row>):
  match yes:
    case True{}:line(String.split(head,' '),pair)
    case False{}:IO.pure(Scene.Application() & List<&2,HW.Row>,pair)

def replay(lines:List<&2,String>,pair:Scene.Application() & List<&2,HW.Row>,+count:U32) -> IO(U32):
  match lines:
    case []:IO.pure(U32,count)
    case +head <> tail:
      do IO<U32>:
        pair:Scene.Application() & List<&2,HW.Row> <- selected(String.starts_with(head,"hierarchy-step="),head,pair)
        replay(tail,pair,U32.add(count,Bool.to_u32(String.starts_with(head,"hierarchy-step="))))

def namespace_value(value:Maybe<&2,U32>) -> IO(U32):
  match value:
    case Some{value}:IO.pure(U32,value)
    case _:IO.die(U32,1,"Malformed recorded world namespace")

def namespace_fields(fields:List<&2,String>) -> IO(U32):
  match fields:
    case first <> _:namespace_value(U32.read(first))
    case _:IO.die(U32,1,"Missing recorded world namespace")

def namespace_record(fields:List<&2,String>) -> IO(U32):
  match fields:
    case [_,state]:namespace_fields(String.split(String.drop(state,6n),','))
    case _:IO.die(U32,1,"Malformed hierarchy state record")

def namespace_selected(selected:Bool,head:String,next:IO(U32)) -> IO(U32):
  match selected:
    case True{}:namespace_record(String.split(head,' '))
    case False{}:next

def recorded_namespace(lines:List<&2,String>) -> IO(U32):
  match lines:
    case []:IO.die(U32,1,"Missing hierarchy replay state")
    case +head <> tail:namespace_selected(String.starts_with(head,"hierarchy-step="),head,recorded_namespace(tail))

def run(path:String) -> IO(Unit):
  do IO<Unit>:
    +log:String <- S.read(path)
    namespace:U32 <- recorded_namespace(String.lines(log))
    pair:Scene.Application() & List<&2,HW.Row> <- Drive.boot_namespace(namespace)
    +count:U32 <- replay(String.lines(log),pair,0)
    S.require(U32.is_ge(count,10),"Hierarchy replay lacks the required actions")
    IO.print("Hierarchy deterministic replay matched " ++ U32.show(count) ++ " commands and complete entity/local/parent/global/bounds bits")

def arguments(args:List<String>) -> IO(Unit):
  match args:
    case [_,path]:run(path)
    case _:IO.die(Unit,1,"Usage: hierarchy-replay native.log")

def main() -> IO(Unit):
  do IO<Unit>:
    args:List<String> <- IO.args
    arguments(args)
