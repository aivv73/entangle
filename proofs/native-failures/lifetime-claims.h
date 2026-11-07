// Predicate/retirement entries use explicit stack topology. Collection entries
// use actual heap rows so production registry removal and free run unchanged.
// Initial allocation success is a premise; bv_prepare_refs allocations may fail.
typedef struct {
  BvDevice device,other_device;
  BvRow owner,other_owner,pool;
  BvRow *buffers[2],*memories[2];
} Lifetime;

static bool choice(void) { return (nondet_u32()&1)!=0; }
static BvRow initial_r0,initial_r1,initial_r2,initial_r3,initial_r4,initial_r5,initial_r6,initial_r7;
static BvRow* const initial_rows[8]={&initial_r0,&initial_r1,&initial_r2,&initial_r3,&initial_r4,&initial_r5,&initial_r6,&initial_r7};
static BvDep initial_e0,initial_e1,initial_e2,initial_e3,initial_e4,initial_e5,initial_e6,initial_e7;
static BvDep* const initial_edges[8]={&initial_e0,&initial_e1,&initial_e2,&initial_e3,&initial_e4,&initial_e5,&initial_e6,&initial_e7};
static unsigned initial_row_count,initial_edge_count;
static bool heap_topology;
extern __CPROVER_bool __CPROVER_malloc_may_fail;
extern const void* __CPROVER_memory_leak;
static void lifetime(Lifetime* r,bool heap) {
  memset(r,0,sizeof(*r)); bv_rows=NULL; bv_next_id=1;
  // Initial allocations already succeeded at this proof boundary. Avoid
  // introducing null-pointer aliases and then assuming them away afterward.
  __CPROVER_malloc_may_fail=false;
  initial_row_count=initial_edge_count=0;heap_topology=heap;
  proof_destroyed=proof_freed=0;
  r->owner=(BvRow){.kind=BV_DEVICE,.context=&r->device};
  r->other_owner=(BvRow){.kind=BV_DEVICE,.context=&r->other_device};
  r->pool=(BvRow){.kind=BV_POOL,.parent=&r->owner};
}
static BvRow* row(BvKind kind,BvRow* parent) {
  BvRow* value;
  __CPROVER_assert(initial_row_count<8,"initial_registry_topology_bound");
  if(heap_topology) {
    value=__CPROVER_allocate(sizeof(BvRow),true);
    if(choice()) __CPROVER_memory_leak=value;
  }
  else value=initial_rows[initial_row_count];
  initial_row_count++;
  *value=(BvRow){.id=initial_row_count,.kind=kind,.parent=parent,.next=bv_rows};bv_rows=value;
  return value;
}
static BvDep* edge(BvRow* from,BvRow* to,BvDepRole role) {
  BvDep* value;
  if(heap_topology) {
    value=__CPROVER_allocate(sizeof(BvDep),false);
    if(choice()) __CPROVER_memory_leak=value;
  }
  else {
    __CPROVER_assert(initial_edge_count<8,"initial_dependency_topology_bound");
    value=initial_edges[initial_edge_count++];
  }
  *value=(BvDep){.target=to,.role=role,.next=from->deps}; from->deps=value;
  return value;
}
static void pair(Lifetime* r,unsigned j,bool adjacent_memory) {
  BvRow* previous=bv_rows;
  r->memories[j]=row(BV_MEMORY,&r->owner);
  r->buffers[j]=row(BV_BUFFER,&r->owner);
  // Vary initial list order without merging different allocated identities.
  if(!adjacent_memory) {
    r->buffers[j]->next=previous;r->memories[j]->next=r->buffers[j];bv_rows=r->memories[j];
  }
  edge(r->buffers[j],r->memories[j],BV_DEP_BINDING);
}
static void clear_registry(void) {
  if(heap_topology) while(bv_rows) bv_remove(bv_rows);
  bv_rows=NULL;
}
static void present_pair(uint32_t buffer,uint32_t memory,bool present) {
  __CPROVER_assert((bv_get(buffer,BV_BUFFER)!=NULL)==present &&
                   (bv_get(memory,BV_MEMORY)!=NULL)==present,
                   "collection_releases_exactly_eligible_pairs");
}
static void observed_pairs(Lifetime* r,bool first,bool second) {
  for(unsigned j=0;j<2;j++) {proof_buffer_ids[j]=r->buffers[j]->id;proof_memory_ids[j]=r->memories[j]->id;}
  proof_retained[0]=first;proof_retained[1]=second;
}

void verify_lifetime_retirement(void) {
  Lifetime r; lifetime(&r,false); pair(&r,0,true); pair(&r,1,false);
  BvRetirement items[2]={{r.buffers[0],r.memories[0]},{r.buffers[1],r.memories[1]}};
  uint32_t modes[2]={nondet_u32(),nondet_u32()},expected[2]={0,0};
  bool before_buffer[2],before_memory[2];
  __CPROVER_assume(modes[0]<7 && modes[1]<7);
  BvRow* set=row(BV_DESCRIPTOR_SET,&r.owner);
  BvRow* command=row(BV_COMMAND,&r.pool);
  unsigned selected=nondet_u32(); __CPROVER_assume(selected<2);
  bool recording=choice(); command->command.phase=recording ? BV_RECORDING : BV_EXECUTABLE;
  edge(command,set,BV_DEP_RECORDED); edge(set,r.buffers[selected],BV_DEP_UNIFORM);
  BvRow* aliases[2]={row(BV_BUFFER,&r.owner),row(BV_BUFFER,&r.owner)};
  edge(aliases[0],r.memories[0],BV_DEP_BINDING);
  edge(aliases[1],r.memories[1],BV_DEP_BINDING);
  for(unsigned j=0;j<2;j++) {
    if(modes[j]!=6) aliases[j]->deps=NULL;
    before_buffer[j]=r.buffers[j]->retired=choice();
    before_memory[j]=r.memories[j]->retired=choice();
    switch(modes[j]) {
      case 1:items[j].buffer=NULL;expected[j]=BV_INVALID;break;
      case 2:items[j].memory=NULL;expected[j]=BV_INVALID;break;
      case 3:r.buffers[j]->parent=&r.other_owner;expected[j]=BV_INVALID;break;
      case 4:items[j].memory=r.memories[1-j];expected[j]=BV_ARGUMENT;break;
      case 5:r.buffers[j]->deps->data.binding.offset=1;expected[j]=BV_ARGUMENT;break;
      case 6:expected[j]=BV_LIFETIME;break;
      default:break;
    }
    if(!expected[j] && recording && selected==j) expected[j]=BV_LIFETIME;
  }
  size_t count=nondet_u32(); __CPROVER_assume(count<=2);
  uint32_t prior=nondet_u32();
  uint32_t wanted=prior ? prior : count && expected[0] ? expected[0] : count==2 ? expected[1] : 0;
  BvRow* head=bv_rows;
  Term result=proof_retire(&r.owner,items,count,prior);
  __CPROVER_assert(result==wanted,"retirement_preserves_first_error_and_validation_order");
  for(unsigned j=0;j<2;j++) {
    __CPROVER_assert(r.buffers[j]->retired==(wanted || j>=count ? before_buffer[j] : true) &&
                     r.memories[j]->retired==(wanted || j>=count ? before_memory[j] : true),
                     "retirement_is_atomic_for_complete_allocation_set");
  }
  __CPROVER_assert(bv_rows==head && command->deps->target==set && set->deps->target==r.buffers[selected],
                   "retirement_preserves_registry_and_recorded_ownership");
  clear_registry();
}

void verify_lifetime_graph(void) {
  Lifetime r; lifetime(&r,false);
  BvRow* memory=row(BV_MEMORY,&r.owner);
  BvRow* image=row(BV_IMAGE,&r.owner);
  BvRow* view=row(BV_IMAGE_VIEW,&r.owner);
  BvRow* sampler=row(BV_SAMPLER,&r.owner);
  BvRow* set=row(BV_DESCRIPTOR_SET,&r.owner);
  BvRow* command=row(BV_COMMAND,&r.pool);
  BvRow* unrelated=row(BV_MEMORY,&r.owner); unrelated->retired=true;
  edge(image,memory,BV_DEP_BINDING); edge(view,image,BV_DEP_VIEW_IMAGE);
  edge(set,view,BV_DEP_SAMPLED_VIEW); edge(set,sampler,BV_DEP_SAMPLER);
  edge(command,set,BV_DEP_RECORDED);
  bool sealed=choice(); memory->retired=sealed;
  image->retired=choice(); view->retired=choice(); sampler->retired=choice(); set->retired=choice();
  sealed=sealed || image->retired || view->retired || sampler->retired || set->retired;
  uint32_t phase=nondet_u32(); __CPROVER_assume(phase<=BV_COMMAND_INVALID);
  command->command.phase=(BvCommandPhase)phase;
  BvRow fence={.kind=BV_FENCE,.parent=&r.owner};
  if(phase==BV_PENDING || phase==BV_UNCERTAIN) command->command.submission.pending.fence=&fence;
  bool foreign=choice(); if(foreign) r.pool.parent=&r.other_owner;
  __CPROVER_assert(bv_may_reach_depth(command,memory,BV_KIND_COUNT),"sampled_graph_reaches_bound_memory");
  __CPROVER_assert(!bv_may_reach_depth(command,unrelated,BV_KIND_COUNT),"sampled_graph_does_not_invent_ownership");
  __CPROVER_assert(bv_sealed(command,BV_KIND_COUNT)==sealed,"sealed_descendants_block_new_recording");
  __CPROVER_assert(bv_memory_busy(memory)==(!foreign && (phase==BV_PENDING || phase==BV_UNCERTAIN)),
                   "transitive_memory_busy_is_scoped_to_active_owner");
  __CPROVER_assert(bv_referenced(set) && bv_referenced(view) && bv_referenced(image) &&
                   bv_referenced(memory) && bv_referenced(sampler),"sampled_graph_retains_every_resource");
  __CPROVER_assert(proof_memory_destroy_guard(memory)==BV_LIFETIME && proof_image_destroy_guard(image)==BV_LIFETIME &&
                   proof_view_destroy_guard(view)==BV_LIFETIME && proof_sampler_destroy_guard(sampler)==BV_LIFETIME,
                   "sampled_resource_destruction_refuses_retaining_edges");
  clear_registry();
}

void verify_lifetime_prepare(void) {
  Lifetime r; lifetime(&r,false);
  BvRow* old=row(BV_BUFFER,&r.owner);
  BvRow* a=row(BV_DESCRIPTOR_SET,&r.owner);
  BvRow* image=row(BV_IMAGE,&r.owner);
  BvRow* view=row(BV_IMAGE_VIEW,&r.owner);
  BvRow* b=row(BV_BUFFER,&r.owner);
  BvRow* command=row(BV_COMMAND,&r.pool);
  BvDep* prior=edge(command,old,BV_DEP_RECORDED);
  edge(a,view,BV_DEP_SAMPLED_VIEW);edge(view,image,BV_DEP_VIEW_IMAGE);
  image->retired=choice(); b->retired=choice();
  BvRow* resources[2]={choice() ? old : a,choice() ? a : b};
  uint32_t count=nondet_u32(); __CPROVER_assume(count<=2);
  bool sealed=(count>0 && resources[0]==a && image->retired) ||
              (count>1 && ((resources[1]==a && image->retired) || (resources[1]==b && b->retired)));
  __CPROVER_malloc_may_fail=true;
  uint32_t result=bv_prepare_refs(command,count,resources);
  __CPROVER_assert(result==0 || result==BV_LIMIT || result==BV_LIFETIME,"reference_staging_reports_only_admitted_outcomes");
  __CPROVER_assert(!sealed || result!=0,"reference_staging_rejects_sealed_descendants");
  if(result) {
    __CPROVER_assert(command->deps==prior && prior->next==NULL && prior->target==old,
                     "failed_reference_staging_preserves_prior_ownership");
  } else {
    unsigned old_count=0,a_count=0,b_count=0,total=0;
    for(BvDep* dep=command->deps;dep;dep=dep->next) {
      __CPROVER_assert(dep->role==BV_DEP_RECORDED,"reference_staging_keeps_recorded_role");
      old_count+=dep->target==old; a_count+=dep->target==a; b_count+=dep->target==b; total++;
    }
    bool want_a=(count>0 && resources[0]==a) || (count>1 && resources[1]==a);
    bool want_b=count>1 && resources[1]==b;
    __CPROVER_assert(old_count==1 && a_count==want_a && b_count==want_b && total==1+want_a+want_b,
                     "reference_staging_installs_complete_deduplicated_set");
  }
  __CPROVER_assert(command->command.lease==NULL && command->command.lease_serial==0,
                   "allocated_resource_staging_preserves_acquisition_identity");
  // Only staged nodes are dynamic in this entry; the prior edge is initial state.
  while(command->deps && command->deps!=prior) {
    BvDep* dep=command->deps;command->deps=dep->next;free(dep);
  }
  clear_registry();
}

static void collection_case(bool first_order,bool second_order,uint32_t configuration) {
  Lifetime r; lifetime(&r,true);
  __CPROVER_assume(configuration<64);
  BvRow holder={.id=20,.kind=BV_DESCRIPTOR_SET,.parent=&r.owner};
  BvRow foreign_memory={.id=21,.kind=BV_MEMORY,.parent=&r.other_owner,.retired=true,.next=&holder};
  BvDep foreign_binding={.target=&foreign_memory,.role=BV_DEP_BINDING};
  BvRow foreign_buffer={.id=22,.kind=BV_BUFFER,.parent=&r.other_owner,.retired=true,.deps=&foreign_binding,.next=&foreign_memory};
  bv_rows=&foreign_buffer;
  pair(&r,0,first_order); pair(&r,1,second_order);
  uint32_t ids[2],memory_ids[2]; bool retained[2],retired[2];
  for(unsigned j=0;j<2;j++) {
    ids[j]=r.buffers[j]->id;memory_ids[j]=r.memories[j]->id;
    retired[j]=r.buffers[j]->retired=r.memories[j]->retired=((configuration>>(2*j))&1)!=0;
    retained[j]=((configuration>>(2*j+1))&1)!=0;
  }
  BvDep reference1={.target=r.buffers[1],.role=BV_DEP_UNIFORM};
  BvDep reference0={.target=r.buffers[0],.role=BV_DEP_UNIFORM,.next=retained[1] ? &reference1 : NULL};
  holder.deps=retained[0] ? &reference0 : retained[1] ? &reference1 : NULL;
  observed_pairs(&r,retained[0],retained[1]);
  bool invalid=(configuration&16)!=0,lost=(configuration&32)!=0; r.device.health=lost ? BV_LOST : BV_HEALTHY;
  uint32_t wanted=invalid ? BV_INVALID : lost ? (uint32_t)VK_ERROR_DEVICE_LOST : 0;
  __CPROVER_assert(proof_collect(invalid ? NULL : &r.owner)==wanted,"collection_preserves_invalid_or_lost_error");
  uint32_t destroyed=0,freed=0;
  for(unsigned j=0;j<2;j++) {
    bool eligible=!invalid && !lost && retired[j] && !retained[j];
    present_pair(ids[j],memory_ids[j],!eligible);
    if(eligible) {destroyed|=1u<<ids[j];freed|=1u<<memory_ids[j];}
  }
  __CPROVER_assert(proof_destroyed==destroyed && proof_freed==freed,"collection_dispatches_exactly_eligible_pairs");
  __CPROVER_assert(bv_get(22,BV_BUFFER) && bv_get(21,BV_MEMORY),"collection_retains_other_device_registry");
  __CPROVER_assert(proof_collect(invalid ? NULL : &r.owner)==wanted && proof_destroyed==destroyed && proof_freed==freed,
                   "repeated_collection_is_idempotent");
  // Only the victim pairs are heap objects here. Static foreign/descriptor
  // owners cannot be collected; production removal handles every heap survivor.
  for(unsigned j=0;j<2;j++) {
    // A failed assertion does not stop symbolic execution. Mutants may already
    // have removed a pair that should survive; never pass a stale fixture pointer
    // to bv_remove, whose production precondition requires a registered row.
    BvRow* buffer=bv_get(ids[j],BV_BUFFER);
    BvRow* memory=bv_get(memory_ids[j],BV_MEMORY);
    if(buffer) bv_remove(buffer);
    if(memory) bv_remove(memory);
  }
  bv_rows=NULL;
}

// collection-cases.bend appends every concrete input entry for all four orders.

static void completion_reset_case(bool uncertain) {
  Lifetime r; lifetime(&r,true); pair(&r,0,true); pair(&r,1,true);
  uint32_t b0=r.buffers[0]->id,m0=r.memories[0]->id,b1=r.buffers[1]->id,m1=r.memories[1]->id;
  BvRow* set=row(BV_DESCRIPTOR_SET,&r.owner); edge(set,r.buffers[1],BV_DEP_UNIFORM);
  BvRow* first=row(BV_COMMAND,&r.pool); edge(first,r.buffers[0],BV_DEP_RECORDED);edge(first,r.buffers[1],BV_DEP_RECORDED);
  BvRow* second=row(BV_COMMAND,&r.pool);edge(second,set,BV_DEP_RECORDED);
  BvRow fence={.kind=BV_FENCE,.parent=&r.owner};
  first->command.phase=uncertain ? BV_UNCERTAIN : BV_PENDING;
  first->command.submission.pending.fence=&fence; second->command.phase=BV_EXECUTABLE;
  BvRetirement items[2]={{r.buffers[0],r.memories[0]},{r.buffers[1],r.memories[1]}};
  observed_pairs(&r,true,true);
  __CPROVER_assert(proof_retire(&r.owner,items,2,0)==0,"active_recordings_allow_deferred_retirement");
  proof_collect(&r.owner);present_pair(b0,m0,true);present_pair(b1,m1,true);
  bv_complete(first);
  proof_collect(&r.owner);present_pair(b0,m0,true);present_pair(b1,m1,true);
  __CPROVER_assert(proof_destroyed==0 && proof_freed==0,"completion_alone_retains_recorded_allocations");
  __CPROVER_assert(proof_reset(first,VK_SUCCESS)==0,"successful_first_reset_releases_recorded_edges");
  proof_retained[0]=false;
  proof_collect(&r.owner);present_pair(b0,m0,false);present_pair(b1,m1,true);
  __CPROVER_assert(proof_reset(second,VK_SUCCESS)==0,"successful_second_reset_releases_recorded_edges");
  proof_collect(&r.owner);present_pair(b1,m1,true);
  __CPROVER_assert(bv_referenced(r.buffers[1]),"descriptor_ownership_outlives_last_command_reset");
  bv_remove(set);
  proof_retained[1]=false;
  proof_collect(&r.owner);present_pair(b1,m1,false);
  __CPROVER_assert(proof_destroyed==((1u<<b0)|(1u<<b1)) && proof_freed==((1u<<m0)|(1u<<m1)),
                   "last_owner_release_allows_complete_collection");
  clear_registry();
}

void verify_lifetime_completion_reset_pending(void) {completion_reset_case(false);}
void verify_lifetime_completion_reset_uncertain(void) {completion_reset_case(true);}
