import Base
import ./scene-seeds.bend as Seeds
import ../src/headless.bend as Headless
import ../src/scene.bend as Scene

def main() -> IO(Unit):
  do IO<Unit>:
    app : Scene.Application() <- Scene.create(Seeds.defaults())
    app : Scene.Application() <- Headless.advance(~Scene.Application(),~Scene.tick,8n,app)
    IO.print("Headless scene completed 8 production ticks.")
