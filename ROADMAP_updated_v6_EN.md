# Game Engine in Bend — Roadmap

**Revision:** 6 · November 4, 2026 · updated for the bounded E4 OBJ importer and verification workflow

**Engine repository:** [Entangle on Entire](https://entire.com/et/bend-engine/entangle). **Vulkan library:** [bend-vulkan on Entire](https://entire.com/et/bend-engine/bend-vulkan).

**Status:** E0, E1, and E2 are complete on `main` through `2faa879` [S24–S37]. Entangle has two interactive non-voxel applications: the moving 100-entity scene and the mesh playground with a controllable object. App extraction, static startup registration, public scene creation, bounded fixed steps, the sequential step contract, and CPU-only headless execution are implemented and verified within the limits below. E3 is complete on `main` under the documented trust limits [S52]. The selected upload-range checker [S38] has a [kernel-checked universal containment proof](docs/upload-range.md). Both production renderers enforce that exact checker through a shared buffer API, with repository verification rejecting ordinary API bypasses [S39]. Scoped native ABI and exact transport-limit verification pass [S40]. Both renderers support [mesh replacement with deferred destruction](docs/mesh-replacement.md) [S48]. Retention verification covers recorded and unsubmitted commands, multiple submissions, uniform and sampled-image descriptor slots and sets, and memory aliases [S49, S52]. Native failure handling is verified through real-runtime checks and bounded proofs of production handlers [S50, S51]. E4 has landed the [Asset API](docs/assets.md), [internal source format](docs/content.md), and [PNG decoder](docs/image-decoder.md) on `main` through `90c7b7e`. The bounded [OBJ importer](docs/model-obj.md) is verified and merged on `main` through `a016c6b`. The remaining E4 tasks, E5–E7, and R0–R4 are planned. `v0.1-alpha` remains an E5 milestone.

**Goal:** an independent, modular game engine, with Bevy-like modularity but a simulation core designed around Bend's computational model. Engine logic and new algorithms are implemented in Bend; native code stays at the system boundary.

**Next release:** `v0.1-alpha` — two non-voxel applications, a public API, a persistent scene representation, and the first practically useful proven guarantee.

**Initial platform:** Linux x86-64, using the existing X11/Vulkan path.

**Schedule:** no calendar deadlines; each stage ends with a verifiable result.

**Dependency research:** the Jonlib and BendHub review supplies candidates for E4 and R0–R2 [S41–S47]. Subsequent runtime qualification selected Jonlib's narrow PNG and OBJ modules behind engine APIs. The [OBJ evidence](docs/verification/2026-11-04-model-obj/README.md) records its supported profile and validation limits. E4 remains incomplete.

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
- Static registration for `Core`, `Input`, `Assets`, and `Render` is implemented and verified in `66413bf`, now on `main`. [Change 8](https://entire.com/et/bend-engine/-/trails/7/changes/entangle/8) is merged [S32].
- The Bend proof gate, pinned native/offscreen verifier, and real-window checks passed. All 13 deterministic captures and the replay and terminal logs matched the pre-change evidence byte for byte. Cleanup left zero live Vulkan objects [S32].
- Frame ordering and Bendvy publication visibility are documented. The production movement kernel has an explicit sequential step contract, and ECS remains the sole owner of mutable component state. The headless reference checks tick entry, publication, numerical updates, and retained observations [S33].
- Fixed-step scheduling now limits catch-up to four steps per poll, drops excess whole steps, and retains fractional time. The original scene uses 250 ms steps; the mesh playground uses 16 ms steps and clears held movement on focus loss or unmap [S34, S37].
- The generic headless runner advances retained game state. Fresh isolated CPU builds and execution passed without Vulkan sources, headers, loader, display, or GPU access [S35].
- Public startup descriptions create meshes, opaque unlit RGB materials, instances, and configurable cameras. Checked compilation produces ECS seeds and shared geometry for used mesh/material pairs. Formal checks, native execution, offscreen rendering, and real-window verification passed [S36].
- The second application, [mesh playground](examples/mesh-playground.bend), is implemented in `45fc1de`. It renders four distinct meshes and lets the user move and reset the orange octahedron while other objects remain fixed. It reuses the existing core and renderer. Real ECS replay, retained rendering, traced and ordinary window runs, and the original applications' window checks passed [S37].
- E2 is complete. Registration and creation remain startup-only. Full runtime phases, removal producers/readers, chunk ownership transfer, dynamic assets, and persistent RenderScene storage remain later work. Compiler-erased callbacks, cross-backend numerical identity, and performance improvements are not established.

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

**Next action:** continue E4 with native texture upload, sampling, and textured materials through Assets. The Asset API, internal source format, and PNG decoder are on `main` through `90c7b7e`. The bounded [OBJ importer](docs/model-obj.md) is on `main` through `a016c6b`, with source, cache/retry, Creation/ECS, offscreen, and X11 evidence. E4 and E5 still precede `v0.1-alpha`. Use the [development workflow](docs/development.md) to define required evidence before implementation.

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

Reuse `bend-collections` for the required arithmetic and containers. Bring in math and decoders from Jonlib or other packages one verified module at a time. Ankra/SDL and a change of windowing layer are not mandatory alpha tasks. Compatibility with all of BendHub is not a milestone.

BendHub packages are immutable by content hash; named versions also identify fixed content [S42]. Record the resolved hash and imported entry with each dependency decision. Hub publication and Bend Crater's compiler checks do not establish runtime correctness, GPU execution, or performance. Audit transitive imports and licenses before adoption. Jonmath, for example, imports separately licensed LGPL numerical modules [S41].

### Package candidates, November 3, 2026

These are reviewed candidates, not new dependency pins. Source revisions, local checks, and their limits are recorded in S41–S47.

| Candidate | Intended use | Selection boundary |
| --- | --- | --- |
| Jonlib at `5e49707e346453f7d36c27d5ca0cb286e431973d` [S41] | E4: PNG or QOI decoding, OBJ parsing, selected math and collision queries | Import or adapt narrow modules behind engine APIs. Keep Bendvy and bend-vulkan authoritative for the world and rendering. Full `jonlib.bend` needs compiler-overlay effects absent from the current toolchain. |
| `emerging-ezimg@1.3.0.0` [S43] | E4: alternative PNG decoder and image export | Compare with Jonlib on the actual asset corpus. Supports 8-bit non-interlaced PNG and baseline JPEG. Its row-major `0xAARRGGBB` lists need conversion to the engine's texture representation. |
| `bend-kit-json@0.7.0.0` or `ezjson@1.4.0.0` [S44] | E4: scene files and asset manifests | Choose one. The kit provides owned bytes and strict parsing with depth and duplicate-key checks; ezjson provides String-based APIs and a pull cursor. Engine schema validation remains separate. |
| `bend-kit-bytes@0.3.3.0` [S44] | Binary parsing when a selected library needs it | Packed storage and bounded cursors are useful at the asset boundary. They do not replace the E3 upload checker or its exact size conversions. |
| `bend-mathlib@0.8.1.0` [S45] | Missing arithmetic, list, ordering, and permutation lemmas | Import only needed proof modules after checking existing `bend-collections` lemmas. This is a proof library, not a replacement for graphics math. |
| `bend-parallel@0.1.0.0` [S46] | R0 audit; R2 scans, spatial buckets, and contribution grouping; possible E7 compaction | Its scan, histogram, and stable counting sort depend on unsafe `Array.fork` and `Array.join`. Adoption requires an explicit trust boundary, real execution, and representative end-to-end measurements. |

Entangle already imports `bend-ui-test@0.1.0.1` and `bend-window-capture@0.1.0.2` in its window drivers. Hub publications of Bendvy, bend-vulkan, and bend-collections do not justify replacing the validated revisions in `toolchain.bend`.

Later candidates [S47] include Gralha fonts and SVG for UI, and `bolt` for developer tooling. Gralha's premultiplied quadtree images need a separate rendering adapter and include unsafe code. `bend-kit-cache` may inform asset metadata invalidation, but its `Data` values cannot directly own affine GPU resources. `bend-kit-resources` accounts for capacity; it does not establish Vulkan retirement safety. Archive and storage packages introduce libz and OpenSSL paths. Prefer Bend implementations where available, and keep necessary native effects at the system boundary.

For each selected module, preserve its input limits and translate its values into engine-owned types. Validate the actual loading, simulation, or rendering consumer before adoption. Keep formal claims in `LAWS.bend`, and record which executable functions and external assumptions those claims cover. Optional parallelism must preserve observable state and pass the common measurement protocol.

---

## 2. Stage order

| Stage | Verifiable result | Scope |
| --- | --- | --- |
| E0 | Library separated from `bend-voxel`; clean-checkout verifier and independent window example passed; README updated | Complete |
| E1 | Bendvy manages 100 rendered objects with verified window behavior and recorded baseline measurements | Complete |
| E2 | Two applications use the public API; a step contract and sequential reference are defined | Complete; mesh playground, headless execution, and runtime evidence recorded |
| E3 | The production upload checker has a proven contract | Complete on `main` under documented trust limits; upload integration, mesh replacement, buffer and sampled-image retention, and failure handling verified [S52] |
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

Baseline, environment, and results: [library split report](deps/bend-vulkan/.audit/library-split.md). Migration and verification commands: [consumer migration report](https://github.com/aivv73/bend-voxel/blob/main/vulkan/docs/migration.md).

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

## E2 — App, plugins, and the game loop (complete)

**Goal:** create the second application through the engine interface rather than by copying the first application's internals.

### Tasks

- [x] Factor out `App`, startup/shutdown, time, input, and error handling. Implemented, verified, and merged into `main` at `912639e` [S31].
- [x] Add static module registration for `Core`, `Input`, `Assets`, and `Render`. Implemented and verified in `66413bf`, merged through [change 8](https://entire.com/et/bend-engine/-/trails/7/changes/entangle/8) [S32]. Four typed callable slots support source-fixed startup assembly. Public creation now supplies scene descriptions, configurable cameras, and compiled geometry [S36]. No general plugin lifecycle or Bevy Rust API is implemented.
- [x] Define the order: input → fixed simulation → update → apply deferred changes → update global transforms → extraction → rendering → completion handling. The [frame-order contract](docs/frame-order.md) defines phase responsibilities and maps the current demonstration to them. This completes the definition only; full runtime phase support remains unimplemented.
- [x] Use Bendvy schedules. Define when structural changes and removal events become visible. The existing scene uses Bendvy schedules. The [schedule-visibility reference](docs/schedule-visibility.md) defines publication barriers, failure behavior, removal notices, and reader retention from dependency source. This completes the definition only. Removal producers and readers and full runtime phases remain unimplemented. The [fixed-timestep policy](docs/fixed-timestep.md) schedules the existing scene ticks.
- [x] Extract a small sequential `step` kernel from the existing movement logic. The [step contract](docs/step-kernel.md) specifies the empty per-transform tick input, ECS ownership, replacement transform, and empty gameplay-event output. The production kernel imports only Base and component records and performs no I/O or clock reads. Whole-scene scheduling remains in Bendvy.
- [x] Use a headless example to define consistent semantics for tick start, numerical updates, and structural commit. This is the reference for R0, not a new ECS or a mandatory parallel runtime. [Reference and verification](docs/headless-reference.md).
- [x] Establish a single owner of mutable state: ECS data and future simulation chunks cannot be two independently writable versions of the same components. The [state ownership contract](docs/state-ownership.md) keeps ECS authoritative and requires future chunks to transfer exclusive access to owned storage. Formal adapter laws bind current movement to the writer's component value rather than copied query views. This completes the ownership decision and current-path verification only. Chunk storage transfer and partition enforcement remain R0–R1 work.
- [x] Add a fixed timestep and an explicit limit on catch-up steps; do not promise bitwise determinism for numerical computations. The [fixed-timestep policy](docs/fixed-timestep.md) uses 250 ms steps, at most four per poll, drops excess whole steps, and preserves fractional time. [Formal and native-window evidence](docs/verification/2026-11-03-fixed-timestep/README.md) covers the clock and actual bounded catch-up.
- [x] Support running game logic headlessly without a window or GPU. [Runner and CPU verification](docs/headless-reference.md).
- [x] Introduce public operations for creating meshes, instances, a camera, and a basic material. [Creation reference](docs/public-creation.md) and [formal, native, and X11 evidence](docs/verification/2026-11-03-public-creation/README.md) cover checked startup compilation, real ECS instances, used-pair geometry, visible RGB tint, range dispatch, empty geometry, and configurable cameras.
- [x] Create a second non-voxel application with different meshes and a controllable object. The [mesh playground](examples/mesh-playground.bend), committed in `45fc1de`, uses four meshes, selective player movement, reset, and camera controls. Formal claims, real ECS replay, and native-window verification cover its behavior [S37].

**Done when:** the second application does not modify the core, does not handle Vulkan handles directly, and has headless runtime verification of its logic; the minimal step contract and sequential movement are accessible to the same verification. Parallel speedup is not required here.

**Acceptance met:** the mesh playground adds application-specific modules while leaving the existing core, schema, renderer, and public APIs unchanged. Content and gameplay use public creation values and Bendvy operations. Its window adapter uses App scope and the renderer API; it does not allocate or manage raw Vulkan resources. Logic checks execute the actual retained ECS application and replay recorded inputs without presenting frames. Separate checks cover rendering, native controls, focus, resizing, and cleanup [S37]. The sequential kernel remains accessible without graphics [S33], and the original scene's runner has separate isolated CPU-only evidence [S35].

**Architectural groundwork:** a logical `RenderId` and the extraction boundary appear now, but persistent scene storage belongs to E5. Use the existing ECS identity through Bendvy; a separate render handle must not replace it or be a pointer into a relocatable array.

**Out of scope:** dynamic plugins, automatic parallelization of every system, a new scheduler, R0–R4 results, networking, or a universal RHI for multiple APIs.

## E3 — First practical formal guarantee

**Goal:** the proof protects executable-code behavior, not merely a model alongside it.

### Contract: valid upload range

For any accepted `offset`, `length`, and `capacity`, the mathematical range `[offset, offset + length)` lies within the buffer. Machine-arithmetic overflow cannot turn invalid input into valid input.

### Checker selection, November 3, 2026

Reuse [`Core.subrange_contains(capacity, offset, length)`](deps/bend-vulkan/src/core.bend). Its unsigned comparisons implement `offset <= capacity` and `length <= capacity - offset`. The difference uses wrapping addition and negation. When the first condition holds, the difference is exact. The checker does not compute `offset + length` during validation. No replacement checker is needed [S38].

The [U64 representation and preconditions](#u64-representation-and-preconditions) below specify this check. The root `upload_range_universal` law now proves its arbitrary-input Boolean equivalence with natural-number containment. See the [proof and trust limits](docs/upload-range.md).

The universal proof reuses the existing modular arithmetic and packed-word comparison lemmas [S38]. It connects unsigned `Core.size_less`, exact subtraction under the first bound, and containment for every input triple. The [verification record](docs/verification/2026-11-03-upload-range/README.md) includes standard proof checks and rejection of a copied checker with its first guard removed.

The dependency's [staging API](deps/bend-vulkan/src/upload.bend) checks source and destination ranges with this function. Entangle's [offscreen](src/scene-render.bend) and [window](src/scene-window.bend) uploads now use [the shared buffer boundary](src/scene-buffer.bend). It retains requested capacity, derives length from the actual byte list, checks the transport limit and conversion exactness, and calls `Core.subrange_contains` before the sole engine raw write. Both geometry paths allocate from serialized bytes instead of widening U32 size products. The default verifier rejects raw writers, forged buffers, and internal-helper bypasses in ordinary repository sources. This is repository policy, not Bend module privacy or a sandbox for downstream raw Vulkan callers. Native checks remain a separate safeguard [S39].

### U64 representation and preconditions

The input type is [`W.U64{lo: U32, hi: U32}`](deps/bend-vulkan/deps/bend-collections/src/math/u64.bend). Define its mathematical value as `V(W.U64{lo, hi}) = lo + 2^32 * hi`, interpreting each limb as an unsigned integer in `[0, 2^32 - 1]`. Arithmetic in `V` uses unbounded natural numbers. Every limb pair is valid and denotes exactly one value in `[0, 2^64 - 1]`. No normalization or signed interpretation is required. This describes a value, not native memory layout or byte order.

`capacity`, `offset`, and `length` all use this representation. The pure checker is total over all three inputs. Callers need not establish `offset <= capacity`, that subtraction cannot underflow, or that `offset + length` fits U64 before calling it. These are validation outcomes, not caller preconditions. Comparisons use unsigned high-limb order followed by unsigned low-limb order when the high limbs are equal, as implemented by `Core.size_less`. `W.le_signed` is not suitable.

The acceptance rule uses these ordered conditions:

1. Reject when `offset > capacity`.
2. Otherwise, accept exactly when `length <= capacity - offset`.

Both comparisons are unsigned. The selected implementation expresses the conditions as a Boolean conjunction. Its subtraction is `W.add(capacity, W.neg(offset))`, computed modulo `2^64`. Once `offset <= capacity` holds, that result equals the mathematical difference and lies in `[0, 2^64 - 1]`. If the first condition fails, the checker rejects regardless of the wrapped difference. Correctness therefore does not depend on short-circuit evaluation. Validation never computes the machine sum `offset + length`.

The mathematical contract now proved is, for every `capacity`, `offset`, and `length` of type `W.U64`:

```text
Core.subrange_contains(capacity, offset, length) = True
    if and only if
V(offset) <= V(capacity)
    and V(length) <= V(capacity) - V(offset).
```

The subtraction in this statement is interpreted under the preceding bound. Acceptance must imply `V(offset) + V(length) <= V(capacity) <= 2^64 - 1`, with addition over natural numbers. Thus the half-open byte range `[V(offset), V(offset) + V(length))` lies within `[0, V(capacity))`. An empty range still requires `offset <= capacity`. Zero capacity accepts only zero offset and zero length. An offset equal to capacity accepts only zero length. The value `W.U64{4294967295, 4294967295}` is the literal maximum value for this checker, even though `Core.whole_size()` returns the same bits. The checker does not interpret it as a sentinel for remaining bytes.

For this numeric guarantee to protect an upload, callers must supply exact byte quantities for the same storage region and origin. Capacity must describe accessible storage that remains valid through the operation. Any source and destination ranges require separate checks against their respective capacities. Conversion and size calculation must preserve the intended values before validation. In particular, widening a U32 product after it wraps cannot recover its byte count. Values outside U64 must be rejected before conversion, and any whole-size sentinel must be resolved before this check.

Acceptance establishes numeric containment only. A native operation may impose stricter limits or reject zero-length operations. Handle validity, source payload availability, alignment, binding offsets, synchronization, and resource lifetime remain separate obligations. The theorem establishes numeric equivalence. The production boundary and its [verification limits](docs/upload-range.md) separately establish how the engine uses that result [S39].

### Tasks

- [x] Review existing arithmetic laws and select an existing checker if its contract is sufficient. Selected `Core.subrange_contains`; reuse its implementation and the existing arithmetic proofs [S38].
- [x] Specify the U64 representation and preconditions; use a check without unsafe addition, such as `offset <= capacity`, followed by `length <= capacity - offset`. The [contract above](#u64-representation-and-preconditions) defines the full input domain, unsigned comparisons, empty ranges, maximum values, and upload caller obligations for the selected checker.
- [x] Prove the property for arbitrary accepted input, not only for the sizes of one scene. `upload_range_universal` proves the Boolean equivalence for every production U64 triple, with no offset or no-overflow premise. See [proof and verification limits](docs/upload-range.md).
- [x] Integrate this exact function into the production upload path; prevent the engine's ordinary API from bypassing the check. Both renderers use the capacity-bearing buffer API in `47534e7`. The default gate rejects bypasses, including ten verified source mutations. See [production enforcement and trust limits](docs/upload-range.md) [S39].
- [x] Complete ABI, boundary, and negative verification, including zero sizes and maximum values. Real Vulkan drivers cover scalar U64 ABI values, flattened high-limb buffer creation without a large allocation, zero allocation failures, empty endpoints, maximum offsets/counts, invalid bytes after a valid prefix, and unchanged destinations. Exact 16 MiB writes/reads and separate engine/native limit-plus-one rejection pass with complete byte comparisons and cleanup. This does not establish every Vulkan structure ABI. See [the verification record](docs/verification/2026-11-03-upload-abi/README.md) [S40].
- [x] Introduce a controlled bug that violates the contract and confirm that the proof is no longer accepted. Removing the first guard in a disposable copy rejects the unchanged universal proof; restoration passes. See the [mutation evidence](docs/verification/2026-11-03-upload-range/README.md). Separate source mutations also verify production API enforcement [S39].

### Resource lifecycle

- [x] Add mesh replacement with deferred destruction of the old resource. Both production renderers share an owner-preserving transaction, paired atomic retirement, candidate rollback, and separate lifecycle collection. [Real Vulkan and X11 verification](docs/verification/2026-11-03-mesh-replacement/README.md) covers changed ranges/pixels, invalid preservation, completed-command retention, recording rejection, repeated empty transitions, and cleanup [S48].
- [x] Account for recorded commands, submissions, descriptors, and other retaining references, not just the completion of one GPU call. The existing registry tracks the complete ownership chain. [Real Vulkan verification](docs/verification/2026-11-03-mesh-replacement/README.md#retaining-references) now covers recorded and unsubmitted commands, two submissions, descriptor rebinding, independent uniform-descriptor sets and array slots, and memory aliases. Completion, device idle, or release of one owner does not reclaim an allocation while another reference remains. The default native gate checks final-reference release, collection, stale handles, and zero-object cleanup [S49].
- [x] Preserve native checks; check failures during recording, submission, reset, and partial preparation. Native checks and production implementations are unchanged. Real Vulkan verifies genuine allocation failure, partial rollback, unchanged resident identities/bytes, retry, lifetime rejections, cleanup diagnostics, and terminal teardown [S50]. Bounded verification of the actual C handlers covers arbitrary driver results for recording/reset, uncertain submission, sticky device loss, descriptor free/reset quarantine, and failed completion/entry cleanup [S51]. All 11 proof entries and 18 source-regression controls pass alongside the full native gate. Closure uses the approved formal-plus-real-runtime criterion; rare driver errors are formally covered within the [documented bounds](proofs/native-failures/README.md), not claimed as observed hardware events.
- [x] Extend retaining-reference verification to sampled-image descriptors. The [sampled helper](tools/verify-sampled-retention.bend) covers views, samplers, images, and bound memory through two submissions, rebinding, completion, reset, partial slot rewrites, independent sets, final overwrite, set free, pool reset, and pool destruction. Exact counts, stale handles, and zero-object cleanup pass in the default native gate [S52].
- [x] Document the mesh lifetime contract and its [native trust boundary](docs/mesh-replacement.md) separately. The contract distinguishes submission completion, recorded references, descriptor slots and sets, memory bindings, and copied handle values. Failure-handler verification has explicit native proof bounds [S51]; sampled-image retention has real-runtime coverage [S52]. A complete lifetime proof is not a hidden alpha requirement.

The current backend distinguishes execution completion from releasing retaining references [S6]. The expanded native gate verifies this distinction for buffer retirement and sampled-image resource destruction without changing the renderer or dependency implementations [S49, S52].

Capacity pools such as `bend-kit-resources` do not track recorded commands, submissions, or descriptors [S47]. Their reservation laws cannot substitute for this resource-lifetime contract.

**Done when:** the proven general property is actually used by the upload path, dynamic replacements pass checks, and trust boundaries are documented.

**Not proven by this stage:** alignment, validity of all GPU accesses, synchronization, the native implementation as a whole, shaders, the driver, or the compiler. These retain separate requirements and verification.

## E4 — Assets and a conventional 3D scene

**Goal:** the engine accepts prepared assets and creates an interactive scene.

### Tasks

- [x] Add a minimal Asset API: handles, loading/error state, a cache, and release rules. Landed on `main` as `513e5e4`: [API reference](docs/assets.md), [source](src/asset.bend), and [trail 23](https://entire.com/et/bend-engine/-/trails/23). Root lifecycle laws, real file loading/retry, and scene execution after source release pass. Scope names must be unique across handle lifetimes; native resource ownership is unchanged.
- [x] Define an [internal mesh and material format](docs/content.md) independent of the importer.
- [x] Select and integrate one [PNG image decoder](docs/image-decoder.md). Native comparison of pinned Jonlib and `emerging-ezimg` on retained cat photos, PNG variants, and engine captures qualifies Jonlib [S41, S43]. Accepted variants, limits, layout, errors, licenses, and reproduction are recorded in the [verification evidence](docs/verification/2026-11-04-image-decoder/README.md). QOI is not added.
- [x] Start the [static-model importer](docs/model-obj.md) with validated Jonlib S41 `src/obj.bend`. Ordered mesh/material/label sources load synchronously through Assets without ECS or Vulkan ownership. The authored-triangle/diffuse profile, exact pin/licenses, properties, file/cache behavior, and real imported Creation/ECS/offscreen/X11 evidence are [recorded](docs/verification/2026-11-04-model-obj/README.md). Other E4 tasks remain incomplete.
- [ ] Choose one JSON parser for scene files and manifests [S44]. Validate schema, number ranges, duplicate-key policy, asset references, and size/depth limits at the loading boundary.
- [ ] For math or collision routines needed by the chosen consumers, evaluate Jonlib reuse through explicit adapters [S41]. Preserve Entangle's matrix multiplication, quaternion, projection, and numerical contracts; verify any replacement against retained scene evidence.
- [ ] Extend the position/color vertex format with the attributes needed for textures and lighting. Implement texture upload and lifetime management, a textured material, a simple light source, and a camera in the existing Vulkan path.
- [ ] Add scene descriptions, a Transform → GlobalTransform hierarchy, and rejection of parent cycles.
- [ ] Correctly update dependent transforms/bounds when a parent changes; this must feed into future render change tracking.
- [ ] Check corrupted files, missing assets, unsupported variants, and repeated loading.
- [ ] Make a model viewer and a small scene with gameplay interaction the two required consumers.

### Importer and math limits

At the reviewed revision, Jonlib's standard PNG profile limits dimensions to 4096 per side and encoded input to 2 MiB. It supports variants, including Adam7 and 16-bit samples, beyond ezimg's PNG subset. Validate the selected profile with real assets and explicit rejection paths; a compiler check alone does not choose a decoder [S41, S43].

Jonmath's `Matrix.multiply(left, right)` computes `right × left` in column-vector notation. Entangle's matrix function computes `left × right`. Preserve the existing Vulkan projection and choose a fixed numerical contract instead of switching simulation results according to the host's libm profile [S41].

Defer GLB until a consumer needs it. Jonlib's reviewed loader accepts a restricted binary glTF subset, rejects text `.gltf`, and truncates indices to 16 bits for raylib compatibility. An Entangle adapter must reject out-of-range indices before truncation or preserve U32 indices in a revised importer. Jonlib's software drawing and shader-uniform wrappers do not implement Entangle's textured Vulkan renderer or lighting [S41].

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
- [ ] If compaction needs a prefix scan, evaluate the reviewed `bend-parallel` algorithm only after the R0 ownership audit [S46]. Bend GPU dispatch does not establish access to Vulkan buffers or the synchronization needed by indirect draws.
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
- [ ] Audit the `Array.fork` and `Array.join` path used by `bend-parallel@0.1.0.0` [S46]. The local strict check rejects its unsafe dependencies. Its compiled sharing semantics are outside the proof model; do not treat it as a proven split API or evaluate these kernels in the checker. Prefer independently owned chunks until a justified alternative passes real execution checks.
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
- [ ] After R0 and the sequential baseline, evaluate `bend-parallel` scans, histograms, stable counting sort, and gather where they fit [S46]. Validate key bounds before the library clamps invalid keys into its last bucket. Prevent wrapping U32 counts from changing event multiplicity, and include scratch storage and assembly in measurements. Stable sorting preserves an input order; the engine must first make that order independent of worker completion.
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

Use `bend-mathlib` only for lemmas missing from the current proof dependencies [S45]. A package import that prints `ALL PROOFS CHECK` is not evidence that every desired property was stated, that the kernel was rerun with `--verdict`, or that native execution matches the model. Keep unsafe and foreign dependencies outside a claimed proof boundary unless that boundary explicitly accounts for them [S42, S46].

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

For a parallel candidate, include one CPU thread and representative thread counts for the primary development machine. Measure Bend GPU lane and work decomposition separately on the available execution lane. Before adoption, demonstrate a repeatable improvement in representative end-to-end workloads while preserving observable world and geometry state. Independence alone is not a reason to fork, and fine-grained leaf work stays sequential.

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

Complete, E2. App extraction and static startup registration are on `main` [S31, S32]. Frame ordering, publication visibility, the sequential step, and ECS ownership are defined [S33]. Bounded fixed steps, isolated headless execution, and public startup creation are verified [S34–S36]. The mesh playground supplies the second interactive application with real ECS replay and native-window evidence [S37]. Persistent RenderScene storage remains E5 work; parallel kernels remain on the R0–R4 track.

### First research issue after E2

**Audit pinned Bend ownership and extend the headless simulation reference (R0).** Reuse E2's step, ownership contract, and CPU runner. Check actual array ownership operations and parallel calls, record an ADR, and define reproducible correctness and benchmark workloads. E2 does not establish chunk transfer or parallel execution. R0 remains an optional experiment after E2, not the next required alpha stage.

**Next action:** continue E4 with native texture upload, sampling, and textured materials through Assets. The Asset API, internal source format, and PNG decoder are on `main` through `90c7b7e`. The bounded [OBJ importer](docs/model-obj.md) is on `main` through `a016c6b`, with source, cache/retry, Creation/ECS, offscreen, and X11 evidence. E4 and E5 still precede `v0.1-alpha`. Use the [development workflow](docs/development.md) to define required evidence before implementation.

---

## Sources and bases for decisions

S1–S13 and the historical E0 evidence are carried forward from revision 3: its statuses are based on the logs/commits listed there. New sources S14–S22 were checked for revision 4, dated November 2, 2026. In revision 5, the independent window example's status was confirmed through the published README/repository page [S23]; there was no independent local run or clean-checkout gate at that time. Revision 6 adds the results of the actual clean-checkout gate and window verifier [S24]. The E1 updates record the native dependency baseline, scene extraction, rendering, window behavior, and measurements [S25–S30]. E2 evidence covers App extraction through the second application [S31–S37]. E0–E2 status reflects committed sources and recorded results through `2faa879`. The E3 review adds source inspection and standard proof checks at `7043fa6` [S38], without fresh native runtime execution. The later universal proof and production integration add kernel checking, real uploads, source mutations, and native renderer verification [S39]. External sources S1–S23 were not rechecked. The November 3 dependency research adds source inspection and scoped compatibility checks [S41–S47]; it completes no engine stage.

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

- [S28] Entangle commit `570e20f`, pushed on `feat/public-vulkan-renderer` on November 3, 2026 local time. The [reviewable change](https://entire.com/et/bend-engine/-/trails/4/changes/entangle/2) records the work. Sources are the [renderer](src/scene-render.bend), [matrix operations](src/scene-matrix.bend), [index validation](src/content.bend), [native rendering verifier](examples/scene-render.bend), [coverage derivation](docs/render-verification.md), [formal claims](LAWS.bend), [proofs](PROOF.bend), and [full verifier](tools/verify.bend). The full verifier and final native validation exited with code `0`. Local, untracked evidence is retained in `build/render-parent-verify.log`, `build/render-reviewed-validation.log`, `build/render-reviewed-proof.log`, and `build/render-sources.sha256`. The executable regenerates `build/scene-render.ppm`. Evidence covers the GTX 1660, both index orders, eight ticks, exact RGBA8 and D32 readback, recovery after rejected input, and zero live objects. Other drivers, device loss, window presentation, and performance were not verified.

### Entangle existing window integration

- [S29] Implementation on `feat/renderer-window`, based on `8012567`, independently reviewed and verified November 3, 2026. The [reviewable change](https://entire.com/et/bend-engine/-/trails/5/changes/entangle/3) records the work. Sources are the [window adapter](src/scene-window.bend), [ECS executable](examples/scene-window.bend), [native window driver](tools/verify-window.bend), and [verification record](docs/window-verification.md). `bend PROOF.bend`, `bend tools/verify.bend`, and the actual-executable window driver each exited `0`. Local evidence is in `build/window-evidence/proof.log`, `full-verify.log`, `verification.log`, scenario logs, PPM captures, and `captures.sha256`. An owned rootful Xwayland used `DISPLAY=:2`; it was stopped and reaped. All six camera keys changed geometry, R returned exact pixels on retained ECS data, repeated landscape and portrait extents matched on revisits, and shutdown scopes had zero live Vulkan objects. No validation errors or synchronization hazards occurred. Deprecated validation-setting warnings are retained. This is window correctness evidence, not timing, performance, sanitizers, or device-loss evidence.

### Entangle native baseline measurements

- [S30] Implementation measured before commit on `feat/baseline-measurements`, based on `f4aea1f`, November 3, 2026. The [measurement report](docs/baseline-measurements.md) records five fresh live and five fresh retained-replay processes through the shared native renderer. The [evidence](docs/verification/2026-11-03-baseline) includes exact CPU spans, raw GPU timestamps and F32 bits, successful host-write and command counters, per-repeat summaries, machine and source provenance, independent native-window validation, and zero-object cleanup. Live ticks retain the 250 ms schedule. Instrumentation overhead and physical traffic remain unmeasured. No optimization, speedup, GPU-compute scaling, or future phase is established. Independent measurement review accepted the recorded evidence. The attempt-cap correction is documented in the report.

### Entangle App extraction

- [S31] Entangle commit `912639e`, merged into `main` on November 3, 2026. The [merged change](https://entire.com/et/bend-engine/-/trails/7/changes/entangle/6) contains the extraction. Sources are the [App scope](src/app.bend), [time policy](src/time.bend), [input controller](src/input.bend), [Action errors](src/error.bend), and [concrete scene App](examples/scene-window-app.bend). The [verification record](docs/verification/2026-11-03-app/README.md), [native log](docs/verification/2026-11-03-app/native.log), and [byte-equivalence results](docs/verification/2026-11-03-app/equivalence.log) record passing proofs, native/offscreen and window checks, exact replay evidence, and zero-object cleanup. The [Bend comparator](tools/compare-window-evidence.bend) reruns the capture/log comparison. Both executable loops retain their ordering and the baseline retains its timing boundaries. This is structural extraction evidence, not a second application, fixed-timestep implementation, headless game API, or speedup claim.

- [S32] Entangle commit `66413bf`, merged into `main` through [change 8](https://entire.com/et/bend-engine/-/trails/7/changes/entangle/8), confirmed November 3, 2026. Sources are the [registration types](src/modules.bend), [example adapters](examples/scene-window-modules.bend), and [window startup](examples/scene-window.bend). The [design and verification record](docs/modules-registration.md), [proof log](docs/verification/2026-11-03-modules/proof.log), [native log](docs/verification/2026-11-03-modules/native.log), [window log](docs/verification/2026-11-03-modules/window.log), and [exact comparison](docs/verification/2026-11-03-modules/equivalence.log) record the passing checks. The four required typed slots enforce registration completeness. Camera initialization and reset have formal laws. Registration behavior and mesh preservation are validated through native execution because the full registration imports Vulkan foreign effects into the proof graph. All 13 deterministic captures and the replay and terminal logs match the pre-change evidence. Scope cleanup leaves zero live Vulkan objects. This completes static startup registration only.

### Entangle E2 contracts and sequential reference

- [S33] Commits `566262a`, `d18c962`, `fe64ff8`, `abc11aa`, and `80619cf` define [frame order](docs/frame-order.md), [schedule visibility](docs/schedule-visibility.md), the [sequential step](docs/step-kernel.md), the [headless reference](docs/headless-reference.md), and [state ownership](docs/state-ownership.md). Evidence for the [step extraction](docs/verification/2026-11-03-step/README.md), [tick reference](docs/verification/2026-11-03-headless/README.md), and [ownership adapter](docs/verification/2026-11-03-state-ownership/README.md) records proof checks and actual production execution. These contracts do not establish full runtime phases, removal processing, rollback, or future chunk transfer.

### Entangle bounded fixed steps

- [S34] Commit `36c7824` implements the [fixed-timestep policy](docs/fixed-timestep.md) in [time.bend](src/time.bend). The [verification record](docs/verification/2026-11-03-fixed-timestep/README.md) covers accounting properties, native scheduling, actual stalled-window catch-up, exact retained replay, and zero-object cleanup. The isolated timing proof slice passed BendTT. The whole-repository optional `--verdict` run encountered translation limitations; the standard proof gate passed. These are correctness results, not a performance comparison.

### Entangle CPU-only headless runner

- [S35] Commits `7b3986d` and `30c1635` add the [headless runner](src/headless.bend) and fresh isolated CPU evidence. The [verification record](docs/verification/2026-11-03-headless-runner/README.md) records direct production execution, the observed reference, and all nine batching partitions across eight ticks. The isolated build has no graphics sources, libraries, display, or GPU access. The [public-creation follow-up](docs/verification/2026-11-03-public-creation/README.md) records a corrected source manifest and another successful isolated run after creation became a transitive dependency. This evidence covers the original scene's CPU entry points, not a separate isolated build of the mesh playground.

### Entangle public startup creation

- [S36] Commit `4fa8a6c` adds [public scene creation](docs/public-creation.md) and the [public creation example](examples/public-creation.bend). The [verification record](docs/verification/2026-11-03-public-creation/README.md) covers checked descriptions, real ECS instances, geometry ranges, RGB tint, empty geometry, configurable cameras, exact old-scene replay, and cleanup. Creation remains startup-only with opaque unlit materials. Dynamic assets, textures, hierarchy, and persistent GPU scene storage remain E4–E5 work. Existing validation does not complete E3's arbitrary-input upload-range guarantee.

### Entangle second interactive application

- [S37] Commit `45fc1de` adds the [mesh playground executable](examples/mesh-playground.bend), [content](examples/mesh-playground-content.bend), [retained ECS application](src/mesh-playground.bend), and [control logic](src/mesh-control.bend). The [verification record](docs/verification/2026-11-03-mesh-playground/README.md), [proof log](docs/verification/2026-11-03-mesh-playground/proof.log), [real ECS results](docs/verification/2026-11-03-mesh-playground/ecs.log), [window results](docs/verification/2026-11-03-mesh-playground/window.log), and [input replay](docs/verification/2026-11-03-mesh-playground/replay-live.log) establish selective player movement, preserved static state, reset, bounded catch-up, focus clearing, camera controls, resizing, and clean exit. Ordinary untraced window runs and the original consumers' checks also passed. Evidence is for the available Linux X11/Vulkan runtime, using synthetic input delivered to the real X11 server. It does not establish other GPU backends, concurrency, or speedup. Commit `2faa879` adds the recorded demo to the README.

### Entangle E3 checker review

- [S38] Read-only source review and proof checks on November 3, 2026, at Entangle `7043fa6b76edb50b43a7f9a81e5f5116ecdea235`, bend-vulkan `a144f7dd4fb4835ca3d5ce17350fc850de049038`, and bend-collections `bc78c4f4cabb536a2a1dd6e308b6a8f0afafda7c`. Sources are the [existing checker](deps/bend-vulkan/src/core.bend), [staging callers](deps/bend-vulkan/src/upload.bend), [range laws](deps/bend-vulkan/LAWS.bend), [range proofs](deps/bend-vulkan/PROOF.bend), [U64 specification](deps/bend-vulkan/deps/bend-collections/spec/math/u64.bend), [arithmetic lemmas](deps/bend-vulkan/deps/bend-collections/proofs/math/u64/u64.bend), and [arithmetic contract proofs](deps/bend-vulkan/deps/bend-collections/proofs/math/proof.bend). `bend PROOF.bend` passed from both the Entangle and bend-vulkan roots. From the bend-collections root, `bend proofs/math/u64/u64.bend` and `bend proofs/math/proof.bend` also passed. Each command exited with code `0` and reported `ALL PROOFS CHECK`. These were standard checks without `--verdict`. The review selected an existing implementation without code changes. It did not add the universal accepted-range theorem, integrate the checker into Entangle, or rerun native uploads.

### Entangle E3 proof and production enforcement

- [S39] Commit `8a93ddd` proves universal containment for the production U64 checker. Commit `47534e7`, now on `main`, integrates it through [scene-buffer.bend](src/scene-buffer.bend), migrates both renderers, and adds [source-policy](tools/verify-upload-boundary.bend), [mutation](tools/verify-upload-mutations.bend), and [real Vulkan upload](tools/verify-upload-runtime.bend) drivers. The [boundary documentation](docs/upload-range.md) and [verification recipe](.agents/skills/verify-entangle/features/upload-boundary.md) describe reproduction and trust limits. Root standard proofs, the standalone universal proof with `--verdict`, ten isolated bypass mutations, real upload/readback and cleanup, the default offscreen gate, native mesh and cube windows, public creation, deterministic replay, and diagnostics off/on passed. Local run evidence remains under `build/verification/upload-cmBuScEY` and `build/verification/entangle-3Aa4mQl8`; those gitignored artifacts are not part of the published repository. Exact 16 MiB and limit-plus-one native transfers were not executed. The new payload bridge proofs received the root standard check, not a full-root kernel rerun. ABI coverage, dynamic replacement, and broader resource-lifetime guarantees remain separate work.

### Entangle E3 native ABI and transport boundaries

- [S40] Verification on `verify/upload-abi-limits`, based on `57d1f4c`, November 3, 2026. The [reviewable evidence](docs/verification/2026-11-03-upload-abi/README.md) records root proofs, source-policy and mutation checks, freshly compiled real Vulkan production/native drivers, and the default gate. Each driver checks 140 scalar U64 ABI inputs. An unbound `W.U64{257,1}` buffer reports requirements `W.U64{272,1}` without a 4 GiB allocation. Both drivers compare every byte and exact length for 16777216-byte transfers between two guards. Separate in-range engine and native 16777217-byte writer rejections, native read rejection, zero/max negative cases, unchanged complete destinations, immediate disposal counts, and zero final live objects pass. The standalone raw verifier is pinned by its complete source hash and cannot accept or return engine memory. Production hashes, dependencies, execution parallelism, and the 300000 ms command deadline are unchanged. Scalar roundtrips retain the paired-error caveat and do not cover all Vulkan structures. Dynamic replacement and broader resource lifetime remain open. No new window run or performance claim is made.

### Jonlib and BendHub dependency research

Reviewed November 3, 2026, using the installed Bend 2.0.39. The following are research results, not dependency-adoption evidence. Hub checks used a file containing only `import 0x<hash>/<entry> as Candidate`, run with `bend <file> --check-only`. They did not execute a package's `main` or foreign effects. No full conformance suite, kernel recheck, GPU execution, or performance measurement was performed for this survey.

- [S41] [Jonlib source](https://github.com/jonathanperis/jonlib/tree/5e49707e346453f7d36c27d5ca0cb286e431973d), including the pinned [model profiles](https://github.com/jonathanperis/jonlib/blob/5e49707e346453f7d36c27d5ca0cb286e431973d/docs/MODELS.md), [PNG profile](https://github.com/jonathanperis/jonlib/blob/5e49707e346453f7d36c27d5ca0cb286e431973d/docs/PNG.md), [math conventions](https://github.com/jonathanperis/jonlib/blob/5e49707e346453f7d36c27d5ca0cb286e431973d/docs/MATH.md), [compiler overlay](https://github.com/jonathanperis/jonlib/blob/5e49707e346453f7d36c27d5ca0cb286e431973d/patches/README.md), and [license notices](https://github.com/jonathanperis/jonlib/blob/5e49707e346453f7d36c27d5ca0cb286e431973d/THIRD_PARTY_NOTICES.md). Checking `src/qoi.bend`, `src/png.bend`, `src/obj.bend`, and `jonmath.bend` passed. Checking `jonlib.bend` failed at the undefined `Path.stat` effect. The existing `examples/math.bend` compiled natively and printed `5` with `+RTS --threads 1 --gpu off`. That single example establishes neither decoder behavior nor full numerical or platform compatibility.
- [S42] [BendHub catalog](https://hub.bend-lang.com/packages) and [publishing guide](https://hub.bend-lang.com/guide); [Bend Crater](https://pedrovioliv.github.io/bend-crater/) and its [method](https://github.com/PedroVIOliv/bend-crater#what-a-cell-means). The catalog was surveyed across its pages and named versions were grouped before selecting candidates. Crater's results are compiler checks, including separate unsafe and timeout statuses, not runtime validation. The package hashes below identify reviewed content independently of later catalog changes.
- [S43] [`emerging-ezimg@1.3.0.0`](https://hub.bend-lang.com/0x57618559b9b26dd8415f821176a3e692), hash `0x57618559b9b26dd8415f821176a3e692`, entry `main.bend`. Published `main.bend` and `src/png.bend` establish the pixel representation and PNG subset. The local import check passed. No image decode, export, or Vulkan upload was run during this survey.
- [S44] [`bend-kit-json@0.7.0.0`](https://hub.bend-lang.com/0x37aacddc1dcb57464b8b5ac6c397bd64), entry `json.bend`, and [`ezjson@1.4.0.0`](https://hub.bend-lang.com/0xdab377b48b4edd8247427c10e2120805), entry `main.bend`: both local import checks passed. The kit imports [`bend-kit-bytes@0.3.3.0`](https://hub.bend-lang.com/0x632652e3c1c0183f12728faf3870bb68), entry `bytes.bend`; its ownership and bounds APIs were inspected. These checks do not validate Entangle's future scene schema or asset limits.
- [S45] [`bend-mathlib@0.8.1.0`](https://hub.bend-lang.com/0x8ae61ec3a6615abd35f196c07232ad28), hash `0x8ae61ec3a6615abd35f196c07232ad28`, entry `all.bend`; [upstream lemma documentation](https://github.com/bendlib/bendlib). The local import check passed. Upstream reports separate kernel checks; this survey did not repeat them or replace Entangle's existing arithmetic proofs.
- [S46] [`bend-parallel@0.1.0.0`](https://hub.bend-lang.com/0xeef3a8486d410ea6f25709aac90dbf40), hash `0xeef3a8486d410ea6f25709aac90dbf40`, files `scan.bend`, `histogram.bend`, and `sort.bend`. The local `sort.bend` import check exited with code `1`, reporting dependencies on unsafe code. The sources document `Array.fork` sharing outside the checker model, wrapping U32 scan sums, last-bucket clamping, and scratch buffers controlled by fork depth and bucket count. No native algorithm run or speedup was established here.
- [S47] Deferred candidates: [Gralha image representation](https://hub.bend-lang.com/0x2c63b99c875a43494881cedcbf2f440f), [bolt 1.27.0.0](https://hub.bend-lang.com/0xe80b84e038766a5c0c16cf84a1d6b0cf), [cache 0.3.0.0](https://hub.bend-lang.com/0x1afe27789226a57428f7ceb2621e112e), [resources 0.1.0.0](https://hub.bend-lang.com/0x8ef64648a1ae4481382be5e5ce2a9fc8), [archive 0.5.1.0](https://hub.bend-lang.com/0xb03a6159aa2131a6271ae6f2503d02f4), and [storage 0.1.0.0](https://hub.bend-lang.com/0x50c218b3c125011f70b36a9eb33129ac). Published source and the corresponding [bend-kit documentation](https://github.com/paymog/bend-kit) were inspected for ownership and native dependencies. No Entangle integration, native library qualification, or resource-lifetime guarantee follows from that inspection.

### Entangle E3 mesh replacement

- [S48] [Mesh replacement contract](docs/mesh-replacement.md), [production transaction](src/scene-geometry.bend), and [verification record](docs/verification/2026-11-03-mesh-replacement/README.md), November 3, 2026, based at `d258fe3`. Both production APIs replace complete geometry and return the owner on rejection. Real offscreen readbacks and X11 captures cover replacement, preservation, ranges, repeated empty transitions, atomic recording rejection, native deferred destruction after completed submission, collection after reset, measured writes, and zero-object cleanup. Pure production-helper laws pass the root standard checker. Native implementation correctness and genuine failure paths remain outside that proof. No dependency, runtime parallelism, or performance claim changes are included.

### Entangle E3 retaining references

- [S49] Working-tree verification based on `b9ca656`, November 3, 2026. The [retention helper](tools/verify-buffer-retention.bend), [replacement driver](tools/verify-mesh-replacement.bend), [lifetime contract](docs/mesh-replacement.md), and [verification record](docs/verification/2026-11-03-mesh-replacement/README.md#retaining-references) establish buffer retention through multiple commands and submissions, descriptor rebinding, array slots, independent sets, and shared memory bindings. Collection waits for the last reference. Root proofs and the full native gate pass with Vulkan synchronization validation, no validation diagnostics, and zero final live objects. All 11 source-policy mutations reject with baseline and restored passes. Local evidence is in `build/verification/retaining-references-CO7wB8nW` and `build/verification/upload-mutations-qTreVUiQ`. Renderer and dependency implementations are unchanged. No new X11 run, native failure injection, sampled-image descriptor verification, or native lifetime proof is claimed.

### Entangle E3 native resource failures

- [S50] Working-tree verification based on `bb565d1`, November 3, 2026, tracked by [trail 20](https://entire.com/et/bend-engine/-/trails/20). The [native failure driver](tools/verify-resource-failures.bend), [process-limit boundary](tools/process-address-limit.bend), and [verification record](docs/verification/2026-11-03-native-failures/README.md) exercise genuine `vkAllocateMemory` failure under a process-local limit, immediate partial-allocation rollback, unchanged old resident identities/bytes, and successful retry. Recording/submission/pending-reset rejection preserves earlier references and exact GPU fill output. Partial upload rollback covers all four candidate-retention combinations, successful-write counters, cleanup error accumulation, and zero-object terminal teardown. No production or dependency changes, mocks, or injected Vulkan results are involved. Uncertain submission, device loss, native Vulkan begin/end/reset failures, and descriptor free/reset driver errors remain unexercised; the lifecycle item stays open.

### Entangle E3 native failure-handler closure

- [S51] Working-tree verification based on `e0dfa4b`, November 4, 2026, tracked by [trail 20](https://entire.com/et/bend-engine/-/trails/20). The [formal checker](proofs/native-failures/README.md), [maintenance skill](.agents/skills/verify-native-failures/SKILL.md), and [closure record](docs/verification/2026-11-04-native-failure-closure/README.md) verify production C handler statements with pinned CBMC 6.9.0. All 11 bounded proof entries pass for symbolic driver results, all 18 deliberate native-source regressions produce their expected counterexamples, and the original source passes again. Root proofs, the full native gate, all 11 upload-policy mutation controls, native bundle consistency, and tool-package integrity checks pass. Real Vulkan again produces `vkAllocateMemory: VkResult -2`, rolls back the partial candidate, preserves the resident, retries successfully, and closes with zero live objects and no validation diagnostics. The native gate now includes the formal checks. Local evidence is `build/verification/native-failure-closure-wN6VT5tB`, `build/verification/native-formal-EvlmPb0q`, and `build/verification/upload-mutations-piFDDj5H`. Production code, dependency pins, and native checks are unchanged. No mocked dispatch, injected runtime result, observed device loss, unbounded native proof, new X11 run, or performance claim is included.

### Entangle E3 sampled-image retaining references

Tracked by [trail 21](https://entire.com/et/bend-engine/-/trails/21).

- [S52] Working-tree verification based on `5ef97bb`, November 4, 2026. The [sampled helper](tools/verify-sampled-retention.bend), [default replacement driver](tools/verify-mesh-replacement.bend), and [runtime record](docs/verification/2026-11-04-sampled-retention/README.md) extend retention checks to descriptor-owned image views and samplers, images, and bound memory. Two real submissions, rebinding, command reset/destruction, partial rewrites, independent sets, final overwrite, set free, and pool reset/destruction preserve or release the expected references. Explicit cleanup checks exact counts and stale handles. Root proofs, the full native gate, native failure mutations, the upload-policy mutations, and bundle consistency pass. Production code, dependencies, formal claims, and execution parallelism are unchanged. This establishes native retaining-reference behavior, not texture sampling, image-layout transitions, other backends, or an unbounded lifetime theorem.

Source file for revision 6: `ROADMAP_updated_v5.md`. Revision 4 clarified the direction and added a verifiable simulation track; revision 5 recorded the independent E0 window example; revision 6 closed E0 after its clean-checkout gate. Subsequent updates close E1 [S25–S30] and E2 [S31–S37]. E3 checker selection [S38], the universal numeric theorem, production upload enforcement [S39], scoped ABI/transport verification [S40], mesh replacement [S48], buffer-retention verification [S49], failure-handler verification [S50–S51], and sampled-image retention [S52] complete E3 under the recorded verification limits. Dependency research [S41–S47] narrows future candidates without changing those statuses. E4–E7 and R0–R4 remain incomplete.
