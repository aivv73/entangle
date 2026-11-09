# Migrate Entangle to the fork's current ECS

## Acceptance and required evidence

Use `aivv73/bendvy` revision `59833adc4dc007588d3b43158e0144abbdad45b4`,
the fork's current master observed on November 9, 2026. Replace the removed
execution-composer interfaces with the current component, query, system,
schedule, transaction, and inspector interfaces. Keep world ownership in ECS.

Preserve deferred bootstrap before the first movement, exactly two successful
system invocations per tick, entity identities and transform bits, deterministic
headless batching and replay, detached drawing, hierarchy edits and rollback,
mesh controls, native rendering, and cleanup. Update production adapters,
dependent examples, laws/proofs, source inventory, mutation controls, and docs
together. Do not emulate the removed ECS using a second writable scene store.

Qualify one real scheduled upstream consumer before implementing adapters.
Then run the existing headless and creation consumers, root frontend proofs,
affected hierarchy checks and sensitivity controls, native rendering consumers,
and live window/replay scenarios through the existing verification workflows.
Retain source-specific receipts and report environment or proof limitations
separately. The existing Clang distribution mismatch must not be hidden by
spoofing compiler output or claiming a failed gate passed.

## State

Implementation uses three canonical typed Column owners in the ECS World;
there is no mutable scene mirror. Movement declares Transform write access and
MeshRef membership. Bootstrap owns seed values and stages real transactional
spawns. The shared static schedule retains both registration owners and runs
bootstrap, barrier, movement, barrier. The mesh application supplies its control
state to that same query and scheduler. Passive Inspector extraction preserves
the caller's cursor and world clock.

Host namespace allocation is isolated in `src/scene.bend`; the runtime in
`src/scene-runtime.bend` stays in the pure proof closure. Independent worlds now
receive distinct namespaces. Hierarchy replay restores the recorded namespace
in a fresh process and continues to compare full handles and all component
bits. In-process mesh replay checks that independent worlds have different
namespaces and compares through one checked namespace bijection, preserving
every entity index/generation and payload bit. Each scripted tick still checks
its complete original handles within its own world. A production mutation
replaces host allocation with a fixed namespace and must fail this verifier.

The new scheduler continues remaining steps and explicit barriers after a
system error, then returns the first error. Entangle rejects that result without
retry. Bootstrap reservation failure rolls back staged commands; ordinary
movement follows the fork's preserving error semantics. Current schedule and
headless documentation describe this change explicitly.

Acceptance was recorded before implementation. The migration is implemented
locally; the native and proof results below apply to the current production
sources. Direct native, live-window, replay, and sensitivity checks are complete.
The canonical workflow remains blocked by its compiler precondition.

## Verification results

The real upstream scheduled-health consumer was qualified before choosing the
adapter. Its complete output matches the independently retained expected
sequence, including deferred visibility and untouched entities:
[qualification receipt](../../../build/verification/ecs-migration/qualification.log).

The source-specific workflow selects `native hierarchy textured-window`.
The [latest canonical receipt](../../../build/verification/workflow-oqWx7mNl/manifest.tsv)
has `state=failed`, `run.status=1`, and `toolchain.status=1`; subsequent registered
stages are `not_run`. Installed Clang 23.1.4 prints the LLVM revision on its
version line and targets `x86_64-unknown-linux-gnu`. The repository requires
the bare version line and `x86_64-pc-linux-gnu`. The gate and pins are unchanged.
No receipt below represents a passing canonical workflow.

Direct downstream checks used Bend 2.0.40, the actual installed Clang
distribution, and Vulkan Lavapipe with Khronos synchronization validation.
They retain their commands, source snapshots, individual statuses, stdout, and
stderr:

| Scope | Result and receipt |
| --- | --- |
| Root frontend claims, components, the observed eight-tick scene, headless consumer, all nine batching splits, public creation, compatibility | Passed individual stages in the [first native receipt](../../../build/verification/workflow-hVrS06Cr/source/build/verification/ecs-direct-native/manifest.tsv). Its overall run failed at the former mesh replay namespace assumption. The [resumed receipt](../../../build/verification/workflow-bDyzIHrl/source/build/verification/ecs-direct-native/reused.tsv) explicitly reuses only successful stages after checking source equivalence. |
| Scene rendering, public creation, retained mesh controls, hierarchy, JSON scenes, OBJ models, texture rendering | The [resumed native manifest](../../../build/verification/workflow-bDyzIHrl/source/build/verification/ecs-direct-native/manifest.tsv) and overall run pass. Checks include exact RGBA/D32 readback, retained snapshots, detached geometry, hierarchy edits/rollback and 17-command replay, input/reset/focus/clamping, and zero live Vulkan objects. |
| Production sensitivity | All 28 root law controls, eight hierarchy runtime controls, and seven texture controls reject their production mutants; restored baselines pass in the resumed native receipt. The hierarchy controls include duplicate world namespaces. |
| Current indexed hierarchy witnesses and source boundary | The [final formal/policy manifest](../../../build/verification/workflow-IKgtW4vi/source/build/verification/ecs-final-checks-2/manifest.tsv) passes. All 22 hierarchy frontend claims, four selected kernel claims, 19 formal production mutations, restored frontend/kernel baselines, and existing source-policy controls pass. The checked-read metadata mutation targets the actual indexed-column path. |
| Live cube, retained cube replay, terminal cube cleanup, public creation, replacement, textured scene, hierarchy and hierarchy replay | All eight individual stages pass in the [extended window evidence](../../../build/verification/workflow-IKgtW4vi/source/build/verification/entangle-AX97MlzW/commands.log). Its overall run failed at the subsequent mesh material-color assertion; that failure is retained. |
| Live mesh controls and recorded-input replay | The [final mesh window evidence](../../../build/verification/workflow-oqWx7mNl/source/build/verification/entangle-6vuFYfeC/commands.log) has `run.status=0`, with window, pointer sensitivity, live replay, and hidden-Close replay all passing. The two replays match 480 and 13 X11 batches, including zero-step polls, using full handles and transform bits. Held/repeated/opposite/released input, all six movement and camera controls, exact reset, focus-loss clearing, bounded catch-up, unmap/restore, repeated resize, unfocused Escape, hidden Close, clean validation, and zero live objects pass. |

The initial mesh capture contains all four materials. Lavapipe yields byte 230
for the two `0.9` channels where the earlier GPU receipt used 229. The maintained
driver now saves the initial capture before asserting and accepts those two
adjacent RGBA8 values at that rounding boundary. Every other channel and each
material's greater-than-100-pixel requirement remain exact. The
[failed diagnostic capture](../../../build/verification/workflow-DXMUMiWK/source/build/verification/entangle-AQmLcfBt/mesh/initial.ppm)
and its native trace remain available.

The final mesh launcher rebuilds the changed driver and reuses only the prior
successful app, replay, and pointer binaries after exact comparisons of their
production, example, dependency, toolchain, and imported helper sources. The
[retained launcher](../../../build/verification/workflow-oqWx7mNl/source/build/ecs-direct-window.sh)
records this scope and the failed canonical precondition. The maintained owned
display/runtime launcher is unchanged. Both window runs used a private Weston
headless compositor and owned Xwayland displays, with capture/input through the
real X11 and Vulkan paths. Their cleanup receipts reap their displays and remove
their disposable runtime directories. The private compositor is also stopped
and reaped; the [display cleanup receipt](../../../build/verification/ecs-migration/display-cleanup.log)
confirms that the owned processes and socket are gone while evidence is retained.

The [inspected capture sheet](../../../build/verification/ecs-migration/window-captures.png)
shows cube, hierarchy, textured, initial mesh, moved mesh, and portrait-resized
mesh output. Exact initial/reset mesh capture comparison passes. Final source
correspondence is retained in the
[source audit](../../../build/verification/ecs-migration/source-audit.log).
Result documentation was added after the captured implementation snapshots.

## Limits and publication

The hierarchy ECS publication claims are frontend qualification of the concrete
schema, indexed columns, live handle, and administrative witnesses. Four pure
core claims are kernel checked. General forest/array witness construction and
the retained-handle/column bridge remain open; this work does not establish
universal atomic publication. The [formal plan](../../../proofs/hierarchy/plan.md)
states that boundary.

Native window/presentation sources and their existing proof bundles are
unchanged. No fresh passing native-failure or presentation proof workflow is
claimed: the canonical workflow stops at its compiler precondition. The older
machine-specific isolated-headless recipe and separate static OBJ X11 consumer
were not rerun. Current headless batching, actual imported OBJ ECS/offscreen
rendering, and migrated interactive scene paths have direct checks above.

Verification was completed before the user requested commit and push.
Publication is tracked by the branch history; no merge is claimed.

Before publication, the migration was rebased onto the existing remote `work`
commit `761e8ba`, preserving the Jonlib compiler-compatibility documentation and
version guards. That integration changes neither production sources, examples,
laws, proofs, nor toolchain pins relative to the verified migration. The
[publication audit](../../../build/verification/ecs-migration/publication-audit.log)
records that correspondence separately from the original source receipts.
