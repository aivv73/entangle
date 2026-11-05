# Public creation reference

`src/creation.bend` defines immutable scenes, instances, cameras, and compiled
ranges. Mesh and material source values come from
[`src/content.bend`](content.md). Constructors create ordinary unchecked values.
`compile(Scene)` is the checked entry point and returns
`Result<Error,Compiled>`. It needs neither Vulkan nor a window.

## Descriptions

- `Content.Vertex`, `Content.Mesh`, and `Content.Basic` follow the
  [mesh and material contract](content.md). RGB is finite but unrestricted in
  magnitude. Tint is finite and bounded to `[0,1]`.
- `Instance{mesh,material,transform}` creates one initial ECS entity.
  Translation and scale must be finite. Quaternion squared length must lie in
  `[0.9999,1.0001]`.
- `Parented{mesh,material,transform,parent}` attaches it to a zero-based source
  instance index. `Creation.parent(instance, Some{index})` sets that relationship;
  `None{}` detaches it. Forward references are allowed. See
  [scene hierarchy](scene-hierarchy.md) for composition and transactional edits.
- `Scene{instances}` preserves instance order through compilation and bootstrap.

`compile` first rejects more than 100,000 instances with `TooLarge`. It then
validates instances in source order. Each instance reports `BadMesh` before
`BadMaterial`, then `BadTransform`, carrying the zero-based instance position.
A source mesh over the current 381,300-vertex or 3,000,000-index profile reports
`BadMesh`. A new pair that overflows aggregate packed counts reports `TooLarge`.
A duplicate pair reuses its range before any aggregate growth check. Validation
and packing complete before any GPU allocation. Hierarchy derivation then rejects
missing parents, cycles, and invalid world transforms or bounds with `BadHierarchy`.

Compilation materializes only used mesh/material pairs. Bitwise structural
comparison identifies identical source values. First occurrences determine
range order. Repeated pairs share a range while retaining separate ECS entities.
References start at 7 to preserve the existing demonstration's mesh reference.
Applications consume generated references instead of selecting them.

`Compiled{seeds,geometry}` is the single result. Each `Seed{transform,mesh,spatial}`
contains the existing `MeshRef`, which identifies baked geometry. It is not an
entity identity. `spatial` contains the validated local relationship/source bounds,
global matrix, and world bounds. `Geometry{vertices,indices,ranges}` contains tinted vertices,
rebased indices, and `Range{id,first_index,index_count,texture}` values.
The texture is `None` for Basic materials and `Some{SourceImage}` for textured materials.
Positions, UVs, and normals remain unchanged. `resolve(ranges,id)` returns the matching range or `None`.

Use `compile` to obtain geometry-derived bounds and lighting requirements.
The source-free `seed(transform, mesh_ref)` helper exists for legacy numerical
fixtures: it has no vertices or material and therefore carries empty source
bounds and an unlit requirement. Bootstrap rederives globals from seed metadata;
it cannot reconstruct missing mesh metadata from a numeric reference.

`Scene.create(seeds)` registers the existing Bendvy application. The first tick
queues and publishes initial entities, then runs the existing movement system.
Bendvy handles identify entities. Completed ticks derive globals and bounds before
observation. `Scene.set_transform` and `Scene.set_parent` consume and return the
application beside a `Result<Hierarchy.Error,Unit>`; rejected edits preserve it.
`Observe.spatial` returns detached entity/local/global/bounds rows. A second tick moves existing entities without
spawning them again. Reservation refusal retains ownership through the existing
bootstrap error path. There is no new runtime asset service or material column.

Both renderers accept `Geometry`, validate its bounds before allocating, and
preflight every extracted drawing before recording commands. They issue the
range's actual first index and count in extraction order with the existing
camera/model matrix push. Zero-index ranges issue no draw or push commands.
Geometry with no indices owns no vertex or index buffers. Framebuffer clears
and presentation still run.

## Camera

`Camera{target,yaw,pitch,distance,projection}` defines an orbit around `target`.
`Perspective{scale,near,far}` uses the vertical projection scale, equivalent to
`cot(vertical_fov / 2)`. All values must be finite. Distance, scale, and near
must be positive, and far must exceed near.

`camera(value)` returns `Some` for a valid configuration and `None` otherwise.
`view(camera,width,height)` returns a finite matrix or `None`. Invalid cameras,
zero dimensions, and non-finite derived matrices return `None`.
`default_camera()` preserves the old orbit and projection arithmetic. The demo
applies its own tick-one framing separately.

`Input.key` changes orbit values while preserving target and projection. Reset
restores yaw `0.65`, pitch `0.45`, and distance `7.0`, preserving the configured
target and lens. Reset does not restore a caller's custom initial orbit.
Controls retain the existing pitch clamp `[0.1,1.4]` and distance clamp `[4,15]`.

## Startup callbacks

The four slots in `src/modules.bend` have these concrete inputs and outputs:

| Slot | Callback |
| --- | --- |
| `Core<A>` | `List<Seed> -> IO(A)` |
| `Input` | `Unit -> Camera` |
| `Assets` | `Unit -> Scene` |
| `Render` | `V.Entry -> Geometry -> V.Action(Win.Renderer)` |

The existing executable calls Assets once, compiles once, sends its geometry to
Render, and sends the same result's seeds to Core. Core retains responsibility
for its first tick. The example recipe owns the former fixed 100-entity seeds.
Render adapters are engine assembly code and retain Vulkan access. The public
creation example imports no Vulkan module and handles no Vulkan values.

## Scope

Creation supplies startup entities and packed renderer geometry. Both renderers
support [whole-mesh replacement](mesh-replacement.md), including deferred destruction
and preservation on rejected candidates. [Textured materials](textured-materials.md)
use the same geometry and camera APIs. Runtime entity insertion, per-asset deletion,
transparency, and persistent GPU scene storage remain separate work.
Packing uses sequential structural lookup for small startup scenes. No
performance or cross-backend bitwise determinism claim is made.

The [verification record](verification/2026-11-03-public-creation/README.md)
records formal claims, real ECS execution, offscreen rendering, and X11 captures.
