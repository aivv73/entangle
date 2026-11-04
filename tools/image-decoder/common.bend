import Base

def require(ok:Bool,message:String) -> IO(Unit):
  match ok:
    case True{}:IO.pure(Unit,Unit{})
    case False{}:IO.die(Unit,1,message)

def result(value:U32 & (String & String)) -> IO(String):
  (code,pair) = value
  (out,err) = pair
  +out:String = out
  +err:String = err
  do IO<String>:
    require(U32.is_zero(code),out ++ err)
    return out

def command(program:String,args:List<String>) -> IO(String):
  do IO<String>:
    value:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(program,args,"",16777216,300000))
    result(value)

def closed(pair:File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(List<&2,U32>):
  (file,result) = pair
  do IO<List<&2,U32>>:
    File.close(file)
    IO.try(List<&2,U32>,IO.pure(Result<&1,&1,U32 & String,List<&2,U32>>,result))

def read(path:String) -> IO(List<&2,U32>):
  do IO<List<&2,U32>>:
    file:File <- IO.try(File,File.open(path,"r"))
    pair:File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,16777217)
    closed(pair)

def written(pair:File & Result<&1,&1,U32 & String,Unit>) -> IO(Unit):
  (file,result) = pair
  do IO<Unit>:
    File.close(file)
    IO.try(Unit,IO.pure(Result<&1,&1,U32 & String,Unit>,result))

def write(path:String,bytes:List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    file:File <- IO.try(File,File.open(path,"w"))
    pair:File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    written(pair)

def array_words(array:Array<U32>,tail:List<&2,U32>) -> List<&2,U32>:
  match array:
    case ALeaf{value}:value <> tail
    case ANode{left,right}:array_words(left,array_words(right,tail))

def rgba(r:U32,g:U32,b:U32,a:U32) -> U32:
  ((r << 24n) .|. (g << 16n) .|. (b << 8n) .|. a : U32)

def reference(bytes:List<&2,U32>) -> List<&2,U32>:
  match bytes:
    case r <> g <> b <> a <> rest:rgba(r,g,b,a) <> reference(rest)
    case _:[]

def probe_input(path:String,+bytes:List<&2,U32>) -> List<&2,U32>:
  Bool.pick(List<&2,U32>,String.ends_with(path,"/bad-byte.png"),List.set(&2,U32,bytes,17n,256),bytes)

def high_bytes(bytes:List<&2,U32>) -> List<&2,U32>:
  match bytes:
    case high <> _ <> rest:high <> high_bytes(rest)
    case _:[]

def equal(a:List<&2,U32>,b:List<&2,U32>) -> Bool:
  match a b:
    case [], []:True{}
    case x <> xs y <> ys:U32.is_eq(x,y) && equal(xs,ys)
    case _ _:False{}

def number(value:String) -> U32:
  Maybe.default(&2,U32,U32.read(value),0)

def checked(+w:U32,+h:U32,pixels:List<&2,U32>,+width:U32,+height:U32,+expected:List<&2,U32>) -> String:
  +ok = U32.is_eq(w,width) && U32.is_eq(h,height) && Nat.is_eq(List.length(&2,U32,expected),Nat.mul(U32.to_nat(w),U32.to_nat(h))) && equal(pixels,expected)
  Bool.pick(String,ok,"exact","MISMATCH") ++ " " ++ U32.show(w) ++ "x" ++ U32.show(h) ++ " pixels=" ++ Nat.show(List.length(&2,U32,expected))
