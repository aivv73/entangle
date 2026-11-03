import Base
import ../deps/bend-vulkan/Vulkan.bend as V

def with(-A:Type,body:V.Entry -> V.Action(A)) -> IO(V.VkResult(A) & U32):
  do IO<V.VkResult(A) & U32>:
    result:V.VkResult(A) <- V.Entry.with(A,body)
    live:V.VkResult(U32) <- V.debug_live_objects()
    count:U32 <- V.or_exit(U32,live)
    return (result,count)
