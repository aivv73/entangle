# Mesh and material reference

[`src/content.bend`](../src/content.bend) defines the engine's copyable source
values and their meaning. It imports only Base and
[`components.bend`](../src/components.bend). Procedural producers, source caches,
and future importer adapters use the same values.

## Source values

| Type | Fields | Meaning |
| --- | --- | --- |
| `Vertex` | `position:C.Vec3`, `color:C.Vec3` | Mesh-local XYZ position and vertex RGB. All six `F32` attributes are finite. |
| `Mesh` | `vertices:List<&2,Vertex>`, `indices:List<&2,U32>` | Ordered vertices and ordered indexed triangles. Each consecutive group of three indices is one triangle. |
| `Material` | `Basic{tint:C.Vec3}` | Opaque, unlit RGB tint. Every channel is finite and lies in `[0,1]`. |

Source RGB has no magnitude bound beyond finiteness. Negative values and values
above one are valid. Position coordinates are local to the mesh. Instances apply
their transforms separately through [scene creation](public-creation.md).

Indices are local zero-based `U32` values below the source vertex count. The
index count is divisible by three. Empty meshes, unused vertices, repeated
indices, and degenerate triangles are valid. Source order and winding are
preserved. The format does not weld vertices, repair topology, or reverse faces.
The window renderer culls back faces. The offscreen renderer does not.

All three types are `Data`. Their exported constructors are raw and unchecked.
`mesh_valid` and `material_valid` return admission predicates, not new wrapper
types. Cache insertion does not validate content. `Create.compile` validates
instances, and renderer admission validates compiled geometry again.

## Identity and material operations

`same_mesh` compares the ordered vertex attributes by exact `F32` words and
the ordered indices by exact `U32` values. `same_material` compares exact tint
words. Signed zeros differ. There is no canonicalization or comparison of
baked appearance. Raw values with arbitrary float payloads still have exact
identity, even when admission rejects them.

`white()` produces tint `(1,1,1)`. `tint(vertex,material)` preserves position and
multiplies RGB componentwise. A tint channel whose word is exactly `1.0` returns
the original source channel without arithmetic. White therefore preserves every
source bit, including signed zero and arbitrary non-finite payloads in raw values.
`bake(vertices,material)` preserves list order and count. Mesh indices are unchanged.

No transfer function, named color space, gamma conversion, or physically based
color interpretation is promised. Textures, normals, UVs, lighting, transparency,
and richer importer profiles remain separate work.

## Current supported profile

`mesh_fits(vertices:Nat,indices:Nat)` accepts at most 699,050 vertices and
3,000,000 indices. These are current engine admission limits, separate from the
topology and attribute representation. A source mesh over either bound is invalid
and compilation reports `BadMesh` at its instance position.

Compilation also applies `mesh_fits` to aggregate packed counts for new source
pairs and reports `TooLarge` on overflow. Identical mesh and material pairs reuse
their first range without aggregate growth. The scene limit is 100,000 instances.
The [creation reference](public-creation.md) specifies error precedence.

## Importer adapter obligations

An adapter produces these source values without owning the ECS world or Vulkan
resources. It converts external topology to ordered indexed triangles, converts
attributes to finite `F32` values, and resolves indices into the local vertex list.
It preserves the intended winding when converting coordinate conventions.

An adapter validates the current source profile and the supported Basic tint,
and reports unsupported material features or conversion failures through its
loader's error policy. It does not silently claim texture, lighting, or color-space
support. File parsing, triangulation policy, path policy, and external material
mapping belong to the adapter. These Bend values define no serialization standard
or stable on-disk schema.

## Renderer upload boundary

[`src/scene-geometry.bend`](../src/scene-geometry.bend) owns upload serialization
and GPU residency. The existing upload ABI is six `F32` words per vertex in XYZ,
then RGB order, with a 24-byte stride. Indices upload as `U32`. Tint is baked before
upload. The current shaders use flat RGB interpolation and output alpha `1.0`.
This byte layout is a renderer contract, separate from the source format and its
current admission limits.

The [source-cache example](../examples/content-assets.bend) loads procedural
`Mesh` and `Material` values into the production Asset cache, releases their
handles, and returns retained source values without importing Creation or Vulkan.

The [verification record](verification/2026-11-04-content-format/README.md)
separates formal claims, native execution, window evidence, and their limits.

## Image sources

`SourceImage{width:U32,height:U32,pixels:List<&2,U32>}` is also `Data`.
`image_valid` checks positive dimensions and an exact Nat pixel count.
The layout is top-left row-major, with numerical `0xRRGGBBAA` words. Standard
PNG alpha is straight. The PNG importer preserves native CgBI component values
without alpha normalization, as documented in its reference. The source
predicate checks storage, not color or alpha semantics, and has no PNG-specific
limits. Source constructors remain unchecked, and Asset does not revalidate them.

The [PNG reference](image-decoder.md) specifies importer limits, variants,
errors, native-extension tolerances, and verification. Image source storage does
not establish a Vulkan texture, upload layout, or textured material.

## Model sources

`SourceModel{parts:List<&2,ModelPart>}` pairs each `Mesh` with its `Material`
and `ModelLabels{object_name,group_names,material_name}`. All are copyable `Data`.
Labels retain optional object/material names and ordered group names. They are
metadata, without entity identity, hierarchy, material slots, or native owners.

`model_valid` checks every pair and aggregate mesh capacity. `same_model`
compares all vertex/material words, indices, labels, and part order exactly.
Constructors remain raw. Asset does not revalidate source values.

The [OBJ adapter](model-obj.md) admits authored triangles and opaque diffuse
materials, preserving maximal contiguous label/material runs. It expands three
white RGB vertices per triangle with sequential local indices. Coordinates,
winding, and accepted F32 words survive. Unused input declarations are validated
but need not appear in the model. Callers create ordinary `Create.Instance`
values after loading; the importer owns no ECS or Vulkan state.
