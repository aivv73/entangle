import Base
import ../../tools/upload-boundary/scan.bend as S

def checked(result:U32 & (String & String)) -> IO(Unit):
  (status,pair) = result
  (out,err) = pair
  S.require(U32.is_zero(status),"CBMC archive checksum failed: " ++ out ++ err)

def install() -> IO(String):
  do IO<String>:
    +root:String = "build/verification/native-formal-tools"
    _:String <- S.run("mkdir",["-p",root ++ "/package"])
    _:String <- S.run("curl",["--fail","--location","--retry","2","--output",root ++ "/cbmc.deb","https://github.com/diffblue/cbmc/releases/download/cbmc-6.9.0/ubuntu-24.04-cbmc-6.9.0-Linux.deb"])
    checksum:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("sha256sum",["--check","-"],"3de313799ec2afc0154dad0e9d72db25d55aab007fa4652bf237626b808ca932  " ++ root ++ "/cbmc.deb\n",65536,300000))
    checked(checksum)
    _:String <- S.run("ar",["x","--output",root ++ "/package",root ++ "/cbmc.deb"])
    _:String <- S.run("tar",["-xf",root ++ "/package/data.tar.gz","-C",root ++ "/package"])
    return root ++ "/package/usr/bin/cbmc"

def available(result:U32 & (String & String),+binary:String) -> IO(String):
  (status,_) = result
  Bool.pick(IO(String),U32.is_zero(status),IO.pure(String,binary),install())

def ensure() -> IO(String):
  do IO<String>:
    +binary:String = "build/verification/native-formal-tools/package/usr/bin/cbmc"
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("test",["-x",binary],"",65536,300000))
    +ready:String <- available(result,binary)
    version:String <- S.run(ready,["--version"])
    S.require(String.eq(String.trim(version),"6.9.0 (cbmc-6.9.0)"),"Native proof requires CBMC 6.9.0")
    return ready
