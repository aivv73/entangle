import Base
import ../src/components.bend as C
import ../tools/component-consumer.bend as Consumer

def from_bits(value: U32) -> F32:
  U32{data} = value
  F32{data}

def vec_bits(value: C.Vec3, x: U32, y: U32, z: U32) -> Bool:
  C.Vec3{a, b, c} = value
  U32.is_eq(F32.bits(a), x) && U32.is_eq(F32.bits(b), y) && U32.is_eq(F32.bits(c), z)

def quat_bits(value: C.Quat, x: U32, y: U32, z: U32, w: U32) -> Bool:
  C.Quat{a, b, c, d} = value
  U32.is_eq(F32.bits(a), x) && U32.is_eq(F32.bits(b), y) && U32.is_eq(F32.bits(c), z) && U32.is_eq(F32.bits(d), w)

def require(ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.pure(Unit, Unit{})
    case False{}: IO.die(Unit, 1, "Component field verification failed")

def transform_bits(value: C.Transform, translation: C.Vec3, rotation: C.Quat, scale: C.Vec3) -> Bool:
  C.Transform{t, r, s} = value
  C.Vec3{tx, ty, tz} = translation
  C.Quat{rx, ry, rz, rw} = rotation
  C.Vec3{sx, sy, sz} = scale
  vec_bits(t, F32.bits(tx), F32.bits(ty), F32.bits(tz)) && quat_bits(r, F32.bits(rx), F32.bits(ry), F32.bits(rz), F32.bits(rw)) && vec_bits(s, F32.bits(sx), F32.bits(sy), F32.bits(sz))

def velocity_bits(value: C.Velocity, x: U32, y: U32, z: U32) -> Bool:
  C.Velocity{linear} = value
  vec_bits(linear, x, y, z)

def mesh_id(value: C.MeshRef, expected: U32) -> Bool:
  C.MeshRef{id} = value
  U32.is_eq(id, expected)

def material_id(value: C.MaterialRef, expected: U32) -> Bool:
  C.MaterialRef{id} = value
  U32.is_eq(id, expected)

def main() -> IO(Unit):
  +translation : C.Vec3 = C.Vec3{from_bits(2147483648), from_bits(2143289345), from_bits(1)}
  +rotation : C.Quat = C.Quat{2.0, from_bits(3225419776), 4.0, from_bits(3231711232)}
  +scale : C.Vec3 = C.Vec3{6.0, 7.0, 8.0}
  +replacement : C.Vec3 = C.Vec3{9.0, 10.0, 11.0}
  do IO<Unit>:
    require(transform_bits(Consumer.transform_reconstruct(C.Transform{translation, rotation, scale}), translation, rotation, scale))
    require(transform_bits(C.Transform.identity(), C.Vec3{0.0, 0.0, 0.0}, C.Quat{0.0, 0.0, 0.0, 1.0}, C.Vec3{1.0, 1.0, 1.0}))
    require(velocity_bits(C.Velocity.zero(), 0, 0, 0))
    require(velocity_bits(Consumer.velocity_reconstruct(C.Velocity{translation}), 2147483648, 2143289345, 1))
    require(transform_bits(Consumer.replace_translation(C.Transform{translation, rotation, scale}, replacement), replacement, rotation, scale))
    require(vec_bits(Consumer.vec3_reconstruct(translation), 2147483648, 2143289345, 1))
    require(quat_bits(Consumer.quat_reconstruct(rotation), 1073741824, 3225419776, 1082130432, 3231711232))
    require(mesh_id(Consumer.meshref_reconstruct(C.MeshRef{0}), 0))
    require(material_id(Consumer.materialref_reconstruct(C.MaterialRef{4294967295}), 4294967295))
    require(mesh_id(C.MeshRef{4294967295}, 4294967295))
    require(material_id(C.MaterialRef{0}, 0))
    IO.print("Project component fields and defaults verified.")
