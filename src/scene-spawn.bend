import ../deps/bendvy/src/ecs/execution-effects.bend as Effects
import Base
import ./scene-schema.bend as D
import ./components.bend as V
import ../deps/bendvy/src/ecs/owner-product.bend as Product
import ../deps/bendvy/src/ecs/execution-composer-layout.bend as L
import ../deps/bendvy/src/ecs/execution-command-system.bend as Cmd
import ../deps/bendvy/src/ecs/execution-command-local.bend as Local
import ../deps/bendvy/src/ecs/execution-command-permission.bend as Permission
import ../deps/bendvy/src/ecs/execution-command-buffer.bend as Buffer
import ../deps/bendvy/src/ecs/execution-command-removed.bend as Removed
import ../deps/bendvy/src/ecs/execution-builder.bend as Build
import ../deps/bendvy/src/ecs/execution-resource-program.bend as Program
import ../deps/bendvy/src/ecs/execution-declaration.bend as Decl
import ../deps/bendvy/src/ecs/execution-system.bend as Sys
import ../deps/bendvy/src/ecs/execution-generalized-command-leaf.bend as Author
import ../deps/bendvy/src/ecs/world.bend as W

def route() -> L.Route:L.InLeft{L.AtLeaf{}}

def Ops(Permit:Data,F:(Type -> Type),H:Type,Q:Type) -> Type:Permission.EntityCommands<Q,D.Schema,D.components(),Permit,F>

type User is Type:
  User{seeds:List<Removed.Removed(D.components())>,handles:List<&2,W.Handle<D.Schema>>,returned:List<Removed.Removed(D.components())>}

def seed(+index:U32) -> Removed.Removed(D.components()):
  +i = U32.to_f32(index)
  Product.Owner{Some{V.Transform{V.Vec3{i,F32.mul(2.0,i),F32.neg(i)},V.Quat{0.0,0.0,0.6,0.8},V.Vec3{2.0,3.0,4.0}}},Some{V.MeshRef{7}}}

def seeds(count:Nat,+index:U32) -> List<Removed.Removed(D.components())>:
  match count:
    case 0n:[]
    case 1n++rest:seed(index) <> seeds(rest,U32.add(index,1))

def initial() -> User:User{seeds(100n,0),[],[]}

def granted(~Permit:Data,~F:(Type -> Type),~H:Type,~Q:Type,-B:Type,-K:Type,book:B,result:K & Ops(Permit,
  F,H,Q)) -> B & (K & Ops(Permit,F,H,Q)):(book,result)

def declaration(~Permit:Data,~F:(Type -> Type),~effects:Effects.Effects<F>,~H:Type,~Q:Type,~commands:Local.Commands<Q,
  D.Schema,V.Transform>,~B:Type,~builder:Build.Builder(~D.Schema,~D.Columns(),~D.Columns(),~D.Resources(),
  ~Permit,~F,~H,~B),~K:Type,~entity:Permission.Grant(~D.Schema,~D.components(),~Permit,~F,~Q,~K),~relations:Permission.RelationGrant(~D.Schema,
  ~D.resources(),~Q,~K),~scopes:Permission.ScopeGrant(~D.Schema,~D.resources(),~Q,~K),book:B,permission:K) -> B & (K & Ops(Permit,
  F,H,Q)):
  granted(~Permit,~F,~H,~Q,B,K,book,Permission.entity(~D.Schema,~D.components(),~Permit,~F,~Q,~K,~entity,
    permission))

def seeded(~Permit:Data,~F:(Type -> Type),~effects:Effects.Effects<F>,~H:Type,~Q:Type,seeds:List<Removed.Removed(D.components())>,
  scope:H,queue:Q,handles:List<&2,W.Handle<D.Schema>>) -> F(H & (Q & (User & Sys.Completion<String,Unit>))):
  Effects.pure(~F,(H & (Q & (User & Sys.Completion<String,Unit>))),effects,(scope,(queue,(User{seeds,
    handles,[]},Sys.Success{Unit{}}))))

def admitted(~F:(Type -> Type),~H:Type,~Q:Type,next:H -> Q -> List<&2,W.Handle<D.Schema>> -> List<Removed.Removed(D.components())> -> F(H & (Q & (User & Sys.Completion<String,
  Unit>))),scope:H,handles:List<&2,W.Handle<D.Schema>>,result:Q & Buffer.SpawnAdmission<D.Schema,Removed.Removed(D.components())>) -> F(H & (Q & (User & Sys.Completion<String,
  Unit>))):
  match result:
    case (queue,Buffer.SpawnQueued{handle}):next(scope,queue,handle <> handles,[])
    case (queue,Buffer.SpawnRejected{bundle,_}):next(scope,queue,handles,[bundle])

def queue_seeds(~Permit:Data,~F:(Type -> Type),~effects:Effects.Effects<F>,~H:Type,~Q:Type,~spawn:Q -> Removed.Removed(D.components()) -> F(Q & Buffer.SpawnAdmission<D.Schema,
  Removed.Removed(D.components())>),seeds:List<Removed.Removed(D.components())>,scope:H,queue:Q,handles:List<&2,
  W.Handle<D.Schema>>,returned:List<Removed.Removed(D.components())>) -> F(H & (Q & (User & Sys.Completion<String,
  Unit>))):
  match seeds returned:
    case [], []:seeded(~Permit,~F,~effects,~H,~Q,[],scope,queue,List.reverse(&2,W.Handle<D.Schema>,handles))
    case seed <> rest, []:Effects.bind(~F,(Q & Buffer.SpawnAdmission<D.Schema,Removed.Removed(D.components())>),
      (H & (Q & (User & Sys.Completion<String,Unit>))),effects,spawn(queue,seed),result => admitted(~F,
      ~H,~Q,queue_seeds(~Permit,~F,~effects,~H,~Q,~spawn,rest),scope,handles,result))
    case seeds, returned:Effects.pure(~F,(H & (Q & (User & Sys.Completion<String,Unit>))),effects,(scope,
      (queue,(User{seeds,handles,returned},Sys.BodyError{"spawn reservation refused",Unit{}}))))

def body(~Permit:Data,~F:(Type -> Type),~effects:Effects.Effects<F>,~H:Type,~Q:Type,~caps:Ops(Permit,
  F,H,Q),~commands:Local.Commands<Q,D.Schema,V.Transform>,scope:H,queue:Q,user:User) -> F(H & (Q & (User & Sys.Completion<String,
  Unit>))):
  match user:
    case User{[],handles,[]}:seeded(~Permit,~F,~effects,~H,~Q,[],scope,queue,handles)
    case User{seeds,handles,[]}:queue_seeds(~Permit,~F,~effects,~H,~Q,~Permission.spawn_field(~Q,~D.Schema,
      ~D.components(),~Permit,~F,caps),seeds,scope,queue,handles,[])
    case user:Effects.pure(~F,(H & (Q & (User & Sys.Completion<String,Unit>))),effects,(scope,(queue,
      (user,Sys.BodyError{"spawn bundle retained after refusal",Unit{}}))))

def kernel(~Permit:Data,~token:Permit,~F:(Type -> Type),~effects:Effects.Effects<F>,~request:Permit -> F(W.Reservation<D.Schema>),
  ~H:Type,~B:Type,~builder:Build.Builder(~D.Schema,~D.Columns(),~D.Columns(),~D.Resources(),~Permit,~F,
  ~H,~B),book:B) -> B & Cmd.ScopedOps(~D.Schema,~D.components(),~D.resources(),~route(),~Ops,Permit,F,
  H):
  Cmd.program_for_buffer(~D.Schema,~D.Columns(),~D.Resources(),~D.components(),~D.resources(),~route(),
    ~Ops,~declaration,~Permit,~token,~F,~effects,~request,~H,~B,~builder,book)

def compilation() -> Decl.Compilation<D.Schema,D.Columns(),D.Columns(),D.Resources(),Cmd.ScopedOps(~D.Schema,
  ~D.components(),~D.resources(),~route(),~Ops)>:
  Program.compile_framework(~D.Schema,~D.Columns(),~D.Columns(),~D.Resources(),~Cmd.ScopedOps(~D.Schema,
    ~D.components(),~D.resources(),~route(),~Ops),~kernel)

def Node() -> Type:Author.Node(~D.Schema,~D.components(),~D.resources(),~Unit,~route(),~Ops,~User,~String,
  ~Unit,~declaration,~body)
