// CBMC's entry point is the return boundary of a real driver call.
// No Vulkan function is substituted, dispatched, or executed by this proof.
#define VK_NO_PROTOTYPES
#include <vulkan/vulkan.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

typedef uint32_t Term;
typedef unsigned Env;

// Project out the native error code; Bend term allocation and strings are
// outside this state/ownership proof and retain their runtime checks.
#define bv_vk_error(e,result,operation) ((uint32_t)(int32_t)(result))
#define bv_ok(e) UINT32_C(0)
#define io_fail(e,result,message) ((uint32_t)(result))
#define io_done(e,result) ((uint32_t)(result))
#define bv_remove(row) __CPROVER_assert(0, "failure_must_not_remove_registry_rows")
#define bv_descriptor_pool_clear(pool) __CPROVER_assert(0, "failure_must_not_clear_descriptor_pool")

extern int32_t nondet_result(void);
extern uint32_t nondet_u32(void);
extern uint64_t nondet_u64(void);

