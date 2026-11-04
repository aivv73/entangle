import Base
import ../../src/model-obj.bend as Obj
import ../../src/content.bend as F
import ../../src/asset.bend as Asset
import ./runtime.bend as Runtime
import ./reference.bend as Ref
import ../image-decoder/common.bend as C
import ../image-decoder/files.bend as Files
import ../process-address-limit.bend as Address
import ../image-decoder/replace.bend as Replace
import ./bounds.bend as Bounds

def dest() -> String:"build/model-obj/files"

def loaded(pair:Asset.Cache<F.SourceModel> & Maybe<&2,Asset.State<F.SourceModel>>,wanted:F.SourceModel) -> IO(Asset.Cache<F.SourceModel>):
  match pair:
    case (cache,Some{Asset.Loaded{actual}}):
      do IO<Asset.Cache<F.SourceModel>>:
        C.require(F.same_model(actual,wanted),"Cache source mismatch")
        return cache
    case _:IO.die(Asset.Cache<F.SourceModel>,1,"Expected loaded cache entry")

def absent(pair:Asset.Cache<F.SourceModel> & Maybe<&2,Asset.State<F.SourceModel>>) -> IO(Asset.Cache<F.SourceModel>):
  match pair:
    case (cache,None{}):IO.pure(Asset.Cache<F.SourceModel>,cache)
    case _:IO.die(Asset.Cache<F.SourceModel>,1,"Stale or foreign model handle remained live")

def retained(pair:Asset.Cache<F.SourceModel> & Maybe<&2,Asset.State<F.SourceModel>>) -> IO(Asset.Cache<F.SourceModel> & F.SourceModel):
  match pair:
    case (cache,Some{Asset.Loaded{model}}):IO.pure(Asset.Cache<F.SourceModel> & F.SourceModel,(cache,model))
    case _:IO.die(Asset.Cache<F.SourceModel> & F.SourceModel,1,"Cannot retain model")

def retry(pair:Asset.Cache<F.SourceModel> & Asset.Handle<F.SourceModel>,+old:Asset.Handle<F.SourceModel>,wanted:F.SourceModel) -> IO(Unit):
  (cache,+handle) = pair
  do IO<Unit>:
    cache:Asset.Cache<F.SourceModel> <- Asset.load(F.SourceModel,cache,old,Obj.load)
    cache:Asset.Cache<F.SourceModel> <- absent(Asset.lookup(F.SourceModel,cache,old))
    cache:Asset.Cache<F.SourceModel> <- Asset.load(F.SourceModel,cache,Asset.Handle{"foreign",0n},Obj.load)
    cache:Asset.Cache<F.SourceModel> <- Asset.load(F.SourceModel,cache,handle,Obj.load)
    _:Asset.Cache<F.SourceModel> <- loaded(Asset.lookup(F.SourceModel,cache,handle),wanted)
    IO.print("Fresh request loaded exact dependency content; stale and foreign handles performed no load.")

def changed(pair:Asset.Cache<F.SourceModel> & F.SourceModel,+handle:Asset.Handle<F.SourceModel>,+path:String,+obj:List<&2,U32>,+mtl:List<&2,U32>) -> IO(Unit):
  (cache,+copy) = pair
  do IO<Unit>:
    C.write(path,Obj.text("invalid"))
    C.write(dest() ++ "/sign.mtl",Obj.text("invalid"))
    cache:Asset.Cache<F.SourceModel> <- Asset.load(F.SourceModel,cache,handle,Obj.load)
    cache:Asset.Cache<F.SourceModel> <- loaded(Asset.lookup(F.SourceModel,cache,handle),Ref.sign())
    cache:Asset.Cache<F.SourceModel> = Asset.release(F.SourceModel,cache,handle)
    cache:Asset.Cache<F.SourceModel> <- absent(Asset.lookup(F.SourceModel,cache,handle))
    C.require(F.same_model(copy,Ref.sign()),"Retained source changed after cache release and file edits")
    C.write(path,obj)
    C.write(dest() ++ "/sign.mtl",Obj.text(Replace.all(Obj.string(mtl),"Kd 1 0 0","Kd 0 0 1")))
    retry(Asset.request(F.SourceModel,cache,path),handle,Ref.blue_sign())
    C.write(dest() ++ "/sign.mtl",mtl)
    IO.print("Cached success skipped invalid changed files; full retained source survived release; fresh load observed red-to-blue dependency edit.")

def success(pair:Asset.Cache<F.SourceModel> & Asset.Handle<F.SourceModel>,+path:String,+obj:List<&2,U32>,mtl:List<&2,U32>) -> IO(Unit):
  (cache,+handle) = pair
  do IO<Unit>:
    cache:Asset.Cache<F.SourceModel> <- Asset.load(F.SourceModel,cache,handle,Obj.load)
    pair:Asset.Cache<F.SourceModel> & F.SourceModel <- retained(Asset.lookup(F.SourceModel,cache,handle))
    changed(pair,handle,path,obj,mtl)

def same_failure(pair:Asset.Cache<F.SourceModel> & Maybe<&2,Asset.State<F.SourceModel>>,error:Asset.Error) -> IO(Asset.Cache<F.SourceModel>):
  match pair error:
    case (cache,Some{Asset.Failed{Asset.Error{a,b}}}),Asset.Error{c,d}:
      do IO<Asset.Cache<F.SourceModel>>:
        C.require(U32.is_eq(a,c) && String.eq(b,d),"Cached error changed")
        return cache
    case _,_:IO.die(Asset.Cache<F.SourceModel>,1,"Failure cache reread dependency")

def failure_cached(pair:Asset.Cache<F.SourceModel> & Maybe<&2,Asset.State<F.SourceModel>>,+handle:Asset.Handle<F.SourceModel>,+path:String,mtl:List<&2,U32>) -> IO(Unit):
  match pair:
    case (cache,Some{Asset.Failed{+error}}):
      do IO<Unit>:
        C.write(dest() ++ "/sign.mtl",mtl)
        cache:Asset.Cache<F.SourceModel> <- Asset.load(F.SourceModel,cache,handle,Obj.load)
        cache:Asset.Cache<F.SourceModel> <- same_failure(Asset.lookup(F.SourceModel,cache,handle),error)
        retry(Asset.request(F.SourceModel,Asset.release(F.SourceModel,cache,handle),path),handle,Ref.sign())
        IO.print("Missing dependency failure remained cached after creation; whole-model retry recovered.")
    case _:IO.die(Unit,1,"Missing declared dependency did not fail")

def failure(pair:Asset.Cache<F.SourceModel> & Asset.Handle<F.SourceModel>,path:String,mtl:List<&2,U32>) -> IO(Unit):
  (cache,+handle) = pair
  do IO<Unit>:
    cache:Asset.Cache<F.SourceModel> <- Asset.load(F.SourceModel,cache,handle,Obj.load)
    failure_cached(Asset.lookup(F.SourceModel,cache,handle),handle,path,mtl)

def changed_read(result:Result<&2,&2,Asset.Error,List<&2,U32>>) -> IO(Unit):
  match result:
    case Fail{Asset.Error{code,_}}:C.require(U32.is_eq(code,2147483912),"Wrong changing-file classification")
    case Done{_}:IO.die(Unit,1,"Changing file was accepted")

def race_sized(pair:File & Result<&1,&1,U32 & String,U32>,+path:String,replacement:List<&2,U32>) -> IO(Unit):
  match pair:
    case (file,Done{+size}):
      do IO<Unit>:
        C.write(path,replacement)
        result:Result<&2,&2,Asset.Error,List<&2,U32>> <- Obj.read_bounded(file,size,path,True{})
        changed_read(result)
    case (file,Fail{_}):
      do IO<Unit>:
        File.close(file)
        IO.die(Unit,1,"Cannot stat race input")

def race(+original:List<&2,U32>,replacement:List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    +path:String = dest() ++ "/race"
    C.write(path,original)
    file:File <- IO.try(File,File.open(path,"r"))
    pair:File & Result<&1,&1,U32 & String,U32> <- File.size(file)
    race_sized(pair,path,replacement)

def repeated(n:Nat,+path:String) -> IO(Unit):
  match n:
    case 0n:IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        good:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(path)
        Runtime.accepted(good,Ref.sign(),"repeated loaded sources")
        _:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(dest() ++ "/missing")
        _:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(dest() ++ "/bad")
        _:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(dest())
        _:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(dest() ++ "/large")
        repeated(rest,path)

def native_same(result:Result<&2,&2,Asset.Error,F.SourceModel>,path:String,error:Asset.Error) -> IO(Unit):
  match result error:
    case Fail{Asset.Error{a,b}},Asset.Error{c,d}:C.require(U32.is_eq(a,c) && String.eq(b,path ++ ": " ++ d),"Native errno or diagnostic changed")
    case _,_:IO.die(Unit,1,"Expected native IO error")

def native_errors() -> IO(Unit):
  do IO<Unit>:
    +missing:String = dest() ++ "/missing"
    opened:Result<&1,&1,U32 & String,File> <- File.open(missing,"r")
    expected:Asset.Error <- Files.native_error(opened)
    result:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(missing)
    native_same(result,missing,expected)
    +sparse:String = dest() ++ "/sparse"
    _:String <- C.command("truncate",["-s","4294967296",sparse])
    file:File <- IO.try(File,File.open(sparse,"r"))
    sized:File & Result<&1,&1,U32 & String,U32> <- File.size(file)
    expected:Asset.Error <- Files.size_error(sized)
    result:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(sparse)
    native_same(result,sparse,expected)
    file:File <- IO.try(File,File.open(dest(),"r"))
    pair:File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,1)
    expected:Asset.Error <- Files.read_error(pair)
    result:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(dest())
    native_same(result,dest(),expected)
    _:String <- C.command("rm",["--",sparse])
    IO.print("Native missing-file, >UINT32_MAX stat and directory-read codes/messages preserved with path context.")

def path_at_bound(result:Result<&2,&2,Asset.Error,F.SourceModel>) -> IO(Unit):
  match result:
    case Fail{Asset.Error{code,_}}:C.require(U32.is_lt(code,2147483648),"4096-byte root path failed adapter policy rather than native filesystem")
    case Done{_}:IO.die(Unit,1,"Unexpected 4096-byte existing path")

def file_bounds(+obj:List<&2,U32>,+mtl:List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    +path:String = dest() ++ "/bound"
    C.write(path,Obj.text(Bounds.exact_bytes(Obj.string(obj),Obj.obj_limit())))
    result:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(path)
    Runtime.accepted(result,Ref.sign(),"real OBJ at byte limit")
    C.write(path,Obj.text(Bounds.exact_bytes(Obj.string(obj),Obj.obj_limit()) ++ "x"))
    result:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(path)
    Runtime.rejected(result,7,"real OBJ over byte limit")
    C.write(path,obj)
    C.write(dest() ++ "/sign.mtl",Obj.text(Bounds.exact_bytes(Obj.string(mtl),Obj.mtl_limit())))
    result:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(path)
    Runtime.accepted(result,Ref.sign(),"real MTL at byte limit")
    C.write(dest() ++ "/sign.mtl",Obj.text(Bounds.exact_bytes(Obj.string(mtl),Obj.mtl_limit()) ++ "x"))
    result:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(path)
    Runtime.rejected(result,7,"real MTL over byte limit")
    C.write(dest() ++ "/sign.mtl",mtl)
    C.write(path,Obj.text("mtllib " ++ String.repeat("x",4080n) ++ "\n" ++ Runtime.obj()))
    result:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(path)
    Runtime.rejected(result,6,"joined dependency path over limit")
    result:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(String.repeat("x",4096n))
    path_at_bound(result)

def main() -> IO(Unit):
  do IO<Unit>:
    _:String <- C.command("mkdir",["-p",dest()])
    +obj:List<&2,U32> <- C.read("docs/verification/2026-11-04-model-obj/corpus/sign.obj")
    +mtl:List<&2,U32> <- C.read("docs/verification/2026-11-04-model-obj/corpus/sign.mtl")
    +path:String = dest() ++ "/" ++ String.from_list([Char.from_u32(1079),Char.from_u32(1085),Char.from_u32(1072),Char.from_u32(1082)])
    C.write(path,obj)
    C.write(dest() ++ "/sign.mtl",mtl)
    success(Asset.request(F.SourceModel,Asset.new(F.SourceModel,"model-files"),path),path,obj,mtl)
    _:String <- C.command("rm",["--",dest() ++ "/sign.mtl"])
    failure(Asset.request(F.SourceModel,Asset.new(F.SourceModel,"model-failure"),path),path,mtl)
    race(obj,[])
    race(obj,List.append(&2,U32,obj,[10]))
    file_bounds(obj,mtl)
    native_errors()
    C.write(dest() ++ "/bad",Obj.text("mtllib missing\n" ++ Runtime.obj()))
    C.write(dest() ++ "/large",Obj.text(String.repeat("x",2097153n)))
    +status:String <- Address.status()
    +pid:String = Address.field(String.split(status,'\n'),"Pid:")
    +before:Nat <- Files.descriptor_count(pid)
    repeated(64n,path)
    +after:Nat <- Files.descriptor_count(pid)
    C.require(Nat.is_eq(before,after),"Model IO leaked descriptors")
    IO.print("Unicode root without extension loaded; real shrink/growth rejected; 64 repetitions of success/missing dependency/missing root/directory/over-limit paths kept descriptor count.")
