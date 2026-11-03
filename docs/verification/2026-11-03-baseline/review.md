# Independent review and capacity correction

An independent gpt-6.1-sol reviewer accepted the recorded measurements after recomputing every per-repeat statistic and repeat aggregate from the raw samples. It checked all 2,237 normal presentations, counters, GPU generations, timestamp availability, raw duration conversion, source and binary hashes, and cleanup records. It inspected the native verification logs and timing boundaries. The comment review found no new or modified comments to remove.

The review found one collector defect. The zero-fuel branch rejected a run even when its last permitted attempt completed all quotas. The longest measured repeat used 304 attempts, so this defect did not affect the ten reported runs. The corrected branch checks quotas before reporting exhausted capacity. `review-cap-fix.patch` records the exact change. `measured-collector.bend` preserves the measured version, whose SHA256 matches the original source manifest entry. `review-source.sha256` identifies the reviewed implementation.

The parent verified the correction with the real native renderer and retained replay workload on an owned rootful Xwayland. The experiments changed only the initial loop fuel in a temporary copy of the production collector. No rendering, simulation, verification, counter, or timing implementation was substituted.

- Initial loop fuel 150 permits 151 total attempts because startup already rendered once. The run exited zero, reported 151 completed presentations, and retained zero live objects after cleanup. See `review-cap-151.jsonl`, `.stderr`, and `.status`.
- Initial loop fuel 149 permits 150 total attempts. The run exited one with an explicit capacity-exhaustion result and zero live objects after cleanup. See `review-cap-150.jsonl`, `.stderr`, and `.status`.

These are excluded correctness experiments, not additional baseline repeats. Their config records retain the production `max_attempts` metadata of 3000. The effective experiment caps are 151 and 150 as specified above. Their timing values do not enter any published statistics.

To reproduce the exact boundary workload, create the temporary source beside the original so its imports resolve. Use an owned Xwayland as described in the main report.

```sh
sed 's/loop(2999n,run,replay)/loop(150n,run,replay)/' \
  examples/scene-window-baseline.bend > examples/baseline-cap-check.bend
bend examples/baseline-cap-check.bend -o build/baseline-cap-check
ENTANGLE_WINDOW_MODE=replay timeout --signal=TERM --kill-after=5s 70s \
  ./build/baseline-cap-check +RTS --threads 1 --gpu off
```

Use `149n` for the insufficient-capacity experiment. Remove the temporary source after both runs and stop the owned display. Both cleanup steps completed for this review. The unmodified corrected collector also compiled natively as `build/scene-window-baseline-reviewed`. `review-proof.log` records another successful `bend PROOF.bend` run. `git diff --check` passed.

Remaining limitations are explicit in the main report. Instrumentation overhead and diagnostics-off payload traversal overhead are unmeasured. GPU compute scaling, physical transfer volume, physical display latency, and peak memory are outside this baseline. Formal counter laws establish field preservation; actual counter placement and rendering correctness have separate source review and real-runtime evidence.
