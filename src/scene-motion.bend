import Base
import ./scene-schema.bend as D
import ./components.bend as Value
import ./scene-step.bend as Step
import ./mesh-control.bend as Player
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/change-tick.bend as Tick
import ../deps/bendvy/src/ecs/component.bend as C
import ../deps/bendvy/src/ecs/capabilities.bend as Cap
import ../deps/bendvy/src/ecs/compose.bend as Q
import ../deps/bendvy/src/ecs/transaction.bend as T
import ../deps/bendvy/src/ecs/ordinary-query-declaration.bend as Decl
import ../deps/bendvy/src/ecs/ordinary-system.bend as Ordinary
import ../deps/bendvy/src/ecs/system.bend as Sys

type Mode is Data:
  Automatic{}
  Controlled{control:Player.Control}

def Frame() -> Type:Q.Frame<D.Schema,D.Store,Unit,Unit>
def Ops(H:Type) -> Type:Cap.Write<H,Value.Transform,Value.Transform> & Cap.ValueRead<H,W.Handle<D.Schema>>

def transform_declaration() -> Decl.Declaration<D.Schema,Frame(),Cap.Write<Frame(),Value.Transform,Value.Transform>>:
  Decl.write(~D.Schema,~Value.Transform,~D.Store,~Unit,~Unit,~D.TransformRest(),~Value.Transform,~D.TransformToken,~D.transform_id(),~D.transform,~D.take_transform,~D.put_transform)

def mesh_declaration() -> Decl.Declaration<D.Schema,Frame(),Unit>:
  Decl.with_component(~D.Schema,~Value.MeshRef,~D.Store,~Unit,~Unit,~D.MeshRest(),~Value.MeshRef,~D.MeshToken,~D.mesh_id(),~D.mesh,~D.take_mesh,~D.put_mesh)

def with_handle(declaration:Decl.Declaration<D.Schema,Frame(),Cap.Write<Frame(),Value.Transform,Value.Transform> & Unit>) -> Decl.Declaration<D.Schema,Frame(),Ops(Frame())>:
  Decl.Declaration{(write,_),select,clauses} = declaration
  Decl.Declaration{(write,Q.handle_read(~D.Schema,~D.Store,~Unit,~Unit)),select,clauses}

def declaration() -> Decl.Declaration<D.Schema,Frame(),Ops(Frame())>:
  with_handle(Decl.pair(~D.Schema,~Frame(),~Cap.Write<Frame(),Value.Transform,Value.Transform>,~Unit,~transform_declaration(),~mesh_declaration()))

def translate(value:Value.Transform) -> Value.Transform & Unit:Step.step(Unit{},value)

def next(mode:Mode,entity:W.Handle<D.Schema>,value:Value.Transform) -> Maybe<&2,Value.Transform>:
  match mode:
    case Automatic{}:Player.moved(translate(value))
    case Controlled{state}:Player.decide(state,entity,value)

def write(~H:Type,~cap:Cap.Write<H,Value.Transform,Value.Transform>,scope:H,value:Maybe<&2,Value.Transform>) -> H & (T.Outcome<String> & Unit):
  match value:
    case None{}:(scope,(T.Success{},Unit{}))
    case Some{value}:(Cap.set(~H,~Value.Transform,~Value.Transform,~cap,scope,value),(T.Success{},Unit{}))

def current(~H:Type,~cap:Cap.Write<H,Value.Transform,Value.Transform>,mode:Mode,entity:W.Handle<D.Schema>,result:H & C.Access<Value.Transform>) -> H & (T.Outcome<String> & Unit):
  match result:
    case (scope,C.Found{value}):write(~H,~cap,scope,next(mode,entity,value))
    case (scope,_):(scope,(T.Failure{"transform read refused"},Unit{}))

def identified(~H:Type,~cap:Cap.Write<H,Value.Transform,Value.Transform>,mode:Mode,result:H & W.Handle<D.Schema>) -> H & (T.Outcome<String> & Unit):
  (scope,entity) = result
  current(~H,~cap,mode,entity,Cap.get(~H,~Value.Transform,~Value.Transform,~cap,scope))

def write_cap(~H:Type,caps:Ops(H)) -> Cap.Write<H,Value.Transform,Value.Transform>:
  (write,_) = caps
  write

def handle_cap(~H:Type,caps:Ops(H)) -> Cap.ValueRead<H,W.Handle<D.Schema>>:
  (_,handle) = caps
  handle

def body(~H:Type,~caps:Ops(H),mode:Mode,scope:H) -> H & (T.Outcome<String> & Unit):
  identified(~H,~write_cap(~H,caps),mode,Cap.value_read(~H,~W.Handle<D.Schema>,~handle_cap(~H,caps),scope))

def Runner() -> D.World() -> (Mode & Maybe<&2,Tick.Tick>) -> Sys.Outcome<D.World(),Q.Error<String>,List<&2,Unit>>:
  Ordinary.runner(~D.Schema,~D.Store,~Unit,~Unit,~Ops,~Mode,~String,~Unit,~declaration(),~body)
def Registry() -> Type:Sys.Registry<D.Schema,D.Store,Unit,Unit,Mode & Maybe<&2,Tick.Tick>,Q.Error<String>,List<&2,Unit>,Runner()>
def Owner() -> Type:Ordinary.Owner<D.Schema,Registry()>
def define(world:D.World()) -> Ordinary.Defined<D.Schema,D.World(),Registry()>:
  Ordinary.define(~D.Schema,~D.Store,~Unit,~Unit,~Ops,~Mode,~String,~Unit,~declaration(),~body,world,"Scene movement","move")

type Execution is Type:
  Execution{owner:Owner(),world:D.World(),outcome:T.Outcome<String>}

def completed(slot:String,clauses:List<&2,Decl.Clause<D.Schema>>,result:Sys.RunResult<D.Schema,D.Store,Unit,Unit,Mode & Maybe<&2,Tick.Tick>,Q.Error<String>,List<&2,Unit>,Runner()>) -> Execution:
  match result:
    case Sys.Completed{registry,Sys.Succeeded{world,_}}:Execution{Ordinary.Owner{registry,slot,clauses},world,T.Success{}}
    case Sys.Completed{registry,Sys.Failed{world,_}}:Execution{Ordinary.Owner{registry,slot,clauses},world,T.Failure{"movement query failed"}}
    case Sys.RegistrationRejected{registry,world,_}:Execution{Ordinary.Owner{registry,slot,clauses},world,T.Failure{"movement registration refused"}}

def returned(pair:Sys.RunResult<D.Schema,D.Store,Unit,Unit,Mode & Maybe<&2,Tick.Tick>,Q.Error<String>,List<&2,Unit>,Runner()> & (String & List<&2,Decl.Clause<D.Schema>>)) -> Execution:
  (result,(slot,clauses)) = pair
  completed(slot,clauses,result)

def run(owner:Owner(),world:D.World(),mode:Mode) -> Execution:
  returned(Ordinary.run(~D.Schema,~D.Store,~Unit,~Unit,~Ops,~Mode,~String,~Unit,~declaration(),~body,owner,world,mode))

def consumed(mode:Mode) -> Mode:
  match mode:
    case Automatic{}:Automatic{}
    case Controlled{state}:Controlled{Player.consumed(state)}
