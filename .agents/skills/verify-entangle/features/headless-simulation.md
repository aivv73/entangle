# Headless simulation

An application can advance the same ECS world without a window, Vulkan, or GPU. The caller chooses the tick count and retains the resulting application.

## Sub-features

- `headless-run` completes eight production ticks through `Headless.advance`.
- `headless-zero` preserves creation and later state for a zero-tick advance.
- `headless-splits` compares every split of eight ticks through real sequential execution.
- `headless-observe` checks entity identities, transform bits, receipts, clock progress, and retained observations.

## How to get to it (user POV)

Call `Headless.advance` from `src/headless.bend` with the application's tick callback. `examples/scene-headless.bend` is the direct consumer. The README exposes `bend tools/verify-headless.bend` to build and exercise that consumer and the observed reference.

## Driving it with the Bend CPU gate

Preconditions: Bend 2.0.39, Clang 23.1.4, Linux x86-64, and `deps/bendvy`. The gate does not require bend-vulkan, graphics headers, a display, or a GPU. No other process may write `build/headless` during the run.

- **Advance and inspect.** Run this independent block from the repository root.

```bash
set +e
mkdir -p build/verification
headless_evidence=$(mktemp -d "$PWD/build/verification/headless-XXXXXXXX")
printf 'Evidence: %s\n' "$headless_evidence"
printf '%s\n' 'env -u DISPLAY -u WAYLAND_DISPLAY bend tools/verify-headless.bend' > "$headless_evidence/commands.log"
env -u DISPLAY -u WAYLAND_DISPLAY bend tools/verify-headless.bend > "$headless_evidence/run.log" 2>&1
headless_status=$?
printf '%s\n' "$headless_status" > "$headless_evidence/run.status"
cat "$headless_evidence/run.log"
test "$headless_status" -eq 0
```

- **Observe completion.** Require `Headless scene completed 8 production ticks.` and `Pinned CPU-only native headless verification passed.` The gate compares exact stdout from each fresh native executable.
- **Observe batching.** Require `split=0+8 production=8 verified` through `split=8+0 production=8 verified`, plus the final ownership/receipts/transform/retention result. The observed reference reports empty creation, 100 entities after each tick, and four schedule-boundary events per tick.

## Gotchas

- Calling the tick callback again advances the world again. Execution is not idempotent and has no rollback on refusal.
- Do not compare namespace IDs across fresh worlds. The verifier compares each replay with its own admitted identities.
- Aggregate `bend PROOF.bend` requires the full dependencies. This CPU gate deliberately avoids that requirement.
- The command leaves generated files in `build/headless`. Keep them as build outputs, or remove only files this run created after checking that no other run uses them. Evidence under the printed directory must survive cleanup.
- A headless pass proves neither presentation nor window input.
