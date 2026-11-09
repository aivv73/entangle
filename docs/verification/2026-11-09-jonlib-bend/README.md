# Standalone Jonlib OBJ and PNG on Bend 2.0.40

## Acceptance

The two vendored source closures run on stock Bend 2.0.40, revision
`624dd9f4607cd29b0871a9b96d413bfb11e92f52`, built with Bun 1.4.4.
Bend's latest stable release was checked against its official release page
on November 9, 2026. Both closures retain upstream Jonlib revision
`5e49707e346453f7d36c27d5ca0cb286e431973d`, which is also the current upstream
`main`. The full Jonlib compiler overlay is outside these source closures.

Production functions are `deps/jonlib-obj/obj.bend` and its seven numeric
helpers, and `deps/jonlib-png/{png,codec,inflate}.bend`; their engine consumers
are `src/model-obj.bend` and `src/image-png.bend`. Successful parsing, exact
geometry/pixels, failure codes, limits, file ownership, and cache/retry behavior
must retain their existing contracts. No source rewrite or checksum change is
needed just to adopt the compiler version.

The two dedicated drivers now enforce the repository Bend version before
running. A real Bend 2.0.39 invocation must fail with the named version error,
and the restored 2.0.40 configuration must run the existing required checks.

## Required evidence

- `bend tools/verify-workflow.bend -o build/jonlib-bend-2.0.40/verify-workflow`
  and `--plan native images json` retain the registered dependent checks.
- `bend tools/verify-images.bend` covers PNG corpus pixels, malformed input,
  resource limits, real file errors/ownership, cache/retry, and production
  sensitivity controls.
- `bend tools/verify-models.bend` covers numeric/parser qualification, exact
  source fidelity, properties, limits, files/cache, isolated source closure,
  production sensitivity controls, and native ECS/offscreen consumers.
- `bend PROOF.bend` checks the frontend laws. It is not a kernel verdict or
  proof of the entire engine or decoder.
- A native JSON scene consumer checks the shared OBJ dependency used by the
  JSON loader.

## Results and receipts

Direct-run logs and the selected workflow plan are retained in
`build/jonlib-bend-2.0.40/`. `sources.sha256` beside this record identifies the
compiler pin, validation entry points, adapters, and vendored sources used.

| Check | Result | Evidence |
| --- | --- | --- |
| PNG version guard with real Bend 2.0.39 | Expected exit 1, named compiler mismatch before decoder execution | `verify-images-version-rejection.log` |
| OBJ version guard with real Bend 2.0.39 | Expected exit 1, named compiler mismatch before parser execution | `verify-models-version-rejection.log` |
| PNG complete dedicated suite, stock Bend 2.0.40 | Passed: all 25 retained images match every pixel; file/decode errors, ownership, cache/retry, and all four production mutations checked | `images-final.log` |
| OBJ complete dedicated suite, stock Bend 2.0.40 | Passed: numeric qualification, exact source and generated properties, bounds, file/cache ownership, source-only closure, four production mutations, two ECS snapshots, complete offscreen RGBA/D32 and zero live Vulkan objects | `models-final.log` |
| Root frontend proofs | Passed; no whole-engine or kernel-proof claim | `proofs.log` |
| Native JSON scene consumer | Passed: 6 instances, 18 vertices, 18 indices, 3 ranges | `json.log` |
| Vendored source/license checksums | Passed; original pins remain intact | Existing `deps/jonlib-{obj,png}/SHA256SUMS` |

The registered `native images json` workflow produced the source-specific
receipt `build/verification/workflow-Prug8ZSB`. Its `state` is `failed`,
`run.status` and `toolchain.status` are 1, and subsequent stages are `not_run`.
The previously identified Clang distribution preflight blocks that workflow:
the official Clang 23.1.4 archive includes a revision on its version line and
defaults to `x86_64-unknown-linux-gnu`, whereas Entangle requires a bare version
line and `x86_64-pc-linux-gnu`. No compiler output is spoofed. The direct
dedicated-suite results above do not turn that workflow into a pass.

The initial PNG run passed exact pixels and malformed-input/cache checks but
reported a descriptor-count mismatch (`images.log`). An unchanged syscall-traced
run, three standalone reruns, and the final complete suite passed. The
measurement launches `ls /proc/<pid>/fd` through `Process.run` and includes
the sampler's subprocess pipes. The first mismatch is retained as an
intermittent verifier limitation; tracing did not establish a persistent file
leak. The descriptor equality assertion was not removed or weakened.

No window behavior or GPU performance change is intended. X11/Wayland-owned
presentation and CUDA/Metal performance are outside this compatibility check.

The compatibility change is implemented and directly verified. No upstream source,
license, original hash manifest, engine law, or dependency revision changed.
Validation ran on uncommitted sources; no environment publication was performed.
Before claiming a
passing registered workflow, qualify a Clang distribution satisfying the
repository preflight and rerun `native images json`.
