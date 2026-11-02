import Base
import ../deps/bendvy/examples/scheduled-health/main.bend as ECS
import ../deps/bend-vulkan/examples/buffer_roundtrip.bend as GPU
import ../deps/bend-vulkan/Vulkan.bend as V

def clean(live: U32) -> IO(Unit):
  match live:
    case 0: IO.print("Bendvy + Vulkan native compatibility verified; live Vulkan objects: 0")
    case _: IO.die(Unit,1,"Vulkan objects remain after compatibility run")

def main() -> IO(Unit):
  do IO<Unit>:
    ECS.main()
    GPU.main()
    result : V.VkResult(U32) <- V.debug_live_objects()
    live : U32 <- V.or_exit(U32,result)
    clean(live)
