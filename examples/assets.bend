import Base
import ../src/asset.bend as Asset

# A bounded regular-file loader. Decoding and path policy belong to the caller.
def exact(bytes:List<&2,U32>,complete:Bool) -> Result<&2,&2,Asset.Error,List<&2,U32>>:
  match complete:
    case True{}:Done{bytes}
    case False{}:Fail{Asset.Error{1,"File size changed or read was incomplete"}}

def read_result(result:Result<&1,&1,U32 & String,List<&2,U32>>,size:U32) -> Result<&2,&2,Asset.Error,List<&2,U32>>:
  match result:
    case Fail{(code,message)}:Fail{Asset.Error{code,message}}
    case Done{+bytes}:exact(bytes,Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(size)))

def read_closed(pair:File & Result<&1,&1,U32 & String,List<&2,U32>>,size:U32) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  (file,result) = pair
  do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
    File.close(file)
    return read_result(result,size)

def read_bounded(file:File,+size:U32,fits:Bool) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  match fits:
    case False{}:
      do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
        File.close(file)
        return Fail{Asset.Error{1,"Asset exceeds 1 MiB"}}
    case True{}:
      do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
        pair:File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,U32.inc(size))
        read_closed(pair,size)

def read_sized(pair:File & Result<&1,&1,U32 & String,U32>) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  match pair:
    case (file,Fail{(code,message)}):
      do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
        File.close(file)
        return Fail{Asset.Error{code,message}}
    case (file,Done{+size}):read_bounded(file,size,U32.is_le(size,1048576))

def read_opened(result:Result<&1,&1,U32 & String,File>) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  match result:
    case Fail{(code,message)}:IO.pure(Result<&2,&2,Asset.Error,List<&2,U32>>,Fail{Asset.Error{code,message}})
    case Done{file}:
      do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
        pair:File & Result<&1,&1,U32 & String,U32> <- File.size(file)
        read_sized(pair)

def read_file(path:String) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
    result:Result<&1,&1,U32 & String,File> <- File.open(path,"r")
    read_opened(result)

def describe(state:Maybe<&2,Asset.State<List<&2,U32>>>) -> String:
  match state:
    case None{}:"Missing"
    case Some{Asset.Loading{}}:"Loading"
    case Some{Asset.Loaded{bytes}}:"Loaded " ++ Nat.show(List.length(&2,U32,bytes)) ++ " bytes"
    case Some{Asset.Failed{Asset.Error{code,message}}}:"Failed " ++ U32.show(code) ++ ": " ++ message

def report(pair:Asset.Cache<List<&2,U32>> & Maybe<&2,Asset.State<List<&2,U32>>>) -> IO(Asset.Cache<List<&2,U32>>):
  (cache,state) = pair
  do IO<Asset.Cache<List<&2,U32>>>:
    IO.print(describe(state))
    return cache

def run_requested(pair:Asset.Cache<List<&2,U32>> & Asset.Handle<List<&2,U32>>) -> IO(Unit):
  (cache,+handle) = pair
  do IO<Unit>:
    cache:Asset.Cache<List<&2,U32>> <- report(Asset.lookup(List<&2,U32>,cache,handle))
    cache:Asset.Cache<List<&2,U32>> <- Asset.load(List<&2,U32>,cache,handle,read_file)
    cache:Asset.Cache<List<&2,U32>> <- report(Asset.lookup(List<&2,U32>,cache,handle))
    cache:Asset.Cache<List<&2,U32>> = Asset.release(List<&2,U32>,cache,handle)
    _:Asset.Cache<List<&2,U32>> <- report(Asset.lookup(List<&2,U32>,cache,handle))
    return Unit{}

def run(path:String) -> IO(Unit):
  run_requested(Asset.request(List<&2,U32>,Asset.new(List<&2,U32>,"file-example"),path))

def args(values:List<String>) -> IO(Unit):
  match values:
    case _ <> path <> _:run(path)
    case _:run("README.md")

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<String> <- IO.args()
    args(values)
