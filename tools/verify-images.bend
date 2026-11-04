import Base
import ./image-decoder/common.bend as C

def command(program:String,args:List<String>) -> IO(Unit):
  do IO<Unit>:
    output:String <- C.command(program,args)
    IO.write(output)

def main() -> IO(Unit):
  do IO<Unit>:
    command("mkdir",["-p","build/image-comparison"])
    command("sha256sum",["-c","deps/jonlib-png/SHA256SUMS"])
    command("sha256sum",["-c","docs/verification/2026-11-04-image-decoder/corpus/SHA256SUMS"])
    command("bend",["tools/image-decoder/corpus.bend","-o","build/image-comparison/prepare"])
    command("./build/image-comparison/prepare",["+RTS","--threads","1","--gpu","off"])
    command("bend",["tools/image-decoder/probes.bend","-o","build/image-comparison/probes"])
    command("./build/image-comparison/probes",["+RTS","--threads","1","--gpu","off"])
    command("bend",["tools/image-decoder/runtime.bend","-o","build/image-comparison/runtime"])
    command("./build/image-comparison/runtime",["+RTS","--threads","1","--gpu","off"])
    command("bend",["tools/image-decoder/files.bend","-o","build/image-comparison/files"])
    command("./build/image-comparison/files",["+RTS","--threads","1","--gpu","off"])
    command("bend",["tools/image-decoder/mutations.bend","-o","build/image-comparison/mutations"])
    command("./build/image-comparison/mutations",["+RTS","--threads","1","--gpu","off"])
    command("bend",["examples/image-assets.bend","-o","build/image-comparison/example"])
    command("./build/image-comparison/example",["build/image-corpus/june-rgb8.png","+RTS","--threads","1","--gpu","off"])
    IO.print("Image decoder verification complete.")
