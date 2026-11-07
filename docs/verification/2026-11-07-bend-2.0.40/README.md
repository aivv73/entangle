# Bend 2.0.40 upgrade

## Acceptance

Entangle uses unchanged Bend 2.0.40 release source built with Bun 1.4.4 and the
existing Clang target. Its Vulkan dependency includes the pointer ABI migration.
The native applications, asset consumers, rendering,
input replay, frontend proofs, kernel proofs, and sensitivity controls retain
their existing observable contracts.

`toolchain.bend`, `tools/verify.bend:preflight`, and
`tools/verify-headless.bend:preflight` enforce the compiler pin. Both window
launchers must invoke that preflight instead of maintaining separate Bend
version literals. One owner keeps the pin, launchers, coverage, and evidence
together. Engine algorithms and formal claims change only if qualification
shows an incompatibility.

Before migration, qualify the release with the real component consumer and
its independently specified field/default output, then run `bend PROOF.bend`.
Require source-specific workflow receipts for `native hierarchy textured-window`
and `math`. Their required stages cover the `all` plan. Also require the separate
`tools/model-obj/window-session.sh` run and the affected headless check.
Require every selected stage
to finish successfully, inspect window captures and replay output, and retain
cleanup evidence. A failed or unexecuted stage remains a failure or a gap.

## Release

- Previous compiler: Bend 2.0.39.
- Release: [official Bend 2.0.40](https://github.com/bendlang/bend/releases/tag/v2.0.40),
  source `624dd9f4607cd29b0871a9b96d413bfb11e92f52`.
- Official installer: `https://bend-lang.com/install.sh`, downloaded and read
  before execution. It pins the Linux x64 archive SHA-256 to
  `c9ff8d67bd903fb6ad9a26b43d8a62c01021de82a44d55ce4a3dcd4732113d6b`.
- Clang remains 23.1.4, targeting `x86_64-pc-linux-gnu`.
- Vulkan compatibility commit: `979a8c2840dcdfd53f41cd70ebaed8de74ec8bed`,
  based on the previous `a144f7d` pin. It is local and unpushed. The
  [retained patch](bend-vulkan.patch) makes its source changes reviewable.
  Bendvy and bend-collections retain their existing revisions.

## Compatibility changes

The first real component consumer passed. The first root proof check rejected
the removed `Mouse` constructor. The production X11 bridge now emits Bend's
`Press` and `Move` layouts, mouse tool and identity, signed F32 coordinates,
32-bit timestamps, and W3C button numbering. Scroll coordinates use F32 words.
The existing release batch ends with `Lost{0}`. Its matching focus-boundary law
preserves the complete batch and arbitrary suffix.

The published `bend-ui-test@0.1.0.1` package also uses `Mouse`. A source copy
under the pinned Vulkan dependency adapts its plan and native decoder to
`Press`. All Entangle window consumers use that adapter. The dependency's
verification bridge registers only reachable effects. Both window launchers
call `verify-toolchain` and use the central compiler pin.

The official Linux archive embeds Bun 1.3.14. Its compiler overflows on
`tools/verify-mesh-window.bend`, including when emitting C. Increasing the
process stack and JavaScriptCore stack options did not resolve this. Running
the exact release source with Bun 1.4.4 and compiling that source into a new
executable both generate the driver successfully. No compiler logic changed.
`tools/build-bend-toolchain.bend` reproduces that build from the exact release
revision and requires the pinned Bun version. It checks real component output
and builds the full native window driver. Both preflight paths check the
embedded Bun version so the archive fails early instead of failing deep in a
window run.

## Qualification and verification

The real X11 pointer baseline, old-button-mapping production regression, and
restored baseline passed in
`build/verification/pointer-controls-EyYvTk3V`. The regression exits one and
names `Pointer Press ABI mismatch`. Positive runs verify event fields and
zero-object shutdown. `verify-pointer-mutations` repeats this control in every
owned window session, using disposable production-source copies.

Earlier workflow receipts `workflow-dkwRQpcr` and `workflow-lDV2ujOP` failed
the source policy on the new adapter and pointer type. The reviewed policy now
lists their exact symbols. `workflow-FidFon02` was interrupted at publication
with status 143 when replacing the compiler host. These are not passing
receipts.

`workflow-VWpm3Tcw` passed toolchain, source policy, and publication controls,
then rejected the math qualification's missing `Create.Parented` branch.
This was verifier drift after the hierarchy feature. The qualifier now checks
the parented instance's local transform with the same numerical contracts.
The acceptance is split into product and math receipts to keep those checks
independent. No required stage is removed.

The focused math run also found an obsolete packed-geometry baseline from
before UVs and normals. All historical ECS, RGBA, and D32 files still match.
A fresh real Bend 2.0.39 build of the current native consumer produced
[complete expanded geometry](baseline-2.0.39/README.md) that matches 2.0.40
byte for byte. The math gate uses those full packed files and keeps the other
historical comparisons. It does not drop fields or overwrite the old record.

The source builder passed at
`build/toolchains/bend-2.0.40-9KLlzJQ7/qualification.txt`, with `run.status=0`.
The original archive is also retained as a preflight sensitivity control:
it exits one with `Expected 1.4.4; found 1.3.14`. The installed compiler and
Base hashes are in `build/bend-upgrade/installed-toolchain.sha256`.

The headless gate passed in
[`headless-upgrade-vIRgjA8N`](../../../build/verification/headless-upgrade-vIRgjA8N/run.log)
with no display variables. It checks eight production ticks, zero preservation,
all nine splits, full transform/identity bits, receipts, and detached retention.

The separate OBJ window run passed in
[`model-window-Nr56qumS`](../../../build/verification/model-window-Nr56qumS/commands.log).
Every status is zero. The sign, wedge, and reversed-face captures were inspected:
the positive inputs show their expected geometry, and reversed faces are
clear-only. All native logs report zero live objects without validation errors.
The recorded display process is gone and the runtime directory was removed.

The source-specific math receipt
[`workflow-lZvAaoHk`](../../../build/verification/workflow-lZvAaoHk/manifest.tsv)
is complete with `run.status=0` and every required stage at zero. It includes
the new toolchain preflight, source policy, root frontend proofs, publication
controls, exact adapter/retained-scene checks, and root law mutations with
restored baselines.

The product receipt
[`workflow-TTt8gDVH`](../../../build/verification/workflow-TTt8gDVH/manifest.tsv)
is complete with `run.status=0` and all 22 required stages at zero. It covers
publication, hierarchy, the full native gate, extended windows, the upload
kernel verdict, hierarchy frontend/kernel checks, law and upload-policy
controls, bounded native failure/lifetime controls, bundle correspondence,
presentation ownership controls, and every restored baseline. The window evidence is
[`entangle-3zm1jVvI`](../../../build/verification/workflow-TTt8gDVH/source/build/verification/entangle-3zm1jVvI/commands.log).
All window statuses are zero. The six player axes, queued focus loss with
zero steps, resize/restore, both exits, and complete ECS replay pass. Initial,
held, reset, textured, and hierarchy captures were inspected. Mesh, texture,
and hierarchy resets compare byte for byte. Every application reports zero
live native objects with clean validation. The owned display and runtime are
gone.

## Scope and state

Implementation and selected verification completed locally on November 8,
2026. Production sources, examples, proofs, and toolchain pins match the
product snapshot. Its only verifier difference is the repaired math baseline
path, covered by the complete math receipt. Documentation records the final
results after those snapshots. The dependency compatibility commit remains
local and unpushed. This record makes no publication or merge claim.

Existing historical 2.0.39 evidence
retains its original version and revision. Available-device Linux Vulkan
checks do not establish other-backend behavior, performance, compiler
soundness, or the hierarchy certificate-construction obligations that remain
open in `proofs/hierarchy/plan.md`. Bend verification used one CPU thread with
GPU dispatch disabled. Its CUDA and Metal execution lanes were not exercised.
