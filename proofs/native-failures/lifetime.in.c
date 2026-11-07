// Complete helpers and contiguous control/metadata statements from native.c.
// @types
#undef bv_remove
// @function|static BvRow* bv_get(
// @function|static void bv_remove(
// @function|static BvRow* bv_command_device(
// @function|static BvRow* bv_command_fence(
// @function|static BvLease* bv_image_lease(
// @function|static void bv_complete(
// @function|static VkResult bv_device_result(
// @function|static int bv_lost(
// @function|static BvDep* bv_dependency(
// @function|static BvRow* bv_bound_memory(
// @function|static uint64_t bv_bound_offset(
// @function|static int bv_may_reach_depth(
// @function|static int bv_memory_busy(
// @function|static int bv_referenced(
// @function|static void bv_free_refs(
// @function|static int bv_sealed(
// @function|static uint32_t bv_prepare_refs(
// @line|typedef struct { BvRow* buffer; BvRow* memory; } BvRetirement;
// @function|static uint32_t bv_validate_retirement(

// Begin after list decoding and allocation of the staging array. A prior staging
// error is symbolic. No list decoder or allocator is reimplemented here.
static Term proof_retire(BvRow* owner,BvRetirement* items,size_t count,uint32_t code) {
  Env e=0; BvRetirement* local=items;
// @section|static Term bv_retire_buffers(|  for (size_t j=0;!code|  if (items!=local)
// @tail|static Term bv_retire_buffers(|  if (items!=local) free(items);

static Term proof_reset(BvRow* command,VkResult returned) {
  Env e=0; BvRow* owner=bv_command_device(command);
  VkResult result=bv_device_result(owner,returned);
// @tail|static Term bv_reset_command_buffer(|  VkResult result=bv_device_result(owner,device->ResetCommandBuffer((VkCommandBuffer)(uintptr_t)command->handle,0));

static Term proof_memory_destroy_guard(BvRow* memory) {
  Env e=0;
// @section|static Term bv_free_memory(|  if (memory->retired|  BvDevice* device=
  __CPROVER_assert(0,"retained_memory_must_not_reach_destruction");return 0;
}
static Term proof_image_destroy_guard(BvRow* image) {
  Env e=0;
// @section|static Term bv_destroy_image(|  if (image->object.image.storage|  BvDevice* device=
  __CPROVER_assert(0,"retained_image_must_not_reach_destruction");return 0;
}
static Term proof_view_destroy_guard(BvRow* view) {
  Env e=0;
// @section|static Term bv_destroy_image_view(|  if (bv_referenced(view))|  BvDevice* device=
  __CPROVER_assert(0,"retained_view_must_not_reach_destruction");return 0;
}
static Term proof_sampler_destroy_guard(BvRow* row) {
  Env e=0;
// @section|static Term bv_destroy_descriptor_resource(|  if(bv_referenced(row))|  BvDevice* d=
  __CPROVER_assert(0,"retained_sampler_must_not_reach_destruction");return 0;
}

// Observations at opaque void-driver boundaries. No Vulkan function is invoked
// or replaced. Only private registry metadata is modeled across these calls.
static uint32_t proof_destroyed,proof_freed;
static uint32_t proof_buffer_ids[2],proof_memory_ids[2];
static bool proof_retained[2];
static void proof_destroy_boundary(BvRow* owner,BvRow* row,BvRow* memory) {
  __CPROVER_assert(row->parent==owner,"collection_preserves_foreign_allocations");
  __CPROVER_assert(row->kind==BV_BUFFER && row->retired,"collection_preserves_unretired_allocations");
  bool retained=false;
  for(unsigned j=0;j<2;j++) if(row->id==proof_buffer_ids[j]) retained|=proof_retained[j];
  __CPROVER_assert(!retained,"collection_preserves_retained_allocations");
  __CPROVER_assert(memory && memory->kind==BV_MEMORY && memory->parent==owner && memory->retired,"collection_uses_paired_retired_memory");
  __CPROVER_assert(row->id<32 && !(proof_destroyed&(1u<<row->id)),"collection_destroys_each_buffer_once");
  proof_destroyed|=1u<<row->id;
}
static void proof_free_boundary(BvRow* owner,BvRow* memory) {
  bool released=false;
  for(unsigned j=0;j<2;j++) if(memory->id==proof_memory_ids[j]) {
    released=(proof_destroyed&(1u<<proof_buffer_ids[j]))!=0;
    __CPROVER_assert(bv_get(proof_buffer_ids[j],BV_BUFFER)==NULL,"collection_frees_only_unreferenced_memory_after_buffer");
  }
  __CPROVER_assert(memory->parent==owner && released,"collection_frees_only_unreferenced_memory_after_buffer");
  __CPROVER_assert(memory->id<32 && !(proof_freed&(1u<<memory->id)),"collection_frees_each_memory_once");
  proof_freed|=1u<<memory->id;
}

static Term proof_collect(BvRow* owner) {
  Env e=0;
// @section|static Term bv_collect_retired(|  if (!owner)|    device->DestroyBuffer(
  proof_destroy_boundary(owner,row,memory);
// @boundary|static Term bv_collect_retired(|    device->DestroyBuffer(device->handle,(VkBuffer)(uintptr_t)row->handle,NULL);
// @section|static Term bv_collect_retired(|    bv_remove(row);|    device->FreeMemory(
  proof_free_boundary(owner,memory);
// @boundary|static Term bv_collect_retired(|    device->FreeMemory(device->handle,(VkDeviceMemory)(uintptr_t)memory->handle,NULL);
// @tail|static Term bv_collect_retired(|    device->FreeMemory(device->handle,(VkDeviceMemory)(uintptr_t)memory->handle,NULL);
