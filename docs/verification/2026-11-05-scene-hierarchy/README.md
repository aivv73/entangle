# E4 scene hierarchy: November 5, 2026

Task: [Trail 31](https://entire.com/et/bend-engine/-/trails/31).
The task is closed for implementation, verification, and performance evaluation.
Verification used the uncommitted implementation on top of `dc70d54`.
[Trail 31](https://entire.com/et/bend-engine/-/trails/31) records subsequent commit
and publication state. The [contract](../../scene-hierarchy.md) records the semantics and
acceptance criteria established before implementation.

## Implemented

Creation descriptions and version 1 JSON accept optional parents, including
forward references. JSON placement references are translated to model-part
anchors. The real ECS owns local transforms, relationships, source bounds, and
rollback checkpoints. Full sequential derivation publishes complete affine
globals and per-object world AABBs. Public edits reject invalid graphs, handles,
and numerical state before writing; scheduled invalid spatial results restore
accepted locals. Both renderers consume the resulting world transforms.
Inverse-transpose normal matrices preserve lighting with nonuniform ancestor
scale, rotation, and shear. Flat root draws retain their representation.

## Verification status

The final `native hierarchy textured-window` workflow passed on the frozen
snapshot `build/verification/workflow-a8yf31nk`: `state=complete`, `run.status=0`,
and all 15 required stages returned zero. The [manifest](workflow/manifest.tsv),
[stage statuses](workflow/stages.tsv), arguments, logs, toolchain records, and
source hashes are retained here. No required stage was skipped.

Verified behavior includes:

- Actual ECS flat forests, a 128-node chain, and 63-node branching trees;
  parent translation/rotation/scale, reparenting/detachment, independent branches,
  scheduled updates and rollback, invalid handles/links, numerical rejection,
  and real JSON forward references and model-part anchors.
- Eight hierarchy render states against independent geometry and normal
  calculations, plus complete-state replay of 17 runtime commands.
- Passing runtime/render baselines, seven named production regressions detected,
  and seven restored passing baselines. The regressions break cycle detection,
  composition, bounds, publication, JSON expansion, normal matrices, and static
  draw extraction. [Detailed controls](hierarchy-controls/) preserve the expected
  nonzero rejection statuses; those are successful sensitivity observations.
- Eleven new frontend hierarchy laws and five hierarchy law controls, alongside
  the existing root laws, standalone upload kernel verdict, source-policy
  controls, and bounded native-handler proofs and mutations.
- Existing native asset, image, OBJ, JSON, texture, flat-scene, rendering, timing,
  and resource-recovery gates. The extended owned-window suite passed for mesh,
  cube, creation, replacement, textured, and hierarchy consumers.

The final window evidence is `entangle-q9qdX0GO` inside the snapshot. Hierarchy
replay matched 23 commands; mesh replay matched 1492 live batches and 27 hidden-Close
batches. Parent edits changed the captured geometry; rejected edits preserved
pixels; reset matched the initial image byte for byte. Resize/restore/Close,
validation, and zero-live-object checks passed. The [window log](window/hierarchy-window.log),
[replay](window/hierarchy-replay.log), [initial capture](window/initial.png),
[scaled capture](window/scaled.png), and [cleanup record](window/cleanup.log)
are retained. The owned display was reaped and its runtime directory removed.

After the run, all 189 code, driver, law, and proof files matched the snapshot's
hashes ([check record](workflow/live-code-check.log)). Only documentation and
result records were updated afterward. The original snapshot remains the
reproducible source receipt; later prose does not replace its source fingerprint.

The new checks execute production ECS and Vulkan paths. The numerical oracle
walks local transforms directly rather than using production matrix composition.
The lighting oracle builds normals from transformed tangents. Render comparison
covers complete RGBA/D32 output, with one UNORM step and `2e-6` depth tolerance.
Replay compares complete local/accepted/global/bounds and entity identity bits.
Root laws quantify production expressions; they are frontend checks, not a
kernel theorem of arbitrary graph or floating-point correctness. The existing
standalone upload kernel verdict remains a separate check.

## Constrained performance evaluation

One performance change was attempted and retained after the final correctness
receipt passed. No parallel or incremental evaluator was introduced.

The initial 1000-node phase probe measured about 485 ms reading ECS components,
0.92 ms deriving the forest, and 28.6 ms committing it. These were diagnostic
measurements under concurrent build load, not the comparison results below.
Inspection located repeated reconstruction of live handles in the per-component
inspector path. The hypothesis was that one captured ECS scope, retaining checked
namespace/generation access, would eliminate that repeated work. The declared
targets were publication time down at least 50% and end-to-end offscreen time down
at least 30%.

The comparison used five alternating pairs (order reversed each pair), six
accepted root updates per timing interval, one warm update/frame, native Bend
with one CPU thread and Bend GPU dispatch off, and an actual 256×256 Vulkan render and
readback per frame. Creation and output validation are outside the measured
interval. Every pair had identical complete ECS state and RGBA/D32 bytes.
Counters require all requested updates, valid analytic forest state, drawn
coverage, and zero live Vulkan objects after the scope.
The workloads use shared unlit quad geometry: a flat grid, a deep chain, and
a binary tree. Root translation alternates between two values. These timings
measure hierarchy publication and its rendering consumer, not asset loading,
complex-material throughput, or a presented window's frame rate.

Machine: AMD Ryzen 5 1600, 12 logical CPUs, GTX 1660, NVIDIA 615.78.08,
Linux x86-64, Bend 2.0.39, Clang 23.1.4. Ordinary desktop/browser processes were
active. The final-source repeat also overlapped a verification build; alternating
order gives both versions exposure to that load. An earlier run without a
concurrent compiler gave the same verdict. These are
wall-clock results for this machine, not a throughput limit or real-time promise.
The offscreen numbers include extraction, draw recording, rendering, and readback.

Values are median milliseconds per update/frame, with the range of five runs.

| Workload | Measurement | Baseline ms (range) | Captured read ms (range) | Reduction |
| --- | --- | ---: | ---: | ---: |
| Flat 1000 | publication | 513.17 (493.06–531.65) | 65.85 (64.83–72.62) | 87.2% |
| Flat 1000 | offscreen-frame | 1010.44 (987.87–1044.26) | 188.50 (185.78–194.93) | 81.3% |
| Chain 256 | publication | 32.22 (31.58–32.55) | 5.96 (5.90–6.24) | 81.5% |
| Chain 256 | offscreen-frame | 149.47 (148.59–151.23) | 101.03 (100.07–103.65) | 32.4% |
| Branches 1023 | publication | 527.11 (518.49–547.10) | 70.47 (67.80–72.96) | 86.6% |
| Branches 1023 | offscreen-frame | 1035.19 (1033.14–1070.14) | 192.64 (188.52–194.49) | 81.4% |

The flat 1000-node workload set the target. The chain and branching workloads
were additional validation scenes. All met both targets; no second or third
performance change was attempted. Even the improved ~66 ms publication at 1000
nodes is unsuitable for a 60 Hz update budget. Checked membership/commit and
full-scene work remain costs for future measurement. E5 remains separate.

These results include the final textured-root detachment admission guard,
rejection scenarios, and migrated consumer extraction. The same candidate passed
the complete source-specific correctness workflow. The [raw timings](performance.log), [source hashes](performance-sources.sha256),
[machine record](performance-machine.txt), and [chart](performance.html) are retained.

## Retained evidence and reproduction

Original evidence remains under `build/verification`:

- `workflow-a8yf31nk/`: complete final receipt and frozen sources, including
  `hierarchy-controls-lJ4oLfEx`, `entangle-q9qdX0GO`, `law-mutations-KLQblLYM`,
  `upload-mutations-hpbwjwhm`, and `native-formal-AZEYmNQ5` nested under
  `source/build/verification`. Selected logs and statuses are copied into this
  record; the full snapshot, traces, captures, and executables remain there.
- `hierarchy/`: decision trail, early runtime/render/replay logs, phase probe,
  comparison output, and build diagnostics.
- `hierarchy-controls-EPWHKwxX/`: passing baseline, six named production-source
  regressions, and six restored passing baselines.
- `hierarchy-measure-RUOmhiH9/`: all 30 comparison runs, exact state and image
  output, binary/source hashes, and machine information.
- `hierarchy-measure-5p2B0oeK/`: repeat of all 30 runs after the detachment guard, copied
  baseline/candidate executables, source hashes, full state/image comparisons,
  and machine/load information, before the last consumer migration.
- `hierarchy-measure-u8uQ1E0f/`: repeat after the consumer migration, with all 30
  runs' state/image outputs and both executables retained. This is the source
  of the table above. Baseline and candidate production sources differ only in
  the checked read path in `scene-hierarchy.bend`.
- `hierarchy-baseline-source/`: isolated baseline source and executable.

Run the registered workflow from the repository root:

```sh
bend tools/verify-workflow.bend -o build/verify-workflow
./build/verify-workflow --plan native hierarchy textured-window
./build/verify-workflow native hierarchy textured-window +RTS --threads 1 --gpu off
```

The focused profiles are `hierarchy hierarchy-window`. The
[feature map](../../../.agents/skills/verify-entangle/features/scene-hierarchy.md)
lists driver coverage and sensitivity expectations.

## Failed attempts and limits

Two early X11 attempts failed because the fixture used an offscreen camera with
window back-face culling, then because its supposed red texel was yellow. A third
standalone build encountered a temporary source parse error while the worktree
was being edited. Their evidence and cleanup records remain in
`entangle-z0JZWcAV`, `entangle-pZqHfv3U`, and `entangle-5PZIpxQ7`.
None is counted as a pass. Final workflow execution uses an isolated snapshot.

`entangle-LSokbavf` passed the hierarchy window and its 23-command replay, and the
mesh live scenario and 1427-batch replay. Hidden Close itself passed, but its trace
contained fewer than the replay gate's required 11 completed batches. The driver
now waits for recorded batches before closing. `workflow-CFQRV3cA` stopped at
source policy because the new JSON Null constructor and checked ECS access
symbols were absent from the reviewed inventory. The inventory now lists those
exact symbols. These failed receipts remain evidence of the corrected workflow,
not complete passes.

`workflow-aZeP21qn` was explicitly stopped and superseded after a consumer audit
found local-only draw construction in the mesh and textured examples. Both now
use the shared derived draw path, as do Creation/OBJ/JSON consumer snapshots.
Two extraction laws and a static-consumer sensitivity control were added before
the fresh `workflow-a8yf31nk` run. The superseded receipt is not a complete pass.

This scope excludes runtime spawn/despawn, preserve-world reparenting, subtree
bounds, runtime mesh/material rebinding, incremental propagation, persistent RenderScene, collision/culling use
of bounds, and CUDA/Metal/WebGPU execution claims. Negative scale preserves
affine semantics; existing window face-culling policy still applies. Numerical
normal-matrix limits are explicit admission constraints, not a proof of good
conditioning for all inputs. Resource lifetime algorithms and dependency pins
are unchanged.

Source-free legacy seed fixtures carry empty bounds because they contain no mesh
data. Use `Creation.compile` for geometry-derived bounds and lighting metadata.
Hierarchy laws are not a kernel proof of arbitrary forests, and this runtime
evidence does not establish CUDA, Metal, WebGPU, or other hardware behavior.
The hierarchy item is implemented and verified; E4 as a whole and E5 remain
incomplete. Task closure and code publication are recorded separately in Trail 31.

