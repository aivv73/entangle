# Application extraction verification

The extraction preserves the existing live, replay, and terminal scenarios.
The native window verifier passed before and after the change on an owned
rootful Xwayland display with Vulkan validation enabled.

`bend PROOF.bend` reported `ALL PROOFS CHECK`. The full pinned native verifier
passed, including component preservation, eight ECS ticks, exact offscreen
color/depth results, repeated and retained frames, input rejection, and cleanup.

`tools/compare-window-evidence.bend` compared 13 replay, camera-control, resize,
and restore captures byte for byte. Every capture matched. The replay and
terminal logs also matched byte for byte. Live captures are excluded from this
comparison because their capture time determines which simulation tick is visible.
The window verifier separately checked live movement, hidden ticks, hidden Close,
Escape, input rejection recovery, and zero live Vulkan objects after cleanup.

Both measured modes completed before and after the extraction with empty stderr
and zero live Vulkan objects after cleanup. Replay retained tick-one drawing
while the world stayed at tick two. Its 151 attempt records preserved configuration,
device, drawing digests, dimensions, generations, outcomes, counters, span names,
and unavailable-span reasons. Live preserved the distinct per-tick drawing digests
and counters and completed eight steady simulation ticks. Wall-clock sampling
produced different live attempt counts. No performance comparison was made.

The implementation keeps the two loops explicit. The baseline ignores camera
events and preserves its timing-read positions. The interactive loop consumes
events before time, simulation, or rendering. The shared App scope returns both
the Action result and the post-cleanup object count so each executable retains
its existing reporting order.

## Reproduce

Use the pinned toolchain and the owned-display setup in
[the baseline record](../../baseline-measurements.md#rerun).
Before changing the source, run the window verifier and copy its evidence
directory. After changing the source, rebuild and run it again.

```sh
bend PROOF.bend
bend tools/verify.bend
bend tools/verify-window.bend -o build/verify-window
DISPLAY=":$owned_display_number" ./build/verify-window
bend tools/compare-window-evidence.bend -o build/compare-window-evidence
./build/compare-window-evidence build/app-refactor-before/window-evidence build/window-evidence
```

The comparator fails if any selected file is missing or differs. It checks
existing execution evidence and does not substitute a test implementation.

Local run output is under `build/app-refactor-before/` and
`build/app-refactor-after/`. These ignored directories include the native and
window logs and the measured live/replay JSON streams. The comparator's output
is retained beside this record.
