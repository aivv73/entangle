import ./src/creation.bend as Create
import ./src/headless.bend as Headless
import ./src/scene.bend as Scene
import ./src/time.bend as Time
import ./src/input.bend as Input
import ./src/measurement-counters.bend as Counts
import ./src/scene-mesh.bend as Mesh
import ./src/scene-matrix.bend as Render
import ./examples/scene-seeds.bend as Seeds
import Base
import ./deps/bendvy/src/ecs/execution-deferred-schedule.bend as Deferred
import ./deps/bendvy/src/ecs/execution-inspector-component.bend as Columns
import ./deps/bendvy/src/ecs/execution-composer-layout.bend as Layout
import ./src/components.bend as C
import ./tools/component-consumer.bend as Consumer
import ./src/scene-step.bend as Step
import ./src/scene-motion.bend as Move
import ./src/scene-spawn.bend as Spawn
import ./src/scene-schema.bend as SceneSchema
import ./deps/bendvy/src/ecs/execution-command-removed.bend as Removed
import ./deps/bendvy/src/ecs/owner-product.bend as Product
import ./deps/bendvy/src/ecs/execution-effects.bend as Effects
import ./deps/bendvy/src/ecs/execution-system.bend as Sys
import ./deps/bendvy/src/ecs/world.bend as W
import ./deps/bendvy/src/ecs/execution-command-local.bend as Local
import ./src/scene-draw.bend as Draw
import ./src/scene-observe.bend as Observe
import ./deps/bendvy/src/ecs/inspector.bend as Inspector
import ./deps/bendvy/src/ecs/component.bend as Component
import ./deps/bendvy/src/ecs/execution-query.bend as Query

law scene_sync_boundary_pair:
  for +id:U32
  for +requested:List<&2,U32>
  for +remaining:List<&2,U32>
  {Deferred.boundaries(Deferred.sync_returned(
    Deferred.sync_entered(Deferred.On{[]},id,requested),id,remaining)) ==
    [Deferred.ApplyEntered{Deferred.Sync{[id]},requested},
     Deferred.ApplyReturned{Deferred.Sync{[id]},remaining}] : List<&2,Deferred.Boundary>}

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
  for H:Type
  for modify:@-Out:Type -> H -> W.Handle<SceneSchema.Schema> -> (C.Transform -> C.Transform & Out) -> H & Query.GeneralEdit<C.Transform,Out>
  for scope:H
  for handle:W.Handle<SceneSchema.Schema>
  for left:Maybe<&2,C.Transform>
  for right:Maybe<&2,C.Transform>
  for rest:List<&2,Query.GeneralRow<SceneSchema.Schema,C.Transform>>
  {Move.move_rows(~H,~modify,Query.GeneralRow{handle,left} <> rest,scope) ==
    Move.move_rows(~H,~modify,Query.GeneralRow{handle,right} <> rest,scope) : H & (Unit & Sys.Completion<String,Unit>)}

law scene_move_current_component:
  for H:Type
  for modify:@-Out:Type -> H -> W.Handle<SceneSchema.Schema> -> (C.Transform -> C.Transform & Out) -> H & Query.GeneralEdit<C.Transform,Out>
  for scope:H
  for handle:W.Handle<SceneSchema.Schema>
  for view:Maybe<&2,C.Transform>
  for rest:List<&2,Query.GeneralRow<SceneSchema.Schema,C.Transform>>
  {Move.move_rows(~H,~modify,Query.GeneralRow{handle,view} <> rest,scope) ==
    Move.edited(~H,Move.move_rows(~H,~modify,rest),modify(Unit,scope,handle,Move.translate)) : H & (Unit & Sys.Completion<String,Unit>)}

law scene_move_query_refusal:
  for H:Type
  for modify:@-Out:Type -> H -> W.Handle<SceneSchema.Schema> -> (C.Transform -> C.Transform & Out) -> H & Query.GeneralEdit<C.Transform,Out>
  for scope:H
  {Move.selected(~H,~modify,(scope,Query.SelectionRefused{})) ==
    (scope,(Unit{},Sys.BodyError{"transform query refused",Unit{}})) : H & (Unit & Sys.Completion<String,Unit>)}

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
  {Seeds.seed(index) == Create.Seed{C.Transform{C.Vec3{U32.to_f32(index),F32.mul(2.0,U32.to_f32(index)),F32.neg(U32.to_f32(index))},C.Quat{0.0,0.0,0.6,0.8},C.Vec3{2.0,3.0,4.0}},C.MeshRef{7}} : Create.Seed}

law scene_seed_count:
  for +count:Nat
  for +index:U32
  {List.length(&2,Create.Seed,Seeds.values(count,index)) == count : Nat}

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


law draw_payload:
  for handle:W.Handle<SceneSchema.Schema>
  for +transform:C.Transform
  for +mesh:C.MeshRef
  {Observe.draw_item(handle,transform,mesh) == Draw.DrawItem{transform,mesh} : Draw.DrawItem}

law draw_handle_independent:
  for left:W.Handle<SceneSchema.Schema>
  for right:W.Handle<SceneSchema.Schema>
  for +transform:C.Transform
  for +mesh:C.MeshRef
  {Observe.draw_item(left,transform,mesh) == Observe.draw_item(right,transform,mesh) : Draw.DrawItem}

law draw_found_order:
  for H:Type
  for next:H -> List<&2,Draw.DrawItem> -> H & Result<&2,&2,Unit,List<&2,Draw.DrawItem>>
  for frame:H
  for handle:W.Handle<SceneSchema.Schema>
  for +transform:C.Transform
  for +mesh:C.MeshRef
  for acc:List<&2,Draw.DrawItem>
  for added:Bool
  for changed:Bool
  {Observe.found_mesh(~Draw.DrawItem,~Observe.draw_item,~H,next,handle,transform,acc,(frame,Inspector.Value{Component.Found{mesh},added,changed})) == next(frame,Draw.DrawItem{transform,mesh} <> acc) : H & Result<&2,&2,Unit,List<&2,Draw.DrawItem>>}

law draw_absent_strict:
  for H:Type
  for next:H -> List<&2,Draw.DrawItem> -> H & Result<&2,&2,Unit,List<&2,Draw.DrawItem>>
  for frame:H
  for handle:W.Handle<SceneSchema.Schema>
  for transform:C.Transform
  for acc:List<&2,Draw.DrawItem>
  for added:Bool
  for changed:Bool
  {Observe.found_mesh(~Draw.DrawItem,~Observe.draw_item,~H,next,handle,transform,acc,(frame,Inspector.Value{Component.ComponentAbsent{},added,changed})) == (frame,Fail{Unit{}}) : H & Result<&2,&2,Unit,List<&2,Draw.DrawItem>>}

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

law draw_finish_order:
  for frame:Inspector.Frame<SceneSchema.Schema,SceneSchema.Columns(),SceneSchema.Resources(),Unit>
  for acc:List<&2,Draw.DrawItem>
  {Observe.values(~Draw.DrawItem,~Observe.draw_item,
    ~Inspector.Frame<SceneSchema.Schema,SceneSchema.Columns(),SceneSchema.Resources(),Unit>,
    ~Columns.get(~SceneSchema.Schema,~SceneSchema.Columns(),~SceneSchema.Resources(),~Unit,
      ~SceneSchema.components(),~Layout.InRight{Layout.AtLeaf{}},~{==}),[],frame,acc) ==
    (frame,Done{List.reverse(&2,Draw.DrawItem,acc)}) : Inspector.Frame<SceneSchema.Schema,SceneSchema.Columns(),SceneSchema.Resources(),Unit> & Result<&2,&2,Unit,List<&2,Draw.DrawItem>>}


law render_push_extent:
  for matrix:Render.Mat4
  {List.length(&1,U32,Render.matrix_words(matrix)) == 16n : Nat}

law render_indices_append:
  for +left:List<&2,U32>
  for +right:List<&2,U32>
  for +count:U32
  {Mesh.indices_valid(List.append(&2,U32,left,right),count) ==
    Bool.and(Mesh.indices_valid(left,count),Mesh.indices_valid(right,count)) : Bool}

law render_indices_order:
  for +left:List<&2,U32>
  for +right:List<&2,U32>
  for +count:U32
  {Mesh.indices_valid(List.append(&2,U32,left,right),count) ==
    Mesh.indices_valid(List.append(&2,U32,right,left),count) : Bool}

law render_float_word_bits:
  for +word:U32
  {Render.float_bits(Render.float_word(word)) == word : U32}

law render_matrix_word_roundtrip:
  for +matrix:Render.Mat4
  {Render.from_words(Render.matrix_words(matrix)) == Some{matrix} : Maybe<Render.Mat4>}

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
  for vertex:Create.Vertex
  {Create.tint(vertex,Create.white()) == vertex : Create.Vertex}

law creation_tint_position:
  for +position:C.Vec3
  for color:C.Vec3
  for material:Create.Material
  exs tinted:C.Vec3
  {Create.tint(Create.Vertex{position,color},material) == Create.Vertex{position,tinted} : Create.Vertex}

law creation_bundle_order:
  for transform:C.Transform
  for mesh:C.MeshRef
  for rest:List<&2,Create.Seed>
  {Spawn.bundles(Create.Seed{transform,mesh} <> rest) == Product.Owner{Some{transform},Some{mesh}} <> Spawn.bundles(rest) : List<Removed.Removed(SceneSchema.components())>}

law creation_empty:
  {Create.compile(Create.Scene{[]}) == Done{Create.Compiled{[],Create.Geometry{[],[],[]}}} : Result<&2,&2,Create.Error,Create.Compiled>}

law creation_resolve_empty:
  for id:U32
  {Create.resolve([],id) == None{} : Maybe<Create.Range>}

law creation_resolve_head:
  for +id:U32
  for first:U32
  for count:U32
  for rest:List<&2,Create.Range>
  {Create.resolve(Create.Range{id,first,count} <> rest,id) == Some{Create.Range{id,first,count}} : Maybe<Create.Range>}

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
  for vertices:List<&2,Create.Vertex>
  {Create.bake(vertices,Create.white()) == vertices : List<&2,Create.Vertex>}

law creation_bundle_count:
  for +seeds:List<&2,Create.Seed>
  {List.length(&1,Removed.Removed(SceneSchema.components()),Spawn.bundles(seeds)) == List.length(&2,Create.Seed,seeds) : Nat}
