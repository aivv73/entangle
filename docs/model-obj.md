# Static OBJ sources

`src/model-obj.bend` imports authored triangles and opaque diffuse materials
into `Content.SourceModel`. Loading is synchronous through the existing Asset
cache. It creates no ECS world, entity, mesh reference, Vulkan object, or renderer.
The caller chooses transforms and passes each part to existing `Create.Instance`.

## API and output

```python
def decode(obj_bytes:List<&2,U32>,mtl_bytes:Maybe<&2,List<&2,U32>>) ->
  Result<&2,&2,Asset.Error,Content.SourceModel>
def load(path:String) -> IO(Result<&2,&2,Asset.Error,Content.SourceModel>)
```

`Content.SourceModel{parts}` contains ordered `ModelPart{mesh,material,labels}`
values. `ModelLabels{object_name,group_names,material_name}` retains optional
object/material names and the ordered group names. Labels are metadata.
They establish no hierarchy or material-editing table.

Each maximal contiguous run of equal labels and material selection becomes one
part. Every accepted face contributes its three ordered corners exactly once.
A part contains expanded positions, white vertex RGB, and sequential local U32
indices. Coordinates, axes, scale, winding, degenerate triangles, finite F32
words, and zero signs are preserved. No welding, sorting, triangulation, tint
baking, quantization, or coordinate conversion occurs in the importer.

The initial material is independent white. A named white material retains its
name. Each selected named material becomes `Content.Basic{tint:Kd}`. Unused
positions and material declarations are validated but need not appear in the
result. This source container is not a round-trip OBJ archive.

`Content.model_valid` checks every mesh/material pair and aggregate geometry
capacity. `Content.same_model` compares all output position/RGB words, indices,
material words, labels, and ordering exactly. Source values remain usable after
cache release. Asset keys remain exact strings. Failed loads are cached too.
Release, request, and load retry the whole OBJ and its dependency.

## Supported text and geometry

Authored triangulation is required. OBJ polygons, including quads, are rejected.
The supported text is ASCII with LF or CRLF, optional final LF, spaces/tabs,
blank lines, and full-line or inline `#` comments. Physical line numbers survive
normalization. NUL, BOM, non-byte words, lone CR, other controls, and line
continuations are rejected. Comment contents do not become directives.

The accepted OBJ directives are:

- `v x y z` with exactly three complete decimal tokens.
- `f a b c` with exactly three bare signed decimal position indices.
- `o name` and `usemtl name` with one case-sensitive token.
- `g name ...` with ordered names. Bare `g` clears groups.
- One `mtllib relative/path` with one dependency filename.
- Neutral `s off` or `s 0`.

Normals, UVs, slash faces, fourth homogeneous coordinates, vertex colors,
active smoothing, lines, points, freeform geometry, and unknown directives are
rejected, including records unused by any face. Zero indices, including signed
zero, fail. Positive references must refer to positions already declared at the
face. Negative indices resolve relative to that same face-time count. Every
`usemtl` must resolve, including one after the final face.

## Numbers and materials

Coordinate, color, and neutral scalar tokens use the complete grammar
`[+-]?[0-9]+(\.[0-9]*)?([eE][+-]?[0-9]+)?`. `.5`, NaN, Inf, missing components,
junk suffixes, and malformed exponents fail. Indices have nonzero magnitude at
most 2147483647. Integer/exponent overflow and every upstream `Parsed` refusal
are errors. The adapter validates unused numeric declarations too.

Numbers use the pinned parser's uncontracted `False{}` binary64 operation
sequence, then its F32 narrowing. The adapter does not use `F32.read` or replace
refusals with zero. This is not a claim of universally correctly rounded decimal
conversion. The pinned helper domain is narrower than all finite decimal inputs.
Finite accepted F32 words, including subnormal values and signed zeros, survive.

A declared MTL must be readable and contain at least one material. Empty or
comment-only declared MTL fails. Pure `decode` requires exactly the bytes implied
by `mtllib`. Unexpected supplied MTL bytes and missing declared bytes fail.

Each `newmtl name` requires exactly one `Kd r g b`, with finite F32 channels in
`[0,1]`. Optional `d 1`, `Tr 0`, and `illum 0` must be mathematically neutral as
complete decimal tokens before F32 rounding. Equivalent exact spellings such as
`d 10e-1` are accepted. Duplicate properties, properties before `newmtl`, duplicate
names, different names with equal upstream hashes, maps, lighting/PBR extensions,
and unknown properties fail. There is no texture IO. Both `MtlOut.ok` and
`table.ok` are checked. A bounded upstream table-probe refusal is reported even
when the declaration count fits the adapter limit.

## File and path policy

Root paths are Base strings, may contain Unicode, and need no extension. Empty
paths, embedded NUL, and paths over 4096 UTF-8 bytes fail before opening. Native
filesystem limits can be lower. An MTL path is relative to the OBJ's lexical
directory without changing cwd. Its slash-separated components cannot be empty,
`.` or `..`. Absolute prefixes, backslashes, controls, whitespace, and colon/URI
syntax fail. The joined path has the same 4096-byte cap.

This is lexical policy, not a symlink sandbox. Base local regular-file IO is the
supported surface. FIFOs, devices, hostile trees, and bounded open latency are
outside it. Reads follow open, size, cap check, read `size+1`, close, and exact
length comparison. Every returned path closes its file. Native errno codes and
native diagnostic bytes are preserved with a path prefix. Expected input
failures return `Asset.Error`; the importer never calls `IO.try` or `IO.die`.

Shrink/growth between size and read is rejected. Same-size concurrent edits and
an atomic snapshot spanning OBJ and MTL are outside this contract.

## Admission limits

| Policy | Limit |
| --- | --- |
| OBJ bytes | 2,097,152 |
| MTL bytes | 262,144 |
| Physical line bytes, excluding LF and including a CR before LF | 4095 |
| Numeric/index token bytes | 64 |
| Object, group, and material label bytes | 255 |
| Materials | 128 |
| Emitted parts | 4096 |
| Source position declarations | 699,050 |
| Aggregate expanded vertices | 381,300 |
| Aggregate indices | 3,000,000 |
| Root and joined path UTF-8 bytes | 4096 |

Counts use Nat before U32 narrowing. Expanded vertices and indices are both
three times the triangle count. The actual geometry ceiling is 233,016 triangles
and 699,048 corners. The index cap is shadowed by the expanded-vertex cap.
The source-position cap is shadowed by the byte cap. A vertex line needs at
least eight bytes, except one absent final LF, so 699,050 declarations cannot
fit in 2 MiB. Verification exercises reachable limits through production inputs
without relaxed test-only entry points.

## Errors

Native IO errors retain their native codes. Adapter errors use these stable
codes. Messages include the source kind, physical line where known, and path for
file loading. Line zero denotes a whole-file/count/conversion failure.

| Code | Class |
| --- | --- |
| `0x80000101` | BadSyntax |
| `0x80000102` | Unsupported |
| `0x80000103` | BadNumber |
| `0x80000104` | BadIndex |
| `0x80000105` | BadMaterial |
| `0x80000106` | BadPath |
| `0x80000107` | Limit |
| `0x80000108` | SourceChanged |
| `0x80000109` | ParserRefused |
| `0x8000010A` | InvalidOutput |
| `0x8000010B` | NoGeometry |

Encoded-size and byte/line admission precede directive inspection. OBJ
inspection precedes MTL inspection, exact reference resolution, and conversion.
A failure discards the whole candidate. There is no partial model or fallback
material for an unknown name.

## Use and verification

The [public example](../examples/model-assets.bend) loads through Asset, releases
the handle, compiles ordinary instances, and runs two real ECS ticks.

```sh
bend examples/model-assets.bend -o build/model-assets
./build/model-assets docs/verification/2026-11-04-model-obj/corpus/sign.obj +RTS --threads 1 --gpu off
bend tools/verify-models.bend -o build/verify-models
./build/verify-models +RTS --threads 1 --gpu off
bash tools/model-obj/window-session.sh
```

The first two commands need no display or GPU allocation. The full verifier
includes offscreen Vulkan. The last command owns its disposable Xwayland display
and validates imported sign/wedge geometry and reversed-face culling. Its Bash
shell manages process lifetime. All verification behavior lives in Bend drivers.

[Design rationale](model-obj-design.md) records the selected boundary and pin.
[Verification evidence](verification/2026-11-04-model-obj/README.md) distinguishes
formal claims, runtime observations, mutation sensitivity, and unsupported scope.
