import Base
import ../src/asset.bend as Asset
import ../src/content.bend as F
import ../src/components.bend as C

def triangle() -> F.Mesh:
  F.Mesh{[
    F.Vertex{C.Vec3{F32.neg(0.25),F32.neg(0.25),0.0},C.Vec3{1.0,1.0,1.0},F.UV{0.0,0.0},C.Vec3{0.0,0.0,1.0}},
    F.Vertex{C.Vec3{0.25,F32.neg(0.25),0.0},C.Vec3{1.0,1.0,1.0},F.UV{0.0,0.0},C.Vec3{0.0,0.0,1.0}},
    F.Vertex{C.Vec3{0.0,0.25,0.0},C.Vec3{1.0,1.0,1.0},F.UV{0.0,0.0},C.Vec3{0.0,0.0,1.0}}],[0,1,2]}

def red() -> F.Material:
  F.Basic{C.Vec3{1.0,0.0,0.0}}

def mesh_loader(_:String) -> IO(Result<&2,&2,Asset.Error,F.Mesh>):
  IO.pure(Result<&2,&2,Asset.Error,F.Mesh>,Done{triangle()})

def material_loader(_:String) -> IO(Result<&2,&2,Asset.Error,F.Material>):
  IO.pure(Result<&2,&2,Asset.Error,F.Material>,Done{red()})

def retained(-A:Data,source:Maybe<&2,Asset.State<A>>,missing:Maybe<&2,Asset.State<A>>) -> Result<&2,&2,Asset.Error,A>:
  match source missing:
    case Some{Asset.Loaded{value}} None{}:Done{value}
    case Some{Asset.Failed{error}} _:Fail{error}
    case _ _:Fail{Asset.Error{1,"Source was not loaded or released"}}

def released(-A:Data,source:Maybe<&2,Asset.State<A>>,pair:Asset.Cache<A> & Maybe<&2,Asset.State<A>>) -> Result<&2,&2,Asset.Error,A>:
  (_,missing) = pair
  retained(A,source,missing)

# Lookup after eviction forces release while the copied source stays usable.
def take(-A:Data,pair:Asset.Cache<A> & Maybe<&2,Asset.State<A>>,+handle:Asset.Handle<A>) -> Result<&2,&2,Asset.Error,A>:
  (cache,source) = pair
  released(A,source,Asset.lookup(A,Asset.release(A,cache,handle),handle))

def load(-A:Data,pair:Asset.Cache<A> & Asset.Handle<A>,loader:String -> IO(Result<&2,&2,Asset.Error,A>)) -> IO(Result<&2,&2,Asset.Error,A>):
  (cache,+handle) = pair
  do IO<Result<&2,&2,Asset.Error,A>>:
    cache:Asset.Cache<A> <- Asset.load(A,cache,handle,loader)
    return take(A,Asset.lookup(A,cache,handle),handle)

def mesh() -> IO(Result<&2,&2,Asset.Error,F.Mesh>):
  load(F.Mesh,Asset.request(F.Mesh,Asset.new(F.Mesh,"procedural-mesh"),"triangle"),mesh_loader)

def material() -> IO(Result<&2,&2,Asset.Error,F.Material>):
  load(F.Material,Asset.request(F.Material,Asset.new(F.Material,"procedural-material"),"red"),material_loader)

def combine(mesh:Result<&2,&2,Asset.Error,F.Mesh>,material:Result<&2,&2,Asset.Error,F.Material>) -> Result<&2,&1,Asset.Error,F.Mesh & F.Material>:
  match mesh material:
    case Fail{error} _:Fail{error}
    case _ Fail{error}:Fail{error}
    case Done{m} Done{t}:Done{(m,t)}

def sources() -> IO(Result<&2,&1,Asset.Error,F.Mesh & F.Material>):
  do IO<Result<&2,&1,Asset.Error,F.Mesh & F.Material>>:
    m:Result<&2,&2,Asset.Error,F.Mesh> <- mesh()
    t:Result<&2,&2,Asset.Error,F.Material> <- material()
    return combine(m,t)

def report_valid(valid:Bool) -> IO(Unit):
  match valid:
    case True{}:IO.print("Procedural mesh and material loaded; source values retained after cache release.")
    case False{}:IO.die(Unit,1,"Procedural content is invalid")

def report(result:Result<&2,&1,Asset.Error,F.Mesh & F.Material>) -> IO(Unit):
  match result:
    case Fail{Asset.Error{code,message}}:IO.die(Unit,code,message)
    case Done{(+mesh,+material)}:
      report_valid(F.mesh_valid(mesh) && F.material_valid(material))

def main() -> IO(Unit):
  do IO<Unit>:
    result:Result<&2,&1,Asset.Error,F.Mesh & F.Material> <- sources()
    report(result)
