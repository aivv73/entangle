# E4 consumers

Acceptance is two native applications using public source loading, creation,
scene editing, drawing, and window APIs. The viewer opens a bundled OBJ or a
supplied path, retains source values after cache release, and offers orbit,
zoom, and camera reset. A rejected custom file prints its diagnostic and falls
back to the bundled model. The gameplay scene loads JSON and its OBJ manifest
from disk. Move the courier to the energy crystal, collect it, and deliver it
to the pad. Completion changes the scene. Reset restores the initial state.

The data shape is a consumer kind and a gameplay state with a phase variant,
bounded grid coordinates, and a camera. The three phases are searching,
carrying, and complete. Production scene handles remain in a separate affine
runtime owner. Only the gameplay consumer edits transforms. Renderer lifecycle
stays in the existing synchronous window API.

Required evidence includes root frontend laws, source-specific workflow asset,
JSON, native, and presentation profiles, a deterministic production ECS run,
actual X11 control and pixel capture for both windows, rejected custom input
fallback, completion and reset, and clean Vulkan teardown. New verification
requires a deliberate gameplay regression and a restored passing baseline.
No claim covers arbitrary scene layouts, other graphics backends, or a general
collision system.

Blocking work is acceptance and loading the original assets through the actual
parsers. There are no independent implementation streams. Code, laws, and
verification share one owner. Renderer and verification runs are sequential.

## Run and inspect

```sh
bend tools/verify-workflow.bend -o build/verify-workflow
./build/verify-workflow --plan consumers native
./build/verify-workflow consumers native +RTS --threads 1 --gpu off
```

The `consumers` profile includes asset and JSON verification, root frontend
laws and production law mutations, consumer windows, an independent ECS
coordinate oracle and its production mutation, and presentation ownership
proofs. The `native` profile retains the existing dependent engine gate.
The owned window session can also run directly with
`bash tools/consumers/window-session.sh`.

The session builds fresh binaries, starts an owned Xwayland display, verifies
its process, display, port, and executable identity, and drives five windows.
The scenarios cover the bundled viewer, courier, external sign OBJ, missing
model fallback, and scene-creation fallback. The extreme OBJ fixture must
first load as a valid source and then fail scene creation after fitting.
Both fallbacks must leave an interactive populated viewer with camera reset.

The driver saves initial, changed, completed, and reset PPM captures. It checks
expected warm and cool material regions, control-induced pixel changes,
completion changes, exact reset pixels, resize restoration, actual Close,
zero live Vulkan objects, and clean validation diagnostics. The courier
additionally records pickup, delivery, and reset states through real X11
input. The native ECS driver checks objective coordinates independently of
the production transform function and compares every reset identity,
mesh reference, and transform bit against the disk scene.

`tools/consumers/mutations.bend` lowers the carried crystal into the player.
The unchanged ECS verifier must reject the named independent height property.
Restored sources must pass. Root law controls separately break reset and
allow searching to skip the carrying phase. These are general production
properties and runtime sensitivity checks, not mock or example unit tests.

## Scope and state

This is a bounded grid delivery game, with discrete movement on key presses.
It does not add collisions, inventory, a general game framework, or model
animation. Input handling has no held-key state, so focus loss cannot leave
movement latched. Model support remains the existing strict static OBJ and
opaque diffuse MTL profile. Bounds fitting uses F32 arithmetic. A model whose
fitted scene is rejected prints a diagnostic and uses the bundled beacon.
The bundled model is required at runtime, and commands run from the repository
root. Native rendering and production state evidence do not certify another
backend or device-loss recovery.

Implementation and acceptance are complete locally as of November 12, 2026.
The [source-specific workflow](../../../build/verification/workflow-5u8gfjwH/manifest.tsv)
has state `complete`, run status zero, and zero for every required stage.
It covers the consumer windows and ECS oracle, full native gate, upload kernel,
production law and source controls, native failure controls, and presentation
ownership under their documented bounds. Code publication remains separate.
Its [consumer session](../../../build/verification/workflow-5u8gfjwH/source/build/verification/consumers-LQCzmUm3/)
passed all five windows, independent ECS coordinates, exact state and pixel
reset, resize restoration, validation diagnostics, and zero-object teardown.
The owned display was reaped and its temporary runtime removed. Initial,
completed, and reset captures were also inspected visually.
The [production mutation](../../../build/verification/workflow-5u8gfjwH/source/build/verification/consumer-mutation-l8qqfHTt/)
failed the named carried-height assertion, and restored sources passed.

The workflow was interrupted after its consumer, full native, upload kernel,
law-control, and upload-control stages passed. On November 12, the unfinished
native failure and presentation stages resumed against the retained snapshot.
The [resumption driver](../../../build/verification/workflow-5u8gfjwH/resume.bend)
uses the production workflow executor, retains successful stages, and requires
every planned status to be zero before completing the receipt. Original
statuses remain in `interrupted-status`. Production hashes and the pinned
toolchain were checked again before resumption. Only evidence documentation
has changed since the production snapshot. A final hash comparison also
confirmed that the working production files match the accepted snapshot.

The live driver exposed an input assumption during development. Bend's
standard window API maps Backspace to 127, but the Vulkan window adapter
filters that X11 keysym. Courier reset therefore uses the supported X key
(120). The laws, runtime oracle, live input, title, and instructions use X.
Receipts `workflow-wwek6atn` and `workflow-sYEXtODQ` retain the two failed
Backspace attempts. Earlier interrupted and edited-launcher runs also remain
failed development evidence. They do not establish acceptance.
