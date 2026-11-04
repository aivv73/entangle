import Base
import ../../src/content.bend as F
import ../../src/components.bend as Comp
import ../../src/asset.bend as Asset
import ../../src/model-obj.bend as Obj
import ../../src/creation.bend as Create
import ../../src/scene-render.bend as R
import ../../src/scene-draw.bend as Draw
import ../../examples/model-assets.bend as Example
import ../../examples/scene-render.bend as Render
import ../../deps/bend-vulkan/Vulkan.bend as V
import ../verify-creation.bend as Consumer
import ../image-decoder/common.bend as C
import ./reference.bend as Ref

def model(result:Result<&2,&2,Asset.Error,F.SourceModel>) -> IO(F.SourceModel):
  match result:
    case Done{value}:IO.pure(F.SourceModel,value)
    case Fail{Asset.Error{code,message}}:IO.die(F.SourceModel,1,message)

def same_ranges(a:List<&2,Create.Range>,b:List<&2,Create.Range>) -> Bool:
  match a b:
    case [],[]:True{}
    case Create.Range{x,y,z} <> xs,Create.Range{u,v,w} <> ys:U32.is_eq(x,u) && U32.is_eq(y,v) && U32.is_eq(z,w) && same_ranges(xs,ys)
    case _,_:False{}

def geometry_equal(a:Create.Geometry,b:Create.Geometry) -> Bool:
  Create.Geometry{v,i,r} = a
  Create.Geometry{w,j,s} = b
  F.same_vertices(v,w) && F.same_indices(i,j) && same_ranges(r,s)

def vec_words(v:Comp.Vec3) -> List<&2,U32>:
  Comp.Vec3{x,y,z} = v
  [F32.bits(x),F32.bits(y),F32.bits(z)]

def pose_words(t:Comp.Transform) -> List<&2,U32>:
  Comp.Transform{p,Comp.Quat{x,y,z,w},s} = t
  List.append(&2,U32,vec_words(p),List.append(&2,U32,[F32.bits(x),F32.bits(y),F32.bits(z),F32.bits(w)],vec_words(s)))

def words(values:List<&2,U32>) -> String:
  match values:
    case []:""
    case x <> rest:U32.show(x) ++ " " ++ words(rest)

def state_items(items:List<&2,Draw.DrawItem>) -> String:
  match items:
    case []:""
    case Draw.DrawItem{t,Comp.MeshRef{id}} <> rest:"mesh=" ++ U32.show(id) ++ " transform=" ++ words(pose_words(t)) ++ "\n" ++ state_items(rest)

def state(list:Draw.DrawList) -> String:
  Draw.DrawList{items} = list
  state_items(items)

def same_items(a:List<&2,Draw.DrawItem>,b:List<&2,Draw.DrawItem>) -> Bool:
  match a b:
    case [],[]:True{}
    case Draw.DrawItem{t,Comp.MeshRef{id}} <> xs,Draw.DrawItem{u,Comp.MeshRef{other}} <> ys:
      U32.is_eq(id,other) && F.same_indices(pose_words(t),pose_words(u)) && same_items(xs,ys)
    case _,_:False{}

def same_draws(a:Draw.DrawList,b:Draw.DrawList) -> Bool:
  Draw.DrawList{a} = a
  Draw.DrawList{b} = b
  same_items(a,b)

def vertex_words(values:List<&2,F.Vertex>) -> String:
  match values:
    case []:""
    case F.Vertex{p,c} <> rest:words(vec_words(p)) ++ words(vec_words(c)) ++ "\n" ++ vertex_words(rest)

def range_words(values:List<&2,Create.Range>) -> String:
  match values:
    case []:""
    case Create.Range{id,first,count} <> rest:words([id,first,count]) ++ "\n" ++ range_words(rest)

def packed(geometry:Create.Geometry) -> String:
  Create.Geometry{v,i,r} = geometry
  "vertices position/RGB words\n" ++ vertex_words(v) ++ "indices\n" ++ words(i) ++ "\nranges id/first/count\n" ++ range_words(r)

def write_image(path:String,image:R.Readback) -> IO(Unit):
  R.Readback{w,h,rgba,_} = image
  C.write(path,Obj.text("P3\n" ++ U32.show(w) ++ " " ++ U32.show(h) ++ "\n255\n" ++ Render.ppm_pixels(rgba)))

def raw(+path:String,image:R.Readback) -> IO(Unit):
  R.Readback{_,_,rgba,depth} = image
  do IO<Unit>:
    C.write(path ++ ".rgba",rgba)
    C.write(path ++ ".d32",depth)

def images(+geometry:Create.Geometry,+expected:Create.Geometry,pair:Draw.DrawList & Draw.DrawList,other:Draw.DrawList & Draw.DrawList,+label:String,+colored:Bool) -> IO(Unit):
  (+first,+second) = pair
  (+reference,+reference_second) = other
  do IO<Unit>:
    C.require(same_draws(first,reference) && same_draws(second,reference_second),"Complete extracted transform words or mesh references differ")
    C.write("build/model-obj/" ++ label ++ ".state.txt",Obj.text("imported tick=1\n" ++ state(first) ++ "imported tick=2\n" ++ state(second) ++ "reference tick=1\n" ++ state(reference) ++ "reference tick=2\n" ++ state(reference_second)))
    C.write("build/model-obj/" ++ label ++ ".packed.txt",Obj.text(packed(geometry)))
    result:V.VkResult(R.Readback) <- Consumer.render_geometry(geometry,first,colored)
    +image:R.Readback <- V.or_exit(R.Readback,result)
    result:V.VkResult(R.Readback) <- Consumer.render_geometry(expected,reference,colored)
    expected:R.Readback <- V.or_exit(R.Readback,result)
    C.require(Render.image_equal(image,expected),"Imported offscreen RGBA/D32 differs from independent engine sources")
    write_image("build/model-obj/" ++ label ++ ".ppm",image)
    raw("build/model-obj/" ++ label,image)
    result:V.VkResult(R.Readback) <- Consumer.render_geometry(geometry,second,colored)
    later:R.Readback <- V.or_exit(R.Readback,result)
    C.require(Bool.not(Render.image_equal(image,later)),"Imported ECS movement did not affect real readback")
    Render.no_live()
    IO.print(label ++ " full packed geometry/ranges, two real ECS snapshots, exact offscreen RGBA/D32, retained replay and zero live Vulkan objects verified.")

def compiled(actual:Create.Compiled,expected:Create.Compiled,label:String,colored:Bool) -> IO(Unit):
  Create.Compiled{seeds,+geometry} = actual
  Create.Compiled{other,+reference} = expected
  do IO<Unit>:
    C.require(geometry_equal(geometry,reference),"Full compiled imported geometry or ranges differ")
    pair:Draw.DrawList & Draw.DrawList <- Consumer.lists(seeds)
    other:Draw.DrawList & Draw.DrawList <- Consumer.lists(other)
    images(geometry,reference,pair,other,label,colored)

def run(path:String,wanted:F.SourceModel,label:String,colored:Bool) -> IO(Unit):
  do IO<Unit>:
    result:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(path)
    model:F.SourceModel <- model(result)
    actual:Create.Compiled <- Consumer.compiled(Create.compile(Example.content(model)))
    reference:Create.Compiled <- Consumer.compiled(Create.compile(Example.content(wanted)))
    compiled(actual,reference,label,colored)

def main() -> IO(Unit):
  do IO<Unit>:
    run("docs/verification/2026-11-04-model-obj/corpus/sign.obj",Ref.sign(),"sign",True{})
    run("docs/verification/2026-11-04-model-obj/corpus/wedge.obj",Ref.wedge(),"wedge",False{})
