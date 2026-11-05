# Jonlib math qualification

Evaluate Jonlib S41 for the math required by current scene consumers while preserving Entangle's numerical behavior.
The acceptance record is [Trail 29](https://entire.com/et/bend-engine/-/trails/29).
Work starts from Entangle `ac805c7` with a clean working tree.

## Decision

Retain production math in `src/scene-matrix.bend` and `src/creation.bend`.
The qualification adapter converts Entangle's four columns to Jonmath's named matrix fields and reverses multiplication arguments.
Its quaternion adapter retains `x,y,z,w`, applies scale to columns, and inserts translation directly.
Neither adapter normalizes the quaternion or chooses a host libm profile.

Entangle uses column vectors and stores four consecutive columns in its push-constant words.
`multiply(left,right)` means `left * right`.
Each dot product keeps its existing left-associated F32 additions.
`model` interprets quaternions as `x,y,z,w` and applies scale before rotation and translation.
Creation accepts finite transforms whose computed squared quaternion norm is within the inclusive interval `[0.9999,1.0001]`.
It does not normalize accepted inputs.
The camera retains Bend's existing `F32.sin` and `F32.cos` calls, Vulkan's Y flip, and depth range `[0,1]`.
This preserves the pinned runtime behavior without promising cross-platform libm equality.

The source consumers are `Creation.target_view`, `Creation.orbit`, the offscreen renderer, and the window renderer.
They already share the small matrix module.
The adapter adds representation conversion without removing a distinct consumer algorithm.
Importing `jonmath.bend` also brings its numerical closure, including separately licensed LGPL modules.
Keeping production math avoids that additional dependency and preserves the existing arithmetic expressions.

Jonmath's frustum uses the OpenGL depth convention.
Direct replacement of Entangle's Vulkan projection is rejected.
Current mesh movement clamps translation and has no geometric collision query.
The OBJ loader's material-name collision check is a hash collision check.
No collision API or rigid-body behavior is added.

## Dependency and qualification boundary

The candidate is [Jonlib S41](https://github.com/jonathanperis/jonlib/tree/5e49707e346453f7d36c27d5ca0cb286e431973d), entry `jonmath.bend`.
The Git revision is `5e49707e346453f7d36c27d5ca0cb286e431973d`.
This evaluation uses its Git source archive, not a newly published BendHub package.
The exact archive SHA-256 is `d9c2b54411c491674e30aca661c0b300f390195804cbb8a3792802262cdcd781`.

The runner downloads that archive, verifies its hash before extraction, and retains it with the complete upstream sources and licenses.
Jonmath carries the zlib license and adapts raymath under the retained raylib notice.
Its import list includes `src/lgpl/{tan,asin,tanf,sin,acos}.bend`.
Those numerical modules have separate LGPL-2.1-or-later notices in upstream `THIRD_PARTY_NOTICES.md` and `LICENSES`.
No part of this candidate is vendored into production.

The `.bend.in` files in `tools/jonmath` are executable qualification sources.
The runner copies them byte-for-byte into `build/jonmath` after fetching the pinned candidate, then compiles them with Bend.
Their build-only imports stay outside the production source dependency policy.
Both the input templates and the fetched archive remain in the workflow receipt.

The first small native probe qualified matrix order before the adapter was written.
Its retained source is `initial-probe.bend.txt`, with output in `initial-probe.log`.
Run it from `build/qualification/probe.bend` after extracting Jonlib.
The independently calculated scale-after-translation result is `4,9,16`.

## Required evidence

The `math` workflow profile requires the pinned toolchain, source policy, root frontend proofs, native qualification, retained scene comparisons, and law sensitivity controls.
The candidate probe checks exact F32 words, without epsilon comparisons.
It covers matrix layout roundtrips, retained nontrivial quaternion scene seeds, mesh instances, quaternion sign combinations, and a finite matrix/TRS grid.
The grid includes signed zero, the least subnormal, the least normal, and the `2^24` rounding boundary.

The independent noncommuting scale/translation oracle rejects unadapted multiplication.
The projection oracle requires near-plane `z/w=0` and far-plane `z/w=1`.
It also checks the Vulkan Y flip and the width-to-height aspect adjustment.
It observes Jonmath's near-plane `z/w=-1` on the matching symmetric frustum.
Runtime controls deliberately remove the operand reversal and corrupt the production projection depth coefficient in separate source copies.
Each must fail at its named observation.
The unchanged baseline runs again afterward.

Root laws constrain production multiplication order, F32 sum grouping, and the quaternion/TRS formula for arbitrary input words.
The law controls change a matrix column, regroup a dot product, and reverse a quaternion cross-term sign.
Each must fail at its specific law.
These are frontend expression proofs, not an independent kernel proof of floating-point hardware or Jonmath equivalence.

The native consumers run with Vulkan validation enabled.
`examples/scene-render.bend` checks quaternion geometry against its independent scalar coverage/depth oracle in both index orders.
`tools/verify-creation.bend` checks public creation and camera validation.
The OBJ consumer recreates retained sign and wedge scenes through real ECS and Vulkan.
Every byte of their state, packed geometry, RGBA, and D32 output is compared with the existing November 4 evidence.

## Reproduction

Run from the repository root with the pinned native toolchain and initialized dependencies.
The qualifier needs HTTPS access to the pinned source archive and a working Vulkan device with validation layers.

```sh
mkdir -p build
bend tools/verify-workflow.bend -o build/verify-workflow
./build/verify-workflow --plan math
./build/verify-workflow math +RTS --threads 1 --gpu off
```

`--gpu off` disables Bend GPU dispatch. The native scene checks still execute real Vulkan rendering.
This profile is opt-in and part of `all`. The default `native` profile does not download a rejected math dependency.

## Results and limits

The complete receipt is `build/verification/workflow-M6jjQLBR`.
It records root revision `ac805c7252ceeebc683e3cdd2ef514cd762238ff`, the dirty-source patch and status, the full source fingerprint, dependency pins, and exact required commands.
All eight manifest stages exited zero. `state` is `complete` and `run.status` is zero.
The native qualifier, both runtime controls, public creation, quaternion scene, and all eight retained-file comparisons passed.
Vulkan diagnostics contain no validation errors, and all three native consumers report zero live Vulkan objects.
The fresh scene images were inspected from the retained receipt.

All 12 law mutations failed at their named properties.
The new controls identified `render_multiply_order`, `render_apply_order`, and `render_model_contract`.
Both restored frontend baselines passed.
`law-mutations.log` retains that result. The individual counterexamples remain under the receipt's `source/build/verification/law-mutations-dx4Inkh9` directory.
The runtime controls remain under `source/build/jonmath/mutation-*`.

Selected native, qualification, and proof logs are copied beside this record.
`verified-sources.sha256` identifies the laws, controls, runner, templates, archive pin, and production math.
The final `src`, `tools`, laws, proofs, and mutation table were compared byte-for-byte with the verified source snapshot.
Only documentation, roadmap state, and raw-log whitespace metadata changed after that snapshot.

The first workflow receipt, `build/verification/workflow-AoRjoXr2`, failed while compiling the new verifier.
A nested reusable pair binding caused a Bend inference error.
That harness defect was corrected before the fresh successful run.
Its unexecuted math and mutation stages are not counted as passes.

The acceptance scope is the current Linux native lane and the retained consumers.
There is no performance, GPU-dispatch, CUDA, Metal, WebGPU, other-platform libm, or exhaustive floating-point equivalence claim.
X11 windows and the full default native profile were not rerun because production code is unchanged.
Verification ran on uncommitted sources at the recorded base.
The evaluation, verification tools, and documentation are complete.
[Trail 29](https://entire.com/et/bend-engine/-/trails/29) records the publication revision and current task state.
