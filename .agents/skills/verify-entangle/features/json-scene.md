# JSON scene and manifest loading

The public entry points are `SceneFile.load`, `load_manifest`, `decode_scene`,
and `decode_manifest`. The [schema reference](../../../../docs/json-scene.md)
defines version 1, parser selection, numeric conversion, references, and limits.

Build `tools/verify-workflow.bend` and run its `json` profile. Its required JSON
stage builds and runs `tools/verify-json.bend`. Run from the repository root.
The native checks require the existing Vulkan offscreen prerequisites.

Require the parser qualification, complete authored scene comparison, real-file
rejection matrix, cache success/failure/release/retry, exact ECS and offscreen
readback comparison, all six deliberate production regressions, and the restored
baseline to pass. Inspect the nested `build/json-scene` logs and
`build/model-obj/json-scene.state.txt`, `.packed.txt`, `.rgba`, `.d32`, and `.ppm`.
The new critical controls check duplicate keys, unknown fields, numeric range,
wrong asset kind, encoded size, and parser depth. Each must fail for its named
observation, not a compile error, timeout, or unrelated failure.

Root laws cover oversized supplied input, incomplete reads, reference rejection,
part preservation, and admitted-scene compilability. They are frontend proofs,
not an independent kernel verdict for the JSON parser or filesystem behavior.
This feature does not change window controls. Offscreen execution does not
establish X11 behavior, another GPU backend, performance, hierarchy, textures,
or filesystem confinement through symlinks.
