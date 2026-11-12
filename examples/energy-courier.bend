import Base
import ./consumer-content.bend as Content
import ./consumer-window.bend as Consumer
import ./courier-state.bend as Game
import ../src/creation.bend as Create

def main() -> IO(Unit):
  do IO<Unit>:
    scene:Create.Scene <- Content.gameplay()
    IO.print(Game.label(Game.Searching{}))
    IO.print("Amber crystal is two steps left. Violet delivery pad is two steps right of the start. WASD orbit, QE zoom, R camera reset. Escape exits.")
    Consumer.open(Consumer.Courier{},scene)
