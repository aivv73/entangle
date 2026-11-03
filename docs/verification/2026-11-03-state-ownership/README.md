# State ownership verification

The ownership contract retains the existing ECS storage and registered movement
writer. Production files under `src/`, native tooling, and dependency pins are
unchanged from `abc11aa63cb15b794b45a5e2c7bd5bc8b12dc2f2`.

## Native execution and proofs

`bend tools/verify.bend` passed on the unchanged runtime before the new laws were
added. [verify.log](verify.log) records the complete output. It covers the pinned
toolchain, dependency proofs, native component consumer, eight scene ticks,
ordered invocation and publication evidence, and exact offscreen rendering in
both index orders. Retained replay passed and terminal Vulkan live objects were
zero.

After adding the three ownership adapter laws, `bend PROOF.bend` passed.
[proof.log](proof.log) records the checker result. The final scene was rebuilt
and run headlessly with the same compiler and runtime settings. Its complete
output in [scene-after.log](scene-after.log) matches the scene output from the
full verifier byte for byte.

The relevant commands, run from the repository root, are:

```sh
mkdir -p build/state-ownership
bend tools/verify.bend > build/state-ownership/before.log 2>&1
bend PROOF.bend > build/state-ownership/proof.log 2>&1
bend examples/scene.bend -o build/state-ownership/scene.c
clang -std=c11 -O2 build/state-ownership/scene.c -lpthread -lm -ldl -o build/state-ownership/scene
env -u DISPLAY -u WAYLAND_DISPLAY ./build/state-ownership/scene --threads 1 --gpu off > build/state-ownership/scene-after.log
sed -n '/^before-tick entities=/,/^Shared mesh scene verified across 8 ticks\./p' build/state-ownership/before.log > build/state-ownership/scene-before.log
cmp build/state-ownership/scene-before.log build/state-ownership/scene-after.log
git diff abc11aa63cb15b794b45a5e2c7bd5bc8b12dc2f2 --exit-code -- src tools toolchain.bend deps
git diff --check
```

## Rejected snapshot writeback

The temporary mutation in
[rejected-snapshot-writeback.patch](rejected-snapshot-writeback.patch) changes
`move_rows` to ignore the writer's current component and advance the copied query
view instead. It changes the actual production adapter for the check.

`bend PROOF.bend` rejected the mutation at `scene_move_view_independent` with
exit status 1. The failure compares the two different captured views, rather
than reporting a syntax or type error. The complete diagnostic is in
[rejected-snapshot-writeback.log](rejected-snapshot-writeback.log).
The original adapter was restored before the final proof and native run.

To reproduce the rejection on a clean checkout of this change:

```sh
git apply docs/verification/2026-11-03-state-ownership/rejected-snapshot-writeback.patch
bend PROOF.bend
git apply -R docs/verification/2026-11-03-state-ownership/rejected-snapshot-writeback.patch
bend PROOF.bend
```

The first proof command must fail at `scene_move_view_independent`. The final
command must pass after the mutation is reversed.

## Limits

These checks establish the current adapter's data dependency and exercise the
real sequential scene. They do not prove ownership partitioning for an absent
chunk runtime, enforce a repository-wide ban on new stores, or prove arbitrary
Bendvy writers correct. The project checker ran without `--verdict`.
The full native verifier was not repeated after adding proof-only definitions.
The window verifier was not rerun because production runtime and input code are
unchanged. No performance or cross-backend determinism claim is made.
