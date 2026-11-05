# Develop and verify Entangle

Keep one owner for coupled production code, laws, and verification. Ordinary features and refactors do not require architect, arena, or adversarial-review panels. Delegate a bounded independent probe only when it answers a named uncertainty. Model-role configuration does not require a panel.

## Before implementation

In the existing task or Trail, record the observable outcome, the production functions that enforce it, the required checks, and their limits. Qualify an unfamiliar dependency with a small real input and an independently known output before designing the adapter. Keep that probe and its pinned dependency revision.

Use real files and native consumers for effects. Prove important general properties against production definitions. For rare driver results that cannot reliably be induced by valid runtime inputs, state the symbolic boundary and bounded proof scope in advance. Preserve the distinction between Bend frontend checks, kernel verdicts, bounded CBMC proofs, and observed hardware behavior.

A new or changed critical verifier needs a sensitivity control. The original implementation passes, a deliberate production-source regression violates the named property, and restored sources pass. A timeout, compiler crash, parse error, or unrelated rejection does not establish sensitivity. Fix the verifier when its oracle is wrong; do not weaken the production contract to make it green.

## Run verification

Run from the repository root. Build the runner natively so large evidence manifests do not depend on the interpreter stack.

```sh
bend guide
mkdir -p build
bend tools/verify-workflow.bend -o build/verify-workflow
./build/verify-workflow --plan assets images
./build/verify-workflow assets images +RTS --threads 1 --gpu off
```

`--plan` lists the selected stages and literal arguments without executing checks. Unknown or empty profile selections fail. Repeated profiles do not repeat stages. All selected stages are required. Source-policy checks run before product profiles, and real-runtime checks precede the expensive proof and mutation stages. Execution stops at the first failure; remaining stages stay `not_run`.

| Profile | Required evidence |
| --- | --- |
| `toolchain` | Pinned Bend, Clang, target, platform, and clean dependency revisions. This alone is not product verification. |
| `proofs` | Root frontend proofs, standalone upload kernel verdict, law mutations and restored baselines. |
| `assets` | Root frontend proofs, law mutations, real file/cache/release/retry and source-consumer checks. |
| `images` | Assets plus PNG corpus, full-pixel comparison, real file/cache behavior and decoder mutations. |
| `json` | Assets plus strict scene/manifest files, reference and resource limits, cache/retry, parser qualification, production mutations and real ECS/offscreen comparison. |
| `math` | Pinned S41 adapter qualification, exact numerical contracts, production projection and adapter controls, root law mutations, and retained native scene/state/readback comparisons. Downloads the rejected candidate for evaluation only. |
| `textures` | Source laws, shader regeneration, real RGBA/D32 sampling and lighting, camera updates, texture rollback/retention/replacement, production mutations, and the native failure profile. |
| `upload` | Root frontend proofs, upload kernel verdict, law and source-policy mutations, real production/native upload boundaries and readback. |
| `native-failures` | Root frontend proofs and law mutations, bounded production-handler proofs with all mutations, real resource failure/rollback/retry. |
| `native` | Existing default native/offscreen gate, plus kernel verdict and law, source-policy, and native-handler sensitivity controls. |
| `window` | Owned Xwayland mesh controls, focus/resize/Close, captures and full-state replay. Requires the parent Wayland session and validation layer. |
| `textured-window` | Owned Xwayland mesh, cube, creation, replacement, and textured windows. Includes camera controls, resize, restore, cleanup, and mesh replay. |
| `all` | `native` and the extended window scenarios. This covers the registered profiles, not every feature-map scenario or backend. |

No arguments selects `native`. Profiles combine by union. Run affected profiles during implementation and include their dependent consumers before completion. Use the [feature map](../.agents/skills/verify-entangle/features/README.md) for other scenarios, including cube/public-creation windows and replacement windows. Add a required scenario when a change introduces a new behavior; do not treat the current profile list as exhaustive. The merged OBJ importer is covered by `verify-models` within the default native gate. Its supported profile and additional X11 evidence are recorded in the feature map; there is no separate `models` profile.

The runner preserves a source snapshot under a fresh `build/verification/workflow-XXXXXXXX/source` directory. It copies current uncommitted sources, creates independent Git repositories for the root and pinned dependencies, checks source fingerprints before and after copying, and executes sequentially inside the snapshot. This supports both ordinary clones and Git worktrees; snapshot Git commands resolve to the copied files. Fixed legacy build paths and mutation copies stay there. It does not switch branches, overwrite another session's binaries, publish code, or remove evidence. Source changes during copying fail the run. Changes after copying do not invalidate the snapshot result, but that result does not certify the new working tree. The snapshot includes other uncommitted work already present in the source directories. Start from a task-specific checkout when that work must be excluded; snapshotting isolates execution, not the choice of patch.

The existing Bash launcher in `tools/verify-window-session.sh` retains the owned-process and signal-cleanup lifecycle from the skill. The Bend runner invokes it inside the snapshot. A standalone launcher invocation retains its own evidence directory. Other shell recipes in the feature map are additional scenarios, not implicit coverage of this launcher.

## Read the result

`manifest.tsv` records the required stage, evidence kind, argv file, stdout, stderr, and status file. Each `.argv` file contains one literal argument per line, starting with the executable. Each stage status starts as `not_run`, becomes `running`, then records its exit code or `process_error:<code>`. Logs remain separate even on failure.

A complete pass requires `state` to be `complete`, `run.status` to be zero, and every manifest stage status to be zero. A missing, interrupted, failed, or unexecuted required stage is not a pass. `run.status` starts nonzero so setup errors and interruption cannot leave a successful receipt. Inspect the actual driver output and relevant captures as prescribed by the feature map.

The receipt includes the root revision, dirty diff and status, dependency revisions, compiler/platform details, source fingerprints, requested profiles, and timestamps. Full untracked source content is retained in the snapshot. Nested drivers retain their own detailed evidence under its `build/verification` directory. Keep the snapshot while its result is used; do not reuse a receipt for changed sources, harnesses, tools, dependencies, or relevant environment.

## Complete the task

Update code, applicable laws, sensitivity controls, coverage and task state together. Link the receipt and state its limits. Re-run only checks invalidated by a relevant edit or unresolved failure; do not add a generic review panel after acceptance passes.

Refresh the roadmap's current summary, next action, and affected checklist. Read live Entire change state before reporting publication or merge. Record implementation completion, task closure, and merged code separately. Preserve historical evidence at its original revision. Publishing and merging remain subject to the user's existing authorization.

The [workflow verification record](verification/2026-11-04-development-workflow/README.md) records the rollout, failure controls, and scoped full run.
