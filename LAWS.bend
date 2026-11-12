import ./examples/courier-state.bend as Courier
import ./src/json-boundary.bend as Json
import ./src/hierarchy.bend as H
import ./src/scene-hierarchy.bend as Hierarchy
import ./src/scene-file.bend as SceneFile
import 0x37aacddc1dcb57464b8b5ac6c397bd64/json.bend as JsonParser
import ./deps/jonlib-obj/obj.bend as ModelParser
import ./src/model-obj.bend as Obj
import ./proofs/image-array.bend as ImageArray
import ./src/image-png.bend as Png
import ./deps/jonlib-png/codec.bend as PngCodec
import ./src/content.bend as F
import ./src/render-format.bend as Format
import ./src/lighting.bend as Light
import ./proofs/upload-range/spec.bend as UploadValue
import ./deps/bend-vulkan/src/core.bend as UploadCore
import ./deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as UploadWord
import ./src/mesh-control.bend as Player
import ./src/creation.bend as Create
import ./src/headless.bend as Headless
import ./src/scene-runtime.bend as Scene
import ./src/time.bend as Time
import ./src/input.bend as Input
import ./src/measurement-counters.bend as Counts
import ./src/scene-matrix.bend as Render
import ./examples/scene-seeds.bend as Seeds
import Base
import ./src/upload-size.bend as UploadSize
import ./src/scene-geometry-policy.bend as Geometry
import ./src/asset.bend as Asset

import ./src/components.bend as C
import ./tools/component-consumer.bend as Consumer
import ./src/scene-step.bend as Step
import ./src/scene-motion.bend as Move
import ./src/scene-spawn.bend as Spawn
import ./src/scene-schema.bend as SceneSchema
import ./deps/bendvy/src/ecs/world.bend as W
import ./deps/bendvy/src/ecs/system.bend as Sys
import ./deps/bendvy/src/ecs/schedule.bend as Schedule
import ./deps/bendvy/src/ecs/capabilities.bend as Cap
import ./deps/bendvy/src/ecs/transaction.bend as T
import ./src/scene-draw.bend as Draw
import ./src/scene-observe.bend as Observe
import ./deps/bendvy/src/ecs/inspector.bend as Inspector
import ./deps/bendvy/src/ecs/component.bend as Component

law scene_sync_boundary_pair:
  for +spawn:U32
  for +move:U32
  {Scene.steps(spawn,move) == [Schedule.System{spawn,0},Schedule.Barrier{},Schedule.System{move,0},Schedule.Barrier{}] : List<&2,Schedule.Step>}

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

law scene_step_adapter:
  for +state:C.Transform
  {Move.translate(state) == Step.step(Unit{},state) : C.Transform & Unit}

law scene_move_view_independent:
  for left:W.Handle<SceneSchema.Schema>
  for right:W.Handle<SceneSchema.Schema>
  for +value:C.Transform
  {Move.next(Move.Automatic{},left,value) == Move.next(Move.Automatic{},right,value) : Maybe<&2,C.Transform>}

law scene_move_current_component:
  for H:Type
  for cap:Cap.Write<H,C.Transform,C.Transform>
  for scope:H
  for handle:W.Handle<SceneSchema.Schema>
  for value:C.Transform
  {Move.current(~H,~cap,Move.Automatic{},handle,(scope,Component.Found{value})) == Move.write(~H,~cap,scope,Player.moved(Step.step(Unit{},value))) : H & (T.Outcome<String> & Unit)}

law scene_move_query_refusal:
  for H:Type
  for cap:Cap.Write<H,C.Transform,C.Transform>
  for scope:H
  for mode:Move.Mode
  for handle:W.Handle<SceneSchema.Schema>
  {Move.current(~H,~cap,mode,handle,(scope,Component.MissingEntity{})) == (scope,(T.Failure{"transform read refused"},Unit{})) : H & (T.Outcome<String> & Unit)}

law scene_move_write:
  for H:Type
  for cap:Cap.Write<H,C.Transform,C.Transform>
  for scope:H
  for value:C.Transform
  {Move.write(~H,~cap,scope,Some{value}) == (Cap.set(~H,~C.Transform,~C.Transform,~cap,scope,value),(T.Success{},Unit{})) : H & (T.Outcome<String> & Unit)}

law scene_translation:
  for +x:F32
  for +y:F32
  for +z:F32
  for +rotation:C.Quat
  for +scale:C.Vec3
  {Step.step(Unit{},C.Transform{C.Vec3{x,y,z},rotation,scale}) == (C.Transform{C.Vec3{F32.add(x,1.0),F32.add(y,0.5),F32.sub(z,2.0)},rotation,scale},Unit{}) : C.Transform & Unit}

law scene_rotation_scale:
  for +position:C.Vec3
  for +rotation:C.Quat
  for +scale:C.Vec3
  exs moved:C.Vec3
  {Step.step(Unit{},C.Transform{position,rotation,scale}) == (C.Transform{moved,rotation,scale},Unit{}) : C.Transform & Unit}

law scene_seed:
  for +index:U32
  {Seeds.seed(index) == Create.seed(C.Transform{C.Vec3{U32.to_f32(index),F32.mul(2.0,U32.to_f32(index)),F32.neg(U32.to_f32(index))},C.Quat{0.0,0.0,0.6,0.8},C.Vec3{2.0,3.0,4.0}},C.MeshRef{7}) : Create.Seed}

law scene_seed_count:
  for +count:Nat
  for +index:U32
  {List.length(&2,Create.Seed,Seeds.values(count,index)) == count : Nat}

law scene_empty_bootstrap:
  for world:SceneSchema.World()
  for +handles:List<&2,W.Handle<SceneSchema.Schema>>
  {Spawn.runner(world,Spawn.User{[],handles,[]}) == Sys.Succeeded{world,Spawn.User{[],handles,[]}} : Sys.Outcome<SceneSchema.World(),String,Spawn.User>}

law draw_payload:
  for handle:W.Handle<SceneSchema.Schema>
  for +transform:C.Transform
  for +mesh:C.MeshRef
  for accepted:C.Transform
  for local_bounds:H.Bounds
  for lit:Bool
  for global:H.GlobalTransform
  for bounds:H.Bounds
  {Hierarchy.drawing(Hierarchy.Row{handle,transform,mesh,H.Spatial{H.Local{accepted,None{},local_bounds,lit},global,bounds}}) == Draw.DrawItem{transform,mesh} : Draw.DrawItem}

law draw_child_payload:
  for handle:W.Handle<SceneSchema.Schema>
  for transform:C.Transform
  for +mesh:C.MeshRef
  for accepted:C.Transform
  for parent:U32
  for local_bounds:H.Bounds
  for lit:Bool
  for +global:H.GlobalTransform
  for bounds:H.Bounds
  {Hierarchy.drawing(Hierarchy.Row{handle,transform,mesh,H.Spatial{H.Local{accepted,Some{parent},local_bounds,lit},global,bounds}}) == Draw.GlobalItem{global,mesh} : Draw.DrawItem}

law draw_handle_independent:
  for left:W.Handle<SceneSchema.Schema>
  for right:W.Handle<SceneSchema.Schema>
  for +transform:C.Transform
  for +mesh:C.MeshRef
  for +spatial:H.Spatial
  {Hierarchy.drawing(Hierarchy.Row{left,transform,mesh,spatial}) == Hierarchy.drawing(Hierarchy.Row{right,transform,mesh,spatial}) : Draw.DrawItem}

law draw_found_order:
  for next:Hierarchy.Scope() -> List<&2,Hierarchy.Row> -> Hierarchy.Scope() & Result<&2,&2,H.Error,List<&2,Hierarchy.Row>>
  for frame:Hierarchy.Scope()
  for handle:W.Handle<SceneSchema.Schema>
  for +transform:C.Transform
  for +mesh:C.MeshRef
  for +spatial:H.Spatial
  for acc:List<&2,Hierarchy.Row>
  {Hierarchy.mesh_read(next,handle,transform,spatial,acc,(frame,Some{mesh})) == next(frame,Hierarchy.Row{handle,transform,mesh,spatial} <> acc) : Hierarchy.Scope() & Result<&2,&2,H.Error,List<&2,Hierarchy.Row>>}

law draw_absent_strict:
  for next:Hierarchy.Scope() -> List<&2,Hierarchy.Row> -> Hierarchy.Scope() & Result<&2,&2,H.Error,List<&2,Hierarchy.Row>>
  for frame:Hierarchy.Scope()
  for handle:W.Handle<SceneSchema.Schema>
  for transform:C.Transform
  for spatial:H.Spatial
  for acc:List<&2,Hierarchy.Row>
  {Hierarchy.mesh_read(next,handle,transform,spatial,acc,(frame,None{})) == (frame,Fail{H.MissingEntity{}}) : Hierarchy.Scope() & Result<&2,&2,H.Error,List<&2,Hierarchy.Row>>}

law row_missing_strict:
  for H:Type
  for next:H -> List<&2,Observe.Row> -> H & Result<&2,&2,Unit,List<&2,Observe.Row>>
  for frame:H
  for handle:W.Handle<SceneSchema.Schema>
  for transform:C.Transform
  for acc:List<&2,Observe.Row>
  for added:Bool
  for changed:Bool
  {Observe.found_mesh(~Observe.Row,~Observe.row,~H,next,handle,transform,acc,(frame,Inspector.Value{Component.MissingEntity{},added,changed})) == (frame,Fail{Unit{}}) : H & Result<&2,&2,Unit,List<&2,Observe.Row>>}

law row_found_order:
  for H:Type
  for next:H -> List<&2,Observe.Row> -> H & Result<&2,&2,Unit,List<&2,Observe.Row>>
  for frame:H
  for +handle:W.Handle<SceneSchema.Schema>
  for +transform:C.Transform
  for +mesh:C.MeshRef
  for acc:List<&2,Observe.Row>
  for added:Bool
  for changed:Bool
  {Observe.found_mesh(~Observe.Row,~Observe.row,~H,next,handle,transform,acc,(frame,Inspector.Value{Component.Found{mesh},added,changed})) == next(frame,Observe.Row{handle,transform,mesh} <> acc) : H & Result<&2,&2,Unit,List<&2,Observe.Row>>}

law row_absent_strict:
  for H:Type
  for next:H -> List<&2,Observe.Row> -> H & Result<&2,&2,Unit,List<&2,Observe.Row>>
  for frame:H
  for handle:W.Handle<SceneSchema.Schema>
  for transform:C.Transform
  for acc:List<&2,Observe.Row>
  for added:Bool
  for changed:Bool
  {Observe.found_mesh(~Observe.Row,~Observe.row,~H,next,handle,transform,acc,(frame,Inspector.Value{Component.ComponentAbsent{},added,changed})) == (frame,Fail{Unit{}}) : H & Result<&2,&2,Unit,List<&2,Observe.Row>>}

law row_finish_order:
  for frame:Inspector.Frame<SceneSchema.Schema,SceneSchema.Columns(),SceneSchema.Resources(),Unit>
  for acc:List<&2,Observe.Row>
  {Observe.values(~Observe.Row,~Observe.row,
    ~Inspector.Frame<SceneSchema.Schema,SceneSchema.Columns(),SceneSchema.Resources(),Unit>,
    ~Observe.mesh_read(~Inspector.Frame<SceneSchema.Schema,SceneSchema.Columns(),SceneSchema.Resources(),Unit>,Inspector.plan_caps(~SceneSchema.Schema,~SceneSchema.Columns(),~SceneSchema.Resources(),~Unit,~Observe.Ops,Observe.plan())),[],frame,acc) ==
    (frame,Done{List.reverse(&2,Observe.Row,acc)}) : Inspector.Frame<SceneSchema.Schema,SceneSchema.Columns(),SceneSchema.Resources(),Unit> & Result<&2,&2,Unit,List<&2,Observe.Row>>}

law draw_finish_order:
  for frame:Hierarchy.Scope()
  for acc:List<&2,Hierarchy.Row>
  {Hierarchy.read_rows([],frame,acc) == (frame,Done{List.reverse(&2,Hierarchy.Row,acc)}) : Hierarchy.Scope() & Result<&2,&2,H.Error,List<&2,Hierarchy.Row>>}

law draw_rows_order:
  for +row:Hierarchy.Row
  for rest:List<&2,Hierarchy.Row>
  {Hierarchy.draw_rows(row <> rest) == Hierarchy.drawing(row) <> Hierarchy.draw_rows(rest) : List<&2,Draw.DrawItem>}

law draw_rows_count:
  for +rows:List<&2,Hierarchy.Row>
  {List.length(&2,Draw.DrawItem,Hierarchy.draw_rows(rows)) == List.length(&2,Hierarchy.Row,rows) : Nat}

law draw_failure_strict:
  for world:SceneSchema.World()
  for error:H.Error
  {Hierarchy.drawn((world,Fail{error})) == (world,Fail{Unit{}}) : SceneSchema.World() & Result<&2,&2,Unit,Draw.DrawList>}

law draw_success_rows:
  for world:SceneSchema.World()
  for rows:List<&2,Hierarchy.Row>
  {Hierarchy.drawn((world,Done{rows})) == (world,Done{Draw.DrawList{Hierarchy.draw_rows(rows)}}) : SceneSchema.World() & Result<&2,&2,Unit,Draw.DrawList>}


law render_push_extent:
  for matrix:Render.Mat4
  {List.length(&1,U32,Render.matrix_words(matrix)) == 16n : Nat}

law render_indices_append:
  for +left:List<&2,U32>
  for +right:List<&2,U32>
  for +count:U32
  {F.indices_valid(List.append(&2,U32,left,right),count) ==
    Bool.and(F.indices_valid(left,count),F.indices_valid(right,count)) : Bool}

law render_indices_order:
  for +left:List<&2,U32>
  for +right:List<&2,U32>
  for +count:U32
  {F.indices_valid(List.append(&2,U32,left,right),count) ==
    F.indices_valid(List.append(&2,U32,right,left),count) : Bool}

law render_float_word_bits:
  for +word:U32
  {Render.float_bits(Render.float_word(word)) == word : U32}

law render_matrix_word_roundtrip:
  for +matrix:Render.Mat4
  {Render.from_words(Render.matrix_words(matrix)) == Some{matrix} : Maybe<Render.Mat4>}

law render_multiply_order:
  for +left:Render.Mat4
  for +a:Render.Vec4
  for +b:Render.Vec4
  for +c:Render.Vec4
  for +d:Render.Vec4
  {Render.multiply(left,Render.Mat4{a,b,c,d}) == Render.Mat4{Render.apply(left,a),Render.apply(left,b),Render.apply(left,c),Render.apply(left,d)} : Render.Mat4}

law render_apply_order:
  for +a:F32
  for +b:F32
  for +c:F32
  for +d:F32
  for +e:F32
  for +f:F32
  for +g:F32
  for +h:F32
  for +i:F32
  for +j:F32
  for +k:F32
  for +l:F32
  for +n:F32
  for +o:F32
  for +p:F32
  for +q:F32
  for +x:F32
  for +y:F32
  for +z:F32
  for +w:F32
  {Render.apply(Render.Mat4{Render.Vec4{a,b,c,d},Render.Vec4{e,f,g,h},Render.Vec4{i,j,k,l},Render.Vec4{n,o,p,q}},Render.Vec4{x,y,z,w}) == Render.Vec4{(a * x + e * y + i * z + n * w : F32),(b * x + f * y + j * z + o * w : F32),(c * x + g * y + k * z + p * w : F32),(d * x + h * y + l * z + q * w : F32)} : Render.Vec4}

law render_model_contract:
  for +tx:F32
  for +ty:F32
  for +tz:F32
  for +x:F32
  for +y:F32
  for +z:F32
  for +w:F32
  for +sx:F32
  for +sy:F32
  for +sz:F32
  {Render.model(C.Transform{C.Vec3{tx,ty,tz},C.Quat{x,y,z,w},C.Vec3{sx,sy,sz}}) == Render.Mat4{
    Render.Vec4{((1.0 - 2.0 * (y * y + z * z)) * sx : F32),(2.0 * (x * y + z * w) * sx : F32),(2.0 * (x * z - y * w) * sx : F32),0.0},
    Render.Vec4{(2.0 * (x * y - z * w) * sy : F32),((1.0 - 2.0 * (x * x + z * z)) * sy : F32),(2.0 * (y * z + x * w) * sy : F32),0.0},
    Render.Vec4{(2.0 * (x * z + y * w) * sz : F32),(2.0 * (y * z - x * w) * sz : F32),((1.0 - 2.0 * (x * x + y * y)) * sz : F32),0.0},
    Render.Vec4{tx,ty,tz,1.0}} : Render.Mat4}

law render_word_matrix_layout:
  for +a:U32
  for +b:U32
  for +c:U32
  for +d:U32
  for +e:U32
  for +f:U32
  for +g:U32
  for +h:U32
  for +i:U32
  for +j:U32
  for +k:U32
  for +l:U32
  for +m:U32
  for +n:U32
  for +o:U32
  for +p:U32
  {Maybe.map(&1,Render.Mat4,List<U32>,Render.matrix_words,Render.from_words([a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p])) == Some{[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p]} : Maybe<List<U32>>}

law render_float_roundtrip:
  for +value:F32
  {Render.float_word(Render.float_bits(value)) == value : F32}


law measurement_push_preserves_draws:
  for c: Counts.Counters
  for bytes: U32
  {Counts.draw_count(Counts.push(c,bytes)) == Counts.draw_count(c) : U32}

law measurement_draw_preserves_pushes:
  for c: Counts.Counters
  {Counts.push_count(Counts.draw(c)) == Counts.push_count(c) : U32}


law time_defaults:
  {(Time.interval(Time.defaults()),Time.limit(Time.defaults())) == (250n,4n) : Nat & Nat}

law time_positive:
  for config:Time.Config
  {Bool.and(Nat.is_lt(0n,Time.interval(config)),Nat.is_lt(0n,Time.limit(config))) == True{} : Bool}

law time_start:
  for +now:Nat
  {Time.start(now) == Time.Clock{now,0n} : Time.Clock}

law time_partition_total:
  for +limit:Nat
  for +whole:Nat
  for remainder:Nat
  for sample:Nat
  {Time.total(Time.partition(limit,whole,remainder,sample)) == whole : Nat}

law time_bounded:
  for +config:Time.Config
  for +clock:Time.Clock
  for +now:Nat
  {Nat.is_le(Time.steps(Time.poll(config,clock,now)),Time.limit(config)) == True{} : Bool}

law time_execution:
  for +config:Time.Config
  for +sample:Nat
  for +remainder:Nat
  for +now:Nat
  {Time.steps(Time.poll(config,Time.Clock{sample,remainder},now)) == Nat.min(Nat.div(Nat.add(remainder,Nat.sub(now,sample)),Time.interval(config)),Time.limit(config)) : Nat}

law time_remainder:
  for +config:Time.Config
  for clock:Time.Clock
  for now:Nat
  {Nat.is_lt(Time.remainder(Time.poll(config,clock,now)),Time.interval(config)) == True{} : Bool}

law time_accumulated_accounting:
  for +config:Time.Config
  for sample:Nat
  for +elapsed:Nat
  {Time.covered(config,Time.accumulated(config,sample,elapsed)) == elapsed : Nat}

law time_accounting:
  for +config:Time.Config
  for +sample:Nat
  for +remainder:Nat
  for +now:Nat
  {Time.covered(config,Time.poll(config,Time.Clock{sample,remainder},now)) == Nat.add(remainder,Nat.sub(now,sample)) : Nat}

law time_high_water:
  for config:Time.Config
  for +sample:Nat
  for remainder:Nat
  for +now:Nat
  {Time.clock(Time.poll(config,Time.Clock{sample,remainder},now)) == Time.Clock{Nat.max(sample,now),Nat.mod(Nat.add(remainder,Nat.sub(now,sample)),Time.interval(config))} : Time.Clock}

law input_close:
  for rest:List<Event>
  for camera:Maybe<Create.Camera>
  {Input.events(Close{} <> rest,camera) == None{} : Maybe<Create.Camera>}

law input_escape:
  for rest:List<Event>
  for camera:Maybe<Create.Camera>
  {Input.events(Key{27,True{}} <> rest,camera) == None{} : Maybe<Create.Camera>}

law input_drain:
  for -A:Type
  for rebuild:List<Event> -> A
  for pending:List<Event>
  {Input.drain(A,rebuild,pending) == rebuild([]) : A}

law input_snapshot:
  for -A:Type
  for rebuild:List<Event> -> A
  for pending:List<Event>
  for camera:Maybe<Create.Camera>
  {Input.snapshot(A,rebuild,pending,camera) == (Input.events(pending,camera),rebuild([])) : Maybe<Create.Camera> & A}

law module_initial_camera:
  {Input.initial() == Create.Camera{C.Vec3{0.0,0.0,0.0},0.65,0.45,7.0,Create.Perspective{1.7320508,0.1,100.0}} : Create.Camera}

law module_camera_reset:
  for camera: Create.Camera
  {Input.key(114,camera) == Input.reset(camera) : Create.Camera}

law headless_scene_zero:
  for app:Scene.Application()
  {Headless.advance(~Scene.Application(),~Scene.tick,0n,app) ==
    IO.pure(Scene.Application(),app) : IO(Scene.Application())}

law headless_scene_successor:
  for remaining:Nat
  for app:Scene.Application()
  {Headless.advance(~Scene.Application(),~Scene.tick,1n+remaining,app) ==
    IO.bind(Scene.Application(),Scene.Application(),Scene.tick(app),
      next => Headless.advance(~Scene.Application(),~Scene.tick,remaining,next)) : IO(Scene.Application())}

law creation_white:
  for vertex:F.Vertex
  {F.tint(vertex,F.white()) == vertex : F.Vertex}

law creation_tint_position:
  for +position:C.Vec3
  for color:C.Vec3
  for +uv:F.UV
  for +normal:C.Vec3
  for material:F.Material
  exs tinted:C.Vec3
  {F.tint(F.Vertex{position,color,uv,normal},material) == F.Vertex{position,tinted,uv,normal} : F.Vertex}

law creation_bundle_order:
  for +transform:C.Transform
  for +mesh:C.MeshRef
  for +spatial:H.Spatial
  for +rest:List<&2,Create.Seed>
  {Spawn.initial(Create.Seed{transform,mesh,spatial} <> rest) == Spawn.User{Create.Seed{transform,mesh,spatial} <> rest,[],[]} : Spawn.User}

law creation_empty:
  {Create.compile(Create.Scene{[]}) == Done{Create.Compiled{[],Create.Geometry{[],[],[]}}} : Result<&2,&2,Create.Error,Create.Compiled>}

law creation_resolve_empty:
  for id:U32
  {Create.resolve([],id) == None{} : Maybe<Create.Range>}

law creation_resolve_head:
  for +id:U32
  for first:U32
  for count:U32
  for +image:Maybe<&2,F.SourceImage>
  for rest:List<&2,Create.Range>
  {Create.resolve(Create.Range{id,first,count,image} <> rest,id) == Some{Create.Range{id,first,count,image}} : Maybe<Create.Range>}

law creation_empty_prepend:
  for geometry:Create.Geometry
  {Create.compile_items([],[],geometry,0,7) == Done{Create.Compiled{[],geometry}} : Result<&2,&2,Create.Error,Create.Compiled>}

law camera_reset_configuration:
  for target:C.Vec3
  for yaw:F32
  for pitch:F32
  for distance:F32
  for projection:Create.Projection
  {Input.reset(Create.Camera{target,yaw,pitch,distance,projection}) == Create.Camera{target,0.65,0.45,7.0,projection} : Create.Camera}

law creation_white_mesh:
  for vertices:List<&2,F.Vertex>
  {F.bake(vertices,F.white()) == vertices : List<&2,F.Vertex>}

law content_mesh_identity:
  for +mesh:F.Mesh
  {F.same_mesh(mesh,mesh) == True{} : Bool}

law content_material_identity:
  for +material:F.Material
  {F.same_material(material,material) == True{} : Bool}

law content_bake_count:
  for +vertices:List<&2,F.Vertex>
  for material:F.Material
  {List.length(&2,F.Vertex,F.bake(vertices,material)) == List.length(&2,F.Vertex,vertices) : Nat}

law content_bake_append:
  for left:List<&2,F.Vertex>
  for right:List<&2,F.Vertex>
  for +material:F.Material
  {F.bake(List.append(&2,F.Vertex,left,right),material) ==
    List.append(&2,F.Vertex,F.bake(left,material),F.bake(right,material)) : List<&2,F.Vertex>}

law creation_bad_mesh_first:
  for material:Bool
  for transform:Bool
  for +number:U32
  {Create.validate(False{},material,transform,number) == Fail{Create.BadMesh{number}} : Result<&2,&2,Create.Error,Unit>}

law creation_bad_material_second:
  for transform:Bool
  for +number:U32
  {Create.validate(True{},False{},transform,number) == Fail{Create.BadMaterial{number}} : Result<&2,&2,Create.Error,Unit>}

law creation_bad_transform_third:
  for +number:U32
  {Create.validate(True{},True{},False{},number) == Fail{Create.BadTransform{number}} : Result<&2,&2,Create.Error,Unit>}

law creation_duplicate_preserves_geometry:
  for +id:U32
  for mesh:F.Mesh
  for material:F.Material
  for +pairs:List<&2,Create.Used>
  for +geometry:Create.Geometry
  for +next:U32
  {Create.compile_pair(Some{id},mesh,material,pairs,geometry,next) == Done{Create.Plan{pairs,geometry,id,next}} : Result<&2,&2,Create.Error,Create.Plan>}

law creation_bundle_count:
  for +seeds:List<&2,Create.Seed>
  {Spawn.initial(seeds) == Spawn.User{seeds,[],[]} : Spawn.User}

law player_key_106_last_state:
  for a:Bool
  for b:Bool
  for keys:Player.Keys
  {Player.key(106,b,Player.key(106,a,keys)) == Player.key(106,b,keys) : Player.Keys}

law player_key_108_last_state:
  for a:Bool
  for b:Bool
  for keys:Player.Keys
  {Player.key(108,b,Player.key(108,a,keys)) == Player.key(108,b,keys) : Player.Keys}

law player_key_105_last_state:
  for a:Bool
  for b:Bool
  for keys:Player.Keys
  {Player.key(105,b,Player.key(105,a,keys)) == Player.key(105,b,keys) : Player.Keys}

law player_key_107_last_state:
  for a:Bool
  for b:Bool
  for keys:Player.Keys
  {Player.key(107,b,Player.key(107,a,keys)) == Player.key(107,b,keys) : Player.Keys}

law player_key_117_last_state:
  for a:Bool
  for b:Bool
  for keys:Player.Keys
  {Player.key(117,b,Player.key(117,a,keys)) == Player.key(117,b,keys) : Player.Keys}

law player_key_111_last_state:
  for a:Bool
  for b:Bool
  for keys:Player.Keys
  {Player.key(111,b,Player.key(111,a,keys)) == Player.key(111,b,keys) : Player.Keys}

law player_opposing_axis:
  for +down:Bool
  {Player.axis(down,down) == 0.0 : F32}

law player_clear_idempotent:
  for state:Player.Control
  {Player.clear(Player.clear(state)) == Player.clear(state) : Player.Control}

law player_reset_intent:
  for handle:Player.Handle()
  for keys:Player.Keys
  for initial:C.Transform
  for pending:Bool
  {Player.intent(32,True{},Player.PlayerReady{handle,keys,initial,pending}) == Player.PlayerReady{handle,Player.empty(),initial,True{}} : Player.Control}

law player_release_keeps_reset:
  for handle:Player.Handle()
  for keys:Player.Keys
  for initial:C.Transform
  {Player.intent(32,False{},Player.PlayerReady{handle,keys,initial,True{}}) == Player.PlayerReady{handle,keys,initial,True{}} : Player.Control}

law player_clear_keeps_reset:
  for handle:Player.Handle()
  for keys:Player.Keys
  for initial:C.Transform
  for pending:Bool
  {Player.clear(Player.PlayerReady{handle,keys,initial,pending}) == Player.PlayerReady{handle,Player.empty(),initial,pending} : Player.Control}

law player_translation_preserves_pose:
  for current:C.Transform
  for d:C.Vec3
  {Player.pose_fields(Player.shifted(current,d)) == Player.pose_fields((current,Unit{})) : C.Quat & C.Vec3}

law player_boot_no_write:
  for entity:Player.Handle()
  for current:C.Transform
  {Player.decide(Player.Boot{},entity,current) == None{} : Maybe<&2,C.Transform>}

law player_idle_no_write:
  for +keys:Player.Keys
  for current:C.Transform
  for initial:C.Transform
  for idle:{Player.idle(keys) == True{} : Bool}
  {Player.decision(keys,current,initial,False{}) == None{} : Maybe<&2,C.Transform>}

law player_writer_retained_handle:
  for +h:Player.Handle()
  for +entity:Player.Handle()
  for +keys:Player.Keys
  for +initial:C.Transform
  for current:C.Transform
  for +reset:Bool
  {Player.decide(Player.PlayerReady{h,keys,initial,reset},entity,current) == Bool.pick(Maybe<&2,C.Transform>,SceneSchema.same(h,entity),Player.decision(keys,current,initial,reset),None{}) : Maybe<&2,C.Transform>}

law player_reset_writer:
  for keys:Player.Keys
  for current:C.Transform
  for +initial:C.Transform
  {Player.decision(keys,current,initial,True{}) == Some{initial} : Maybe<&2,C.Transform>}

law player_inactive_clock_anchor:
  for clock:Time.Clock
  for +now:Nat
  {Player.clock_batch(False{},clock,now) == Time.Batch{Time.start(now),0n,0n} : Time.Batch}

law player_active_clock_policy:
  for clock:Time.Clock
  for now:Nat
  {Player.clock_batch(True{},clock,now) == Time.poll(Time.Config{15n,3n},clock,now) : Time.Batch}

law player_native_focus_boundary:
  for rest:List<Event>
  {Player.focus_boundary(Key{119,False{}} <> Key{115,False{}} <> Key{97,False{}} <> Key{100,False{}} <> Key{113,False{}} <> Key{101,False{}} <> Lost{0} <> rest) == (Key{119,False{}} <> Key{115,False{}} <> Key{97,False{}} <> Key{100,False{}} <> Key{113,False{}} <> Key{101,False{}} <> Lost{0} <> rest,True{}) : List<Event> & Bool}

law player_query_gate:
  for H:Type
  for cap:Cap.Write<H,C.Transform,C.Transform>
  for scope:H
  {Move.write(~H,~cap,scope,None{}) == (scope,(T.Success{},Unit{})) : H & (T.Outcome<String> & Unit)}

law upload_range_universal:
  for +c:UploadWord.U64
  for +o:UploadWord.U64
  for +l:UploadWord.U64
  {UploadCore.subrange_contains(c,o,l) == Bool.and(Nat.is_le(UploadValue.value(o),UploadValue.value(c)),Nat.is_le(Nat.add(UploadValue.value(o),UploadValue.value(l)),UploadValue.value(c))) : Bool}

law upload_transport_length:
  for +bytes:List<&2,U32>
  {List.length(&1,U32,UploadSize.transport(bytes)) == UploadSize.byte_length(bytes) : Nat}

law upload_conversion_exact:
  for +n:Nat
  for h:{UploadSize.exact(n) == True{} : Bool}
  {UploadValue.value(UploadSize.encode(n)) == n : Nat}

law geometry_install_reject:
  for -A:Data
  for +old:A
  for fresh:A
  {Geometry.select(A,old,fresh,False{}) == old : A}

law geometry_pair_allocations:
  for -A:Type
  for vertices:A
  for indices:A
  {Geometry.allocations(A,Some{(vertices,indices)}) == [vertices,indices] : List<A>}

law geometry_empty_allocations:
  for -A:Type
  {Geometry.allocations(A,None{}) == [] : List<A>}

law asset_release_entry:
  for -A:Data
  for +scope:String
  for +next:Nat
  for key:String
  for +id:Nat
  for state:Asset.State<A>
  {Asset.release_scoped(A,Asset.Cache{scope,next,[Asset.Entry{key,id,state}]},id,True{}) == Asset.Cache{scope,next,[]} : Asset.Cache<A>}

law asset_request_hit:
  for -A:Data
  for +scope:String
  for +next:Nat
  for +entries:List<&2,Asset.Entry<A>>
  for +key:String
  for +id:Nat
  for found:{Asset.find_key(A,entries,key) == Some{id} : Maybe<Nat>}
  {Asset.request(A,Asset.Cache{scope,next,entries},key) == (Asset.Cache{scope,next,entries},Asset.Handle{scope,id}) : Asset.Cache<A> & Asset.Handle<A>}

law asset_request_miss:
  for -A:Data
  for +scope:String
  for +next:Nat
  for +entries:List<&2,Asset.Entry<A>>
  for +key:String
  for found:{Asset.find_key(A,entries,key) == None{} : Maybe<Nat>}
  {Asset.request(A,Asset.Cache{scope,next,entries},key) == (Asset.Cache{scope,1n+next,Asset.Entry{key,next,Asset.Loading{}} <> entries},Asset.Handle{scope,next}) : Asset.Cache<A> & Asset.Handle<A>}

law asset_load_success:
  for -A:Data
  for +value:A
  {Asset.settle(A,Asset.Loading{},Done{value}) == Asset.Loaded{value} : Asset.State<A>}

law asset_load_failure:
  for -A:Data
  for +error:Asset.Error
  {Asset.settle(A,Asset.Loading{},Fail{error}) == Asset.Failed{error} : Asset.State<A>}

law asset_loaded_stable:
  for -A:Data
  for +value:A
  for result:Result<&2,&2,Asset.Error,A>
  {Asset.settle(A,Asset.Loaded{value},result) == Asset.Loaded{value} : Asset.State<A>}

law asset_failed_stable:
  for -A:Data
  for +error:Asset.Error
  for result:Result<&2,&2,Asset.Error,A>
  {Asset.settle(A,Asset.Failed{error},result) == Asset.Failed{error} : Asset.State<A>}

law asset_complete_preserves_keys:
  for -A:Data
  for +entries:List<&2,Asset.Entry<A>>
  for id:Nat
  for +key:String
  for result:Result<&2,&2,Asset.Error,A>
  {Asset.find_key(A,Asset.complete(A,entries,id,result),key) == Asset.find_key(A,entries,key) : Maybe<Nat>}

law asset_remove_absent:
  for -A:Data
  for entries:List<&2,Asset.Entry<A>>
  for +id:Nat
  {Asset.find_id(A,Asset.remove(A,entries,id),id) == None{} : Maybe<&2,Asset.State<A>>}

law asset_remove_no_work:
  for -A:Data
  for entries:List<&2,Asset.Entry<A>>
  for +id:Nat
  {Asset.pending(A,Asset.remove(A,entries,id),id) == None{} : Maybe<String>}

law asset_remove_idempotent:
  for -A:Data
  for +entries:List<&2,Asset.Entry<A>>
  for +id:Nat
  {Asset.remove(A,Asset.remove(A,entries,id),id) == Asset.remove(A,entries,id) : List<&2,Asset.Entry<A>>}

law asset_release_idempotent:
  for -A:Data
  for cache:Asset.Cache<A>
  for +handle:Asset.Handle<A>
  {Asset.release(A,Asset.release(A,cache,handle),handle) == Asset.release(A,cache,handle) : Asset.Cache<A>}

law asset_released_lookup:
  for -A:Data
  for cache:Asset.Cache<A>
  for +handle:Asset.Handle<A>
  {Asset.lookup(A,Asset.release(A,cache,handle),handle) == (Asset.release(A,cache,handle),None{}) : Asset.Cache<A> & Maybe<&2,Asset.State<A>>}

law asset_released_load:
  for -A:Data
  for cache:Asset.Cache<A>
  for +handle:Asset.Handle<A>
  for loader:String -> IO(Result<&2,&2,Asset.Error,A>)
  {Asset.load(A,Asset.release(A,cache,handle),handle,loader) == IO.pure(Asset.Cache<A>,Asset.release(A,cache,handle)) : IO(Asset.Cache<A>)}

law asset_release_counter:
  for -A:Data
  for +scope:String
  for +next:Nat
  for entries:List<&2,Asset.Entry<A>>
  for handle:Asset.Handle<A>
  exs remaining:List<&2,Asset.Entry<A>>
  {Asset.release(A,Asset.Cache{scope,next,entries},handle) == Asset.Cache{scope,next,remaining} : Asset.Cache<A>}

law asset_wrong_scope:
  for -A:Data
  for +scope:String
  for +other:String
  for next:Nat
  for entries:List<&2,Asset.Entry<A>>
  for id:Nat
  for different:{String.eq(scope,other) == False{} : Bool}
  {Asset.release(A,Asset.Cache{scope,next,entries},Asset.Handle{other,id}) == Asset.Cache{scope,next,entries} : Asset.Cache<A>}

law image_array_leaf:
  for value:U32
  for tail:List<&2,U32>
  {Png.array_words(ALeaf{value},tail) == value <> tail : List<&2,U32>}

law image_array_order:
  for left:Array<U32>
  for right:Array<U32>
  for tail:List<&2,U32>
  {Png.array_words(ANode{left,right},tail) == Png.array_words(left,Png.array_words(right,tail)) : List<&2,U32>}

law image_array_tail:
  for +array:ImageArray.Tree
  for +tail:List<&2,U32>
  {Png.array_words(ImageArray.array(array),tail) == List.append(&2,U32,Png.array_words(ImageArray.array(array),[]),tail) : List<&2,U32>}

law image_array_count:
  for +array:ImageArray.Tree
  for +tail:List<&2,U32>
  {List.length(&2,U32,Png.array_words(ImageArray.array(array),tail)) == Nat.add(List.length(&2,U32,Png.array_words(ImageArray.array(array),[])),List.length(&2,U32,tail)) : Nat}

law image_array_capacity:
  for +tree:ImageArray.Tree
  {List.length(&2,U32,Png.array_words(ImageArray.array(tree),[])) == ImageArray.count(tree) : Nat}

law image_storage_rule:
  for +width:U32
  for +height:U32
  for +pixels:List<&2,U32>
  {F.image_valid(F.SourceImage{width,height,pixels}) == (U32.is_gt(width,0) && U32.is_gt(height,0) && Nat.is_eq(List.length(&2,U32,pixels),Nat.mul(U32.to_nat(width),U32.to_nat(height)))) : Bool}

law image_padding:
  for +a:U32
  for +b:U32
  for +c:U32
  for padding:U32
  {Png.picture(Done{PngCodec.Picture{3,1,4,ANode{ANode{ALeaf{a},ALeaf{b}},ANode{ALeaf{c},ALeaf{padding}}}}}) == Done{F.SourceImage{3,1,[a,b,c]}} : Result<&2,&2,Asset.Error,F.SourceImage>}

law image_exact_read:
  for bytes:List<&2,U32>
  {Png.exact(bytes,False{}) == Fail{Asset.Error{2147483655,"PNG file size changed or read was incomplete"}} : Result<&2,&2,Asset.Error,F.SourceImage>}

law image_error_header:
  {Png.decoder_error(PngCodec.BadHeader{}) == Asset.Error{2147483649,"PNG BadHeader"} : Asset.Error}
law image_error_byte:
  {Png.decoder_error(PngCodec.BadByte{}) == Asset.Error{2147483650,"PNG BadByte"} : Asset.Error}
law image_error_size:
  {Png.decoder_error(PngCodec.BadSize{}) == Asset.Error{2147483651,"PNG BadSize"} : Asset.Error}
law image_error_truncated:
  {Png.decoder_error(PngCodec.Truncated{}) == Asset.Error{2147483652,"PNG Truncated"} : Asset.Error}
law image_error_stream:
  {Png.decoder_error(PngCodec.BadStream{}) == Asset.Error{2147483653,"PNG BadStream"} : Asset.Error}

law model_pair_validity:
  for +mesh:F.Mesh
  for +material:F.Material
  for labels:F.ModelLabels
  for +rest:List<&2,F.ModelPart>
  {F.parts_valid(F.ModelPart{mesh,material,labels} <> rest) == (F.mesh_valid(mesh) && F.material_valid(material) && F.parts_valid(rest)) : Bool}

law model_aggregate_validity:
  for +parts:List<&2,F.ModelPart>
  {F.model_valid(F.SourceModel{parts}) == (F.parts_valid(parts) && F.counts_fit(F.model_counts(parts))) : Bool}

law model_triangle_emission:
  for a:F.Vertex
  for b:F.Vertex
  for c:F.Vertex
  for tail:List<&2,F.Vertex>
  {Obj.emit_vertices(a,b,c,tail) == c <> b <> a <> tail : List<&2,F.Vertex>}

law model_triangle_corner_count:
  for a:F.Vertex
  for b:F.Vertex
  for c:F.Vertex
  for tail:List<&2,F.Vertex>
  {List.length(&2,F.Vertex,Obj.emit_vertices(a,b,c,tail)) == 3n+List.length(&2,F.Vertex,tail) : Nat}

law model_local_indices:
  for +local:U32
  for tail:List<&2,U32>
  {Obj.emit_indices(local,tail) == U32.add(local,2) <> U32.inc(local) <> local <> tail : List<&2,U32>}

law model_index_count:
  for local:U32
  for tail:List<&2,U32>
  {List.length(&2,U32,Obj.emit_indices(local,tail)) == 3n+List.length(&2,U32,tail) : Nat}

law model_first_triangle_order:
  for +a:F.Vertex
  for +b:F.Vertex
  for +c:F.Vertex
  {List.reverse(&2,F.Vertex,Obj.emit_vertices(a,b,c,[])) == [a,b,c] : List<&2,F.Vertex>}

law model_first_indices:
  {List.reverse(&2,U32,Obj.emit_indices(0,[])) == [0,1,2] : List<&2,U32>}

law model_initial_material:
  for materials:List<&2,Obj.NamedMaterial>
  for line:Nat
  {Obj.selected(None{},materials,line) == Done{Obj.Selected{4294967295,F.white()}} : Result<&2,&2,Asset.Error,Obj.Selected>}

law model_missing_material:
  for +name:String
  for +line:Nat
  for index:U32
  {Obj.named([],name,line,index) == Fail{Obj.error(5,"OBJ",line,"unresolved usemtl " ++ name)} : Result<&2,&2,Asset.Error,Obj.Selected>}

law model_raw_zero:
  for count:Nat
  for +line:Nat
  {Obj.index("0",count,line) == Fail{Obj.error(4,"OBJ",line,"nonzero complete signed 31-bit index required")} : Result<&2,&2,Asset.Error,Unit>}

law model_negative_zero:
  for count:Nat
  for +line:Nat
  {Obj.index("-0",count,line) == Fail{Obj.error(4,"OBJ",line,"nonzero complete signed 31-bit index required")} : Result<&2,&2,Asset.Error,Unit>}

law model_run_conservation:
  for +n:Nat
  for labels:F.ModelLabels
  for line:Nat
  for rest:List<&2,Obj.Run>
  {Obj.run_count(Obj.Run{n,labels,line} <> rest) == Nat.add(n,Obj.run_count(rest)) : Nat}

law model_run_boundary:
  for +labels:F.ModelLabels
  for +previous:F.ModelLabels
  for +line:Nat
  for +first:Nat
  for +n:Nat
  for +rest:List<&2,Obj.Run>
  for different:{F.same_labels(labels,previous) == False{} : Bool}
  {Obj.add_run(Obj.Run{n,previous,first} <> rest,labels,line) == Obj.Run{1n,labels,line} <> Obj.Run{n,previous,first} <> rest : List<&2,Obj.Run>}

law model_checked_success:
  for +model:F.SourceModel
  {Obj.valid_result(Obj.admit(model)) == True{} : Bool}

law model_reject_incomplete_read:
  for +bytes:List<&2,U32>
  for +size:U32
  for +path:String
  for incomplete:{Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(size)) == False{} : Bool}
  {Obj.exact(Done{bytes},size,path) == Fail{Obj.error(8,path,0n,"file size changed or read was incomplete")} : Result<&2,&2,Asset.Error,List<&2,U32>>}

law model_expanded_limit:
  {F.mesh_fits(381300n,381300n) == True{} : Bool}
law model_expanded_over_limit:
  {F.mesh_fits(381303n,381303n) == False{} : Bool}

law model_admit_result:
  for result:Result<&2,&2,Asset.Error,F.SourceModel>
  {Obj.valid_result(Obj.admit_result(result)) == True{} : Bool}

law model_finish_valid:
  for plan:Obj.Plan
  for materials:Obj.Materials
  {Obj.valid_result(Obj.finish(plan,materials)) == True{} : Bool}

law model_finish_bytes_valid:
  for plan:Obj.Plan
  for mtl:Maybe<&2,List<&2,U32>>
  {Obj.valid_result(Obj.finish_bytes(plan,mtl)) == True{} : Bool}

law model_decode_valid:
  for obj:List<&2,U32>
  for mtl:Maybe<&2,List<&2,U32>>
  {Obj.valid_result(Obj.decode(obj,mtl)) == True{} : Bool}

law model_parsed_word:
  for +value:F32
  for +source:String
  for +line:Nat
  for finite:{F.finite(value) == True{} : Bool}
  {Obj.parsed(ModelParser.Parsed{False{},Some{value}},source,line) == Done{value} : Result<&2,&2,Asset.Error,F32>}

law model_negative_relative:
  for +value:U32
  for +count:U32
  for nonzero:{U32.is_eq(value,0) == False{} : Bool}
  for in_range:{U32.is_le(value,count) == True{} : Bool}
  {ModelParser.fix.int(True{},value,count) == ModelParser.Fix{True{},U32.sub(count,value)} : ModelParser.Fix}

law model_run_coalescing:
  for +labels:F.ModelLabels
  for +previous:F.ModelLabels
  for line:Nat
  for +first:Nat
  for +n:Nat
  for +rest:List<&2,Obj.Run>
  for equal:{F.same_labels(labels,previous) == True{} : Bool}
  {Obj.add_run(Obj.Run{n,previous,first} <> rest,labels,line) == Obj.Run{1n+n,previous,first} <> rest : List<&2,Obj.Run>}

law model_source_limit_shadowed:
  {Nat.is_lt(Obj.obj_limit(),Nat.sub(Nat.mul(699050n,8n),1n)) == True{} : Bool}

law json_guard_reject:
  for code:U32
  for path:String
  for reason:String
  {Json.need(False{},code,path,reason) == Fail{Json.error(code,path,reason)} : Result<&2,&1,Asset.Error,Unit>}

law json_encoded_bound:
  for +bytes:List<&2,U32>
  for +path:String
  for oversized:{Nat.is_le(List.length(&2,U32,bytes),Json.byte_limit()) == False{} : Bool}
  {Json.parse(bytes,path) == Fail{Json.error(2,path,"JSON exceeds 65536 bytes")} : Result<&2,&1,Asset.Error,JsonParser.Val>}

law json_read_exact:
  for +bytes:List<&2,U32>
  for +size:U32
  for +path:String
  for incomplete:{Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(size)) == False{} : Bool}
  {Json.exact(Done{bytes},size,path) == Fail{Json.error(6,path,"file changed or read incomplete")} : Result<&2,&2,Asset.Error,List<&2,U32>>}

law json_reject_image_as_model:
  for id:String
  for path:String
  {SceneFile.reference_kind(True{},SceneFile.Image{},id,path) == Fail{Json.error(5,path,"image used as model " ++ id)} : Result<&2,&2,Asset.Error,Unit>}

law json_unresolved_reference:
  for +id:String
  for +path:String
  {SceneFile.model_reference([],id,path) == Fail{Json.error(5,path,"unresolved model " ++ id)} : Result<&2,&2,Asset.Error,Unit>}

law json_preserve_model_part:
  for mesh:F.Mesh
  for material:F.Material
  for labels:F.ModelLabels
  for transform:C.Transform
  {SceneFile.instances([F.ModelPart{mesh,material,labels}],transform) == [Create.Instance{mesh,material,transform}] : List<&2,Create.Instance>}

law json_admitted_scene_compiles:
  for +scene:Create.Scene
  for path:String
  {SceneFile.valid_result(SceneFile.admit(scene,path)) == True{} : Bool}

law json_depth_limit:
  {Json.depth_limit() == 8 : U32}

law vertex_upload_stride:
  for vertex:F.Vertex
  {U32.from_nat(Nat.mul(4n,List.length(&1,U32,Format.vertex_words(vertex)))) == F.vertex_stride() : U32}

law texture_rgba_bytes:
  for +pixel:U32
  {Format.pixel_bytes(pixel) == [UploadCore.word_byte(pixel,3),UploadCore.word_byte(pixel,2),UploadCore.word_byte(pixel,1),UploadCore.word_byte(pixel,0)] : List<&2,U32>}

law textured_source_retained:
  for tint:C.Vec3
  for +image:F.SourceImage
  {F.material_image(F.Textured{tint,image}) == Some{image} : Maybe<&2,F.SourceImage>}

law texture_zero_width:
  for height:U32
  for pixels:List<&2,U32>
  {F.texture_valid(F.SourceImage{0,height,pixels}) == False{} : Bool}

law light_requires_direction:
  for +direction:C.Vec3
  for +color:C.Vec3
  for +ambient:F32
  for +intensity:F32
  for invalid:{F.normal_valid(direction) == False{} : Bool}
  {Light.valid(Light.Directional{direction,color,ambient,intensity}) == False{} : Bool}

law hierarchy_root_matrix:
  for local:C.Transform
  {H.compose(None{},local) == H.GlobalTransform{Render.model(local)} : H.GlobalTransform}

law hierarchy_root_draw:
  for local:C.Transform
  for mesh:C.MeshRef
  for global:H.GlobalTransform
  {Draw.item(None{},local,mesh,global) == Draw.DrawItem{local,mesh} : Draw.DrawItem}

law hierarchy_child_draw:
  for parent:U32
  for local:C.Transform
  for mesh:C.MeshRef
  for global:H.GlobalTransform
  {Draw.item(Some{parent},local,mesh,global) == Draw.GlobalItem{global,mesh} : Draw.DrawItem}

law hierarchy_parent_composition:
  for parent:Render.Mat4
  for local:C.Transform
  {H.compose(Some{H.GlobalTransform{parent}},local) == H.GlobalTransform{Render.multiply(parent,Render.model(local))} : H.GlobalTransform}

law hierarchy_empty_bounds:
  for global:H.GlobalTransform
  {H.world_bounds(global,H.Empty{}) == H.Empty{} : H.Bounds}

law hierarchy_derived_bounds:
  for global:H.GlobalTransform
  for local:H.Bounds
  {H.world_bounds(global,local) == H.transformed(H.corners(local),H.matrix(global),H.Empty{}) : H.Bounds}

law hierarchy_visiting_rejected:
  for array:Array<H.Mark>
  for index:U32
  for next:U32 -> Array<H.Mark> -> Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>
  {H.visit_mark((array,H.Visiting{}),index,next) == Fail{H.Cycle{index}} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}

law hierarchy_missing_rejected:
  for array:Array<H.Mark>
  for index:U32
  for next:U32 -> Array<H.Mark> -> Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>
  {H.visit_checked(False{},index,array,next) == Fail{H.MissingParent{index}} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}

law hierarchy_invalid_derived_rejected:
  for index:U32
  for local:H.Local
  for global:H.GlobalTransform
  for bounds:H.Bounds
  {H.derived(False{},index,local,global,bounds) == Fail{H.InvalidTransform{index}} : Result<&2,&2,H.Error,H.Spatial>}

law hierarchy_parent_rejection_preserves_world:
  for entity:W.Handle<SceneSchema.Schema>
  for parent:Maybe<&2,W.Handle<SceneSchema.Schema>>
  for world:SceneSchema.World()
  for rows:List<&2,Hierarchy.Row>
  for error:H.Error
  {Hierarchy.evaluated(Hierarchy.SetParent{entity,parent},world,rows,Fail{error}) == (world,Fail{error}) : SceneSchema.World() & Result<&2,&2,H.Error,Unit>}

law hierarchy_transform_rejection_preserves_world:
  for entity:W.Handle<SceneSchema.Schema>
  for transform:C.Transform
  for world:SceneSchema.World()
  for rows:List<&2,Hierarchy.Row>
  for error:H.Error
  {Hierarchy.evaluated(Hierarchy.SetTransform{entity,transform},world,rows,Fail{error}) == (world,Fail{error}) : SceneSchema.World() & Result<&2,&2,H.Error,Unit>}

law courier_reset_restores_every_state:
  for state:Courier.State
  {Courier.key(120,state) == Courier.initial() : Courier.State}

law courier_complete_interaction_absorbs:
  for x:U32
  for z:U32
  {Courier.interact(x,z,Courier.Complete{}) == Courier.Complete{} : Courier.Phase}

law courier_complete_movement_stops:
  for x:U32
  for z:U32
  {Courier.key(106,Courier.State{x,z,Courier.Complete{}}) == Courier.State{x,z,Courier.Complete{}} : Courier.State}

law courier_search_cannot_complete:
  for +x:U32
  for +z:U32
  {Courier.interact(x,z,Courier.Searching{}) == Bool.pick(Courier.Phase,U32.is_eq(x,1) && U32.is_eq(z,3),Courier.Carrying{},Courier.Searching{}) : Courier.Phase}
