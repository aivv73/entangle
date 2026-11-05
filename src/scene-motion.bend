import ../deps/bendvy/src/ecs/execution-effects.bend as Effects
import Base
import ./scene-schema.bend as D
import ./components.bend as Value
import ./scene-step.bend as Step
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/execution-composer-layout.bend as L
import ../deps/bendvy/src/ecs/execution-builder.bend as Build
import ../deps/bendvy/src/ecs/execution-query.bend as Q
import ../deps/bendvy/src/ecs/execution-query-recipe.bend as Recipe
import ../deps/bendvy/src/ecs/execution-query-matches.bend as Match
import ../deps/bendvy/src/ecs/execution-resource-program.bend as Program
import ../deps/bendvy/src/ecs/execution-system.bend as Sys
import ../deps/bendvy/src/ecs/execution-declaration.bend as Decl
import ../deps/bendvy/src/ecs/execution-generalized-system-leaf.bend as Leaf

def C() -> Type:L.columns(~D.Schema,D.components())

def R() -> Type:L.resources(~D.Schema,D.resources())

def Ops(Permit:Data,F:(Type -> Type),H:Type) -> Type:Q.GeneralWriter<D.Schema,H,Value.Transform,Value.Transform>

def any_transform(_:Maybe<&2,Value.Transform>) -> Bool:True{}

def selection(~Permit:Data,~F:(Type -> Type),~H:Type,~B:Type,~cr:Build.ComponentRead(~D.Schema,~C(),~R(),
  ~H,~B),~cw:Build.ComponentWrite(~D.Schema,~C(),~R(),~H,~B),~rr:Build.ResourceRead(~D.Schema,~C(),~R(),
  ~H,~B),~rw:Build.ResourceWrite(~D.Schema,~C(),~R(),~H,~B),~q:Build.Query(~D.Schema,~D.Columns(),~C(),
  ~R(),~F,~H,~B),~life:Build.Lifecycle(~D.Schema,~D.Columns(),~C(),~R(),~H,~B),book:B) -> B & Ops(Permit,
  F,H):
  Build.general_query(~D.Schema,~D.Columns(),~C(),~R(),~F,~D.components(),~L.InLeft{L.AtLeaf{}},~{==},
    ~{==},~{==},~Recipe.WriteRows{},~Recipe.With{L.InRight{L.InLeft{L.AtLeaf{}}}},~Match.Required{},~any_transform,
    ~H,~B,~q,book)

def program(~Permit:Data,~F:(Type -> Type),~effects:Effects.Effects<F>,~H:Type,~B:Type,~builder:Build.Builder(~D.Schema,
  ~D.Columns(),~C(),~R(),~Permit,~F,~H,~B),book:B) -> B & Ops(Permit,F,H):builder(Ops,selection(~Permit,
  ~F,~H,~B),book)

def kernel(~Permit:Data,~token:Permit,~F:(Type -> Type),~effects:Effects.Effects<F>,~request:Permit -> F(W.Reservation<D.Schema>),
  ~H:Type,~B:Type,~builder:Build.Builder(~D.Schema,~D.Columns(),~C(),~R(),~Permit,~F,~H,~B),book:B) -> B & Ops(Permit,
  F,H):Build.framework_program(~D.Schema,~D.Columns(),~C(),~R(),~Ops,~program,~Permit,~token,~F,~effects,
  ~request,~H,~B,~builder,book)

def translate(value:Value.Transform) -> Value.Transform & Unit:Step.step(Unit{},value)

def edited(~H:Type,next:H -> H & (Unit & Sys.Completion<String,Unit>),result:H & Q.GeneralEdit<Value.Transform,
  Unit>) -> H & (Unit & Sys.Completion<String,Unit>):
  match result:
    case (scope,Q.GeneralEdited{_}):next(scope)
    case (scope,Q.GeneralUnchanged{_}):(scope,(Unit{},Sys.BodyError{"transform write refused",Unit{}}))

def move_rows(~H:Type,~modify:@-Out:Type -> H -> W.Handle<D.Schema> -> (Value.Transform -> Value.Transform & Out) -> H & Q.GeneralEdit<Value.Transform,
  Out>,values:List<&2,Q.GeneralRow<D.Schema,Value.Transform>>,scope:H) -> H & (Unit & Sys.Completion<String,
  Unit>):
  match values:
    case []:(scope,(Unit{},Sys.Success{Unit{}}))
    case Q.GeneralRow{handle,_} <> rest:edited(~H,move_rows(~H,~modify,rest),modify(Unit,scope,handle,
      translate))

def selected(~H:Type,~modify:@-Out:Type -> H -> W.Handle<D.Schema> -> (Value.Transform -> Value.Transform & Out) -> H & Q.GeneralEdit<Value.Transform,
  Out>,result:H & Q.GeneralReport<D.Schema,Value.Transform>) -> H & (Unit & Sys.Completion<String,Unit>):
  match result:
    case (scope,Q.SelectedRows{values}):move_rows(~H,~modify,values,scope)
    case (scope,Q.SelectionRefused{}):(scope,(Unit{},Sys.BodyError{"transform query refused",Unit{}}))

def write_transform(~Permit:Data,~F:(Type -> Type),~H:Type,caps:Ops(Permit,F,H)) -> @-Out:Type -> H -> W.Handle<D.Schema> -> (Value.Transform -> Value.Transform & Out) -> H & Q.GeneralEdit<Value.Transform,Out>:
  match caps:
    case Q.GeneralWriter{_,modify}:modify
    case _:Out => scope => _ => unused => (scope,Q.GeneralUnchanged{unused})

def select_transform(~Permit:Data,~F:(Type -> Type),~H:Type,caps:Ops(Permit,F,H)) -> H -> H & Q.GeneralReport<D.Schema,Value.Transform>:
  match caps:
    case Q.GeneralWriter{Q.GeneralReader{query,_},_}:query
    case _:scope => (scope,Q.SelectionRefused{})

def body(~Permit:Data,~F:(Type -> Type),~effects:Effects.Effects<F>,~H:Type,~caps:Ops(Permit,F,H),scope:H,
  _:Unit) -> F(H & (Unit & Sys.Completion<String,Unit>)):
  Effects.pure(~F,(H & (Unit & Sys.Completion<String,Unit>)),effects,selected(~H,~write_transform(~Permit,
    ~F,~H,caps),select_transform(~Permit,~F,~H,caps)(scope)))

def compiled() -> Decl.Compilation<D.Schema,D.Columns(),C(),R(),Ops>:Program.compile_framework(~D.Schema,
  ~D.Columns(),~C(),~R(),~Ops,~kernel)

def Node() -> Type:Leaf.Node(~D.Schema,~D.components(),~D.resources(),~Unit,~Ops,~Unit,~String,~Unit,
  ~kernel,~body)
