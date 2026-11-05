import Base
import ../src/creation.bend as Create
import ./scene-seeds.bend as Seeds
import ../src/scene-step.bend as Step
import ../src/scene-spawn.bend as Spawn
import ../deps/bendvy/src/ecs/execution-generalized-root-application.bend as Root
import ../deps/bendvy/src/ecs/execution-deferred-schedule.bend as Deferred
import ../deps/bendvy/src/ecs/execution-deferred-settings.bend as Settings
import ../deps/bendvy/src/ecs/dependency-executor.bend as Exec
import ../deps/bendvy/src/ecs/dependency-registration.bend as Reg
import ../deps/bendvy/src/ecs/execution-retained-system.bend as Retained
import ../deps/bendvy/src/ecs/execution-command-system.bend as Cmd
import ../deps/bendvy/src/ecs/execution-system.bend as Sys
import ../deps/bendvy/src/ecs/execution-command-local.bend as Local
import ../deps/bendvy/src/ecs/execution-command-buffer.bend as Buffer
import ../deps/bendvy/src/ecs/execution-command-removed.bend as Removed
import ../deps/bendvy/src/ecs/owner-product.bend as Product
import ../src/scene-draw.bend as Draw
import ../deps/bendvy/src/ecs/execution-schedule.bend as Scheduled
import ../deps/bendvy/src/ecs/dependency-application.bend as App
import ../deps/bendvy/src/ecs/change-tick.bend as Tick
import ../src/components.bend as C
import ../src/scene.bend as Scene
import ../src/scene-schema.bend as D
import ../src/scene-observe.bend as Observe
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/entity-key.bend as Key
import ../deps/bendvy/src/ecs/inspector.bend as I

type Identity is Data:Identity{handle:W.Handle<D.Schema>,index:U32}

type Bootstrap is Data:
  Bootstrap{id:U32,receipts:List<&2,W.Handle<D.Schema>>,valid:Bool,clean:Bool,exhausted:Bool}

type Inventory is Data:
  Inventory{bootstrap:Bootstrap,move:U32,syncs:List<&2,U32>,drained:Bool}

def require(ok:Bool,message:String) -> IO(Unit):
  match ok:
    case True{}:IO.pure(Unit,Unit{})
    case False{}:IO.die(Unit,1,message)

def run_observed(app:Scene.Application()) -> Scheduled.ObservedScheduled<Scene.State(),String,Unit>:
  Root.run_observed(~D.Schema,~D.components(),~D.resources(),~Unit,~Scene.Nodes(),~Unit,~Unit,~String,
    ~Unit,~Scene.dispatch(),~Scene.guard_dispatch(),~Scene.handle,~Scene.apply,True{},app)

def receipt_cons(head:Observe.Receipt(),+handle:W.Handle<D.Schema>,
  result:List<Observe.Receipt()> & (List<&2,W.Handle<D.Schema>> & Bool)) -> List<Observe.Receipt()> & (List<&2,W.Handle<D.Schema>> & Bool):
  match result:
    case (rest,(handles,ok)):(head <> rest,(handle <> handles,ok))

def receipt_summary(values:List<Observe.Receipt()>) -> List<Observe.Receipt()> & (List<&2,W.Handle<D.Schema>> & Bool):
  match values:
    case []:([],([],True{}))
    case Buffer.Spawned{+handle,Product.Owner{None{},Product.Owner{None{},None{}}}} <> rest:
      receipt_cons(Buffer.Spawned{handle,Product.Owner{None{},Product.Owner{None{},None{}}}},handle,receipt_summary(rest))
    case head <> rest:(head <> rest,([],False{}))

def summarized(restore:List<Observe.Receipt()> -> Scene.Owner(),id:U32,exhausted:Bool,
  result:List<Observe.Receipt()> & (List<&2,W.Handle<D.Schema>> & Bool)) -> Scene.Owner() & Bootstrap:
  match result:
    case (receipts,(handles,ok)):(restore(receipts),Bootstrap{id,handles,ok,True{},exhausted})

def seeds_empty(values:List<Removed.Removed(D.components())>) -> List<Removed.Removed(D.components())> & Bool:
  match values:
    case []:([],True{})
    case head <> rest:(head <> rest,False{})

def bootstrap_seeds(restore:List<Removed.Removed(D.components())> -> List<Observe.Receipt()> -> Scene.Owner(),
  id:U32,receipts:List<Observe.Receipt()>,result:List<Removed.Removed(D.components())> & Bool) -> Scene.Owner() & Bootstrap:
  match result:
    case (seeds,exhausted):summarized(restore(seeds),id,exhausted,receipt_summary(receipts))

def bootstrap_summary(owner:Scene.Owner()) -> Scene.Owner() & Bootstrap:
  match owner:
    case Cmd.Owner{Sys.Owner{ns,+id,name,access,cursor,Local.Local{Spawn.User{seeds,handles,[]},Buffer.Buffer{[],receipts},permission}}}:
      bootstrap_seeds(seeds => receipts => Cmd.Owner{Sys.Owner{ns,id,name,access,cursor,
        Local.Local{Spawn.User{seeds,handles,[]},Buffer.Buffer{[],receipts},permission}}},id,receipts,seeds_empty(seeds))
    case Cmd.Owner{Sys.Owner{ns,+id,name,access,cursor,local}}:
      (Cmd.Owner{Sys.Owner{ns,id,name,access,cursor,local}},Bootstrap{id,[],False{},False{},False{}})

def move_id(owner:Scene.Peer()) -> Scene.Peer() & U32:
  Sys.Owner{ns,+id,name,access,cursor,local} = owner
  (Sys.Owner{ns,id,name,access,cursor,local},id)

def inventory_move(rebuild:Scene.PeerBinding() -> Scene.Application(),bootstrap:Bootstrap,syncs:List<&2,U32>,drained:Bool,
  result:Scene.PeerBinding() & U32) -> Scene.Application() & Inventory:
  match result:
    case (right,id):(rebuild(right),Inventory{bootstrap,id,syncs,drained})

def inventory_spawn(rebuild:Scene.Binding() -> Scene.PeerBinding() -> Scene.Application(),right:Scene.PeerBinding(),
  syncs:List<&2,U32>,drained:Bool,result:Scene.Binding() & Bootstrap) -> Scene.Application() & Inventory:
  match result:
    case (left,bootstrap):inventory_move(rebuild(left),bootstrap,syncs,drained,
      Retained.map_owner(Scene.PeerCompilation(),Scene.Peer(),U32,move_id,right))

def no_ids(values:List<&2,U32>) -> Bool:
  match values:
    case []:True{}
    case _:False{}

def inventory(app:Scene.Application()) -> Scene.Application() & Inventory:
  Scheduled.Scheduled{App.State{world,Reg.Product{left,right,routing},guards,handler,stateBindings},plan,bindings,
    Scheduled.Deferred{systems,settings,+unapplied,Settings.Built{compiled,+syncs},publication}} = app
  inventory_spawn(left => right => Scheduled.Scheduled{App.State{world,Reg.Product{left,right,routing},guards,
    handler,stateBindings},plan,bindings,Scheduled.Deferred{systems,settings,unapplied,Settings.Built{compiled,
    syncs},publication}},right,syncs,no_ids(unapplied),
    Retained.map_owner(Scene.Compilation(),Scene.Owner(),Bootstrap,bootstrap_summary,left))

def require_report(+spawn:U32,+move:U32,report:App.Report<String,Unit>) -> IO(Unit):
  match report:
    case App.Finished{[Exec.Ran{left,Unit{}},Exec.Ran{right,Unit{}}]}:
      require(U32.is_eq(left,spawn) && U32.is_eq(right,move) && Bool.not(U32.is_eq(spawn,move)),
        "scene invocation roles or order differ")
    case App.Finished{_}:IO.die(Unit,1,"scene finished with unexpected invocation observations")
    case App.Stopped{_,_}:IO.die(Unit,1,"scene stopped; retained writes and publication are not retried")
    case App.Invalid{_}:IO.die(Unit,1,"scene schedule invalid; retained application is not retried")

def require_boundaries(+spawn:U32,+move:U32,syncs:List<&2,U32>,values:List<&2,Deferred.Boundary>) -> IO(U32):
  match values:
    case [Deferred.ApplyEntered{Deferred.Sync{[+sync]},[left]},
      Deferred.ApplyReturned{Deferred.Sync{[returned]},[]},
      Deferred.ApplyEntered{Deferred.Final{},[right]},Deferred.ApplyReturned{Deferred.Final{},[]}]:
      do IO<U32>:
        require(U32.is_eq(left,spawn) && U32.is_eq(right,move) && U32.is_eq(sync,returned) &&
          Settings.member(sync,syncs),"scene publication boundary IDs differ from retained inventory")
        IO.pure(U32,sync)
    case _:IO.die(U32,1,"scene requires exactly four drained sync/final boundary events")

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

def vec_equal(left:C.Vec3,right:C.Vec3) -> Bool:
  C.Vec3{x,y,z} = left
  C.Vec3{a,b,c} = right
  bits(x,a) && bits(y,b) && bits(z,c)

def transform_equal(left:C.Transform,right:C.Transform) -> Bool:
  C.Transform{p,C.Quat{x,y,z,w},s} = left
  C.Transform{q,C.Quat{a,b,c,d},t} = right
  vec_equal(p,q) && bits(x,a) && bits(y,b) && bits(z,c) && bits(w,d) && vec_equal(s,t)

def previous_transform(values:List<&2,Observe.Row>,+target:W.Handle<D.Schema>) -> Maybe<&2,C.Transform>:
  match values:
    case []:None{}
    case Observe.Row{handle,value,_} <> rest:
      Bool.pick(Maybe<&2,C.Transform>,equal(handle,target),Some{value},previous_transform(rest,target))

def seeded_transform(seed:Create.Seed) -> Maybe<&2,C.Transform>:
  Create.Seed{value,_,_} = seed
  Some{value}

def seed_transform(index:U32) -> Maybe<&2,C.Transform>:seeded_transform(Seeds.seed(index))

def stepped(result:C.Transform & Unit) -> C.Transform:
  match result:
    case (value,Unit{}):value

def recurrence_row(value:C.Transform,prior:Maybe<&2,C.Transform>) -> IO(Unit):
  match prior:
    case Some{prior}:require(transform_equal(value,stepped(Step.step(Unit{},prior))),
      "scene numerical recurrence differs by float bits")
    case None{}:IO.die(Unit,1,"scene recurrence has no prior identity or seed")

def recurrence(values:List<&2,Observe.Row>,+previous:List<&2,Observe.Row>,+baseline:List<&2,Identity>,+first:Bool) -> IO(Unit):
  match values:
    case []:IO.pure(Unit,Unit{})
    case Observe.Row{+handle,value,_} <> rest:
      do IO<Unit>:
        recurrence_row(value,Bool.pick(Maybe<&2,C.Transform>,first,
          Maybe.bind(&2,U32,C.Transform,find(baseline,handle),seed_transform),previous_transform(previous,handle)))
        recurrence(rest,previous,baseline,first)

def drawing_equal(items:List<&2,Draw.DrawItem>,rows:List<&2,Observe.Row>) -> Bool:
  match items rows:
    case [], []:True{}
    case Draw.DrawItem{t,C.MeshRef{id}} <> rest, Observe.Row{_,u,C.MeshRef{other}} <> tail:
      transform_equal(t,u) && U32.is_eq(id,other) && drawing_equal(rest,tail)
    case _, _:False{}

def cursor_key(cursor:Maybe<&2,Tick.Tick>) -> String:
  match cursor:
    case None{}:"none"
    case Some{tick}:Nat.show(Tick.total(tick))

def instance_key(instance:I.Instance<D.Schema>) -> I.Instance<D.Schema> & String:
  match instance:
    case I.Fresh{}:(I.Fresh{},"fresh")
    case I.Active{+cursor,+registered}:(I.Active{cursor,registered},cursor_key(cursor) ++ "/" ++ Nat.show(Tick.total(registered)))

def clocked(rebuild:D.World() -> Scene.Application(),result:D.World() & Tick.Tick) -> Scene.Application() & Tick.Tick:
  match result:
    case (world,clock):(rebuild(world),clock)

def app_clock(app:Scene.Application()) -> Scene.Application() & Tick.Tick:
  Scheduled.Scheduled{App.State{world,nodes,guards,handler,stateBindings},settings,bindings,deferred} = app
  clocked(world => Scheduled.Scheduled{App.State{world,nodes,guards,handler,stateBindings},settings,bindings,deferred},
    W.clock(~D.Schema,~D.Columns(),~D.Resources(),~Unit,world))

def checked_clock(next:Scene.Application() -> IO(Unit),before:Tick.Tick,result:Scene.Application() & Tick.Tick) -> IO(Unit):
  match result:
    case (app,after):
      do IO<Unit>:
        require(Nat.is_eq(Tick.total(before),Tick.total(after)),"drawing changed world clock")
        next(app)

def checked_instance(next:Scene.Application() -> I.Instance<D.Schema> -> Draw.DrawList -> IO(Unit),
  retained:Draw.DrawList,prior:String,before:Tick.Tick,app:Scene.Application(),result:I.Instance<D.Schema> & String) -> IO(Unit):
  match result:
    case (instance,key):
      do IO<Unit>:
        require(String.eq(prior,key),"drawing changed inspector instance")
        checked_clock(app => next(app,instance,retained),before,app_clock(app))

def drawn(next:Scene.Application() -> I.Instance<D.Schema> -> Draw.DrawList -> IO(Unit),
  +expected:List<&2,Observe.Row>,prior:String,before:Tick.Tick,
  result:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Draw.DrawList>)) -> IO(Unit):
  match result:
    case (app,(instance,Done{Draw.DrawList{+items}})):
      do IO<Unit>:
        require(drawing_equal(items,expected),"drawing payload differs from ordered observer rows")
        checked_instance(next,Draw.DrawList{items},prior,before,app,instance_key(instance))
    case _:IO.die(Unit,1,"scene drawing extraction refused")

def drawing_instance(next:Scene.Application() -> I.Instance<D.Schema> -> Draw.DrawList -> IO(Unit),
  expected:List<&2,Observe.Row>,before:Tick.Tick,app:Scene.Application(),result:I.Instance<D.Schema> & String) -> IO(Unit):
  match result:
    case (instance,key):drawn(next,expected,key,before,Observe.draw_list(app,instance))

def drawing_clock(next:Scene.Application() -> I.Instance<D.Schema> -> Draw.DrawList -> IO(Unit),
  expected:List<&2,Observe.Row>,instance:I.Instance<D.Schema>,result:Scene.Application() & Tick.Tick) -> IO(Unit):
  match result:
    case (app,before):drawing_instance(next,expected,before,app,instance_key(instance))

def drawing(next:Scene.Application() -> I.Instance<D.Schema> -> Draw.DrawList -> IO(Unit),
  expected:List<&2,Observe.Row>,app:Scene.Application(),instance:I.Instance<D.Schema>) -> IO(Unit):
  drawing_clock(next,expected,instance,app_clock(app))

def retained_checked(next:Scene.Application() -> I.Instance<D.Schema> -> IO(Unit),expected:List<&2,Observe.Row>,
  retained:Draw.DrawList,app:Scene.Application(),instance:I.Instance<D.Schema>) -> IO(Unit):
  Draw.DrawList{items} = retained
  do IO<Unit>:
    require(drawing_equal(items,expected),"retained drawing changed after extraction or tick")
    next(app,instance)

def repeated(next:Scene.Application() -> I.Instance<D.Schema> -> IO(Unit),+expected:List<&2,Observe.Row>,
  app:Scene.Application(),instance:I.Instance<D.Schema>) -> IO(Unit):
  drawing(app => instance => retained => drawing(app => instance => _ =>
    retained_checked(next,expected,retained,app,instance),expected,app,instance),expected,app,instance)

def baseline_at(baseline:List<&2,Identity>,admitted:List<&2,W.Handle<D.Schema>>) -> List<&2,Identity>:
  match baseline:
    case []:identities(admitted,0)
    case baseline:baseline

def observed(next:Scene.Application() -> I.Instance<D.Schema> -> List<&2,Identity> -> List<&2,Observe.Row> -> IO(Unit),+tick:U32,
  baseline:List<&2,Identity>,previous:List<&2,Observe.Row>,+receipts:List<&2,W.Handle<D.Schema>>,evidence:String,
  result:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Observe.Snapshot>)) -> IO(Unit):
  match result:
    case (app,(instance,Done{Observe.Snapshot{+live,+admitted,exhausted,clean,+values}})):
      +baseline = baseline_at(baseline,admitted)
      do IO<Unit>:
        validate(tick,baseline,Observe.Snapshot{live,admitted,exhausted,clean,values})
        require(Nat.is_eq(List.length(&2,W.Handle<D.Schema>,receipts),100n) && same(receipts,admitted) &&
          same(receipts,live) && same(receipts,row_handles(values)),"scene successful receipt identities differ from the world")
        recurrence(values,previous,baseline,U32.is_eq(tick,1))
        IO.print("tick=" ++ U32.show(tick) ++ " entities=100 mesh=7 translated=100 stable=true preserved=true bootstrap=exhausted")
        IO.print(evidence)
        repeated(app => instance => next(app,instance,baseline,values),values,app,instance)
    case _:IO.die(Unit,1,"scene component observation refused")

def returned_inventory(next:Scene.Application() -> I.Instance<D.Schema> -> List<&2,Identity> -> List<&2,Observe.Row> -> IO(Unit),
  +tick:U32,baseline:List<&2,Identity>,previous:List<&2,Observe.Row>,start:Nat,+spawn:U32,+move:U32,+sync:U32,
  instance:I.Instance<D.Schema>,result:Scene.Application() & Inventory) -> IO(Unit):
  match result:
    case (app,Inventory{Bootstrap{id,receipts,valid,clean,exhausted},right,syncs,drained}):
      do IO<Unit>:
        require(U32.is_eq(id,spawn) && U32.is_eq(right,move) && Settings.member(sync,syncs),"scene retained roles changed")
        require(valid && clean && exhausted && drained,"scene returned refused receipts, pending commands, seeds, or unapplied systems")
        observed(next,tick,baseline,previous,receipts,"boundaries tick=" ++ U32.show(tick) ++ " start=" ++ Nat.show(start) ++
          " finish=100 receipts=100 updates=100 spawn=" ++ U32.show(spawn) ++ " move=" ++ U32.show(move) ++
          " sync=" ++ U32.show(sync) ++ " events=4 unapplied=0",Observe.snapshot(app,instance))

def executed(next:Scene.Application() -> I.Instance<D.Schema> -> List<&2,Identity> -> List<&2,Observe.Row> -> IO(Unit),
  tick:U32,baseline:List<&2,Identity>,previous:List<&2,Observe.Row>,start:Nat,info:Inventory,
  prior:List<&2,Observe.Row>,retained:Draw.DrawList,instance:I.Instance<D.Schema>,
  result:Scheduled.ObservedScheduled<Scene.State(),String,Unit>) -> IO(Unit):
  Inventory{Bootstrap{+spawn,_,_,_,_},+move,syncs,_} = info
  Scheduled.ObservedScheduled{app,report,boundaries} = result
  do IO<Unit>:
    require_report(spawn,move,report)
    sync : U32 <- require_boundaries(spawn,move,syncs,boundaries)
    retained_checked(app => instance => returned_inventory(next,tick,baseline,previous,start,spawn,move,sync,
      instance,inventory(app)),prior,retained,app,instance)

def start_snapshot(tick:U32,baseline:List<&2,Identity>,+receipts:List<&2,W.Handle<D.Schema>>,exhausted:Bool,
  snapshot:Observe.Snapshot) -> IO(Unit):
  match tick snapshot:
    case 1, Observe.Snapshot{[],[],_,_,[]}:
      require(Bool.not(exhausted) && Nat.is_eq(List.length(&2,W.Handle<D.Schema>,receipts),0n),
        "scene first tick requires unexhausted seeds and empty receipts")
    case 1, _:IO.die(Unit,1,"scene first tick must start empty")
    case tick, +snapshot:
      Observe.Snapshot{_,+admitted,_,_,_} = snapshot
      do IO<Unit>:
        require(exhausted && Nat.is_eq(List.length(&2,W.Handle<D.Schema>,receipts),100n) && same(receipts,admitted),
          "scene tick start receipt identities changed")
        validate(U32.sub(tick,1),baseline,snapshot)

def require_start(+tick:U32,+baseline:List<&2,Identity>,info:Inventory,snapshot:Observe.Snapshot) -> IO(Unit):
  Inventory{Bootstrap{_,+receipts,valid,clean,exhausted},_,_,drained} = info
  do IO<Unit>:
    require(valid && clean && drained,"scene tick start has refused receipts, pending commands, or unapplied systems")
    start_snapshot(tick,baseline,receipts,exhausted,snapshot)

def started(next:Scene.Application() -> I.Instance<D.Schema> -> List<&2,Identity> -> List<&2,Observe.Row> -> IO(Unit),
  +tick:U32,+baseline:List<&2,Identity>,previous:List<&2,Observe.Row>,retained:Draw.DrawList,+info:Inventory,
  result:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Observe.Snapshot>)) -> IO(Unit):
  match result:
    case (app,(instance,Done{+snapshot})):
      Observe.Snapshot{live,_,_,_,values} = snapshot
      do IO<Unit>:
        require_start(tick,baseline,info,snapshot)
        executed(next,tick,baseline,values,List.length(&2,W.Handle<D.Schema>,live),
          info,previous,retained,instance,run_observed(app))
    case _:IO.die(Unit,1,"scene tick-start observation refused")

def start_inventory(next:Scene.Application() -> I.Instance<D.Schema> -> List<&2,Identity> -> List<&2,Observe.Row> -> IO(Unit),
  tick:U32,baseline:List<&2,Identity>,previous:List<&2,Observe.Row>,retained:Draw.DrawList,instance:I.Instance<D.Schema>,
  result:Scene.Application() & Inventory) -> IO(Unit):
  match result:
    case (app,info):started(next,tick,baseline,previous,retained,info,Observe.snapshot(app,instance))

def ticks(remaining:Nat,+tick:U32,app:Scene.Application(),instance:I.Instance<D.Schema>,baseline:List<&2,
  Identity>,retained:Draw.DrawList,previous:List<&2,Observe.Row>) -> IO(Unit):
  match remaining:
    case 0n:IO.print("Shared mesh scene verified across 8 ticks.")
    case 1n++rest:
      start_inventory(app => instance => baseline => +values =>
        drawing(app => instance => retained => ticks(rest,U32.add(tick,1),app,instance,baseline,retained,values),
          values,app,instance),tick,baseline,previous,retained,instance,inventory(app))

def initial(result:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Observe.Snapshot>)) -> IO(Unit):
  match result:
    case (app,(instance,Done{Observe.Snapshot{[],[],_,_,[]}})):
      do IO<Unit>:
        IO.print("before-tick entities=0 admitted=0")
        repeated(app => _ => repeated(app => instance => ticks(8n,1,app,instance,[],Draw.DrawList{[]},[]),[],app,
          I.Active{Some{Tick.zero()},Tick.zero()}),[],app,instance)
    case _:IO.die(Unit,1,"scene must start empty before its first tick")

def main() -> IO(Unit):
  do IO<Unit>:
    app : Scene.Application() <- Scene.create(Seeds.defaults())
    initial(Observe.snapshot(app,I.Fresh{}))
