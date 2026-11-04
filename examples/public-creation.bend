import ../src/content.bend as F
import Base
import ../src/creation.bend as Create
import ../src/components.bend as C
import ../src/scene.bend as Scene
import ../src/headless.bend as Headless
import ./content-assets.bend as Source

def transform(x:F32) -> C.Transform:
  C.Transform{C.Vec3{x,0.0,0.0},C.Quat{0.0,0.0,0.0,1.0},C.Vec3{1.0,1.0,1.0}}

def content() -> Create.Scene:
  +triangle:F.Mesh = Source.triangle()
  Create.Scene{[
    Create.Instance{triangle,F.Basic{C.Vec3{1.0,0.0,0.0}},transform(F32.neg(0.5))},
    Create.Instance{triangle,F.Basic{C.Vec3{0.0,1.0,0.0}},transform(0.5)},
    Create.Instance{triangle,F.Basic{C.Vec3{1.0,0.0,0.0}},transform(1.5)}]}

def camera() -> Create.Camera:
  Create.Camera{C.Vec3{1.0,F32.neg(1.0),F32.neg(2.0)},0.65,0.45,7.0,Create.Perspective{1.7320508,0.1,100.0}}

def start(compiled:Create.Compiled) -> IO(Unit):
  Create.Compiled{seeds,_} = compiled
  do IO<Unit>:
    app:Scene.Application() <- Scene.create(seeds)
    app:Scene.Application() <- Headless.advance(~Scene.Application(),~Scene.tick,2n,app)
    IO.print("Public instances completed two production ECS ticks.")

def checked(result:Result<&2,&2,Create.Error,Create.Compiled>) -> IO(Unit):
  match result:
    case Fail{_}:IO.die(Unit,1,"Invalid scene description")
    case Done{compiled}:start(compiled)

def configured(camera:Maybe<Create.Camera>) -> IO(Unit):
  match camera:
    case None{}:IO.die(Unit,1,"Invalid camera configuration")
    case Some{_}:checked(Create.compile(content()))

def main() -> IO(Unit):configured(Create.camera(camera()))
