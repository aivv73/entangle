import ./src/hierarchy.bend as H
import 0x632652e3c1c0183f12728faf3870bb68/bytes.bend as JsonBytes
import ./src/json-boundary.bend as Json
import ./src/scene-file.bend as SceneFile
import 0x37aacddc1dcb57464b8b5ac6c397bd64/json.bend as JsonParser
import ./deps/jonlib-obj/obj.bend as ModelParser
import ./src/model-obj.bend as Obj
import ./proofs/image-array.bend as ImageArray
import ./src/image-png.bend as Png
import ./deps/jonlib-png/codec.bend as PngCodec
import ./src/content.bend as F
import ./proofs/upload-range/PROOF.bend as UploadProof
import ./proofs/upload-range/LAWS.bend as UploadLaws
import ./src/mesh-control.bend as Player
import ./deps/bend-vulkan/deps/bend-collections/proofs/lib/u32.bend as U32Proof
import ./src/creation.bend as Create
import ./src/measurement-counters.bend as Counts
import ./src/scene-matrix.bend as Render
import ./deps/bend-vulkan/PROOF.bend as Vulkan
import ./deps/bendvy/test-fixtures/execution-laws/PROOF.bend as ECS
import ./tools/component-consumer.bend as Consumer
import ./examples/scene-seeds.bend as Seeds
import Base
import ./src/upload-size.bend as UploadSize
import ./proofs/upload-range/spec.bend as UploadValue
import ./deps/bend-vulkan/deps/bend-collections/proofs/lib/nat.bend as UploadNat
import ./deps/bend-vulkan/deps/bend-collections/proofs/lib/lemmas/spec/numeric.bend as UploadNumeric
import ./src/time.bend as Time
import ./deps/bend-vulkan/deps/bend-collections/proofs/math/natural/arith.bend as Arithmetic
import ./deps/bend-vulkan/deps/bend-collections/proofs/math/natural/misc.bend as Misc
import ./src/components.bend as C
import ./LAWS.bend as Laws
import ./src/asset.bend as Asset
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

def Laws.render_multiply_order(left,a,b,c,d):{==}

def Laws.render_apply_order(a,b,c,d,e,f,g,h,i,j,k,l,n,o,p,q,x,y,z,w):{==}

def Laws.render_model_contract(tx,ty,tz,x,y,z,w,sx,sy,sz):{==}

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
        F.indices_valid(List.append(&2,U32,head <> tail,right),count),
        Bool.and(U32.is_lt(head,count),Bool.and(F.indices_valid(tail,count),F.indices_valid(right,count))),
        Bool.and(F.indices_valid(head <> tail,count),F.indices_valid(right,count)),
        Equal.cong(Bool,Bool,b => Bool.and(U32.is_lt(head,count),b),
          F.indices_valid(List.append(&2,U32,tail,right),count),
          Bool.and(F.indices_valid(tail,count),F.indices_valid(right,count)),
          Laws.render_indices_append(tail,right,count)),
        conjunction_associative(U32.is_lt(head,count),F.indices_valid(tail,count),F.indices_valid(right,count)))

def Laws.render_indices_order(left,right,count):
  Equal.trans(Bool,
    F.indices_valid(List.append(&2,U32,left,right),count),
    Bool.and(F.indices_valid(left,count),F.indices_valid(right,count)),
    F.indices_valid(List.append(&2,U32,right,left),count),
    Laws.render_indices_append(left,right,count),
    Equal.trans(Bool,
      Bool.and(F.indices_valid(left,count),F.indices_valid(right,count)),
      Bool.and(F.indices_valid(right,count),F.indices_valid(left,count)),
      F.indices_valid(List.append(&2,U32,right,left),count),
      conjunction_commutative(F.indices_valid(left,count),F.indices_valid(right,count)),
      Equal.sym(Bool,
        F.indices_valid(List.append(&2,U32,right,left),count),
        Bool.and(F.indices_valid(right,count),F.indices_valid(left,count)),
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
    case F.Vertex{position,C.Vec3{r,g,b},+uv,+normal}:{==}

def Laws.creation_tint_position(position,color,uv,normal,material):
  match color material:
    case C.Vec3{r,g,b} F.Basic{C.Vec3{x,y,z}}:
      (C.Vec3{F.tint_channel(r,x),F.tint_channel(g,y),F.tint_channel(b,z)},{==})
    case C.Vec3{r,g,b} F.Textured{C.Vec3{x,y,z},_}:
      (C.Vec3{F.tint_channel(r,x),F.tint_channel(g,y),F.tint_channel(b,z)},{==})

def Laws.creation_bundle_order(transform,mesh,spatial,rest):{==}

def Laws.creation_empty():{==}

def Laws.creation_resolve_empty(id):{==}

def Laws.creation_resolve_head(id,first,count,image,rest):
  Equal.cong(Bool,Maybe<Create.Range>,b => Bool.pick(Maybe<Create.Range>,b,Some{Create.Range{id,first,count,image}},Create.resolve(rest,id)),U32.is_eq(id,id),True{},U32Proof.u32_eq_refl(id))

def Laws.creation_empty_prepend(geometry):{==}

def Laws.camera_reset_configuration(target,yaw,pitch,distance,projection):{==}

def Laws.creation_white_mesh(vertices):
  match vertices:
    case []:{==}
    case +vertex <> +rest:
      Equal.trans(List<&2,F.Vertex>,F.tint(vertex,F.white()) <> F.bake(rest,F.white()),vertex <> F.bake(rest,F.white()),vertex <> rest,
        Equal.cong(F.Vertex,List<&2,F.Vertex>,v => v <> F.bake(rest,F.white()),F.tint(vertex,F.white()),vertex,Laws.creation_white(vertex)),
        Equal.cong(List<&2,F.Vertex>,List<&2,F.Vertex>,xs => vertex <> xs,F.bake(rest,F.white()),rest,Laws.creation_white_mesh(rest)))

def conjunction_true(+a:Bool,+b:Bool,pa:{a == True{} : Bool},pb:{b == True{} : Bool}) -> {Bool.and(a,b) == True{} : Bool}:
  Equal.trans(Bool,Bool.and(a,b),Bool.and(True{},b),True{},
    Equal.cong(Bool,Bool,x => Bool.and(x,b),a,True{},pa),pb)

def content_vec_identity(+v:C.Vec3) -> {F.same_vec(v,v) == True{} : Bool}:
  match v:
    case C.Vec3{+x,+y,+z}:
      conjunction_true(Bool.and(U32.is_eq(F32.bits(x),F32.bits(x)),U32.is_eq(F32.bits(y),F32.bits(y))),U32.is_eq(F32.bits(z),F32.bits(z)),
        conjunction_true(U32.is_eq(F32.bits(x),F32.bits(x)),U32.is_eq(F32.bits(y),F32.bits(y)),U32Proof.u32_eq_refl(F32.bits(x)),U32Proof.u32_eq_refl(F32.bits(y))),
        U32Proof.u32_eq_refl(F32.bits(z)))

def content_uv_identity(+uv:F.UV) -> {F.same_uv(uv,uv) == True{} : Bool}:
  match uv:
    case F.UV{+u,+v}:
      conjunction_true(U32.is_eq(F32.bits(u),F32.bits(u)),U32.is_eq(F32.bits(v),F32.bits(v)),U32Proof.u32_eq_refl(F32.bits(u)),U32Proof.u32_eq_refl(F32.bits(v)))

def content_vertices_identity(+vertices:List<&2,F.Vertex>) -> {F.same_vertices(vertices,vertices) == True{} : Bool}:
  match vertices:
    case []:{==}
    case F.Vertex{+p,+c,+uv,+normal} <> +rest:
      conjunction_true(F.same_vec(p,p) && F.same_vec(c,c) && F.same_uv(uv,uv) && F.same_vec(normal,normal),F.same_vertices(rest,rest),
        conjunction_true(F.same_vec(p,p) && F.same_vec(c,c) && F.same_uv(uv,uv),F.same_vec(normal,normal),
          conjunction_true(F.same_vec(p,p) && F.same_vec(c,c),F.same_uv(uv,uv),
            conjunction_true(F.same_vec(p,p),F.same_vec(c,c),content_vec_identity(p),content_vec_identity(c)),content_uv_identity(uv)),content_vec_identity(normal)),content_vertices_identity(rest))


def content_indices_identity(+indices:List<&2,U32>) -> {F.same_indices(indices,indices) == True{} : Bool}:
  match indices:
    case []:{==}
    case +i <> +rest:
      conjunction_true(U32.is_eq(i,i),F.same_indices(rest,rest),U32Proof.u32_eq_refl(i),content_indices_identity(rest))

def Laws.content_mesh_identity(mesh):
  match mesh:
    case F.Mesh{+vertices,+indices}:
      conjunction_true(F.same_vertices(vertices,vertices),F.same_indices(indices,indices),content_vertices_identity(vertices),content_indices_identity(indices))

def Laws.content_material_identity(material):
  match material:
    case F.Basic{+tint}:content_vec_identity(tint)
    case F.Textured{+tint,F.SourceImage{+w,+h,+pixels}}:
      conjunction_true(F.same_vec(tint,tint),F.same_image(F.SourceImage{w,h,pixels},F.SourceImage{w,h,pixels}),content_vec_identity(tint),
        conjunction_true(U32.is_eq(w,w) && U32.is_eq(h,h),F.same_indices(pixels,pixels),
          conjunction_true(U32.is_eq(w,w),U32.is_eq(h,h),U32Proof.u32_eq_refl(w),U32Proof.u32_eq_refl(h)),content_indices_identity(pixels)))

def Laws.content_bake_count(vertices,material):
  match vertices:
    case []:{==}
    case vertex <> +rest:
      Equal.cong(Nat,Nat,n => 1n+n,List.length(&2,F.Vertex,F.bake(rest,material)),List.length(&2,F.Vertex,rest),Laws.content_bake_count(rest,material))

def Laws.content_bake_append(left,right,material):
  match left:
    case []:{==}
    case +vertex <> rest:
      Equal.cong(List<&2,F.Vertex>,List<&2,F.Vertex>,xs => F.tint(vertex,material) <> xs,
        F.bake(List.append(&2,F.Vertex,rest,right),material),
        List.append(&2,F.Vertex,F.bake(rest,material),F.bake(right,material)),Laws.content_bake_append(rest,right,material))

def Laws.creation_bad_mesh_first(material,transform,number):
  match material transform:
    case False{} False{}:{==}
    case False{} True{}:{==}
    case True{} False{}:{==}
    case True{} True{}:{==}

def Laws.creation_bad_material_second(transform,number):
  match transform:
    case False{}:{==}
    case True{}:{==}

def Laws.creation_bad_transform_third(number):{==}

def Laws.creation_duplicate_preserves_geometry(id,mesh,material,pairs,geometry,next):{==}

def Laws.creation_bundle_count(seeds):
  match seeds:
    case []:{==}
    case Create.Seed{transform,mesh,spatial} <> +rest:
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

def Laws.upload_range_universal(c,o,l):
  UploadLaws.universal(c,o,l)

def Laws.upload_transport_length(bytes):
  match bytes:
    case []:{==}
    case _ <> rest:Equal.cong(Nat,Nat,n => 1n+n,List.length(&1,U32,UploadSize.transport(rest)),UploadSize.byte_length(rest),Laws.upload_transport_length(rest))

def upload_scale_zero(k:Nat) -> {UploadNumeric.scale_binary(k,0n) == 0n : Nat}:
  match k:
    case 0n:{==}
    case 1n+p:Equal.cong(Nat,Nat,Nat.double,UploadNumeric.scale_binary(p,0n),0n,upload_scale_zero(p))

def Laws.upload_conversion_exact(n,h):
  Equal.trans(Nat,UploadValue.value(UploadSize.encode(n)),U32.to_nat(U32.from_nat(n)),n,
    Equal.trans(Nat,UploadValue.value(UploadSize.encode(n)),Nat.add(U32.to_nat(U32.from_nat(n)),UploadNumeric.scale_binary(32n,0n)),U32.to_nat(U32.from_nat(n)),UploadLaws.value_limbs(U32.from_nat(n),0),
      Equal.trans(Nat,Nat.add(U32.to_nat(U32.from_nat(n)),UploadNumeric.scale_binary(32n,0n)),Nat.add(U32.to_nat(U32.from_nat(n)),0n),U32.to_nat(U32.from_nat(n)),
        Equal.cong(Nat,Nat,x => Nat.add(U32.to_nat(U32.from_nat(n)),x),UploadNumeric.scale_binary(32n,0n),0n,upload_scale_zero(32n)),UploadNat.add_zero(U32.to_nat(U32.from_nat(n))))),
    UploadNat.eq_from_is_eq(U32.to_nat(U32.from_nat(n)),n,h))


def Laws.geometry_install_accept(A,old,fresh):{==}
def Laws.geometry_install_reject(A,old,fresh):{==}
def Laws.geometry_pair_allocations(A,vertices,indices):{==}
def Laws.geometry_empty_allocations(A):{==}

def asset_rewrite(-A:Type,-P:A -> Type,-x:A,-y:A,e:{x == y : A},p:P(y)) -> P(x):
  %Equal.sym(A,x,y,e) : P(_)
  p

def asset_id_self(+id:Nat) -> {Nat.is_eq(id,id) == True{} : Bool}:
  match id:
    case 0n:{==}
    case 1n+rest:asset_id_self(rest)

def Laws.asset_release_entry(A,scope,next,key,id,state):
  asset_rewrite(Bool,b => {Asset.Cache{scope,next,Asset.keep(A,Asset.Entry{key,id,state},[],b)} == Asset.Cache{scope,next,[]} : Asset.Cache<A>},Nat.is_eq(id,id),True{},asset_id_self(id),{==})

def Laws.asset_request_hit(A,scope,next,entries,key,id,found):
  asset_rewrite(Maybe<Nat>,m => {Asset.requested(A,scope,next,entries,key,m) == (Asset.Cache{scope,next,entries},Asset.Handle{scope,id}) : Asset.Cache<A> & Asset.Handle<A>},Asset.find_key(A,entries,key),Some{id},found,{==})

def Laws.asset_request_miss(A,scope,next,entries,key,found):
  asset_rewrite(Maybe<Nat>,m => {Asset.requested(A,scope,next,entries,key,m) == (Asset.Cache{scope,1n+next,Asset.Entry{key,next,Asset.Loading{}} <> entries},Asset.Handle{scope,next}) : Asset.Cache<A> & Asset.Handle<A>},Asset.find_key(A,entries,key),None{},found,{==})

def Laws.asset_load_success(A,value):{==}
def Laws.asset_load_failure(A,error):{==}
def Laws.asset_loaded_stable(A,value,result):{==}
def Laws.asset_failed_stable(A,error,result):{==}

def Laws.asset_complete_preserves_keys(A,entries,id,key,result):
  match entries:
    case []:{==}
    case Asset.Entry{+name,+serial,state} <> +rest:
      Equal.cong(Maybe<Nat>,Maybe<Nat>,tail => Bool.pick(Maybe<Nat>,String.eq(key,name),Some{serial},tail),
        Asset.find_key(A,Asset.complete(A,rest,id,result),key),Asset.find_key(A,rest,key),
        Laws.asset_complete_preserves_keys(A,rest,id,key,result))

def asset_remove_absent_step(-A:Data,+key:String,+other:Nat,+state:Asset.State<A>,+rest:List<&2,Asset.Entry<A>>,+id:Nat,+same:Bool,h:{Nat.is_eq(id,other) == same : Bool},ih:{Asset.find_id(A,rest,id) == None{} : Maybe<&2,Asset.State<A>>}) ->
  {Asset.find_id(A,Asset.keep(A,Asset.Entry{key,other,state},rest,same),id) == None{} : Maybe<&2,Asset.State<A>>}:
  match same:
    case True{}:ih
    case False{}:
      asset_rewrite(Bool,b => {Bool.pick(Maybe<&2,Asset.State<A>>,b,Some{state},Asset.find_id(A,rest,id)) == None{} : Maybe<&2,Asset.State<A>>},Nat.is_eq(id,other),False{},h,ih)

def Laws.asset_remove_absent(A,entries,id):
  match entries:
    case []:{==}
    case Asset.Entry{key,+other,state} <> +rest:
      asset_remove_absent_step(A,key,other,state,Asset.remove(A,rest,id),id,Nat.is_eq(id,other),{==},Laws.asset_remove_absent(A,rest,id))

def asset_remove_work_step(-A:Data,+key:String,+other:Nat,+state:Asset.State<A>,+rest:List<&2,Asset.Entry<A>>,+id:Nat,+same:Bool,h:{Nat.is_eq(id,other) == same : Bool},ih:{Asset.pending(A,rest,id) == None{} : Maybe<String>}) ->
  {Asset.pending(A,Asset.keep(A,Asset.Entry{key,other,state},rest,same),id) == None{} : Maybe<String>}:
  match same:
    case True{}:ih
    case False{}:
      asset_rewrite(Bool,b => {Bool.pick(Maybe<String>,b,Asset.pending_state(A,state,key),Asset.pending(A,rest,id)) == None{} : Maybe<String>},Nat.is_eq(id,other),False{},h,ih)

def Laws.asset_remove_no_work(A,entries,id):
  match entries:
    case []:{==}
    case Asset.Entry{key,+other,state} <> +rest:
      asset_remove_work_step(A,key,other,state,Asset.remove(A,rest,id),id,Nat.is_eq(id,other),{==},Laws.asset_remove_no_work(A,rest,id))

def asset_remove_twice_step(-A:Data,+key:String,+other:Nat,+state:Asset.State<A>,+rest:List<&2,Asset.Entry<A>>,+id:Nat,+same:Bool,h:{Nat.is_eq(id,other) == same : Bool},ih:{Asset.remove(A,rest,id) == rest : List<&2,Asset.Entry<A>>}) ->
  {Asset.remove(A,Asset.keep(A,Asset.Entry{key,other,state},rest,same),id) == Asset.keep(A,Asset.Entry{key,other,state},rest,same) : List<&2,Asset.Entry<A>>}:
  match same:
    case True{}:ih
    case False{}:
      asset_rewrite(Bool,b => {Asset.keep(A,Asset.Entry{key,other,state},Asset.remove(A,rest,id),b) == Asset.Entry{key,other,state} <> rest : List<&2,Asset.Entry<A>>},Nat.is_eq(id,other),False{},h,
        Equal.cong(List<&2,Asset.Entry<A>>,List<&2,Asset.Entry<A>>,tail => Asset.Entry{key,other,state} <> tail,Asset.remove(A,rest,id),rest,ih))

def Laws.asset_remove_idempotent(A,entries,id):
  match entries:
    case []:{==}
    case Asset.Entry{key,+other,state} <> +rest:
      asset_remove_twice_step(A,key,other,state,Asset.remove(A,rest,id),id,Nat.is_eq(id,other),{==},Laws.asset_remove_idempotent(A,rest,id))

def asset_release_twice(-A:Data,+scope:String,+next:Nat,+entries:List<&2,Asset.Entry<A>>,+other:String,+id:Nat,+same:Bool,h:{String.eq(scope,other) == same : Bool}) ->
  {Asset.release(A,Asset.release_scoped(A,Asset.Cache{scope,next,entries},id,same),Asset.Handle{other,id}) == Asset.release_scoped(A,Asset.Cache{scope,next,entries},id,same) : Asset.Cache<A>}:
  match same:
    case False{}:
      asset_rewrite(Bool,b => {Asset.release_scoped(A,Asset.Cache{scope,next,entries},id,b) == Asset.Cache{scope,next,entries} : Asset.Cache<A>},String.eq(scope,other),False{},h,{==})
    case True{}:
      asset_rewrite(Bool,b => {Asset.release_scoped(A,Asset.Cache{scope,next,Asset.remove(A,entries,id)},id,b) == Asset.Cache{scope,next,Asset.remove(A,entries,id)} : Asset.Cache<A>},String.eq(scope,other),True{},h,
        Equal.cong(List<&2,Asset.Entry<A>>,Asset.Cache<A>,tail => Asset.Cache{scope,next,tail},Asset.remove(A,Asset.remove(A,entries,id),id),Asset.remove(A,entries,id),Laws.asset_remove_idempotent(A,entries,id)))

def Laws.asset_release_idempotent(A,cache,handle):
  match cache handle:
    case Asset.Cache{+scope,next,entries} Asset.Handle{+other,+id}:
      asset_release_twice(A,scope,next,entries,other,id,String.eq(scope,other),{==})

def asset_release_lookup(-A:Data,+scope:String,+next:Nat,+entries:List<&2,Asset.Entry<A>>,+other:String,+id:Nat,+same:Bool,h:{String.eq(scope,other) == same : Bool}) ->
  {Asset.lookup(A,Asset.release_scoped(A,Asset.Cache{scope,next,entries},id,same),Asset.Handle{other,id}) == (Asset.release_scoped(A,Asset.Cache{scope,next,entries},id,same),None{}) : Asset.Cache<A> & Maybe<&2,Asset.State<A>>}:
  match same:
    case False{}:
      asset_rewrite(Bool,b => {Asset.lookup_scoped(A,Asset.Cache{scope,next,entries},id,b) == (Asset.Cache{scope,next,entries},None{}) : Asset.Cache<A> & Maybe<&2,Asset.State<A>>},String.eq(scope,other),False{},h,{==})
    case True{}:
      asset_rewrite(Bool,b => {Asset.lookup_scoped(A,Asset.Cache{scope,next,Asset.remove(A,entries,id)},id,b) == (Asset.Cache{scope,next,Asset.remove(A,entries,id)},None{}) : Asset.Cache<A> & Maybe<&2,Asset.State<A>>},String.eq(scope,other),True{},h,
        Equal.cong(Maybe<&2,Asset.State<A>>,Asset.Cache<A> & Maybe<&2,Asset.State<A>>,state => (Asset.Cache{scope,next,Asset.remove(A,entries,id)},state),Asset.find_id(A,Asset.remove(A,entries,id),id),None{},Laws.asset_remove_absent(A,entries,id)))

def Laws.asset_released_lookup(A,cache,handle):
  match cache handle:
    case Asset.Cache{+scope,next,entries} Asset.Handle{+other,+id}:
      asset_release_lookup(A,scope,next,entries,other,id,String.eq(scope,other),{==})

def asset_release_load(-A:Data,+scope:String,+next:Nat,+entries:List<&2,Asset.Entry<A>>,+other:String,+id:Nat,loader:String -> IO(Result<&2,&2,Asset.Error,A>),+same:Bool,h:{String.eq(scope,other) == same : Bool}) ->
  {Asset.load(A,Asset.release_scoped(A,Asset.Cache{scope,next,entries},id,same),Asset.Handle{other,id},loader) == IO.pure(Asset.Cache<A>,Asset.release_scoped(A,Asset.Cache{scope,next,entries},id,same)) : IO(Asset.Cache<A>)}:
  match same:
    case False{}:
      asset_rewrite(Bool,b => {Asset.load_scoped(A,Asset.Cache{scope,next,entries},id,loader,b) == IO.pure(Asset.Cache<A>,Asset.Cache{scope,next,entries}) : IO(Asset.Cache<A>)},String.eq(scope,other),False{},h,{==})
    case True{}:
      asset_rewrite(Bool,b => {Asset.load_scoped(A,Asset.Cache{scope,next,Asset.remove(A,entries,id)},id,loader,b) == IO.pure(Asset.Cache<A>,Asset.Cache{scope,next,Asset.remove(A,entries,id)}) : IO(Asset.Cache<A>)},String.eq(scope,other),True{},h,
        asset_rewrite(Maybe<String>,work => {Asset.load_pending(A,Asset.Cache{scope,next,Asset.remove(A,entries,id)},id,work,loader) == IO.pure(Asset.Cache<A>,Asset.Cache{scope,next,Asset.remove(A,entries,id)}) : IO(Asset.Cache<A>)},Asset.pending(A,Asset.remove(A,entries,id),id),None{},Laws.asset_remove_no_work(A,entries,id),{==}))

def Laws.asset_released_load(A,cache,handle,loader):
  match cache handle:
    case Asset.Cache{+scope,next,entries} Asset.Handle{+other,+id}:
      asset_release_load(A,scope,next,entries,other,id,loader,String.eq(scope,other),{==})

def asset_counter(-A:Data,scope:String,+next:Nat,entries:List<&2,Asset.Entry<A>>,id:Nat,same:Bool) ->
  &remaining:List<&2,Asset.Entry<A>> -> {Asset.release_scoped(A,Asset.Cache{scope,next,entries},id,same) == Asset.Cache{scope,next,remaining} : Asset.Cache<A>}:
  match same:
    case False{}:(entries,{==})
    case True{}:(Asset.remove(A,entries,id),{==})

def Laws.asset_release_counter(A,scope,next,entries,handle):
  match handle:
    case Asset.Handle{other,id}:asset_counter(A,scope,next,entries,id,String.eq(scope,other))

def Laws.asset_wrong_scope(A,scope,other,next,entries,id,different):
  asset_rewrite(Bool,b => {Asset.release_scoped(A,Asset.Cache{scope,next,entries},id,b) == Asset.Cache{scope,next,entries} : Asset.Cache<A>},String.eq(scope,other),False{},different,{==})

def Laws.image_array_leaf(value,tail):{==}
def Laws.image_array_order(left,right,tail):{==}

def image_append_assoc(xs:List<&2,U32>,+ys:List<&2,U32>,+zs:List<&2,U32>) ->
  {List.append(&2,U32,List.append(&2,U32,xs,ys),zs) == List.append(&2,U32,xs,List.append(&2,U32,ys,zs)) : List<&2,U32>}:
  match xs:
    case []:{==}
    case +x <> rest:Equal.cong(List<&2,U32>,List<&2,U32>,t => x <> t,List.append(&2,U32,List.append(&2,U32,rest,ys),zs),List.append(&2,U32,rest,List.append(&2,U32,ys,zs)),image_append_assoc(rest,ys,zs))

def Laws.image_array_tail(array,tail):
  match array:
    case ImageArray.Leaf{value}:{==}
    case ImageArray.Node{left,right}:
      Equal.trans(List<&2,U32>,Png.array_words(ImageArray.array(left),Png.array_words(ImageArray.array(right),tail)),List.append(&2,U32,Png.array_words(ImageArray.array(left),[]),Png.array_words(ImageArray.array(right),tail)),List.append(&2,U32,Png.array_words(ImageArray.array(left),Png.array_words(ImageArray.array(right),[])),tail),
        Laws.image_array_tail(left,Png.array_words(ImageArray.array(right),tail)),
        Equal.trans(List<&2,U32>,List.append(&2,U32,Png.array_words(ImageArray.array(left),[]),Png.array_words(ImageArray.array(right),tail)),List.append(&2,U32,Png.array_words(ImageArray.array(left),[]),List.append(&2,U32,Png.array_words(ImageArray.array(right),[]),tail)),List.append(&2,U32,Png.array_words(ImageArray.array(left),Png.array_words(ImageArray.array(right),[])),tail),
          Equal.cong(List<&2,U32>,List<&2,U32>,xs => List.append(&2,U32,Png.array_words(ImageArray.array(left),[]),xs),Png.array_words(ImageArray.array(right),tail),List.append(&2,U32,Png.array_words(ImageArray.array(right),[]),tail),Laws.image_array_tail(right,tail)),
          Equal.trans(List<&2,U32>,List.append(&2,U32,Png.array_words(ImageArray.array(left),[]),List.append(&2,U32,Png.array_words(ImageArray.array(right),[]),tail)),List.append(&2,U32,List.append(&2,U32,Png.array_words(ImageArray.array(left),[]),Png.array_words(ImageArray.array(right),[])),tail),List.append(&2,U32,Png.array_words(ImageArray.array(left),Png.array_words(ImageArray.array(right),[])),tail),
            Equal.sym(List<&2,U32>,List.append(&2,U32,List.append(&2,U32,Png.array_words(ImageArray.array(left),[]),Png.array_words(ImageArray.array(right),[])),tail),List.append(&2,U32,Png.array_words(ImageArray.array(left),[]),List.append(&2,U32,Png.array_words(ImageArray.array(right),[]),tail)),image_append_assoc(Png.array_words(ImageArray.array(left),[]),Png.array_words(ImageArray.array(right),[]),tail)),
            Equal.cong(List<&2,U32>,List<&2,U32>,xs => List.append(&2,U32,xs,tail),List.append(&2,U32,Png.array_words(ImageArray.array(left),[]),Png.array_words(ImageArray.array(right),[])),Png.array_words(ImageArray.array(left),Png.array_words(ImageArray.array(right),[])),Equal.sym(List<&2,U32>,Png.array_words(ImageArray.array(left),Png.array_words(ImageArray.array(right),[])),List.append(&2,U32,Png.array_words(ImageArray.array(left),[]),Png.array_words(ImageArray.array(right),[])),Laws.image_array_tail(left,Png.array_words(ImageArray.array(right),[])))))))

def image_append_length(xs:List<&2,U32>,+ys:List<&2,U32>) ->
  {List.length(&2,U32,List.append(&2,U32,xs,ys)) == Nat.add(List.length(&2,U32,xs),List.length(&2,U32,ys)) : Nat}:
  match xs:
    case []:{==}
    case _ <> rest:Equal.cong(Nat,Nat,n => 1n+n,List.length(&2,U32,List.append(&2,U32,rest,ys)),Nat.add(List.length(&2,U32,rest),List.length(&2,U32,ys)),image_append_length(rest,ys))

def Laws.image_array_count(array,tail):
  Equal.trans(Nat,List.length(&2,U32,Png.array_words(ImageArray.array(array),tail)),List.length(&2,U32,List.append(&2,U32,Png.array_words(ImageArray.array(array),[]),tail)),Nat.add(List.length(&2,U32,Png.array_words(ImageArray.array(array),[])),List.length(&2,U32,tail)),
    Equal.cong(List<&2,U32>,Nat,xs => List.length(&2,U32,xs),Png.array_words(ImageArray.array(array),tail),List.append(&2,U32,Png.array_words(ImageArray.array(array),[]),tail),Laws.image_array_tail(array,tail)),
    image_append_length(Png.array_words(ImageArray.array(array),[]),tail))

def Laws.image_array_capacity(tree):
  match tree:
    case ImageArray.Leaf{_}:{==}
    case ImageArray.Node{left,right}:
      Equal.trans(Nat,List.length(&2,U32,Png.array_words(ImageArray.array(left),Png.array_words(ImageArray.array(right),[]))),Nat.add(List.length(&2,U32,Png.array_words(ImageArray.array(left),[])),List.length(&2,U32,Png.array_words(ImageArray.array(right),[]))),Nat.add(ImageArray.count(left),ImageArray.count(right)),
        Laws.image_array_count(left,Png.array_words(ImageArray.array(right),[])),
        Equal.trans(Nat,Nat.add(List.length(&2,U32,Png.array_words(ImageArray.array(left),[])),List.length(&2,U32,Png.array_words(ImageArray.array(right),[]))),Nat.add(ImageArray.count(left),List.length(&2,U32,Png.array_words(ImageArray.array(right),[]))),Nat.add(ImageArray.count(left),ImageArray.count(right)),
          Equal.cong(Nat,Nat,n => Nat.add(n,List.length(&2,U32,Png.array_words(ImageArray.array(right),[]))),List.length(&2,U32,Png.array_words(ImageArray.array(left),[])),ImageArray.count(left),Laws.image_array_capacity(left)),
          Equal.cong(Nat,Nat,n => Nat.add(ImageArray.count(left),n),List.length(&2,U32,Png.array_words(ImageArray.array(right),[])),ImageArray.count(right),Laws.image_array_capacity(right))))

def Laws.image_storage_rule(width,height,pixels):{==}
def Laws.image_padding(a,b,c,padding):{==}
def Laws.image_exact_read(bytes):{==}
def Laws.image_error_header():{==}
def Laws.image_error_byte():{==}
def Laws.image_error_size():{==}
def Laws.image_error_truncated():{==}
def Laws.image_error_stream():{==}

def Laws.model_pair_validity(mesh,material,labels,rest):{==}
def Laws.model_aggregate_validity(parts):{==}
def Laws.model_triangle_emission(a,b,c,tail):{==}
def Laws.model_triangle_corner_count(a,b,c,tail):{==}
def Laws.model_local_indices(local,tail):{==}
def Laws.model_index_count(local,tail):{==}
def Laws.model_first_triangle_order(a,b,c):{==}
def Laws.model_first_indices():{==}
def Laws.model_initial_material(materials,line):{==}
def Laws.model_missing_material(name,line,index):{==}
def Laws.model_raw_zero(count,line):{==}
def Laws.model_negative_zero(count,line):{==}
def Laws.model_run_conservation(n,labels,line,rest):{==}
def Laws.model_run_boundary(labels,previous,line,first,n,rest,different):
  asset_rewrite(Bool,b => {Bool.pick(List<&2,Obj.Run>,b,Obj.Run{1n+n,previous,first} <> rest,Obj.Run{1n,labels,line} <> Obj.Run{n,previous,first} <> rest) == Obj.Run{1n,labels,line} <> Obj.Run{n,previous,first} <> rest : List<&2,Obj.Run>},F.same_labels(labels,previous),False{},different,{==})

def model_checked(+model:F.SourceModel,valid:Bool,equal:{F.model_valid(model) == valid : Bool}) -> {Obj.valid_result(Obj.checked(model,valid)) == True{} : Bool}:
  match valid:
    case False{}:{==}
    case True{}:equal

def Laws.model_checked_success(model):model_checked(model,F.model_valid(model),{==})

def Laws.model_reject_incomplete_read(bytes,size,path,incomplete):
  asset_rewrite(Bool,b => {Result.bind(&2,&2,Asset.Error,Unit,List<&2,U32>,Obj.need(b,8,path,0n,"file size changed or read was incomplete"),_ => Done{bytes}) == Fail{Obj.error(8,path,0n,"file size changed or read was incomplete")} : Result<&2,&2,Asset.Error,List<&2,U32>>},Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(size)),False{},incomplete,{==})

def Laws.model_expanded_limit():{==}
def Laws.model_expanded_over_limit():{==}

def Laws.model_admit_result(result):
  match result:
    case Fail{_}:{==}
    case Done{model}:Laws.model_checked_success(model)

def Laws.model_finish_valid(plan,materials):
  match plan materials:
    case Obj.Plan{+commands,+runs,+lib,+uses,+vc,+fc},Obj.Materials{+values,+table}:
      Laws.model_admit_result(Result.bind(&2,&2,Asset.Error,Unit,F.SourceModel,Obj.check_uses(uses,values,table),_ => Obj.lower(Obj.Plan{commands,runs,lib,uses,vc,fc},Obj.Materials{values,table},ModelParser.attributes(commands,table))))

def model_materials_valid(+plan:Obj.Plan,result:Result<&2,&2,Asset.Error,Obj.Materials>) ->
  {Obj.valid_result(Result.bind(&2,&2,Asset.Error,Obj.Materials,F.SourceModel,result,materials => Obj.finish(plan,materials))) == True{} : Bool}:
  match result:
    case Fail{_}:{==}
    case Done{materials}:Laws.model_finish_valid(plan,materials)

def Laws.model_finish_bytes_valid(plan,mtl):
  match plan mtl:
    case Obj.Plan{commands,runs,None{},uses,vc,fc},None{}:Laws.model_finish_valid(Obj.Plan{commands,runs,None{},uses,vc,fc},Obj.Materials{[],ModelParser.table.new()})
    case Obj.Plan{commands,runs,Some{name},uses,vc,fc},Some{bytes}:model_materials_valid(Obj.Plan{commands,runs,Some{name},uses,vc,fc},Obj.materials(bytes))
    case Obj.Plan{_,_,None{},_,_,_},Some{_}:{==}
    case Obj.Plan{_,_,Some{_},_,_,_},None{}:{==}

def model_prepared_valid(result:Result<&2,&2,Asset.Error,Obj.Plan>,+mtl:Maybe<&2,List<&2,U32>>) ->
  {Obj.valid_result(Result.bind(&2,&2,Asset.Error,Obj.Plan,F.SourceModel,result,plan => Obj.finish_bytes(plan,mtl))) == True{} : Bool}:
  match result:
    case Fail{_}:{==}
    case Done{plan}:Laws.model_finish_bytes_valid(plan,mtl)

def Laws.model_decode_valid(obj,mtl):model_prepared_valid(Obj.prepare(obj),mtl)

def Laws.model_parsed_word(value,source,line,finite):
  asset_rewrite(Bool,b => {Result.bind(&2,&2,Asset.Error,Unit,F32,Obj.need(b,3,source,line,"nonfinite number"),_ => Done{value}) == Done{value} : Result<&2,&2,Asset.Error,F32>},F.finite(value),True{},finite,{==})

def Laws.model_negative_relative(value,count,nonzero,in_range):
  asset_rewrite(Bool,b => {Bool.pick(ModelParser.Fix,b,ModelParser.Fix{True{},0},Bool.pick(ModelParser.Fix,U32.is_le(value,count),ModelParser.Fix{True{},U32.sub(count,value)},ModelParser.Fix{False{},0})) == ModelParser.Fix{True{},U32.sub(count,value)} : ModelParser.Fix},U32.is_eq(value,0),False{},nonzero,
    asset_rewrite(Bool,b => {Bool.pick(ModelParser.Fix,b,ModelParser.Fix{True{},U32.sub(count,value)},ModelParser.Fix{False{},0}) == ModelParser.Fix{True{},U32.sub(count,value)} : ModelParser.Fix},U32.is_le(value,count),True{},in_range,{==}))

def Laws.model_run_coalescing(labels,previous,line,first,n,rest,equal):
  asset_rewrite(Bool,b => {Bool.pick(List<&2,Obj.Run>,b,Obj.Run{1n+n,previous,first} <> rest,Obj.Run{1n,labels,line} <> Obj.Run{n,previous,first} <> rest) == Obj.Run{1n+n,previous,first} <> rest : List<&2,Obj.Run>},F.same_labels(labels,previous),True{},equal,{==})

def Laws.model_source_limit_shadowed():{==}

def Laws.json_guard_reject(code,path,reason):{==}

def Laws.json_encoded_bound(bytes,path,oversized):
  asset_rewrite(Bool,b => {Result.bind(&2,&1,Asset.Error,Unit,JsonParser.Val,Json.need(b,2,path,"JSON exceeds 65536 bytes"),_ => Result.bind(&2,&1,Asset.Error,Unit,JsonParser.Val,Json.need(Json.octets(bytes),1,path,"input contains a non-byte word"),_ => Json.parsed(JsonParser.parse.strict.unique.bytes(JsonBytes.from_string(Json.string(bytes)),Json.depth_limit()),path))) == Fail{Json.error(2,path,"JSON exceeds 65536 bytes")} : Result<&2,&1,Asset.Error,JsonParser.Val>},Nat.is_le(List.length(&2,U32,bytes),Json.byte_limit()),False{},oversized,{==})

def Laws.json_read_exact(bytes,size,path,incomplete):
  asset_rewrite(Bool,b => {Result.bind(&2,&2,Asset.Error,Unit,List<&2,U32>,Json.data(Unit,Json.need(b,6,path,"file changed or read incomplete")),_ => Done{bytes}) == Fail{Json.error(6,path,"file changed or read incomplete")} : Result<&2,&2,Asset.Error,List<&2,U32>>},Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(size)),False{},incomplete,{==})

def Laws.json_reject_image_as_model(id,path):{==}
def Laws.json_unresolved_reference(id,path):{==}
def Laws.json_preserve_model_part(mesh,material,labels,transform):{==}

def json_checked(+scene:Create.Scene,path:String,valid:Bool,equal:{SceneFile.scene_valid(scene) == valid : Bool}) -> {SceneFile.valid_result(SceneFile.checked(scene,path,valid)) == True{} : Bool}:
  match valid:
    case False{}:{==}
    case True{}:equal

def Laws.json_admitted_scene_compiles(scene,path):json_checked(scene,path,SceneFile.scene_valid(scene),{==})
def Laws.json_depth_limit():{==}

def Laws.vertex_upload_stride(vertex):
  match vertex:
    case F.Vertex{C.Vec3{_,_,_},C.Vec3{_,_,_},F.UV{_,_},C.Vec3{_,_,_}}:{==}

def Laws.texture_rgba_bytes(pixel):{==}

def Laws.textured_source_retained(tint,image):{==}

def and_false_right(value:Bool) -> {Bool.and(value,False{}) == False{} : Bool}:
  match value:
    case False{}:{==}
    case True{}:{==}

def Laws.texture_zero_width(height,pixels):
  and_false_right(Bool.and(U32.is_le(height,4096),True{}))

def Laws.light_requires_direction(direction,color,ambient,intensity,invalid):
  Equal.cong(Bool,Bool,b => b && F.tint_valid(color) && F.channel(ambient) && F.channel(intensity),F.normal_valid(direction),False{},invalid)

def Laws.hierarchy_root_matrix(local):{==}
def Laws.hierarchy_root_draw(local,mesh,global):{==}
def Laws.hierarchy_child_draw(parent,local,mesh,global):{==}
def Laws.hierarchy_parent_composition(parent,local):{==}
def Laws.hierarchy_empty_bounds(global):
  match global:
    case H.GlobalTransform{matrix}:{==}
def Laws.hierarchy_derived_bounds(global,local):
  match global:
    case H.GlobalTransform{matrix}:{==}
def Laws.hierarchy_visiting_rejected(array,index,next):{==}
def Laws.hierarchy_missing_rejected(array,index,next):{==}
def Laws.hierarchy_invalid_derived_rejected(index,local,global,bounds):{==}
def Laws.hierarchy_parent_rejection_preserves_world(entity,parent,world,rows,error):{==}
def Laws.hierarchy_transform_rejection_preserves_world(entity,transform,world,rows,error):{==}
