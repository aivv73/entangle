import ../src/content.bend as F
import ../src/creation.bend as Create
import ./scene-seeds.bend as Seeds
import Base
import ../src/modules.bend as Modules
import ../src/scene.bend as Scene
import ../src/input.bend as Camera
import ../src/scene-render.bend as R
import ../src/scene-window.bend as Win
import ../deps/bend-vulkan/Vulkan.bend as V
import ./scene-window-app.bend as SceneApp

def core_start(seeds:List<&2,Create.Seed>) -> IO(Scene.Application()):
  do IO<Scene.Application()>:
    app : Scene.Application() <- Scene.create(seeds)
    Scene.tick(app)

def input_start(_:Unit) -> Create.Camera:
  Camera.initial()

def instances(seeds:List<&2,Create.Seed>,+mesh:F.Mesh) -> List<&2,Create.Instance>:
  match seeds:
    case []:[]
    case Create.Seed{transform,_,_} <> rest:Create.Instance{mesh,F.white(),transform} <> instances(rest,mesh)

def content(geometry:Create.Geometry) -> Create.Scene:
  Create.Geometry{vertices,indices,_} = geometry
  Create.Scene{instances(Seeds.defaults(),F.Mesh{vertices,indices})}

def asset_load(_:Unit) -> Create.Scene:content(SceneApp.mesh())

def render_open(entry:V.Entry,mesh:Create.Geometry) -> V.Action(Win.Renderer):
  Win.open(entry,"Entangle ECS scene",mesh)

def defaults() -> Modules.Registration<Scene.Application()>:
  Modules.Registration{Modules.Core{core_start},Modules.Input{input_start},Modules.Assets{asset_load},Modules.Render{render_open}}
