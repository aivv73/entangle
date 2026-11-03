# Headless reference verification

The checkout is `/home/aivv/.t3/worktrees/entangle/t3-9739c77c`.
The [reference contract](../../headless-reference.md) describes the checked
semantics and their limits. [commands.sh](commands.sh) records the exact proof,
native compilation, headless execution, and repository verification commands.
Generated C and the standalone binary stay in `/tmp`; repository verifier
artifacts stay in ignored `build/`. No generated binaries are included here.

## Toolchain and checkout preparation

[toolchain.log](toolchain.log) records Bend 2.0.39, Clang 23.1.4,
`x86_64-pc-linux-gnu`, and all three exact dependency revisions.
The initial dependency directories had Git metadata but incomplete files.
The documented initialization command first failed because bend-vulkan had no
current revision. The following commands populated the existing exact pins:

```sh
git -c protocol.entire.allow=always submodule update --init deps/bendvy deps/bend-vulkan
git -C deps/bendvy read-tree HEAD
git -C deps/bendvy checkout-index -a
git -C deps/bend-vulkan -c protocol.entire.allow=always fetch origin a144f7dd4fb4835ca3d5ce17350fc850de049038
git -C deps/bend-vulkan checkout --detach a144f7dd4fb4835ca3d5ce17350fc850de049038
git -C deps/bend-vulkan submodule update --init deps/bend-collections
```

No dependency revision, source, or toolchain pin changed. `bend guide` ran before
implementation. Source inspection confirmed the production Root completion,
retained owner representation, compiled sync inventory, and deferred trace API.

## Results

`bend PROOF.bend` exited 0 and printed `ALL PROOFS CHECK` in
[proof.log](proof.log). This invocation checks the Bend proofs; it does not run
the optional `--verdict` mathematical-validity gate.

A fresh `bend examples/scene.bend -o /tmp/entangle-headless-scene.c` and
`clang -std=c11 -O2 /tmp/entangle-headless-scene.c -lpthread -lm -ldl -o /tmp/entangle-headless-scene`
both exited 0. With display environment variables removed,
`/tmp/entangle-headless-scene --threads 1 --gpu off` exited 0.
[scene.stdout](scene.stdout) contains all eight checked ticks.
Actual owner IDs were spawn 1 and movement 2, with compiled sync 0.
Tick one started empty and returned 100 entities; ticks two through eight
started and returned 100. Each invocation checked 100 successful receipt
identities, 100 numerical recurrences, two ordered `Ran` reports, four apply
events, empty pending commands, and empty unapplied systems.

`bend tools/verify.bend` exited 0 on the final source. [verify.log](verify.log)
records the exact scene stdout comparison, native compatibility and component
checks, both offscreen index orders, exact color and depth, retained replay,
terminal cleanup, and zero live Vulkan objects. It ends with
`Pinned native toolchain and dependency compatibility verified.`
The retained-drawing assertion remains after the next actual invocation;
proof checking, fresh standalone native compilation and execution, and the full
verifier all ran again after that placement was corrected during diff review.

`git diff --check` passed. Only the requested E2 reference checkbox is complete;
the remaining E2 items and R0 retain their prior status.

The parent independently reran `bend PROOF.bend` and `bend tools/verify.bend`.
Both exited 0. Their complete output matched the recorded logs byte for byte.
Parent diff review found no correctness issues. The separate source-comment
review found no comments to remove or constraints requiring follow-up.

## Evidence limits

The trace law proves constructor ordering only. Native assertions cover this
successful production scene with its 100 seeds and eight invocations. They do
not prove the entire scheduler, compiler, runtime, or ECS. There is no snapshot
inside the synchronization boundary. Final apply contains empty structural work.
Failure behavior was read in the production source, not exercised by injected
refusals. No rollback, recovery, arbitrary-F32 determinism, parallel speedup,
GPU-dispatch behavior, window behavior, removal production, or lifecycle
expiration is established. R0 remains open.
