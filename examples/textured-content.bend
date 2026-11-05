import Base
import ../src/asset.bend as Asset
import ../src/content.bend as F
import ../src/image-png.bend as Png
import ../src/components.bend as C
import ../src/creation.bend as Create
import ../src/scene-draw.bend as Draw

def released(pair:Asset.Cache<F.SourceImage> & Maybe<&2,Asset.State<F.SourceImage>>,image:F.SourceImage) -> IO(F.SourceImage):
  match pair:
    case (_,None{}):IO.pure(F.SourceImage,image)
    case _:IO.die(F.SourceImage,1,"Released texture source still resolves")

def ready(pair:Asset.Cache<F.SourceImage> & Maybe<&2,Asset.State<F.SourceImage>>,+handle:Asset.Handle<F.SourceImage>) -> IO(F.SourceImage):
  match pair:
    case (cache,Some{Asset.Loaded{image}}):released(Asset.lookup(F.SourceImage,Asset.release(F.SourceImage,cache,handle),handle),image)
    case (_,Some{Asset.Failed{Asset.Error{code,message}}}):IO.die(F.SourceImage,code,message)
    case _:IO.die(F.SourceImage,1,"Texture source did not load")

def requested(pair:Asset.Cache<F.SourceImage> & Asset.Handle<F.SourceImage>) -> IO(F.SourceImage):
  (cache,+handle) = pair
  do IO<F.SourceImage>:
    cache:Asset.Cache<F.SourceImage> <- Asset.load(F.SourceImage,cache,handle,Png.load)
    ready(Asset.lookup(F.SourceImage,cache,handle),handle)

def load(path:String) -> IO(F.SourceImage):
  requested(Asset.request(F.SourceImage,Asset.new(F.SourceImage,"textured-scene"),path))

def vertex(x:F32,y:F32,u:F32,v:F32,+normal:C.Vec3) -> F.Vertex:
  F.Vertex{C.Vec3{x,y,0.25},C.Vec3{1.0,1.0,1.0},F.UV{u,v},normal}

def quad(+normal:C.Vec3) -> F.Mesh:
  F.Mesh{[vertex(F32.neg(0.75),F32.neg(0.75),0.0,0.0,normal),vertex(0.75,F32.neg(0.75),1.0,0.0,normal),vertex(0.75,0.75,1.0,1.0,normal),vertex(F32.neg(0.75),0.75,0.0,1.0,normal)],[0,1,2,2,3,0]}

def scene(image:F.SourceImage,normal:C.Vec3) -> Create.Scene:
  Create.Scene{[Create.Instance{quad(normal),F.Textured{C.Vec3{1.0,1.0,1.0},image},C.Transform.identity()}]}

def compiled(result:Result<&2,&2,Create.Error,Create.Compiled>) -> IO(Create.Compiled):
  match result:
    case Done{value}:IO.pure(Create.Compiled,value)
    case Fail{_}:IO.die(Create.Compiled,1,"Textured scene compilation failed")

def draws(seeds:List<&2,Create.Seed>) -> List<&2,Draw.DrawItem>:
  match seeds:
    case []:[]
    case Create.Seed{t,m} <> rest:Draw.DrawItem{t,m} <> draws(rest)

def face_vertex(center:C.Vec3,uaxis:C.Vec3,vaxis:C.Vec3,normal:C.Vec3,+u:F32,+v:F32) -> F.Vertex:
  C.Vec3{x,y,z} = center
  C.Vec3{ux,uy,uz} = uaxis
  C.Vec3{vx,vy,vz} = vaxis
  F.Vertex{C.Vec3{(x + u * ux + v * vx : F32),(y + u * uy + v * vy : F32),(z + u * uz + v * vz : F32)},C.Vec3{1.0,1.0,1.0},F.UV{((u + 1.0) * 0.5 : F32),((v + 1.0) * 0.5 : F32)},normal}

def face(+center:C.Vec3,+u:C.Vec3,+v:C.Vec3) -> List<&2,F.Vertex>:
  [face_vertex(center,u,v,center,F32.neg(1.0),F32.neg(1.0)),face_vertex(center,u,v,center,1.0,F32.neg(1.0)),face_vertex(center,u,v,center,1.0,1.0),face_vertex(center,u,v,center,F32.neg(1.0),1.0)]

def cube() -> F.Mesh:
  F.Mesh{List.concat(&2,F.Vertex,[
    face(C.Vec3{0.0,0.0,1.0},C.Vec3{1.0,0.0,0.0},C.Vec3{0.0,1.0,0.0}),
    face(C.Vec3{0.0,0.0,F32.neg(1.0)},C.Vec3{F32.neg(1.0),0.0,0.0},C.Vec3{0.0,1.0,0.0}),
    face(C.Vec3{1.0,0.0,0.0},C.Vec3{0.0,0.0,F32.neg(1.0)},C.Vec3{0.0,1.0,0.0}),
    face(C.Vec3{F32.neg(1.0),0.0,0.0},C.Vec3{0.0,0.0,1.0},C.Vec3{0.0,1.0,0.0}),
    face(C.Vec3{0.0,1.0,0.0},C.Vec3{1.0,0.0,0.0},C.Vec3{0.0,0.0,F32.neg(1.0)}),
    face(C.Vec3{0.0,F32.neg(1.0),0.0},C.Vec3{1.0,0.0,0.0},C.Vec3{0.0,0.0,1.0})]),
    [0,1,2,2,3,0,4,5,6,6,7,4,8,9,10,10,11,8,12,13,14,14,15,12,16,17,18,18,19,16,20,21,22,22,23,20]}

def showcase(+image:F.SourceImage) -> Create.Scene:
  Create.Scene{[
    Create.Instance{cube(),F.Textured{C.Vec3{1.0,1.0,1.0},image},C.Transform{C.Vec3{F32.neg(1.2),0.0,0.0},C.Quat{0.0,0.0,0.0,1.0},C.Vec3{0.8,1.0,0.6}}},
    Create.Instance{cube(),F.Textured{C.Vec3{0.8,0.9,1.0},image},C.Transform{C.Vec3{1.2,0.0,0.0},C.Quat{0.0,0.38268343,0.0,0.9238795},C.Vec3{0.7,0.7,0.7}}}]}
