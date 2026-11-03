import Base

type Camera is Data:
  Camera{yaw: F32, pitch: F32, distance: F32}

def initial() -> Camera:
  Camera{0.65,0.45,7.0}

def clamp(+x: F32, +low: F32, +high: F32) -> F32:
  F32.max(low,F32.min(x,high))

def key(+code: U32, camera: Camera) -> Camera:
  match code:
    case 114: initial()
    case _:
      Camera{+yaw,+pitch,+distance} = camera
      Camera{(yaw + Bool.pick(F32,U32.is_eq(code,97),F32.neg(0.12),Bool.pick(F32,U32.is_eq(code,100),0.12,0.0)) : F32),
        clamp((pitch + Bool.pick(F32,U32.is_eq(code,119),0.1,Bool.pick(F32,U32.is_eq(code,115),F32.neg(0.1),0.0)) : F32),0.1,1.4),
        clamp((distance + Bool.pick(F32,U32.is_eq(code,113),F32.neg(0.4),Bool.pick(F32,U32.is_eq(code,101),0.4,0.0)) : F32),4.0,15.0)}

def events(xs: List<Event>, camera: Maybe<Camera>) -> Maybe<Camera>:
  match xs camera:
    case _ None{}: None{}
    case Nil{} Some{c}: Some{c}
    case Con{Close{},rest} _: None{}
    case Con{Key{27,True{}},rest} _: None{}
    case Con{Key{code,True{}},rest} Some{c}: events(rest,Some{key(code,c)})
    case Con{event,rest} Some{c}: events(rest,Some{c})

def drain(-A:Type,rebuild:List<Event> -> A,pending:List<Event>) -> A:
  rebuild([])

def snapshot(-A:Type,rebuild:List<Event> -> A,pending:List<Event>,camera:Maybe<Camera>) -> Maybe<Camera> & A:
  (events(pending,camera),rebuild([]))
