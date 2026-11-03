import Base
import ../src/headless.bend as Headless
import ../src/scene.bend as Scene
import ../src/scene-schema.bend as D
import ../src/scene-observe.bend as Observe
import ../src/scene-draw.bend as Draw
import ../examples/scene.bend as Reference
import ../deps/bendvy/src/ecs/inspector.bend as I
import ../deps/bendvy/src/ecs/change-tick.bend as Tick
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/entity-key.bend as Key

type Evidence is Type:
  Evidence{app:Scene.Application(),instance:I.Instance<D.Schema>,completed:U32,
    baseline:List<&2,Reference.Identity>,previous:List<&2,Observe.Row>,retained:Draw.DrawList}

def drawn(completed:U32,baseline:List<&2,Reference.Identity>,+values:List<&2,Observe.Row>,
  result:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Draw.DrawList>)) -> IO(Evidence):
  match result:
    case (app,(instance,Done{Draw.DrawList{+items}})):
      do IO<Evidence>:
        Reference.require(Reference.drawing_equal(items,values),"headless drawing differs from scene")
        return Evidence{app,instance,completed,baseline,values,Draw.DrawList{items}}
    case _:IO.die(Evidence,1,"headless drawing refused")

def drawing(completed:U32,baseline:List<&2,Reference.Identity>,+values:List<&2,Observe.Row>,
  app:Scene.Application(),instance:I.Instance<D.Schema>) -> IO(Evidence):
  drawn(completed,baseline,values,Observe.draw_list(app,instance))

def captured(+completed:U32,baseline:List<&2,Reference.Identity>,+previous:List<&2,Observe.Row>,
  +receipts:List<&2,W.Handle<D.Schema>>,
  result:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Observe.Snapshot>)) -> IO(Evidence):
  match result:
    case (app,(instance,Done{+snapshot})):
      Observe.Snapshot{+live,+admitted,_,_,+values} = snapshot
      +baseline = Reference.baseline_at(baseline,admitted)
      do IO<Evidence>:
        Reference.validate(completed,baseline,snapshot)
        Reference.require(Reference.same(receipts,admitted) && Reference.same(receipts,live) &&
          Reference.same(receipts,Reference.row_handles(values)),"headless receipt identities differ")
        Reference.recurrence(values,previous,baseline,U32.is_eq(completed,1))
        drawn : Evidence <- drawing(completed,baseline,values,app,instance)
        IO.pure(Evidence,drawn)
    case _:IO.die(Evidence,1,"headless production observation refused")

def inspected(completed:U32,baseline:List<&2,Reference.Identity>,previous:List<&2,Observe.Row>,
  instance:I.Instance<D.Schema>,result:Scene.Application() & Reference.Inventory) -> IO(Evidence):
  (app,Reference.Inventory{Reference.Bootstrap{spawn,+receipts,valid,clean,exhausted},move,_,drained}) = result
  do IO<Evidence>:
    Reference.require(valid && clean && exhausted && drained && Bool.not(U32.is_eq(spawn,move)) &&
      Nat.is_eq(List.length(&2,W.Handle<D.Schema>,receipts),100n),"headless retained inventory differs")
    captured(completed,baseline,previous,receipts,Observe.snapshot(app,instance))

def tick_returned(+completed:U32,baseline:List<&2,Reference.Identity>,+previous:List<&2,Observe.Row>,
  items:List<&2,Draw.DrawItem>,instance:I.Instance<D.Schema>,before:Tick.Tick,
  result:Scene.Application() & Tick.Tick) -> IO(Evidence):
  (app,after) = result
  do IO<Evidence>:
    Reference.require(Nat.is_lt(Tick.total(before),Tick.total(after)),"production tick did not advance world clock")
    Reference.require(Reference.drawing_equal(items,previous),"detached drawing changed across production tick")
    inspected(U32.inc(completed),baseline,previous,instance,Reference.inventory(app))

def tick_clock(completed:U32,baseline:List<&2,Reference.Identity>,previous:List<&2,Observe.Row>,
  items:List<&2,Draw.DrawItem>,instance:I.Instance<D.Schema>,result:Scene.Application() & Tick.Tick) -> IO(Evidence):
  (app,before) = result
  do IO<Evidence>:
    app : Scene.Application() <- Scene.tick(app)
    tick_returned(completed,baseline,previous,items,instance,before,Reference.app_clock(app))

def checked_tick(state:Evidence) -> IO(Evidence):
  Evidence{app,instance,completed,baseline,previous,Draw.DrawList{items}} = state
  tick_clock(completed,baseline,previous,items,instance,Reference.app_clock(app))

def unchanged_snapshot(completed:U32,baseline:List<&2,Reference.Identity>,snapshot:Observe.Snapshot) -> IO(Unit):
  match completed snapshot:
    case 0, Observe.Snapshot{[],[],False{},False{},[]}:IO.pure(Unit,Unit{})
    case 0, _:IO.die(Unit,1,"zero batch bootstrapped scene")
    case completed, snapshot:Reference.validate(completed,baseline,snapshot)

def initial(info:Reference.Inventory,result:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Observe.Snapshot>)) -> IO(Evidence):
  match result:
    case (app,(instance,Done{+snapshot})):
      do IO<Evidence>:
        Reference.require_start(1,[],info,snapshot)
        unchanged_snapshot(0,[],snapshot)
        IO.pure(Evidence,Evidence{app,instance,0,[],[],Draw.DrawList{[]}})
    case _:IO.die(Evidence,1,"headless creation must precede bootstrap")

def sync_key(values:List<&2,U32>) -> String:
  match values:
    case []:""
    case id <> rest:U32.show(id) ++ "/" ++ sync_key(rest)

def receipt_key(handle:W.Handle<D.Schema>) -> String:
  W.Handle{namespace,Key.EntityKey{index,generation}} = handle
  U32.show(namespace) ++ "/" ++ U32.show(index) ++ "/" ++ U32.show(generation)

def receipt_keys(values:List<&2,W.Handle<D.Schema>>) -> String:
  match values:
    case []:""
    case handle <> rest:receipt_key(handle) ++ ";" ++ receipt_keys(rest)

def inventory_key(info:Reference.Inventory) -> String:
  Reference.Inventory{Reference.Bootstrap{id,+receipts,valid,clean,exhausted},move,syncs,drained} = info
  U32.show(id) ++ "/" ++ U32.show(move) ++ "/" ++ Nat.show(List.length(&2,W.Handle<D.Schema>,receipts)) ++
    "/" ++ Bool.show(valid) ++ Bool.show(clean) ++ Bool.show(exhausted) ++ Bool.show(drained) ++
    sync_key(syncs) ++ "/" ++ receipt_keys(receipts)

def fingerprint_instance(app:Scene.Application(),completed:U32,baseline:List<&2,Reference.Identity>,
  previous:List<&2,Observe.Row>,retained:Draw.DrawList,prefix:String,result:I.Instance<D.Schema> & String) -> Evidence & String:
  (instance,key) = result
  (Evidence{app,instance,completed,baseline,previous,retained},prefix ++ "/" ++ key)

def fingerprint_inventory(instance:I.Instance<D.Schema>,completed:U32,baseline:List<&2,Reference.Identity>,
  previous:List<&2,Observe.Row>,retained:Draw.DrawList,clock:Tick.Tick,
  result:Scene.Application() & Reference.Inventory) -> Evidence & String:
  (app,info) = result
  fingerprint_instance(app,completed,baseline,previous,retained,Nat.show(Tick.total(clock)) ++ "/" ++
    inventory_key(info),Reference.instance_key(instance))

def fingerprint_clock(instance:I.Instance<D.Schema>,completed:U32,baseline:List<&2,Reference.Identity>,
  previous:List<&2,Observe.Row>,retained:Draw.DrawList,result:Scene.Application() & Tick.Tick) -> Evidence & String:
  (app,clock) = result
  fingerprint_inventory(instance,completed,baseline,previous,retained,clock,Reference.inventory(app))

def fingerprint(state:Evidence) -> Evidence & String:
  Evidence{app,instance,completed,baseline,previous,retained} = state
  fingerprint_clock(instance,completed,baseline,previous,retained,Reference.app_clock(app))

def reobserved(+completed:U32,+baseline:List<&2,Reference.Identity>,+previous:List<&2,Observe.Row>,retained:Draw.DrawList,
  result:Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Observe.Snapshot>)) -> IO(Evidence):
  Draw.DrawList{+items} = retained
  match result:
    case (app,(instance,Done{+snapshot})):
      Observe.Snapshot{_,_,_,_,+values} = snapshot
      do IO<Evidence>:
        Reference.require(Reference.drawing_equal(items,values) && Reference.drawing_equal(items,previous),
          "zero batch changed snapshot or detached drawing")
        unchanged_snapshot(completed,baseline,snapshot)
        return Evidence{app,instance,completed,baseline,values,Draw.DrawList{items}}
    case _:IO.die(Evidence,1,"zero batch observation refused")

def reobserve(state:Evidence) -> IO(Evidence):
  Evidence{app,instance,+completed,+baseline,+previous,retained} = state
  reobserved(completed,baseline,previous,retained,Observe.snapshot(app,instance))

def zero_after(before:String,result:Evidence & String) -> IO(Evidence):
  (state,after) = result
  do IO<Evidence>:
    Reference.require(String.eq(before,after),"zero batch changed clock, inspector, or retained owners")
    reobserve(state)

def zero_before(result:Evidence & String) -> IO(Evidence):
  (state,before) = result
  do IO<Evidence>:
    state : Evidence <- Headless.advance(~Evidence,~checked_tick,0n,state)
    zero_after(before,fingerprint(state))

def zero(state:Evidence) -> IO(Evidence):zero_before(fingerprint(state))

def finish(state:Evidence) -> IO(Unit):
  Evidence{app,instance,completed,baseline,previous,retained} = state
  do IO<Unit>:
    Reference.require(U32.is_eq(completed,8),"split batch returned wrong ordinal")
    Reference.repeated(app => instance => IO.pure(Unit,Unit{}),previous,app,instance)

def created(result:Scene.Application() & Reference.Inventory) -> IO(Evidence):
  (app,info) = result
  initial(info,Observe.snapshot(app,I.Fresh{}))

def replay(+split:Nat) -> IO(Unit):
  do IO<Unit>:
    app : Scene.Application() <- Scene.create()
    state : Evidence <- created(Reference.inventory(app))
    state : Evidence <- zero(state)
    state : Evidence <- Headless.advance(~Evidence,~checked_tick,split,state)
    state : Evidence <- zero(state)
    state : Evidence <- Headless.advance(~Evidence,~checked_tick,Nat.sub(8n,split),state)
    state : Evidence <- zero(state)
    finish(state)
    IO.print("split=" ++ Nat.show(split) ++ "+" ++ Nat.show(Nat.sub(8n,split)) ++ " production=8 verified")

def splits(remaining:Nat,+split:Nat) -> IO(Unit):
  match remaining:
    case 0n:IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        replay(split)
        splits(rest,1n+split)

def main() -> IO(Unit):
  do IO<Unit>:
    splits(9n,0n)
    IO.print("Headless production batching, zero, ownership, receipts, transform bits and detached retention verified.")
