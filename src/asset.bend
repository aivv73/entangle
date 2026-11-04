import Base

# Source data only. A cache scope must be unique for as long as its handles exist.
type Handle<-A:Data> is Data:
  Handle{scope:String,id:Nat}
type Error is Data:
  Error{code:U32,message:String}
type State<-A:Data> is Data:
  Loading{}
  Loaded{value:A}
  Failed{error:Error}
type Entry<-A:Data> is Data:
  Entry{key:String,id:Nat,state:State<A>}
type Cache<-A:Data> is Type:
  Cache{scope:String,next:Nat,entries:List<&2,Entry<A>>}

def new(-A:Data,scope:String) -> Cache<A>:
  Cache{scope,0n,[]}

def find_key(-A:Data,entries:List<&2,Entry<A>>,+key:String) -> Maybe<Nat>:
  match entries:
    case []:None{}
    case Entry{other,id,_} <> rest:
      Bool.pick(Maybe<Nat>,String.eq(key,other),Some{id},find_key(A,rest,key))

def requested(-A:Data,+scope:String,+next:Nat,entries:List<&2,Entry<A>>,key:String,found:Maybe<Nat>) -> Cache<A> & Handle<A>:
  match found:
    case Some{id}:(Cache{scope,next,entries},Handle{scope,id})
    case None{}:(Cache{scope,1n+next,Entry{key,next,Loading{}} <> entries},Handle{scope,next})

# Requests never perform IO, including repeated requests in Loading or Failed.
def request(-A:Data,cache:Cache<A>,+key:String) -> Cache<A> & Handle<A>:
  Cache{scope,next,+entries} = cache
  requested(A,scope,next,entries,key,find_key(A,entries,key))

def find_id(-A:Data,entries:List<&2,Entry<A>>,+id:Nat) -> Maybe<&2,State<A>>:
  match entries:
    case []:None{}
    case Entry{_,other,state} <> rest:
      Bool.pick(Maybe<&2,State<A>>,Nat.is_eq(id,other),Some{state},find_id(A,rest,id))

def lookup_scoped(-A:Data,cache:Cache<A>,id:Nat,matching:Bool) -> Cache<A> & Maybe<&2,State<A>>:
  match cache matching:
    case cache False{}:(cache,None{})
    case Cache{scope,next,+entries} True{}:
      (Cache{scope,next,entries},find_id(A,entries,id))

def lookup(-A:Data,cache:Cache<A>,handle:Handle<A>) -> Cache<A> & Maybe<&2,State<A>>:
  Cache{+scope,next,entries} = cache
  Handle{other,id} = handle
  lookup_scoped(A,Cache{scope,next,entries},id,String.eq(scope,other))

def pending_state(-A:Data,state:State<A>,key:String) -> Maybe<String>:
  match state:
    case Loading{}:Some{key}
    case Loaded{_}:None{}
    case Failed{_}:None{}

def pending(-A:Data,entries:List<&2,Entry<A>>,+id:Nat) -> Maybe<String>:
  match entries:
    case []:None{}
    case Entry{key,other,state} <> rest:
      Bool.pick(Maybe<String>,Nat.is_eq(id,other),pending_state(A,state,key),pending(A,rest,id))

def settled(-A:Data,result:Result<&2,&2,Error,A>) -> State<A>:
  match result:
    case Done{value}:Loaded{value}
    case Fail{error}:Failed{error}

def settle(-A:Data,state:State<A>,result:Result<&2,&2,Error,A>) -> State<A>:
  match state:
    case Loading{}:settled(A,result)
    case Loaded{value}:Loaded{value}
    case Failed{error}:Failed{error}

def settle_matching(-A:Data,state:State<A>,result:Result<&2,&2,Error,A>,matching:Bool) -> State<A>:
  match matching:
    case True{}:settle(A,state,result)
    case False{}:state

# Only an extant Loading entry can transition; no completion inserts an entry.
def complete(-A:Data,entries:List<&2,Entry<A>>,+id:Nat,+result:Result<&2,&2,Error,A>) -> List<&2,Entry<A>>:
  match entries:
    case []:[]
    case Entry{key,+other,state} <> rest:
      Entry{key,other,settle_matching(A,state,result,Nat.is_eq(id,other))} <> complete(A,rest,id,result)

def load_pending(-A:Data,cache:Cache<A>,id:Nat,work:Maybe<String>,loader:String -> IO(Result<&2,&2,Error,A>)) -> IO(Cache<A>):
  match cache work:
    case cache None{}:IO.pure(Cache<A>,cache)
    case Cache{scope,next,entries} Some{key}:
      do IO<Cache<A>>:
        result:Result<&2,&2,Error,A> <- loader(key)
        return Cache{scope,next,complete(A,entries,id,result)}

def load_scoped(-A:Data,cache:Cache<A>,+id:Nat,loader:String -> IO(Result<&2,&2,Error,A>),matching:Bool) -> IO(Cache<A>):
  match cache matching:
    case cache False{}:IO.pure(Cache<A>,cache)
    case Cache{scope,next,+entries} True{}:
      load_pending(A,Cache{scope,next,entries},id,pending(A,entries,id),loader)

# The affine cache stays owned by this IO until the synchronous loader finishes.
# A returned failure is cached; a loader that halts IO cannot return its owner.
def load(-A:Data,cache:Cache<A>,handle:Handle<A>,loader:String -> IO(Result<&2,&2,Error,A>)) -> IO(Cache<A>):
  Cache{+scope,next,entries} = cache
  Handle{other,id} = handle
  load_scoped(A,Cache{scope,next,entries},id,loader,String.eq(scope,other))

def keep(-A:Data,entry:Entry<A>,rest:List<&2,Entry<A>>,matching:Bool) -> List<&2,Entry<A>>:
  match matching:
    case True{}:rest
    case False{}:entry <> rest

def remove(-A:Data,entries:List<&2,Entry<A>>,+id:Nat) -> List<&2,Entry<A>>:
  match entries:
    case []:[]
    case Entry{key,+other,state} <> rest:
      keep(A,Entry{key,other,state},remove(A,rest,id),Nat.is_eq(id,other))

def release_scoped(-A:Data,cache:Cache<A>,id:Nat,matching:Bool) -> Cache<A>:
  match cache matching:
    case cache False{}:cache
    case Cache{scope,next,entries} True{}:
      Cache{scope,next,remove(A,entries,id)}

# Explicit eviction, not refcounting. Dropping/copying a handle has no effect.
def release(-A:Data,cache:Cache<A>,handle:Handle<A>) -> Cache<A>:
  Cache{+scope,next,entries} = cache
  Handle{other,id} = handle
  release_scoped(A,Cache{scope,next,entries},id,String.eq(scope,other))
