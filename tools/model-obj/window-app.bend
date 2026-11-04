import Base
import ../../src/model-obj.bend as Obj
import ../../src/asset.bend as Asset
import ../../src/content.bend as F
import ../../src/creation.bend as Create
import ../../src/app.bend as Scope
import ../../deps/bend-vulkan/Vulkan.bend as V
import ../../examples/model-assets.bend as Example
import ../creation-window-app.bend as Window
import ../verify-creation.bend as Consumer
import ./native.bend as Native

def main() -> IO(Unit):
  do IO<Unit>:
    path:String <- IO.try(String,IO.get_env("ENTANGLE_OBJ_INPUT"))
    result:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(path)
    model:F.SourceModel <- Native.model(result)
    compiled:Create.Compiled <- Consumer.compiled(Create.compile(Example.content(model)))
    result:V.VkResult(Unit) & U32 <- Scope.with(Unit,entry => Window.run(entry,compiled))
    Window.finished(result)
    IO.print("Imported model window closed; live Vulkan objects: 0")
