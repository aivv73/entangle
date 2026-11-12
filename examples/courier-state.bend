import Base
import ../src/components.bend as C

type Phase is Data:
  Searching{}
  Carrying{}
  Complete{}

type State is Data:
  State{x:U32,z:U32,phase:Phase}

def initial() -> State:State{3,3,Searching{}}
def phase(state:State) -> Phase:
  State{_,_,p} = state
  p

def label(value:Phase) -> String:
  match value:
    case Searching{}:"Find the amber crystal. IJKL move. Space collect. X reset."
    case Carrying{}:"Carrying energy. Reach the violet pad and press Space."
    case Complete{}:"Delivery complete! X starts again."

def decrement(+n:U32) -> U32:Bool.pick(U32,U32.is_zero(n),0,(n - 1 : U32))
def increment(n:U32) -> U32:U32.min(6,(n + 1 : U32))
def interact(+x:U32,+z:U32,p:Phase) -> Phase:
  match p:
    case Searching{}:Bool.pick(Phase,U32.is_eq(x,1) && U32.is_eq(z,3),Carrying{},Searching{})
    case Carrying{}:Bool.pick(Phase,U32.is_eq(x,5) && U32.is_eq(z,3),Complete{},Carrying{})
    case Complete{}:Complete{}

def action(+code:U32,state:State) -> State:
  match code state:
    case _ State{x,z,Complete{}}:State{x,z,Complete{}}
    case 106 State{x,z,p}:State{decrement(x),z,p}
    case 108 State{x,z,p}:State{increment(x),z,p}
    case 105 State{x,z,p}:State{x,decrement(z),p}
    case 107 State{x,z,p}:State{x,increment(z),p}
    case 32 State{+x,+z,p}:State{x,z,interact(x,z,p)}
    case _ state:state

def key(+code:U32,state:State) -> State:
  match code:
    case 120:initial()
    case _:action(code,state)

def pose(x:F32,y:F32,z:F32,+s:F32) -> C.Transform:
  C.Transform{C.Vec3{x,y,z},C.Quat{0.0,0.0,0.0,1.0},C.Vec3{s,s,s}}

def transform(index:Nat,state:State) -> C.Transform:
  match index state:
    case 0n State{x,z,_}:pose((U32.to_f32(x) - 3.0 : F32),0.2,(U32.to_f32(z) - 3.0 : F32),0.5)
    case 1n State{x,z,Carrying{}}:pose((U32.to_f32(x) - 3.0 : F32),1.0,(U32.to_f32(z) - 3.0 : F32),0.3)
    case 1n State{_,_,Complete{}}:pose(2.0,0.5,0.0,0.65)
    case 1n _:pose(F32.neg(2.0),0.2,0.0,0.4)
    case 2n State{_,_,Complete{}}:pose(2.0,0.15,0.0,1.3)
    case 2n _:pose(2.0,0.15,0.0,1.0)
    case _ _:C.Transform{C.Vec3{0.0,0.0,0.0},C.Quat{0.0,0.0,0.0,1.0},C.Vec3{6.0,1.0,6.0}}

def phase_equal(a:Phase,b:Phase) -> Bool:
  match a b:
    case Searching{} Searching{}:True{}
    case Carrying{} Carrying{}:True{}
    case Complete{} Complete{}:True{}
    case _ _:False{}

def equal(a:State,b:State) -> Bool:
  State{x,z,p} = a
  State{u,v,q} = b
  U32.is_eq(x,u) && U32.is_eq(z,v) && phase_equal(p,q)
