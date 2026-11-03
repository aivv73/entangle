# Game Engine in Bend — Roadmap

**Revision:** 6 · November 3, 2026 · updated for E1 completion, E2 App extraction, and static startup registration

**Engine repository:** [Entangle on Entire](https://entire.com/et/bend-engine/entangle). **Vulkan library:** [bend-vulkan on Entire](https://entire.com/et/bend-engine/bend-vulkan).

**Status:** E0 and E1 are complete [S24–S30]. E2 is in progress. Entangle renders 100 moving Bendvy entities through the public Vulkan API, with verified camera input, resizing, exit handling, and recorded CPU/GPU baseline measurements. App resource scope, startup/shutdown cleanup, time, input, and error handling are extracted in `912639e` on `main` [S31]. Source-fixed startup registration now supplies Core, Input, Assets, and Render through four typed callable slots. The second application and the remaining E2 tasks are still open. E3–E7 and R0–R4 remain planned.

**Goal:** an independent, modular game engine, with Bevy-like modularity but a simulation core designed around Bend's computational model. Engine logic and new algorithms are implemented in Bend; native code stays at the system boundary.

**Next release:** `v0.1-alpha` — two non-voxel applications, a public API, a persistent scene representation, and the first practically useful proven guarantee.

**Initial platform:** Linux x86-64, using the existing X11/Vulkan path.

**Schedule:** no calendar deadlines; each stage ends with a verifiable result.

## E1 progress, November 3, 2026

- Completed the separate engine project and native dependency-pinning task in Entangle. Exact commits and compiler requirements are in [toolchain.bend](toolchain.bend); Git submodules retain the dependency revisions.
- `bend tools/verify.bend` passed on Linux x86-64. One native executable runs the upstream scheduled-health consumer and Vulkan buffer roundtrip. The check compares the complete ECS output and requires zero live Vulkan objects after cleanup [S25].
- Project component records, exact defaults, structural laws, and a native field-preservation consumer are implemented.
- The registered scene creates 100 entities once and translates each by `(1.0, 0.5, -2.0)` per tick. An explicit publication barrier makes the new entities visible before movement on tick 1. All entities retain logical mesh ID 7, rotation, scale, and full entity identities across eight native ticks [S26].
- `Observe.draw_list` extracts only complete transforms and mesh references. It returns the retained application separately and shares the observer's ordered component traversal. Proofs and native checks passed for empty extraction, repeated extraction, retained lists across ticks, and inspector and world-clock preservation [S27].
- The offscreen renderer consumes the actual detached `DrawList`, uploads one shared mesh per scope, and reuses Vulkan resources. Bend computes complete translation, quaternion rotation, scale, and camera transforms. No new C code or dependency changes were needed [S28].
- The full verifier passed with clean dependency checkouts and unchanged pins. It includes the dependency baseline, component consumer, shared-mesh scene, and offscreen renderer. The final reviewed native build also passed Khronos synchronization validation on the GTX 1660, with zero live objects after cleanup. Entangle window checks, sanitizers, benchmarks, and the full upstream suites were not part of this run [S28].

- Entangle now renders the actual shared-mesh DrawList in the existing native window path. The separate window driver verified live ECS movement, retained tick-one camera replay, repeated resizing, hidden polling and ticks, Escape, hidden Close, input rejection, and terminal cleanup on the GTX 1660 with Khronos synchronization validation [S29].

- Reviewed CPU/GPU baseline timings and counters complete the final E1 task [S30]. The window runs satisfy E1's moving-scene, controllable-camera, resize, and exit criteria. The App extraction reran these checks without changing their results [S31]. E1 is complete.

## E2 progress, November 3, 2026

- Extracted shared App resource scope, time policy, camera input, event draining, and Action error handling. Concrete scene state and verification live in `examples/scene-window-app.bend`. The interactive and measured loops remain explicit and retain their distinct input and reporting policies [S31].
- Formal proofs, native/offscreen verification, and real-window checks passed. All 13 replay/control/resize/restore captures and the replay and terminal logs matched the pre-refactor evidence byte for byte. Measured live and replay runs preserved drawing digests and counters and left zero live Vulkan objects [S31].
- App extraction and source-fixed startup registration are implemented. Registration supports startup only, with the existing mesh and concrete renderer. A public application API, the sequential step contract, fixed-timestep catch-up policy, headless execution, and the second application remain open. The existing 250 ms due-time policy advances once when due and does not implement fixed-timestep catch-up.

## History: what changed in revision 6 before E1

- Completed the E0 item requiring the library verifier to run from a clean Git checkout of a published revision, together with the new example. A fresh clone was obtained from Entire; local Git objects were not used as a fallback. The pinned `bend-collections` commit is `bc78c4f4cabb536a2a1dd6e308b6a8f0afafda7c`; both checkouts were clean before and after the runs [S24].
- The library verifier exited with code `0`, with `DISPLAY` and `WAYLAND_DISPLAY` unset. The window verifier exited with code `0` in a separate rootful XWayland; both shutdown scenarios left `live Vulkan objects: 0`. The initial failed desktop-display run and validation warnings were also preserved [S24].
- Current commands were updated to the Bend runners: `tools/verify.bend`, `examples/verify.bend`, and `examples/verify_window.bend`. Python commands from earlier runs remain only as historical evidence; this is not a rerun of the removed native fixture/probe suites.
- Updated the repository README and closed E0. E1, the first Bendvy ECS → Vulkan scene, is next; the scope of E1–E7 and R0–R4 is unchanged.

## History: what changed in revision 5

- Marked E0's “independent window example” item complete: the published `bend-vulkan` contains `examples/indexed_window.bend`, with an indexed cube and floor, an orbit camera, depth testing, resizing, and exit handling; it has no dependency on `bend-voxel` [S23].
- The README documents `examples/verify_window.py` and its rendering, camera, resize, suspend/restore, and shutdown checks. Published code and instructions are not equivalent to a successful local run in that revision [S23].
- At revision 5, E0 acceptance remained incomplete: verification from a clean checkout of the library revision with recorded results was still open. The clean-checkout gate was completed in revision 6 [S24]. E1–E7 and R0–R4 are unchanged.

## History: what changed in revision 4

- Clarified the direction: a functional simulation-step boundary, explicit data ownership, and independent computations expressed in Bend. This does not require copying the entire World every tick or promise automatic speedups.
- Preserved E0–E7, the original E0 acceptance criteria, the `v0.1-alpha` release in E5, Bendvy, and the existing Vulkan path. The completed repository split is not being redone.
- Added a `step` contract and a simple sequential reference to E2. A parallel simulator, a new physics solver, and a million entities are not alpha requirements.
- Replaced the previous brief optional item with a concrete R0–R4 track: toolchain capability checks → independent updates → interactions within one world → integration → a separate physics experiment. After alpha, R0–R3 take priority over new graphical effects.
- Established three distinct mechanisms: updating independently owned data, combining contributions by recipient, and iteratively solving coupled constraints. Structural commands have their own conflict semantics.
- Connected research on Pure Borrow, Birdseed, VBD/AVBD, functional array languages, and verified optimization to concrete experiments and rejection criteria. These are not mandatory middleware.
- Added end-to-end measurements of copying, neighbor reads, merging, imbalance, and the ECS adapter; separated equivalence proofs from tests and from the correctness of the specification itself.

**Basis for the update:** revision 3 supplies statuses and previous constraints; the discussion supplies the new direction; external sources S14–S22 were checked on November 2, 2026. The proposed architecture is a project decision, not a result already demonstrated in Bend by those works.

## History: what changed in revision 3

- The repository split was completed and published: `bend-voxel → bend-vulkan`.
- The voxel renderer, Atelier, shaders, tests, laws/proofs, and tools reside in `bend-voxel/vulkan/`. The intermediate `consumers/voxel/` directory no longer exists in the library.
- Library checks work without `bend-voxel` files; verification results and limitations are listed under E0 below.
- At revision 3, the next step was an independent window example with a conventional mesh; it was completed later, as recorded in revision 5. The clean-checkout gate and E0 closure were recorded in revision 6.
- The content and order of E1–E7 were unchanged.

## History: revision 2 changes from the first revision

- Preserved E0–E4: independent library → ECS and graphics → application API → first guarantee → assets and scenes. These were not replaced with a new project.
- E5 now includes a persistent RenderScene, change-driven updates, and the alpha release. Migrating `bend-voxel` is no longer a release requirement.
- Added E6 — a small, verifiable render graph — and E7 — an optional GPU-driven path. Both follow the first alpha.
- Ideas from the Skyrim blog inform the design rather than requiring the entire described stack to be reproduced immediately.
- Moved two-phase parallel simulation into a separate experiment. MMO support, sharding, and a new scheduler were not added to the required scope.
- Preserved the Bend-first principle: do not move the engine architecture into C/Rust under the pretext of easier integration.

**Next action:** define the E2 public application API and sequential step contract on top of App extraction and static startup registration. E1 is complete.

---

## 1. Project boundaries

### What “an engine in Bend” means

App, systems and ECS integration, scenes, transforms, resource management, game logic, draw-data extraction, and pass planning live in Bend. New engine algorithms are also written in Bend by default.

The native layer handles the ABI, system calls, driver objects, and boundary protection. Visibility determination, game-scene management, material selection, and the pass dependency graph are not moved into it.

Existing defensive checks in the C backend are retained. They should not be removed before a verified replacement exists. The existing GLSL → SPIR-V path remains an explicitly identified GPU-code boundary; a custom Bend shader compiler is not an alpha requirement [S1, S2].

Formal guarantees apply to specific executable functions under listed assumptions, not to the entire driver, compiler, or image on the screen.

### Bend-native simulation: agreed boundaries

Conceptual interface, **not verified Bend syntax**:

```text
step(state, tick_input, tick_config) -> next_state + events + diagnostics
```

Ownership of `state` is transferred to the computation. The interface does not promise that the previous state remains available. Snapshots, rollback, and replay are different capabilities: an input log does not replace a snapshot, and a pure function does not make snapshots free. I/O, real clocks, devices, and publication of results remain in App; each tick receives explicit inputs and configuration.

The current Bend guide describes a uniquely owned `Array` with in-place writes and a binary fork–join scheduler that does not move already assigned tasks. It also documents wrapping array indices [S14]. This describes the documentation reviewed, **not the results of checking the project's pinned Bend 2.0.39**. R0 will check applicability; the compiler must not be silently upgraded.

Project rules:

- A functional boundary is compatible with mutating storage owned by the function. The goal is to avoid unnecessary copies, not to prohibit all copying or all mutable arrays.
- A `storage chunk` defines data placement and ownership; a `work batch` defines the amount of computation. A spatial region does not have to correspond to a task. Changing the partitioning does not change the simulation rules.
- Independent updates operate on disjoint ownership. Contributions from multiple interactions are collected and combined first. Coupled constraints are solved in separate iterations with explicit dependencies.
- Reading another chunk requires an implementable protocol: a read-only view, a bounded halo/snapshot, or another verified path. An affine array cannot simply be declared available to every worker without costs and access rules.
- Bendvy remains responsible for entity identity and application scheduling. Small computational kernels execute within the relevant systems; a second general-purpose scheduler is not created.
- The initial target is the CPU and **one interacting world**. GPU simulation, Vulkan compute, and a GPU-driven renderer are separate capabilities; having one does not establish the others.

### Research → decisions to validate

| Basis | What the source establishes | Our experiment / scope of application |
| --- | --- | --- |
| Pure Borrow, PLDI 2026 [S15] | Parallel mutation within pure computations in Linear Haskell | R0–R1: chunk ownership and a functional API. Do not transfer the Haskell API or its guarantees to Bend; parts of the paper's metatheory remain conjectures. |
| Birdseed, October 2026 [S16] | Compilation of parallel sparse-output construction, including scatter | R2: local contributions → grouping → application. This adapts an idea; it is not a compiler port or a ready-made solution to gameplay conflicts. |
| VBD, 2024 [S17]; AVBD, 2025 [S18] | Local iterative updates; an extension for hard constraints and high stiffness ratios | R4: a limited-scope solver in Bend. Do not promise the quality, stability, or speed of the authors' implementations for ours. |
| Comparing Parallel Functional Array Languages, 2025 [S19] | A comparison of five languages on CPU/GPU tasks, not an evaluation of Bend | R1–R2: compare representations, pass fusion, and temporary-data costs. Automatic fusion/flattening by Bend is not assumed. |
| Agentic Verified Optimization, October 2026 [S20] | Optimization with machine-checked equivalence in Lean 4 | Preserve the reference; verify optimized Bend code within the available model. Do not replace the verifier with an agent's promises or transfer a proof between languages without justification. |
| Brax [S21], Madrona [S22] | Accelerator-oriented simulation; Madrona uses ECS and many-world execution | Architectural references, not dependencies. Throughput across many independent worlds is not acceptance evidence for our single interacting world. |

No paper proves the performance of the future engine. The tasks below are our hypotheses and checks; third-party speedup figures do not become project promises.

### Target architecture

```text
Non-voxel applications / future game / optional bend-voxel
                                  ↓
                     Game engine in Bend
          App · Input · Assets · Scenes · RenderPlugin
                ├── Bendvy: entity identity, ECS, and system scheduling
                ├── Simulation: step / reference → kernels R0–R3
                │      ├── task-owned chunks
                │      ├── contributions / merging / structural commit
                │      └── constraints: separate R4 candidate
                ├── RenderScene: persistent rendering state
                ├── RenderPlan: fixed, later graph-based
                └── bend-vulkan: low-level GPU API
                                  ↓
                     Native bridge + Vulkan + OS
```

Bendvy must not depend on the renderer; `bend-vulkan` must not depend on ECS, scenes, assets, or the game. Engine modules initially live in one repository. A new repository is created only when an independent consumer emerges.

**OpenRenderGraph and BasicRHI are sources of architectural ideas, not mandatory native dependencies.** Integrating them must not turn Bend into an interface to someone else's engine.

### What the original revision recorded as of October 28, 2026

The reviewed `bend-vulkan` documentation describes indexed graphics, images, descriptors, synchronization, X11 presentation, and Bend 2.0.39; compute pipelines and indirect draws are marked as future work [S1, S2]. The reverse `bend-voxel` submodule was removed [S3]. `bend-voxel` now contains the renderer in `vulkan/` and depends on the library through `deps/bend-vulkan` [S12, S13].

Bendvy describes components, queries, systems, schedules, change detection, and deferred commands; its API is evolving [S4]. Its specification calls for law-driven development [S5]. This provides a basis for integration, but does not prove that the selected revisions are compatible.

The original file records the builds and runtime checks for the repository split listed in E0. They are carried forward as historical evidence and were not repeated here. The remaining information in this subsection is a previous documentation review, not a new compatibility check. No subsequent stage is automatically declared complete.

### Dependency policy

Start with the toolchain already validated by the user, not an automatically selected “latest” version. Pin the compiler version and dependency commits/hashes, and record build commands and the test environment. Upgrade the toolchain in a separate change with verification.

Use Bendvy through public interfaces. If difficulties arise, prepare a minimal example and discuss it with the author rather than immediately writing a custom ECS. Do not build a second general-purpose scheduler on top of Bendvy.

Reuse `bend-collections` for the required arithmetic/containers. Bring in math and decoders from Jonlib or other packages one verified module at a time. Ankra/SDL and a change of windowing layer are not mandatory alpha tasks. Compatibility with all of BendHub is not a milestone.

---

## 2. Stage order

| Stage | Verifiable result | Scope |
| --- | --- | --- |
| E0 | Library separated from `bend-voxel`; clean-checkout verifier and independent window example passed; README updated | Complete |
| E1 | Bendvy manages 100 rendered objects with verified window behavior and recorded baseline measurements | Complete |
| E2 | Two applications use the public API; a step contract and sequential reference are defined | In progress; App extraction and static startup registration complete |
| E3 | The production upload checker has a proven contract | First formal guarantee |
| E4 | Models, textures, materials, and an interactive scene | Assets and scenes |
| E5 | Persistent RenderScene, change-driven updates, reproducible alpha | `v0.1-alpha` |
| E6 | Small render graph with verifiable pass ordering | After alpha |
| E7 | Measured experiment with GPU culling and indirect drawing | Optional, after E6 |

E0–E7 are engine stages. They do not renumber `bend-vulkan`'s own milestones.

### New simulation track

| Stage | Verifiable result | Prerequisites / role |
| --- | --- | --- |
| R0 | Validated ownership/parallelism capabilities on the pinned toolchain, and a headless reference | After E2; not an alpha requirement |
| R1 | Independent updates to owned chunks, compared with the reference | After R0; CPU-first |
| R2 | Spatial search and correct interactions within one world | After R1; main research gate |
| R3 | Simulation module operates through App/Bendvy and a committed RenderScene | After R2 and E5; practical integration |
| R4 | Measured VBD/AVBD candidate with an explicit scope of applicability | After R2; a separate decision after R3, based on game needs |

Recommended order:

```text
E0 → E1 → E2 → E3 → E4 → E5: v0.1-alpha
                             ↓
                       R0 → R1 → R2 → R3
                                       ↓
                           small game / R4 as needed

Independently after alpha: E6 → optional E7
```

R0 may be done earlier, after E2, as an explicitly chosen short experiment. This does not change the E3–E5 criteria. E6/E7 are not prerequisites for simulation or a small game. The research interest now has a separate priority track, but does not turn alpha into a promise to finish all the research.

---

## E0 — Standalone bend-vulkan (complete)

**Goal:** build and verify the library without installing anything from `bend-voxel`.

### Tasks

- [x] Preserve the baseline commit, environment, and verifier results actually obtained. The completeness of the original run is qualified separately in the evidence.
- [x] Separate code and tests into the general Vulkan API, general graphics examples, and the voxel consumer.
- [x] Move voxel examples, shaders, tests, and their specific laws/proofs into the existing `bend-voxel` repository, under `vulkan/`.
- [x] Preserve a runnable historical version of Atelier and its verification commands. Migration to the future engine is not required.
- [x] Remove the reverse submodule and voxel imports from the library verifier. Pin the standalone `bend-vulkan` dependency in `bend-voxel`.
- [x] Update the README and public API documentation around the standalone library.
- [x] Provide an independent window example: a conventional indexed mesh, camera, depth testing, resizing, and shutdown — `examples/indexed_window.bend`, published and documented [S23].
- [x] Run the library verifier from a clean Git checkout of a published revision, initializing only `bend-collections`, and record the result together with a run of the new example. Completed on November 2, 2026, at `a144f7dd4fb4835ca3d5ce17350fc850de049038`; the library verifier and isolated window verifier exited with code `0` [S24].
- [x] Update the repository README with standalone-library acceptance, verification evidence, and the next engine stage.

### What is complete and where the code lives

- `bend-vulkan`: `Vulkan.bend`, `src/`, general `examples/` and `shaders/`, formal `LAWS.bend`/`PROOF.bend`; the library gate is built with `bend tools/verify.bend -o build/verify` and run with `./build/verify`; separate headless examples use `bend examples/verify.bend -o build/verify-examples` and `./build/verify-examples`. Create `build/` before compiling. Traditional unit/integration/mock and native fixture suites were removed under `AGENTS.md`; current verification relies on proofs, real Vulkan examples, and live UI evidence [S24].
- `bend-voxel`: `vulkan/` contains the renderer, examples, shaders, checks, and its own `LAWS.bend`/`PROOF.bend`; the gate is `python3 vulkan/tools/verify.py`. The main Bend-native renderer and its root laws are preserved.
- The split was published in `bend-vulkan` commit [`753f8f4`](https://github.com/aivv73/bend-vulkan/commit/753f8f49549b6eb17c6e609346fed5a580bdc8a1). The consumer migration is [`6c28547`](https://github.com/aivv73/bend-voxel/commit/6c28547); the pin update to the merged library is [`2e608c6`](https://github.com/aivv73/bend-voxel/commit/2e608c6).
- The original 111 library/consumer law statements are preserved: 64 in the library and 47 in `bend-voxel/vulkan/`. These supplement the existing root laws of `bend-voxel` itself rather than replacing them.

### Evidence and limitations

**New independent window example (revision 5):** the published `bend-vulkan` README describes `examples/indexed_window.bend`: a colored indexed cube above a floor, a perspective orbit camera, depth testing, A/D, W/S, Q/E, and R controls, and exit via Escape/the close button. Resizing recreates the swapchain, framebuffers, and depth attachment and updates the aspect ratio; a zero-sized or hidden window does not initiate acquisition. The example depends only on `bend-vulkan` and `bend-collections` [S23].

In revision 5, documentation confirmed the existence of the example and the former Python verifier [S23]. On the revision checked in revision 6, the example is still built and run with `bend examples/indexed_window.bend -o build/indexed-window` and `./build/indexed-window`; the window verifier is now built with `bend examples/verify_window.bend -o build/verify-window` and run as `./build/verify-window` [S24].

**Clean-checkout gate (revision 6, November 2, 2026):** a fresh remote clone of `entire://aws-eu-central-1.entire.io/et/bend-engine/bend-vulkan` confirmed both `HEAD` and `origin/main` at `a144f7dd4fb4835ca3d5ce17350fc850de049038`. Direct cloning succeeded after initial `ls-remote` availability errors. Only `deps/bend-collections` was initialized, at `bc78c4f4cabb536a2a1dd6e308b6a8f0afafda7c`, without recursive initialization or `bend-voxel` files. There was no `build/` directory before execution; `git status --porcelain=v1 --untracked-files=all` was empty for both the library and dependency before and after all runs [S24].

- Environment: Linux x86-64, Bend 2.0.39, NVIDIA GeForce GTX 1660; Khronos and synchronization validation were available and enabled in the relevant runtime checks.
- `env -u DISPLAY -u WAYLAND_DISPLAY ./build/verify` exited with code **0** at **17:24:16 UTC**. Generation/shader freshness, import boundaries, root proofs, pixel proofs with `--verdict`, example proofs, and public headless examples passed. All three proof entry points reported `ALL PROOFS CHECK`; real buffer/offscreen/indexed checks also passed under validation.
- The first `./build/verify-window` on the desktop's `DISPLAY=:1` exited with code **1**: the window manager changed the client size from `640×480` to `939×993`, and the verifier timed out waiting for the expected frame/extent. This result was preserved, not counted as a success.
- The rerun, `DISPLAY=:2 ./build/verify-window`, in a separate rootful XWayland exited with code **0** at **17:25:35 UTC**, without source changes. It checked colors, camera movement and exact reset, landscape/portrait resizing, unmap/restore, Escape, and closing a hidden window. Both runs of `indexed_window.bend` ended with `live Vulkan objects: 0`. The temporary XWayland was stopped afterward.
- There were no `Validation Error`, `SYNC-HAZARD`, or `VUID-` errors. `VALIDATION-SETTINGS` warnings about deprecated `VK_LAYER_ENABLES` were preserved. The two PPM frames are byte-identical; their SHA-256 hashes were recorded. The run did not use `--sanitize` or include benchmarks; it does not establish results for the old removed native probes or consumer checks.

The E0 report, commands, logs, and frame checksums reside in `bend-vulkan` under `docs/verification/2026-11-02/` [S24]. That directory in Entangle contains the separate E1 dependency-baseline record [S25]. E0 frames were retained locally under `build/published-verification/2026-11-02/` in the library workspace and in the clean clone's `build/`; binary frames are not included in Git.

**Historical evidence for the split (carried forward from revision 3):**

`python3 tools/verify.py --sanitize` passed with ASan/UBSan and Vulkan validation, including in a fresh temporary source tree without `consumers/voxel` and `deps/bend-voxel`. This confirms the absence of a file dependency, but is not described as a separate clean Git checkout of a published commit.

After the move to `bend-voxel`, both proof sets, shader freshness, measurement checks, timing-reset with sanitizers, shader GPU acceptance, reference lighting, and a rebuilt live Atelier window with carve, exact reset, and suspended close passed. Library native implementations and the bodies of the moved Bend/C/GLSL code did not change; import paths and verification tooling changed.

The consumer's full production sanitizer gate was not completed: the long Clang compilation was stopped. The broad instrumented `--presentation` gate was not rerun in full after the move. These are not passing results or conditions that may be silently weakened.

Baseline, environment, and results: [library split report](.audit/library-split.md). Migration and verification commands: [consumer migration report](https://github.com/aivv73/bend-voxel/blob/main/vulkan/docs/migration.md).

**Acceptance met:** a clean checkout passes the current library checks without `bend-voxel` files; the independent window example works with camera, depth testing, resizing, and shutdown; voxel checks are preserved in the consumer; the README and documentation reflect the library boundary. Historical consumer-verification limitations above remain unchanged.

**Out of scope:** new broad Vulkan coverage, moving the native registry to Bend, a new window backend, or refactoring all subsystems at once.

## E1 — First ECS → Vulkan scene (complete)

**Goal:** validate compatibility and responsibility boundaries in a small, real application.

### Tasks

- [x] Create a separate engine project. Pin compatible Bendvy and `bend-vulkan` revisions on one native toolchain. Completed locally in Entangle on November 2, 2026 [S25].
- [x] Add project components `Transform`, `Velocity`, `MeshRef`, and `MaterialRef`. Structural laws and the native consumer are gated by `bend tools/verify.bend`.
- [x] Create 100 entities sharing a mesh; a Bendvy system changes their position or orientation. Completed on `main` at `ff71773` with shared logical `MeshRef{7}` and translation updates [S26]. The offscreen consumer now supplies the shared mesh payload [S28].
- [x] Extract only drawing data into a small `DrawList`, not a copy of the entire World. Committed at `feeaa7f`, with proofs and native verification [S27].
- [x] Render it through the public `bend-vulkan` API, without a C function that knows about ECS or a particular scene. Offscreen rendering and exact color/depth readback are committed at `570e20f` on `feat/public-vulkan-renderer` [S28].
- [x] Use the existing input, camera, and window path. Implemented, independently reviewed, and verified on `feat/renderer-window` [S29].
- [x] Record baseline CPU/GPU timings and upload/command counters with explicit measurement boundaries. Five fresh processes per mode and raw samples passed independent measurement review [S30].

### Verified native dependency baseline

- Bendvy: `16405fbeb75cd6da1eb8c79ea48d3532ee9a30ee`.
- `bend-vulkan`: `a144f7dd4fb4835ca3d5ce17350fc850de049038`.
- Transitive `bend-collections`: `bc78c4f4cabb536a2a1dd6e308b6a8f0afafda7c`.
- Toolchain: Bend 2.0.39 and Clang 23.1.4, targeting `x86_64-pc-linux-gnu`.

Run `bend tools/verify.bend` from Entangle after the [dependency setup](README.md#verify-the-native-baseline). The imported Vulkan and Bendvy execution-law proofs passed. The combined native executable produced the expected output across six scheduled ECS updates, verified host and GPU buffer readback, and left zero live Vulkan objects. It used one Bend CPU thread with Bend GPU dispatch disabled; the Vulkan buffer fill still ran on the graphics device [S25].

This completes the dependency-baseline task. Its ECS example and Vulkan example run sequentially in one executable. The separate offscreen executable below now passes actual ECS drawing data to the renderer [S28]. The component records also have structural proofs and a native verifier.

### Verified shared-mesh ECS scene

The scene in [examples/scene.bend](examples/scene.bend) is committed on `main` at `ff717736acd156f3c0f1306aed4b988a2b0a9a54` [S26]. Creation leaves an empty world. Tick 1 queues 100 entities, publishes them before movement, and translates each once. Later ticks move the same entities by `(1.0, 0.5, -2.0)` without changing rotation or scale.

`bend PROOF.bend` checks general translation, rotation/scale preservation, seed contents/count, and exhausted-bootstrap claims. `bend tools/verify.bend` builds and runs the scene natively with one CPU thread and Bend GPU dispatch disabled. Across eight ticks, it checks all 100 entities against independent coordinate expectations, compares complete live and admitted handle sets including generations, and rejects changed mesh IDs, duplicate or missing rows, pending commands, and failed publication or execution.

The ECS-only example keeps mesh sharing as a logical reference. The offscreen consumer supplies one shared indexed mesh and renders the extracted transforms [S28]. Input, interactive camera, and window integration are locally verified [S29]. The instrumented native baseline is recorded locally [S30]. E1's acceptance criteria are unchanged.

### Verified drawing-data extraction

`Observe.draw_list(app, instance)` returns the retained application and inspector instance alongside a result containing `DrawList`. Each item contains only a complete `Transform` and `MeshRef`. The payload holds no World, entity handles, or bootstrap diagnostics. Drawing and diagnostic observation share the required-component traversal, query order, and strict failure policy. Drawing does not construct a diagnostic snapshot [S27].

The native scene checks exact ordered payloads, every transform float bit, mesh IDs, empty and repeated extraction, and retained lists after subsequent ticks. It also checks Fresh and Active inspector instances and the world clock. The full verifier passed with output identical to the pre-extraction baseline. Formal claims cover payload projection and local traversal steps. Extraction failure for a missing required mesh component has formal coverage but has not been exercised in the live runtime. These extraction checks do not establish rendering or performance [S27].

### Verified offscreen rendering

The [renderer](src/scene-render.bend) consumes only detached drawing data, a caller-supplied mesh, and a fixed camera matrix. It imports no ECS modules or dependency examples. Bend owns mesh validation, transforms, allocation composition, command recording, and readback. The existing shader receives sixteen column-major words for `camera * T * R(q) * S`. One mesh upload and reusable RGBA8/D32 resources live inside the public `Entry.with` scope [S28].

The [native executable](examples/scene-render.bend) renders all 100 entities across eight actual ECS ticks in both near-first and far-first index orders. Independent integer rectangles and dyadic depth encoding check every pixel. It also checks repeated frames, retained tick-one drawings, empty frames after populated frames, unknown mesh and invalid transform rejection followed by valid replay, and zero live objects after normal or terminal-error cleanup. Scalar cross-product checks supplement the seeded quaternion workload. The [coverage derivation](docs/render-verification.md) states the rounding assumptions [S28].

`bend PROOF.bend` and the full `bend tools/verify.bend` passed. The final reviewed native build passed with Khronos synchronization validation enabled on the GTX 1660. Validation emitted settings-deprecation warnings but no validation or synchronization errors. Review aligned accepted image and vertex sizes with the public API's 16 MiB transfer limit. Formal claims cover push-constant extent and index validation, not arbitrary floating-point matrix algebra or driver behavior [S28].

This completes the offscreen public-API rendering task. The separate window integration adds the existing interactive camera and presentation path [S29]. CPU/GPU timings and upload/command counters are recorded and reviewed [S30].

**Done when:** one executable shows moving ECS entities, a controllable camera, and correct resize/exit behavior. The example does not require game logic inside dependencies.

**Acceptance met:** the native window driver verifies each behavior above [S29, S31], and the reviewed baseline records CPU/GPU timings and command/upload counters [S30]. Measurement limitations remain recorded in S30; they do not establish performance claims or later-stage completion.

**Out of scope:** a complete GPU Scene, a render graph, a custom scheduler, or 10,000 objects as an acceptance threshold. Full extraction of a small list is acceptable here as a temporary reference implementation.

## E2 — App, plugins, and the game loop

**Goal:** create the second application through the engine interface rather than by copying the first application's internals.

### Tasks

- [x] Factor out `App`, startup/shutdown, time, input, and error handling. Implemented, verified, and merged into `main` at `912639e` [S31].
- [x] Add static module registration for `Core`, `Input`, `Assets`, and `Render`. Four typed callable slots support source-fixed startup assembly with the existing camera, mesh, and renderer. No general plugin lifecycle or Bevy Rust API is implemented.
- [ ] Define the order: input → fixed simulation → update → apply deferred changes → update global transforms → extraction → rendering → completion handling.
- [ ] Use Bendvy schedules. Define when structural changes and removal events become visible.
- [ ] Extract a small sequential `step` kernel from the existing movement logic. Specify tick inputs, state ownership, and output events; do not read I/O or real clocks inside the kernel.
- [ ] Use a headless example to define consistent semantics for tick start, numerical updates, and structural commit. This is the reference for R0, not a new ECS or a mandatory parallel runtime.
- [ ] Establish a single owner of mutable state: ECS data and future simulation chunks cannot be two independently writable versions of the same components.
- [ ] Add a fixed timestep and an explicit limit on catch-up steps; do not promise bitwise determinism for numerical computations.
- [ ] Support running game logic headlessly without a window or GPU.
- [ ] Introduce public operations for creating meshes, instances, a camera, and a basic material.
- [ ] Create a second non-voxel application: for example, an interactive scene with different meshes and a controllable object.

**Done when:** the second application does not modify the core, does not handle Vulkan handles directly, and has headless tests of its logic; the minimal step contract and sequential movement are accessible to those same tests. Parallel speedup is not required here.

**Architectural groundwork:** a logical `RenderId` and the extraction boundary appear now, but persistent scene storage belongs to E5. Use the existing ECS identity through Bendvy; a separate render handle must not replace it or be a pointer into a relocatable array.

**Out of scope:** dynamic plugins, automatic parallelization of every system, a new scheduler, R0–R4 results, networking, or a universal RHI for multiple APIs.

## E3 — First practical formal guarantee

**Goal:** the proof protects executable-code behavior, not merely a model alongside it.

### Contract: valid upload range

For any accepted `offset`, `length`, and `capacity`, the mathematical range `[offset, offset + length)` lies within the buffer. Machine-arithmetic overflow cannot turn invalid input into valid input.

### Tasks

- [ ] Review existing arithmetic laws and select an existing checker if its contract is sufficient. Do not duplicate a proven function just to satisfy a new milestone.
- [ ] Specify the U64 representation and preconditions; use a check without unsafe addition, such as `offset <= capacity`, followed by `length <= capacity - offset`.
- [ ] Prove the property for arbitrary accepted input, not only for the sizes of one scene.
- [ ] Integrate this exact function into the production upload path; prevent the engine's ordinary API from bypassing the check.
- [ ] Add ABI, boundary, and negative tests, including zero sizes and maximum values.
- [ ] Introduce a controlled bug that violates the contract and confirm that the proof is no longer accepted. Do not weaken the law to fix a failing status.

### Resource lifecycle

- [ ] Add mesh replacement with deferred destruction of the old resource.
- [ ] Account for recorded commands, submissions, descriptors, and other retaining references, not just the completion of one GPU call.
- [ ] Preserve native checks; check failures during recording, submission, reset, and partial preparation.
- [ ] Document the next lifetime contract separately. A complete lifetime proof is not a hidden alpha requirement.

The current backend distinguishes execution completion from releasing recorded-command references; this rule must survive the project split [S6].

**Done when:** the proven general property is actually used by the upload path, dynamic replacements pass checks, and trust boundaries are documented.

**Not proven by this stage:** alignment, validity of all GPU accesses, synchronization, the native implementation, shaders, the driver, or the compiler. These retain separate requirements and tests.

## E4 — Assets and a conventional 3D scene

**Goal:** the engine accepts prepared assets and creates an interactive scene.

### Tasks

- [ ] Add a minimal Asset API: handles, loading/error state, a cache, and release rules.
- [ ] Define an internal mesh and material format independent of the importer.
- [ ] Integrate one validated image decoder and one static-model format. Start with synchronous loading; asynchronous loading is not needed to demonstrate the API.
- [ ] Reuse Bend math/decoding modules as needed, without bringing in all of Jonlib up front.
- [ ] Implement a textured material, a simple light source, and a camera.
- [ ] Add scene descriptions, a Transform → GlobalTransform hierarchy, and rejection of parent cycles.
- [ ] Correctly update dependent transforms/bounds when a parent changes; this must feed into future render change tracking.
- [ ] Check corrupted files, missing assets, unsupported variants, and repeated loading.
- [ ] Make a model viewer and a small scene with gameplay interaction the two required consumers.

**Done when:** both applications use the public API, one scene loads from disk, loading errors do not break the application, and assets do not require manual Vulkan calls.

**Out of scope:** all of glTF, skeletal animation, PBR, an editor, hot reload, or a universal asset dependency graph.

## E5 — Persistent RenderScene and v0.1-alpha

**Goal:** stop rebuilding and uploading all object data merely because the next frame has begun.

The Skyrim blog proposes a persistent GPU scene representation with event-driven updates instead of repeatedly traversing the game graph [S7]. Here, that idea is introduced incrementally: persistent state and correct changes first; GPU visibility arrives only in E7.

### E5.1. Persistent state on the Bend side

- [ ] Create an independent RenderScene with tables of instances, transforms/bounds, mesh/material references, and loading state.
- [ ] Define a `Create / Update / Remove` protocol. Handle render-component addition and removal, despawn, mesh/material changes, and parent changes.
- [ ] Use Bendvy's public change/removal mechanisms or an explicit observation adapter. Do not assume a `Changed` query necessarily runs in O(number of changes).
- [ ] Give each render slot a stable identity. A stale update must not alter a new object after slot reuse; generation/ID overflow has an explicit failure policy or a safe ID-space renewal policy.
- [ ] Preserve a full rebuild as a debugging reference and recovery path, not as normal per-frame work.
- [ ] Compare incremental state with a full ECS projection for identical committed states. Comparison uses logical IDs rather than requiring identical element placement in memory.

### E5.2. Persistent GPU resources and revisions

- [ ] Retain mesh/material/object data between frames. Existing buffers/descriptors and CPU-issued draws are acceptable initially.
- [ ] Before storing the complete table in one GPU-readable buffer, check API capabilities; if needed, add storage buffers as a separate minimal extension rather than claiming they already exist.
- [ ] Separate object data from camera/view data: moving the camera does not trigger re-uploading unchanged meshes or object transforms.
- [ ] Upload dirty ranges after the E3 check; record upload volume and count.
- [ ] Start with correct single-threaded application of changes at the frame boundary. A separate render thread and a lock-free mailbox are not required.
- [ ] With multiple frame slots, track the applied revision of each dataset and do not modify memory still in use by the GPU.
- [ ] Clear the change log only after the necessary consumer acknowledgments, or replace it with a complete consistent revision. Skipping a frame must not lose an object removal.
- [ ] If delta packets are introduced later, include `base_revision` and `new_revision`. A base mismatch triggers replay/resync rather than silently applying the latest delta.
- [ ] Distinguish prepared data, successfully queued uploads, and completed use. A backend error must not falsely acknowledge an applied revision.

**Important:** a mailbox of complete revisions and a delta queue are different protocols. “Take only the latest message” is not valid for every sequence of changes. This is not a reason to immediately introduce shared memory/zero-copy.

### E5.3. Measurements and acceptance

- [ ] Check a static scene; camera-only movement; changes to a small subset of objects; movement of every object; frequent spawn/despawn and resource replacement.
- [ ] After the initial population of all active frame slots, a static scene does not repack or re-upload unchanged object data. Camera uniforms and other actual changes are accounted for separately.
- [ ] Measure separately: N inspected ECS elements, K changed objects, bytes uploaded, CPU visibility, and draw preparation. A small K does not prove that all CPU work has become O(K).
- [ ] Preserve a correct CPU-culling/direct-draw path. Traversal for visibility remains acceptable; this stage aims to eliminate unnecessary state reconstruction and uploads, not to claim zero CPU cost.
- [ ] Automate proofs, headless tests, builds, and available GPU/window checks; an absent GPU means “not performed,” not success.
- [ ] Document installation, the API, limitations, dependencies, and licenses for code/demo assets in use.
- [ ] Check both non-voxel applications from a clean environment and release `v0.1-alpha`.

**Done when:** both programs run without core changes; RenderScene matches the reference projection; unchanged data is not re-uploaded; updates and removals are not lost; checks are reproducible.

**Out of scope:** mandatory `bend-voxel` migration, a render graph, compute culling, multi-draw, a multithreaded mailbox, or beating Bevy in FPS.

---

## E6 — Verifiable render graph

**Prerequisite:** a working alpha and several real passes with dependencies. For example: shadow pass → main pass → postprocess. Do not add an effect solely to manufacture a graph.

**Goal:** Bend builds an executable plan from pass and resource descriptions. Separating the graph from the GPU API follows an idea similar to OpenRenderGraph/BasicRHI, but this implementation is a small Bend module [S8].

### First-version limits

One queue for graphics/compute passes; the existing presentation protocol stays separate. No async compute, memory aliasing, automatic pass elimination, or reordering of unspecified external effects. Access may be tracked conservatively at whole-buffer/image granularity; finer ranges are a separate extension.

### Tasks

- [ ] Define descriptions for passes, logical resources, result versions, reads/writes, and explicitly ordered external effects.
- [ ] Give each imported resource a specified initial state; each locally produced readable result has a producer. Do not prohibit valid reads of imported or retained data.
- [ ] Compute dependencies and reject cycles, missing producers, and ambiguous writes.
- [ ] Build a stable topological schedule and connect it to the production executor.
- [ ] Account for RAW/WAR/WAW when mapping versions to physical resources; initially prohibit implicit memory sharing between different logical resources.
- [ ] Separately implement translation from states/accesses to stage masks, access masks, and image layouts in the supported Vulkan profile.
- [ ] Do not treat CPU call order or a topological sort as sufficient GPU synchronization. Validate the translation against Khronos examples and synchronization validation [S9].
- [ ] Use the available legacy barrier API until a newer API is explicitly implemented and enabled. synchronization2 examples cannot simply be copied into the bindings without the required support [S2, S9].

### First proofs

- [ ] For every successfully compiled finite graph, each pass appears in the plan exactly once.
- [ ] For every declared dependency edge, the producer precedes the consumer.
- [ ] Every accepted read has a valid producer version or a correctly declared import.

These are properties of the graph model and the production plan compiler. They do not prove that shaders declare all their accesses, that barrier lowering is entirely correct, or that the driver executes correctly. These boundaries must be documented rather than hidden behind the word “verified.”

**Done when:** a real scene uses the graph instead of manual ordering, the relevant general properties are proven, invalid graphs are rejected, and a manual reference path and GPU validation confirm the cases being checked.

**Out of scope:** copying all of OpenRenderGraph, multiple graphics APIs, optimal scheduling, memory aliasing, or proving the entire Vulkan memory model.

## E7 — GPU-driven rendering as a measured extension

**Prerequisite:** alpha and E6 work; there is an experiment of interest or a measured CPU visibility/draw-preparation cost. This is not a prerequisite for the engine to be useful.

**Goal:** the GPU reads persistent scene tables, computes visibility, and produces indirect-draw parameters. Bend continues to manage state, data, resources, and the frame plan.

### Minimal bend-vulkan extension

- [ ] Check and, where needed, implement storage-buffer descriptors, compute pipelines, dispatch, and the required buffer usages.
- [ ] Add indexed indirect drawing and command-buffer range checks.
- [ ] Check and enable actual device features/limits. For example, `multiDrawIndirect` is required for `drawCount > 1`; indirect-count variants have separate requirements [S10].
- [ ] Initially use a supported queue with graphics/compute capabilities and a simple synchronization scheme. Do not introduce a separate compute queue.
- [ ] Validate compute write → indirect-command read and shader reads with explicit barriers [S9].

### Renderer experiment

- [ ] Start with frustum culling of opaque objects using conservative bounds; leave transparency and its ordering on the existing path.
- [ ] Choose a simple, bounded indirect-command format. A GPU-generated count, bindless access, and device-generated state changes are not required.
- [ ] Compare CPU and GPU visibility on known scenes, with particular attention to frustum boundaries and numerical tolerances.
- [ ] Bound output-list capacity; overflow triggers explicit handling/fallback rather than memory corruption or silently disappearing objects.
- [ ] Preserve the CPU/direct path for comparison, debugging, and devices without the required capabilities.
- [ ] Compare CPU cost, GPU cost, frame intervals, and memory on the same workload, rather than comparing API-call counts.

Khronos publishes a separate GPU-culling and multi-draw-indirect example; it can be used to check understanding of the API, not as a mandatory engine feature set [S11].

**Done when:** results are correct within the stated scope, the fallback works, and costs/benefits are reproducible. If the variant loses on the selected scenes, it remains experimental rather than automatically replacing the working path.

**Do not promise:** elimination of all CPU costs, an unlimited object count, automatic GPU speedups, or equivalence across different floating-point backends.

---

## R0 — Ownership-model validation and a sequential reference

**Goal:** check which operations are actually available on the pinned toolchain before designing storage and parallel kernels around them.

**Starting point:** the headless step from E2. Use a `simulation/` directory within the engine repository; a separate `bend-sim` repository is not yet needed.

### Tasks

- [ ] Pin compiler/dependency commits, the native target, and the corresponding guide/runtime source. Distinguish “described in the current guide” from “compiled and measured on our pinned version.”
- [ ] Check creation, reading, writing, and transfer of an array owned by the function; separately check safe splitting/reassembly. If no views/split API exists, start with independently allocated chunks rather than inventing such an API.
- [ ] Check indexing rules, logical size, and physical capacity. The engine API rejects invalid indices before access; index wrapping is not considered a valid way to access a different entity.
- [ ] Create a minimal example with two independent computations and confirm the available parallel execution path. Do not treat source syntax as proof of execution on multiple cores.
- [ ] Choose an implementable method for reading neighboring data and measuring allocations/copies. Report an unavailable counter as “not measured,” not zero.
- [ ] Record an ADR covering `EntityId + generation`, state representation, the sole owner, inputs/events, seed, dt, arithmetic, NaN/Inf, overflow, and the structural-commit boundary.
- [ ] Create a reference for a small particle set: independent integration, followed by a simple exhaustive interaction search for small N. The reference model and optimized candidate must use one specification, not different physical rules.
- [ ] Preserve the workload generator, result checker, and machine-readable report format. Check an empty world, one object, boundary indices, ID reuse, and rejection of invalid input.

**Done when:** the reference runs without a GPU, key capabilities are confirmed by minimal programs, unsupported operations are listed, and the first implementable layout has been selected. This is evidence for the experiment, not a new guarantee of the entire compiler's correctness.

**Reconsideration criterion:** if a required capability is missing, choose a simpler Bend representation or a separately verified toolchain upgrade. Do not move the kernel to C or replace the ECS without measured justification.

## R1 — Independent updates and representation costs

**Goal:** establish a baseline for the simplest parallel work before adding interactions.

### Tasks

- [ ] Implement sequential and parallel versions of independent position/velocity updates in Bend. For a clean parallelism comparison, use the same layout and numerical operation order within each entity.
- [ ] Transfer ownership of each chunk to its task; prove, or initially check through tests, that the partition covers the required elements without overlap. Having an `EntityId` does not grant permission to address an arbitrary physical slot.
- [ ] Separate storage chunks from work batches. Compare several batch sizes, including uneven amounts of work, without a custom work-stealing runtime.
- [ ] Compare separate passes with a fused kernel: identical operations and results, but different intermediate data. Treat compiler-fusion capabilities as unknown until checked.
- [ ] Measure chunk creation/repacking, allocations, copying, result assembly, and full tick time, not just the hot loop.
- [ ] Use 10,000 / 100,000 / 1,000,000 entities as research parameters, not a capacity promise. Explicitly record cases that exceed memory/time constraints; small N is sufficient for correctness tests.
- [ ] Check canonical state by logical IDs and repeatability under a fixed configuration. Define exact/tolerance comparison for the numerical mode in advance; do not call approximate equality proven equivalence.

**Done when:** there is a reproducible “reference → sequential same-layout → parallel” report, including overhead, memory, and losing cases. A working sequential fallback is retained.

**Adoption gate:** the parallel path becomes the default only for workloads shown by measurements to suit it. A negative result does not end the research, but rules out claiming a speedup without evidence.

**Out of scope:** interactions, physical stability, a million-NPC demo, GPU migration, or a mandatory win over C++/Bevy. A fast `map` does not establish the viability of the whole simulation.

## R2 — One world: interactions, sparse contributions, and structural commit

**Goal:** test the engine's central hypothesis on tasks with dependencies, rather than on many independent worlds.

Proposed pipeline; this is a design sketch, not a promise of a free snapshot:

```text
Committed state(t) + tick inputs
             ↓
Chosen read representation and spatial index
             ↓
Candidate search / local interactions
             ↓
Contributions addressed to EntityId + generation
             ↓
Grouping / explicit reduction semantics
             ↓
Numerical update of owned chunks
             ↓
Ordered structural commands → committed state(t+1)
```

The iterative constraint solver in R4 cannot be reduced to a single additive reduction; when introduced, it will have its own loop and read/write boundaries.

### Spatial search and ownership

- [ ] Start with a simple grid and a bounded interaction radius; explicitly define cell coordinates, negative coordinates, boundaries, and spatial-key arithmetic. For small N, compare the actual interactions found with exhaustive search.
- [ ] The broadphase may return extra pairs, but must not miss pairs valid under the chosen model; the narrowphase filters candidates. Check the uniqueness of canonical pair IDs rather than incidental agreement in traversal order.
- [ ] For a symmetric pairwise force, compute each pair once and address contributions to both participants. Directed interactions have a separate rule; one scheme cannot be applied universally to every effect.
- [ ] Check uniform distributions, a dense cluster, empty cells, movement across boundaries, distributions with several hot regions, and frequent spawn/despawn.
- [ ] Keep only the necessary fields in the read representation. Count bytes copied, halo/snapshot costs, neighbor assembly, and access to shared values. Copying the entire World is not an assumption of the algorithm.
- [ ] Partition work by the measured amount of interaction work, not just entity/cell count. A dense cell must not automatically become one giant task.

### Contributions and conflicts

- [ ] Start with local lists of `(destination, source, kind, ordinal, payload)` and explicit grouping by recipient. A hash-based or other sparse structure is a candidate after the baseline, not a mandatory Birdseed port [S16].
- [ ] Define a stable ordering key independent of worker ID and completion time. Include the tick and generation; sources with multiple events have a defined ordinal.
- [ ] For floating-point sums, choose a canonical order or a fixed tree independent of task partitioning. A different tree or fast-math is a separate numerical configuration, not “the same deterministic simulation.”
- [ ] Separate additive contributions from `Set / Spawn / Despawn / Reparent`. Define conflict-resolution rules and negative tests for each noncommutative command.
- [ ] Initial semantics: interactions read the committed state at tick start; despawn at commit cancels writes to the generation being removed; spawn receives an ID in a defined order and participates in interactions from the next tick. Two `Set` writes are resolved by an explicit stable priority, not “whoever finished last.”
- [ ] Handle list/queue/key overflow explicitly. Never silently drop pairs, contributions, or despawns to fit a limit. Check the maximum size before an unsafe write; choose a verifiable fallback or a diagnosable failure.
- [ ] Define failed-tick behavior before application integration. Do not publish partially applied state as a successful commit; rollback is not assumed without a separate mechanism.

**Done when:** the reference and candidate agree within the stated scope; events and pairs are neither lost nor duplicated; tests with different batches pass; an end-to-end report shows the costs of broadphase, reads/copies, compute, grouping/reduction, and commit.

**Adoption gate:** evaluate optimization across the entire tick, including merging and dense scenes. If it loses, retain the reference or a simpler variant. Identical physical accuracy and inputs are mandatory for a fair comparison.

**Out of scope:** network exactly-once semantics, distributed snapshots, MMO support, a complete rigid-body engine, cross-platform bitwise determinism, or assuming that every reduction is associative.

## R3 — Simulation in App/Bendvy, not a standalone toy

**Goal:** make the results of R1–R2 part of the engine through the same public API and E2/E5 pipeline.

### Tasks

- [ ] Integrate Simulation as a static App module and one or more explicitly ordered Bendvy systems. Do not duplicate its scheduling/command API with a general-purpose framework.
- [ ] Choose and document one owner of each mutable field. Prefer validated public access to ECS data; if a separate owned resource is needed, the other components/views are managed projections, not second sources of truth.
- [ ] Check the actual adapter cost: extraction, packing, copying, writing results, and change detection. Report kernel time and total integrated simulation time separately.
- [ ] Send only committed state and the necessary changes to RenderScene. `EntityId` and `RenderId` remain distinct identities; spawn/despawn/reuse use the existing E5 protocol.
- [ ] Compare the incremental render projection with a full rebuild of the same committed state. Headless and windowed runs receive identical inputs, seed, and numerical settings.
- [ ] Add an interactive scene: the user creates/removes objects and changes one interaction parameter through commands, with no Vulkan handles in gameplay code.
- [ ] Check the catch-up step limit, absence of lost inputs, and correct pause behavior. Rendering must not change simulation order; an interpolation snapshot has a separate, accounted-for cost.
- [ ] Record an ADR on the adopted layout and fallback modes. Extract `bend-sim` into a package only when a second independent consumer appears.

**Done when:** the same simulation runs headlessly and through App, does not have two writable copies of state, agrees with the renderer, and has been measured together with the ECS adapter. R3 is a functional-core checkpoint after alpha, not a new requirement for the already defined `v0.1-alpha`.

**Reconsideration criterion:** if copying through the public API consumes the benefit, first prepare a minimal reproducer and change the adapter/discuss it with Bendvy. Replacing the ECS requires separate evidence and a decision.

## R4 — Parallel physics candidate: VBD → AVBD

**Goal:** investigate a solver with an explicit dependency structure, without immediately promising general-purpose physics.

VBD uses local updates and graph coloring. Dynamic contacts require additional handling; the paper describes a variant with an auxiliary buffer rather than simply updating every vertex in place [S17]. AVBD extends the approach with an augmented-Lagrangian formulation for hard constraints and high stiffness ratios [S18]. These sources define the subject of the experiment, not its result.

### Tasks

- [ ] Start with a small particle/spring system with fixed topology, a specified energy function, and a numerical model. Preserve a sequential reference of the same algorithm.
- [ ] Build groups for which the chosen read/write protocol is correct. Check the conflict graph; different output slots alone do not rule out a read/write dependency.
- [ ] Execute groups in an explicit order, with independent work within each group running in parallel; measure group count, imbalance, and preparation cost.
- [ ] For dynamic contacts, choose dynamic dependency rebuilding or a documented buffered/Jacobi-like mode. Account for contact updates within the solver; static coloring does not automatically cover new connections.
- [ ] Compare error/residual and time to a specified quality, not just the same iteration count. Separately record penetration, drift, NaN/Inf, dt, mass, stiffness, and iteration budget.
- [ ] Only then add one contact scenario; subsequently investigate AVBD hard constraints if practically needed. Limited primitives are preferable to immediately implementing mesh collision and a complete rigid-body API.
- [ ] Check repeatability, extreme mass/stiffness ratios, failures, and degradation; retain a simpler working path for the scene.

**Done when:** a small demonstration workload uses the solver, supported and failing cases are documented, correctness and quality are compared with the reference, and the full preparation and solving cost has been measured.

**Adoption gate:** improvement in the quality/time/memory tradeoff needed by the selected game. No improvement is a valid experimental result. Someone else's stability claim does not automatically apply to our discretization, contact model, or implementation.

**Out of scope:** complete physics middleware, differentiable simulation, agent training, a mandatory GPU solver, or a proof of all physics.

---

## 3. Formal verification as a cross-cutting process

| When | Verification target | What does not follow from the result |
| --- | --- | --- |
| E3 | An accepted upload range lies within the buffer | Valid shader accesses and synchronization |
| E5 | Incremental state matches a full rebuild — tests first, then a separate general theorem | That the log receives every actual change without a correct adapter |
| E6 | The plan contains the passes and preserves declared dependencies | That GPU memory dependencies and undeclared effects are handled automatically |
| R1 | Partitioning owned data covers the domain without overlap; accesses pass range checks | A bug-free compiler/runtime or free array splitting |
| R2 | Grouping preserves the specified multiset of events; the chosen optimization is equivalent to the reference | Correctness of the reference itself or arbitrary reordering of floating-point sums |
| R4 | The group plan respects declared conflicts under the chosen read/write protocol | Physical accuracy, convergence, or complete coverage of undeclared contacts |
| Later | Stale engine handles are rejected after reuse; retirement prevents premature release | Correctness of the driver, FFI, or external completion notifications |

For each proof, record the input domain, arithmetic, assumptions, executable function, and call path. Reuse existing proofs. Distinguish `specified`, `tested`, `proved`, and `integrated`: one status does not replace the others.

Do not tie project success to the number of laws. Do not weaken contracts to pass the verifier. Changing the specification when requirements genuinely change is acceptable, but must be a separate, deliberate decision.

### Reference → optimized → evidence

Verified optimization [S20] is used as a development method, not as a promise of automatic translation of Lean proofs into Bend. An optimization is given an unchanged reference, a valid-input domain, an equality criterion, tests, and a measurable workload. After locating the bottleneck, verify the optimized code that is actually called, not an adjacent mathematical model.

The first candidate after E3 is a small discrete algorithm: event grouping, checked lookup, or pair canonicalization. For the broadphase, an integer coordinate model can be specified first; a floating-point extension requires a separate specification. Do not require a proof of the entire solver to obtain the first useful result.

Proven equivalence can preserve a bug in the reference. Semantic invariants, boundary/negative tests, and requirements validation are therefore needed separately. Speedup is checked by benchmarks, not a proof checker; existing E3 proofs are not duplicated to increase the count.

## 4. Common measurement protocol

From E1 onward, preserve machine-readable results and run commands. For each set, record the commit, compiler/dependency revisions, CPU/GPU/driver, resolution, scene, camera path, object count, workers, frame slots, present mode, validation/instrumentation, warm-up, and repeat count.

Measure simulation, change collection, RenderScene updates, packing/upload preparation, visibility, command recording/submission, waits, and GPU timestamps separately. Overlapping CPU/GPU intervals cannot simply be added into a “full frame.”

For frame time, name the exact boundary being measured. Do not present a submit/handoff interval as the time when the image is physically displayed. Publish median/p95, upload volume, draw count, and live-resource count; retaining raw samples is also useful.

Sets of 100 / 1,000 / 10,000 objects are research points, not mandatory performance promises. Static and fully dynamic scenes are different workloads. Comparing methods requires identical data, quality, and conditions, or an explicit acknowledgment that they are not comparable.

Do not use old DDA/face/handoff figures to derive strict speedup ratios for the new engine.

### Addendum for R0–R4

Reports must include seed, dt, tick count, density/distribution, candidate and actual interaction counts, chunk/batch sizes, actually available workers, FP mode, and chosen reduction semantics. Measure memory using an available method; account for instrumentation overhead separately.

| What to measure | Misinterpretation it prevents |
| --- | --- |
| Reference, sequential same-layout, and parallel end-to-end tick | A layout or physics change is not presented as a parallelism benefit |
| Broadphase, read-data preparation, compute, grouping/reduction, commit | A fast kernel does not conceal expensive result assembly |
| Allocated/copied bytes, peak memory; clone/halo and intermediate buffers | Functional programming is not presented as an absence of copying |
| Median/p95 tick, min/max or distribution of work across batches | Rare dense regions and stragglers do not disappear into an average |
| ECS extraction/application and render change propagation | An isolated headless result does not stand in for integration cost |
| For R4: residual/error and time to a specified quality | Different numerical results are not compared solely by FPS |

First repeat one configuration; then vary worker and batch counts. Scaling claims require confirmed distinct execution configurations. Agreement on one machine is not a cross-platform guarantee. No speedup is an honest result; a missing measurement is “not measured.”

A PR with a new optimization includes reproducible commands, revisions, raw samples or a report, the correctness-check result, and a decision of `accepted / experimental / rejected`. Do not treat names of future scripts as existing tooling.

## 5. After the main stages

### A small, finished game

The next concrete goal is a small game, not dozens of abstract APIs. R3 should provide reusable simulation for it; E6/E7 and R4 are not required if its mechanics do not need them.

Add collisions/raycasting, character control, audio, UI, saves, animation, and format extensions as the game needs them. A minimal collision/query API is acceptable before a full solver; audio and UI should not wait for research physics. E4 scene loading is not declared to be complete game save/load: saves need separate rules for versions, IDs, and restoration.

Develop custom algorithms in Bend under the chosen principle; use existing Bend packages after validation. System audio/window APIs are acceptable at the designated boundary; large native middleware is not silently introduced as a change of goal. The form of the first finished game example is determined by working mechanics, not by a desire to implement every subsystem at once.

### A large world and a Skyrim consumer

Order: region streaming → loading priorities and per-frame memory/work budgets → LOD → a separate format importer → one imported location → custom gameplay mechanics.

Regions are units of storage/streaming, not necessarily network shards. The engine does not depend on Bethesda formats. The importer converts data into ordinary engine assets/scenes. Do not make Papyrus, SKSE, original saves, or full Skyrim compatibility core requirements. Test materials are, by default, original or licensed for redistribution.

### Status of the former two-phase branch

The revision 2–3 item about `snapshot → intents → resolve/apply` is replaced by the R0–R4 track above. This direction is now part of the architecture and the post-alpha priority; specific parallel kernels are adopted based on evidence. A snapshot is not required for every stage, ECS is not discarded, and there is no commitment to build an MMO.

Skyrim remains a distant consumer, not the measure of R2's success. First, one small interacting world and a working game example.

---

## 6. Scope limits

Only one main stage is active at a time, including research stages R0–R4. Research is allowed, but does not move the completion criteria of neighboring stages. Each checkpoint preserves a working demo or reproducible headless reference; changes of focus are recorded explicitly.

Before alpha, do not add MMO support, a distributed ECS, a universal RHI, an editor, Nanite-like geometry, texture streaming, a lock-free mailbox, zero-copy Bend/CUDA/Vulkan integration, or a complete Skyrim port.

A new API appears for a concrete consumer. Replacing the language, ECS, backend, or format requires a reproducible reason, not another interesting link. The absence of a deadline allows research, but does not make every idea mandatory at once.

Do not add a universal borrow checker, tensor compiler, custom work-stealing runtime, or new shader toolchain merely to reproduce a paper. Do not move the computational core into C/Rust to make a benchmark pass. Changing the original Bend-first goal is a separate decision, not a hidden optimization.

## 7. First three issues

### 1. Finish standalone bend-vulkan acceptance

Complete, E0. The voxel-code migration and removal of the reverse dependency are already published. **The non-voxel window example and clean-checkout gate are complete**: on `a144f7dd4fb4835ca3d5ce17350fc850de049038`, the library verifier and the window verifier in rootful XWayland exited with code `0`; results and limitations are recorded [S24]. The README now documents acceptance, and E0 is complete. Do not redo the completed split or example.

### 2. Render a Bendvy scene through the public bend-vulkan API

Complete, E1. Entangle's dependency revisions, native toolchain, and project components are verified [S25]. The 100-entity scene and registered movement system are complete [S26]. Drawing-data extraction and public-API offscreen rendering have exact native verification [S27, S28]. The input, controllable camera, resize, and exit paths are verified [S29, S31]. Baseline timings and counters are recorded and independently reviewed [S30]. No render graph was added.

### 3. Run a second non-voxel application through App and RenderPlugin

In progress, E2. App resource scope, time, input, and error handling are extracted and verified [S31]. Static startup registration is implemented. Next, define the public API and headless runtime verification, and build a second scene. Specify the step contract, sequential movement reference, and state owner. The interface anticipates persistent render-scene storage, but its full implementation belongs to E5; parallel kernels are not yet required.

### First research issue after E2

**Audit pinned Bend ownership and build a headless simulation reference (R0).** Check actual array/ownership operations and parallel calls, record an ADR, reuse the step from E2, and define a correctness/benchmark harness. Do not include VBD, a renderer rewrite, or a million objects in this issue's acceptance criteria.

**Next action:** continue issue 3 / E2 with the public application API and sequential step contract, using the App extraction [S31] and static startup registration. Issues 1 / E0 and 2 / E1 are complete. After alpha, the research priority is R0–R3; E6/E7 do not block that path.

---

## Sources and bases for decisions

S1–S13 and the historical E0 evidence are carried forward from revision 3: its statuses are based on the logs/commits listed there. New sources S14–S22 were checked for revision 4, dated November 2, 2026. In revision 5, the independent window example's status was confirmed through the published README/repository page [S23]; there was no independent local run or clean-checkout gate at that time. Revision 6 adds the results of the actual clean-checkout gate and window verifier [S24]. The E1 updates add Entangle's native dependency baseline [S25], the shared-mesh scene with native verification [S26], committed drawing-data extraction [S27], and public-API offscreen rendering [S28]. External sources S1–S23 were not rechecked for this roadmap update.

The R0–R4 architectural decisions are our design synthesis. External papers establish the methods described in the table within their own environments, not the compatibility, correctness, or speed of a Bend implementation. Sources on mutable branches require a commit/hash at implementation time; an access date does not replace a pin. Third-party speedup figures have not been imported into our engine's criteria.

- [S1] bend-vulkan README: `https://raw.githubusercontent.com/aivv73/bend-vulkan/main/README.md`
- [S2] bend-vulkan roadmap, implemented and planned capabilities: `https://raw.githubusercontent.com/aivv73/bend-vulkan/main/docs/roadmap.md`
- [S3] Submodules after the split: `https://raw.githubusercontent.com/aivv73/bend-vulkan/753f8f49549b6eb17c6e609346fed5a580bdc8a1/.gitmodules`
- [S4] Bendvy README, API, and capabilities: `https://raw.githubusercontent.com/dearlordylord/bendvy/master/README.md`
- [S5] Bendvy specification, declared contracts: `https://raw.githubusercontent.com/dearlordylord/bendvy/master/docs/SPEC.md`
- [S6] bend-vulkan dispatch/ownership design: `https://raw.githubusercontent.com/aivv73/bend-vulkan/main/docs/design.md`
- [S7] Fixing Skyrim’s render pipeline, October 9, 2026: `https://panthuncia.github.io/blog/fixing-skyrims-render-pipeline/`
- [S8] What I’m working on, October 13, 2026, OpenRenderGraph and BasicRHI sections: `https://panthuncia.github.io/blog/`
- [S9] Khronos Synchronization Examples, including the legacy API link: `https://docs.vulkan.org/guide/latest/synchronization_examples.html`
- [S10] Khronos vkCmdDrawIndexedIndirect, valid usage and feature requirements: `https://docs.vulkan.org/refpages/latest/refpages/source/vkCmdDrawIndexedIndirect.html`
- [S11] Khronos GPU Rendering and Multi-Draw Indirect: `https://docs.vulkan.org/samples/latest/samples/performance/multi_draw_indirect/README.html`

- [S12] Renderer migration to bend-voxel: `https://github.com/aivv73/bend-voxel/commit/6c28547`
- [S13] Pin to the merged standalone library: `https://github.com/aivv73/bend-voxel/commit/2e608c6`

### New verified sources for revision 4

- [S14] Bend Guide, Parallelism / Arrays sections: `https://github.com/bendlang/bend/blob/main/guide/GUIDE.md` — current documentation, not confirmation of capabilities on the pinned toolchain. Accessed November 2, 2026.
- [S15] Yusuke Matsushita, Hiromi Ishii. *Pure Borrow: Linear Haskell Meets Rust-Style Borrowing*. PLDI 2026; arXiv:2604.15290v4, June 5, 2026 (first version April 16): `https://arxiv.org/abs/2604.15290v4`. HTML, including §5.5 with conjectures: `https://arxiv.org/html/2604.15290v4`.
- [S16] Adrian Gushin, Pau Sum, Willow Ahrens. *Parallel Sparse Outputs for Tensor Compilers*. arXiv:2610.19308v2, October 22, 2026 (first version October 13): `https://arxiv.org/abs/2610.19308v2`. The abstract and metadata were checked for this revision; Birdseed's implementation details are not treated as a validated Bend-module design.
- [S17] Anka He Chen, Ziheng Liu, Yin Yang, Cem Yuksel. *Vertex Block Descent*. arXiv:2403.06321v4, June 1, 2024: `https://arxiv.org/abs/2403.06321v4`. HTML §3.9 — coloring and dynamic contacts: `https://arxiv.org/html/2403.06321v4`.
- [S18] Chris Giles, Elie Diaz, Cem Yuksel. *Augmented Vertex Block Descent*. ACM TOG / SIGGRAPH 2025. Authors' page with the publication and source code: `https://graphics.cs.utah.edu/research/projects/avbd/`. An additional source, not claimed to be an identified arXiv publication.
- [S19] David van Balen et al. *Comparing Parallel Functional Array Languages: Programming and Performance*. arXiv:2505.08906v1, May 13, 2025: `https://arxiv.org/abs/2505.08906v1`. The scope/abstract are used here; no claim is made about numerical results or the presence of corresponding optimizations in Bend.
- [S20] Zhe Ye, Udaya Ghai, Zhizhen Qin, Dawn Song, Soonho Kong. *Agentic Verified Optimization of Real-World Software*. arXiv:2610.30188v1, October 20, 2026: `https://arxiv.org/abs/2610.30188v1`. Equivalence is studied in Lean; migrations of source applications are checked through differential testing. These are different levels of assurance.
- [S21] C. Daniel Freeman et al. *Brax — A Differentiable Physics Engine for Large Scale Rigid Body Simulation*. arXiv:2106.13281v1, June 24, 2021: `https://arxiv.org/abs/2106.13281v1`. An architectural reference, not a library dependency.
- [S22] Madrona, official README: `https://github.com/shacklettbp/madrona` — ECS and many-world simulation. An additional primary source outside arXiv; its runtime and native stack are not proposed as our engine implementation.

### Confirmation of the E0 update in revision 5

- [S23] Public `bend-vulkan` page with the README and independent window example description: `https://entire.com/et/bend-engine/bend-vulkan`; the README lists `examples/indexed_window.bend` and the verifier script `examples/verify_window.py`. Accessed November 2, 2026. Publication does not replace verification of a specific Git checkout on the target system.

### Confirmation of E0's clean-checkout gate in revision 6

- [S24] E0 evidence dated November 2, 2026, retained in [bend-vulkan](https://entire.com/et/bend-engine/bend-vulkan) commit `e2fae37c7c82b5568d591bd27918aeff30f25bee`, under `docs/verification/2026-11-02/`: `README.md`, `result.json`, `checkout.log`, `library.log`, `window.log`, `window-desktop.log`, and `captures.sha256`. The verified library revision was `a144f7dd4fb4835ca3d5ce17350fc850de049038`, with Bend 2.0.39 and `bend-collections` `bc78c4f4cabb536a2a1dd6e308b6a8f0afafda7c`. These are historical E0 results, not a new Entangle window run.

### Entangle native dependency baseline

- [S25] Entangle evidence dated November 2, 2026: [report](docs/verification/2026-11-02/README.md), [result.json](docs/verification/2026-11-02/result.json), [native verification log](docs/verification/2026-11-02/native.log), and [environment and compiler fingerprints](docs/verification/2026-11-02/environment.log). Exact pins are in [toolchain.bend](toolchain.bend). `bend tools/verify.bend` exited with code `0`. The [work item](https://entire.com/et/bend-engine/-/trails/1) records the scope. The baseline implementation and evidence are committed at `a0f4a691aa9af4f33177c039c5f1d28a8f8323df`.

### Entangle shared-mesh ECS scene

- [S26] Entangle commit `ff717736acd156f3c0f1306aed4b988a2b0a9a54`, pushed to `main` on November 2, 2026. The [reviewable change](https://entire.com/et/bend-engine/-/trails/3/changes/entangle/1) records implementation and verification. Sources are [scene execution](src/scene.bend), [movement](src/scene-motion.bend), [native property driver](examples/scene.bend), [formal claims](LAWS.bend), [proofs](PROOF.bend), and [full verifier](tools/verify.bend). Independent runs of `bend PROOF.bend`, the native scene, and the full `bend tools/verify.bend` rebuild exited with code `0`. The scene checked 100 entities across eight ticks. This evidence establishes headless ECS behavior, not rendering or performance.

### Entangle drawing-data extraction

- [S27] Entangle commit `feeaa7f`, implemented and verified on November 2, 2026. Sources are the [drawing payload](src/scene-draw.bend), [extractor and shared traversal](src/scene-observe.bend), [native property driver](examples/scene.bend), [formal claims](LAWS.bend), [proofs](PROOF.bend), and [full verifier](tools/verify.bend). `bend PROOF.bend` and `bend tools/verify.bend` passed. A separate full-verifier rerun exited with code `0`; its complete stdout matched the pre-change baseline. Validation covered 100 entities over eight ticks, ordered draw payloads, repeated extraction, retained lists, and inspector and clock preservation. Live extraction failure for a missing required mesh component remains unexercised. This extraction commit does not establish rendering or performance.

### Entangle public-API offscreen renderer

- [S28] Entangle commit `570e20f`, pushed on `feat/public-vulkan-renderer` on November 3, 2026 local time. The [reviewable change](https://entire.com/et/bend-engine/-/trails/4/changes/entangle/2) records the work. Sources are the [renderer](src/scene-render.bend), [matrix operations](src/scene-matrix.bend), [index validation](src/scene-mesh.bend), [native rendering verifier](examples/scene-render.bend), [coverage derivation](docs/render-verification.md), [formal claims](LAWS.bend), [proofs](PROOF.bend), and [full verifier](tools/verify.bend). The full verifier and final native validation exited with code `0`. Local, untracked evidence is retained in `build/render-parent-verify.log`, `build/render-reviewed-validation.log`, `build/render-reviewed-proof.log`, and `build/render-sources.sha256`. The executable regenerates `build/scene-render.ppm`. Evidence covers the GTX 1660, both index orders, eight ticks, exact RGBA8 and D32 readback, recovery after rejected input, and zero live objects. Other drivers, device loss, window presentation, and performance were not verified.

### Entangle existing window integration

- [S29] Implementation on `feat/renderer-window`, based on `8012567`, independently reviewed and verified November 3, 2026. The [reviewable change](https://entire.com/et/bend-engine/-/trails/5/changes/entangle/3) records the work. Sources are the [window adapter](src/scene-window.bend), [ECS executable](examples/scene-window.bend), [native window driver](tools/verify-window.bend), and [verification record](docs/window-verification.md). `bend PROOF.bend`, `bend tools/verify.bend`, and the actual-executable window driver each exited `0`. Local evidence is in `build/window-evidence/proof.log`, `full-verify.log`, `verification.log`, scenario logs, PPM captures, and `captures.sha256`. An owned rootful Xwayland used `DISPLAY=:2`; it was stopped and reaped. All six camera keys changed geometry, R returned exact pixels on retained ECS data, repeated landscape and portrait extents matched on revisits, and shutdown scopes had zero live Vulkan objects. No validation errors or synchronization hazards occurred. Deprecated validation-setting warnings are retained. This is window correctness evidence, not timing, performance, sanitizers, or device-loss evidence.

### Entangle native baseline measurements

- [S30] Implementation measured before commit on `feat/baseline-measurements`, based on `f4aea1f`, November 3, 2026. The [measurement report](docs/baseline-measurements.md) records five fresh live and five fresh retained-replay processes through the shared native renderer. The [evidence](docs/verification/2026-11-03-baseline) includes exact CPU spans, raw GPU timestamps and F32 bits, successful host-write and command counters, per-repeat summaries, machine and source provenance, independent native-window validation, and zero-object cleanup. Live ticks retain the 250 ms schedule. Instrumentation overhead and physical traffic remain unmeasured. No optimization, speedup, GPU-compute scaling, or future phase is established. Independent measurement review accepted the recorded evidence. The attempt-cap correction is documented in the report.

### Entangle App extraction

- [S31] Entangle commit `912639e`, merged into `main` on November 3, 2026. The [merged change](https://entire.com/et/bend-engine/-/trails/7/changes/entangle/6) contains the extraction. Sources are the [App scope](src/app.bend), [time policy](src/time.bend), [input controller](src/input.bend), [Action errors](src/error.bend), and [concrete scene App](examples/scene-window-app.bend). The [verification record](docs/verification/2026-11-03-app/README.md), [native log](docs/verification/2026-11-03-app/native.log), and [byte-equivalence results](docs/verification/2026-11-03-app/equivalence.log) record passing proofs, native/offscreen and window checks, exact replay evidence, and zero-object cleanup. The [Bend comparator](tools/compare-window-evidence.bend) reruns the capture/log comparison. Both executable loops retain their ordering and the baseline retains its timing boundaries. This is structural extraction evidence, not a second application, fixed-timestep implementation, headless game API, or speedup claim.

Source file for revision 6: `ROADMAP_updated_v5.md`. Revision 4 clarified the direction and added a verifiable simulation track; revision 5 recorded the independent E0 window example; revision 6 closed E0 after its clean-checkout gate. E1 is complete with verified native rendering and window behavior plus reviewed baseline measurements [S25–S30]. E2 includes the verified App extraction [S31] and static startup registration. The remaining E2 tasks, E3–E7, and R0–R4 remain incomplete.
