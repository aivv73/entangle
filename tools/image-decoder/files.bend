import Base
import ./common.bend as C
import ./corpus.bend as Corpus
import ./runtime.bend as Runtime
import ../process-address-limit.bend as Address
import ../../src/asset.bend as Asset
import ../../src/content.bend as Content
import ../../src/image-png.bend as Png

def native_error(value:Result<&1,&1,U32 & String,File>) -> IO(Asset.Error):
  match value:
    case Fail{(code,message)}:IO.pure(Asset.Error,Asset.Error{code,message})
    case Done{file}:
      do IO<Asset.Error>:
        File.close(file)
        IO.die(Asset.Error,1,"Expected native open failure")

def size_error(pair:File & Result<&1,&1,U32 & String,U32>) -> IO(Asset.Error):
  match pair:
    case (file,Fail{(code,message)}):
      do IO<Asset.Error>:
        File.close(file)
        return Asset.Error{code,message}
    case (file,Done{_}):
      do IO<Asset.Error>:
        File.close(file)
        IO.die(Asset.Error,1,"Expected native size failure")

def read_error(pair:File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(Asset.Error):
  match pair:
    case (file,Fail{(code,message)}):
      do IO<Asset.Error>:
        File.close(file)
        return Asset.Error{code,message}
    case (file,Done{_}):
      do IO<Asset.Error>:
        File.close(file)
        IO.die(Asset.Error,1,"Expected native read failure")

def report(label:String,error:Asset.Error) -> IO(Unit):
  Asset.Error{code,message} = error
  IO.print(label ++ " code=" ++ U32.show(code) ++ " message=" ++ message)

def same_error(result:Result<&2,&2,Asset.Error,Content.SourceImage>,wanted:Asset.Error) -> IO(Unit):
  match result wanted:
    case Fail{Asset.Error{code,message}} Asset.Error{c,m}:C.require(U32.is_eq(code,c) && String.eq(message,m),"Native IO code or message changed")
    case _ _:IO.die(Unit,1,"Expected IO failure")

def changed(file:File,+size:U32,+path:String,bytes:List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    C.write(path,bytes)
    result:Result<&2,&2,Asset.Error,Content.SourceImage> <- Png.read_bounded(file,size,U32.is_le(size,2097152))
    Runtime.rejected(result,2147483655,"Real file changed after stat")

def sized(pair:File & Result<&1,&1,U32 & String,U32>,path:String,bytes:List<&2,U32>) -> IO(Unit):
  match pair:
    case (file,Done{size}):changed(file,size,path,bytes)
    case (file,Fail{_}):
      do IO<Unit>:
        File.close(file)
        IO.die(Unit,1,"Cannot stat change probe")

def race(+path:String,+original:List<&2,U32>,replacement:List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    C.write(path,original)
    file:File <- IO.try(File,File.open(path,"r"))
    pair:File & Result<&1,&1,U32 & String,U32> <- File.size(file)
    sized(pair,path,replacement)

def descriptor_count(+pid:String) -> IO(Nat):
  do IO<Nat>:
    +out:String <- C.command("ls",["-1","/proc/" ++ pid ++ "/fd"])
    return List.length(&2,String,String.split(String.trim(out),'\n'))

def repeated(n:Nat,+path:String) -> IO(Unit):
  match n:
    case 0n:IO.pure(Unit,Unit{})
    case 1n+p:
      do IO<Unit>:
        result:Result<&2,&2,Asset.Error,Content.SourceImage> <- Png.load(path)
        Runtime.rejected(result,2147483651,"Oversized file")
        _:Result<&2,&2,Asset.Error,Content.SourceImage> <- Png.load(Corpus.output() ++ "/stored.png")
        _:Result<&2,&2,Asset.Error,Content.SourceImage> <- Png.load(Corpus.output() ++ "/empty.png")
        _:Result<&2,&2,Asset.Error,Content.SourceImage> <- Png.load(Corpus.output() ++ "/absent.png")
        _:Result<&2,&2,Asset.Error,Content.SourceImage> <- Png.load(Corpus.output() ++ "/sparse.png")
        _:Result<&2,&2,Asset.Error,Content.SourceImage> <- Png.load(Corpus.output())
        repeated(p,path)

def main() -> IO(Unit):
  do IO<Unit>:
    +missing:String = Corpus.output() ++ "/absent.png"
    _:String <- C.command("rm",["-f",missing])
    opened:Result<&1,&1,U32 & String,File> <- File.open(missing,"r")
    +error:Asset.Error <- native_error(opened)
    result:Result<&2,&2,Asset.Error,Content.SourceImage> <- Png.load(missing)
    same_error(result,error)
    report("missing",error)
    +sparse:String = Corpus.output() ++ "/sparse.png"
    _:String <- C.command("truncate",["-s","4294967296",sparse])
    file:File <- IO.try(File,File.open(sparse,"r"))
    pair:File & Result<&1,&1,U32 & String,U32> <- File.size(file)
    +error:Asset.Error <- size_error(pair)
    result:Result<&2,&2,Asset.Error,Content.SourceImage> <- Png.load(sparse)
    same_error(result,error)
    report("sparse-size",error)
    file:File <- IO.try(File,File.open(Corpus.output(),"r"))
    pair:File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,1)
    +error:Asset.Error <- read_error(pair)
    result:Result<&2,&2,Asset.Error,Content.SourceImage> <- Png.load(Corpus.output())
    same_error(result,error)
    report("directory-read",error)
    +bytes:List<&2,U32> <- C.read(Corpus.output() ++ "/stored.png")
    race(Corpus.output() ++ "/change.png",bytes,[])
    race(Corpus.output() ++ "/change.png",bytes,List.append(&2,U32,bytes,[42]))
    +status:String <- Address.status()
    +pid:String = Address.field(String.split(status,'\n'),"Pid:")
    +before:Nat <- descriptor_count(pid)
    repeated(64n,Corpus.output() ++ "/input-over-limit.png")
    +after:Nat <- descriptor_count(pid)
    C.require(Nat.is_eq(before,after),"File descriptors leaked on size rejection")
    _:String <- C.command("rm",["-f",sparse])
    IO.print("Native missing-file and >UINT32_MAX errors preserved byte for byte; real shrink/growth rejected; 64 repetitions of six file paths retain descriptor count.")
