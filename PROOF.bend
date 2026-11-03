import ./src/mesh-control.bend as Player
import ./deps/bend-vulkan/deps/bend-collections/proofs/lib/u32.bend as U32Proof
import ./src/creation.bend as Create
import ./src/measurement-counters.bend as Counts
import ./src/scene-mesh.bend as Mesh
import ./src/scene-matrix.bend as Render
import ./deps/bend-vulkan/PROOF.bend as Vulkan
import ./deps/bendvy/test-fixtures/execution-laws/PROOF.bend as ECS
import ./tools/component-consumer.bend as Consumer
import ./examples/scene-seeds.bend as Seeds
import Base
import ./src/time.bend as Time
import ./deps/bend-vulkan/deps/bend-collections/proofs/math/natural/arith.bend as Arithmetic
import ./deps/bend-vulkan/deps/bend-collections/proofs/math/natural/misc.bend as Misc
import ./src/components.bend as C
import ./LAWS.bend as Laws
import ./src/scene-spawn.bend as Spawn
import ./src/scene-schema.bend as SceneSchema
import ./deps/bendvy/src/ecs/execution-command-removed.bend as Removed

def Laws.scene_sync_boundary_pair(id,requested,remaining):
  {==}

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

def Laws.scene_step_adapter(state):
  {==}

def Laws.scene_move_view_independent(H,modify,scope,handle,left,right,rest):
  {==}

def Laws.scene_move_current_component(H,modify,scope,handle,view,rest):
  {==}

def Laws.scene_move_query_refusal(H,modify,scope):
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
      Equal.cong(Nat,Nat,n => 1n+n,List.length(&2,Create.Seed,Seeds.values(rest,U32.inc(index))),rest,Laws.scene_seed_count(rest,U32.inc(index)))

def Laws.scene_empty_bootstrap(F,effects,H,Q,caps,commands,scope,queue,handles):
  {==}

def Laws.draw_payload(handle,transform,mesh):{==}

def Laws.draw_handle_independent(left,right,transform,mesh):{==}

def Laws.draw_found_order(H,next,frame,handle,transform,mesh,acc,added,changed):{==}

def Laws.draw_absent_strict(H,next,frame,handle,transform,acc,added,changed):{==}

def Laws.row_missing_strict(H,next,frame,handle,transform,acc,added,changed):{==}

def Laws.draw_finish_order(frame,acc):{==}


def Laws.render_push_extent(matrix):
  match matrix:
    case Render.Mat4{Render.Vec4{a,b,c,d},Render.Vec4{e,f,g,h},Render.Vec4{i,j,k,l},Render.Vec4{m,n,o,p}}:{==}

def conjunction_associative(+a:Bool,+b:Bool,+c:Bool) ->
  {Bool.and(a,Bool.and(b,c)) == Bool.and(Bool.and(a,b),c) : Bool}:
  match a:
    case False{}:{==}
    case True{}:{==}

def conjunction_commutative(+a:Bool,+b:Bool) ->
  {Bool.and(a,b) == Bool.and(b,a) : Bool}:
  match a b:
    case False{} False{}:{==}
    case False{} True{}:{==}
    case True{} False{}:{==}
    case True{} True{}:{==}

def Laws.render_indices_append(left,right,count):
  match left:
    case []:{==}
    case +head <> +tail:
      Equal.trans(Bool,
        Mesh.indices_valid(List.append(&2,U32,head <> tail,right),count),
        Bool.and(U32.is_lt(head,count),Bool.and(Mesh.indices_valid(tail,count),Mesh.indices_valid(right,count))),
        Bool.and(Mesh.indices_valid(head <> tail,count),Mesh.indices_valid(right,count)),
        Equal.cong(Bool,Bool,b => Bool.and(U32.is_lt(head,count),b),
          Mesh.indices_valid(List.append(&2,U32,tail,right),count),
          Bool.and(Mesh.indices_valid(tail,count),Mesh.indices_valid(right,count)),
          Laws.render_indices_append(tail,right,count)),
        conjunction_associative(U32.is_lt(head,count),Mesh.indices_valid(tail,count),Mesh.indices_valid(right,count)))

def Laws.render_indices_order(left,right,count):
  Equal.trans(Bool,
    Mesh.indices_valid(List.append(&2,U32,left,right),count),
    Bool.and(Mesh.indices_valid(left,count),Mesh.indices_valid(right,count)),
    Mesh.indices_valid(List.append(&2,U32,right,left),count),
    Laws.render_indices_append(left,right,count),
    Equal.trans(Bool,
      Bool.and(Mesh.indices_valid(left,count),Mesh.indices_valid(right,count)),
      Bool.and(Mesh.indices_valid(right,count),Mesh.indices_valid(left,count)),
      Mesh.indices_valid(List.append(&2,U32,right,left),count),
      conjunction_commutative(Mesh.indices_valid(left,count),Mesh.indices_valid(right,count)),
      Equal.sym(Bool,
        Mesh.indices_valid(List.append(&2,U32,right,left),count),
        Bool.and(Mesh.indices_valid(right,count),Mesh.indices_valid(left,count)),
        Laws.render_indices_append(right,left,count))))

def Laws.render_float_word_bits(word):
  match word:
    case U32{bits}:{==}

def Laws.render_matrix_word_roundtrip(matrix):
  match matrix:
    case Render.Mat4{Render.Vec4{F32{a},F32{b},F32{c},F32{d}},Render.Vec4{F32{e},F32{f},F32{g},F32{h}},Render.Vec4{F32{i},F32{j},F32{k},F32{l}},Render.Vec4{F32{m},F32{n},F32{o},F32{p}}}:{==}

def Laws.render_word_matrix_layout(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p):
  match a b c d e f g h i j k l m n o p:
    case U32{a} U32{b} U32{c} U32{d} U32{e} U32{f} U32{g} U32{h} U32{i} U32{j} U32{k} U32{l} U32{m} U32{n} U32{o} U32{p}:{==}

def Laws.render_float_roundtrip(value):
  match value:
    case F32{bits}:{==}


def Laws.measurement_push_preserves_draws(c,bytes):
  match c:
    case Counts.Counters{w,b,p,pb,d,s}:{==}

def Laws.measurement_draw_preserves_pushes(c):
  match c:
    case Counts.Counters{w,b,p,pb,d,s}:{==}

def Laws.time_defaults():
  {==}

def Laws.time_positive(config):
  match config:
    case Time.Config{interval,limit}:{==}

def Laws.time_start(now):
  {==}

def Laws.time_partition_total(limit,whole,remainder,sample):
  match limit whole:
    case 0n 0n:{==}
    case 0n 1n+p:{==}
    case 1n+l 0n:{==}
    case 1n+l 1n+w:
      %Laws.time_partition_total(l,w,remainder,sample) : {1n+Nat.add(Nat.min(w,l),Nat.sub(w,Nat.min(w,l))) == 1n+_ : Nat}
      {==}

def Laws.time_bounded(config,clock,now):
  match config clock:
    case Time.Config{+interval,+limit} Time.Clock{+sample,+remainder}:
      Misc.min_le_r(Nat.div(Nat.add(remainder,Nat.sub(now,sample)),1n+interval),1n+limit)

def Laws.time_execution(config,sample,remainder,now):
  match config:
    case Time.Config{interval,limit}:{==}

def Laws.time_remainder(config,clock,now):
  match config clock:
    case Time.Config{+interval,limit} Time.Clock{+sample,remainder}:
      Arithmetic.dm_lt(interval,Nat.add(remainder,Nat.sub(now,sample)))

def Laws.time_accumulated_accounting(config,sample,elapsed):
  match config:
    case Time.Config{+interval,+limit}:
      +q = Nat.div(elapsed,1n+interval)
      +r = Nat.mod(elapsed,1n+interval)
      Equal.trans(Nat,Time.covered(Time.Config{interval,limit},Time.accumulated(Time.Config{interval,limit},sample,elapsed)),Nat.add(Nat.mul(q,1n+interval),r),elapsed,
        Equal.cong(Nat,Nat,x => Nat.add(Nat.mul(x,1n+interval),r),Time.total(Time.partition(1n+limit,q,r,sample)),q,Laws.time_partition_total(1n+limit,q,r,sample)),
        Equal.sym(Nat,elapsed,Nat.add(Nat.mul(q,1n+interval),r),Arithmetic.dm_eq(interval,elapsed)))

def Laws.time_accounting(config,sample,remainder,now):
  Laws.time_accumulated_accounting(config,Nat.max(sample,now),Nat.add(remainder,Nat.sub(now,sample)))

def Laws.time_high_water(config,sample,remainder,now):
  match config:
    case Time.Config{interval,limit}:{==}

def Laws.input_close(rest,camera):
  match camera:
    case None{}:{==}
    case Some{value}:{==}

def Laws.input_escape(rest,camera):
  match camera:
    case None{}:{==}
    case Some{value}:{==}

def Laws.input_drain(A,rebuild,pending):
  {==}

def Laws.input_snapshot(A,rebuild,pending,camera):
  {==}

def Laws.module_initial_camera():
  {==}

def Laws.module_camera_reset(camera):
  {==}

def Laws.headless_scene_zero(app):{==}

def Laws.headless_scene_successor(remaining,app):{==}

def Laws.creation_white(vertex):
  match vertex:
    case Create.Vertex{position,C.Vec3{r,g,b}}:{==}

def Laws.creation_tint_position(position,color,material):
  match color material:
    case C.Vec3{r,g,b} Create.Basic{C.Vec3{x,y,z}}:
      (C.Vec3{Create.tint_channel(r,x),Create.tint_channel(g,y),Create.tint_channel(b,z)},{==})

def Laws.creation_bundle_order(transform,mesh,rest):{==}

def Laws.creation_empty():{==}

def Laws.creation_resolve_empty(id):{==}

def Laws.creation_resolve_head(id,first,count,rest):
  Equal.cong(Bool,Maybe<Create.Range>,b => Bool.pick(Maybe<Create.Range>,b,Some{Create.Range{id,first,count}},Create.resolve(rest,id)),U32.is_eq(id,id),True{},U32Proof.u32_eq_refl(id))

def Laws.creation_empty_prepend(geometry):{==}

def Laws.camera_reset_configuration(target,yaw,pitch,distance,projection):{==}

def Laws.creation_white_mesh(vertices):
  match vertices:
    case []:{==}
    case +vertex <> +rest:
      Equal.trans(List<&2,Create.Vertex>,Create.tint(vertex,Create.white()) <> Create.bake(rest,Create.white()),vertex <> Create.bake(rest,Create.white()),vertex <> rest,
        Equal.cong(Create.Vertex,List<&2,Create.Vertex>,v => v <> Create.bake(rest,Create.white()),Create.tint(vertex,Create.white()),vertex,Laws.creation_white(vertex)),
        Equal.cong(List<&2,Create.Vertex>,List<&2,Create.Vertex>,xs => vertex <> xs,Create.bake(rest,Create.white()),rest,Laws.creation_white_mesh(rest)))

def Laws.creation_bundle_count(seeds):
  match seeds:
    case []:{==}
    case Create.Seed{transform,mesh} <> +rest:
      Equal.cong(Nat,Nat,n => 1n+n,List.length(&1,Removed.Removed(SceneSchema.components()),Spawn.bundles(rest)),List.length(&2,Create.Seed,rest),Laws.creation_bundle_count(rest))

def Laws.player_key_106_last_state(a,b,keys):
  match keys:
    case Player.Keys{l,r,f,k,u,d}:{==}

def Laws.player_key_108_last_state(a,b,keys):
  match keys:
    case Player.Keys{l,r,f,k,u,d}:{==}

def Laws.player_key_105_last_state(a,b,keys):
  match keys:
    case Player.Keys{l,r,f,k,u,d}:{==}

def Laws.player_key_107_last_state(a,b,keys):
  match keys:
    case Player.Keys{l,r,f,k,u,d}:{==}

def Laws.player_key_117_last_state(a,b,keys):
  match keys:
    case Player.Keys{l,r,f,k,u,d}:{==}

def Laws.player_key_111_last_state(a,b,keys):
  match keys:
    case Player.Keys{l,r,f,k,u,d}:{==}

def Laws.player_opposing_axis(down):
  match down:
    case False{}:{==}
    case True{}:{==}

def Laws.player_clear_idempotent(state):
  match state:
    case Player.Boot{}:{==}
    case Player.PlayerReady{h,k,t,p}:{==}

def Laws.player_reset_intent(handle,keys,initial,pending):{==}

def Laws.player_release_keeps_reset(handle,keys,initial):
  match keys:
    case Player.Keys{l,r,f,b,u,d}:{==}

def Laws.player_clear_keeps_reset(handle,keys,initial,pending):{==}

def Laws.player_translation_preserves_pose(current,d):
  match current d:
    case C.Transform{C.Vec3{x,y,z},r,s} C.Vec3{dx,dy,dz}:{==}

def Laws.player_boot_no_write(H,modify,scope):{==}
def Laws.player_idle_no_write(H,modify,scope,h,keys,initial):{==}
def Laws.player_writer_retained_handle(H,modify,scope,h,keys,initial):{==}
def Laws.player_reset_writer(H,modify,scope,h,keys,initial):{==}

def Laws.player_inactive_clock_anchor(clock,now):{==}
def Laws.player_active_clock_policy(clock,now):{==}
def Laws.player_native_focus_boundary(rest):{==}

def Laws.player_query_gate(H,modify,state,scope):{==}
