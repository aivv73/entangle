# Mesh replacement reference

Both production renderers replace their complete packed geometry through the same API. Mesh references resolve against the installed range table. Replacement does not change ECS entities or their `MeshRef` values.

```python
import Base
import ./src/scene-render.bend as Offscreen
import ./src/scene-window.bend as Window
import ./src/scene-geometry.bend as Geometry
import ./src/creation.bend as Create
import ./deps/bend-vulkan/Vulkan.bend as V

def change_mesh(renderer:Offscreen.Renderer,candidate:Create.Geometry) -> IO(Offscreen.Renderer & Geometry.ReplaceStatus):
  Offscreen.replace_geometry(renderer,candidate)

def collect_mesh(renderer:Offscreen.Renderer) -> IO(Offscreen.Renderer & V.VkResult(Unit)):
  Offscreen.collect_geometry(renderer)
```

`Window.replace_geometry` and `Window.collect_geometry` have the same signatures with `Window.Renderer`. The owner is outside the failure result. A rejected candidate leaves the previous buffers, range namespace, attachments, camera, layout state, commands, and target current. Diagnostic ownership is retained. Successful candidate writes still contribute to the existing measured upload counters, including when retirement rejects the candidate.

`Rejected` contains the initiating `(code,message)` and a list of cleanup failures. Allocation failures from `scene-buffer` retain their original code and append any internal cleanup error to the message. Device loss remains terminal for useful rendering. This API preserves ownership; it does not promise device recovery.

## Transaction and collection

`scene-geometry.bend` owns the allocation context, paired vertex and index buffers, and one `Resident` containing both buffers and ranges. Creation and replacement share validation, serialization, preparation, and rollback. `creation.geometry_valid` remains the geometry authority. Both byte capacities pass the checked upload boundary before allocation. Empty index geometry owns no buffers and can retain valid zero-count ranges.

The transaction allocates and uploads the complete candidate before submitting both old buffer and memory pairs to one `Device.retire_buffers` call. Failure disposes every acquired candidate buffer. Both cleanups run even if the first fails. Entry teardown owns any native resource left by failed cleanup.

Successful retirement seals the old handles. The next effect returns the fresh resident and `Installed`; replacement performs no collection or other fallible native effect after sealing. A caller must retain the returned owner before any later collection. Sealed handles never become current again.

`collect_geometry` scans native retired resources and returns `(owner,VkResult(Unit))`. Success does not imply destruction. A completed executable command still retains its recorded resources. Successful command reset releases those references. Normal frames collect at entry and after reset, including hidden, empty, and rejected-input frames. Window close collects after reset. Frame and close failures retain their existing terminal `V.Action` contract. Entry teardown remains the final cleanup authority.

## Proof and native boundary

The root laws prove the generic selection and complete paired-allocation enumeration in `scene-geometry-policy.bend`. The production transaction calls those helpers for both success and rejection. The pure module keeps foreign effects out of the root proof checker. These laws do not prove native Vulkan calls, allocation success, submission completion, or the C registry.

The [verification recipe](../.agents/skills/verify-entangle/features/mesh-replacement.md) drives both public APIs with real Vulkan resources and X11 pixels. It checks exact offscreen coverage, RGBA and D32 preservation, range changes, removed identifiers, repeated empty transitions, deferred destruction after completed submission, and atomic recording-reference rejection with immediate candidate disposal. Actual allocation exhaustion, device loss, and cleanup failures require genuine failures and remain unexercised without fault injection. No engine retirement queue, per-entity asset lifecycle, new runtime parallelism, or performance claim is included.
