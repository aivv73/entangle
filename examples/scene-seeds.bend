import Base
import ../src/creation.bend as Create
import ../src/components.bend as V

def seed(+index:U32) -> Create.Seed:
  +i = U32.to_f32(index)
  Create.seed(V.Transform{V.Vec3{i,F32.mul(2.0,i),F32.neg(i)},V.Quat{0.0,0.0,0.6,0.8},V.Vec3{2.0,3.0,4.0}},V.MeshRef{7})

def values(count:Nat,+index:U32) -> List<&2,Create.Seed>:
  match count:
    case 0n:[]
    case 1n++rest:seed(index) <> values(rest,U32.inc(index))

def defaults() -> List<&2,Create.Seed>:values(100n,0)
