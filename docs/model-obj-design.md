# Static-model importer design rationale

Callers need a synchronous model source they can retain, inspect, cache, and
pass to the existing scene compiler. Loading must not choose entity identity,
transforms, renderer residency, or native resource lifetime.

Ordered paired `ModelPart{mesh,material,labels}` values meet that need directly.
An immutable Basic material has only three channels, so a public table, slot
identity, binding layer, or Creation bridge would add relations without serving
this consumer. Labels retain source names without promising scene hierarchy or
a material-editing archive. This is the Model the Domain choice.

The parser boundary is validated `Cmd`/`Attrib`. The retained qualification
shows upstream mesh assembly combines an unassigned face and a named-material
face into one material run. It also reverses accumulated lists and has fallback
rules outside Entangle's profile. The adapter therefore does not call
`assemble.meshes`, `shapes`, or `Model.load`. It retains labels and maximal runs
before parsing loses them, validates complete tokens before prefix-tolerant
numeric parsing, resolves every material by exact spelling, and compares each
upstream triangle's material with that resolved selection.

Admitted vertices become a balanced upstream ITree once. Checked corner indices
use that tree rather than repeatedly scanning the source list. Faces expand in
original order to white RGB vertices and local sequential indices. Expansion
intentionally changes sharing/index numbering while preserving the ordered
corner stream and material selection. Unchanged Creation may deduplicate equal
mesh/material pairs later. Conversion checks source, triangle, run, and material
counts, with exact list exhaustion instead of truncating a zip.

Pure `decode` and bounded `load` share preparation and finish. The existing
Asset cache already supplies exact string keys, synchronous completion, cached
errors, and explicit retry. No cache or native dependency changes are needed.
Content continues to import only Base and Components. The isolated source-only
consumer compiles and runs with just that closure, Asset, this adapter, and the
eight parser modules. All engine and verification logic is Bend. Blender's
optional regeneration driver uses the external exporter's Python API, its only
authoring interface here. The X11 launcher uses the established narrow shell
boundary for display/process lifetime.

The dependency is byte-identical Jonlib S41 commit
`5e49707e346453f7d36c27d5ca0cb286e431973d`. Its eight-file import closure, hashes,
original license, tinyobj MIT notice, and raylib zlib notice are retained in
[deps/jonlib-obj](../deps/jonlib-obj/README.md). No umbrella, overlay effects,
foreign parser, unrelated math, or platform-specific algorithm enters the engine.
The chosen uncontracted numeric sequence remains portable Bend code.

The supported profile deliberately requires authored triangles and diffuse,
opaque, unlit material data. UVs, normals, textures, lighting, transparency, scene
JSON, hierarchy, asynchronous work, hot reload, and new rendering capabilities
remain separate work. A successful parse does not imply renderer support for an
unsupported source field. Bounds describe admission, not performance guarantees
or a hostile filesystem sandbox.

Build the Lever produced the rerunnable Bend qualifier, property/file/cache
verifiers, isolated mutations, source inventory, and real native consumer.
Prove It Works required full independent source/packed/readback comparison and
actual owned X11 captures, rather than inferring correctness from compilation.
The [evidence record](verification/2026-11-04-model-obj/README.md) states precisely
which claims are formal and which are observations on this lane.
