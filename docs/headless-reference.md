# Headless scene reference

`examples/scene.bend` defines tick-start, numerical-update, and structural-commit
semantics for the retained scene. It is the E2 reference for future R0 work.
It does not complete R0 or introduce an ECS or a parallel runtime.

## Public bounded runner

`src/headless.bend` imports only Base and exposes one operation.

```bend
def advance(~A:Type,~tick:A -> IO(A),remaining:Nat,state:A) -> IO(A)
```

The caller owns creation and passes its existing affine state as `A`.
Zero returns that state without calling `tick`. A successor waits for one
completed tick, then advances the returned state by the remaining count.
The returned application can be inspected or advanced again.
The closed template callback can be specialized repeatedly without copying
an affine function value or application.

`examples/scene-headless.bend` calls `Scene.create` explicitly and specializes
`advance` with the real `Scene.tick`. Creation performs no ticks.
The window's startup tick and existing window behavior remain unchanged.
The runner supplies no clock, registration, retry, rollback, or error protocol.
Failure follows the callback. A refused production scene tick exits nonzero,
and earlier writes or bootstrap publication can already have happened.

Design C was selected over A's additional startup operation because explicit
creation keeps the tick budget visible at the consumer. Both designs retained
one affine application and used closed callbacks. No production wrapper or
second world is needed.

## CPU verification

`bend tools/verify-headless.bend` checks the pinned Bend and Clang versions and
native target, emits fresh C, links with `-lpthread -lm`, and executes with
one CPU thread and GPU dispatch disabled. It runs the direct production
specialization, the unchanged `examples/scene.bend` observed reference, and
`tools/verify-headless-scene.bend`. Exact stdout is checked for each.
The reference output contract is shared with `tools/verify.bend`.
The CPU gate imports neither the graphics gate nor aggregate proofs.

The production verifier checks every split `a + b = 8` in a fresh sequential
replay. Its verification-only record owns one real application, inspector,
ordinal, and detached observations. Each evidence tick calls `Scene.tick`
once and reuses the reference's numerical and full-handle oracles.
It checks empty creation, first-tick publication, all eight transform recurrences
by float bits, mesh identity, exhausted seeds, successful receipt identities,
empty queues, drained unapplied systems, clock progress, and detached retention.
Zero batches before bootstrap, at each split, and after tick eight preserve
world clock, inspector key, retained inventory, and snapshot values.
Each replay compares full handles against its own admitted baseline.
Namespace IDs are not compared across fresh worlds.
The ordinary tick verifier does not observe scheduler boundary events.
The unchanged observed reference checks those events separately.

`headless_scene_zero` and `headless_scene_successor` in `LAWS.bend` state the
actual runner's scene-specialized IO unfolding equations. Their reflexivity
proofs in `PROOF.bend` establish construction of the IO computation.
They do not prove arbitrary IO equivalence or native runtime correctness.
The aggregate proof command still requires the full dependency checkout.

The [runner verification record](verification/2026-11-03-headless-runner/README.md)
records the isolated fresh CPU build and the separate full verifier.

## Tick start

One tick is one whole-scene invocation on the retained `Scene.Application`.
The example inspects that application's current state immediately before calling
its local `run_observed`. This helper specializes Bendvy's `Root.run_observed`
with the same production dispatch, guards, handler, apply, and completion as
`Scene.run`. Successful completion includes Root lifecycle maintenance.
Window callers continue to use `Scene.tick`.

The application remains the only owner of the world, bootstrap state, system
owners, and deferred schedule. Snapshots, receipt summaries, and drawing lists
are detached observations. They do not provide another writable world.
Tick start does not freeze a universal snapshot for all systems. Explicit
synchronization can change visibility within the invocation.

The reference ordinal starts at one and advances after a checked completion.
It differs from the world change clock, which tracks changes and lifecycle work.
The reference adds no duration, fixed timestep, or catch-up policy.

## Numerical updates

The existing movement writer calls `Step.step(Unit{},transform)` once for each
selected entity. It writes each replacement immediately during sequential row
traversal. Translation uses the existing F32 additions and subtraction; rotation
and scale pass through unchanged. See the [step kernel](step-kernel.md).

The reference compares complete handles, including namespace and entity-key
identity. On tick one, it checks each seed's one-step result. On later ticks,
it finds the entity in the actual tick-start snapshot and checks the result of
one kernel call against every returned transform float bit. Query order does
not determine correspondence. The independent closed-form oracle for these
100 seeds and eight ticks, mesh checks, and drawing checks remain active.
These checks do not assert bitwise determinism for arbitrary F32 inputs,
iteration counts, or execution backends.

## Structural commit

A structural commit is a production apply boundary. One invocation can contain
several boundaries. The scene's explicit bootstrap synchronization publishes
new entities before movement, so tick one moves all 100 seeds immediately.
Final apply follows movement and has empty structural work in this scene.
Its requested movement ID records a publication obligation, not a command count.
Bootstrap's ID also recurs on later ticks after the seeds are exhausted.
See [schedule visibility](schedule-visibility.md) for the existing schedule.

The reference resolves spawn and movement IDs from their retained owners.
It requires `Finished` with exactly two ordered `Ran` reports, spawn then
movement. It requires exactly these four events:

1. Sync apply enters with the spawn ID as the only requested system.
2. The same sync returns with no remaining systems.
3. Final apply enters with the movement ID as the only requested system.
4. Final apply returns with no remaining systems.

The sync ID must belong to the application's compiled sync inventory.
At tick one entry, live entities, admissions, query rows, receipts, pending
commands, and unapplied systems are empty, and seeds are unexhausted.
Every returned application has exhausted seeds, empty pending commands and
unapplied systems, and exactly 100 successful spawn receipts with empty previous
bundles. Their unique full handles equal admissions, live handles, and query
handles. Later invocations retain those receipt identities; they do not produce
100 new receipts each time. Inspection reconstructs every affine owner and
receipt, including unexpected payloads, without clearing them.

The executed ordering, empty initial state, receipts, and numerical results
establish bootstrap publication before movement. The observer does not capture
an intermediate world at the barrier. The final boundary does not establish
nontrivial structural publication.

## Failure behavior

A query or write refusal stops movement with earlier writes retained.
Bootstrap publication can already have happened before a later failure.
`Stopped` and `Invalid` return the retained application and report, skip final
apply, and skip successful lifecycle maintenance. They provide no rollback.
`Finished` alone does not establish successful structural work; receipts and
queues still require inspection.

The example checks the raw report before validating successful state. It exits
nonzero on refusal, unexpected observations, or failed assertions. It does not
retry. Calling the application again advances it again; an invocation is not
idempotent. Failure behavior follows the production implementation; this
successful-run reference does not inject failures or prove recovery.

## Evidence and limits

Three design sketches compared extending the existing example, adding a separate
driver, and exposing production observation helpers. The selected design extends
the existing example to reuse its numerical and drawing checks. Independent
cross-review agreed. It also adopted explicit initial receipt and queue checks
from the third sketch. A separate driver would duplicate checks; new production
helpers would expose an API used only by this example.

`scene_sync_boundary_pair` in `LAWS.bend`, implemented in `PROOF.bend`, proves
the actual dependency trace constructors emit the entered event before the
returned event. It does not prove publication, the scheduler, compiler, native
runtime, or complete ECS behavior. Existing numerical and bootstrap laws remain.

The [verification record](verification/2026-11-03-headless/README.md) contains
commands and stdout from proof checking, a fresh pinned native scene, and the
repository verifier. The latter retains the offscreen color, depth, replay,
and cleanup checks. This work makes no performance, GPU-dispatch, window,
removal-production, or lifecycle-expiration claim.
