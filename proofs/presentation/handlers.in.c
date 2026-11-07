// Only validated arguments and real Vulkan effect results are supplied here.
// All ownership transitions and guards below are extracted from production.
#define CID(name) 0
#define term_pak(tag,value) ((uint32_t)(tag))
// Observe numeric fields at the actual acquired-outcome constructor boundary.
// Bend heap allocation/tags remain projected out; no lease transition lives here.
static bool proof_token_seen;
static uint32_t proof_token_key,proof_token_index,proof_token_suboptimal;
static uint64_t proof_token_serial;
static Term proof_acquired_token(uint32_t count,const Term* fields) {
  __CPROVER_assert(count==5,"acquired_payload_matches_binding_width");
  proof_token_seen=true;proof_token_key=fields[0];
  proof_token_serial=((uint64_t)fields[2]<<32)|fields[1];
  proof_token_index=fields[3];proof_token_suboptimal=fields[4];
  return 0;
}
#define bv_node(e,tag,count,fields) proof_acquired_token(count,fields)
#define PROOF_DISPATCH UINT32_C(0x70000001)
// @types
// @function|static BvRow* bv_get(
// @function|static BvRow* bv_child(
// @function|static BvRow* bv_command_device(
// @function|static int bv_outside(
// @function|static BvRow* bv_command_fence(
// @function|static BvRow* bv_active(
// @function|static int bv_uncertain(
// @function|static BvLease* bv_image_lease(
// @function|static void bv_finish_wsi_fence(
// @function|static void bv_complete(
// @function|static VkResult bv_device_result(
// @function|static Term bv_device_error(
// @function|static int bv_lost(
// @function|static BvDep* bv_dependency(
// @function|static BvRow* bv_bound_memory(
// @function|static int bv_image_available(
// @function|static int bv_may_reach_depth(
// @function|static int bv_referenced(
// @function|static void bv_free_refs(
// @function|static int bv_sealed(
// @function|static uint32_t bv_prepare_refs(
// @function|static BvRow* bv_set_pool(
static int bv_baseline_stages(BvDevice* device,VkPipelineStageFlags stages);

static BvLease* proof_lookup(BvRow* owner,uint32_t key,uint64_t serial) {
  Env e=0; Term fields[3]={key,(uint32_t)serial,(uint32_t)(serial>>32)};
// @tail|static BvLease* bv_acquisition(|  Term fields[3];bv_unpack(e,value,3,fields);

static Term proof_acquire(BvRow* owner,BvRow* row,BvRow* fence,VkResult status,VkResult returned,uint32_t index) {
  Env e=0;
// @section|static Term bv_acquire(|  BvDevice* device=|  VkResult result=device->GetFenceStatus(
// @boundary|static Term bv_acquire(|  VkResult result=device->GetFenceStatus(device->handle,(VkFence)(uintptr_t)fence->handle);
  VkResult result=status;
// @section|static Term bv_acquire(|  if(result!=VK_NOT_READY)|  uint32_t index=0;result=
// @boundary|static Term bv_acquire(|  uint32_t index=0;result=bv_device_result(owner,device->AcquireNextImageKHR(device->handle,(VkSwapchainKHR)(uintptr_t)row->handle,timeout,VK_NULL_HANDLE,(VkFence)(uintptr_t)fence->handle,&index));
  result=bv_device_result(owner,returned);
// @tail|static Term bv_acquire(|  uint32_t index=0;result=bv_device_result(owner,device->AcquireNextImageKHR(device->handle,(VkSwapchainKHR)(uintptr_t)row->handle,timeout,VK_NULL_HANDLE,(VkFence)(uintptr_t)fence->handle,&index));

static Term proof_use(BvRow* command,BvLease* lease) {
  Env e=0; BvRow* owner=bv_command_device(command);
// @tail|static Term bv_use_acquisition(|  BvRow* command=bv_get(bv_key(e,f[0]),BV_COMMAND),*owner=bv_command_device(command);BvLease* lease=bv_acquisition(e,f[1],owner);

static Term proof_submit(BvRow* owner,BvRow* command,BvRow* fence,VkResult status,VkResult returned) {
  Env e=0;
// @section|static Term bv_submit_core_impl(|  if (bv_lost(owner))|  VkResult result=bv_device_result(owner,device->GetFenceStatus(
// @boundary|static Term bv_submit_core_impl(|  VkResult result=bv_device_result(owner,device->GetFenceStatus(device->handle,(VkFence)(uintptr_t)fence->handle));
  VkResult result=bv_device_result(owner,status);
// @section|static Term bv_submit_core_impl(|  if (result==VK_SUCCESS) return|  VkCommandBuffer handle=
  result=bv_device_result(owner,returned);
// @tail|static Term bv_submit_core_impl(|  result=bv_device_result(owner,device->QueueSubmit(device->queue,1,synced ? synced : &submit,(VkFence)(uintptr_t)fence->handle));

static Term proof_synced(BvRow* owner,BvRow* command,BvRow* fence,BvDep* staged,VkResult status,VkResult returned) {
  BvCommandPhase before=command->command.phase;
  Term result=proof_submit(owner,command,fence,status,returned);
// @tail|static Term bv_submit_synced(|  Term result=bv_submit_core_impl(e,owner,command,fence,&submit);

static Term proof_observe(BvRow* fence,VkResult returned,int wait) {
  Env e=0;
// @section|static Term bv_fence_observe(|  BvRow* owner=|  VkFence handle=
  VkResult result=bv_device_result(owner,returned);
// @tail|static Term bv_fence_observe(|  VkResult result=bv_device_result(owner,wait ? device->WaitForFences(device->handle,1,&handle,VK_TRUE,timeout) : device->GetFenceStatus(device->handle,handle));

static Term proof_present(BvRow* owner,BvLease* lease,BvRow* semaphore,BvRow* fence,VkResult status,VkResult returned) {
  Env e=0;
// @section|static Term bv_present(|  if(!owner|  VkFence signal=
// @boundary|static Term bv_present(|  VkFence signal=(VkFence)(uintptr_t)fence->handle;VkResult result=device->GetFenceStatus(device->handle,signal);
  VkResult result=status;
// @section|static Term bv_present(|  if(result!=VK_NOT_READY)|  VkSwapchainKHR handle=
  result=bv_device_result(owner,returned);
// @tail|static Term bv_present(|  result=bv_device_result(owner,device->QueuePresentKHR(device->present_queue,&present));

static Term proof_release(BvRow* owner,BvLease* lease,VkResult returned) {
  Env e=0;
// @section|static Term bv_release_acquired(|  if(!owner|  VkReleaseSwapchainImagesInfoEXT release=
  VkResult result=bv_device_result(owner,returned);
// @tail|static Term bv_release_acquired(|  VkResult result=bv_device_result(owner,device->ReleaseSwapchainImagesEXT(device->handle,&release));

static Term proof_fence_reset(BvRow* fence) {
  Env e=0; BvRow* owner=fence->parent;
// @section|static Term bv_reset_fence_core(|  if (bv_lost(owner))|  VkFence handle=
  return PROOF_DISPATCH;
}
static Term proof_reset_command(BvRow* command,VkResult returned) {
  Env e=0; BvRow* owner=bv_command_device(command);
// @section|static Term bv_reset_command_buffer(|  if (bv_lost(owner))|  VkResult result=
  VkResult result=bv_device_result(owner,returned);
// @tail|static Term bv_reset_command_buffer(|  VkResult result=bv_device_result(owner,device->ResetCommandBuffer((VkCommandBuffer)(uintptr_t)command->handle,0));
static Term proof_fence_destroy(BvRow* owner,BvRow* fence) {
  Env e=0;
// @section|static Term bv_destroy_fence(|  if (bv_active(owner,fence)|  BvDevice* device=
  return PROOF_DISPATCH;
}
static Term proof_semaphore_destroy(BvRow* row) {
  Env e=0;
// @section|static Term bv_destroy_semaphore(|  if((row->semaphore.phase|  BvDevice* device=
  return PROOF_DISPATCH;
}
static Term proof_signal_guard(BvRow* semaphore) {
  uint32_t list_index=1,mask=0,code=0; BvDevice* device=NULL;
  do {
// @section|static Term bv_submit_synced(|      if((!list_index && (semaphore->semaphore.phase|      BvDep* dep=malloc(
  } while(0);
  return code ? code : PROOF_DISPATCH;
}
static Term proof_swapchain_destroy(BvRow* owner,BvRow* row) {
  Env e=0;
// @section|static Term bv_destroy_swapchain(|  BvDevice* device=|  bv_swapchain_remove(row);
  return PROOF_DISPATCH;
}
static VkResult proof_idle(BvRow* owner,VkResult returned) {
// @section|static VkResult bv_idle(|  if (bv_lost(owner))|  VkResult result=bv_device_result(
  VkResult result=bv_device_result(owner,returned);
// @tail|static VkResult bv_idle(|  VkResult result=bv_device_result(owner,device->DeviceWaitIdle(device->handle));

static VkResult proof_drain(BvRow* owner,VkResult results[2]) {
// @section|static VkResult bv_drain_presentation(BvRow* owner) {|  BvDevice* device=|      VkResult result=bv_device_result(
  VkResult result=bv_device_result(owner,results[j]);
// @tail|static VkResult bv_drain_presentation(BvRow* owner) {|      VkResult result=bv_device_result(owner,device->WaitForFences(device->handle,1,&handle,VK_TRUE,UINT64_C(1000000000)));

#define bv_idle(owner) proof_idle(owner,render)
#define bv_drain_presentation(owner) proof_drain(owner,presentation)
static bool proof_close_destroy_reached;
static Term proof_close(BvRow* found,VkResult render,VkResult presentation[2]) {
  Env e=0; VkResult first=VK_SUCCESS;
  proof_close_destroy_reached=false;
// @section|static Term bv_entry_close(|    VkResult result =|    bv_destroy_device(found);
  proof_close_destroy_reached=true;
  return PROOF_DISPATCH;
}
