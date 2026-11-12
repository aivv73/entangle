import Base
import ../../examples/consumer-content.bend as Content
import ../../src/asset.bend as Asset
import ../../src/creation.bend as Create
import ../window-verification/check.bend as Check


def rejected(result:Result<&2,&2,Create.Error,Create.Compiled>) -> IO(Unit):
  match result:
    case Fail{_}:IO.print("Extreme source model accepted; fitting rejected by scene creation.")
    case _:IO.die(Unit,1,"Extreme source fixture must fail scene creation")

def checked(result:Result<&2,&2,Asset.Error,Create.Scene>) -> IO(Unit):
  match result:
    case Done{scene}:rejected(Create.compile(scene))
    case _:IO.die(Unit,1,"Extreme fixture must be accepted by the source importer")

def main() -> IO(Unit):
  do IO<Unit>:
    result:Result<&2,&2,Asset.Error,Create.Scene> <- Content.model("assets/consumers/extreme.obj")
    checked(result)
