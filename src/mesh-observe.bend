import Base
import ./scene-draw.bend as Draw
import ./scene-schema.bend as D
import ./mesh-playground.bend as Scene
import ./scene-observe.bend as Observe
import ./scene-spawn.bend as Spawn
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/inspector.bend as I
import ../deps/bendvy/src/ecs/execution-schedule.bend as Scheduled
import ../deps/bendvy/src/ecs/dependency-application.bend as App
import ../deps/bendvy/src/ecs/dependency-registration.bend as Reg
import ../deps/bendvy/src/ecs/execution-retained-system.bend as Retained

def observed(rebuild:D.World() -> Scene.Application(),live:List<&2,W.Handle<D.Schema>>,admitted:List<&2,
  W.Handle<D.Schema>>,exhausted:Bool,clean:Bool,result:I.Observed<D.Schema,D.Columns(),D.Resources(),
  Unit,Unit,List<&2,Observe.Row>>) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Observe.Snapshot>):
  match result:
    case I.Observed{world,instance,Done{rows}}:(rebuild(world),(instance,Done{Observe.Snapshot{live,admitted,
      exhausted,clean,rows}}))
    case I.Observed{world,instance,Fail{error}}:(rebuild(world),(instance,Fail{error}))

def live_observed(rebuild:D.World() -> Scene.Application(),admitted:List<&2,W.Handle<D.Schema>>,exhausted:Bool,
  clean:Bool,instance:I.Instance<D.Schema>,result:D.World() & List<&2,W.Handle<D.Schema>>) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,
  &2,Unit,Observe.Snapshot>):
  match result:
    case (world,live):observed(rebuild,live,admitted,exhausted,clean,I.passive(~D.Schema,~D.Columns(),
      ~D.Resources(),~Unit,~Observe.Ops,~Unit,~Unit,~(List<&2,Observe.Row>),~Observe.plan(),~Observe.body(~Observe.Row,~Observe.row),instance,Unit{},world))

def bootstrap_observed(rebuild:Spawn.Node() -> D.World() -> Scene.Application(),world:D.World(),instance:I.Instance<D.Schema>,
  result:Spawn.Node() & (List<&2,W.Handle<D.Schema>> & (Bool & Bool))) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,
  &2,Unit,Observe.Snapshot>):
  match result:
    case (left,(admitted,(exhausted,clean))):live_observed(rebuild(left),admitted,exhausted,clean,instance,
      W.handles(~D.Schema,~D.Columns(),~D.Resources(),~Unit,world))

def snapshot(app:Scene.Application(),instance:I.Instance<D.Schema>) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,
  &2,Unit,Observe.Snapshot>):
  match app:
    case Scheduled.Scheduled{App.State{world,Reg.Product{left,right,routing},guards,handler,stateBindings},settings,bindings,deferred}:
      bootstrap_observed(left => world => Scheduled.Scheduled{App.State{world,Reg.Product{left,right,
        routing},guards,handler,stateBindings},settings,bindings,deferred},world,instance,Retained.map_owner(Scene.Compilation(),
        Scene.Owner(),List<&2,W.Handle<D.Schema>> & (Bool & Bool),Observe.bootstrap,left))

def drawn(rebuild:D.World() -> Scene.Application(),result:I.Observed<D.Schema,D.Columns(),D.Resources(),
  Unit,Unit,List<&2,Draw.DrawItem>>) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Draw.DrawList>):
  match result:
    case I.Observed{world,instance,Done{items}}:(rebuild(world),(instance,Done{Draw.DrawList{items}}))
    case I.Observed{world,instance,Fail{error}}:(rebuild(world),(instance,Fail{error}))

def draw_list(app:Scene.Application(),instance:I.Instance<D.Schema>) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Draw.DrawList>):
  match app:
    case Scheduled.Scheduled{App.State{world,nodes,guards,handler,stateBindings},settings,bindings,deferred}:
      drawn(world => Scheduled.Scheduled{App.State{world,nodes,guards,handler,stateBindings},settings,
        bindings,deferred},I.passive(~D.Schema,~D.Columns(),~D.Resources(),~Unit,~Observe.Ops,~Unit,~Unit,
        ~(List<&2,Draw.DrawItem>),~Observe.plan(),~Observe.body(~Draw.DrawItem,~Observe.draw_item),instance,Unit{},world))
