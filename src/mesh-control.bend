import ./time.bend as Time
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

def write_transform(~Permit:Data,~F:(Type -> Type),~H:Type,caps:Ops(Permit,F,H)) -> @-Out:Type -> H -> W.Handle<D.Schema> -> (Value.Transform -> Value.Transform & Out) -> H & Q.GeneralEdit<Value.Transform,Out>:
  match caps:
    case Q.GeneralWriter{_,modify}:modify
    case _:Out => scope => _ => unused => (scope,Q.GeneralUnchanged{unused})

def select_transform(~Permit:Data,~F:(Type -> Type),~H:Type,caps:Ops(Permit,F,H)) -> H -> H & Q.GeneralReport<D.Schema,Value.Transform>:
  match caps:
    case Q.GeneralWriter{Q.GeneralReader{query,_},_}:query
    case _:scope => (scope,Q.SelectionRefused{})

type Keys is Data:
  Keys{left:Bool,right:Bool,forward:Bool,back:Bool,up:Bool,down:Bool}

type Control is Data:
  Boot{}
  PlayerReady{handle:W.Handle<D.Schema>,keys:Keys,initial:Value.Transform,reset:Bool}

def empty() -> Keys:Keys{False{},False{},False{},False{},False{},False{}}

def key(+code:U32,down:Bool,keys:Keys) -> Keys:
  match code keys:
    case 106 Keys{l,r,f,b,u,d}:Keys{down,r,f,b,u,d}
    case 108 Keys{l,r,f,b,u,d}:Keys{l,down,f,b,u,d}
    case 105 Keys{l,r,f,b,u,d}:Keys{l,r,down,b,u,d}
    case 107 Keys{l,r,f,b,u,d}:Keys{l,r,f,down,u,d}
    case 117 Keys{l,r,f,b,u,d}:Keys{l,r,f,b,down,d}
    case 111 Keys{l,r,f,b,u,d}:Keys{l,r,f,b,u,down}
    case _ Keys{l,r,f,b,u,d}:Keys{l,r,f,b,u,d}

def axis(negative:Bool,positive:Bool) -> F32:
  match negative positive:
    case False{} True{}:0.048
    case True{} False{}:F32.neg(0.048)
    case _ _:0.0

def delta(keys:Keys) -> Value.Vec3:
  Keys{l,r,f,b,u,d} = keys
  Value.Vec3{axis(l,r),axis(d,u),axis(f,b)}

def zero(v:Value.Vec3) -> Bool:
  Value.Vec3{x,y,z} = v
  F32.is_eq(x,0.0) && F32.is_eq(y,0.0) && F32.is_eq(z,0.0)

def idle(keys:Keys) -> Bool:zero(delta(keys))

def shifted(current:Value.Transform,d:Value.Vec3) -> Value.Transform & Unit:
  Value.Transform{Value.Vec3{x,y,z},rotation,scale} = current
  Value.Vec3{dx,dy,dz} = d
  (Value.Transform{Value.Vec3{F32.max(F32.neg(3.0),F32.min(3.0,(x + dx : F32))),F32.max(F32.neg(0.2),F32.min(2.5,(y + dy : F32))),F32.max(F32.neg(3.0),F32.min(3.0,(z + dz : F32)))},rotation,scale},Unit{})

def translate(keys:Keys,current:Value.Transform) -> Value.Transform & Unit:shifted(current,delta(keys))

def intent(+code:U32,+down:Bool,control:Control) -> Control:
  match code down control:
    case _ _ Boot{}:Boot{}
    case 32 True{} PlayerReady{h,keys,t,pending}:PlayerReady{h,empty(),t,True{}}
    case _ _ PlayerReady{h,keys,t,pending}:PlayerReady{h,key(code,down,keys),t,pending}

def clear(control:Control) -> Control:
  match control:
    case Boot{}:Boot{}
    case PlayerReady{h,_,t,pending}:PlayerReady{h,empty(),t,pending}

def edited(~H:Type,control:Control,result:H & Q.GeneralEdit<Value.Transform,Unit>) -> H & (Control & Sys.Completion<String,Unit>):
  match result:
    case (scope,Q.GeneralEdited{_}):(scope,(control,Sys.Success{Unit{}}))
    case (scope,Q.GeneralUnchanged{_}):(scope,(control,Sys.BodyError{"player transform write refused",Unit{}}))

def moving(~H:Type,~modify:@-Out:Type -> H -> W.Handle<D.Schema> -> (Value.Transform -> Value.Transform & Out) -> H & Q.GeneralEdit<Value.Transform,Out>,scope:H,+h:W.Handle<D.Schema>,+keys:Keys,+initial:Value.Transform,stop:Bool) -> H & (Control & Sys.Completion<String,Unit>):
  match stop:
    case True{}:(scope,(PlayerReady{h,keys,initial,False{}},Sys.Success{Unit{}}))
    case False{}:edited(~H,PlayerReady{h,keys,initial,False{}},modify(Unit,scope,h,translate(keys)))

def control(~H:Type,~modify:@-Out:Type -> H -> W.Handle<D.Schema> -> (Value.Transform -> Value.Transform & Out) -> H & Q.GeneralEdit<Value.Transform,Out>,scope:H,state:Control) -> H & (Control & Sys.Completion<String,Unit>):
  match state:
    case Boot{}:(scope,(Boot{},Sys.Success{Unit{}}))
    case PlayerReady{+h,+keys,+initial,True{}}:edited(~H,PlayerReady{h,empty(),initial,False{}},modify(Unit,scope,h,_ => (initial,Unit{})))
    case PlayerReady{+h,+keys,+initial,False{}}:
      moving(~H,~modify,scope,h,keys,initial,idle(keys))

def selected(~H:Type,~modify:@-Out:Type -> H -> W.Handle<D.Schema> -> (Value.Transform -> Value.Transform & Out) -> H & Q.GeneralEdit<Value.Transform,Out>,state:Control,result:H & Q.GeneralReport<D.Schema,Value.Transform>) -> H & (Control & Sys.Completion<String,Unit>):
  match result:
    case (scope,Q.SelectedRows{_}):control(~H,~modify,scope,state)
    case (scope,Q.SelectionRefused{}):(scope,(state,Sys.BodyError{"player transform query refused",Unit{}}))

def body(~Permit:Data,~F:(Type -> Type),~effects:Effects.Effects<F>,~H:Type,~caps:Ops(Permit,F,H),scope:H,
  state:Control) -> F(H & (Control & Sys.Completion<String,Unit>)):
  Effects.pure(~F,(H & (Control & Sys.Completion<String,Unit>)),effects,selected(~H,~write_transform(~Permit,~F,~H,caps),state,select_transform(~Permit,~F,~H,caps)(scope)))

def compiled() -> Decl.Compilation<D.Schema,D.Columns(),C(),R(),Ops>:Program.compile_framework(~D.Schema,
  ~D.Columns(),~C(),~R(),~Ops,~kernel)

def Node() -> Type:Leaf.Node(~D.Schema,~D.components(),~D.resources(),~Unit,~Ops,~Control,~String,~Unit,
  ~kernel,~body)

def Handle() -> Data:W.Handle<D.Schema>

def pose_fields(pair:Value.Transform & Unit) -> Value.Quat & Value.Vec3:
  (Value.Transform{_,r,s},_) = pair
  (r,s)

def clock_batch(active:Bool,clock:Time.Clock,+now:Nat) -> Time.Batch:
  Bool.pick(Time.Batch,active,Time.poll(Time.Config{15n,3n},clock,now),Time.Batch{Time.start(now),0n,0n})

def boundary_tail(head:Event,pair:List<Event> & Bool) -> List<Event> & Bool:
  (tail,lost) = pair
  (head <> tail,lost)

# The pinned native backend emits this release batch even if FocusIn follows FocusOut in one poll.
def focus_boundary(events:List<Event>) -> List<Event> & Bool:
  match events:
    case Key{119,False{}} <> Key{115,False{}} <> Key{97,False{}} <> Key{100,False{}} <> Key{113,False{}} <> Key{101,False{}} <> Lost{0} <> rest:
      (Key{119,False{}} <> Key{115,False{}} <> Key{97,False{}} <> Key{100,False{}} <> Key{113,False{}} <> Key{101,False{}} <> Lost{0} <> rest,True{})
    case head <> tail:boundary_tail(head,focus_boundary(tail))
    case []:([],False{})
