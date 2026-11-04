// Extraction directives copy production statements verbatim, on every run.
// Wrappers bind validated objects at a driver-return or guard boundary.
// @types
// @function|static BvRow* bv_command_device(
// @function|static BvRow* bv_command_fence(
// @function|static BvRow* bv_active(
// @function|static int bv_uncertain(
// @function|static void bv_complete(
// @function|static VkResult bv_device_result(
// @function|static Term bv_device_error(
// @function|static int bv_lost(
// @function|static BvDep* bv_dependency(
// @function|static BvRow* bv_set_pool(
// @function|static BvRow* bv_set_layout(
// @function|static void bv_free_refs(
// @function|static int bv_referenced(

static Term proof_reset(BvRow* command, VkResult returned) {
  Env e=0; BvRow* owner=bv_command_device(command);
  VkResult result=bv_device_result(owner,returned);
// @tail|static Term bv_reset_command_buffer(|  VkResult result=bv_device_result(owner,device->ResetCommandBuffer((VkCommandBuffer)(uintptr_t)command->handle,0));

static Term proof_begin(BvRow* command, VkResult result) {
  Env e=0;
// @tail|static Term bv_begin_command_buffer(|  VkResult result=device->BeginCommandBuffer((VkCommandBuffer)(uintptr_t)command->handle,&info);

static Term proof_end(BvRow* command, VkResult result) {
  Env e=0;
// @tail|static Term bv_end_command_buffer(|  VkResult result=device->EndCommandBuffer((VkCommandBuffer)(uintptr_t)command->handle);

static Term proof_submit(BvRow* owner,BvRow* command,BvRow* fence,VkResult returned) {
  Env e=0; BvLease* lease=command->command.lease;
  VkResult result=bv_device_result(owner,returned);
// @tail|static Term bv_submit_core_impl(|  result=bv_device_result(owner,device->QueueSubmit(device->queue,1,synced ? synced : &submit,(VkFence)(uintptr_t)fence->handle));

static Term proof_synced(BvRow* owner,BvRow* command,BvRow* fence,BvDep* staged,VkResult returned) {
  BvCommandPhase before=command->command.phase;
  Term result=proof_submit(owner,command,fence,returned);
// @tail|static Term bv_submit_synced(|  Term result=bv_submit_core_impl(e,owner,command,fence,&submit);

static Term proof_fence_reset(BvRow* owner,VkResult returned) {
  Env e=0; VkResult result=bv_device_result(owner,returned);
// @tail|static Term bv_reset_fence_core(|  VkResult result=bv_device_result(owner,device->ResetFences(device->handle,1,&handle));

static Term proof_free_set(BvRow* owner,BvRow* set,VkResult result) {
  Env e=0; BvRow* pool=bv_set_pool(set); BvDescriptorPool* p=&pool->object.descriptor_pool;
// @tail|static Term bv_free_descriptor_set(|  VkResult result=d->FreeDescriptorSets(d->handle,(VkDescriptorPool)(uintptr_t)pool->handle,1,&handle);

static Term proof_reset_descriptor_pool(BvRow* owner,BvRow* pool,VkResult result) {
  Env e=0;
// @section|static Term bv_descriptor_pool_operation(|    if(result!=VK_SUCCESS)|  } else
  return bv_ok(e);
}

static VkResult proof_idle(BvRow* owner,VkResult returned) {
  VkResult result=bv_device_result(owner,returned);
// @tail|static VkResult bv_idle(|  VkResult result=bv_device_result(owner,device->DeviceWaitIdle(device->handle));

static Term proof_reset_guard(BvRow* owner,BvRow* command) {
  Env e=0;
// @section|static Term bv_reset_command_buffer(|  if (bv_lost(owner))|  VkResult result=
  __CPROVER_assert(0,"active_or_lost_command_must_not_reach_reset_dispatch"); return 0;
}

static Term proof_fence_reset_guard(BvRow* owner,BvRow* fence) {
  Env e=0;
// @section|static Term bv_reset_fence_core(|  if (bv_lost(owner))|  VkFence handle=
  __CPROVER_assert(0,"active_or_lost_fence_must_not_reach_reset_dispatch"); return 0;
}

static Term proof_fence_observe_guard(BvRow* owner,BvRow* fence) {
  Env e=0;
// @section|static Term bv_fence_observe(|  if (bv_lost(owner))|  VkFence handle=
  __CPROVER_assert(0,"uncertain_or_lost_fence_must_not_reach_observation_dispatch"); return 0;
}

static Term proof_pool_destroy_guard(BvRow* pool) {
  Env e=0;
// @section|static Term bv_destroy_command_pool(|  for (BvRow* row=bv_rows;|  bv_destroy_pool(
  __CPROVER_assert(0,"active_pool_must_not_reach_destruction"); return 0;
}

static Term proof_fence_destroy_guard(BvRow* owner,BvRow* fence) {
  Env e=0;
// @section|static Term bv_destroy_fence(|  if (bv_active(owner,fence)|  BvDevice* device=
  __CPROVER_assert(0,"active_fence_must_not_reach_destruction"); return 0;
}

// Start after the sealed-resource guard. All other arguments were validated.
static Term proof_submit_guard(BvRow* owner,BvRow* command,BvRow* fence) {
  Env e=0;
// @section|static Term bv_submit_core_impl(|  if (command->command.phase!=BV_EXECUTABLE|  BvDevice* device=
  __CPROVER_assert(0,"uncertain_owner_must_not_reach_submit_dispatch"); return 0;
}

static Term proof_entry_cleanup_guard(VkResult result) {
  Env e=0; VkResult first=VK_SUCCESS;
// @section|static Term bv_entry_close(|    if (result != VK_SUCCESS|    bv_destroy_device(found);
  __CPROVER_assert(0,"failed_completion_must_not_reach_device_destruction"); return 0;
}

static Term proof_descriptor_reset_guard(BvRow* owner,BvRow* pool) {
  Env e=0;
// @section|static Term bv_descriptor_pool_operation(|    if(bv_lost(owner))|    VkResult result=
  __CPROVER_assert(0,"quarantined_pool_must_not_reach_reset_dispatch"); return 0;
}

static Term proof_descriptor_free_guard(BvRow* pool,BvRow* set) {
  Env e=0; BvDescriptorPool* p=&pool->object.descriptor_pool;
// @section|static Term bv_free_descriptor_set(|  if(p->phase!=BV_POOL_READY|  BvDevice* d=
  __CPROVER_assert(0,"quarantined_pool_must_not_reach_free_dispatch"); return 0;
}

static Term proof_descriptor_submit_guard(BvRow* command) {
  Env e=0;
// @section|static Term bv_submit_core_impl(|  for(BvDep* dep=command->deps;|  BvLease* lease=
  __CPROVER_assert(0,"quarantined_pool_must_not_reach_submit_dispatch"); return 0;
}
