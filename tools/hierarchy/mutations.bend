import Base
import ../upload-boundary/scan.bend as S
import ../verify-upload-mutations.bend as Files
import ../verify-native-failures.bend as Replace
import ../verify-texture-mutations.bend as Gate

def mutation(+dest:String,+label:String,+path:String,before:String,after:String,+driver:String,failure:String) -> IO(Unit):
  do IO<Unit>:
    +original:String <- S.read(path)
    changed:String <- Replace.replaced(Replace.replace(String.split(original,'\n'),before,after))
    Files.save(dest ++ "/" ++ path,changed)
    Gate.gate(dest,label,driver,failure)
    Files.save(dest ++ "/" ++ path,original)
    Gate.gate(dest,label ++ "-restored",driver,"")
    IO.print(label ++ " rejected at named property; restored source passed")

def main() -> IO(Unit):
  do IO<Unit>:
    _:String <- S.run("mkdir",["-p","build/verification"])
    path:String <- S.run("mktemp",["-d","build/verification/hierarchy-controls-XXXXXXXX"])
    +dest:String = String.trim(path)
    IO.print("Hierarchy sensitivity evidence: " ++ dest)
    _:String <- S.run("cp",["-R","--reflink=auto","--","src","tools","examples","deps","assets","proofs","LAWS.bend","PROOF.bend","toolchain.bend",dest])
    _:String <- S.run("mkdir",["-p",dest ++ "/build",dest ++ "/docs/verification/2026-11-04-json-scene"])
    _:String <- S.run("cp",["-R","--reflink=auto","docs/verification/2026-11-04-json-scene/corpus",dest ++ "/docs/verification/2026-11-04-json-scene"])
    Gate.gate(dest,"baseline-runtime","hierarchy/runtime","")
    Gate.gate(dest,"baseline-render","hierarchy/render","")
    mutation(dest,"cycle-detection","src/hierarchy.bend",
      "    case (array,Visiting{}):Fail{Cycle{index}}",
      "    case (array,Visiting{}):Done{(array,initialized(Local{C.Transform.identity(),None{},Empty{},False{}}))}",
      "hierarchy/runtime","Creation self-parent accepted")
    mutation(dest,"composition","src/hierarchy.bend",
      "    case Some{GlobalTransform{matrix}}:GlobalTransform{M.multiply(matrix,M.model(local))}",
      "    case Some{GlobalTransform{matrix}}:GlobalTransform{M.model(local)}",
      "hierarchy/runtime","Hierarchy world position/composition differs from independent point oracle")
    mutation(dest,"bounds","src/hierarchy.bend",
      "  transformed(corners(bounds),matrix,Empty{})","  bounds",
      "hierarchy/runtime","Hierarchy world bounds differ from independent corner oracle")
    mutation(dest,"propagation","src/scene-hierarchy.bend",
      "def propagate(world:D.World()) -> D.World():propagated(update(world,Propagate{}))",
      "def propagate(world:D.World()) -> D.World():world",
      "hierarchy/runtime","Hierarchy accepted local differs from ECS Transform")
    mutation(dest,"json-parent","src/scene-file.bend",
      "    return placement_parent(item,parent)","    return placement_parent(item,None{})",
      "hierarchy/runtime","Hierarchy JSON placement parents or model anchors differ")
    mutation(dest,"normal-matrix","src/hierarchy.bend",
      "  inverse_columns(xyz(a),xyz(b),xyz(c))",
      "  Some{M.Mat4{a,b,c,M.Vec4{0.0,0.0,0.0,1.0}}}",
      "hierarchy/render","Hierarchy affine rendering/lighting differs from independent baked geometry")
    mutation(dest,"static-consumer","examples/textured-content.bend",
      "    case Create.Seed{t,m,H.Spatial{H.Local{_,p,_,_},g,_}} <> rest:Draw.item(p,t,m,g) <> draws(rest)",
      "    case Create.Seed{t,m,H.Spatial{H.Local{_,p,_,_},g,_}} <> rest:Draw.DrawItem{t,m} <> draws(rest)",
      "hierarchy/render","Static textured consumer discarded derived transforms")
    IO.print("Hierarchy baseline, seven production regressions and seven restored baselines passed")
