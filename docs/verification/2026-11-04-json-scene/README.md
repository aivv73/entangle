# S44 JSON scene loading verification

This change implements the S44 loading boundary on base
`d012aa4841c022c854a674d66827418ed9c06a32`. Work is local and uncommitted.
[Trail 28](https://entire.com/et/bend-engine/-/trails/28) tracks the acceptance
contract and actual delivery state. The required `json` workflow completed with
all ten required stages at exit 0 in
`build/verification/workflow-Le2SzUwZ`. Its `state` is `complete` and its
`run.status` is 0.

The receipt retains the dirty-source snapshot, exact commands, toolchain,
dependency revisions, statuses, and logs. [receipt.sha256](receipt.sha256) binds
its source manifests. [workflow-manifest.tsv](workflow-manifest.tsv),
[frontend.log](frontend.log), and [law-mutations.log](law-mutations.log) retain
the selected stages and proof results. The full JSON runtime output is
`build/verification/workflow-Le2SzUwZ/json.stdout`. Its six deliberate runtime
regressions failed for their named observations, and the restored baseline
passed. All nine root law mutation controls, including both new controls,
failed at the expected properties and restored successfully.

The final default-native entry point calls `Json.main()` directly. This avoids
putting the whole JSON suite under its generic five-minute subprocess timeout.
That wiring change follows the snapshot. The JSON driver, production code,
laws, controls, and public example still match the verified snapshot exactly.
The final default verifier compiled natively, and the source-policy gate passed
again. [final-sources.sha256](final-sources.sha256) identifies these final files.
The supplementary commands and results are in [integration.tsv](integration.tsv).
README, coverage, roadmap, and completion-record updates also follow the snapshot.

One supplementary invocation of `bend tools/verify.bend` started the entire
default native suite unintentionally. Its owned process group was stopped at
exit 143. It is not counted as a passing full-native run. The partial log remains
at `build/json-scene/native-entrypoint-check.log`. The intended native build used
`bend tools/verify.bend -o build/json-scene/default-verifier` and exited 0.

## Acceptance and ownership

One implementation owner keeps the parser adapter, schema, IO, laws, and drivers
in this change. `src/json-boundary.bend` owns strict byte parsing and bounded
reads. `src/scene-file.bend` owns version 1, typed references and placements,
source loading, and admission through `Creation.compile`.

Success means a disk scene produces the exact authored meshes, materials,
transforms, part order, and shared geometry through existing engine consumers.
Failures must return `Asset.Error` before a scene or engine resources are
created. Schema, F32 ranges, duplicate decoded keys, asset references, and
resource limits are all required boundary checks.

## Parser qualification

`tools/json-scene/qualify.bend` reads the retained manifest with both S44
candidates. The native probe preserves the integer token `9007199254740993`
exactly in bend-kit-json. It rejects duplicate and escaped-equivalent keys,
nested duplicates, invalid surrogates, leading-zero numbers, trailing text,
and containers beyond the chosen cap. The same duplicate-key input is accepted
by ezjson. This makes the kit's existing strict mode the smaller adapter.

The production imports use content hashes, not a mutable package name.

| Package | Revision | Entry |
| --- | --- | --- |
| bend-kit-json 0.7.0.0 | `0x37aacddc1dcb57464b8b5ac6c397bd64` | `json.bend` |
| bend-kit-bytes 0.3.3.0 | `0x632652e3c1c0183f12728faf3870bb68` | `bytes.bend` |
| ezjson 1.4.0.0, qualification only | `0xdab377b48b4edd8247427c10e2120805` | `main.bend` |

The kit packages contain no LICENSE file. The pinned Bend guide defines
unlicensed BendHub packages as MIT-0. No upstream package source is vendored.
The OBJ and PNG files in `corpus` are copies of existing engine-authored
verification assets. `corpus/SHA256SUMS` binds their exact bytes.

## Required evidence

The `json` workflow profile selects the toolchain and source-policy checks,
root frontend proofs, existing Asset runtime checks, `verify-json`, and root
law mutation controls. `verify-json` executes the following checks sequentially.

- Native qualification of both pinned parsers on real input.
- Exact source comparison against the independently authored sign model and
  two known transforms, plus actual Creation compilation.
- Real-file schema, syntax, range, duplicate, path, reference, and size rejection.
- Accepted boundaries at 65536 bytes, 64 assets, and 256 placements. Generated
  real OBJ files accept 4080 expanded parts and reject 4097.
- Cache success and failure retention, released-handle rejection, fresh retry,
  and source use after cache release.
- Two real ECS snapshots and exact offscreen RGBA/D32 comparison with the
  independent reference, retained replay, and zero live Vulkan objects.
- Six isolated production regressions for duplicate keys, unknown fields,
  numeric range, wrong asset kind, byte limit, and nesting depth.
- The restored runtime baseline and the public command-line example.

Eight new root laws cover guards, supplied-byte size, incomplete reads, image
references, missing references, model-part preservation, admitted-scene
compilability, and the chosen nesting cap. Two new root mutation controls check
depth and part preservation. These are Bend frontend checks. There is no new
independent kernel verdict for the parser or IO.

The first required workflow attempt is retained at
`build/verification/workflow-U6Hmdaq9`. It stopped at the source-policy gate
because the new content-addressed packages had not been allowlisted. Its
remaining stages were not run. The correction adds only the reviewed JSON
package symbols and extends inventory generation to recognize hash imports.
Raw upload permissions remain unchanged.

## Limits

The [schema reference](../../json-scene.md) defines the supported flat format.
No hierarchy, texture binding, camera schema, new backend, performance result,
X11 interaction, or symlink confinement is claimed. Numbers are checked after
conversion to F32, with rounding and underflow stated explicitly. The native
runtime and parser remain trusted beyond the proved adapter properties.
