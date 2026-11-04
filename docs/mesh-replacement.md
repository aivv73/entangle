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

`collect_geometry` scans native retired resources and returns `(owner,VkResult(Unit))`. Success does not imply destruction. Collection requires a sealed buffer with no remaining native retaining references. Its paired memory must have been dedicated to that buffer when retirement succeeded. Sealing prevents new recording, submission, descriptor writes, or memory bindings from introducing uses of that allocation.

The native registry accounts for the complete chain of owners:

- Each command retains every recorded resource, including descriptors and earlier bindings superseded during recording. Unsubmitted and completed commands keep those references until successful reset or command pool destruction. Resetting one command does not release another command's references.
- Pending and uncertain submissions prevent command reset or pool destruction. Observing completion releases submission associations but preserves recorded references. A fence wait or device idle therefore does not establish that an allocation can be reclaimed.
- Each descriptor set retains the resources in every populated slot. Rewriting one slot preserves the others. References disappear after the corresponding slots are overwritten, the set is freed, or its pool is reset or destroyed. Recorded sets remain frozen until every referring command releases them.
- Memory bindings retain allocations. Retirement rejects an allocation shared with another bound resource before sealing any pair. After successful retirement, new aliases are rejected.

These edges compose: a command can retain a descriptor set that retains a buffer that retains memory. A sampled-image descriptor retains both its sampler and image view. The view retains the image, which retains its bound memory. Collection waits for every retaining edge to a retired buffer to disappear. Sampled resources use explicit destruction after their incoming references disappear. Copies of Bend handle values are lookup keys, not native retaining owners; they become stale after collection or explicit destruction.

Normal frames collect at entry and after reset, including hidden, empty, and rejected-input frames. Window close collects after reset. Frame and close failures retain their existing terminal `V.Action` contract. Entry teardown remains the final cleanup authority.

## Proof and native boundary

The root laws prove the generic selection and complete paired-allocation enumeration in `scene-geometry-policy.bend`. The production transaction calls those helpers for both success and rejection. The pure module keeps foreign effects out of the root proof checker. These laws do not prove native Vulkan calls, allocation success, submission completion, or the C registry.

The [verification recipe](../.agents/skills/verify-entangle/features/mesh-replacement.md) drives both public APIs with real Vulkan resources and X11 pixels. The offscreen driver checks exact coverage, RGBA and D32 preservation, range changes, removed identifiers, repeated empty transitions, and atomic recording-reference rejection with immediate candidate disposal. It also executes multiple submissions, retains an unsubmitted command, rewrites descriptor array slots, frees sets, resets pools, and binds memory aliases. Exact live-object counts and stale-handle checks establish that collection waits for the last owner. The native gate runs this driver.

The [sampled-image retention helper](../tools/verify-sampled-retention.bend) adds two sampled descriptor sets with two slots each. It checks frozen recorded sets, rejection of resource destruction, retention across completion and idle, and rewriting one set after its command resets while another set remains recorded. Final overwrite, set free, pool reset, and pool destruction each release descriptor references. Explicit cleanup checks the view-to-image-to-memory chain, exact live counts, and stale handles for all four resource kinds. Its submitted commands bind descriptors without drawing; texture sampling and image-layout transitions are outside this check. See the [runtime record](verification/2026-11-04-sampled-retention/README.md).

[Native failure verification](verification/2026-11-03-native-failures/README.md) exercises a genuine allocation failure under a process-local address-space limit, partial preparation rollback, cleanup rejections, error preservation, and terminal teardown. Recording, submission, and pending-reset rejections preserve earlier references and permit recovery.

[Bounded verification of production handlers](../proofs/native-failures/README.md) covers arbitrary driver return values for begin/end/reset, submission, sticky device loss, descriptor free/reset quarantine, and failed idle/entry cleanup. It checks statements extracted from the unchanged native C implementation and guards that prevent uncertain work from being reused or destroyed. Successful idle/completion preserves recorded references. The native gate includes these proofs; source mutations check that the properties detect broken handlers. See the [closure record](verification/2026-11-04-native-failure-closure/README.md) for the approved evidence standard and results.

These rare errors are formally covered within explicit registry/list bounds; they are not claimed as observed hardware events. The proof does not establish unbounded native lifetime correctness, dispatch/driver correctness, or device recovery. Sampled-image retention is checked by real execution, outside the formal proof boundary. No engine retirement queue, per-entity asset lifecycle, new runtime parallelism, or performance claim is included.
