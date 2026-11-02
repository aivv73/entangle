import Base
import ../src/components.bend as C
import ../src/scene.bend as Scene
import ../src/scene-schema.bend as D
import ../src/scene-observe.bend as Observe
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/entity-key.bend as Key
import ../deps/bendvy/src/ecs/inspector.bend as I

type Identity is Data:Identity{handle:W.Handle<D.Schema>,index:U32}

def require(ok:Bool,message:String) -> IO(Unit):
  match ok:
    case True{}:IO.pure(Unit,Unit{})
    case False{}:IO.die(Unit,1,message)

def equal(left:W.Handle<D.Schema>,right:W.Handle<D.Schema>) -> Bool:
  W.Handle{ln,lk} = left
  W.Handle{rn,rk} = right
  U32.is_eq(ln,rn) && Key.equal(lk,rk)

def member(handles:List<&2,W.Handle<D.Schema>>,+handle:W.Handle<D.Schema>) -> Bool:
  List.contains(~W.Handle<D.Schema>,~equal,handles,handle)

def distinct(handles:List<&2,W.Handle<D.Schema>>) -> Bool:
  match handles:
    case []:True{}
    case +handle <> +rest:Bool.not(member(rest,handle)) && distinct(rest)

def subset(left:List<&2,W.Handle<D.Schema>>,+right:List<&2,W.Handle<D.Schema>>) -> Bool:
  match left:
    case []:True{}
    case handle <> rest:member(right,handle) && subset(rest,right)

def same(+left:List<&2,W.Handle<D.Schema>>,+right:List<&2,W.Handle<D.Schema>>) -> Bool:
  distinct(left) && distinct(right) && subset(left,right) && subset(right,left)

def identities(handles:List<&2,W.Handle<D.Schema>>,+index:U32) -> List<&2,Identity>:
  match handles:
    case []:[]
    case handle <> rest:Identity{handle,index} <> identities(rest,U32.add(index,1))

def handles(values:List<&2,Identity>) -> List<&2,W.Handle<D.Schema>>:
  match values:
    case []:[]
    case Identity{handle,_} <> rest:handle <> handles(rest)

def row_handles(rows:List<&2,Observe.Row>) -> List<&2,W.Handle<D.Schema>>:
  match rows:
    case []:[]
    case Observe.Row{handle,_,_} <> rest:handle <> row_handles(rest)

def choose(found:Bool,index:U32,next:Maybe<&2,U32>) -> Maybe<&2,U32>:
  match found:
    case True{}:Some{index}
    case False{}:next

def find(values:List<&2,Identity>,+target:W.Handle<D.Schema>) -> Maybe<&2,U32>:
  match values:
    case []:None{}
    case Identity{handle,index} <> rest:choose(equal(handle,target),index,find(rest,target))

def bits(left:F32,right:F32) -> Bool:U32.is_eq(F32.bits(left),F32.bits(right))

def translation(value:C.Vec3,+index:U32,+tick:U32) -> Bool:
  C.Vec3{x,y,z} = value
  expectedX = U32.to_f32(U32.add(index,tick))
  expectedY = F32.div(U32.to_f32(U32.add(U32.mul(4,index),tick)),2.0)
  expectedZ = F32.neg(U32.to_f32(U32.add(index,U32.mul(2,tick))))
  bits(x,expectedX) && bits(y,expectedY) && bits(z,expectedZ)

def preserved(rotation:C.Quat,scale:C.Vec3) -> Bool:
  C.Quat{x,y,z,w} = rotation
  C.Vec3{sx,sy,sz} = scale
  rotationOk = bits(x,0.0) && bits(y,0.0) && bits(z,0.6) && bits(w,0.8)
  scaleOk = bits(sx,2.0) && bits(sy,3.0) && bits(sz,4.0)
  rotationOk && scaleOk

def row_at(value:C.Transform,mesh:C.MeshRef,+tick:U32,index:Maybe<&2,U32>) -> IO(Unit):
  C.Transform{position,rotation,scale} = value
  C.MeshRef{id} = mesh
  match index:
    case Some{+index}:
      do IO<Unit>:
        require(U32.is_eq(id,7),"scene mesh ID changed")
        require(translation(position,index,tick),"scene translation mismatch at tick " ++ U32.show(tick) ++ " seed " ++ U32.show(index))
        require(preserved(rotation,scale),"scene rotation or scale changed")
    case None{}:IO.die(Unit,1,"scene row has no admitted identity")

def rows(values:List<&2,Observe.Row>,+baseline:List<&2,Identity>,+tick:U32) -> IO(Unit):
  match values:
    case []:IO.pure(Unit,Unit{})
    case Observe.Row{handle,value,mesh} <> rest:
      do IO<Unit>:
        row_at(value,mesh,tick,find(baseline,handle))
        rows(rest,baseline,tick)

def validate(+tick:U32,+baseline:List<&2,Identity>,snapshot:Observe.Snapshot) -> IO(Unit):
  Observe.Snapshot{+live,+admitted,exhausted,clean,+values} = snapshot
  do IO<Unit>:
    require(Nat.is_eq(List.length(&2,W.Handle<D.Schema>,live),100n),"scene live population is not 100")
    require(Nat.is_eq(List.length(&2,W.Handle<D.Schema>,admitted),100n),"scene admitted population is not 100")
    require(same(live,admitted),"scene live handles differ from admissions or contain duplicates")
    require(same(live,row_handles(values)),"scene rows are duplicate, missing, or outside the live set")
    require(same(admitted,handles(baseline)),"scene handles changed after bootstrap")
    require(exhausted && clean,"scene bootstrap seeds, pending commands, or rejected collections remain")
    rows(values,baseline,tick)

def observed(next:Scene.Application() -> I.Instance<D.Schema> -> List<&2,Identity> -> IO(Unit),+tick:U32,
  baseline:List<&2,Identity>,result:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Observe.Snapshot>)) -> IO(Unit):
  match baseline result:
    case [], (app,(instance,Done{Observe.Snapshot{live,+admitted,exhausted,clean,values}})):
      +baseline = identities(admitted,0)
      do IO<Unit>:
        validate(tick,baseline,Observe.Snapshot{live,admitted,exhausted,clean,values})
        IO.print("tick=" ++ U32.show(tick) ++ " entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted")
        next(app,instance,baseline)
    case +baseline, (app,(instance,Done{snapshot})):
      do IO<Unit>:
        validate(tick,baseline,snapshot)
        IO.print("tick=" ++ U32.show(tick) ++ " entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted")
        next(app,instance,baseline)
    case _, _:IO.die(Unit,1,"scene component observation refused")

def ticks(remaining:Nat,+tick:U32,app:Scene.Application(),instance:I.Instance<D.Schema>,baseline:List<&2,
  Identity>) -> IO(Unit):
  match remaining:
    case 0n:IO.print("Shared mesh scene verified across 8 ticks.")
    case 1n++rest:
      do IO<Unit>:
        app : Scene.Application() <- Scene.tick(app)
        observed(app => instance => baseline => ticks(rest,U32.add(tick,1),app,instance,baseline),tick,
          baseline,Observe.snapshot(app,instance))

def initial(result:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Observe.Snapshot>)) -> IO(Unit):
  match result:
    case (app,(instance,Done{Observe.Snapshot{[],[],_,_,[]}})):
      do IO<Unit>:
        IO.print("before-tick entities=0 admitted=0")
        ticks(8n,1,app,instance,[])
    case _:IO.die(Unit,1,"scene must start empty before its first tick")

def main() -> IO(Unit):
  do IO<Unit>:
    app : Scene.Application() <- Scene.create()
    initial(Observe.snapshot(app,I.Fresh{}))
