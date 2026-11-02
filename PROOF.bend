import ./deps/bend-vulkan/PROOF.bend as Vulkan
import ./deps/bendvy/test-fixtures/execution-laws/PROOF.bend as ECS
import ./tools/component-consumer.bend as Consumer
import Base
import ./src/components.bend as C
import ./LAWS.bend as Laws
import ./src/scene-spawn.bend as Spawn
import ./src/scene-schema.bend as SceneSchema
import ./deps/bendvy/src/ecs/execution-command-removed.bend as Removed

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

def Laws.scene_translation(x,y,z,rotation,scale):
  {==}

def Laws.scene_rotation_scale(position,rotation,scale):
  match position:
    case C.Vec3{x,y,z}:(C.Vec3{F32.add(x,1.0),F32.add(y,0.5),F32.sub(z,2.0)},{==})

def Laws.scene_seed(index):
  {==}

def Laws.scene_seed_count(count,index):
  match count:
    case 0n:{==}
    case 1n++rest:
      Equal.cong(Nat,Nat,n => 1n+n,List.length(&1,Removed.Removed(SceneSchema.components()),Spawn.seeds(rest,U32.add(index,1))),rest,Laws.scene_seed_count(rest,U32.add(index,1)))

def Laws.scene_empty_bootstrap(F,effects,H,Q,caps,commands,scope,queue,handles):
  {==}
