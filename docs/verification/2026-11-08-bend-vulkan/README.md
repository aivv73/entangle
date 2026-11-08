# Update bend-vulkan to GitHub main

## Acceptance and required evidence

Entangle pins the latest published GitHub main revision observed on November 8,
2026: bend-vulkan `190023575c64915677ae02e4d5ef082b51c239e9` and its
bend-collections fork `32526a9a3d82ffc988bf4a122f8c37240a70a87b`.
Both submodules must remain clean and reproducible from their published URLs.
Bendvy and the qualified Bend 2.0.40 toolchain retain their existing pins.

The public Vulkan API and native resource implementation match the previously
used Entire revision `a144f7d`. GitHub main lacks that revision's standalone
window example and verification helpers, and its X11 poll still constructs
the removed `Mouse` event despite advertising Bend 2.0.40. Preserve Entangle's
existing input and rendering behavior through an engine-owned native adapter
and the existing real-window drivers. Do not change rendering or lifetime
semantics to accommodate the dependency update.

One owner keeps the dependency pins, window boundary, source policy, mutation
controls, feature coverage, and this record together. `toolchain.bend` and
`tools/verify.bend:preflight` enforce the dependency pins. The native window
adapter must be generated deterministically from the pinned upstream X11
implementation, retaining the already qualified Bend 2.0.40 pointer conversion.
Its correspondence check and real pointer baseline/regression/restoration are
required evidence.

Before accepting the adapter, build and execute the actual upstream buffer
roundtrip and Entangle pointer consumer. Require source-specific workflow
receipts for `native hierarchy textured-window`, root `bend PROOF.bend`, and
the separate OBJ window scenario. Existing frontend, kernel, bounded native,
production sensitivity, rendering/readback, full-state replay, resize/Close,
and cleanup contracts remain required. Inspect real captures and validation
logs. Missing, failed, or unexecuted stages remain gaps.

These checks cover the available Linux Vulkan device and synchronous renderer.
They do not establish other-backend behavior, performance, compiler soundness,
or the outstanding general hierarchy certificate-construction obligations.

## Results

The [qualification receipt](../../../build/verification/vulkan-qualification-Hy047NLw/)
records the live upstream revision and unchanged Vulkan API, native handlers,
selection and upload helpers, and U64 source. The validation-enabled buffer
roundtrip and root `bend PROOF.bend` pass. The final upstream check still
reports `1900235` as GitHub main.

The `native hierarchy textured-window`
[workflow receipt](../../../build/verification/workflow-Tm10tz1F/manifest.tsv)
is complete with `run.status=0` and all 23 required stage statuses at zero.
The [receipt audit](../../../build/verification/vulkan-qualification-Hy047NLw/workflow-audit.txt)
confirms those results. Coverage includes source policy and adapter
correspondence, frontend proofs, upload and hierarchy kernel checks, real
native consumers, retained rendering, complete-state replay, law and source
regressions, bounded native failure and presentation proofs, and restored
baselines. These evidence kinds retain their documented limits.

The [window audit](../../../build/verification/vulkan-qualification-Hy047NLw/window-audit.txt)
records clean validation, exact mesh, texture, and hierarchy resets, inspected
captures, and removal of the owned display and runtime. The live evidence is
[entangle-AIJ6Egvr](../../../build/verification/workflow-Tm10tz1F/source/build/verification/entangle-AIJ6Egvr/commands.log).
All application and driver statuses are zero.

The new pointer
[control receipt](../../../build/verification/workflow-Tm10tz1F/source/build/verification/pointer-controls-koF8r3JV/)
rejects the deliberate middle/right mapping through both adapter
correspondence and the real `Pointer Press ABI mismatch` property. Both
negative commands exit one. Restored correspondence and runtime commands
exit zero.

The separate [OBJ window receipt](../../../build/verification/model-window-zEglIZ5k/commands.log)
passes every stage with `run.status=0`. The sign, wedge, and reversed-face
captures were inspected. Positive inputs show their expected geometry;
reversed faces are clear-only. Actual Close, zero live Vulkan objects, clean
validation, and removal of the owned display and runtime all pass. The
[OBJ audit](../../../build/verification/vulkan-qualification-Hy047NLw/obj-audit.txt)
retains the checks.

The [source audit](../../../build/verification/vulkan-qualification-Hy047NLw/source-audit.txt)
confirms that current production code, verification drivers, fixtures, and
dependency files match the retained workflow snapshot. Markdown documentation
was updated afterward. All pinned dependency checkouts remain clean.

Earlier `workflow-RLXqgAzi` stopped during setup because Bendvy's shallow partial
clone could not be copied. Fetching its remaining history repaired the local
Git metadata without changing its revision. `workflow-4Sophzjw` rejected the
new native-effect declarations before their reviewed source hashes were added
to the existing source policy. Both receipts remain unsuccessful.

## State

Implementation and selected verification completed locally on November 8,
2026. No required check remains skipped or unfinished. This record makes no
publication or merge claim.
