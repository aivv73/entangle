import Base
import ../src/modules.bend as Modules
import ../src/scene.bend as Scene
import ../src/input.bend as Camera
import ../src/scene-render.bend as R
import ../src/scene-window.bend as Win
import ../deps/bend-vulkan/Vulkan.bend as V
import ./scene-window-app.bend as SceneApp

def core_start(_:Unit) -> IO(Scene.Application()):
  do IO<Scene.Application()>:
    app : Scene.Application() <- Scene.create()
    Scene.tick(app)

def input_start(_:Unit) -> Camera.Camera:
  Camera.initial()

def asset_load(_:Unit) -> R.Mesh:
  SceneApp.mesh()

def render_open(entry:V.Entry,mesh:R.Mesh) -> V.Action(Win.Renderer):
  Win.open(entry,"Entangle ECS scene",mesh)

def defaults() -> Modules.Registration<Scene.Application()>:
  Modules.Registration{Modules.Core{core_start},Modules.Input{input_start},Modules.Assets{asset_load},Modules.Render{render_open}}
