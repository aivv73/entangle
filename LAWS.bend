import Base
import ./src/components.bend as C
import ./tools/component-consumer.bend as Consumer
import ./src/scene-motion.bend as Move
import ./src/scene-spawn.bend as Spawn
import ./src/scene-schema.bend as SceneSchema
import ./deps/bendvy/src/ecs/execution-command-removed.bend as Removed
import ./deps/bendvy/src/ecs/owner-product.bend as Product
import ./deps/bendvy/src/ecs/execution-effects.bend as Effects
import ./deps/bendvy/src/ecs/execution-system.bend as Sys
import ./deps/bendvy/src/ecs/world.bend as W
import ./deps/bendvy/src/ecs/execution-command-local.bend as Local

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

law scene_translation:
  for +x:F32
  for +y:F32
  for +z:F32
  for +rotation:C.Quat
  for +scale:C.Vec3
  {Move.advance(C.Transform{C.Vec3{x,y,z},rotation,scale}) == C.Transform{C.Vec3{F32.add(x,1.0),F32.add(y,0.5),F32.sub(z,2.0)},rotation,scale} : C.Transform}

law scene_rotation_scale:
  for +position:C.Vec3
  for +rotation:C.Quat
  for +scale:C.Vec3
  exs moved:C.Vec3
  {Move.advance(C.Transform{position,rotation,scale}) == C.Transform{moved,rotation,scale} : C.Transform}

law scene_seed:
  for +index:U32
  {Spawn.seed(index) == Product.Owner{Some{C.Transform{C.Vec3{U32.to_f32(index),F32.mul(2.0,U32.to_f32(index)),F32.neg(U32.to_f32(index))},C.Quat{0.0,0.0,0.6,0.8},C.Vec3{2.0,3.0,4.0}}},Some{C.MeshRef{7}}} : Removed.Removed(SceneSchema.components())}

law scene_seed_count:
  for +count:Nat
  for +index:U32
  {List.length(&1,Removed.Removed(SceneSchema.components()),Spawn.seeds(count,index)) == count : Nat}

law scene_empty_bootstrap:
  for F:Type -> Type
  for effects:Effects.Effects<F>
  for H:Type
  for Q:Type
  for caps:Spawn.Ops(Unit,F,H,Q)
  for commands:Local.Commands<Q,SceneSchema.Schema,C.Transform>
  for scope:H
  for queue:Q
  for +handles:List<&2,W.Handle<SceneSchema.Schema>>
  {Spawn.body(~Unit,~F,~effects,~H,~Q,~caps,~commands,scope,queue,Spawn.User{[],handles,[]}) == Effects.pure(~F,(H & (Q & (Spawn.User & Sys.Completion<String,Unit>))),effects,(scope,(queue,(Spawn.User{[],handles,[]},Sys.Success{Unit{}})))) : F(H & (Q & (Spawn.User & Sys.Completion<String,Unit>)))}
