import Base
import ../toolchain.bend as Pin
import ./upload-boundary/scan.bend as S
import ./verify-upload-mutations.bend as Files

def exact(program:String,args:List<String>,expected:String) -> IO(Unit):
  do IO<Unit>:
    +actual:String <- S.run(program,args)
    S.require(String.eq(String.trim(actual),expected),"Toolchain qualification output mismatch: " ++ actual)

def main() -> IO(Unit):
  do IO<Unit>:
    exact("bun",["--version"],Pin.bend_host_version())
    _:String <- S.run("mkdir",["-p","build/toolchains"])
    directory:String <- S.run("mktemp",["-d","build/toolchains/bend-2.0.40-XXXXXXXX"])
    +dest:String = String.trim(directory)
    +source:String = dest ++ "/source"
    +binary:String = dest ++ "/bin/bend"
    IO.print("Bend toolchain: " ++ dest)
    Files.save(dest ++ "/run.status","1\n")
    _:String <- S.run("git",["clone","--depth","1","--branch","v2.0.40","https://github.com/bendlang/bend.git",source])
    exact("git",["-C",source,"rev-parse","HEAD"],Pin.bend_revision())
    exact("git",["-C",source,"status","--porcelain"],"")
    _:String <- S.run("mkdir",["-p",dest ++ "/bin"])
    _:String <- S.run("cp",["-R",source ++ "/bend2",source ++ "/guide",dest])
    _:String <- S.run("bun",["build","--compile",source ++ "/bend2/main.ts","--outfile",binary])
    exact(binary,["version"],Pin.bend_version())
    exact("env",["BUN_BE_BUN=1",binary,"--version"],Pin.bend_host_version())
    _:String <- S.run(binary,["examples/components.bend","-o",dest ++ "/components"])
    exact(dest ++ "/components",["+RTS","--threads","1","--gpu","off"],"Project component fields and defaults verified.")
    _:String <- S.run(binary,["tools/verify-mesh-window.bend","-o",dest ++ "/verify-mesh-window"])
    hashes:String <- S.run("sha256sum",[binary,dest ++ "/bend2/base.bend"])
    Files.save(dest ++ "/qualification.txt",Pin.bend_version() ++ "\nsource " ++ Pin.bend_revision() ++ "\nBun " ++ Pin.bend_host_version() ++ "\n" ++ hashes)
    Files.save(dest ++ "/run.status","0\n")
    IO.print("Qualified compiler, real component output, and full native window-driver build. Prepend " ++ dest ++ "/bin to PATH.")
