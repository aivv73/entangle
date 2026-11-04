# Static OBJ importer verification

The first importer converts pinned Jonlib S41 Cmd/Attrib data into ordered
engine mesh/material/label pairs and loads synchronously through Asset.
Loading owns no ECS world, entity, mesh reference, or Vulkan object.
The supported surface is authored triangles with opaque diffuse materials.
E4 as a whole remains incomplete.

The implementation starts from `90c7b7e` on `feat/static-model-importer`.
[The reference](../../model-obj.md) states the accepted profile and limits.
[The rationale](../../model-obj-design.md) records the selected data shape and
boundary. No alternate parser, public material table, Creation operation,
rendering capability, runtime fork, or GPU-specific algorithm is introduced.

## Reproduction

Run from the repository root with the pinned toolchain and existing dependencies.
The source/consumer gate uses the retained assets and does not require Blender.

```sh
bend PROOF.bend
bend tools/verify-models.bend -o build/verify-models
VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation VK_LAYER_VALIDATE_SYNC=1 \
  ./build/verify-models +RTS --threads 1 --gpu off
bash tools/model-obj/window-session.sh
```

The model verifier executes the exact parser qualifier, production decoding,
generated properties, production bounds, real files/cache, isolated source
inventory, deliberate production mutations, real Creation/ECS/offscreen
consumers, and the public Asset example. Each command stops on failure.
`--gpu off` controls Bend dispatch; offscreen and X11 still call real Vulkan.
The existing `tools/verify-creation.bend` is also compiled and run separately.

The combined receipt is
`build/verification/models-final-wxcB3fIt`. `commands.log` contains exact literal
commands. Per-stage `.status` files, `run.status`, logs, and source hashes remain
there. A complete receipt requires every executed status and `run.status` to
be zero. The supplemental shared-workspace `assets` workflow receipt is named
in `workflow-assets.log` as `workflow-zIbnOaXe`. It includes toolchain, source-boundary, frontend,
generic Asset, and law-mutation checks in an isolated source snapshot.
Concurrent development-workflow/guidance edits belong to their separate owner.
The importer has its own rerunnable verifier and window launcher.

The final owned X11 receipt is
`build/verification/model-window-xnuTk9Ov`. It retains fresh binaries, commands,
source hashes, reversed input, three captures, driver/native logs, per-stage
statuses, and cleanup. All three cases use the actual OBJ loader. The sign has
white, red, and green regions. The closed asymmetric Blender wedge has visible
geometry. Reversing every sign face gives clear-only output under native
back-face culling. Each case sends actual Close, reports zero live Vulkan
objects, and has no validation diagnostics. The owned display PID 356752 is
reaped and runtime `build/model-window-runtime-m8D7u1c2` is removed.
The earlier complete X11 receipt `model-window-KvFSFUGO` is also retained.

Selected logs, source hashes, captures, packed/state words, and readbacks are
copied beside this record. The originals remain in `build`. `captures.sha256`
and `readbacks.sha256` identify the retained artifacts.
Narrow Git whitespace attributes preserve the byte-identical upstream raylib
notice and raw captured logs/state words, including their trailing spaces.

## Independent source oracle and qualification

The MIT-licensed sign and Blender 5.2.3 LTS export live in `corpus` with complete
hashes and provenance. The original sign specification is three ordered panels.
The wedge's original authoring specification has six vertices and eight ordered
triangles. `tools/model-obj/reference.bend` supplies every engine-source corner,
white RGB, local index, material word, and label from those specifications.
It does not import or call the parser. The optional `export.bend` driver invokes
the real Blender authoring/export API to regenerate the closed wedge.

The first native qualifier ran the real pinned parser on the retained sign
before adapter implementation. The retained final qualifier additionally checks
the real exported wedge and prints full Cmd, position, triangle, material, and
Parsed observations. Numeric controls cover signed zero, a binary32 midpoint,
the next binary32 value, finite exponent ranges, gradual underflow, signed
underflow zero, helper refusal, exponent overflow, and prefix-to-zero quirks.
A real `ab`/`bA` hash collision and a real 128-declaration table-probe refusal
are exercised. The latter has `MtlOut.ok=True` and `table.ok=False`.
Both flags require independent admission checks.

The coordinator's earlier `assemble.meshes` observation is retained separately
as `upstream-assembly-hazard.log`. It shows default/named material loss in the
assembly facade. That observation is not full parser qualification. Production
uses validated commands and attributes instead.

## Formal coverage

`LAWS.bend` contains only claims; `PROOF.bend` supplies their proofs.
`bend PROOF.bend` reports `ALL PROOFS CHECK`. This is the Bend frontend verdict,
not a BendTT kernel verdict or a universal parser/filesystem proof.

The new claims cover pair/aggregate admission, three-corner emission and count,
local index emission/count and first-triangle winding, initial independent white,
missing-name rejection, both zero-index spellings, conditional face-time
negative-index resolution, run count/coalescing/boundaries, finite Parsed-word
transfer, incomplete-read rejection, the expanded geometry boundary, and the
byte-shadowed source-position cap. The general successful-decode theorem is
`Obj.valid_result(Obj.decode(obj,mtl)) == True`. Failures classify as valid results;
every Done must satisfy the production `Content.model_valid` predicate.

These proofs establish the stated structural/admission properties against
production definitions. They do not prove universal source parsing, arbitrary
decimal correct rounding, upstream numerical completeness, native driver
behavior, or all filesystem race interleavings.

## Runtime properties and consumers

The production checks establish complete model equality on both retained assets.
The 64-count family executes positive and equivalent negative references plus
whitespace/CRLF/comment/no-final-LF variants, for 192 generated comparisons.
Additional properties check maximal contiguous runs, object/group metadata,
bare `g`, default versus named white, repeated selections, no empty-declaration
parts, exact Kd and zero signs, all unsupported fields, malformed numbers and
indices, unused declarations, material collisions, and missing/unexpected MTL.

Production limits are reached at and over 2 MiB OBJ, 256 KiB MTL, 4095 physical
line bytes, 64 numeric bytes, 255 label bytes, 128 materials, 4096 parts, and
233,016 triangles. Every one of 699,048 expanded vertices and indices is checked
at the geometry ceiling. Source positions cannot reach 699,050 inside the byte
cap. Expanded indices cannot reach 3,000,000 before the vertex cap. Verification
does not introduce relaxed parsing entry points to make shadowed cases reachable.

Real filesystem checks cover Unicode roots without extensions, joined-path
bounds, missing roots/dependencies, native size/read errors, sparse sizes above
UINT32_MAX, exact byte bounds, and shrink/growth after stat. Cached success skips
invalid changed files. A retained full source survives release. Fresh loading
observes a red-to-blue dependency edit. Cached failure remains stable after MTL
creation, and release/request recovers. Stale/foreign handles perform no load.
Across 64 repetitions of successful and failed real load paths, descriptor counts
remain equal. These are bounded runtime observations and explicit close paths.

The isolated inventory compiles and runs with only Base, Content, Components,
Asset, the adapter, and eight pinned parser modules. No Creation, ECS, Vulkan,
umbrella, or foreign parser enters that source closure. The repository source
boundary includes the reviewed OBJ symbols and verifies the exact vendor
SHA-256 closure. The public Asset example retains the source after cache release,
creates ordinary instances, and completes two production ECS ticks.

The native consumer compares every packed position/RGB word, index, and range
against direct engine sources. It compares every extracted transform word and
mesh reference after two real ECS ticks. `.state.txt` files retain both actual
and reference observations; `.packed.txt` files retain the actual full geometry.
`.rgba` and `.d32` contain complete 128x64 real readbacks. Actual and reference
RGBA/D32 match exactly. The retained drawing-list replay matches, later real
movement changes output, and resource counts return to zero. The separate existing
Creation verifier also covers rejection, empty geometry, sharing, and camera
configuration. The owned X11 gate establishes the culling behavior that the
culling-disabled offscreen path cannot establish.

## Sensitivity and failed attempts

Four isolated production mutations must fail for their named observations,
with native status 1, rather than a timeout or unrelated compile failure.

- Reversed emitted corners fail complete independent source equality.
- Removing raw-zero rejection accepts `f 0 2 3` and fails the rejection property.
- Allowing unknown-name/default fallback accepts the unresolved `usemtl` and fails.
- Ignoring unsupported three-field MTL properties accepts `Ks` and fails.

The restored source passes the same production verifier. Mutation copies and logs
remain under `build/model-obj/mutation-*` and in the combined model log.

An early adapter opacity validator tried to accumulate long decimal coefficients
in Nat. A native run reached `a Nat past the largest immediate 2^48-1` on a long
non-neutral decimal. The final validator uses bounded digit shape, zero counts,
and exponent displacement. The long-decimal rejection remains in the production
runtime gate. That exploratory output was overwritten during iteration; this
record does not claim to retain its full original log.

The first naive 128-material source reached an upstream table refusal. Its log
is retained as `bounds-table-refusal.log`; final qualification reproduces the
actual refusal. Distinct safe probe slots exercise the independent 128/129 count
limit. The adapter reports table refusal rather than substituting a dependency.

The first combined attempt `models-final-W5bdRFKU` stopped because the `files`
binary output path collided with the filesystem-fixture directory. Executables
now use `build/model-obj/bin`. Its original log/status remain in that directory.
The next combined attempt `models-final-emt322zu` passed model and Creation gates
but stopped at source-boundary registration. `workflow-c0HRPOnJ` retains the
specific unregistered OBJ import failure. The final inventory and exact pin check
include that closure. The verifier's Unicode filename uses character scalars to
fit the source scanner's ASCII read policy without changing the real filename.
An exploratory interpreter invocation of the native consumer hit the existing
Vulkan native-build guard. Native acceptance uses compiled executables only.

## Limits

There is no performance claim, general OBJ/MTL support claim, archive fidelity,
texture/normal/UV/lighting/transparency support, parser-wide proof, symlink
sandbox, two-file atomic snapshot, same-size edit detection, device-loss claim,
or CUDA/Metal/WebGPU execution claim. The importer stays sequential and portable
Bend. No renderer or native resource code changes are made. Root independently
reviews the commit and evidence before publication.
