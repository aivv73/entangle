# Static OBJ model sources

The [strict OBJ profile](../../../../docs/model-obj.md) imports authored triangles
and opaque diffuse materials through the existing synchronous Asset cache.
The importer owns source values only.

## Source and native consumers

Run from the repository root with the pinned compiler and dependencies.

```sh
bend PROOF.bend
bend tools/verify-models.bend -o build/verify-models
./build/verify-models +RTS --threads 1 --gpu off
```

The Bend driver first requires the Bend version in `toolchain.bend` (currently
2.0.40). The standalone source closure needs no Jonlib compiler overlay; see the
[compatibility record](../../../../docs/verification/2026-11-09-jonlib-bend/README.md).
It verifies the exact pinned parser and licenses, complete source
words and labels against independent authored values, generated text/index
properties, reachable bounds, real file/cache/retry and closure behavior,
isolated production mutations, and a source-only inventory without Creation,
ECS, or Vulkan. Its native consumer then uses unchanged Creation and real ECS
snapshots. It compares every packed word/range and complete offscreen RGBA/D32
readbacks against direct engine sources. Require its final completion message.
`build/model-obj/sign.ppm` and `wedge.ppm` retain real output. This path needs
Vulkan but no display. `--gpu off` controls Bend dispatch.

## Owned X11 geometry and culling

```sh
bash tools/model-obj/window-session.sh
```

The launcher follows the skill's owned Xwayland lifecycle in a fresh runtime.
It does not replace the repository's `build/indexed-window`. The Bend driver
finds only its child's window by PID. The imported sign must show white, red,
and green regions. The closed Blender wedge must show geometry. An imported
sign with all visible faces reversed must show clear-only output under native
back-face culling. The driver captures each case, sends actual Close, and checks
clean validation and zero live Vulkan objects.

The printed `build/verification/model-window-XXXXXXXX` contains commands,
statuses, binaries, source hashes, the reversed input, captures, native logs,
and cleanup. Require all statuses and `run.status` to be zero. Inspect all three
captures. Confirm the runtime is absent and the recorded display PID has gone.
Keep evidence after teardown. A blank positive capture, timeout, live process,
or unrelated scene is not imported-geometry evidence.

No renderer/native resource code changes are part of this importer. Device-loss
recovery, other backends, universal decimal correctness, filesystem snapshot
isolation, and performance are outside these observations.
