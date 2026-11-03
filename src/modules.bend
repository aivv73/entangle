import Base
import ./input.bend as Camera
import ./scene-render.bend as R
import ./scene-window.bend as Win
import ../deps/bend-vulkan/Vulkan.bend as V

type Core<-A:Type> is Type:
  Core{start:Unit -> IO(A)}

type Input is Type:
  Input{initial:Unit -> Camera.Camera}

type Assets is Type:
  Assets{load:Unit -> R.Mesh}

type Render is Type:
  Render{open:V.Entry -> R.Mesh -> V.Action(Win.Renderer)}

type Registration<-A:Type> is Type:
  Registration{core:Core<A>,input:Input,assets:Assets,render:Render}
