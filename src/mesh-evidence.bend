import Base
import ./components.bend as C
import ./scene-schema.bend as D
import ./scene-observe.bend as Observe
import ../deps/bendvy/src/ecs/world.bend as W
import ../deps/bendvy/src/ecs/entity-key.bend as K

def words(xs:List<&2,F32>) -> String:
  match xs:
    case []:""
    case x <> rest:U32.show(F32.bits(x)) ++ "," ++ words(rest)

def row(value:Observe.Row) -> String:
  Observe.Row{W.Handle{ns,K.EntityKey{index,generation}},C.Transform{C.Vec3{x,y,z},C.Quat{a,b,c,d},C.Vec3{sx,sy,sz}},C.MeshRef{id}} = value
  U32.show(ns) ++ "," ++ U32.show(index) ++ "," ++ U32.show(generation) ++ "," ++ U32.show(id) ++ "," ++ words([x,y,z,a,b,c,d,sx,sy,sz])

def rows(values:List<&2,Observe.Row>) -> String:
  match values:
    case []:""
    case x <> rest:row(x) ++ ";" ++ rows(rest)

def print(enabled:Bool,text:String) -> IO(Unit):
  match enabled:
    case True{}:IO.print(text)
    case False{}:IO.pure(Unit,Unit{})

def events(+enabled:Bool,values:List<Event>) -> IO(List<Event>):
  match values:
    case []:IO.pure(List<Event>,[])
    case Key{+code,+down} <> rest:
      do IO<List<Event>>:
        print(enabled,"mesh-key " ++ U32.show(code) ++ " " ++ U32.show(Bool.to_u32(down)))
        tail:List<Event> <- events(enabled,rest)
        return Key{code,down} <> tail
    case event <> rest:
      do IO<List<Event>>:
        tail:List<Event> <- events(enabled,rest)
        return event <> tail
