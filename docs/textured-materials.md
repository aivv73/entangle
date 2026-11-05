# Textured materials and directional lighting

Entangle renders `Content.Textured{tint,image}` through the existing offscreen
and X11 Vulkan paths. `image` is a retained `Content.SourceImage`, including an
image loaded through `Asset` and the PNG adapter. Source-cache release does not
destroy GPU resources or invalidate retained scene values.

## Public data and rendering

`Vertex{position,color,uv,normal}` carries eleven finite floats. `UV{u,v}` uses a
top-left origin. Normals are local vectors with squared length in `(1e-12,1e12]`.
Procedural producers supply their surface normals. Existing Basic producers and
the position-only OBJ adapter use default UV `(0,0)` and normal `(0,0,1)`.
OBJ texture coordinates, normal import, and material texture-file resolution
remain outside that adapter's supported profile.

The upload format has a 44-byte stride. Position, color, UV, and normal start at
bytes 0, 12, 24, and 32. The 16 MiB vertex transport bound admits 381,300 vertices.
`render-format.bend` owns the serialized words and image-byte conversion.
The vertex-stride and RGBA-order laws constrain those production definitions.

`Basic` remains unlit. `Textured` uses the same baked RGB tint, samples RGB,
and applies an ambient term plus directional Lambert diffuse lighting.
Both outputs are opaque. Vertex color is flat, while UVs and world normals use
perspective-correct interpolation. Source numerical `0xRRGGBBAA` pixels become
RGBA bytes explicitly. Sampling uses `R8G8B8A8_UNORM`, one mip level, nearest
filtering, and clamp-to-edge addressing. There is no gamma conversion, blending,
normal mapping, or shadow map.

Textures have positive dimensions no larger than 4096 on either axis and at
most 4,194,304 pixels. The pixel list must match the dimensions exactly.
The device's image-format limits are checked before allocation. Each used
textured mesh/material pair owns its descriptor and texture resources. Identical
pairs share their compiled range. Different materials can upload the same source
image separately.

`Lighting.Directional{toward,color,ambient,intensity}` points from the surface
toward the light. Its color, ambient, and intensity channels lie in `[0,1]`.
The default direction is `(0.4,0.7,1)`, with white light, ambient `0.2`, and
intensity `0.8`. Normal transforms apply inverse scale followed by quaternion
rotation. Textured draws reject scale magnitudes outside `[1e-6,1e6]`.
Interpolated zero normals receive ambient light without a normalization singularity.

Offscreen configuration is `Render.Config{width,height,camera,light}`.
`Render.default_light()` returns the default light. `Render.set_light` and
`Window.set_light` return the renderer beside a Boolean acceptance result.
Invalid updates preserve the previous light. `Render.set_camera` accepts the
existing `Creation.Camera`, computes the view for the target extent, and also
preserves the previous configuration on rejection. Window frames continue to use
`Creation.view(camera,width,height)`. Camera or light changes do not upload meshes
or textures again.

The native shaders use at most 128 push-constant bytes. Shader source and generated
SPIR-V live under `src/shaders`. Rebuild with `bend tools/build-scene-shaders.bend`.
For a read-only regeneration check, compile that tool and run its binary with
`--check`. The generator uses `glslc` targeting Vulkan 1.0 and runs `spirv-val`.
No Vulkan dependency revision or backend-specific core algorithm changes.

## Ownership and replacement

`scene-texture.bend` owns image allocation, memory, view, sampler, descriptor
schema, and descriptor pool. Upload uses the checked scene-buffer boundary,
explicit host/transfer/shader barriers, and a fence. The upload command resets
before staging storage is released.

`scene-materials.bend` groups each material's owned resources in destruction
order. Collection first destroys the descriptor pool, which native guards reject
while a recorded command retains a set. Successful pool destruction releases its
sets. Collection then releases the sampler, view, image, memory, and schema.
If any release fails, the exact unprocessed suffix remains available for retry.

Whole-geometry replacement prepares the new materials before publishing the
candidate. Successful buffer retirement moves old material ownership into the
new resident's deferred list. Failed preparation preserves the previous resident.
`collect_geometry` and normal frames retry deferred cleanup. GPU completion alone
does not release executable command references. Every retaining command must
reset or be destroyed before collection can finish.

The existing terminal error contract still applies. Failed native cleanup returns
its diagnostics, and `Entry.close` owns remaining registry resources. Device loss
or uncertain submission does not promise continued device recovery. The bounded
native-handler proofs use symbolic driver results. They do not establish that
hardware actually produced these rare errors.

## Run the example and required verification

Run these commands from the repository root.

```sh
bend examples/textured-scene.bend -o build/textured-scene
./build/textured-scene +RTS --threads 1 --gpu off
```

The example loads `assets/checker.png` through Asset, releases the source handle,
and renders two textured cubes with different tints and scales. A/D orbit,
W/S change elevation, Q/E zoom, and R restores the camera. Escape and window Close
exit through the existing scoped cleanup.

```sh
bend tools/verify-workflow.bend -o build/verify-workflow
./build/verify-workflow --plan native textured-window
./build/verify-workflow native textured-window +RTS --threads 1 --gpu off
```

The smaller `textures` profile runs the texture checks and native failure checks.
`textured-window` invokes the existing owned Xwayland launcher in `extended` mode.
It also runs cube, public-creation, mesh-replacement, and mesh movement/replay
scenarios because they consume the changed vertex and pipeline paths.

The runtime drivers check the complete 64×64 RGBA/D32 readback, UV orientation,
diffuse and ambient lighting, inverse scale, rotated normals, and exact camera
move/reset behavior. Small valid normals retain their lighting at the largest
accepted uniform scale. The normal oracle allows one UNORM step for floating-point
rounding. The scalar expected intensities are `255 * 1.6 / sqrt(0.3² + 1.6²)`
and `255 * 0.3 / sqrt(0.3² + 1.6²)` for the two transformed normal scenarios.

The lifetime driver checks exact live-object deltas across submission,
completion observation, two command resets, repeated replacement, and collection.
Its retaining commands bind descriptors without drawing. It establishes native
reference retention, not physical GPU overlap. The upload driver exercises a real
native binding rejection with an undersized allocation, verifies release of both
candidate resources, then retries a successful upload. It does not inject a replacement driver.

Production mutation controls break RGBA order, normal scaling and normalization, diffuse lighting,
camera updates, upload rollback, and deferred ownership. Each must fail at its named observable
property, and restored sources must pass. Shader regeneration must also match the
checked-in words. All native scopes require zero live objects and clean validation
logs. X11 captures, camera controls, repeated extents, restore, and Close establish
the actual window behavior. A complete workflow receipt, its per-stage status,
and retained captures are the authority for a particular source snapshot.

This verification targets the available Linux Vulkan device. It makes no
performance, other-backend, unbounded native-lifetime, or device-recovery claim.
