# Project instructions

## Development workflow

Follow [the development workflow](docs/development.md). Define observable acceptance and its required evidence before implementation. Use one owner for coupled code, laws, and verification. Arena and adversarial-review panels are explicit opt-ins. For unfamiliar dependencies, run a real-input qualification probe before choosing the adapter.

Use `tools/verify-workflow.bend` to select required checks and retain a source-specific receipt. Keep source updates, applicable proofs, sensitivity controls, feature coverage, and task state together. Do not call a missing or skipped required check a pass.

## Tests

Do not add traditional unit, integration, or mock-based tests.

Correctness should instead be established through:
- invariants and properties defined in `LAWS.bend`;
- executable verification of those laws where possible;
- real-runtime validation;
- live UI tests and deterministic replay/evidence checks.

Prefer proving or validating a general property over adding example-based test cases.

Do not replace real execution with mocks or synthetic test-only implementations.

## Bend

Follow these rules:

- If code can be written in Bend, do not use another programming language.
- Write only formal claims in `LAWS.bend`.

## Parallelism

Follow these rules:

- Independence alone is not sufficient reason to fork.
- Prefer sequential execution unless representative end-to-end benchmarks
  demonstrate a repeatable improvement.
- For CPU parallelism, benchmark representative thread counts including
  1-thread and the primary development-machine configurations.
- For GPU execution, benchmark representative Bend lane/work decomposition
  separately; do not infer GPU performance from CPU thread scaling.
- Validate candidate parallelism in representative end-to-end workloads on
  the currently available execution lane, not only in isolated or headless
  benchmarks.
- Reject performance changes that alter observable world/geometry state.
- Keep fine-grained work sequential at leaves.

## GPU portability

Follow these rules:

- Current CUDA and Metal lanes are execution targets, not architectural
  dependencies.
- GPU execution (`!`) is an execution/optimization choice and must not change
  program semantics. Where practical, the same algorithm should remain valid
  without GPU dispatch.
- Do not add temporary CUDA-specific architecture merely because a future
  WebGPU lane is not available yet. Prefer portable Bend code even when the
  current backend could support a more specialized implementation.

The project must target Bend's portable GPU execution model rather than any
specific GPU backend.

GPU-oriented Bend code must remain portable across the currently supported
CUDA and Metal lanes and should be designed to remain compatible with future
WebGPU lanes.

Do not introduce CUDA-, NVIDIA-, Metal-, Apple-, or platform-specific
assumptions into core engine algorithms unless strictly necessary.

In particular, core engine code must not rely on:

- CUDA warp size or warp-specific behavior;
- CUDA streams or CUDA-specific synchronization semantics;
- NVIDIA-specific memory hierarchy assumptions;
- Metal-specific execution details;
- backend-specific intrinsics or data layouts.

Backend-specific code, when unavoidable, must be isolated behind a narrow
boundary and must not affect the semantics of the engine.

Performance tuning may target the current hardware/runtime, but tuning
parameters must remain configurable and must not become architectural
requirements.

Prefer algorithms expressed in terms of Bend's execution and parallelism
model so that the same engine code can migrate to future GPU lanes, including
WebGPU, without redesigning the engine.
