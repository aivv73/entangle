import Base
import ./upload-boundary/scan.bend as S

# Linux-only verification boundary. The hard limit is never changed.
type Limit is Data:
  Limit{pid:String,previous:String}

def read_done(pair:File & Result<&1,&1,U32 & String,String>) -> IO(String):
  (file,result) = pair
  do IO<String>:
    File.close(file)
    IO.try(String,IO.pure(Result<&1,&1,U32 & String,String>,result))

def status() -> IO(String):
  do IO<String>:
    file:File <- IO.try(File,File.open("/proc/self/status","r"))
    pair:File & Result<&1,&1,U32 & String,String> <- File.read(file,32768)
    read_done(pair)

def field(lines:List<&2,String>,+prefix:String) -> String:
  match lines:
    case []:""
    case +line <> rest:
      Bool.pick(String,String.starts_with(line,prefix),String.trim(String.drop(line,String.length(prefix))),field(rest,prefix))

def number(found:Maybe<&2,U32>) -> IO(U32):
  match found:
    case Some{n}:IO.pure(U32,n)
    case None{}:IO.die(U32,1,"Missing or invalid process address-space size")

def current(pid:String) -> IO(String):
  do IO<String>:
    value:String <- S.run("prlimit",["--pid",pid,"--as","--raw","--noheadings","--output","SOFT"])
    return String.trim(value)

def set(+pid:String,+value:String) -> IO(Unit):
  do IO<Unit>:
    _:String <- S.run("prlimit",["--pid",pid,"--as=" ++ value ++ ":"])
    actual:String <- current(pid)
    S.require(String.eq(actual,value),"Process address-space limit differs from request")

def lower(request:Nat,previous:Maybe<&2,Nat>) -> Bool:
  match previous:
    case Some{limit}:Nat.is_le(request,limit)
    case None{}:False{}

def restrict(+headroom_kib:U32) -> IO(Limit):
  do IO<Limit>:
    # Warm the subprocess helper before measuring this process's address space.
    _:String <- S.run("prlimit",["--version"])
    +text:String <- status()
    +pid:String = field(String.split(text,'\n'),"Pid:")
    +size:U32 <- number(U32.read(S.next(String.split(field(String.split(text,'\n'),"VmSize:"),' '))))
    +previous:String <- current(pid)
    +bytes:Nat = Nat.mul(Nat.add(U32.to_nat(size),U32.to_nat(headroom_kib)),1024n)
    +limit:String = Nat.show(bytes)
    S.require(String.eq(previous,"unlimited") || lower(bytes,Nat.read(previous)),"Verification must not raise the existing address-space limit")
    IO.print("Allocation pressure: process=" ++ pid ++ " VmSizeKiB=" ++ U32.show(size) ++ " headroomKiB=" ++ U32.show(headroom_kib) ++ " soft-bytes=" ++ limit ++ " previous=" ++ previous)
    set(pid,limit)
    return Limit{pid,previous}

def restore(value:Limit) -> IO(Unit):
  Limit{pid,+previous} = value
  do IO<Unit>:
    set(pid,previous)
    IO.print("Process address-space limit restored: " ++ previous)
