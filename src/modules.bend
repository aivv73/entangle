import ./creation.bend as Create
import Base
import ./scene-window.bend as Win
import ../deps/bend-vulkan/Vulkan.bend as V

type Core<-A:Type> is Type:
  Core{start:List<&2,Create.Seed> -> IO(A)}

type Input is Type:
  Input{initial:Unit -> Create.Camera}

type Assets is Type:
  Assets{load:Unit -> Create.Scene}

type Render is Type:
  Render{open:V.Entry -> Create.Geometry -> V.Action(Win.Renderer)}

type Registration<-A:Type> is Type:
  Registration{core:Core<A>,input:Input,assets:Assets,render:Render}

def compile(result:Result<&2,&2,Create.Error,Create.Compiled>) -> V.Action(Create.Compiled):
  match result:
    case Done{compiled}:V.Action.pure(Create.Compiled,compiled)
    case Fail{_}:IO.pure(V.VkResult(Create.Compiled),Fail{(1,"Invalid startup scene")})
