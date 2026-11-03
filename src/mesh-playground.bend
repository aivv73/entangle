import Base
import ./creation.bend as Create
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/execution-composer-schema.bend as Setup
import ./scene-schema.bend as D
import ./scene-spawn.bend as Spawn
import ./mesh-control.bend as Move
import ../deps/bendvy/src/ecs/execution-condition-registry.bend as Conditions
import ../deps/bendvy/src/ecs/execution-generalized-command-leaf.bend as Author
import ../deps/bendvy/src/ecs/execution-generalized-system-leaf.bend as Leaf
import ../deps/bendvy/src/ecs/execution-generalized-publication.bend as Publication
import ../deps/bendvy/src/ecs/execution-generalized-root-application.bend as Root
import ../deps/bendvy/src/ecs/execution-schedule.bend as Scheduled
import ../deps/bendvy/src/ecs/execution-registry.bend as Registry
import ../deps/bendvy/src/ecs/dependency-registration.bend as Reg
import ../deps/bendvy/src/ecs/execution-command-retention.bend as Retention
import ../deps/bendvy/src/ecs/execution-retained-system.bend as Retained
import ../deps/bendvy/src/ecs/execution-deferred-settings.bend as Settings
import ../deps/bendvy/src/ecs/execution-command-system.bend as Cmd
import ../deps/bendvy/src/ecs/execution-system.bend as Sys
import ../deps/bendvy/src/ecs/execution-declaration.bend as Decl
import ../deps/bendvy/src/ecs/dependency-application.bend as App
import ../deps/bendvy/src/ecs/dependency-plan.bend as Plan
import ../deps/bendvy/src/ecs/change-tick.bend as Tick
import ../deps/bendvy/src/ecs/dependency-executor.bend as Exec
import ./scene-observe.bend as Observe
import ./components.bend as C
import ./input.bend as Input

def handle(local:Unit,_:String) -> Unit & Exec.Handling:(local,Exec.Escalate{})

def available(_:String) -> Bool:True{}

def Nodes() -> Type:Reg.Product<Spawn.Node(),Move.Node()>

def State() -> Type:App.State<D.World(),Nodes(),Unit,Unit>

def Application() -> Type:Scheduled.Scheduled<State()>

def spawn_dispatch() -> Spawn.Node() -> D.World() -> U32 -> Spawn.Node() & (D.World() & Exec.Invocation<String,
  Unit>):
  Author.dispatch(~D.Schema,~D.components(),~D.resources(),~Unit,~Spawn.route(),~Spawn.Ops,~Spawn.User,
    ~String,~Unit,~Spawn.declaration,~Spawn.body,~Spawn.compilation())

def spawn_pending() -> List<&2,U32> -> D.World() -> Spawn.Node() -> D.World() & (Spawn.Node() & Bool):
  Author.pending(~D.Schema,~D.components(),~D.resources(),~Unit,~Spawn.route(),~Spawn.Ops,~Spawn.User,
    ~String,~Unit,~Spawn.declaration,~Spawn.body)

def spawn_publish() -> List<&2,U32> -> Tick.Tick -> D.World() -> Spawn.Node() -> D.World() & Spawn.Node():
  Author.publish(~D.Schema,~D.components(),~D.resources(),~Unit,~Spawn.route(),~Spawn.Ops,~Spawn.User,
    ~String,~Unit,~Spawn.declaration,~Spawn.body,~{==},~Cmd.checked_relations(~D.Schema,~D.resources(),
    Cmd.compiled_permission(~D.Schema,~D.Columns(),~D.Resources(),~D.components(),~D.resources(),~Spawn.route(),
    ~Spawn.Ops,Spawn.compilation())),~Cmd.construction_selection(~D.Schema,~D.Columns(),~D.Resources(),
    ~D.components(),~D.resources(),~Spawn.route(),~Spawn.Ops,Spawn.compilation()))

def spawn_collect() -> List<&2,U32> -> Spawn.Node() -> Spawn.Node() & List<&2,U32>:
  Author.collect(~D.Schema,~D.components(),~D.resources(),~Unit,~Spawn.route(),~Spawn.Ops,~Spawn.User,
    ~String,~Unit,~Spawn.declaration,~Spawn.body)

def spawn_facts(node:Spawn.Node()) -> Registry.Facts<Reg.Registry<D.World(),Spawn.Node(),String,Unit,spawn_dispatch()>>:
  Registry.command(~D.World(),~Spawn.Node(),~String,~Unit,~spawn_dispatch(),Author.facts(~D.Schema,~D.components(),
    ~D.resources(),~Unit,~Spawn.route(),~Spawn.Ops,~Spawn.User,~String,~Unit,~Spawn.declaration,~Spawn.body,
    ~Spawn.compilation(),node))

def move_dispatch() -> Move.Node() -> D.World() -> U32 -> Move.Node() & (D.World() & Exec.Invocation<String,
  Unit>):
  Leaf.dispatch(~D.Schema,~D.components(),~D.resources(),~Unit,~Move.Ops,~Move.Control,~String,~Unit,~Move.kernel,
    ~Move.body,~Move.compiled())

def move_pending() -> List<&2,U32> -> D.World() -> Move.Node() -> D.World() & (Move.Node() & Bool):
  Retention.pending_none(~D.World(),~Move.Node())

def move_publish() -> List<&2,U32> -> Tick.Tick -> D.World() -> Move.Node() -> D.World() & Move.Node():
  Retention.publish_none(~D.World(),~Move.Node())

def move_collect() -> List<&2,U32> -> Move.Node() -> Move.Node() & List<&2,U32>:
  Retention.collect_none(~Move.Node())

def move_facts(node:Move.Node()) -> Registry.Facts<Reg.Registry<D.World(),Move.Node(),String,Unit,move_dispatch()>>:
  Registry.ordinary(~D.World(),~Move.Node(),~String,~Unit,~move_dispatch(),Leaf.facts(~D.Schema,~D.components(),
    ~D.resources(),~Unit,~Move.Ops,~Move.Control,~String,~Unit,~Move.kernel,~Move.body,~Move.compiled(),node))

def dispatch() -> Nodes() -> D.World() -> U32 -> Nodes() & (D.World() & Exec.Invocation<String,Unit>):
  Reg.paired_dispatch(~D.World(),~Spawn.Node(),~Move.Node(),~String,~Unit,~spawn_dispatch(),~move_dispatch())

def pending(ids:List<&2,U32>,world:D.World(),nodes:Nodes()) -> D.World() & (Nodes() & Bool):
  Retention.pending_pair(~D.World(),~Spawn.Node(),~Move.Node(),~spawn_pending(),~move_pending(),ids,world,
    nodes)

def publish(ids:List<&2,U32>,tick:Tick.Tick,world:D.World(),nodes:Nodes()) -> D.World() & Nodes():
  Retention.publish_pair(~D.World(),~Spawn.Node(),~Move.Node(),~spawn_publish(),~move_publish(),ids,tick,
    world,nodes)

def collect(ids:List<&2,U32>,nodes:Nodes()) -> Nodes() & List<&2,U32>:
  Retention.collect_pair(~Spawn.Node(),~Move.Node(),~spawn_collect(),~move_collect(),ids,nodes)

def apply(ids:List<&2,U32>,world:D.World(),nodes:Nodes()) -> D.World() & (Nodes() & List<&2,U32>):
  Publication.apply(~D.Schema,~D.Columns(),~D.Resources(),~Unit,~Nodes(),~pending,~publish,~collect,ids,
    world,nodes)

def guard_dispatch() -> Unit -> D.World() -> U32 -> Unit & (D.World() & Exec.Invocation<String,Bool>):
  Reg.empty_dispatch(~D.World(),~String,~Bool)

def run(app:Application()) -> Application() & App.Report<String,Unit>:
  Root.run(~D.Schema,~D.components(),~D.resources(),~Unit,~Nodes(),~Unit,~Unit,~String,~Unit,~dispatch(),
    ~guard_dispatch(),~handle,~apply,app)

def configure(id:U32,app:Application()) -> Application():Scheduled.configure(~State(),Settings.Settings{False{},
  True{},[],[Settings.Explicit{id,None{}}]},app)

def Compilation() -> Type:Author.Compilation(~D.Schema,~D.components(),~D.resources(),~Spawn.route(),
  ~Spawn.Ops)

def Owner() -> Type:Author.Owner(~D.Schema,~D.components(),~D.resources(),~Unit,~Spawn.route(),~Spawn.Ops,
  ~Spawn.User,~String,~Unit,~Spawn.declaration,~Spawn.body)

def Binding() -> Type:Spawn.Node()

def Peer() -> Type:Sys.Owner<D.Schema,D.Columns(),D.Columns(),D.Resources(),Unit,Move.Ops,Move.Control,String,Unit,Move.kernel,Move.body>

def PeerCompilation() -> Type:Decl.Compilation<D.Schema,D.Columns(),D.Columns(),D.Resources(),Move.Ops>

def PeerBinding() -> Type:Move.Node()

def build_unpacked(world:D.World(),left:Compilation() & Owner(),right:PeerCompilation() & Peer()) -> Application():
  match left right:
    case (lc,Cmd.Owner{Sys.Owner{ln,+lid,lname,la,lt,ll}}), (rc,Sys.Owner{rn,+rid,rname,ra,rt,rl}):
      configure(rid,Root.build(~D.Schema,~D.components(),~D.resources(),~Unit,~Nodes(),~Unit,~Unit,~String,
        ~Unit,~dispatch(),~guard_dispatch(),~available,world,Registry.paired(~D.World(),~Spawn.Node(),
        ~Move.Node(),~String,~Unit,~spawn_dispatch(),~move_dispatch(),spawn_facts(Retained.pack(Compilation(),
        Owner(),lc,Cmd.Owner{Sys.Owner{ln,lid,lname,la,lt,ll}})),move_facts(Retained.pack(PeerCompilation(),
        Peer(),rc,Sys.Owner{rn,rid,rname,ra,rt,rl}))),Conditions.compile_empty(~String,~D.World()),Unit{},
        [Plan.Edge{lid,rid}],[]))

def build(world:D.World(),left:Binding(),right:PeerBinding()) -> Application():build_unpacked(world,Retained.unpack(Compilation(),
  Owner(),left),Retained.unpack(PeerCompilation(),Peer(),right))

def peer(left:Binding(),result:PeerCompilation() & Sys.Defined<D.World(),Peer(),Move.Control>) -> IO(Application()):
  match result:
    case (compilation,Sys.Defined{world,owner}):IO.pure(Application(),build(world,left,Retained.pack(PeerCompilation(),
      Peer(),compilation,owner)))
    case _:IO.die(Application(),1,"scene movement registration refused")

def author(result:Compilation() & Sys.Defined<D.World(),Owner(),Cmd.Captures(~D.Schema,~D.components(),
  ~D.resources(),~Spawn.route(),~Spawn.User)>) -> IO(Application()):
  match result:
    case (compilation,Sys.Defined{world,owner}):peer(Retained.pack(Compilation(),Owner(),compilation,
      owner),Leaf.define_with_compilation(~D.Schema,~D.components(),~D.resources(),~Unit,~Move.Ops,~Move.Control,
      ~String,~Unit,~Move.kernel,~Move.body,Move.compiled(),world,"Mesh player",Move.Boot{}))
    case _:IO.die(Application(),1,"scene bootstrap registration refused")

def attach(seeds:List<&2,Create.Seed>,world:D.World()) -> IO(Application()):
  author(Author.define_with_compilation(~D.Schema,~D.components(),~D.resources(),~Unit,~Spawn.route(),
    ~Spawn.Ops,~Spawn.User,~String,~Unit,~Spawn.declaration,~Spawn.body,~{==},Spawn.compilation(),world,
    "Scene bootstrap",Spawn.initial(seeds)))

def created(seeds:List<&2,Create.Seed>,result:Setup.Initialized<D.Schema,D.components(),D.resources(),Unit>) -> IO(Application()):
  match result:
    case Setup.SchemaCreated{_,world}:attach(seeds,world)
    case _:IO.die(Application(),1,"scene schema creation refused")

def unbooted(seeds:List<&2,Create.Seed>) -> IO(Application()):created(seeds,D.create(W.factory()))

def distinct_systems(same:Bool) -> IO(Unit):
  match same:
    case False{}:IO.pure(Unit,Unit{})
    case True{}:IO.die(Unit,1,"scene schedule repeated a system")

def require_success(events:List<&2,Exec.Observation<String,Unit>>) -> IO(Unit):
  match events:
    case [Exec.Ran{left,_},Exec.Ran{right,_}]:distinct_systems(U32.is_eq(left,right))
    case _:IO.die(Unit,1,"scene schedule must report exactly two successful invocations")

def checked(result:Application() & App.Report<String,Unit>) -> IO(Application()):
  match result:
    case (app,App.Finished{events}):
      do IO<Application()>:
        require_success(events)
        return app
    case _:IO.die(Application(),1,"scene schedule refused")

def tick(app:Application()) -> IO(Application()):
  checked(run(app))


def owner_map(f:Move.Control -> Move.Control,owner:Peer()) -> Peer() & Unit:
  Sys.Owner{ns,id,name,access,cursor,local} = owner
  (Sys.Owner{ns,id,name,access,cursor,f(local)},Unit{})

def updated(rebuild:Move.Node() -> Application(),pair:Move.Node() & Unit) -> Application():
  (right,_) = pair
  rebuild(right)

def update(f:Move.Control -> Move.Control,app:Application()) -> Application():
  Scheduled.Scheduled{App.State{world,Reg.Product{left,right,routing},guards,handler,stateBindings},settings,bindings,deferred} = app
  updated(right => Scheduled.Scheduled{App.State{world,Reg.Product{left,right,routing},guards,handler,stateBindings},settings,bindings,deferred},Retained.map_owner(PeerCompilation(),Peer(),Unit,owner_map(f),right))

def bound(rebuild:Spawn.Node() -> Application(),initial:C.Transform,pair:Spawn.Node() & (List<&2,W.Handle<D.Schema>> & (Bool & Bool))) -> IO(Application()):
  match pair:
    case (left,([handle,_,_,_],(True{},True{}))):IO.pure(Application(),update(_ => Move.PlayerReady{handle,Move.empty(),initial,False{}},rebuild(left)))
    case _:IO.die(Application(),1,"Mesh bootstrap requires four complete admissions")

def bind(initial:C.Transform,app:Application()) -> IO(Application()):
  Scheduled.Scheduled{App.State{world,Reg.Product{left,right,routing},guards,handler,stateBindings},settings,bindings,deferred} = app
  bound(left => Scheduled.Scheduled{App.State{world,Reg.Product{left,right,routing},guards,handler,stateBindings},settings,bindings,deferred},initial,Retained.map_owner(Compilation(),Owner(),List<&2,W.Handle<D.Schema>> & (Bool & Bool),Observe.bootstrap,left))

def initialized(initial:C.Transform,app:Application()) -> IO(Application()):
  do IO<Application()>:
    app:Application() <- tick(app)
    bind(initial,app)

def create_seeds(seeds:List<&2,Create.Seed>,pending:IO(Application())) -> IO(Application()):
  match seeds:
    case Create.Seed{initial,_} <> _:
      do IO<Application()>:
        app:Application() <- pending
        initialized(initial,app)
    case _:IO.die(Application(),1,"Mesh playground needs a player")

def create(+seeds:List<&2,Create.Seed>) -> IO(Application()):
  create_seeds(seeds,unbooted(seeds))

def input(events:List<Event>,app:Application(),camera:Maybe<Create.Camera>) -> Application() & Maybe<Create.Camera>:
  match events camera:
    case _ None{}:(app,None{})
    case [] Some{c}:(app,Some{c})
    case Close{} <> _ _:(app,None{})
    case Key{27,True{}} <> _ _:(app,None{})
    case Key{+code,+down} <> rest Some{+c}:input(rest,update(Move.intent(code,down),app),Some{Bool.pick(Create.Camera,down,Input.key(code,c),c)})
    case _ <> rest Some{+c}:input(rest,app,Some{c})

def visible(active:Bool,app:Application()) -> Application():
  match active:
    case True{}:app
    case False{}:update(Move.clear,app)

def visibility(mapped:Bool,focused:Bool,app:Application()) -> Application():
  visible(mapped && focused,app)
