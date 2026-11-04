// Bounded well-formed registry: two commands on one device, one on another.
// Payloads and return values are symbolic; topology is explicit.
typedef struct {
  BvDevice device,other_device;
  BvRow owner,other_owner,pool,other_pool,command,peer,foreign,fence,resource;
  BvDep reference;
  BvLease lease;
} Registry;

static void registry(Registry* r) {
  memset(r,0,sizeof(*r));
  r->owner=(BvRow){.kind=BV_DEVICE,.context=&r->device};
  r->other_owner=(BvRow){.kind=BV_DEVICE,.context=&r->other_device};
  r->pool=(BvRow){.kind=BV_POOL,.parent=&r->owner};
  r->other_pool=(BvRow){.kind=BV_POOL,.parent=&r->other_owner};
  r->fence=(BvRow){.kind=BV_FENCE,.parent=&r->owner};
  r->command=(BvRow){.kind=BV_COMMAND,.parent=&r->pool,.next=&r->peer};
  r->peer=(BvRow){.kind=BV_COMMAND,.parent=&r->pool,.next=&r->foreign};
  r->foreign=(BvRow){.kind=BV_COMMAND,.parent=&r->other_pool,.next=&r->resource};
  r->resource=(BvRow){.kind=BV_BUFFER,.parent=&r->owner};
  r->reference=(BvDep){.target=&r->resource,.role=BV_DEP_RECORDED};
  r->command.deps=&r->reference;
  r->command.command.generation=nondet_u64();
  r->command.command.lease=&r->lease;
  r->command.command.lease_serial=7;
  r->lease=(BvLease){.phase=BV_LEASE_ACQUIRED,.serial=7};
  bv_rows=&r->command;
}

static BvCommandPhase phase(void) {
  uint32_t value=nondet_u32(); __CPROVER_assume(value<=BV_COMMAND_INVALID);
  return (BvCommandPhase)value;
}

void verify_device_loss(void) {
  Registry r; registry(&r);
  BvCommandPhase first=phase(),second=phase(),foreign=phase();
  r.command.command.phase=first; r.peer.command.phase=second; r.foreign.command.phase=foreign;
  BvRow peer_fence={.kind=BV_FENCE,.parent=&r.owner};
  BvRow foreign_fence={.kind=BV_FENCE,.parent=&r.other_owner};
  if(first==BV_PENDING || first==BV_UNCERTAIN) r.command.command.submission.pending.fence=&r.fence;
  if(second==BV_PENDING || second==BV_UNCERTAIN) r.peer.command.submission.pending.fence=&peer_fence;
  if(foreign==BV_PENDING || foreign==BV_UNCERTAIN) r.foreign.command.submission.pending.fence=&foreign_fence;
  uint32_t health=nondet_u32(); __CPROVER_assume(health<=BV_LOST);
  r.device.health=(BvHealth)health;
  VkResult result=(VkResult)nondet_result();
  __CPROVER_assert(bv_device_result(&r.owner,result)==result,"device_result_preserves_status");
  __CPROVER_assert(r.device.health==(result==VK_ERROR_DEVICE_LOST ? BV_LOST : health),"device_loss_is_sticky");
  __CPROVER_assert(r.command.command.phase==(result==VK_ERROR_DEVICE_LOST ? BV_COMMAND_INVALID : first),"loss_invalidates_first_owned_command");
  __CPROVER_assert(r.peer.command.phase==(result==VK_ERROR_DEVICE_LOST ? BV_COMMAND_INVALID : second),"loss_invalidates_every_owned_command_in_registry");
  __CPROVER_assert(r.foreign.command.phase==foreign && r.other_device.health==BV_HEALTHY,"loss_is_scoped_to_owner");
  __CPROVER_assert(r.command.deps==&r.reference,"loss_retains_recorded_references");
  if(result==VK_ERROR_DEVICE_LOST) {
    __CPROVER_assert(r.command.command.submission.pending.fence==NULL && r.peer.command.submission.pending.fence==NULL,"lost_commands_clear_submission_storage");
    bv_device_result(&r.owner,(VkResult)nondet_result());
    __CPROVER_assert(bv_lost(&r.owner),"later_result_cannot_revive_lost_device");
  }
}

void verify_record_reset_failure(void) {
  Registry r; registry(&r);
  uint32_t operation=nondet_u32(),slot=nondet_u32();
  __CPROVER_assume(operation<3 && slot<BV_MAX_DESCRIPTOR_SETS);
  r.command.command.phase=operation==0 ? BV_INITIAL : operation==1 ? BV_RECORDING : phase();
  __CPROVER_assume(r.command.command.phase!=BV_PENDING && r.command.command.phase!=BV_UNCERTAIN);
  r.command.command.sets[slot]=&r.resource;
  uint64_t generation=r.command.command.generation;
  VkResult result=(VkResult)nondet_result(); __CPROVER_assume(result!=VK_SUCCESS);
  Term error=operation==0 ? proof_begin(&r.command,result) : operation==1 ? proof_end(&r.command,result) : proof_reset(&r.command,result);
  __CPROVER_assert(error==(uint32_t)(int32_t)result,"record_reset_preserves_error_bits");
  __CPROVER_assert(r.command.deps==&r.reference && r.reference.target==&r.resource,"failed_record_reset_retains_references");
  __CPROVER_assert(r.command.command.sets[slot]==&r.resource && r.command.command.lease==&r.lease && r.command.command.lease_serial==7,"failed_record_reset_retains_bindings_and_lease");
  __CPROVER_assert(r.command.command.generation==generation,"failed_record_reset_does_not_advance_generation");
  __CPROVER_assert(r.command.command.phase==BV_COMMAND_INVALID,"failed_record_reset_invalidates_command");
  __CPROVER_assert(bv_command_fence(&r.command)==NULL,"failed_record_reset_does_not_invent_submission");
  __CPROVER_assert(r.device.health==(result==VK_ERROR_DEVICE_LOST ? BV_LOST : BV_HEALTHY),"record_reset_marks_device_loss");
}

void verify_submit_result(void) {
  Registry r; registry(&r); r.command.command.phase=BV_EXECUTABLE;
  VkResult result=(VkResult)nondet_result();
  Term error=proof_submit(&r.owner,&r.command,&r.fence,result);
  bool oom=result==VK_ERROR_OUT_OF_HOST_MEMORY || result==VK_ERROR_OUT_OF_DEVICE_MEMORY;
  BvCommandPhase expected=result==VK_SUCCESS ? BV_PENDING : result==VK_ERROR_DEVICE_LOST ? BV_COMMAND_INVALID : oom ? BV_EXECUTABLE : BV_UNCERTAIN;
  __CPROVER_assert(error==(uint32_t)(int32_t)result,"submit_preserves_error_bits");
  __CPROVER_assert(r.command.command.phase==expected,"submit_classifies_all_result_bits");
  __CPROVER_assert(bv_command_fence(&r.command)==((expected==BV_PENDING || expected==BV_UNCERTAIN) ? &r.fence : NULL),"submitted_or_uncertain_work_keeps_fence");
  __CPROVER_assert(r.command.deps==&r.reference,"every_submit_result_retains_recorded_references");
  __CPROVER_assert(r.lease.phase==(expected==BV_PENDING ? BV_LEASE_RENDERING : expected==BV_UNCERTAIN ? BV_LEASE_RENDER_UNCERTAIN : BV_LEASE_ACQUIRED),"submission_lease_tracks_uncertainty");
  __CPROVER_assert(r.device.health==(result==VK_ERROR_DEVICE_LOST ? BV_LOST : BV_HEALTHY),"submit_marks_device_loss");
}

void verify_uncertain_guards(void) {
  Registry r; registry(&r);
  r.command.command.phase=BV_UNCERTAIN;
  r.command.command.submission.uncertain.fence=&r.fence;
  r.peer.command.phase=BV_EXECUTABLE;
  BvRow unused_fence={.kind=BV_FENCE,.parent=&r.owner};
  __CPROVER_assert(bv_uncertain(&r.owner),"uncertain_command_is_discoverable");
  __CPROVER_assert(proof_reset_guard(&r.owner,&r.command)==BV_LIFETIME,"uncertain_command_blocks_reset");
  __CPROVER_assert(proof_fence_reset_guard(&r.owner,&r.fence)==BV_LIFETIME,"uncertain_fence_blocks_reset");
  __CPROVER_assert(proof_fence_observe_guard(&r.owner,&r.fence)==BV_LIFETIME,"uncertain_fence_blocks_observation");
  __CPROVER_assert(proof_pool_destroy_guard(&r.pool)==BV_LIFETIME,"uncertain_pool_blocks_destruction");
  __CPROVER_assert(proof_fence_destroy_guard(&r.owner,&r.fence)==BV_LIFETIME,"uncertain_fence_blocks_destruction");
  __CPROVER_assert(proof_submit_guard(&r.owner,&r.peer,&unused_fence)==BV_LIFETIME,"uncertain_device_blocks_other_submission");
  __CPROVER_assert(r.command.deps==&r.reference && bv_command_fence(&r.command)==&r.fence,"rejections_preserve_uncertain_ownership");
}

void verify_lost_guards(void) {
  Registry r; registry(&r); r.device.health=BV_LOST;
  __CPROVER_assert(proof_reset_guard(&r.owner,&r.command)==(uint32_t)VK_ERROR_DEVICE_LOST,"lost_device_blocks_command_reset");
  __CPROVER_assert(proof_fence_reset_guard(&r.owner,&r.fence)==(uint32_t)VK_ERROR_DEVICE_LOST,"lost_device_blocks_fence_reset");
  __CPROVER_assert(proof_fence_observe_guard(&r.owner,&r.fence)==(uint32_t)VK_ERROR_DEVICE_LOST,"lost_device_blocks_fence_observation");
}

void verify_descriptor_failure(void) {
  Registry r; registry(&r);
  BvRow pool={.kind=BV_DESCRIPTOR_POOL},set={.kind=BV_DESCRIPTOR_SET},layout={.kind=BV_DESCRIPTOR_LAYOUT};
  BvDep layout_ref={.target=&layout,.role=BV_DEP_SET_LAYOUT};
  BvDep pool_ref={.target=&pool,.role=BV_DEP_SET_POOL,.next=&layout_ref}; set.deps=&pool_ref;
  uint32_t sets=nondet_u32(),uniforms=nondet_u32(),sampled=nondet_u32(); __CPROVER_assume(sets>0);
  pool.object.descriptor_pool=(BvDescriptorPool){.phase=BV_POOL_READY,.sets=sets,.used_uniforms=uniforms,.used_sampled=sampled};
  VkResult result=(VkResult)nondet_result(); __CPROVER_assume(result!=VK_SUCCESS);
  Term error=nondet_u32()&1 ? proof_free_set(&r.owner,&set,result) : proof_reset_descriptor_pool(&r.owner,&pool,result);
  __CPROVER_assert(error==(uint32_t)(int32_t)result,"descriptor_cleanup_preserves_error_bits");
  __CPROVER_assert(pool.object.descriptor_pool.phase==BV_POOL_QUARANTINED,"failed_native_cleanup_quarantines_pool");
  __CPROVER_assert(pool.object.descriptor_pool.sets==sets && pool.object.descriptor_pool.used_uniforms==uniforms && pool.object.descriptor_pool.used_sampled==sampled,"failed_native_cleanup_preserves_accounting");
  __CPROVER_assert(set.deps==&pool_ref && pool_ref.next==&layout_ref,"failed_native_cleanup_preserves_set_ownership");
  __CPROVER_assert(r.device.health==(result==VK_ERROR_DEVICE_LOST ? BV_LOST : BV_HEALTHY),"descriptor_cleanup_marks_device_loss");
  __CPROVER_assert(proof_descriptor_free_guard(&pool,&set)==BV_LIFETIME,"quarantined_pool_blocks_further_free");
  r.command.deps=&r.reference; r.reference.target=&set;
  __CPROVER_assert(proof_descriptor_submit_guard(&r.command)==BV_LIFETIME,"quarantined_pool_blocks_recorded_submit");
  __CPROVER_assert(proof_descriptor_reset_guard(&r.owner,&pool)==(result==VK_ERROR_DEVICE_LOST ? (uint32_t)VK_ERROR_DEVICE_LOST : BV_LIFETIME),"quarantined_pool_blocks_reset");
}

void verify_fence_reset_failure(void) {
  Registry r; registry(&r);
  VkResult result=(VkResult)nondet_result(); __CPROVER_assume(result!=VK_SUCCESS);
  __CPROVER_assert(proof_fence_reset(&r.owner,result)==(uint32_t)(int32_t)result,"fence_reset_preserves_failure_status");
  __CPROVER_assert(r.command.deps==&r.reference,"failed_fence_reset_retains_references");
  __CPROVER_assert(r.device.health==(result==VK_ERROR_DEVICE_LOST ? BV_LOST : BV_HEALTHY),"fence_reset_marks_device_loss");
}

void verify_synced_submission(void) {
  Registry r; registry(&r); r.command.command.phase=BV_EXECUTABLE;
  BvRow wait={.kind=BV_SEMAPHORE,.semaphore.phase=BV_SEM_SIGNALED};
  BvRow signal={.kind=BV_SEMAPHORE};
  BvDep* waiting=malloc(sizeof(*waiting)); BvDep* signaling=malloc(sizeof(*signaling));
  __CPROVER_assume(waiting && signaling);
  *waiting=(BvDep){.target=&wait,.role=BV_DEP_SUBMIT_WAIT};
  *signaling=(BvDep){.target=&signal,.role=BV_DEP_SUBMIT_SIGNAL,.next=waiting};
  VkResult result=(VkResult)nondet_result();
  __CPROVER_assert(proof_synced(&r.owner,&r.command,&r.fence,signaling,result)==(uint32_t)(int32_t)result,"synced_submission_preserves_error_bits");
  bool active=r.command.command.phase==BV_PENDING || r.command.command.phase==BV_UNCERTAIN;
  if(active) {
    __CPROVER_assert(r.command.deps==waiting && waiting->next==signaling && signaling->next==&r.reference,"active_synced_submission_keeps_both_semaphore_edges");
    bool uncertain=r.command.command.phase==BV_UNCERTAIN;
    __CPROVER_assert(wait.semaphore.phase==(uncertain ? BV_SEM_UNCERTAIN : BV_SEM_SUBMIT_WAIT) && signal.semaphore.phase==(uncertain ? BV_SEM_UNCERTAIN : BV_SEM_SIGNAL_PENDING),"synced_semaphores_track_uncertainty");
    free(waiting); free(signaling);
  } else {
    __CPROVER_assert(r.command.deps==&r.reference,"rejected_synced_submission_keeps_only_recorded_edges");
    __CPROVER_assert(wait.semaphore.phase==BV_SEM_SIGNALED && signal.semaphore.phase==BV_SEM_UNUSED,"rejected_synced_submission_preserves_semaphore_state");
  }
}

void verify_idle_failure(void) {
  Registry r; registry(&r);
  r.command.command.phase=(nondet_u32()&1) ? BV_PENDING : BV_UNCERTAIN;
  BvCommandPhase before=r.command.command.phase;
  r.command.command.submission.pending.fence=&r.fence;
  VkResult result=(VkResult)nondet_result(); __CPROVER_assume(result!=VK_SUCCESS);
  __CPROVER_assert(proof_idle(&r.owner,result)==result,"idle_preserves_failure_status");
  __CPROVER_assert(r.command.deps==&r.reference,"failed_idle_retains_recorded_references");
  __CPROVER_assert(r.command.command.phase==(result==VK_ERROR_DEVICE_LOST ? BV_COMMAND_INVALID : before),"failed_idle_does_not_claim_completion");
  if(result!=VK_ERROR_DEVICE_LOST) {
    __CPROVER_assert(bv_command_fence(&r.command)==&r.fence,"failed_idle_preserves_submission_ownership");
    __CPROVER_assert(proof_entry_cleanup_guard(result)==(uint32_t)(int32_t)result,"failed_entry_completion_preserves_error_and_live_resources");
  }
}

void verify_completion(void) {
  Registry r; registry(&r);
  bool uncertain=(nondet_u32()&1)!=0;
  r.command.command.phase=uncertain ? BV_UNCERTAIN : BV_PENDING;
  r.command.command.submission.pending.fence=&r.fence;
  r.lease.phase=uncertain ? BV_LEASE_RENDER_UNCERTAIN : BV_LEASE_RENDERING;
  BvRow wait={.kind=BV_SEMAPHORE},signal={.kind=BV_SEMAPHORE};
  BvDep* waiting=malloc(sizeof(*waiting)); BvDep* signaling=malloc(sizeof(*signaling));
  __CPROVER_assume(waiting && signaling);
  *waiting=(BvDep){.target=&wait,.role=BV_DEP_SUBMIT_WAIT,.next=&r.reference};
  *signaling=(BvDep){.target=&signal,.role=BV_DEP_SUBMIT_SIGNAL,.next=waiting}; r.command.deps=signaling;
  bv_complete(&r.command);
  __CPROVER_assert(r.command.command.phase==(uncertain ? BV_COMMAND_INVALID : BV_COMPLETED),"uncertain_completion_requires_reset");
  __CPROVER_assert(r.command.deps==&r.reference && r.reference.next==NULL,"completion_releases_only_submission_edges");
  __CPROVER_assert(bv_command_fence(&r.command)==NULL,"completion_clears_active_fence");
  __CPROVER_assert(wait.semaphore.phase==(uncertain ? BV_SEM_QUARANTINED : BV_SEM_UNUSED) && signal.semaphore.phase==(uncertain ? BV_SEM_QUARANTINED : BV_SEM_SIGNALED),"completion_quarantines_uncertain_semaphores");
  __CPROVER_assert(r.lease.phase==(uncertain ? BV_LEASE_ABANDONED : BV_LEASE_RENDERED),"completion_preserves_lease_uncertainty");
}

void verify_idle_success(void) {
  Registry r; registry(&r);
  bool uncertain=(nondet_u32()&1)!=0;
  r.command.command.phase=uncertain ? BV_UNCERTAIN : BV_PENDING;
  r.command.command.submission.pending.fence=&r.fence;
  __CPROVER_assert(proof_idle(&r.owner,VK_SUCCESS)==VK_SUCCESS,"idle_success_is_preserved");
  __CPROVER_assert(r.command.command.phase==(uncertain ? BV_COMMAND_INVALID : BV_COMPLETED),"successful_idle_completes_active_command");
  __CPROVER_assert(r.command.deps==&r.reference && bv_command_fence(&r.command)==NULL,"successful_idle_preserves_recorded_ownership");
}
