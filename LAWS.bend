import Base
import ./src/components.bend as C
import ./tools/component-consumer.bend as Consumer

law vec3_reconstruct:
  for +value: C.Vec3
  {Consumer.vec3_reconstruct(value) == value : C.Vec3}

law vec3_fields:
  for +x: F32
  for +y: F32
  for +z: F32
  {Consumer.vec3_fields(C.Vec3{x, y, z}) == (x, (y, z)) : F32 & F32 & F32}

law quat_reconstruct:
  for +value: C.Quat
  {Consumer.quat_reconstruct(value) == value : C.Quat}

law quat_fields:
  for +x: F32
  for +y: F32
  for +z: F32
  for +w: F32
  {Consumer.quat_fields(C.Quat{x, y, z, w}) == (x, (y, (z, w))) : F32 & F32 & F32 & F32}

law transform_reconstruct:
  for +value: C.Transform
  {Consumer.transform_reconstruct(value) == value : C.Transform}

law transform_fields:
  for +translation: C.Vec3
  for +rotation: C.Quat
  for +scale: C.Vec3
  {Consumer.transform_fields(C.Transform{translation, rotation, scale}) == (translation, (rotation, scale)) : C.Vec3 & C.Quat & C.Vec3}

law velocity_reconstruct:
  for +value: C.Velocity
  {Consumer.velocity_reconstruct(value) == value : C.Velocity}

law velocity_fields:
  for +linear: C.Vec3
  {Consumer.velocity_fields(C.Velocity{linear}) == linear : C.Vec3}

law meshref_reconstruct:
  for +value: C.MeshRef
  {Consumer.meshref_reconstruct(value) == value : C.MeshRef}

law meshref_fields:
  for +id: U32
  {Consumer.meshref_fields(C.MeshRef{id}) == id : U32}

law materialref_reconstruct:
  for +value: C.MaterialRef
  {Consumer.materialref_reconstruct(value) == value : C.MaterialRef}

law materialref_fields:
  for +id: U32
  {Consumer.materialref_fields(C.MaterialRef{id}) == id : U32}

law identity:
  {C.Transform.identity() == C.Transform{C.Vec3{0.0, 0.0, 0.0}, C.Quat{0.0, 0.0, 0.0, 1.0}, C.Vec3{1.0, 1.0, 1.0}} : C.Transform}

law zero:
  {C.Velocity.zero() == C.Velocity{C.Vec3{0.0, 0.0, 0.0}} : C.Velocity}

law translation_replacement:
  for +old: C.Vec3
  for +translation: C.Vec3
  for +rotation: C.Quat
  for +scale: C.Vec3
  {Consumer.replace_translation(C.Transform{old, rotation, scale}, translation) == C.Transform{translation, rotation, scale} : C.Transform}
