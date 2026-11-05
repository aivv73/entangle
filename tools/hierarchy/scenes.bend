import Base
import ../../src/components.bend as C
import ../../src/content.bend as F
import ../../src/creation.bend as Create

def pose(x:F32,y:F32,z:F32,rotation:C.Quat,scale:C.Vec3) -> C.Transform:
  C.Transform{C.Vec3{x,y,z},rotation,scale}

def rotation() -> C.Quat:C.Quat{0.0,0.0,0.0,1.0}
def unit() -> C.Vec3:C.Vec3{1.0,1.0,1.0}

def before_tick(t:C.Transform) -> C.Transform:
  C.Transform{C.Vec3{x,y,z},q,s} = t
  pose(F32.sub(x,1.0),F32.sub(y,0.5),F32.add(z,2.0),q,s)

def vertex(x:F32,y:F32,u:F32,v:F32) -> F.Vertex:
  F.Vertex{C.Vec3{x,y,0.0},C.Vec3{1.0,1.0,1.0},F.UV{u,v},C.Vec3{0.0,0.0,1.0}}

def mesh() -> F.Mesh:
  F.Mesh{[vertex(F32.neg(0.5),F32.neg(0.5),0.0,0.0),vertex(0.5,F32.neg(0.5),1.0,0.0),vertex(0.5,0.5,1.0,1.0),vertex(F32.neg(0.5),0.5,0.0,1.0)],[0,1,2,0,2,3]}

def material() -> F.Material:
  F.Textured{C.Vec3{1.0,1.0,1.0},F.SourceImage{2,2,[4278190335,16711935,65535,4294967295]}}

def root() -> C.Transform:pose(F32.neg(0.3),0.0,0.5,rotation(),C.Vec3{0.8,0.6,0.5})
def child() -> C.Transform:pose(0.0,0.0,0.0,C.Quat{0.0,0.6,0.0,0.8},unit())
def other() -> C.Transform:pose(0.65,F32.neg(0.5),0.5,rotation(),C.Vec3{0.35,0.35,0.35})

def showcase() -> Create.Scene:
  Create.Scene{[
    Create.Instance{F.Mesh{[],[]},F.white(),before_tick(root())},
    Create.Parented{mesh(),material(),before_tick(child()),0},
    Create.Parented{mesh(),F.Basic{C.Vec3{1.0,0.4,0.1}},before_tick(pose(0.0,1.0,0.0,rotation(),C.Vec3{0.4,0.4,0.4})),0},
    Create.Instance{mesh(),material(),before_tick(other())},
    Create.Parented{mesh(),material(),before_tick(pose(0.0,1.0,0.0,rotation(),C.Vec3{0.5,0.5,0.5})),2}]}

def parent(+mode:U32,index:U32) -> Maybe<&2,U32>:
  match index:
    case 0:None{}
    case +index:Bool.pick(Maybe<&2,U32>,U32.is_zero(mode),None{},Some{Bool.pick(U32,U32.is_eq(mode,1),U32.sub(index,1),U32.div(U32.sub(index,1),2))})

def forest(count:Nat,+mode:U32,+index:U32) -> List<&2,Create.Instance>:
  match count:
    case 0n:[]
    case 1n+n:Create.parent(Create.Instance{mesh(),F.white(),before_tick(pose(0.25,0.125,0.0,rotation(),unit()))},parent(mode,index)) <> forest(n,mode,U32.inc(index))
