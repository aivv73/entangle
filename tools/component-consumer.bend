import Base
import ../src/components.bend as C

def vec3_reconstruct(value: C.Vec3) -> C.Vec3:
  C.Vec3{x, y, z} = value
  C.Vec3{x, y, z}

def vec3_fields(value: C.Vec3) -> F32 & F32 & F32:
  C.Vec3{x, y, z} = value
  (x, (y, z))

def quat_reconstruct(value: C.Quat) -> C.Quat:
  C.Quat{x, y, z, w} = value
  C.Quat{x, y, z, w}

def quat_fields(value: C.Quat) -> F32 & F32 & F32 & F32:
  C.Quat{x, y, z, w} = value
  (x, (y, (z, w)))

def transform_reconstruct(value: C.Transform) -> C.Transform:
  C.Transform{translation, rotation, scale} = value
  C.Transform{translation, rotation, scale}

def transform_fields(value: C.Transform) -> C.Vec3 & C.Quat & C.Vec3:
  C.Transform{translation, rotation, scale} = value
  (translation, (rotation, scale))

def velocity_reconstruct(value: C.Velocity) -> C.Velocity:
  C.Velocity{linear} = value
  C.Velocity{linear}

def velocity_fields(value: C.Velocity) -> C.Vec3:
  C.Velocity{linear} = value
  linear

def meshref_reconstruct(value: C.MeshRef) -> C.MeshRef:
  C.MeshRef{id} = value
  C.MeshRef{id}

def meshref_fields(value: C.MeshRef) -> U32:
  C.MeshRef{id} = value
  id

def materialref_reconstruct(value: C.MaterialRef) -> C.MaterialRef:
  C.MaterialRef{id} = value
  C.MaterialRef{id}

def materialref_fields(value: C.MaterialRef) -> U32:
  C.MaterialRef{id} = value
  id

def replace_translation(value: C.Transform, translation: C.Vec3) -> C.Transform:
  C.Transform{_, rotation, scale} = value
  C.Transform{translation, rotation, scale}
