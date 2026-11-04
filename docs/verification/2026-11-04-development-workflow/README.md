# Development workflow verification

The process change keeps ordinary implementation with one owner, makes arena and adversarial panels explicit opt-ins, and requires a concrete acceptance contract and sensitivity controls for critical verifiers. The [development guide](../../development.md) defines the selected profiles, receipt format, and completion rules.

## Source scope

The initial full validation used main `90c7b7e7a3df83e57fce114c9153f3dc6fbfae20` plus the process changes in a disposable source tree. The then-active OBJ implementation was excluded. At that point, the shared `tools/verify.bend` contained both this task's preflight extraction and the OBJ task's new verifier invocation; the validation tree applied only the extraction over main. No existing product law or proof is weakened.

The new runner retains its own snapshot and complete input fingerprints. A result belongs to that snapshot, not to later edits in the shared checkout. This initial run preceded publication. The publication scope below records the later baseline.

## Confirmed corrections

The first full run rejected `src/image-png.bend` because the already-landed decoder was absent from the upload-boundary dependency policy. The policy now admits only the used PNG/codec symbols and the retained ezimg comparison probe interface. The reviewed closures contain Base and pure decoder modules, with no native upload path. The gate checks the three vendored Jonlib source hashes before scanning callers. The stable-source boundary now passes.

A separate validation attempt inadvertently copied the concurrent OBJ invocation without its implementation. It stopped at the missing verifier and left later stages unexecuted. Its evidence is retained. The corrected validation overlay excludes that unrelated invocation.

## Runner controls

The native runner rejects an empty `--plan`, an unknown profile, and a mixed valid/unknown selection. `--help` and valid plans pass. Repeated `assets` profiles produce only one assets stage and one boundary stage.

A copied production toolchain pin was changed from Bend 2.0.39 to an incorrect version. The real preflight failed, `run.status` stayed nonzero, and the dependent frontend/assets stages stayed `not_run`. Restoring the pin passed. No mocked process or test-only verifier was used.

The standard p3 validator passes all 56 installed skills. A separate Markdown inventory checks both Entangle skills and all local skill links. The two project skills pass the Codex skill validator. The stock Codex validator rejects the pre-existing p3 `disable-model-invocation` field; this change preserves that repository convention and adds supported `agents/openai.yaml` explicit-invocation policy for arena and interrogate.

## Final execution

The final native runner invocation completed with exit zero. `state` is `complete`, `run.status` is zero, and all 13 required manifest stages have zero status.

Evidence is retained at:

```text
/home/aivv/.t3/scratch/2026-11-04-skills-skills-home-aivv-agents-0301535c/entangle-process-validation/source/build/verification/workflow-fXhXHYta
```

Run command, from the validation source tree:

```sh
./build/verify-workflow all +RTS --threads 1 --gpu off
```

The registered profiles passed the pinned toolchain and source boundary, the existing native/offscreen gate, the owned mesh window and replay, the standalone upload kernel verdict, seven Bend-law mutation controls, eleven upload-source mutation controls, and eleven native-handler proofs with eighteen deliberate regressions and restored-source checks. Native execution observed real allocation failure, rollback and successful retry, exact readbacks, and zero-object cleanup. Rare driver errors remain bounded symbolic coverage.

The live-window evidence is under `source/build/verification/entangle-qpbtscpq` within that receipt. Replay matched 1433 live and 14 hidden-Close batches with full identities and transform bits. Initial, held, and reset captures were inspected; initial and reset are byte-identical. The owned display was reaped and the disposable runtime removed.

This is the registered `all` profile on the stated snapshot. It does not certify the OBJ implementation, other window scenarios in the feature map, other backends, or performance. The publication checks below cover a later correction to snapshot Git metadata; the launcher and stage implementations are unchanged. Publication uses an isolated checkout to keep unrelated local changes out of the commit.

The final runner controls are recorded in the task workspace at `entangle-process-evidence/runner-controls/final-controls.json`. Invalid pin evidence ends in `workflow-Dy9YxEPi`; the restored pass ends in `workflow-cLTbjcgq` under the retained original toolchain snapshot. The manifest and dependency checks establish these as separate runs.

## Publication checks

Publication starts from main `a016c6b3ef3aadd7961b191acf59803e225bcea2`, which includes the merged OBJ importer and the PNG dependency-policy correction. The branch is `chore/verification-workflow`. The earlier 13-stage run remains evidence for its stated source scope; it is not a new full run of this baseline.

A clean worktree exposed two setup issues. The documented build command needed `mkdir -p build`. More substantially, copied submodule Git files could point outside the source snapshot and fail to resolve. The runner now creates local repositories with their own object copies and indexes for the root and pinned dependencies. No original repository is changed by that setup.

Native toolchain runs pass from a Git worktree and from a standalone snapshot repository. A separate copy passed preflight, rejected a deliberate edit to a tracked Bend dependency file, and passed after restoration. Its original dependency stayed clean. All four copied repositories resolve their own top-level directories and have no Git object alternates. The failed worktree attempt remains in `workflow-sw6d12dA`; the corrected toolchain receipt is `workflow-iA0Fkb1g` under the publication checkout's `build/verification`.

Direct `bend PROOF.bend` returned `ALL PROOFS CHECK`; the source-boundary check, six native CLI controls, Bash syntax, and the two project skills' 44 local links passed. The CLI controls were repeated after the metadata correction.

Publication-side logs and control output are in the task workspace's `publish` directory: `entangle-proof.log`, `entangle-boundary.log`, `entangle-cli-controls-final.json`, and `entangle-snapshot-controls.json`. The earlier native/window evidence retains its original limits. This metadata correction does not change the window launcher or stage implementations.

The p3 process changes are committed as `46c9db38a00b0a3419e44bd5add9f615ecea2b5a` on `refactor/verification-first-workflow` in [aivv73/p3-stack](https://github.com/aivv73/p3-stack). The original upstream denied push access. Publication excludes unrelated pre-existing local changes. The isolated p3 branch has no new validation errors and no errors in its 13 changed files; its baseline still has two pre-existing link diagnostics in untouched templates. The earlier clean validation of 56 installed skills describes the complete local checkout, which contains additional unpublished work.

The final publication run `./build/verify-workflow proofs +RTS --threads 1 --gpu off` completed in `build/verification/workflow-RF4JIqrE` under the publication checkout. All seven required stages have status zero: pinned toolchain, source-boundary build and execution, root frontend proofs, standalone upload kernel verdict, and law-mutation build and execution. The law driver rejected seven named production regressions and passed the restored baseline. `state=complete` and `run.status=0`. Production, driver, runner, and proof source bytes match this receipt; subsequent edits only update documentation.
