# Sequential step extraction evidence

The baseline is commit `d18c962`. The candidate is the extraction on
`feat/sequential-step`. [Source hashes](sources.sha256) identify the verified
kernel, adapter, laws, and proofs. The
[Entire change](https://entire.com/et/bend-engine/-/trails/10/changes/entangle/11)
contains the implementation.

## Checks

- [Proofs](proof.log) report `ALL PROOFS CHECK`. They cover exact translation,
  preserved rotation and scale, empty event output, and equality between the ECS
  callback and the extracted step. This is the standard Bend checker run, not
  `--verdict` validation.
- The native verifier passed [before](native-before.log) and
  [after](native-after.log) extraction. It checks the real ECS scene across eight
  ticks and the offscreen renderer in both index orders. `cmp` found the complete
  native logs and generated offscreen PPM byte-identical. The
  [offscreen hashes](offscreen.sha256) record the two PPM files.
- Fresh [before](window-before.log) and [after](window-after.log) window runs
  passed live movement, hidden ticks and Close, camera input, resizing, retained
  replay, Escape, rejected-input recovery, and terminal cleanup. Khronos
  validation was enabled. Scope cleanup left zero live Vulkan objects.
- The [Bend comparison](equivalence.log) found all 13 deterministic captures and
  the replay and terminal logs byte-identical. Timing-dependent live captures
  are checked for movement by the window verifier, not compared byte-for-byte.

## Reproduce

Run `bend PROOF.bend` and `bend tools/verify.bend` from the repository root.
Run the [documented window gate](../../../README.md#verify-the-ecs-window) using
an owned rootful Xwayland. Preserve `build/window-evidence` after each revision.
For this run, the captures remain under `build/step-before/fresh-window-evidence`
and `build/step-after/window-evidence`.

```sh
bend tools/compare-window-evidence.bend -o build/compare-window-evidence
./build/compare-window-evidence build/step-before/fresh-window-evidence build/step-after/window-evidence
```

The evidence does not establish performance, cross-backend bitwise determinism,
or a complete headless scene contract. Refusal branches remain structurally
unchanged; these runtime checks do not inject write refusals. No traditional
unit, integration, or mock-based tests were added.
