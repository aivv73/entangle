import Base
import ../src/asset.bend as Asset
import ../examples/assets.bend as Files
import ../examples/asset-scene.bend as Scene
import ../examples/content-assets.bend as Content
import ../src/content.bend as F

def Bytes() -> Data:List<&2,U32>

def require(ok:Bool,message:String) -> IO(Unit):
  match ok:
    case True{}:IO.pure(Unit,Unit{})
    case False{}:IO.die(Unit,1,message)

def bytes_equal(a:Bytes(),b:Bytes()) -> Bool:
  match a b:
    case [], []:True{}
    case x <> xs, y <> ys:U32.is_eq(x,y) && bytes_equal(xs,ys)
    case _, _:False{}

def states_equal(a:Maybe<&2,Asset.State<Bytes()>>,b:Maybe<&2,Asset.State<Bytes()>>) -> Bool:
  match a b:
    case None{} None{}:True{}
    case Some{Asset.Loading{}} Some{Asset.Loading{}}:True{}
    case Some{Asset.Loaded{xs}} Some{Asset.Loaded{ys}}:bytes_equal(xs,ys)
    case Some{Asset.Failed{Asset.Error{c,m}}} Some{Asset.Failed{Asset.Error{d,n}}}:U32.is_eq(c,d) && String.eq(m,n)
    case _ _:False{}

def same_handle(a:Asset.Handle<Bytes()>,b:Asset.Handle<Bytes()>) -> Bool:
  Asset.Handle{scope,id} = a
  Asset.Handle{other,serial} = b
  String.eq(scope,other) && Nat.is_eq(id,serial)

def expect(pair:Asset.Cache<Bytes()> & Maybe<&2,Asset.State<Bytes()>>,wanted:Maybe<&2,Asset.State<Bytes()>>) -> IO(Asset.Cache<Bytes()>):
  (cache,actual) = pair
  do IO<Asset.Cache<Bytes()>>:
    require(states_equal(actual,wanted),"Asset state differs")
    return cache

def shared(pair:Asset.Cache<Bytes()> & Asset.Handle<Bytes()>,wanted:Asset.Handle<Bytes()>) -> IO(Asset.Cache<Bytes()>):
  (cache,actual) = pair
  do IO<Asset.Cache<Bytes()>>:
    require(same_handle(actual,wanted),"Repeated request changed identity")
    return cache

def written(pair:File & Result<&1,&1,U32 & String,Unit>) -> IO(Unit):
  (file,result) = pair
  do IO<Unit>:
    File.close(file)
    IO.try(Unit,IO.pure(Result<&1,&1,U32 & String,Unit>,result))

def write(path:String,mode:String,text:String) -> IO(Unit):
  do IO<Unit>:
    file:File <- IO.try(File,File.open(path,mode))
    pair:File & Result<&1,&1,U32 & String,Unit> <- File.write(file,text)
    written(pair)

# Each actual loader invocation appends one byte, then performs real file IO.
def tracked(path:String) -> IO(Result<&2,&2,Asset.Error,Bytes()>):
  +path = path
  do IO<Result<&2,&2,Asset.Error,Bytes()>>:
    write(path ++ ".reads","a","x")
    Files.read_file(path)

def counted(result:Result<&2,&2,Asset.Error,Bytes()>,count:Nat) -> IO(Unit):
  match result:
    case Done{bytes}:require(Nat.is_eq(List.length(&2,U32,bytes),count),"Unexpected loader invocation count")
    case Fail{_}:IO.die(Unit,1,"Missing loader evidence")

def reads(path:String,count:Nat) -> IO(Unit):
  do IO<Unit>:
    result:Result<&2,&2,Asset.Error,Bytes()> <- Files.read_file(path ++ ".reads")
    counted(result,count)

def recovered(pair:Asset.Cache<Bytes()> & Asset.Handle<Bytes()>,+old:Asset.Handle<Bytes()>,+good:Asset.Handle<Bytes()>,+path:String) -> IO(Unit):
  (cache,+handle) = pair
  do IO<Unit>:
    require(Bool.not(same_handle(old,handle)),"Failed asset identity revived")
    cache:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,old),None{})
    cache:Asset.Cache<Bytes()> <- Asset.load(Bytes(),cache,old,tracked)
    cache:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,handle),Some{Asset.Loading{}})
    cache:Asset.Cache<Bytes()> <- Asset.load(Bytes(),cache,handle,tracked)
    cache:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,handle),Some{Asset.Loaded{[67]}})
    cache:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,good),Some{Asset.Loaded{[66]}})
    cache:Asset.Cache<Bytes()> = Asset.release(Bytes(),Asset.release(Bytes(),cache,handle),good)
    cache:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,good),None{})
    _:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,handle),None{})
    reads(path,2n)
    IO.print("Failed load cached; explicit retry recovered; unrelated asset preserved.")

def failed(pair:Asset.Cache<Bytes()> & Maybe<&2,Asset.State<Bytes()>>,+handle:Asset.Handle<Bytes()>,good:Asset.Handle<Bytes()>,+path:String) -> IO(Unit):
  match pair:
    case (cache,Some{Asset.Failed{+error}}):
      do IO<Unit>:
        write(path,"w","C")
        cache:Asset.Cache<Bytes()> <- shared(Asset.request(Bytes(),cache,path),handle)
        cache:Asset.Cache<Bytes()> <- Asset.load(Bytes(),cache,handle,tracked)
        cache:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,handle),Some{Asset.Failed{error}})
        reads(path,1n)
        recovered(Asset.request(Bytes(),Asset.release(Bytes(),cache,handle),path),handle,good,path)
    case _:IO.die(Unit,1,"Missing file did not become Failed")

def failure_requested(pair:Asset.Cache<Bytes()> & Asset.Handle<Bytes()>,good:Asset.Handle<Bytes()>,path:String) -> IO(Unit):
  (cache,+handle) = pair
  do IO<Unit>:
    cache:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,handle),Some{Asset.Loading{}})
    cache:Asset.Cache<Bytes()> <- Asset.load(Bytes(),cache,handle,tracked)
    failed(Asset.lookup(Bytes(),cache,handle),handle,good,path)

def isolated(pair:Asset.Cache<Bytes()> & Asset.Handle<Bytes()>,+foreign:Asset.Handle<Bytes()>,path:String) -> IO(Unit):
  (cache,+local) = pair
  do IO<Unit>:
    cache:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,foreign),None{})
    cache:Asset.Cache<Bytes()> = Asset.release(Bytes(),cache,foreign)
    cache:Asset.Cache<Bytes()> <- Asset.load(Bytes(),cache,foreign,tracked)
    cache:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,local),Some{Asset.Loading{}})
    cache:Asset.Cache<Bytes()> = Asset.release(Bytes(),cache,local)
    cache:Asset.Cache<Bytes()> <- Asset.load(Bytes(),cache,local,tracked)
    _:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,local),None{})
    reads(path,1n)
    IO.print("Wrong scope rejected; released Loading entry performs no IO.")

def reloaded(pair:Asset.Cache<Bytes()> & Asset.Handle<Bytes()>,+old:Asset.Handle<Bytes()>,+path:String) -> IO(Unit):
  (cache,+handle) = pair
  do IO<Unit>:
    require(Bool.not(same_handle(old,handle)),"Released asset identity revived")
    cache:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,old),None{})
    cache:Asset.Cache<Bytes()> <- Asset.load(Bytes(),cache,old,tracked)
    cache:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,handle),Some{Asset.Loading{}})
    cache:Asset.Cache<Bytes()> <- Asset.load(Bytes(),cache,handle,tracked)
    cache:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,handle),Some{Asset.Loaded{[66]}})
    reads(path,2n)
    IO.print("Loaded data cached; release is idempotent; reacquisition has fresh identity.")
    failure_requested(Asset.request(Bytes(),cache,path ++ ".missing"),handle,path ++ ".missing")

def loaded(pair:Asset.Cache<Bytes()> & Asset.Handle<Bytes()>,+path:String) -> IO(Unit):
  (cache,+handle) = pair
  do IO<Unit>:
    cache:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,handle),Some{Asset.Loading{}})
    cache:Asset.Cache<Bytes()> <- shared(Asset.request(Bytes(),cache,path),handle)
    cache:Asset.Cache<Bytes()> <- Asset.load(Bytes(),cache,handle,tracked)
    cache:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,handle),Some{Asset.Loaded{[65]}})
    write(path,"w","B")
    cache:Asset.Cache<Bytes()> <- shared(Asset.request(Bytes(),cache,path),handle)
    cache:Asset.Cache<Bytes()> <- Asset.load(Bytes(),cache,handle,tracked)
    cache:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,handle),Some{Asset.Loaded{[65]}})
    reads(path,1n)
    isolated(Asset.request(Bytes(),Asset.new(Bytes(),"other-scope"),path),handle,path)
    cache:Asset.Cache<Bytes()> = Asset.release(Bytes(),Asset.release(Bytes(),cache,handle),handle)
    cache:Asset.Cache<Bytes()> <- expect(Asset.lookup(Bytes(),cache,handle),None{})
    reloaded(Asset.request(Bytes(),cache,path),handle,path)

def directory(result:U32 & (String & String)) -> IO(String):
  (code,(out,err)) = result
  do IO<String>:
    require(U32.is_zero(code),err)
    return String.trim(out)

def size_accepted(result:Result<&2,&2,Asset.Error,Bytes()>,size:Nat) -> IO(Unit):
  match result:
    case Done{bytes}:require(Nat.is_eq(List.length(&2,U32,bytes),size),"File loader changed the byte count")
    case Fail{_}:IO.die(Unit,1,"File within the byte limit was refused")

def size_rejected(result:Result<&2,&2,Asset.Error,Bytes()>) -> IO(Unit):
  match result:
    case Fail{Asset.Error{code,message}}:require(U32.is_eq(code,1) && String.eq(message,"Asset exceeds 1 MiB"),"Wrong size-limit error")
    case Done{_}:IO.die(Unit,1,"Oversized file was accepted")

def limits(+path:String) -> IO(Unit):
  do IO<Unit>:
    write(path,"w","")
    empty:Result<&2,&2,Asset.Error,Bytes()> <- Files.read_file(path)
    size_accepted(empty,0n)
    write(path,"w",String.repeat("x",1048576n))
    full:Result<&2,&2,Asset.Error,Bytes()> <- Files.read_file(path)
    size_accepted(full,1048576n)
    write(path,"a","x")
    large:Result<&2,&2,Asset.Error,Bytes()> <- Files.read_file(path)
    size_rejected(large)
    IO.print("Real file byte limit verified at zero, exactly 1 MiB, and one byte over.")

def retained_sources(result:Result<&2,&1,Asset.Error,F.Mesh & F.Material>) -> IO(Unit):
  match result:
    case Fail{_}:IO.die(Unit,1,"Procedural source cache failed")
    case Done{(+mesh,+material)}:
      require(F.mesh_valid(mesh) && F.material_valid(material) && F.same_mesh(mesh,Content.triangle()) && F.same_material(material,Content.red()),"Released cache changed retained mesh or material")

def command_result(result:U32 & (String & String)) -> IO(Unit):
  (code,pair) = result
  (out,err) = pair
  +out:String = out
  +err:String = err
  do IO<Unit>:
    require(U32.is_zero(code),out ++ err)
    IO.write(out)
    IO.write(err)

def command(program:String,args:List<String>) -> IO(Unit):
  do IO<Unit>:
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(program,args,"",1048576,300000))
    command_result(result)

# Compilation with only this inventory proves the source dependency boundary.
def source_only(+dest:String) -> IO(Unit):
  do IO<Unit>:
    command("mkdir",["-p",dest])
    command("cp",["--parents","examples/content-assets.bend","src/content.bend","src/components.bend","src/asset.bend",dest])
    command("bend",[dest ++ "/examples/content-assets.bend","-o",dest ++ "/content-assets"])
    command(dest ++ "/content-assets",["+RTS","--threads","1","--gpu","off"])
    result:Result<&2,&1,Asset.Error,F.Mesh & F.Material> <- Content.sources()
    retained_sources(result)
    IO.print("Mesh and material source caches verified after release; source-only closure compiled and ran without Creation or Vulkan.")

def main() -> IO(Unit):
  do IO<Unit>:
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("mktemp",["-d","build/verification/assets-XXXXXXXX"],"",4096,10000))
    +dest:String <- directory(result)
    IO.print("Asset runtime evidence: " ++ dest)
    write(dest ++ "/source","w","A")
    loaded(Asset.request(Bytes(),Asset.new(Bytes(),"runtime-files"),dest ++ "/source"),dest ++ "/source")
    limits(dest ++ "/limit")
    source_only(dest ++ "/source-only")
    Scene.main()
    IO.print("Asset API verified with real files and production scene execution.")
