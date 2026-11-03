# ECS window verification

The window adapter composes Entangle's detached drawing data with the existing
bend-vulkan window, camera, indexed pipeline, and target lifecycle. The native
acceptance command is `./build/verify-window`, built from
`tools/verify-window.bend`. Run it from the repository root. It builds the actual
`examples/scene-window.bend` executable, never the dependency's demonstration.

## Renderer contract

`src/scene-window.bend` owns one affine `Renderer`. Its indexed resources contain
a persistent vertex buffer and index buffer. Its optional target is created,
replaced, and retired by the existing `Indexed.ensure`, `retire`, and `destroy`
helpers. The adapter records `R.draw_items` because the dependency recorder fixes
its draw count to 42 indices. There is one frame in flight. The acquisition lease
is passed to `use_acquisition` and then presentation. Both render and presentation
fences complete before shared resources are reused.

`open(entry,title,mesh)` validates and uploads the mesh once. `poll(renderer)`
returns the renderer and a native snapshot. The application handles camera
events before its scheduled ECS tick, extraction, and `frame` call. A view
function passed to `frame` receives the actual swapchain width and height. It
returns `Maybe<Mat4>`, which accommodates the checked sixteen-word camera adapter.
Neither the core adapter nor its acquisition dispatcher imports ECS.

A drawable frame ensures its target before validating the camera and drawing
input. Invalid input returns renderer ownership and a recoverable `InputError`
without acquiring an image. Any target replacement already performed by ensure
is retained. Hidden or zero-sized snapshots skip acquisition and drawing.
The application continues to poll and run due ECS ticks while hidden.

`close` retires the current target. Keep the entire renderer lifetime inside
`V.Entry.with`; Entry owns final persistent-resource cleanup, including Action
failure. The executable checks `debug_live_objects` after that scope returns.
This does not establish recovery from device loss or a failing driver.

The existing window pipeline culls back faces. The executable uses the first
24 vertices and 36 indices of the dependency's properly wound closed cube,
without its floor. Positive ECS scales preserve orientation. Arbitrary mesh
parity with the unculled offscreen pipeline is outside this contract.

## Fixed framing and unchanged world

At tick one, entity `i` has position `(i+1, 2i+0.5, -i-2)` for `0 <= i < 100`.
Its line center is `(50.5,99.5,-51.5)`. Every center is within
`49.5 * sqrt(6) < 121.25` of that point. The local cube has coordinates in
`[-1,1]`, scale `(2,3,4)`, and the existing unit rotation. Its enclosing radius
is `sqrt(29) < 5.39`. A radius of 130 therefore encloses the initial geometry
with room for float rounding.

The fixed view is `P * V * S(s) * T(-center)`, where
`s = 3 * min(1,width/height) / 130`. The initial distance is the dependency's 7.
Only aspect changes with the target. The initial captured view motivated an
increase from the tentative scale 1.8 to 3. No entity data, mesh IDs, item order,
or model transforms changed for framing. The cubes overlap in the original
scene and appear as a dense diagonal line.

Live mode schedules at most one ECS tick when each 250 ms deadline becomes due.
It sets the next deadline from that poll's time. This is demonstration pacing,
not a fixed-dt simulation or catch-up policy. It never resets or follows the
World. Uniform translation is visible and eventually moves beyond this fixed
view. R resets only the existing orbit camera.

Replay first advances the actual application to tick one and retains its
DrawList. It then reaches tick two, validates the retained tick-one bits against
saved observation rows, and renders the retained data. Camera reset can therefore
be compared by exact pixels without resetting ECS. Both modes use the same
`Win.frame` and `R.draw_items` path.

## Proofs and runtime checks

`bend PROOF.bend` proves structural float-word reconstruction in both directions,
Mat4 reconstruction, and the exact sixteen-word column layout for arbitrary
bit patterns. These laws use the structural encoder because Base's `F32.bits`
is opaque to the proof checker. Native startup separately compares that encoder
and the decoder against `F32.bits`, including signed zero, subnormals, infinities,
and NaN payloads. These claims do not prove native drivers or foreign effects.

The executable reuses existing scene verification helpers. They validate 100
stable entity identities, original mesh IDs, rotation and scale, exact translation
at every genuine tick, ordered drawing bits, passive world clocks, and inspector
cursors. It checks current and retained DrawLists before frames. Per-tick logs
include ordered float-bit digests as evidence identifiers; digest equality alone
is not the correctness check.

The live driver counts colored geometry pixels, rather than accepting any changed
frame or background. Movement requires changed colored geometry at equal extents.
Replay requires exact frame equality after R. The driver imports the dependency's
bounded process/window waits, capture bridge, PPM writer, child ownership, and
cleanup. Local orchestration supplies scene-specific pixel expectations and
input sequences. There is no new C, synthetic renderer, or mock implementation.

## Native evidence

The implementation run uses Bend 2.0.39, Clang 23.1.4, Linux x86-64, and a GTX 1660.
Dependency revisions remain those in `toolchain.bend`. The display is an owned
rootful Xwayland at 1280x1024 so the desktop does not override client sizes.
The verifier records layer availability, raw logs, exact pixel captures, and
zero-object shutdown results under `build/window-evidence`.

The local implementation report at `build/window-implementation-report.md`
records the implementation run. The parent review and reruns are recorded in
`build/window-parent-report.md`. Evidence remains untracked. Timing and counter measurements,
other GPUs and operating systems, forced surface loss, and device loss are not
covered by this acceptance run.

On November 3, 2026, `bend PROOF.bend`, `bend tools/verify.bend`, and the isolated
actual-executable window gate each exited 0. Live captures contained 2671 and
2684 colored geometry pixels across successive genuine ticks. Replay matched
exact pixels after each A/D, W/S, and Q/E action followed by R. The sequence
`800x450, 360x640, 720x480, 360x640, 800x450, 640x480` checked changed geometry
at each extent and exact matches when an extent recurred. These asynchronous
captures do not identify which input event produced every intermediate frame.
Unmap/restore, hidden ECS ticks, Escape, hidden Close, all four input-rejection
cases, and the intentional terminal Action return passed. All three Entry scopes
reported zero live Vulkan objects. Khronos and synchronization validation were
enabled. The logs contain deprecated `VK_LAYER_ENABLES` setting warnings, with
no `Validation Error`, `SYNC-HAZARD`, or `VUID-` diagnostics. The owned Xwayland
was stopped and reaped after the run.

Independent review found that retained pixels could satisfy the original restore
check without resumed presentation. The driver now requires D to change geometry
after restoring the window, followed by R and exact baseline pixels. Input
rejection is exercised at startup before normal replay, not after a resize or
an earlier rendered frame. Device-loss cleanup remains outside the claim.

The parent reran `bend PROOF.bend` and `bend tools/verify.bend` successfully.
After the review fix, the rebuilt native window gate also exited 0. The restored
window changed geometry under D and returned exact baseline pixels under R.
All scopes again reported zero live objects, with no validation errors or
synchronization hazards. Logs are `build/window-parent-reviewed-proof.log`,
`build/window-parent-full-verify.log`, and `build/window-parent-reviewed-native.log`.
