import Base
import ./image-decoder/common.bend as C

def run(+name:String) -> IO(Unit):
  do IO<Unit>:
    IO.print("+ bend tools/json-scene/" ++ name ++ ".bend -o build/json-scene/" ++ name)
    output:String <- C.command("bend",["tools/json-scene/" ++ name ++ ".bend","-o","build/json-scene/" ++ name])
    IO.write(output)
    output:String <- C.command("build/json-scene/" ++ name,["+RTS","--threads","1","--gpu","off"])
    IO.write(output)

def main() -> IO(Unit):
  do IO<Unit>:
    _:String <- C.command("mkdir",["-p","build/json-scene"])
    output:String <- C.command("sha256sum",["-c","docs/verification/2026-11-04-json-scene/corpus/SHA256SUMS"])
    IO.write(output)
    run("qualify")
    run("runtime")
    run("bounds")
    run("cache")
    run("native")
    run("mutations")
    output:String <- C.command("build/json-scene/runtime",["+RTS","--threads","1","--gpu","off"])
    IO.write(output)
    output:String <- C.command("bend",["examples/json-scene.bend","-o","build/json-scene/example"])
    IO.write(output)
    output:String <- C.command("build/json-scene/example",["docs/verification/2026-11-04-json-scene/corpus/scene.json","+RTS","--threads","1","--gpu","off"])
    IO.write(output)
    IO.print("JSON qualification, file/schema/reference/limit checks, cache, production mutations, restored baseline and real ECS/offscreen consumer passed.")
