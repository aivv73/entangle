import Base
import 0x37aacddc1dcb57464b8b5ac6c397bd64/json.bend as J
import 0x632652e3c1c0183f12728faf3870bb68/bytes.bend as B
import ./asset.bend as Asset
import ./content.bend as F

def byte_limit() -> Nat:65536n
def depth_limit() -> U32:8

def error(code:U32,path:String,reason:String) -> Asset.Error:
  Asset.Error{U32.add(2147484160,code),path ++ ": " ++ reason}

def need(ok:Bool,code:U32,path:String,reason:String) -> Result<&2,&1,Asset.Error,Unit>:
  match ok:
    case True{}:Done{Unit{}}
    case False{}:Fail{error(code,path,reason)}

def data(-A:Data,result:Result<&2,&1,Asset.Error,A>) -> Result<&2,&2,Asset.Error,A>:
  match result:
    case Fail{e}:Fail{e}
    case Done{value}:Done{value}

def owned(-A:Data,result:Result<&2,&2,Asset.Error,A>) -> Result<&2,&1,Asset.Error,A>:
  match result:
    case Fail{e}:Fail{e}
    case Done{value}:Done{value}

def octets(bytes:List<&2,U32>) -> Bool:
  match bytes:
    case []:True{}
    case b <> rest:U32.is_le(b,255) && octets(rest)

def string(bytes:List<&2,U32>) -> String:
  match bytes:
    case []:""
    case b <> rest:SCon{Char.from_u32(b),string(rest)}

def parsed(value:Maybe<&1,J.Val>,path:String) -> Result<&2,&1,Asset.Error,J.Val>:
  match value:
    case None{}:Fail{error(1,path,"invalid UTF-8 JSON, duplicate decoded key, or nesting exceeds 8")}
    case Some{value}:Done{value}

def parse(+bytes:List<&2,U32>,+path:String) -> Result<&2,&1,Asset.Error,J.Val>:
  do Result<&2,&1,Asset.Error,J.Val>:
    _:Unit <- need(Nat.is_le(List.length(&2,U32,bytes),byte_limit()),2,path,"JSON exceeds 65536 bytes")
    _:Unit <- need(octets(bytes),1,path,"input contains a non-byte word")
    parsed(J.parse.strict.unique.bytes(B.from_string(string(bytes)),depth_limit()),path)

def fields(v:J.Val,path:String) -> Result<&2,&1,Asset.Error,List<&1,B.Bytes & J.Val>>:
  match v:
    case J.Obj{pairs}:Done{pairs}
    case _:Fail{error(3,path,"expected object")}

def pull_step(same:Bool,key:B.Bytes,value:J.Val,tail:Maybe<&1,J.Val> & List<&1,B.Bytes & J.Val>) -> Maybe<&1,J.Val> & List<&1,B.Bytes & J.Val>:
  match same:
    case True{}:
      (_,rest) = tail
      (Some{value},rest)
    case False{}:
      (found,rest) = tail
      (found,(key,value) <> rest)

def pull(pairs:List<&1,B.Bytes & J.Val>,+name:String) -> Maybe<&1,J.Val> & List<&1,B.Bytes & J.Val>:
  match pairs:
    case []:(None{},[])
    case (key,value) <> rest:
      +key = B.to_string(key)
      pull_step(String.eq(key,name),B.from_string(key),value,pull(rest,name))

def required(pair:Maybe<&1,J.Val> & List<&1,B.Bytes & J.Val>,name:String,path:String) -> Result<&2,&1,Asset.Error,J.Val & List<&1,B.Bytes & J.Val>>:
  match pair:
    case (None{},_):Fail{error(3,path,"missing field " ++ name)}
    case (Some{value},rest):Done{(value,rest)}

def take(pairs:List<&1,B.Bytes & J.Val>,+name:String,path:String) -> Result<&2,&1,Asset.Error,J.Val & List<&1,B.Bytes & J.Val>>:
  required(pull(pairs,name),name,path)

def end(pairs:List<&1,B.Bytes & J.Val>,path:String) -> Result<&2,&1,Asset.Error,Unit>:
  match pairs:
    case []:Done{Unit{}}
    case (key,_) <> _:Fail{error(3,path,"unknown field " ++ B.to_string(key))}

def array(v:J.Val,path:String) -> Result<&2,&1,Asset.Error,List<&1,J.Val>>:
  match v:
    case J.Arr{xs}:Done{xs}
    case _:Fail{error(3,path,"expected array")}

def text(v:J.Val,+path:String) -> Result<&2,&1,Asset.Error,String>:
  match v:
    case J.Str{s}:
      +s = B.to_string(s)
      do Result<&2,&1,Asset.Error,String>:
        _:Unit <- need(Nat.is_le(String.length(s),255n),2,path,"string exceeds 255 UTF-8 bytes")
        return s
    case _:Fail{error(3,path,"expected string")}

def version(v:J.Val,+path:String) -> Result<&2,&1,Asset.Error,Unit>:
  match v:
    case J.Num{s}:need(String.eq(B.to_string(s),"1"),3,path,"version must be integer 1")
    case _:Fail{error(3,path,"version must be integer 1")}

def finite(value:Maybe<&2,F32>,+path:String) -> Result<&2,&1,Asset.Error,F32>:
  match value:
    case None{}:Fail{error(4,path,"number cannot be converted to F32")}
    case Some{+v}:
      do Result<&2,&1,Asset.Error,F32>:
        _:Unit <- need(F.finite(v) && F32.is_ge(v,F32.neg(1000000.0)) && F32.is_le(v,1000000.0),4,path,"number must be finite in [-1000000,1000000]")
        return v

def number(v:J.Val,+path:String) -> Result<&2,&1,Asset.Error,F32>:
  match v:
    case J.Num{s}:
      +s = B.to_string(s)
      do Result<&2,&1,Asset.Error,F32>:
        _:Unit <- need(Nat.is_le(String.length(s),64n),2,path,"number exceeds 64 bytes")
        finite(F32.read(s),path)
    case _:Fail{error(3,path,"expected number")}

def exact(result:Result<&1,&1,U32 & String,List<&2,U32>>,size:U32,+path:String) -> Result<&2,&2,Asset.Error,List<&2,U32>>:
  match result:
    case Fail{(code,message)}:Fail{Asset.Error{code,path ++ ": " ++ message}}
    case Done{+bytes}:
      do Result<&2,&2,Asset.Error,List<&2,U32>>:
        _:Unit <- data(Unit,need(Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(size)),6,path,"file changed or read incomplete"))
        return bytes

def read_closed(pair:File & Result<&1,&1,U32 & String,List<&2,U32>>,size:U32,path:String) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  (file,result) = pair
  do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
    File.close(file)
    return exact(result,size,path)

def read_bounded(fits:Bool,file:File,+size:U32,+path:String) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  match fits:
    case False{}:
      do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
        File.close(file)
        return Fail{error(2,path,"JSON exceeds 65536 bytes")}
    case True{}:
      do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
        pair:File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,U32.inc(size))
        read_closed(pair,size,path)

def read_sized(pair:File & Result<&1,&1,U32 & String,U32>,+path:String) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  match pair:
    case (file,Fail{(code,message)}):
      do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
        File.close(file)
        return Fail{Asset.Error{code,path ++ ": " ++ message}}
    case (file,Done{+size}):read_bounded(Nat.is_le(U32.to_nat(size),byte_limit()),file,size,path)

def opened(result:Result<&1,&1,U32 & String,File>,+path:String) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  match result:
    case Fail{(code,message)}:IO.pure(Result<&2,&2,Asset.Error,List<&2,U32>>,Fail{Asset.Error{code,path ++ ": " ++ message}})
    case Done{file}:
      do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
        pair:File & Result<&1,&1,U32 & String,U32> <- File.size(file)
        read_sized(pair,path)

def read(+path:String) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
    result:Result<&1,&1,U32 & String,File> <- File.open(path,"r")
    opened(result,path)

def pair(-A:Type,-B:Type,-C:Type,value:A & B,next:A -> B -> C) -> C:
  (a,b) = value
  next(a)(b)

def ordered(names:List<&2,String>,pairs:List<&1,B.Bytes & J.Val>,+path:String) -> Result<&2,&1,Asset.Error,List<&1,J.Val>>:
  match names:
    case []:
      do Result<&2,&1,Asset.Error,List<&1,J.Val>>:
        _:Unit <- end(pairs,path)
        return []
    case name <> rest:
      do Result<&2,&1,Asset.Error,List<&1,J.Val>>:
        field:J.Val & List<&1,B.Bytes & J.Val> <- take(pairs,name,path)
        pair(J.Val,List<&1,B.Bytes & J.Val>,Result<&2,&1,Asset.Error,List<&1,J.Val>>,field,value => fields =>
          Result.bind(&2,&1,Asset.Error,List<&1,J.Val>,List<&1,J.Val>,ordered(rest,fields,path),tail => Done{value <> tail}))

def schema(v:J.Val,names:List<&2,String>,+path:String) -> Result<&2,&1,Asset.Error,List<&1,J.Val>>:
  do Result<&2,&1,Asset.Error,List<&1,J.Val>>:
    pairs:List<&1,B.Bytes & J.Val> <- fields(v,path)
    ordered(names,pairs,path)
