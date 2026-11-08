# Update bend-ui-test

## Acceptance and required evidence

Use the latest published bend-ui-test version observed on November 8, 2026,
with an immutable package hash or upstream source revision. Replace the old
Bend 2.0.40 compatibility copy when the published implementation supports the
pinned compiler. All seven current window drivers must use the same version.

Before changing consumers, compile and run an upstream native consumer against
an owned X11 window. Require the known key/click/Close input and lifecycle
results. Retain the upstream revision, package metadata, command, and output.
The input boundary is `UI.send_to`; production event handling and rendering
must retain their existing behavior.

Required verification is root `bend PROOF.bend`, source policy, the
`textured-window` workflow profile (all six renderer windows, pointer sensitivity,
full-state replay, resize/Close, cleanup, and presentation prerequisites), and
the separate OBJ window consumer. Inspect captures and validation logs. Keep
the source-specific workflow receipt. No traditional tests or mocks are added.
Existing laws and sensitivity controls remain applicable unless the upstream
API requires a behavior change; any such change needs corresponding evidence.

This verifies the available Linux X11/Vulkan lane and synchronous renderer.
It does not certify other backends, performance, or outstanding general
hierarchy proof obligations. One owner keeps source, dependency policy,
coverage, and this task record together.

## Selected release and qualification

The live [BendHub namespace](https://hub.bend-lang.com/n/bend-ui-test) reports
`bend-ui-test@0.1.0.2` as the latest release. Its immutable content hash is
`0x614861e9d7b7bc38bc65b16aa435d067`. All seven drivers import its
`uitest.bend` entry directly. The obsolete local input adapter and its trusted
source exemption are removed. The source policy permits only the new package
and the existing `send_to` operation.

The package's four implementation files match upstream GitHub commit
[`7214ab1961024a1cb93fe6576cce93166a141001`](https://github.com/aivv73/bend-ui-test/commit/7214ab1961024a1cb93fe6576cce93166a141001)
byte for byte. The transitive window-reference package is pinned to
`0xc49b12025f945d56de002cde2237ecc5`. The Hub terms supply the default MIT-0
license when a package has no license file. No compiler, renderer, Vulkan,
Bendvy, capture, or collections pin changes.

The [qualification receipt](../../../build/verification/bend-ui-test-qualification/)
retains live namespace and package metadata, the published implementation,
and an upstream smoke consumer importing the named release. The smoke consumer
and upstream native consumer both pass on an owned Xwayland display. The native
consumer checks real key and click event pairs, Close, two-window isolation,
invalid pointer rejection, stale references, and all 260 codes in the active
keyboard map. The display is reaped and `run.status=0`. The upstream
`bend PROOF.bend --verdict` also passes for its three pure key, click, and Close
plan laws. Engine laws remain unchanged.

## Verification results

The `textured-window`
[workflow receipt](../../../build/verification/workflow-7oJw7Grw/manifest.tsv)
is complete with `run.status=0` and all 13 required stage statuses at zero.
The [receipt audit](../../../build/verification/bend-ui-test-qualification/workflow-audit.txt)
confirms those results. Root `bend PROOF.bend` passes the frontend check.
Source policy, native-window correspondence, publication and law sensitivity,
and bounded production presentation proofs with their controls and restored
baselines all pass. The presentation proofs retain their documented symbolic
boundaries and topology limits.

The [live window receipt](../../../build/verification/workflow-7oJw7Grw/source/build/verification/entangle-xKtNO9Ji/commands.log)
covers mesh, cube, public creation, replacement, textured, and hierarchy
windows. All driver statuses are zero. Real held input, camera controls,
focus loss, resize, restore, Close, complete-state replay, and zero-object
shutdown pass. The pointer ABI baseline, named production regression, and
restored baseline pass. Captures were inspected. Mesh, texture, and hierarchy
reset files match their initial captures byte for byte. Validation logs are
clean, and the owned display and runtime are absent. The
[window audit](../../../build/verification/bend-ui-test-qualification/window-audit.txt)
retains these observations.

The separate [OBJ window receipt](../../../build/verification/model-window-Al5u6yhf/commands.log)
also has every stage and `run.status` at zero. The sign, wedge, and reversed-face
captures were inspected: the positive inputs show geometry, and reversed faces
are clear-only. Actual Close, clean validation, zero live Vulkan objects, and
display/runtime cleanup pass. The
[OBJ audit](../../../build/verification/bend-ui-test-qualification/obj-audit.txt)
records the checks.

The [source audit](../../../build/verification/bend-ui-test-qualification/source-audit.txt)
confirms that current executable sources, fixtures, policy, laws, and toolchain
match the passing snapshot. Markdown results were updated afterward.

## Compiler stack environment

The complete workflow and OBJ run use the pinned compiler with a 32 MiB
JavaScript stack budget and a 64 MiB process stack. The
[host option output](../../../build/verification/bend-ui-test-qualification/compiler-stack-options.log)
confirms `maxPerThreadStackUsage=33554432`, replacing the 5 MiB default.
The [workflow environment](../../../build/verification/workflow-7oJw7Grw/compiler-environment.txt)
retains these settings. Reproduce them with:

```sh
ulimit -s 65536
BUN_JSC_maxPerThreadStackUsage=33554432 \
  VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation VK_LAYER_VALIDATE_SYNC=1 \
  ./build/verify-workflow textured-window +RTS --threads 1 --gpu off
BUN_JSC_maxPerThreadStackUsage=33554432 bash tools/model-obj/window-session.sh
```

Earlier receipts `workflow-PAOdUrhF` and `workflow-6bwRy5QI` failed while
compiling the unchanged cube application with the default stack budget.
Their later stages remain unexecuted. Direct builds, including one inside the
first snapshot and one through native `Process.run`, succeeded. The compiler
failure's exact cause remains undiagnosed; the larger stack budgets allowed
the complete gate to pass. No compiler source or application workaround was
introduced, and the unsuccessful receipts remain retained.

## State

Implementation, qualification, and all required verification completed locally
on November 8, 2026. No required check remains skipped or unfinished. This
record makes no publication or merge claim.
