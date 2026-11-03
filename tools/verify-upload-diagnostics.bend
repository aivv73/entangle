import Base
import ../examples/scene-render.bend as Example
import ../src/scene-window.bend as Win
import ../src/scene-diagnostics.bend as D
import ../src/measurement-counters.bend as Count
import ../src/error.bend as Error
import ../src/app.bend as Scope
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W

def span_present(spans:List<&2,D.Span>,+name:String) -> Bool:
  match spans:
    case []:False{}
    case D.Span{x,D.Available{_}} <> rest:String.eq(x,name) || span_present(rest,name)
    case _ <> rest:span_present(rest,name)

def check(on:Bool,probe:D.Probe) -> V.Action(Unit):
  match on probe:
    case False{} D.Off{}:V.Action.pure(Unit,Unit{})
    case True{} D.On{_,_,_,_,Count.Counters{w,W.U64{lo,hi},_,_,_,_},_,+spans,_,_}:
      Error.require(U32.is_eq(w,2) && U32.is_eq(lo,240) && U32.is_zero(hi) && span_present(spans,"mesh_vertex_host_write") && span_present(spans,"mesh_index_host_write"),"Upload diagnostic count or write spans differ")
    case _ _:Error.require(False{},"Wrong diagnostic mode")

def opened(renderer:Win.Renderer,on:Bool) -> V.Action(Unit):
  Win.Renderer{window,target,ranges,+probe} = renderer
  do V.Action<Unit>:
    check(on,probe)
    Win.close(Win.Renderer{window,target,ranges,probe})

def run(+entry:V.Entry,+on:Bool) -> V.Action(Unit):
  do V.Action<Unit>:
    renderer:Win.Renderer <- Bool.pick(V.Action(Win.Renderer),on,Win.open_measured(entry,"Upload diagnostics on",Example.mesh(False{})),Win.open(entry,"Upload diagnostics off",Example.mesh(False{})))
    opened(renderer,on)

def finished(pair:V.VkResult(Unit) & U32) -> IO(Unit):
  (result,live) = pair
  do IO<Unit>:
    V.or_exit(Unit,result)
    IO.try(Unit,Error.require(U32.is_zero(live),"Upload diagnostics leaked objects"))

def main() -> IO(Unit):
  do IO<Unit>:
    pair:V.VkResult(Unit) & U32 <- Scope.with(Unit,entry => run(entry,False{}))
    finished(pair)
    pair:V.VkResult(Unit) & U32 <- Scope.with(Unit,entry => run(entry,True{}))
    finished(pair)
    IO.print("Native window uploads diagnostics off/on verified; two writes, 240 bytes, both host-write spans; live Vulkan objects=0.")
