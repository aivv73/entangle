import Base
import ../examples/textured-content.bend as Content
import ../examples/scene-render.bend as Existing
import ../src/content.bend as F
import ../src/components.bend as C
import ../src/creation.bend as Create
import ../src/scene-render.bend as R
import ../src/scene-draw.bend as Draw
import ../src/scene-matrix.bend as M
import ../src/lighting.bend as Light
import ../src/error.bend as Error
import ../deps/bend-vulkan/Vulkan.bend as V

def camera() -> M.Mat4:
  M.Mat4{M.Vec4{1.0,0.0,0.0,0.0},M.Vec4{0.0,1.0,0.0,0.0},M.Vec4{0.0,0.0,1.0,0.0},M.Vec4{0.0,0.0,0.0,1.0}}

def light() -> Light.Light:
  Light.Directional{C.Vec3{0.0,0.0,1.0},C.Vec3{1.0,1.0,1.0},0.0,1.0}

def pixel(+x:U32,+y:U32,+level:U32) -> List<&2,U32>:
  +inside = U32.is_ge(x,8) && U32.is_lt(x,56) && U32.is_ge(y,8) && U32.is_lt(y,56)
  +right = U32.is_ge(x,32)
  +bottom = U32.is_ge(y,32)
  Bool.pick(List<&2,U32>,inside,[Bool.pick(U32,Bool.xor(right,bottom),0,level),Bool.pick(U32,right,level,0),Bool.pick(U32,bottom,level,0),255],[0,0,255,255])

def check(rgba:List<&2,U32>,depth:List<&2,U32>,+index:U32,+level:U32) -> Bool:
  match rgba depth:
    case [],[]:U32.is_eq(index,4096)
    case r <> g <> b <> a <> rest,d0 <> d1 <> d2 <> d3 <> ds:
      +x = U32.mod(index,64)
      +y = U32.div(index,64)
      +inside = U32.is_ge(x,8) && U32.is_lt(x,56) && U32.is_ge(y,8) && U32.is_lt(y,56)
      F.same_indices([r,g,b,a],pixel(x,y,level)) && U32.is_zero(d0) && U32.is_zero(d1) && U32.is_eq(d2,128) && U32.is_eq(d3,Bool.pick(U32,inside,62,63)) && check(rest,ds,U32.inc(index),level)
    case _,_:False{}

def observed(pair:R.Renderer & Result<&2,&2,R.InputError,R.Readback>,level:U32,+label:String) -> V.Action(R.Renderer):
  match pair:
    case (renderer,Done{R.Readback{64,64,rgba,depth}}):
      do V.Action<R.Renderer>:
        Error.require(check(rgba,depth,0,level),label ++ ": full RGBA/D32 differs")
        V.Action.lift(Unit,IO.print(label ++ ": every color and depth byte matches"))
        return renderer
    case _:Error.failure(R.Renderer,1,label ++ ": frame rejected")

def frame(renderer:R.Renderer,draws:Draw.DrawList,level:U32,label:String) -> V.Action(R.Renderer):
  do V.Action<R.Renderer>:
    pair:R.Renderer & Result<&2,&2,R.InputError,R.Readback> <- R.render(renderer,draws)
    observed(pair,level,label)

def changed(pair:R.Renderer & Bool) -> V.Action(R.Renderer):
  match pair:
    case (renderer,True{}):V.Action.pure(R.Renderer,renderer)
    case _:Error.failure(R.Renderer,1,"Valid light rejected")

def rejected_light(pair:R.Renderer & Bool) -> V.Action(R.Renderer):
  match pair:
    case (renderer,False{}):V.Action.pure(R.Renderer,renderer)
    case _:Error.failure(R.Renderer,1,"Zero light direction accepted")

def rejected_transform(pair:R.Renderer & Result<&2,&2,R.InputError,R.Readback>) -> V.Action(R.Renderer):
  match pair:
    case (renderer,Fail{R.InvalidTransform{0}}):V.Action.pure(R.Renderer,renderer)
    case _:Error.failure(R.Renderer,1,"Singular textured transform accepted")

def run(entry:V.Entry,compiled:Create.Compiled) -> V.Action(Unit):
  Create.Compiled{seeds,geometry} = compiled
  +draws:Draw.DrawList = Draw.DrawList{Content.draws(seeds)}
  do V.Action<Unit>:
    renderer:R.Renderer <- R.create(entry,R.Config{64,64,camera(),light()},geometry)
    renderer:R.Renderer <- frame(renderer,draws,255,"Texture orientation and sampling")
    renderer:R.Renderer <- rejected_light(R.set_light(renderer,Light.Directional{C.Vec3{0.0,0.0,0.0},C.Vec3{1.0,1.0,1.0},0.0,1.0}))
    rejected:R.Renderer & Result<&2,&2,R.InputError,R.Readback> <- R.render(renderer,Draw.DrawList{[Draw.DrawItem{C.Transform{C.Vec3{0.0,0.0,0.0},C.Quat{0.0,0.0,0.0,1.0},C.Vec3{1.0,1.0,0.0}},C.MeshRef{7}}]})
    renderer:R.Renderer <- rejected_transform(rejected)
    renderer:R.Renderer <- frame(renderer,draws,255,"Invalid light and singular transform preserve the renderer")
    renderer:R.Renderer <- changed(R.set_light(renderer,Light.Directional{C.Vec3{0.0,0.0,F32.neg(1.0)},C.Vec3{1.0,1.0,1.0},0.0,1.0}))
    renderer:R.Renderer <- frame(renderer,draws,0,"Back-facing normals receive no diffuse light")
    renderer:R.Renderer <- changed(R.set_light(renderer,Light.Directional{C.Vec3{0.0,0.0,F32.neg(1.0)},C.Vec3{1.0,1.0,1.0},1.0,0.0}))
    renderer:R.Renderer <- frame(renderer,draws,255,"Ambient-only texture")
    return Unit{}

def pair_scene() -> Create.Scene:
  Create.Scene{[
    Create.Instance{Content.quad(C.Vec3{0.0,0.0,1.0}),F.Textured{C.Vec3{0.6,1.0,1.0},F.SourceImage{1,1,[4278190335]}},C.Transform{C.Vec3{F32.neg(0.5),0.0,0.0},C.Quat{0.0,0.0,0.0,1.0},C.Vec3{0.5,0.5,1.0}}},
    Create.Instance{Content.quad(C.Vec3{0.0,0.0,1.0}),F.Textured{C.Vec3{1.0,1.0,1.0},F.SourceImage{1,1,[16711935]}},C.Transform{C.Vec3{0.5,0.0,0.0},C.Quat{0.0,0.0,0.0,1.0},C.Vec3{0.5,0.5,1.0}}}]}

def pair_pixels(rgba:List<&2,U32>,+index:U32) -> String:
  match rgba:
    case []:Bool.pick(String,U32.is_eq(index,4096),"","incomplete readback")
    case +r <> +g <> +b <> +a <> rest:
      +x = U32.mod(index,64)
      +y = U32.div(index,64)
      +row = U32.is_ge(y,20) && U32.is_lt(y,44)
      +red = row && U32.is_ge(x,4) && U32.is_lt(x,28)
      +green = row && U32.is_ge(x,36) && U32.is_lt(x,60)
      Bool.pick(String,U32.is_eq(r,Bool.pick(U32,red,153,0)) && U32.is_eq(g,Bool.pick(U32,green,255,0)) && U32.is_eq(b,Bool.pick(U32,red || green,0,255)) && U32.is_eq(a,255),pair_pixels(rest,U32.inc(index)),"pixel " ++ U32.show(index) ++ " = " ++ U32.show(r) ++ "," ++ U32.show(g) ++ "," ++ U32.show(b) ++ "," ++ U32.show(a))
    case _:"partial pixel"

def pair_observed(pair:R.Renderer & Result<&2,&2,R.InputError,R.Readback>) -> V.Action(Unit):
  match pair:
    case (_,Done{R.Readback{64,64,rgba,_}}):
      do V.Action<Unit>:
        +difference:String = pair_pixels(rgba,0)
        Error.require(String.is_empty(difference),"Distinct texture bindings or material tint differs: " ++ difference)
        V.Action.lift(Unit,IO.print("Distinct texture bindings and baked material tint match every pixel."))
    case _:Error.failure(Unit,1,"Multiple textured materials rejected")

def pair_run(entry:V.Entry,compiled:Create.Compiled) -> V.Action(Unit):
  Create.Compiled{seeds,geometry} = compiled
  do V.Action<Unit>:
    renderer:R.Renderer <- R.create(entry,R.Config{64,64,camera(),light()},geometry)
    pair:R.Renderer & Result<&2,&2,R.InputError,R.Readback> <- R.render(renderer,Draw.DrawList{Content.draws(seeds)})
    pair_observed(pair)

def main() -> IO(Unit):
  do IO<Unit>:
    image:F.SourceImage <- Content.load("assets/checker.png")
    compiled:Create.Compiled <- Content.compiled(Create.compile(Content.scene(image,C.Vec3{0.0,0.0,1.0})))
    IO.try(Unit,V.Entry.with(Unit,entry => run(entry,compiled)))
    compiled:Create.Compiled <- Content.compiled(Create.compile(pair_scene()))
    IO.try(Unit,V.Entry.with(Unit,entry => pair_run(entry,compiled)))
    live:U32 <- IO.try(U32,V.debug_live_objects())
    IO.try(Unit,Error.require(U32.is_zero(live),"Textured rendering leaked Vulkan resources"))
    IO.print("Textured renderer live objects=0")
