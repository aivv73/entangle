# JSON scene files and manifests

`SceneFile.load(path)` reads a flat scene, resolves its manifest, validates every
declared OBJ and PNG source, and returns `Creation.Scene`. Errors are
`Asset.Error` values. Loading creates no ECS or Vulkan resources. The caller can
cache the result through `Asset.load` and compile it through `Creation.compile`.

```python
import ./src/scene-file.bend as SceneFile

def load(path:String) -> IO(Result<&2,&2,Asset.Error,Creation.Scene>)
def load_manifest(path:String) -> IO(Result<&2,&2,Asset.Error,List<&2,SceneFile.Source>>)
```

`load_manifest` returns ordered `ModelSource{id,value}` and
`ImageSource{id,value}` entries after all declared files load successfully.
`decode_manifest(bytes,path)` and `decode_scene(bytes,path)` validate JSON into
`Manifest` and `Description` without file access. Their `path` argument supplies
diagnostic context. `load` additionally resolves references and checks that the
result compiles through the existing Creation rules. No partial scene is
returned on failure.

## Version 1 schema

Every listed field is required. Unknown fields and wrong types are errors at
all object levels. Object field order is irrelevant. Array order is preserved.
Version is the exact JSON integer token `1`.

A manifest has this shape.

```json
{
  "version": 1,
  "assets": [
    {"id": "sign", "kind": "obj", "path": "sign.obj"},
    {"id": "image", "kind": "png", "path": "image.png"}
  ]
}
```

A scene has this shape.

```json
{
  "version": 1,
  "manifest": "manifest.json",
  "instances": [
    {
      "model": "sign",
      "transform": {
        "position": [0, 0, 0],
        "rotation": [0, 0, 0, 1],
        "scale": [1, 1, 1]
      }
    }
  ]
}
```

IDs contain 1 to 64 ASCII letters, digits, hyphens, or underscores. They are
case-sensitive and unique across both asset kinds. Each scene model reference
must name an OBJ entry. A PNG entry cannot be used as a model. Every declared
asset loads, including unused entries. Missing files and malformed OBJ, MTL,
or PNG contents fail the load.

The manifest path is relative to the scene file. Each asset path is relative
to the manifest file. Paths contain printable ASCII slash-separated components.
Empty components, `.` and `..`, backslashes, colons, spaces, and control bytes
are rejected. These are lexical path rules. They do not confine symlink targets
or provide a filesystem sandbox. Root paths must be nonempty, contain no NUL,
and fit within 4096 UTF-8 bytes. Joined paths have the same limit.

A model's parts expand in order at each placement. Meshes, materials, winding,
and transforms are preserved. Existing Creation compilation shares identical
mesh/material pairs. Images remain source assets. This schema adds no texture
binding, cameras, parent hierarchy, animation, or new model format.

## Parser and limits

Both document kinds use only `bend-kit-json@0.7.0.0`, content hash
`0x37aacddc1dcb57464b8b5ac6c397bd64`, through
`parse.strict.unique.bytes`. Its byte storage is
`bend-kit-bytes@0.3.3.0`, hash `0x632652e3c1c0183f12728faf3870bb68`.
Strict UTF-8, complete JSON consumption, valid escapes, and unique decoded
object keys are required. Duplicate keys are rejected even when written with
different escape spellings. Neither first nor last duplicate wins.

The parser retains numeric tokens exactly. Version validation uses that text.
Transform values use `F32.read` only after JSON syntax validation and a numeric
token length check. The resulting F32 must be finite and within
`[-1000000,1000000]`. Decimal values round to F32, including underflow to signed
zero. Position and scale contain exactly three numbers. Rotation contains
exactly four numbers in x/y/z/w order. Its squared norm must be within
`[0.9999,1.0001]`. Loading does not normalize it. Zero and negative scale remain
valid under the existing Creation contract.

| Boundary | Limit |
| --- | --- |
| Each scene or manifest | 65536 encoded bytes |
| Nested arrays and objects | 8, checked before parsing contents |
| Decoded string field | 255 UTF-8 bytes |
| Transform numeric token | 64 ASCII bytes |
| Manifest entries | 64 |
| Scene placements | 256 |
| Expanded model parts | 4096 |
| Aggregate loaded source geometry | 381300 vertices and 3000000 indices |
| Aggregate loaded image pixels | 16777216 |
| Each OBJ, MTL, or PNG | Existing importer limits apply |

The file boundary checks size before reading, requests at most size plus one
byte, and rejects a read whose count differs from the measured size. It closes
the file on success and failure. This detects incomplete reads and size changes.
It does not make same-size concurrent edits transactional. Decoding supplied
bytes checks the encoded limit and rejects words above 255 before packing.
Aggregate source limits are checked after each asset decodes. One candidate
asset can temporarily exceed the aggregate budget before rejection.

Adapter errors use `2147484160 + code`. Codes 1 through 6 identify invalid JSON,
a size limit, schema mismatch, numeric or Creation rejection, a reference or
path error, and an incomplete read. File and importer errors retain their own
codes. JSON diagnostics include the document path and the affected schema
location when available. The chosen parser returns a single failure result for
syntax, duplicate keys, and excessive depth, so these share code 1.

## Verification

Run `bend tools/verify-workflow.bend -o build/verify-workflow`, inspect
`./build/verify-workflow --plan json`, then run
`./build/verify-workflow json +RTS --threads 1 --gpu off`.
The JSON profile includes the existing asset checks and root law checks.
`tools/verify-json.bend` retains parser qualification, real file rejection
checks, cache behavior, six production mutations, a restored runtime baseline,
and real ECS/offscreen comparison against an independently authored scene.

The [retained scene](verification/2026-11-04-json-scene/corpus/scene.json) runs
through `examples/json-scene.bend`. Its expected compilation has six instances,
18 vertices, 18 indices, and three shared ranges. The
[verification record](verification/2026-11-04-json-scene/README.md) states the
source receipt and evidence limits.
