import Base
import ./upload-boundary/scan.bend as S
import ./upload-boundary/inventory.bend as I
import ../toolchain.bend as Pin

def pins(xs:List<(String & String)>) -> IO(Unit):
  match xs:
    case []:IO.pure(Unit,Unit{})
    case (+path,+revision) <> rest:
      do IO<Unit>:
        actual:String <- S.run("git",["-C",path,"rev-parse","HEAD"])
        S.require(String.eq(String.trim(actual),revision),"Upload gate dependency revision mismatch " ++ path)
        status:String <- S.run("git",["-C",path,"status","--porcelain","--untracked-files=all"])
        S.require(String.is_empty(status),"Upload gate dependency dirty " ++ path)
        pins(rest)

def trusted(+file:String,+hashes:List<&2,String>) -> IO(Bool):
  do IO<Bool>:
    actual:String <- S.run("sha256sum",["--",file])
    return S.has(hashes,String.trim(actual))

def scan(xs:List<&2,String>,+all:List<&2,String>,+policy:List<&2,String>,+hashes:List<&2,String>) -> IO(Unit):
  match xs:
    case []:IO.pure(Unit,Unit{})
    case +file <> rest:
      do IO<Unit>:
        +capsule:Bool <- trusted(file,hashes)
        S.require(Bool.not(String.eq(file,"src/scene-buffer.bend") || String.eq(file,"src/upload-size.bend") || String.eq(file,"examples/native_compatibility.bend")) || capsule,"Upload trusted capsule changed. Review source and refresh tools/upload-boundary/trusted.sha256 after verification: " ++ file)
        Bool.pick(IO(Unit),capsule,IO.pure(Unit,Unit{}),S.scan(file,all,policy))
        scan(rest,all,policy,hashes)

def main() -> IO(Unit):
  do IO<Unit>:
    pins(Pin.dependencies())
    +symlinks:String <- S.run("find",[".","-path","./.git","-prune","-o","-path","./deps","-prune","-o","-path","./build","-prune","-o","-path","./docs","-prune","-o","-type","l","-print"])
    S.require(String.is_empty(symlinks),"Upload source scope rejects symlinks: " ++ symlinks)
    +files:List<&2,String> <- I.files()
    policy:String <- S.read("tools/upload-boundary/dependencies.txt")
    hashes:String <- S.read("tools/upload-boundary/trusted.sha256")
    scan(files,files,String.lines(String.trim(policy)),String.lines(String.trim(hashes)))
    IO.print("Upload source boundary verified, including untracked Bend sources.")
