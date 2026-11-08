import Base
import ../src/mesh-playground.bend as Play
import ../src/mesh-control.bend as Control
import ../src/mesh-evidence.bend as Evidence
import ../src/scene-observe.bend as Old
import ../src/creation.bend as Create
import ../examples/mesh-playground-content.bend as Content
import ./verify-mesh-playground.bend as Real
import ./verify-creation.bend as Creation
import ./window-verification/check.bend as Check

def checked_state(expected:String,+baseline:List<&2,Old.Row>,pair:Play.Application() & List<&2,Old.Row>) -> IO(Play.Application()):
  (app,+rows) = pair
  do IO<Play.Application()>:
    Check.assert(Real.invariant(baseline,rows) && String.eq(expected,Evidence.rows(rows)),"Recorded X11 batch replay differs in full identity/mesh/transform bits")
    return app

def parsed_nat(value:Maybe<&2,Nat>) -> IO(Nat):
  match value:
    case Some{value}:IO.pure(Nat,value)
    case _:IO.die(Nat,1,"Invalid recorded step count")

def nat(text:String) -> IO(Nat):parsed_nat(Nat.read(text))

def parsed_key(app:Play.Application(),code:Maybe<&2,U32>,down:String) -> IO(Play.Application()):
  match code:
    case Some{code}:IO.pure(Play.Application(),Play.update(Control.intent(code,String.eq(down,"1")),app))
    case _:IO.die(Play.Application(),1,"Invalid recorded key")

def key(code:String,down:String,app:Play.Application()) -> IO(Play.Application()):
  parsed_key(app,U32.read(code),down)

def line(words:List<&2,String>,original:String,+baseline:List<&2,Old.Row>,app:Play.Application()) -> IO(Play.Application()):
  match words:
    case ["mesh-key",code,down]:key(code,down,app)
    case ["mesh-active",active]:IO.pure(Play.Application(),Play.visible(String.eq(active,"1"),app))
    case ["mesh-step",count]:
      do IO<Play.Application()>:
        +n:Nat <- nat(count)
        Check.assert(Nat.is_le(n,4n),"Recorded catch-up exceeds four steps")
        return app
    case ["mesh-tick"]:Real.advance(1n,app)
    case "mesh-tick-state" <> _:
      do IO<Play.Application()>:
        observed:Play.Application() & List<&2,Old.Row> <- Real.snapshot(app)
        checked_state(String.drop(original,16n),baseline,observed)
    case "mesh-state" <> _:
      do IO<Play.Application()>:
        observed:Play.Application() & List<&2,Old.Row> <- Real.snapshot(app)
        checked_state(String.drop(original,11n),baseline,observed)
    case _:IO.pure(Play.Application(),app)

def account(words:List<&2,String>,+pending:Nat) -> IO(Nat):
  match words:
    case ["mesh-step",count]:
      do IO<Nat>:
        Check.assert(Nat.is_eq(pending,0n),"Recorded batch did not finish its announced ticks")
        nat(count)
    case ["mesh-tick"]:
      do IO<Nat>:
        Check.assert(Nat.is_gt(pending,0n),"Recorded tick exceeds announced batch")
        return Nat.sub(pending,1n)
    case "mesh-state" <> _:
      do IO<Nat>:
        Check.assert(Nat.is_eq(pending,0n),"Recorded state precedes announced ticks")
        return pending
    case _:IO.pure(Nat,pending)

def lines(xs:List<&2,String>,+baseline:List<&2,Old.Row>,app:Play.Application(),count:Nat,+pending:Nat) -> IO(Nat):
  match xs:
    case []:
      do IO<Nat>:
        Check.assert(Nat.is_eq(pending,0n),"Recorded trace ended inside a batch")
        return count
    case +head <> tail:
      do IO<Nat>:
        pending:Nat <- account(String.split(head,' '),pending)
        app:Play.Application() <- line(String.split(head,' '),head,baseline,app)
        lines(tail,baseline,app,Nat.add(count,Bool.pick(Nat,String.starts_with(head,"mesh-state "),1n,0n)),pending)

def replay_started(text:String,pair:Play.Application() & List<&2,Old.Row>) -> IO(Unit):
  (app,baseline) = pair
  do IO<Unit>:
    +count:Nat <- lines(String.lines(text),baseline,app,0n,0n)
    Check.assert(Nat.is_gt(count,10n),"Insufficient recorded batches")
    IO.print("Real ECS replay matched " ++ Nat.show(count) ++ " X11 batches, including zero-step polls, with full handle and transform bits.")

def run(text:String,compiled:Create.Compiled) -> IO(Unit):
  Create.Compiled{seeds,_} = compiled
  do IO<Unit>:
    app:Play.Application() <- Play.create(seeds)
    initial:Play.Application() & List<&2,Old.Row> <- Real.snapshot(app)
    replay_started(text,initial)

def args(values:List<String>) -> IO(Unit):
  match values:
    case [_,path]:
      do IO<Unit>:
        text:String <- Check.read(path)
        compiled:Create.Compiled <- Creation.compiled(Create.compile(Content.scene()))
        run(text,compiled)
    case _:IO.die(Unit,1,"Usage: replay-mesh-window path/to/native.log")

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<String> <- IO.args()
    args(values)
