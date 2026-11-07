// Four lease slots (at most two active), two images, one command, three fences,
// one binary semaphore, and a foreign owner. Initial topology is a premise.
typedef struct {
  BvDevice *device,*foreign_device;
  BvRow *owner,*foreign,*pool,*command,*swapchain,*acquire,*render,*present,*semaphore,*image,*peer_image;
  BvSwapchain* target;
  BvLease* leases;
  BvRow** images;
} Presentation;
extern const void* __CPROVER_memory_leak;
static BvDevice fixture_device,fixture_foreign_device;
static BvRow fixture_owner,fixture_foreign,fixture_pool,fixture_command,fixture_swapchain,fixture_acquire,fixture_render,fixture_present,fixture_semaphore,fixture_image,fixture_peer_image;
static BvSwapchain fixture_target;
static BvLease fixture_leases[4];
static BvDep fixture_image_edge,fixture_peer_image_edge;
static BvRow* fixture_images[2];
static void presentation(Presentation* r) {
  proof_token_seen=false;
  *r=(Presentation){.device=&fixture_device,.foreign_device=&fixture_foreign_device,
    .owner=&fixture_owner,.foreign=&fixture_foreign,.pool=&fixture_pool,
    .command=&fixture_command,.swapchain=&fixture_swapchain,.acquire=&fixture_acquire,
    .render=&fixture_render,.present=&fixture_present,.semaphore=&fixture_semaphore,
    .image=&fixture_image,.peer_image=&fixture_peer_image,.target=&fixture_target,
    .leases=fixture_leases,.images=fixture_images};
  memset(r->device,0,sizeof(*r->device));memset(r->foreign_device,0,sizeof(*r->foreign_device));
  r->leases[0]=(BvLease){0};r->leases[1]=(BvLease){0};r->leases[2]=(BvLease){0};r->leases[3]=(BvLease){0};
  *r->owner=(BvRow){.id=1,.kind=BV_DEVICE,.context=r->device,.next=r->swapchain};
  *r->foreign=(BvRow){.id=2,.kind=BV_DEVICE,.context=r->foreign_device};
  *r->pool=(BvRow){.id=3,.kind=BV_POOL,.parent=r->owner};
  *r->swapchain=(BvRow){.id=4,.kind=BV_SWAPCHAIN,.parent=r->owner,.context=r->target,.next=r->command};
  *r->command=(BvRow){.id=5,.kind=BV_COMMAND,.parent=r->pool,.next=r->acquire};
  *r->acquire=(BvRow){.id=6,.kind=BV_FENCE,.parent=r->owner,.next=r->render};
  *r->render=(BvRow){.id=7,.kind=BV_FENCE,.parent=r->owner,.next=r->present};
  *r->present=(BvRow){.id=8,.kind=BV_FENCE,.parent=r->owner,.next=r->semaphore};
  *r->semaphore=(BvRow){.id=9,.kind=BV_SEMAPHORE,.parent=r->owner,.next=r->image};
  *r->image=(BvRow){.id=10,.kind=BV_IMAGE,.parent=r->owner,.next=r->peer_image};
  *r->peer_image=(BvRow){.id=11,.kind=BV_IMAGE,.parent=r->owner};
  r->image->object.image=(BvImage){.storage=BV_BORROWED_IMAGE,.swapchain=r->swapchain,.index=0};
  r->peer_image->object.image=(BvImage){.storage=BV_BORROWED_IMAGE,.swapchain=r->swapchain,.index=1};
  fixture_image_edge=(BvDep){.target=r->swapchain,.role=BV_DEP_SWAPCHAIN};r->image->deps=&fixture_image_edge;
  fixture_peer_image_edge=(BvDep){.target=r->swapchain,.role=BV_DEP_SWAPCHAIN};r->peer_image->deps=&fixture_peer_image_edge;
  r->images[0]=r->image;r->images[1]=r->peer_image;
  *r->target=(BvSwapchain){.count=2,.lease_count=4,.images=r->images,.leases=r->leases};
  // Only rows visited for protocol ownership: swapchain, command and images.
  // Validated owner/pool/fence/semaphore objects have no outgoing registry edges.
  r->command->next=r->image;bv_rows=r->swapchain;
}
static bool oom(VkResult result) {
  return result==VK_ERROR_OUT_OF_HOST_MEMORY || result==VK_ERROR_OUT_OF_DEVICE_MEMORY;
}
static bool acquired_result(VkResult result) { return result==VK_SUCCESS || result==VK_SUBOPTIMAL_KHR; }
static bool present_result(VkResult result) {
  return acquired_result(result) || result==VK_ERROR_OUT_OF_DATE_KHR || result==VK_ERROR_SURFACE_LOST_KHR;
}
static bool empty_acquire(VkResult result) {
  return oom(result) || result==VK_ERROR_DEVICE_LOST || result==VK_TIMEOUT || result==VK_NOT_READY ||
    result==VK_ERROR_OUT_OF_DATE_KHR || result==VK_ERROR_SURFACE_LOST_KHR;
}
static void lease_at(Presentation* r,unsigned j,BvLeasePhase phase,uint64_t serial,uint32_t index,BvRow* fence) {
  r->leases[j]=(BvLease){.phase=phase,.swapchain=r->swapchain,.fence=fence,.index=index,.serial=serial};
  if(serial>r->device->lease_serial) r->device->lease_serial=serial;
}
static void acquired(Presentation* r) {
  r->device->lease_serial=7;
  lease_at(r,0,BV_LEASE_ACQUIRED,7,0,r->acquire);
}
static void rendered(Presentation* r) {
  acquired(r); r->leases[0].phase=BV_LEASE_RENDERED;
  r->semaphore->semaphore=(BvSemaphore){.phase=BV_SEM_SIGNALED,.producer=r->swapchain,.producer_serial=7};
}
static void associated(Presentation* r,unsigned j,BvLeasePhase phase,BvRow* fence,uint64_t serial) {
  lease_at(r,j,phase,serial,j,fence);
  fence->fence=(BvFence){.use=(phase==BV_LEASE_ACQUIRING || phase==BV_LEASE_ACQUIRE_UNCERTAIN) ? BV_FENCE_ACQUIRE : BV_FENCE_PRESENT,.lease=&r->leases[j],.serial=serial};
  if(fence->fence.use==BV_FENCE_PRESENT) {
    r->leases[j].semaphore=r->semaphore;
    r->semaphore->semaphore=(BvSemaphore){.phase=phase==BV_LEASE_PRESENTING ? BV_SEM_PRESENT_WAIT : BV_SEM_UNCERTAIN,.producer=r->swapchain,.producer_serial=serial};
  }
}
static void dispose(Presentation* r) { bv_free_refs(r->command->deps); r->command->deps=NULL; bv_rows=NULL; }
static BvDep* signal_edge(Presentation* r) {
  BvDep* dep=__CPROVER_allocate(sizeof(*dep),false);
  if(nondet_u32()&1) __CPROVER_memory_leak=dep;
  *dep=(BvDep){.target=r->semaphore,.role=BV_DEP_SUBMIT_SIGNAL};
  return dep;
}
// Successful end-recording boundary. proof_use/bv_prepare_refs allocation,
// identity and refusal are verified separately by the recording entry.
static void recorded(Presentation* r,BvLease* lease) {
  BvDep* dep=__CPROVER_allocate(sizeof(*dep),false);
  if(nondet_u32()&1) __CPROVER_memory_leak=dep;
  *dep=(BvDep){.target=r->swapchain,.role=BV_DEP_RECORDED};r->command->deps=dep;
  r->command->command=(BvCommand){.phase=BV_EXECUTABLE,.lease=lease,.lease_serial=lease->serial};
}

void verify_presentation_acquire_results(void) {
  Presentation r; presentation(&r);
  VkResult result=(VkResult)nondet_result(); uint32_t index=nondet_u32();
  uint64_t before=nondet_u64(); __CPROVER_assume(before<UINT64_MAX); r.device->lease_serial=before;
  bool older=(nondet_u32()&1)!=0,presenting=(nondet_u32()&1)!=0;
  if(older) lease_at(&r,1,presenting ? BV_LEASE_PRESENTING : BV_LEASE_ACQUIRED,before,0,r.present);
  Term status=proof_acquire(r.owner,r.swapchain,r.acquire,VK_NOT_READY,result,index);
  bool success=acquired_result(result),valid=index<2 && !(older && !presenting && index==0);
  bool held=success || !empty_acquire(result);
  __CPROVER_assert(proof_token_seen==(success && valid),"only_valid_acquisition_issues_a_token");
  if(success && valid) __CPROVER_assert(proof_token_key==r.swapchain->id && proof_token_serial==before+1 && proof_token_index==index && proof_token_suboptimal==(result==VK_SUBOPTIMAL_KHR),"issued_token_matches_native_lease_identity");
  __CPROVER_assert(r.device->lease_serial==before+1,"acquire_serial_is_monotonic_nonzero");
  __CPROVER_assert(r.leases[0].phase==(success ? (valid ? BV_LEASE_ACQUIRING : BV_LEASE_ACQUIRE_UNCERTAIN) : held ? BV_LEASE_ACQUIRE_UNCERTAIN : BV_LEASE_NONE),"acquire_classifies_every_result_and_index");
  __CPROVER_assert(r.acquire->fence.use==(held ? BV_FENCE_ACQUIRE : BV_FENCE_FREE) && r.acquire->fence.lease==(held ? &r.leases[0] : NULL),"acquire_retains_fence_exactly_when_completion_is_owned");
  if(held) __CPROVER_assert(r.leases[0].serial==before+1 && r.acquire->fence.serial==before+1 && r.leases[0].swapchain==r.swapchain,"acquire_has_one_serial_and_owner");
  if(success && !valid) __CPROVER_assert(status==BV_INVALID && bv_uncertain(r.owner),"invalid_image_quarantines_acquisition");
  __CPROVER_assert(r.device->health==(result==VK_ERROR_DEVICE_LOST ? BV_LOST : BV_HEALTHY),"acquire_propagates_device_loss");
}

// Qualification: actual production acquire -> observe -> release -> reacquire.
void verify_presentation_serial_sequence(void) {
  Presentation r; presentation(&r);
  uint64_t first=nondet_u64(); __CPROVER_assume(first<UINT64_MAX-1); r.device->lease_serial=first;
  proof_acquire(r.owner,r.swapchain,r.acquire,VK_NOT_READY,VK_SUCCESS,0);
  __CPROVER_assert(r.leases[0].serial==first+1 && r.leases[0].phase==BV_LEASE_ACQUIRING,"sequence_first_acquisition_is_distinct");
  proof_observe(r.acquire,VK_SUCCESS,1);
  __CPROVER_assert(r.leases[0].phase==BV_LEASE_ACQUIRED && r.acquire->fence.use==BV_FENCE_FREE,"sequence_acquisition_wait_completes_only_acquisition");
  proof_release(r.owner,&r.leases[0],VK_SUCCESS);
  proof_acquire(r.owner,r.swapchain,r.acquire,VK_NOT_READY,VK_SUCCESS,0);
  __CPROVER_assert(r.leases[0].serial==first+2 && proof_lookup(r.owner,4,first+1)==NULL,"stale_token_cannot_resolve_reused_slot");
  __CPROVER_assert(proof_lookup(r.owner,4,first+2)==&r.leases[0],"new_token_resolves_exact_lease");
}

void verify_presentation_serial_exhaustion(void) {
  Presentation r; presentation(&r); r.device->lease_serial=UINT64_MAX;
  __CPROVER_assert(proof_acquire(r.owner,r.swapchain,r.acquire,VK_NOT_READY,VK_SUCCESS,0)==BV_LIMIT,"serial_exhaustion_rejects_before_acquisition");
  __CPROVER_assert(r.leases[0].phase==BV_LEASE_NONE && r.acquire->fence.use==BV_FENCE_FREE && r.device->lease_serial==UINT64_MAX,"serial_exhaustion_preserves_ownership");
}

void verify_presentation_identity(void) {
  Presentation r; presentation(&r); acquired(&r);
  lease_at(&r,1,BV_LEASE_ACQUIRED,8,1,NULL);
  uint64_t serial=nondet_u64(); uint32_t key=nondet_u32();
  bool foreign=(nondet_u32()&1)!=0;
  BvLease* found=proof_lookup(foreign ? r.foreign : r.owner,key,serial);
  __CPROVER_assert(found==(!foreign && key==4 ? (serial==7 ? &r.leases[0] : serial==8 ? &r.leases[1] : NULL) : NULL),"lookup_requires_owner_key_and_full_serial");
  if(!found) {
    r.command->command.phase=BV_RECORDING;
    __CPROVER_assert(proof_use(r.command,found)==BV_INVALID && proof_release(r.owner,found,VK_SUCCESS)==BV_INVALID && proof_present(r.owner,found,r.semaphore,r.present,VK_NOT_READY,VK_SUCCESS)==BV_INVALID,"stale_token_cannot_record_release_or_present");
  }
  r.command->command.phase=BV_EXECUTABLE; r.command->command.lease=&r.leases[0]; r.command->command.lease_serial=6;
  __CPROVER_assert(proof_submit(r.owner,r.command,r.render,VK_NOT_READY,VK_SUCCESS)==BV_LIFETIME,"stale_recording_cannot_submit_later_acquisition");
  dispose(&r);
}

void verify_presentation_recording(void) {
  Presentation r; presentation(&r); acquired(&r); r.command->command.phase=BV_RECORDING;
  uint32_t mode=nondet_u32(); __CPROVER_assume(mode<4);
  if(mode==1) r.leases[0].phase=BV_LEASE_ACQUIRING;
  if(mode==2) {r.command->command.lease=&r.leases[1];r.command->command.lease_serial=8;}
  if(mode==3) {r.command->command.lease=&r.leases[0];r.command->command.lease_serial=6;}
  BvLease* before=r.command->command.lease; uint64_t serial=r.command->command.lease_serial;
  Term result=proof_use(r.command,&r.leases[0]);
  if(mode || result==BV_LIMIT) __CPROVER_assert(r.command->deps==NULL && r.command->command.lease==before && r.command->command.lease_serial==serial,"recording_refusal_or_allocation_failure_is_atomic");
  else __CPROVER_assert(result==0 && r.command->deps && r.command->deps->target==r.swapchain && r.command->command.lease==&r.leases[0] && r.command->command.lease_serial==7,"recording_retains_exact_acquisition");
  if(!mode && result==BV_LIMIT) {
    Term retry=proof_use(r.command,&r.leases[0]);
    __CPROVER_assert(retry==0 || retry==BV_LIMIT,"recording_allocation_failure_can_retry");
    if(retry==BV_LIMIT) __CPROVER_assert(r.command->deps==NULL && r.command->command.lease==before && r.command->command.lease_serial==serial,"repeated_allocation_failure_preserves_retryable_owner");
    else __CPROVER_assert(r.command->deps && r.command->deps->target==r.swapchain && r.command->command.lease==&r.leases[0] && r.command->command.lease_serial==7,"successful_recording_retry_has_original_identity");
  }
  dispose(&r);
}

void verify_presentation_borrowed_recording(void) {
  Presentation r; presentation(&r);acquired(&r);lease_at(&r,1,BV_LEASE_ACQUIRED,8,1,NULL);
  unsigned image=nondet_u32(),lease=nondet_u32();__CPROVER_assume(image<2 && lease<2);
  bool complete=(nondet_u32()&1)!=0;
  if(!complete) r.leases[image].phase=BV_LEASE_ACQUIRING;
  uint64_t serial=nondet_u64();
  r.command->command.phase=BV_RECORDING;r.command->command.lease=&r.leases[lease];r.command->command.lease_serial=serial;
  BvRow* resource=r.images[image];uint32_t result=bv_prepare_refs(r.command,1,&resource);
  bool valid=complete && image==lease && serial==7+lease;
  __CPROVER_assert(valid ? (result==0 || result==BV_LIMIT) : result==BV_LIFETIME,"borrowed_recording_requires_matching_completed_image_and_full_serial");
  if(result) __CPROVER_assert(r.command->deps==NULL && r.command->command.lease==&r.leases[lease] && r.command->command.lease_serial==serial,"borrowed_recording_refusal_preserves_ownership");
  else __CPROVER_assert(r.command->deps && r.command->deps->target==resource && r.command->command.lease==&r.leases[image],"borrowed_recording_retains_the_matching_image");
  dispose(&r);
}

void verify_presentation_submit_results(void) {
  Presentation r; presentation(&r); acquired(&r);
  r.command->command.phase=BV_EXECUTABLE; r.command->command.lease=&r.leases[0];r.command->command.lease_serial=7;
  VkResult result=(VkResult)nondet_result();
  proof_synced(r.owner,r.command,r.render,signal_edge(&r),VK_NOT_READY,result);
  bool held=result==VK_SUCCESS || (!oom(result) && result!=VK_ERROR_DEVICE_LOST);
  __CPROVER_assert(r.leases[0].phase==(result==VK_SUCCESS ? BV_LEASE_RENDERING : held ? BV_LEASE_RENDER_UNCERTAIN : BV_LEASE_ACQUIRED),"submission_retains_lease_for_pending_and_uncertain_work");
  __CPROVER_assert(r.semaphore->semaphore.phase==(result==VK_SUCCESS ? BV_SEM_SIGNAL_PENDING : held ? BV_SEM_UNCERTAIN : BV_SEM_UNUSED),"submission_retains_binary_signal_until_render_completion");
  if(held) __CPROVER_assert(r.semaphore->semaphore.producer==r.swapchain && r.semaphore->semaphore.producer_serial==7 && bv_command_fence(r.command)==r.render,"submission_signal_and_fence_have_exact_identity");
  if(oom(result)) {
    __CPROVER_assert(r.command->command.phase==BV_EXECUTABLE && r.command->deps==NULL,"submission_allocation_failure_is_retryable");
    proof_synced(r.owner,r.command,r.render,signal_edge(&r),VK_NOT_READY,VK_SUCCESS);
    __CPROVER_assert(r.command->command.phase==BV_PENDING && r.leases[0].phase==BV_LEASE_RENDERING,"submission_retry_preserves_acquisition");
  }
  dispose(&r);
}

void verify_presentation_uncertain_render_sequence(void) {
  Presentation r; presentation(&r);acquired(&r);
  recorded(&r,&r.leases[0]);
  VkResult result=(VkResult)nondet_result();__CPROVER_assume(result!=VK_SUCCESS && result!=VK_ERROR_DEVICE_LOST && !oom(result));
  proof_synced(r.owner,r.command,r.render,signal_edge(&r),VK_NOT_READY,result);
  __CPROVER_assert(proof_observe(r.render,VK_SUCCESS,1)==BV_LIFETIME && proof_reset_command(r.command,VK_SUCCESS)==BV_LIFETIME,"uncertain_render_requires_idle_and_retains_recording");
  __CPROVER_assert(proof_swapchain_destroy(r.owner,r.swapchain)==BV_LIFETIME,"uncertain_render_blocks_target_destruction");
  proof_idle(r.owner,VK_SUCCESS);
  __CPROVER_assert(r.leases[0].phase==BV_LEASE_ABANDONED && r.command->command.phase==BV_COMMAND_INVALID && r.semaphore->semaphore.phase==BV_SEM_QUARANTINED,"uncertain_render_completion_quarantines_signal_and_abandons_lease");
  __CPROVER_assert(r.command->deps && r.command->deps->target==r.swapchain && proof_swapchain_destroy(r.owner,r.swapchain)==BV_LIFETIME,"uncertain_render_completion_retains_recorded_ownership");
  dispose(&r);
}

void verify_presentation_fence_status(void) {
  Presentation r; presentation(&r);
  VkResult status=(VkResult)nondet_result();__CPROVER_assume(status!=VK_NOT_READY);
  Term acquired=proof_acquire(r.owner,r.swapchain,r.acquire,status,VK_SUCCESS,0);
  __CPROVER_assert(r.device->lease_serial==0 && r.leases[0].phase==BV_LEASE_NONE && r.acquire->fence.use==BV_FENCE_FREE,"acquire_requires_confirmed_unsignaled_fence");
  if(status==VK_SUCCESS) __CPROVER_assert(acquired==BV_LIFETIME,"signaled_acquisition_fence_is_rejected");
  presentation(&r); rendered(&r);
  Term presented=proof_present(r.owner,&r.leases[0],r.semaphore,r.present,status,VK_SUCCESS);
  __CPROVER_assert(r.leases[0].phase==BV_LEASE_RENDERED && r.semaphore->semaphore.phase==BV_SEM_SIGNALED && r.present->fence.use==BV_FENCE_FREE,"present_requires_confirmed_unsignaled_fence");
  if(status==VK_SUCCESS) __CPROVER_assert(presented==BV_LIFETIME,"signaled_presentation_fence_is_rejected");
}

void verify_presentation_frame_sequence(void) {
  Presentation r; presentation(&r);
  proof_acquire(r.owner,r.swapchain,r.acquire,VK_NOT_READY,VK_SUCCESS,0);
  __CPROVER_assert(proof_fence_reset(r.acquire)==BV_LIFETIME,"acquire_fence_cannot_reset_before_completion");
  proof_observe(r.acquire,VK_SUCCESS,1);
  recorded(&r,proof_lookup(r.owner,proof_token_key,proof_token_serial));
  proof_synced(r.owner,r.command,r.render,signal_edge(&r),VK_NOT_READY,VK_SUCCESS);
  __CPROVER_assert(proof_present(r.owner,&r.leases[0],r.semaphore,r.present,VK_NOT_READY,VK_SUCCESS)==BV_LIFETIME,"rendering_does_not_authorize_presentation");
  proof_observe(r.render,VK_SUCCESS,1);
  __CPROVER_assert(r.leases[0].phase==BV_LEASE_RENDERED && r.semaphore->semaphore.phase==BV_SEM_SIGNALED,"render_completion_preserves_image_and_signal");
  __CPROVER_assert(proof_swapchain_destroy(r.owner,r.swapchain)==BV_LIFETIME,"completed_rendering_still_retains_recorded_swapchain");
  proof_reset_command(r.command,VK_SUCCESS);
  __CPROVER_assert(r.leases[0].phase==BV_LEASE_RENDERED && r.semaphore->semaphore.phase==BV_SEM_SIGNALED,"command_reset_keeps_rendered_lease_and_signal");
  proof_present(r.owner,&r.leases[0],r.semaphore,r.present,VK_NOT_READY,VK_SUCCESS);
  proof_idle(r.owner,VK_SUCCESS);
  __CPROVER_assert(r.leases[0].phase==BV_LEASE_PRESENTING && r.semaphore->semaphore.phase==BV_SEM_PRESENT_WAIT && r.present->fence.use==BV_FENCE_PRESENT,"render_idle_does_not_complete_presentation");
  __CPROVER_assert(proof_fence_reset(r.present)==BV_LIFETIME && proof_fence_destroy(r.owner,r.present)==BV_LIFETIME,"presentation_fence_remains_owned_until_observed");
  __CPROVER_assert(proof_signal_guard(r.semaphore)==BV_LIFETIME && proof_semaphore_destroy(r.semaphore)==BV_LIFETIME,"presentation_wait_blocks_signal_reuse_and_destruction");
  proof_observe(r.present,VK_SUCCESS,1);
  __CPROVER_assert(r.leases[0].phase==BV_LEASE_NONE && r.present->fence.use==BV_FENCE_FREE && r.semaphore->semaphore.phase==BV_SEM_UNUSED,"only_presentation_completion_releases_lease_and_signal");
  proof_reset_command(r.command,VK_SUCCESS);
  __CPROVER_assert(proof_swapchain_destroy(r.owner,r.swapchain)==PROOF_DISPATCH,"reset_recorded_references_permits_target_destruction");
  dispose(&r);
}

void verify_presentation_present_results(void) {
  Presentation r; presentation(&r); rendered(&r);
  VkResult result=(VkResult)nondet_result();
  proof_present(r.owner,&r.leases[0],r.semaphore,r.present,VK_NOT_READY,result);
  bool retry=oom(result),lost=result==VK_ERROR_DEVICE_LOST,held=!retry && !lost;
  __CPROVER_assert(r.leases[0].phase==(held ? (present_result(result) ? BV_LEASE_PRESENTING : BV_LEASE_PRESENT_UNCERTAIN) : BV_LEASE_RENDERED),"present_classifies_every_result");
  __CPROVER_assert(r.semaphore->semaphore.phase==(held ? (present_result(result) ? BV_SEM_PRESENT_WAIT : BV_SEM_UNCERTAIN) : BV_SEM_SIGNALED),"present_preserves_or_retains_binary_semaphore");
  if(held) {
    __CPROVER_assert(r.present->fence.use==BV_FENCE_PRESENT && r.present->fence.lease==&r.leases[0] && r.present->fence.serial==7 && r.leases[0].fence==r.present && r.leases[0].semaphore==r.semaphore,"present_has_one_completion_owner");
    __CPROVER_assert(proof_swapchain_destroy(r.owner,r.swapchain)==BV_LIFETIME,"unresolved_presentation_blocks_resize");
  }
  if(retry) {
    __CPROVER_assert(r.present->fence.use==BV_FENCE_FREE && r.semaphore->semaphore.producer_serial==7,"present_allocation_failure_preserves_retry_identity");
    proof_present(r.owner,&r.leases[0],r.semaphore,r.present,VK_NOT_READY,VK_SUCCESS);
    __CPROVER_assert(r.leases[0].phase==BV_LEASE_PRESENTING,"present_allocation_failure_can_retry");
  }
  if(held && !present_result(result)) __CPROVER_assert(bv_uncertain(r.owner) && proof_signal_guard(r.semaphore)==BV_LIFETIME,"unknown_present_result_conservatively_blocks_reuse");
}

void verify_presentation_present_identity(void) {
  Presentation r; presentation(&r); rendered(&r);
  uint32_t mode=nondet_u32(); __CPROVER_assume(mode<7);
  switch(mode) {
    case 0:r.semaphore->semaphore.producer=r.foreign;break;
    case 1:r.semaphore->semaphore.producer_serial=6;break;
    case 2:r.semaphore->semaphore.phase=BV_SEM_SIGNAL_PENDING;break;
    case 3:r.present->fence.use=BV_FENCE_ACQUIRE;break;
    case 4:r.leases[0].phase=BV_LEASE_ACQUIRED;break;
    case 5:r.command->command.phase=BV_PENDING;r.command->command.submission.pending.fence=r.present;break;
    case 6:lease_at(&r,1,BV_LEASE_PRESENT_UNCERTAIN,8,1,r.acquire);break;
  }
  __CPROVER_assert(proof_present(r.owner,&r.leases[0],r.semaphore,r.present,VK_NOT_READY,VK_SUCCESS)==BV_LIFETIME,"present_requires_exact_rendered_lease_signal_and_free_fence");
}

void verify_presentation_observation(void) {
  Presentation r; presentation(&r);
  uint32_t mode=nondet_u32(); __CPROVER_assume(mode<4);
  BvLeasePhase phases[4]={BV_LEASE_ACQUIRING,BV_LEASE_ACQUIRE_UNCERTAIN,BV_LEASE_PRESENTING,BV_LEASE_PRESENT_UNCERTAIN};
  associated(&r,0,phases[mode],r.present,7);
  VkResult result=(VkResult)nondet_result(); int wait=(nondet_u32()&1)!=0;
  proof_observe(r.present,result,wait);
  if(result==VK_SUCCESS) {
    __CPROVER_assert(r.leases[0].phase==(mode==0 ? BV_LEASE_ACQUIRED : mode==1 ? BV_LEASE_ABANDONED : BV_LEASE_NONE),"wsi_observation_completes_only_matching_operation");
    __CPROVER_assert(r.present->fence.use==BV_FENCE_FREE && r.present->fence.lease==NULL && r.present->fence.serial==0,"completed_wsi_fence_disassociates_exactly_once");
    if(mode>=2) __CPROVER_assert(r.semaphore->semaphore.phase==BV_SEM_UNUSED,"present_observation_releases_binary_wait");
  } else __CPROVER_assert(r.leases[0].phase==phases[mode] && r.present->fence.lease==&r.leases[0] && r.present->fence.serial==7,"failed_or_incomplete_observation_retains_ownership");
}

void verify_presentation_stale_completion(void) {
  Presentation r; presentation(&r); associated(&r,0,BV_LEASE_PRESENTING,r.present,7);
  r.leases[0].serial=8; BvLease before=r.leases[0];
  bv_finish_wsi_fence(r.present);
  __CPROVER_assert(r.leases[0].phase==before.phase && r.leases[0].serial==8 && r.semaphore->semaphore.phase==BV_SEM_PRESENT_WAIT,"stale_wsi_fence_cannot_release_newer_lease_or_semaphore");
  r.command->command.lease=&r.leases[0]; r.command->command.lease_serial=7;r.command->command.phase=BV_PENDING;
  r.leases[0].phase=BV_LEASE_RENDERING;
  bv_complete(r.command);
  __CPROVER_assert(r.leases[0].phase==BV_LEASE_RENDERING,"stale_render_completion_cannot_complete_newer_lease");
}

void verify_presentation_reacquire_overlap(void) {
  Presentation r; presentation(&r); r.device->lease_serial=7;
  associated(&r,0,BV_LEASE_PRESENTING,r.present,7);
  proof_acquire(r.owner,r.swapchain,r.acquire,VK_NOT_READY,VK_SUCCESS,0);
  __CPROVER_assert(r.leases[1].phase==BV_LEASE_ACQUIRING && r.leases[1].serial==8 && bv_image_lease(r.image)==&r.leases[1],"reacquired_image_resolves_new_lease_during_old_presentation");
  proof_observe(r.acquire,VK_SUCCESS,1);
  proof_observe(r.present,VK_SUCCESS,1);
  __CPROVER_assert(r.leases[1].phase==BV_LEASE_ACQUIRED && r.leases[1].serial==8 && proof_lookup(r.owner,4,8)==&r.leases[1] && proof_lookup(r.owner,4,7)==NULL,"old_presentation_completion_preserves_reacquired_image");
}

void verify_presentation_release_results(void) {
  Presentation r; presentation(&r); acquired(&r);
  uint32_t phase=nondet_u32();__CPROVER_assume(phase<=BV_LEASE_ABANDONED);r.leases[0].phase=(BvLeasePhase)phase;
  VkResult result=(VkResult)nondet_result(); bool valid=phase==BV_LEASE_ACQUIRED || phase==BV_LEASE_RENDERED;
  Term status=proof_release(r.owner,&r.leases[0],result);
  __CPROVER_assert(r.leases[0].phase==(valid && result==VK_SUCCESS ? BV_LEASE_NONE : phase),"release_clears_lease_only_after_completed_success");
  if(!valid) __CPROVER_assert(status==BV_LIFETIME && r.device->health==BV_HEALTHY,"release_rejects_unresolved_operation_before_dispatch");
  if(valid && result!=VK_SUCCESS) __CPROVER_assert(r.leases[0].serial==7 && r.leases[0].swapchain==r.swapchain,"release_failure_preserves_retryable_owner");
}

void verify_presentation_reuse_guards(void) {
  Presentation r; presentation(&r);
  uint32_t mode=nondet_u32(); __CPROVER_assume(mode<6);
  if(mode<4) {
    BvLeasePhase phases[4]={BV_LEASE_ACQUIRING,BV_LEASE_PRESENTING,BV_LEASE_ACQUIRE_UNCERTAIN,BV_LEASE_PRESENT_UNCERTAIN};
    associated(&r,0,phases[mode],r.acquire,7);
  } else {
    acquired(&r);r.command->command.phase=mode==4 ? BV_PENDING : BV_UNCERTAIN;
    r.command->command.submission.pending.fence=r.acquire;
  }
  __CPROVER_assert(proof_fence_reset(r.acquire)==BV_LIFETIME && proof_fence_destroy(r.owner,r.acquire)==BV_LIFETIME,"every_active_fence_blocks_reset_and_destruction");
  __CPROVER_assert(proof_acquire(r.owner,r.swapchain,r.acquire,VK_NOT_READY,VK_SUCCESS,1)==BV_LIFETIME,"active_or_uncertain_ownership_blocks_acquire_reuse");
  uint32_t sem=nondet_u32();__CPROVER_assume(sem<=BV_SEM_QUARANTINED);r.semaphore->semaphore.phase=(BvSemaphorePhase)sem;
  __CPROVER_assert((proof_signal_guard(r.semaphore)==PROOF_DISPATCH)==(sem==BV_SEM_UNUSED),"binary_signal_reuse_requires_unused_state");
}

void verify_presentation_resize_guards(void) {
  Presentation r; presentation(&r);
  uint32_t phase=nondet_u32();__CPROVER_assume(phase<=BV_LEASE_ABANDONED);
  lease_at(&r,0,(BvLeasePhase)phase,7,0,r.acquire);
  bool lost=(nondet_u32()&1)!=0;r.device->health=lost ? BV_LOST : BV_HEALTHY;
  bool completed=phase==BV_LEASE_NONE || phase==BV_LEASE_ACQUIRED || phase==BV_LEASE_RENDERED || phase==BV_LEASE_ABANDONED;
  __CPROVER_assert((proof_swapchain_destroy(r.owner,r.swapchain)==PROOF_DISPATCH)==(lost || completed),"resize_refuses_unresolved_completion_except_terminal_device_loss");
  // A completed lease is still retained by either a view/image dependency or
  // the command's direct acquisition reference until that owner is reset.
  r.leases[0].phase=BV_LEASE_NONE;
  BvDep reference={.target=r.swapchain,.role=BV_DEP_RECORDED};
  BvDep viewed={.target=r.image,.role=BV_DEP_VIEW_IMAGE};
  BvRow view={.kind=BV_IMAGE_VIEW,.parent=r.owner,.deps=&viewed,.next=bv_rows};
  if(nondet_u32()&1) bv_rows=&view; else r.command->deps=&reference;
  __CPROVER_assert(proof_swapchain_destroy(r.owner,r.swapchain)==BV_LIFETIME,"resize_retains_recorded_image_and_acquisition_references");
  r.command->deps=NULL;bv_rows=NULL;
}

void verify_presentation_drain_sequence(void) {
  Presentation r; presentation(&r);
  associated(&r,0,BV_LEASE_ACQUIRING,r.acquire,7);
  associated(&r,1,BV_LEASE_PRESENTING,r.present,8);
  VkResult results[2]={(VkResult)nondet_result(),(VkResult)nondet_result()};
  VkResult status=proof_drain(r.owner,results);
  VkResult expected=results[0]!=VK_SUCCESS ? results[0] : results[1];
  __CPROVER_assert(status==expected,"drain_preserves_first_unresolved_completion");
  __CPROVER_assert(r.leases[0].phase==(results[0]==VK_SUCCESS ? BV_LEASE_ACQUIRED : BV_LEASE_ACQUIRING),"drain_observes_acquisition_before_releasing_its_fence");
  __CPROVER_assert(r.leases[1].phase==(expected==VK_SUCCESS ? BV_LEASE_NONE : BV_LEASE_PRESENTING),"drain_retains_later_presentation_after_either_failure");
  if(status!=VK_SUCCESS && status!=VK_ERROR_DEVICE_LOST) {
    VkResult retry[2]={VK_SUCCESS,VK_SUCCESS};
    __CPROVER_assert(proof_drain(r.owner,retry)==VK_SUCCESS && r.leases[1].phase==BV_LEASE_NONE,"failed_drain_retains_retryable_completion_owners");
  }
}

void verify_presentation_close_sequence(void) {
  Presentation r; presentation(&r); acquired(&r);
  r.command->command.lease=&r.leases[0];r.command->command.lease_serial=7;
  r.command->command.phase=BV_PENDING;r.command->command.submission.pending.fence=r.render;r.leases[0].phase=BV_LEASE_RENDERING;
  associated(&r,1,BV_LEASE_PRESENTING,r.present,8);
  VkResult render=(VkResult)nondet_result(),results[2]={VK_SUCCESS,(VkResult)nondet_result()};
  proof_close(r.owner,render,results);
  bool permit=render==VK_ERROR_DEVICE_LOST || (render==VK_SUCCESS && (results[1]==VK_SUCCESS || results[1]==VK_ERROR_DEVICE_LOST));
  __CPROVER_assert(proof_close_destroy_reached==permit,"close_requires_render_and_presentation_completion_or_terminal_loss");
  if(!permit) {
    __CPROVER_assert(r.leases[1].phase==BV_LEASE_PRESENTING && r.present->fence.lease==&r.leases[1] && r.semaphore->semaphore.phase==BV_SEM_PRESENT_WAIT,"failed_close_retains_presentation_objects");
    VkResult retry[2]={VK_SUCCESS,VK_SUCCESS};
    proof_close(r.owner,VK_SUCCESS,retry);
    __CPROVER_assert(proof_close_destroy_reached && r.leases[1].phase==BV_LEASE_NONE,"failed_close_can_retry_both_completion_domains");
  }
}

void verify_presentation_broken_association(void) {
  Presentation r; presentation(&r);associated(&r,0,BV_LEASE_PRESENT_UNCERTAIN,r.present,7);
  if(nondet_u32()&1) r.present->fence.serial=6; else r.leases[0].fence=NULL;
  VkResult success[2]={VK_SUCCESS,VK_SUCCESS};
  VkResult drained=proof_drain(r.owner,success);proof_close(r.owner,VK_SUCCESS,success);
  __CPROVER_assert(drained==VK_NOT_READY && !proof_close_destroy_reached,"missing_or_stale_completion_owner_prevents_close");
  __CPROVER_assert(r.leases[0].phase==BV_LEASE_PRESENT_UNCERTAIN && r.semaphore->semaphore.phase==BV_SEM_UNCERTAIN,"unresolved_association_retains_uncertain_objects");
}
