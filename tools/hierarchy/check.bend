import Base
import ../../src/hierarchy.bend as H
import ../../src/scene-hierarchy.bend as HW
import ../../src/components.bend as C
import ../../src/content.bend as F
import ../../src/scene-matrix.bend as M
import ../../src/scene-schema.bend as D
import ../../src/scene-runtime.bend as Scene
import ../../src/creation.bend as Create
import ../../deps/bendvy/src/ecs/world.bend as W
import ../../deps/bendvy/src/ecs/entity-key.bend as Key
import ../upload-boundary/scan.bend as S

def captured(rebuild:D.World() -> Scene.Application(),pair:D.World() & Result<&2,&2,H.Error,List<&2,HW.Row>>) -> IO(Scene.Application() & List<&2,HW.Row>):
  match pair:
    case (world,Done{rows}):IO.pure(Scene.Application() & List<&2,HW.Row>,(rebuild(world),rows))
    case _:IO.die(Scene.Application() & List<&2,HW.Row>,1,"Hierarchy ECS observation failed")

def capture(app:Scene.Application()) -> IO(Scene.Application() & List<&2,HW.Row>):
  Scene.Application{world,schedule} = app
  captured(world => Scene.Application{world,schedule},HW.read(world))

def at(rows:List<&2,HW.Row>,index:Nat) -> Maybe<&2,HW.Row>:
  match rows index:
    case row <> _,0n:Some{row}
    case _ <> rest,1n+n:at(rest,n)
    case [] _:None{}

def entity(value:Maybe<&2,HW.Row>) -> IO(W.Handle<D.Schema>):
  match value:
    case Some{HW.Row{entity,_,_,_}}:IO.pure(W.Handle<D.Schema>,entity)
    case _:IO.die(W.Handle<D.Schema>,1,"Missing oracle entity")

def close(+a:F32,+b:F32) -> Bool:
  F.finite(a) && F.finite(b) && F32.is_le(F32.abs(F32.sub(a,b)),F32.mul(0.0001,F32.max(1.0,F32.max(F32.abs(a),F32.abs(b)))))

def vec(a:C.Vec3,b:C.Vec3) -> Bool:
  C.Vec3{x,y,z} = a
  C.Vec3{u,v,w} = b
  close(x,u) && close(y,v) && close(z,w)

# Independent oracle applies local scale and quaternion rotation to a point,
# then walks parents. It never composes model matrices.
def local_point(t:C.Transform,p:C.Vec3) -> C.Vec3:
  C.Transform{C.Vec3{tx,ty,tz},C.Quat{+qx,+qy,+qz,+qw},C.Vec3{sx,sy,sz}} = t
  C.Vec3{x,y,z} = p
  +x = F32.mul(x,sx)
  +y = F32.mul(y,sy)
  +z = F32.mul(z,sz)
  +rx = (2.0 * (qy * z - qz * y) : F32)
  +ry = (2.0 * (qz * x - qx * z) : F32)
  +rz = (2.0 * (qx * y - qy * x) : F32)
  C.Vec3{(tx + x + qw * rx + qy * rz - qz * ry : F32),(ty + y + qw * ry + qz * rx - qx * rz : F32),(tz + z + qw * rz + qx * ry - qy * rx : F32)}

def follow(parent:Maybe<&2,U32>,p:C.Vec3,next:U32 -> C.Vec3 -> Maybe<&2,C.Vec3>) -> Maybe<&2,C.Vec3>:
  match parent:
    case None{}:Some{p}
    case Some{n}:next(n,p)

def walk_row(row:Maybe<&2,HW.Row>,p:C.Vec3,next:U32 -> C.Vec3 -> Maybe<&2,C.Vec3>) -> Maybe<&2,C.Vec3>:
  match row:
    case None{}:None{}
    case Some{HW.Row{_,t,_,H.Spatial{H.Local{_,parent,_,_},_,_}}}:follow(parent,local_point(t,p),next)

def walk(fuel:Nat,+rows:List<&2,HW.Row>,index:U32,p:C.Vec3) -> Maybe<&2,C.Vec3>:
  match fuel:
    case 0n:None{}
    case 1n+n:walk_row(at(rows,U32.to_nat(index)),p,i => p => walk(n,rows,i,p))

def matches(expected:Maybe<&2,C.Vec3>,actual:C.Vec3) -> Bool:
  match expected:
    case None{}:False{}
    case Some{p}:vec(p,actual)

def points(values:List<&2,C.Vec3>,+rows:List<&2,HW.Row>,+index:U32,+global:H.GlobalTransform) -> Bool:
  match values:
    case []:True{}
    case +p <> rest:matches(walk(1n+List.length(&2,HW.Row,rows),rows,index,p),H.point(H.matrix(global),p)) && points(rest,rows,index,global)

def expected_include(value:Maybe<&2,C.Vec3>,bounds:Maybe<&2,H.Bounds>) -> Maybe<&2,H.Bounds>:
  match value bounds:
    case Some{p} Some{b}:Some{H.include(b,p)}
    case _ _:None{}

def expected_bounds(corners:List<&2,C.Vec3>,+rows:List<&2,HW.Row>,+index:U32) -> Maybe<&2,H.Bounds>:
  match corners:
    case []:Some{H.Empty{}}
    case p <> rest:expected_include(walk(1n+List.length(&2,HW.Row,rows),rows,index,p),expected_bounds(rest,rows,index))

def bounds(expected:Maybe<&2,H.Bounds>,actual:H.Bounds) -> Bool:
  match expected actual:
    case Some{H.Empty{}} H.Empty{}:True{}
    case Some{H.Bounds{a,b}} H.Bounds{c,d}:vec(a,c) && vec(b,d)
    case _ _:False{}

def pose_words(t:C.Transform) -> List<&2,U32>:
  C.Transform{C.Vec3{x,y,z},C.Quat{a,b,c,d},C.Vec3{sx,sy,sz}} = t
  [F32.bits(x),F32.bits(y),F32.bits(z),F32.bits(a),F32.bits(b),F32.bits(c),F32.bits(d),F32.bits(sx),F32.bits(sy),F32.bits(sz)]

def same_pose(a:C.Transform,b:C.Transform) -> Bool:F.same_indices(pose_words(a),pose_words(b))

def verify_rows(todo:List<&2,HW.Row>,+all:List<&2,HW.Row>,+index:U32) -> IO(Unit):
  match todo:
    case []:IO.pure(Unit,Unit{})
    case HW.Row{_,+t,_,H.Spatial{H.Local{accepted,_,+local,_},+global,b}} <> rest:
      do IO<Unit>:
        S.require(same_pose(t,accepted),"Hierarchy accepted local differs from ECS Transform")
        S.require(points([C.Vec3{0.0,0.0,0.0},C.Vec3{1.0,0.0,0.0},C.Vec3{0.0,1.0,0.0},C.Vec3{0.0,0.0,1.0}],all,index,global),"Hierarchy world position/composition differs from independent point oracle")
        S.require(bounds(expected_bounds(H.corners(local),all,index),b),"Hierarchy world bounds differ from independent corner oracle")
        verify_rows(rest,all,U32.inc(index))

def words(values:List<U32>) -> String:
  match values:
    case []:""
    case value <> rest:U32.show(value) ++ "," ++ words(rest)

def data_words(values:List<&2,U32>) -> String:
  match values:
    case []:""
    case value <> rest:U32.show(value) ++ "," ++ data_words(rest)

def vec_words(v:C.Vec3) -> String:
  C.Vec3{x,y,z} = v
  data_words([F32.bits(x),F32.bits(y),F32.bits(z)])

def bound_words(b:H.Bounds) -> String:
  match b:
    case H.Empty{}:"empty"
    case H.Bounds{a,b}:vec_words(a) ++ vec_words(b)

def parent_words(p:Maybe<&2,U32>) -> String:
  match p:
    case None{}:"root"
    case Some{n}:U32.show(n)

def row_words(row:HW.Row) -> String:
  HW.Row{W.Handle{ns,Key.EntityKey{id,gen}},t,C.MeshRef{mesh},H.Spatial{H.Local{accepted,p,b,lit},global,wb}} = row
  data_words([ns,id,gen,mesh,Bool.to_u32(lit)]) ++ data_words(pose_words(t)) ++ data_words(pose_words(accepted)) ++ parent_words(p) ++ ";" ++ bound_words(b) ++ ";" ++ words(M.matrix_words(H.matrix(global))) ++ bound_words(wb)

def state(rows:List<&2,HW.Row>) -> String:
  match rows:
    case []:""
    case row <> rest:row_words(row) ++ "|" ++ state(rest)

def checked(pair:Scene.Application() & List<&2,HW.Row>) -> IO(Scene.Application() & List<&2,HW.Row>):
  (app,+rows) = pair
  do IO<Scene.Application() & List<&2,HW.Row>>:
    verify_rows(rows,rows,0)
    return (app,rows)

def observe(app:Scene.Application()) -> IO(Scene.Application() & List<&2,HW.Row>):
  do IO<Scene.Application() & List<&2,HW.Row>>:
    pair:Scene.Application() & List<&2,HW.Row> <- capture(app)
    checked(pair)

def accepted(pair:Scene.Application() & Result<&2,&2,H.Error,Unit>,expected:Bool) -> IO(Scene.Application()):
  match pair:
    case (app,Done{_}):
      do IO<Scene.Application()>:
        S.require(expected,"Invalid hierarchy edit was accepted")
        return app
    case (app,Fail{_}):
      do IO<Scene.Application()>:
        S.require(Bool.not(expected),"Valid hierarchy edit was rejected")
        return app
