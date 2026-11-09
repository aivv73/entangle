import Base
import ./time.bend as Time
import ./components.bend as Value
import ./scene-schema.bend as D
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/entity-key.bend as Key

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


def same(left:W.Handle<D.Schema>,right:W.Handle<D.Schema>) -> Bool:
  W.Handle{ln,lk} = left
  W.Handle{rn,rk} = right
  U32.is_eq(ln,rn) && Key.equal(lk,rk)

# Decide from the actual component read by the executing query. Only the
# retained player's complete namespace/generation handle can be written.
def moved(pair:Value.Transform & Unit) -> Maybe<&2,Value.Transform>:
  (value,_) = pair
  Some{value}

def decision(keys:Keys,current:Value.Transform,initial:Value.Transform,reset:Bool) -> Maybe<&2,Value.Transform>:
  +keys:Keys = keys
  Bool.pick(Maybe<&2,Value.Transform>,reset,Some{initial},Bool.pick(Maybe<&2,Value.Transform>,idle(keys),None{},moved(translate(keys,current))))

def decide(state:Control,entity:W.Handle<D.Schema>,current:Value.Transform) -> Maybe<&2,Value.Transform>:
  match state:
    case Boot{}:None{}
    case PlayerReady{h,keys,initial,reset}:Bool.pick(Maybe<&2,Value.Transform>,same(h,entity),decision(keys,current,initial,reset),None{})

def consumed(state:Control) -> Control:
  match state:
    case Boot{}:Boot{}
    case PlayerReady{h,keys,initial,True{}}:PlayerReady{h,empty(),initial,False{}}
    case state:state

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
