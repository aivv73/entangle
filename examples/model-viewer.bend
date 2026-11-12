import Base
import ./consumer-content.bend as Content
import ./consumer-window.bend as Consumer
import ../src/creation.bend as Create

def path(values:List<String>) -> String:
  match values:
    case _ <> path <> _:path
    case _:"assets/consumers/beacon.obj"

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<String> <- IO.args()
    scene:Create.Scene <- Content.viewer(path(values))
    IO.print("Model viewer. WASD orbit, QE zoom, R reset, Escape exits. Static opaque triangulated OBJ and diffuse MTL supported.")
    Consumer.open(Consumer.Viewer{},scene)
