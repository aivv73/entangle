# Public creation reference

`src/creation.bend` defines immutable startup descriptions. Constructors create
ordinary values. `compile(Scene)` is the checked entry point and returns
`Result<Error,Compiled>`. It needs neither Vulkan nor a window.

## Descriptions

- `Vertex{position,color}` contains finite RGB and position coordinates.
- `Mesh{vertices,indices}` contains triangle-list indices into its own vertices.
  Empty meshes are valid. The index count must be divisible by three.
- `Basic{tint}` multiplies vertex RGB componentwise. Each channel must be finite
  and in `[0,1]`. The material is opaque and unlit. `white()` preserves every
  source color bit, including signed zero.
- `Instance{mesh,material,transform}` creates one initial ECS entity.
  Translation and scale must be finite. Quaternion squared length must lie in
  `[0.9999,1.0001]`.
- `Scene{instances}` preserves instance order through compilation and bootstrap.

`compile` rejects invalid descriptions with `BadMesh`, `BadMaterial`, or
`BadTransform`, each carrying the zero-based instance position. `TooLarge`
rejects more than 100,000 instances, 699,050 packed vertices, or 3,000,000 packed
indices. A source mesh also obeys the vertex and index limits. Validation and
packing complete before any GPU allocation.

Compilation materializes only used mesh/material pairs. Bitwise structural
comparison identifies identical source values. First occurrences determine
range order. Repeated pairs share a range while retaining separate ECS entities.
References start at 7 to preserve the existing demonstration's mesh reference.
Applications consume generated references instead of selecting them.

`Compiled{seeds,geometry}` is the single result. Each `Seed{transform,mesh}`
contains the existing `MeshRef`, which identifies baked geometry. It is not an
entity identity. `Geometry{vertices,indices,ranges}` contains tinted vertices,
rebased indices, and `Range{id,first_index,index_count}` values. Positions remain
unchanged. `resolve(ranges,id)` returns the matching range or `None`.

`Scene.create(seeds)` registers the existing Bendvy application. The first tick
queues and publishes initial entities, then runs the existing movement system.
Bendvy handles identify entities. A second tick moves existing entities without
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

Creation supplies startup entities and immutable renderer geometry. Runtime
insertion, resource deletion, textures, lighting, transparency, persistent GPU
scene storage, and the roadmap's second interactive application remain separate
work. Packing uses sequential structural lookup for small startup scenes. No
performance or cross-backend bitwise determinism claim is made.

The [verification record](verification/2026-11-03-public-creation/README.md)
records formal claims, real ECS execution, offscreen rendering, and X11 captures.
