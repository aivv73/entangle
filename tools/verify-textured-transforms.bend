import Base
import ./verify-textured-render.bend as Check
import ./verify-buffer-retention.bend as Retain
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

def close(+value:U32,+expected:U32) -> Bool:
  U32.is_le(U32.sub(U32.max(value,expected),U32.min(value,expected)),1)

def accumulate(ok:Bool,pair:U32 & Bool) -> U32 & Bool:
  (count,rest) = pair
  (U32.inc(count),ok && rest)

def lit_pixels(bytes:List<&2,U32>,depth:List<&2,U32>,+expected:U32) -> U32 & Bool:
  match bytes depth:
    case [],[]:(0,True{})
    case r <> g <> b <> a <> rest,0 <> 0 <> 128 <> 63 <> ds:lit_pixels(rest,ds,expected)
    case r <> g <> b <> a <> rest,_ <> _ <> _ <> _ <> ds:
      accumulate(close(r,expected) && close(g,expected) && close(b,expected) && U32.is_eq(a,255),lit_pixels(rest,ds,expected))
    case _,_:(0,False{})


def checked(+label:String,pair:U32 & Bool) -> V.Action(Unit):
  (count,ok) = pair
  do V.Action<Unit>:
    Error.require(U32.is_gt(count,300) && ok,label ++ ": normal transform irradiance differs")
    V.Action.lift(Unit,IO.print(label ++ ": all covered pixels match scalar irradiance within one UNORM step"))

def rendered(pair:R.Renderer & R.Readback,expected:U32,label:String) -> V.Action(Unit):
  (_,R.Readback{_,_,rgba,depth}) = pair
  checked(label,lit_pixels(rgba,depth,expected))

def normal(entry:V.Entry,compiled:Create.Compiled,matrix:M.Mat4,transform:C.Transform,light:Light.Light,expected:U32,label:String) -> V.Action(Unit):
  Create.Compiled{_,geometry} = compiled
  do V.Action<Unit>:
    renderer:R.Renderer <- R.create(entry,R.Config{64,64,matrix,light},geometry)
    pair:R.Renderer & R.Readback <- Existing.frame(renderer,Draw.DrawList{[Draw.DrawItem{transform,C.MeshRef{7}}]})
    rendered(pair,expected,label)

def scaled_camera() -> M.Mat4:
  M.Mat4{M.Vec4{0.000001,0.0,0.0,0.0},M.Vec4{0.0,0.000001,0.0,0.0},M.Vec4{0.0,0.0,0.000001,0.0},M.Vec4{0.0,0.0,0.0,1.0}}

def orbit(+yaw:F32) -> Create.Camera:
  Create.Camera{C.Vec3{0.0,0.0,0.0},yaw,0.15,3.0,Create.Perspective{1.7320508,0.1,100.0}}

def images_equal(a:R.Readback,b:R.Readback) -> Bool:
  R.Readback{w,h,p,d} = a
  R.Readback{x,y,q,e} = b
  U32.is_eq(w,x) && U32.is_eq(h,y) && F.same_indices(p,q) && F.same_indices(d,e)

def reset_frame(pair:R.Renderer & R.Readback,+before:R.Readback,after:R.Readback) -> V.Action(Unit):
  (_,reset) = pair
  do V.Action<Unit>:
    Error.require(Bool.not(images_equal(before,after)) && images_equal(before,reset),"Camera move/reset did not change and restore exact RGBA/D32")
    V.Action.lift(Unit,IO.print("Camera move changes pixels; reset restores exact RGBA/D32 without resource growth."))

def second_frame(pair:R.Renderer & R.Readback,before:R.Readback,+draws:Draw.DrawList,+count:U32) -> V.Action(Unit):
  (renderer,after) = pair
  do V.Action<Unit>:
    renderer:R.Renderer <- Check.changed(R.set_camera(renderer,orbit(0.2)))
    pair:R.Renderer & R.Readback <- Existing.frame(renderer,draws)
    Retain.count(count,"Camera-only frames preserve GPU allocations")
    reset_frame(pair,before,after)

def first_frame(pair:R.Renderer & R.Readback,+draws:Draw.DrawList) -> V.Action(Unit):
  (renderer,before) = pair
  do V.Action<Unit>:
    +count:U32 <- V.debug_live_objects()
    renderer:R.Renderer <- Check.changed(R.set_camera(renderer,orbit(0.8)))
    pair:R.Renderer & R.Readback <- Existing.frame(renderer,draws)
    second_frame(pair,before,draws,count)

def camera(entry:V.Entry,compiled:Create.Compiled) -> V.Action(Unit):
  Create.Compiled{seeds,geometry} = compiled
  +draws:Draw.DrawList = Draw.DrawList{Content.draws(seeds)}
  do V.Action<Unit>:
    renderer:R.Renderer <- R.create(entry,R.Config{64,64,Check.camera(),Check.light()},geometry)
    renderer:R.Renderer <- Check.changed(R.set_camera(renderer,orbit(0.2)))
    pair:R.Renderer & R.Readback <- Existing.frame(renderer,draws)
    first_frame(pair,draws)

def main() -> IO(Unit):
  do IO<Unit>:
    +compiled:Create.Compiled <- Content.compiled(Create.compile(Content.scene(F.SourceImage{1,1,[4294967295]},C.Vec3{0.6,0.0,0.8})))
    IO.try(Unit,V.Entry.with(Unit,entry => normal(entry,compiled,Check.camera(),C.Transform{C.Vec3{0.0,0.0,0.0},C.Quat{0.0,0.0,0.0,1.0},C.Vec3{2.0,1.0,0.5}},Check.light(),251,"Nonuniform inverse scale")))
    IO.try(Unit,V.Entry.with(Unit,entry => normal(entry,compiled,Check.camera(),C.Transform{C.Vec3{0.0,0.0,0.0},C.Quat{0.0,0.0,0.70710678,0.70710678},C.Vec3{2.0,1.0,0.5}},Light.Directional{C.Vec3{0.0,1.0,0.0},C.Vec3{1.0,1.0,1.0},0.0,1.0},47,"Rotated scaled normals")))
    compiled:Create.Compiled <- Content.compiled(Create.compile(Content.scene(F.SourceImage{1,1,[4294967295]},C.Vec3{0.000006,0.0,0.000008})))
    IO.try(Unit,V.Entry.with(Unit,entry => normal(entry,compiled,scaled_camera(),C.Transform{C.Vec3{0.0,0.0,0.0},C.Quat{0.0,0.0,0.0,1.0},C.Vec3{1000000.0,1000000.0,1000000.0}},Check.light(),204,"Small valid normals at maximum scale")))
    image:F.SourceImage <- Content.load("assets/checker.png")
    compiled:Create.Compiled <- Content.compiled(Create.compile(Content.scene(image,C.Vec3{0.0,0.0,1.0})))
    IO.try(Unit,V.Entry.with(Unit,entry => camera(entry,compiled)))
    IO.try(Unit,Retain.count(0,"Normal and camera terminal cleanup"))
