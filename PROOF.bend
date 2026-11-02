import ./deps/bend-vulkan/PROOF.bend as Vulkan
import ./deps/bendvy/test-fixtures/execution-laws/PROOF.bend as ECS
import ./tools/component-consumer.bend as Consumer
import Base
import ./src/components.bend as C
import ./LAWS.bend as Laws

def Laws.vec3_reconstruct(value):
  match value:
    case C.Vec3{x, y, z}: {==}

def Laws.vec3_fields(x, y, z):
  {==}

def Laws.quat_reconstruct(value):
  match value:
    case C.Quat{x, y, z, w}: {==}

def Laws.quat_fields(x, y, z, w):
  {==}

def Laws.transform_reconstruct(value):
  match value:
    case C.Transform{translation, rotation, scale}: {==}

def Laws.transform_fields(translation, rotation, scale):
  {==}

def Laws.velocity_reconstruct(value):
  match value:
    case C.Velocity{linear}: {==}

def Laws.velocity_fields(linear):
  {==}

def Laws.meshref_reconstruct(value):
  match value:
    case C.MeshRef{id}: {==}

def Laws.meshref_fields(id):
  {==}

def Laws.materialref_reconstruct(value):
  match value:
    case C.MaterialRef{id}: {==}

def Laws.materialref_fields(id):
  {==}

def Laws.identity():
  {==}

def Laws.zero():
  {==}

def Laws.translation_replacement(old, translation, rotation, scale):
  {==}
