# Upload-range proof verification

Checks run on November 3, 2026, with Bend 2.0.39. The base Entangle revision is `77dc4cd5a87c842fdf75174859b1033af173f12d`, bend-vulkan is `a144f7dd4fb4835ca3d5ce17350fc850de049038`, and bend-collections is `bc78c4f4cabb536a2a1dd6e308b6a8f0afafda7c`. Production source and dependency pins are unchanged. Verification uses formal proofs and a controlled mutation, without traditional tests or mocks.

The following commands each exited `0` and reported `ALL PROOFS CHECK`:

```sh
bend proofs/upload-range/word.bend
bend proofs/upload-range/natural.bend
bend proofs/upload-range/bridge.bend
bend proofs/upload-range/PROOF.bend
bend PROOF.bend
```

The corresponding logs are `word.log`, `natural.log`, `bridge.log`, `standalone.log`, and `root.log`. `bend guide` was read before implementation. Standard checks are Bend frontend proof checks. Their output explicitly recommends `--verdict` for mathematical validity.

The parent independently reran the root proof gate and the standalone `--verdict` command after inspecting all six proof modules. Both exited `0` and reported `ALL PROOFS CHECK`. See `parent-root.log` and `parent-verdict.log`. The scoped comment review found no comments, suppressions, or unresolved constraints. `git diff --check` passed, and both dependency checkouts remained clean.

## Controlled mutation

A disposable directory under `/tmp/entangle-upload-range-mutation.*` held copies of `proofs/upload-range`, `deps/bend-vulkan/src`, and `deps/bend-vulkan/deps/bend-collections`. Run Bend from that directory. A symlink to the original collections directory causes Bend's import-path validation to fail before proof checking, so the successful experiment uses a real copy.

The unchanged copied `bend proofs/upload-range/PROOF.bend` exited `0`. In the copied `core.bend`, the sole mutation replaced:

```text
Bool.not(size_less(capacity,offset)) && Bool.not(size_less(W.add(capacity,W.neg(offset)),length))
```

with:

```text
Bool.not(size_less(W.add(capacity,W.neg(offset)),length))
```

The same proof command exited `1`, reported `SOME PROOFS FAIL`, and rejected `Laws.universal`. Restoring the copied production file and rerunning exited `0`. See `mutation-original.log`, `mutation-rejected.log`, and `mutation-restored.log`. The law and proof were unchanged throughout this experiment. Tracked dependencies were untouched.

## Kernel checks and trust limits

`bend proofs/upload-range/PROOF.bend --verdict` exited `0` and reported `ALL PROOFS CHECK`. This is the standalone entry point, without Entangle's unrelated ECS imports. See `verdict.log`. Both `timeout 60s bend proofs/upload-range/natural.bend --verdict` and `timeout 60s bend proofs/upload-range/word.bend --verdict` also exited `0` and reported `ALL PROOFS CHECK`. See `natural-verdict.log` and `word-verdict.log`.

The standalone `--verdict` result includes the universal theorem, the limb-value claim, and their imported arithmetic proofs. The root entry point received a standard check, not a kernel verdict. Kernel validation is for the Bend definitions and proof terms. It does not verify native code generation, native ABI behavior, the installed checker binary, GPU execution, or production enforcement of this predicate. All claims depend on the checked source dependency revisions and the correctness of the verification tooling.
