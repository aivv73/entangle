# Native window baseline measurements

This is an instrumented baseline for the current 100-object Entangle window scene on one Linux desktop. It makes no speedup claim. Five fresh live processes and five fresh replay processes ran sequentially in alternating order. All reported samples come from the measured collector source identified by `source.sha256`.

The normal application keeps its controls and 250 ms schedule. Maintainers get successful-call counters and a bounded executable that uses the same upload, draw, acquisition, recording, presentation, and cleanup path.

## Measured results

The table gives the median of five per-repeat medians and their minimum and maximum. Values are milliseconds. The CPU render call includes waits and retirement. The GPU interval overlaps the CPU intervals.

| Mode | Metric | Median of repeat medians ms | Repeat median min ms | Repeat median max ms |
| --- | --- | ---: | ---: | ---: |
| live | `startup_through_first_completed_frame` | 229.178471 | 218.077082 | 245.846028 |
| live | `simulation` | 9.136713 | 8.325990 | 9.469364 |
| live | `observation` | 4.378161 | 4.319769 | 6.704196 |
| live | `extraction` | 2.692037 | 2.642374 | 6.162946 |
| live | `record` | 0.580994 | 0.546489 | 0.590004 |
| live | `submit` | 0.050220 | 0.048265 | 0.051128 |
| live | `render_wait` | 0.314595 | 0.311521 | 0.322207 |
| live | `present_wait_and_reset` | 0.017532 | 0.017043 | 0.018090 |
| live | `render_call_wall` | 1.437432 | 1.418294 | 1.497536 |
| live | `poll` | 5.342200 | 5.269104 | 5.374574 |
| live | `loop_through_initial_buffer` | 6.927569 | 6.912447 | 6.937278 |
| live | `gpu_interval_truncated_ns` | 0.122944 | 0.120960 | 0.123424 |
| replay | `startup_through_first_completed_frame` | 232.301783 | 217.612523 | 266.865380 |
| replay | `simulation` | unavailable | unavailable | unavailable |
| replay | `observation` | unavailable | unavailable | unavailable |
| replay | `extraction` | unavailable | unavailable | unavailable |
| replay | `record` | 0.582739 | 0.528049 | 0.612005 |
| replay | `submit` | 0.050116 | 0.046868 | 0.053468 |
| replay | `render_wait` | 0.313233 | 0.305374 | 0.321998 |
| replay | `present_wait_and_reset` | 0.018195 | 0.017951 | 0.019312 |
| replay | `render_call_wall` | 1.473403 | 1.383474 | 1.521738 |
| replay | `poll` | 5.358334 | 5.301304 | 5.477041 |
| replay | `loop_through_initial_buffer` | 6.933226 | 6.929908 | 6.958372 |
| replay | `gpu_interval_truncated_ns` | 0.130064 | 0.129344 | 0.132048 |

The final set contains 2,237 attempts. Every attempt completed a normal presentation at 640 by 480. There were no skipped, rejected, suboptimal, out-of-date, or failed attempts in this set. Live repeats each contain eight actual steady ticks. Their steady frame counts are 263, 273, 266, 257, 268. Each replay repeat contains 120 steady frames. Replay simulation, observation, and extraction are unavailable during steady rendering because those operations do not run there.

[Per-repeat summaries](verification/2026-11-03-baseline/per-repeat-summary.md) give count, missing count, median, nearest-rank p95, minimum, and maximum for every metric and repeat. The raw `live-N.jsonl` and `replay-N.jsonl` files contain the same summaries and all individual attempts. [Repeat ranges](verification/2026-11-03-baseline/repeat-ranges.jsonl) retain the five-repeat aggregation in machine-readable form. No pooled distribution is the primary result.

CPU durations retain exact U64 low and high limbs. The median is the middle order statistic, or the midpoint of the two middle values for even counts. The p95 is the observation at rank `ceil(0.95*N)`. GPU summaries truncate the finite F32 duration to integer nanoseconds before ordering. Raw GPU F32 bits remain authoritative for the duration returned by the API.

## Successful calls and correctness

Every measured renderer reported two startup host mesh writes totaling 720 bytes. Each completed frame reported zero additional host mesh writes, 100 accepted push-constant calls, 6,400 push payload bytes, 100 indexed draws, and one successful submit. The implementation increments these counters beside successful calls. It counts actual serialized payload lengths. It does not derive accepted calls from the number of scene objects.

Host mesh write bytes describe byte values accepted by `write_memory`. Push payload bytes describe command payload accepted by `push_constants`. Neither measures driver staging, PCIe traffic, physical GPU memory traffic, flushes, or hidden driver command counts. The counters cover the Entangle window path. They do not count every Vulkan command-buffer function.

All GPU samples were available. Each retained both raw U64 timestamps, per-query availability, generation, 64 valid bits, a 1 ns F32 period, the exact independent CPU completion bound, and F32 duration bits. Every frame generation matched its GPU generation and attempt identity. No stale result entered a summary.

Every process reported 36 live Vulkan objects before renderer close and zero after `Entry.with` cleanup. These are snapshots, not a measured peak. Exact ordered drawing-bit validation remained enabled before and after rendering. Replay kept world tick two and draw tick one with the exact retained tick-one payload. The retained digest was 956920501 in all replay attempts. The assertions also compare full payloads, so correctness does not depend on the digest alone.

[Counter and GPU checks](verification/2026-11-03-baseline/evidence-check.json), [terminal checks](verification/2026-11-03-baseline/terminal-check.json), and [replay checks](verification/2026-11-03-baseline/replay-check.json) summarize the raw final files. `verify_samples` in the collector independently checks counters and query generations after timed work.

The following gates passed locally.

- `bend PROOF.bend` checked all laws, including preservation of accepted draw counts by a push and preservation of accepted push counts by a draw.
- `bend tools/verify.bend` checked pins, the native dependency consumer, component values, eight real ECS ticks, and the offscreen renderer.
- The rebuilt `tools/verify-window.bend` drove the actual native executable on an owned rootful Xwayland. It checked live movement, hidden ticks, retained replay, six camera keys, exact reset, repeated resize, unmap and restore, rejection recovery, Escape, hidden Close, and terminal cleanup.
- A separate replay baseline process ran the diagnostic query path with Khronos synchronization validation. Its stdout is valid JSONL and stderr is empty. Its timings are excluded from the baseline.

The existing window verifier uses deprecated `VK_LAYER_ENABLES`, which emits a settings-deprecation warning. Its logs contain no Vulkan validation errors. The separate diagnostic run uses `VK_LAYER_VALIDATE_SYNC=1` and emits no validation messages. The original warning is preserved in `diagnostic-validation-deprecated.log`. No dependency file changed.

[Independent review](verification/2026-11-03-baseline/review.md) accepted the raw measurements and reproduced their statistics. It found an attempt-cap boundary defect outside the recorded runs. The corrected collector completed a real replay run at exactly 151 available attempts and rejected a 150-attempt run, with zero live objects in both cases. Those correctness experiments are excluded from the baseline.

## Exact measurement boundaries

All clocks use `V.monotonic_ns`. Logs, sorting, statistics, JSON formatting, file writes, and process teardown occur after the bounded collection. `render_call_wall` ends before the drawing checks, digests, and sample insertion performed by `record_sample`.

| Metric | Start and end |
| --- | --- |
| `startup_through_first_completed_frame` | Immediately before window setup through the return of the first completed frame, including device creation, mesh setup, initial real ECS work, lazy target and pipeline creation, recording, all required waits, presentation, and retirement. Compilation, process launch, metadata serialization, and teardown are outside. |
| `open_window_device_mesh` | Startup clock through successful `Win.open_measured`, including device selection, resource allocation, optional diagnostic pool creation, mesh serialization, and both writes. |
| `mesh_vertex_host_write`, `mesh_index_host_write` | Immediately before the actual host write through the accepted-call counter update. Serialization and payload length traversal precede these spans. |
| `world_create` | Immediately around `Scene.create`. |
| `simulation` | Immediately around `Scene.tick`. The initial tick ends before the scheduling-clock read. Live updates preserve the original 250 ms due-time policy. |
| `observation` | Around `Observe.snapshot`. Snapshot validation runs afterward. |
| `extraction` | Around `Observe.draw_list`, the same extraction used by `Extract.observe`. Inspector-key and world-clock capture precede this span. `Extract.observed` performs the original preservation validation afterward. |
| `replay_initial_*` | The corresponding real tick-two startup operations. Replay still draws the retained tick-one list. These startup samples do not enter steady distributions. |
| `target_upkeep` | Before extent handling through `Indexed.ensure` and target retention. The startup sample contains lazy swapchain, depth target, render-pass, framebuffer, and pipeline creation. Stable steady samples reuse those objects. |
| `view_preflight` | Before building the camera at the actual target extent through camera and drawing preflight, before acquisition. |
| `acquire_call` | Immediately around `Device.acquire`. |
| `acquire_wait_and_reset` | Around `Indexed.wait(acquire)`, including its fence reset. |
| `record` | Before command-buffer begin through command-buffer end. Includes acquisition attachment, query commands, barriers, per-item matrix packing, pushes, and indexed draws. |
| `submit` | Around `submit_synced` and its accepted-call counter update. |
| `render_wait` | Before render-fence wait through the successful completion check. Fence reset is outside. |
| `query_read_and_conversion` | Around result readback and duration conversion, after the render fence completes and before command reset. |
| `render_fence_reset`, `command_reset` | Around the named reset operation. |
| `present_call` | Immediately around `Device.present`. |
| `present_wait_and_reset` | Around `Indexed.wait(present)`, including its fence reset. |
| `retirement` | Around `Indexed.retire`. |
| `render_call_wall` | Before `Win.frame` through its return, including target handling, preflight, acquisition, recording, submit, waits, query read, resets, present, and retirement. |
| `poll` | Around `Win.poll`, preserving its existing native poll timeout. |
| `loop_service_before_buffer` | Before poll through the end of frame return. Includes due application work and its validation. |
| `evidence_checks_digest_initial_buffer` | After the frame-return clock through exact drawing checks, digesting, and initial sample and run-state construction. |
| `loop_through_initial_buffer` | Before poll through that initial sample construction. The final insertion of these two envelope metrics occurs afterward and is excluded. This is not a fully inclusive event-loop period. |
| GPU interval | TOP_OF_PIPE before the first host-buffer or image barrier through BOTTOM_OF_PIPE after the final transition to PRESENT. Both timestamps are outside the render pass. |
| GPU CPU bound | The independent CPU clock before submit through the successful render-fence completion check. CPU and GPU epochs are never subtracted. |

The first startup attempt has no poll. The startup subscopes remain in its raw record and have one observation per process. Later live frames without a due tick use unavailable metrics with `not scheduled`. Replay uses `not executed in replay`. Missing metrics never contribute zero-duration observations.

The timestamp owner remains in `Win.Renderer` when a reset or timestamp command disables the active frame view. A successful command reset releases query references before the pool can be reused or destroyed. Diagnostic failures produce unavailable metrics where rendering can continue. A fatal API error, invalid stable target, deadline, capacity exhaustion, crash, or watchdog termination invalidates the repeat. The driver archives available stdout, stderr, and process status and stops. Partial counters are unavailable on fatal failure. It never guesses a successful prefix or replaces a failed repeat automatically.

The fixed-workload collector rejects requested-size changes and rejects a target retired after startup. It therefore cannot mix an implicit target rebuild into steady timing. Normal renderer resize behavior remains covered by the independent window verifier.

The following roadmap metrics are explicitly absent.

| Metric | Status |
| --- | --- |
| Change collection | Not applicable. There is no separate change collector. |
| RenderScene update | Not applicable. There is no retained RenderScene. |
| Visibility | Not applicable. There is no visibility pass. |
| Separate packing and upload preparation | Not measured separately. Matrix packing is inside recording. Mesh serialization is inside startup setup. |
| GPU parallel compute using Bend `!` | Not applicable to this run. Bend GPU dispatch is off. Vulkan rendering is real GPU work. |
| Driver command count, physical upload traffic, physical display latency, peak memory | Not measured. |

The intervals overlap. Adding CPU scopes or adding GPU time to CPU time does not produce full-frame time. Neither a present call nor present-fence completion measures physical display latency.

## Configuration and provenance

The host is an AMD Ryzen 5 1600 with six cores and 12 logical CPUs, and an NVIDIA GeForce GTX 1660 using driver 615.78.08. The runtime device record identifies the actual selected device and queue families. The machine runs Arch Linux with niri on Wayland. The renderer used an owned rootful Xwayland at 1280 by 1024 and a 640 by 480 client window. Present mode is the successfully created FIFO mode. Each process used one Bend worker, Bend GPU dispatch off, one frame slot, `Camera.initial`, and the same shared mesh and 100-object scene.

Each process collected one startup presentation, 30 completed warm-up presentations, and at least 120 steady presentations. Live collection extended until eight genuine steady ticks completed. The world schedule stayed at 250 ms. No tick-per-frame substitute ran. There is no random scene seed, physics dt, interaction count, or compute batch size in this discrete translation example.

The attempt cap is 3,000 total, including startup. The internal deadline is 60 seconds. Each child also has an external 70-second `timeout` watchdog and a five-second termination grace. The Bend driver has an 80-second process timeout. The outer ten-process driver command has a 600-second watchdog. Only fixed-extent normal presentations with no suboptimal acquisition qualify. All attempts remain in the raw stream.

The recorded base revision is `f4aea1fa7e18e06812fd5fbcef935bf08cc107e3`. Collection ran before the implementation was committed. `source.sha256`, `tracked-source.patch`, `dirty-before-collection.txt`, and `binaries.sha256` identify the measured source and binaries. Independent review then corrected collection at the attempt-cap boundary. `measured-collector.bend` preserves the exact pre-correction collector matching the manifest's `examples/scene-window-baseline.bend` entry. All other measured source files remain unchanged. No recorded repeat reached the cap, and the correction changes no measured phase or rendering call. Bend is pinned to 2.0.39 and Clang to 23.1.4. Native builds use Bend's default `-O3`; `observed-clang-command.txt` records the actual compiler invocation. Dependency revisions remain those in `toolchain.bend`, with clean dependency checkouts verified by the gate.

The raw [protocol metadata](verification/2026-11-03-baseline/protocol.json), CPU, compiler, kernel, OS, Vulkan, NVIDIA, load, environment, pin, and source files are in [the evidence directory](verification/2026-11-03-baseline). Validation is off in the ten timed processes. CPU clocks, successful-call counters, two GPU queries, exact drawing checks, and bounded sample storage are enabled.

Instrumentation overhead is unmeasured. These values describe the instrumented collector. There is no diagnostics-off timing comparison and no claim that the counters or queries are free.

The diagnostics-off path also traverses and reconstructs push payloads to determine their size. Its performance impact is unmeasured. The baseline establishes instrumented costs, not performance equivalence with the prior uninstrumented implementation.

## Limiter evidence and limits

A separate excluded live process ran with `/proc` and `ps -L` observations every 100 ms, `vmstat` every second, and NVIDIA system telemetry every 200 ms. Its raw output and observations use the `observation-*` filenames. No profiler or system sampler ran during the reported ten-process set.

The main thread appeared in `x64_sys_poll.cold` in 14 of 24 observations. The current native polling implementation calls `poll` when no X event is pending. This agrees with the separately timed poll interval dominating the median loop envelope. System GPU utilization was 0 to 6 percent in that observation and the steady GPU interval was much smaller than CPU loop service. This supports an event-polling and scheduling limit for median loop cadence. It does not identify the limiter inside simulation or extraction. `perf` and `strace` were unavailable, so no call-stack or syscall-count profile resolves those phases.

The desktop, browser, chat application, and compositor remained active. Load snapshots include uptime, `nproc`, and competing processes. The observation showed system idle time of 87 to 92 percent in interval samples, with 1 to 4 percent I/O wait. Those samples and shared GPU utilization do not isolate the renderer from every source of noise. Alternating modes reduces drift but does not remove that noise. The CPU and GPU frequency policy remained the desktop default.

No thread-count comparison, GPU lane scaling study, optimization, or cross-device portability benchmark was performed. There is no performance conclusion about another machine or future engine phase.

## Architecture synthesis

`Metric` distinguishes available values from missing measurements. `FrameOutcome` distinguishes skipped, submitted, and completed work. `Counters` records accepted public calls. `Win.Renderer` owns the optional query pool separately from its active frame view and generation. Normal `open` creates diagnostics off. `open_measured` enables them before actual mesh writes.

The existing indexed-draw traversal is shared by normal, offscreen, and observed rendering. The separate bounded entrypoint adds collection policy while retaining the same native renderer. The Bend collection driver owns fresh processes, watchdogs, raw output, and repeat-median summaries. There is no copied renderer or generic template profiler.

Model the Domain shaped the explicit outcome and availability types. Prove It Works required native pixels, real query reads, successful counters, and zero-object cleanup. Explain the Number required the excluded observation run and the instrumentation limitation. Build the Lever produced the rerunnable Bend collector and driver. Laziness Protocol kept the existing draw traversal as the single issuing implementation.

## Rerun

Preserve the current evidence directory before another collection. The driver writes the ten named raw files and the repeat-range file there. It does not retry failed repeats.

```sh
bend PROOF.bend
bend tools/verify.bend
bend examples/scene-window-baseline.bend -o build/scene-window-baseline
bend tools/baseline-collect.bend -o build/baseline-collect
bend tools/verify-window.bend -o build/verify-window
mkdir -p build/baseline-evidence
: > build/baseline-evidence/display
Xwayland -displayfd 3 -geometry 1280x1024 -nolisten tcp \
  3>build/baseline-evidence/display >build/baseline-evidence/xwayland.log 2>&1 &
owned_display_pid=$!
trap 'kill "$owned_display_pid" 2>/dev/null; wait "$owned_display_pid" 2>/dev/null' EXIT
for attempt in $(seq 1 100); do
  [ -s build/baseline-evidence/display ] && break
  kill -0 "$owned_display_pid" || break
  sleep 0.05
done
[ -s build/baseline-evidence/display ] || exit 1
read -r owned_display_number < build/baseline-evidence/display
DISPLAY=":$owned_display_number" timeout --signal=TERM --kill-after=5s 240s ./build/verify-window
DISPLAY=":$owned_display_number" env -u VK_LAYER_ENABLES \
  VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation VK_LAYER_VALIDATE_SYNC=1 \
  ENTANGLE_WINDOW_MODE=replay timeout --signal=TERM --kill-after=5s 70s \
  ./build/scene-window-baseline +RTS --threads 1 --gpu off
DISPLAY=":$owned_display_number" timeout --signal=TERM --kill-after=5s 600s \
  ./build/baseline-collect +RTS --threads 1 --gpu off
```

A successful collector run emits config, selected-device, startup-summary, attempt, phase-summary, and terminal records. A successful driver prints `Five fresh alternating live/replay repeats archived.` Every `.status` file must contain zero. The owned display used for this record was stopped after verification and collection.

Exploratory runs remain separate. `exploratory-cap-boundary` preserves the first successful ten-process set before the total-attempt cap correction. `exploratory-before-rebuild-guard` preserves the second successful set before the stable-target guard. Neither set contributes to the published tables. Smoke records remain under `build/baseline-evidence` and are excluded. No failed measured repeat was replaced.
