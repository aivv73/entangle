import Base
import ./scene-schema.bend as D
import ./creation.bend as Create
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/system.bend as Sys
import ../deps/bendvy/src/ecs/transaction.bend as T
import ../deps/bendvy/src/ecs/commands.bend as Cmd
import ../deps/bendvy/src/ecs/trace-facts.bend as Trace

type User is Data:
  User{seeds:List<&2,Create.Seed>,handles:List<&2,W.Handle<D.Schema>>,returned:List<&2,Create.Seed>}

def initial(seeds:List<&2,Create.Seed>) -> User:User{seeds,[],[]}

def installed(next:D.World() -> D.World(),pair:D.World() & Bool) -> D.World():
  (world,_) = pair
  next(world)

# The deferred command owns its seed. Activation precedes these canonical
# structural writes; no second scene store owns component values.
def populate(world:D.World(),entity:W.Handle<D.Schema>,seed:Create.Seed) -> D.World():
  Create.Seed{transform,mesh,spatial} = seed
  +entity:W.Handle<D.Schema> = entity
  installed(w => installed(w => w,D.install_spatial(w,entity,spatial)),D.install_mesh(installed(w => w,D.install_transform(world,entity,transform)),entity,mesh))

def reserved(next:T.Tx<D.World(),Unit> -> List<&2,W.Handle<D.Schema>> -> T.Tx<D.World(),Unit> & (User & T.Outcome<String>),rest:List<&2,Create.Seed>,handles:List<&2,W.Handle<D.Schema>>,seed:Create.Seed,pair:T.Tx<D.World(),Unit> & W.Reservation<D.Schema>) -> T.Tx<D.World(),Unit> & (User & T.Outcome<String>):
  match pair:
    case (tx,W.Reserved{handle}):next(tx,handle <> handles)
    case (tx,W.ReservationRejected{_}):(tx,(User{rest,handles,[seed]},T.Failure{"spawn reservation refused"}))

def queued(seeds:List<&2,Create.Seed>,tx:T.Tx<D.World(),Unit>,handles:List<&2,W.Handle<D.Schema>>) -> T.Tx<D.World(),Unit> & (User & T.Outcome<String>):
  match seeds:
    case []:(tx,(User{[],List.reverse(&2,W.Handle<D.Schema>,handles),[]},T.Success{}))
    case +seed <> +rest:reserved(tx => hs => queued(rest,tx,hs),rest,handles,seed,Cmd.tx_spawn(~D.Schema,~D.Store,~Unit,~Unit,~Create.Seed,~populate,tx,seed))

def finished(user:User,result:T.Returned<D.World(),String>) -> Sys.Outcome<D.World(),String,User>:
  match result:
    case T.Returned{world,T.Success{}}:Sys.Succeeded{world,user}
    case T.Returned{world,T.Failure{error}}:Sys.Failed{world,error}

def staged(pair:T.Tx<D.World(),Unit> & (User & T.Outcome<String>)) -> Sys.Outcome<D.World(),String,User>:
  (tx,(user,outcome)) = pair
  finished(user,Cmd.tx_finish(~D.Schema,~D.Store,~Unit,~Unit,~String,tx,outcome))

def runner(world:D.World(),user:User) -> Sys.Outcome<D.World(),String,User>:
  match user:
    case User{[],handles,[]}:Sys.Succeeded{world,User{[],handles,[]}}
    case User{seeds,_,[]}:staged(queued(seeds,T.Tx{world,[],[],[],Trace.Off{}},[]))
    case _:Sys.Failed{world,"spawn bundle retained after refusal"}

def Registry() -> Type:Sys.Registry<D.Schema,D.Store,Unit,Unit,User,String,User,runner>

def define(world:D.World()) -> Sys.RegistrationResult<D.Schema,D.Store,Unit,Unit,User,String,User,runner>:
  Sys.register(~D.Schema,~D.Store,~Unit,~Unit,~User,~String,~User,~runner,world,"Scene bootstrap",["spawn","transform","mesh-ref","spatial"])

def run(owner:Registry(),world:D.World(),user:User) -> Sys.RunResult<D.Schema,D.Store,Unit,Unit,User,String,User,runner>:
  Sys.run(~D.Schema,~D.Store,~Unit,~Unit,~User,~String,~User,~runner,owner,world,user)
