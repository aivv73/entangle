import ../src/content.bend as F
import Base
import ../src/components.bend as C

type Face is Data:Face{a:U32,b:U32,c:U32}

def faces(indices:List<&2,U32>) -> List<&2,Face>:
  match indices:
    case a <> b <> c <> rest:Face{a,b,c} <> faces(rest)
    case _:[]

def edge(+a:U32,+b:U32,+x:U32,+y:U32,+z:U32) -> U32:
  U32.add(Bool.to_u32(U32.is_eq(a,x) && U32.is_eq(b,y)),U32.add(Bool.to_u32(U32.is_eq(a,y) && U32.is_eq(b,z)),Bool.to_u32(U32.is_eq(a,z) && U32.is_eq(b,x))))

def incidence(+a:U32,+b:U32,fs:List<&2,Face>) -> U32:
  match fs:
    case []:0
    case Face{x,y,z} <> rest:U32.add(edge(a,b,x,y,z),incidence(a,b,rest))

def paired(+a:U32,+b:U32,+all:List<&2,Face>) -> Bool:
  U32.is_ne(a,b) && U32.is_eq(incidence(a,b,all),1) && U32.is_eq(incidence(b,a,all),1)

def vertex(vs:List<&2,F.Vertex>,i:Nat) -> C.Vec3:
  match vs i:
    case F.Vertex{p,_} <> _ 0n:p
    case _ <> rest 1n+tail:vertex(rest,tail)
    case [] _:C.Vec3{0.0,0.0,0.0}

def sub(a:C.Vec3,b:C.Vec3) -> C.Vec3:
  C.Vec3{+x,+y,+z} = a
  C.Vec3{+u,+v,+w} = b
  C.Vec3{(x - u : F32),(y - v : F32),(z - w : F32)}

def cross(a:C.Vec3,b:C.Vec3) -> C.Vec3:
  C.Vec3{+x,+y,+z} = a
  C.Vec3{+u,+v,+w} = b
  C.Vec3{(y * w - z * v : F32),(z * u - x * w : F32),(x * v - y * u : F32)}

def dot(a:C.Vec3,b:C.Vec3) -> F32:
  C.Vec3{+x,+y,+z} = a
  C.Vec3{+u,+v,+w} = b
  (x * u + y * v + z * w : F32)

def outward(+a:C.Vec3,+b:C.Vec3,c:C.Vec3) -> Bool:
  F32.is_gt(dot(cross(sub(b,a),sub(c,a)),a),0.0)

def closed(fs:List<&2,Face>,+all:List<&2,Face>,+vs:List<&2,F.Vertex>) -> Bool:
  match fs:
    case []:True{}
    case Face{+a,+b,+c} <> rest:
      paired(a,b,all) && paired(b,c,all) && paired(c,a,all) && outward(vertex(vs,U32.to_nat(a)),vertex(vs,U32.to_nat(b)),vertex(vs,U32.to_nat(c))) && closed(rest,all,vs)

def has(+n:U32,xs:List<&2,U32>) -> Bool:
  match xs:
    case []:False{}
    case x <> rest:U32.is_eq(n,x) || has(n,rest)

def grow(fs:List<&2,Face>,+seen:List<&2,U32>) -> List<&2,U32>:
  match fs:
    case []:seen
    case Face{+a,+b,+c} <> rest:grow(rest,Bool.pick(List<&2,U32>,has(a,seen) || has(b,seen) || has(c,seen),a <> b <> c <> seen,seen))

def reach(n:Nat,+fs:List<&2,Face>,seen:List<&2,U32>) -> List<&2,U32>:
  match n:
    case 0n:seen
    case 1n+rest:reach(rest,fs,grow(fs,seen))

def all_seen(vs:List<&2,F.Vertex>,+seen:List<&2,U32>,+index:U32) -> Bool:
  match vs:
    case []:True{}
    case _ <> rest:has(index,seen) && all_seen(rest,seen,U32.inc(index))

def connected(+vs:List<&2,F.Vertex>,+fs:List<&2,Face>) -> Bool:
  all_seen(vs,reach(List.length(&2,F.Vertex,vs),fs,[0]),0)

def inspect(mesh:F.Mesh,base:Bool) -> Bool:
  F.Mesh{+vs,+indices} = mesh
  base && Nat.is_gt(List.length(&2,F.Vertex,vs),0n) && closed(faces(indices),faces(indices),vs) && connected(vs,faces(indices))

def valid(+mesh:F.Mesh) -> Bool:
  inspect(mesh,F.mesh_valid(mesh))
