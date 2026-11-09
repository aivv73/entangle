import Base
import ./image-decoder/common.bend as C
import ../toolchain.bend as Pin

def run(+name:String) -> IO(Unit):
  do IO<Unit>:
    IO.print("+ bend tools/model-obj/" ++ name ++ ".bend -o build/model-obj/bin/" ++ name)
    build:String <- C.command("bend",["tools/model-obj/" ++ name ++ ".bend","-o","build/model-obj/bin/" ++ name])
    IO.write(build)
    IO.print("+ build/model-obj/bin/" ++ name ++ " +RTS --threads 1 --gpu off")
    output:String <- C.command("build/model-obj/bin/" ++ name,["+RTS","--threads","1","--gpu","off"])
    IO.write(output)

def main() -> IO(Unit):
  do IO<Unit>:
    +version:String <- C.command("bend",["version"])
    C.require(String.eq(String.trim(version),Pin.bend_version()),"OBJ verification requires " ++ Pin.bend_version() ++ "; found " ++ String.trim(version))
    IO.write(version)
    _:String <- C.command("mkdir",["-p","build/model-obj/bin"])
    output:String <- C.command("sha256sum",["-c","deps/jonlib-obj/SHA256SUMS"])
    IO.write(output)
    output:String <- C.command("sha256sum",["-c","docs/verification/2026-11-04-model-obj/corpus/SHA256SUMS"])
    IO.write(output)
    run("qualify")
    run("runtime")
    run("properties")
    run("bounds")
    run("files")
    run("inventory")
    run("mutations")
    run("native")
    output:String <- C.command("bend",["examples/model-assets.bend","-o","build/model-obj/example"])
    IO.write(output)
    output:String <- C.command("build/model-obj/example",["docs/verification/2026-11-04-model-obj/corpus/sign.obj","+RTS","--threads","1","--gpu","off"])
    IO.write(output)
    IO.print("Static OBJ source, properties, bounds, files/cache, mutations, source-only closure and real native consumers verified. X11 is a separate owned-display gate.")
