import Base
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/core.bend as Core

# Engine-owned Bend 2.0.40 event boundary over the pinned Vulkan registry.
# Generated native code preserves upstream window ownership and dispatch.
def open_raw(entry: V.Entry, title: String, width: U32, height: U32) -> IO(V.VkResult(U32)):
  import "./vulkan-window.c"
  import "./vulkan-window.js"

type Snapshot is Type:
  Snapshot{width:U32,height:U32,mapped:Bool,focused:Bool,captured:Bool,events:List<Event>}

def poll_raw(window: V.NativeWindow, timeout_ms: U32) -> IO(V.VkResult(Snapshot)):
  import "./vulkan-window.c"
  import "./vulkan-window.js"

def close_window(window: V.NativeWindow) -> IO(V.VkResult(Unit)):
  import "./vulkan-window.c"
  import "./vulkan-window.js"

def capture(window: V.NativeWindow, enabled: Bool) -> IO(V.VkResult(Bool)):
  import "./vulkan-window.c"
  import "./vulkan-window.js"

def surface_raw(instance: V.Instance, window: V.NativeWindow) -> IO(V.VkResult(U32)):
  import "./vulkan-window.c"
  import "./vulkan-window.js"

def open_window(entry:V.Entry,title:String,width:U32,height:U32) -> V.Action(V.NativeWindow):
  do V.Action<V.NativeWindow>:
    key:U32 <- open_raw(entry,title,width,height)
    return V.NativeWindow{key}

def snapshot(value:Snapshot) -> V.WindowSnapshot:
  Snapshot{width,height,mapped,focused,captured,events} = value
  V.WindowSnapshot{width,height,mapped,focused,captured,events}

def poll(window:V.NativeWindow,timeout_ms:U32) -> V.Action(V.WindowSnapshot):
  do V.Action<V.WindowSnapshot>:
    value:Snapshot <- poll_raw(window,timeout_ms)
    return snapshot(value)

def create_surface(instance:V.Instance,window:V.NativeWindow) -> V.Action(V.Surface):
  do V.Action<V.Surface>:
    key:U32 <- surface_raw(instance,window)
    return V.Surface{key}

type Context is Data:
  Context{window: V.NativeWindow, instance: V.Instance, physical: V.PhysicalDevice, surface: V.Surface, device: V.Device, graphics: U32, present: U32}

def supports(families: List<(U32 & U32)>, +instance: V.Instance, +physical: V.PhysicalDevice, +surface: V.Surface, +index: U32) -> V.Action(List<&2,Core.QueueSupport>):
  match families:
    case Nil{}: V.Action.pure(List<&2,Core.QueueSupport>,Nil{})
    case Con{(flags,count),rest}:
      do V.Action<List<&2,Core.QueueSupport>>:
        supported : Bool <- V.Instance.present_support(instance,physical,surface,index)
        next : List<&2,Core.QueueSupport> <- supports(rest,instance,physical,surface,U32.inc(index))
        return Core.QueueSupport{flags,count,supported} <> next

def candidate_finish(caps: V.SurfaceCapabilities, formats: List<(U32 & U32)>, modes: List<U32>, support: List<&2,Core.QueueSupport>, split: Bool) -> Maybe<Core.QueuePair>:
  V.SurfaceCapabilities{a,b,c,d,e,f,g,h,i,j,k,usage} = caps
  Bool.pick(Maybe<Core.QueuePair>,Core.flags_contains(usage,16) && Maybe.is_some(&1,U32 & U32,Core.surface_format(formats)) && Core.fifo_supported(modes),Core.queue_pair(support,split),None{})

def candidate(+instance: V.Instance, +physical: V.PhysicalDevice, +surface: V.Surface, split: Bool, supported: Bool) -> V.Action(Maybe<Core.QueuePair>):
  match supported:
    case False{}: V.Action.pure(Maybe<Core.QueuePair>,None{})
    case True{}:
      do V.Action<Maybe<Core.QueuePair>>:
        caps : V.SurfaceCapabilities <- V.Instance.surface_capabilities(instance,physical,surface)
        formats : List<(U32 & U32)> <- V.Instance.surface_formats(instance,physical,surface)
        modes : List<U32> <- V.Instance.present_modes(instance,physical,surface)
        families : List<(U32 & U32)> <- V.Instance.get_physical_device_queue_family_properties(instance,physical)
        support : List<&2,Core.QueueSupport> <- supports(families,instance,physical,surface,0)
        return candidate_finish(caps,formats,modes,support,split)

def selected(pair: Maybe<Core.QueuePair>, physical: V.PhysicalDevice, next: Unit -> V.Action(V.PhysicalDevice & Core.QueuePair)) -> V.Action(V.PhysicalDevice & Core.QueuePair):
  match pair:
    case Some{queues}: V.Action.pure(V.PhysicalDevice & Core.QueuePair,(physical,queues))
    case None{}: next(Unit{})

def select(devices: List<V.PhysicalDevice>, +instance: V.Instance, +surface: V.Surface, +split: Bool) -> V.Action(V.PhysicalDevice & Core.QueuePair):
  match devices:
    case Nil{}: IO.pure(V.VkResult(V.PhysicalDevice & Core.QueuePair),Fail{(1610612739,"No suitable presentation device with maintenance1")})
    case Con{+physical,rest}:
      do V.Action<V.PhysicalDevice & Core.QueuePair>:
        supported : Bool <- V.Instance.presentation_supported(instance,physical)
        pair : Maybe<Core.QueuePair> <- candidate(instance,physical,surface,split,supported)
        selected(pair,physical,u => select(rest,instance,surface,split))

def open_device(+window: V.NativeWindow, +instance: V.Instance, +surface: V.Surface, chosen: V.PhysicalDevice & Core.QueuePair) -> V.Action(Context):
  (+physical,Core.QueuePair{+graphics,+present}) = chosen
  do V.Action<Context>:
    device : V.Device <- V.Instance.create_presentation_device(instance,physical,V.PresentationDeviceInfo{graphics,present,surface})
    return Context{window,instance,physical,surface,device,graphics,present}

def open(+entry: V.Entry, title: String, +split: Bool) -> V.Action(Context):
  do V.Action<Context>:
    +window : V.NativeWindow <- open_window(entry,title,640,480)
    +instance : V.Instance <- V.Entry.create_instance(entry,V.InstanceCreateInfo{"Bend interactive",Core.make_api_version(0,1,0,0),[],["VK_KHR_surface","VK_KHR_xlib_surface","VK_KHR_get_physical_device_properties2","VK_KHR_get_surface_capabilities2","VK_EXT_surface_maintenance1"]})
    +surface : V.Surface <- create_surface(instance,window)
    devices : List<V.PhysicalDevice> <- V.Instance.enumerate_physical_devices(instance)
    chosen : V.PhysicalDevice & Core.QueuePair <- select(devices,instance,surface,split)
    open_device(window,instance,surface,chosen)

