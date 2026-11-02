import Base

type Vec3 is Data:
  Vec3{x: F32, y: F32, z: F32}

type Quat is Data:
  Quat{x: F32, y: F32, z: F32, w: F32}

type Transform is Data:
  Transform{translation: Vec3, rotation: Quat, scale: Vec3}

type Velocity is Data:
  Velocity{linear: Vec3}

type MeshRef is Data:
  MeshRef{id: U32}

type MaterialRef is Data:
  MaterialRef{id: U32}

def Transform.identity() -> Transform:
  Transform{Vec3{0.0, 0.0, 0.0}, Quat{0.0, 0.0, 0.0, 1.0}, Vec3{1.0, 1.0, 1.0}}

def Velocity.zero() -> Velocity:
  Velocity{Vec3{0.0, 0.0, 0.0}}
