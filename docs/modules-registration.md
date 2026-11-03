# Static startup registration

The design exploration selected candidate C's four callable startup slots and
candidate A's constructor-only assembly. Declarations live in
`src/modules.bend`. `Core<A>` and `Registration<A>` are generic over the produced
application type. The example recipe instantiates `A` with `Scene.Application()`.
The remaining slots retain the existing camera, mesh, Vulkan entry, and renderer
types. Constructors require all four slots without an identity registration
function, lookup, installer, or stage registry.

Candidate B bundled configuration and threaded a configurable interval through
the loop. That alternative was rejected because it expanded the change without
providing callable registration. The 250 ms deadline stays in the executable. These
slots support startup only. Static means source-fixed selection and concrete
types; it makes no promise that the compiler erases callbacks.

The executable consumes Assets through Render first, enables the existing input
verification, runs Core's create and first tick, reads time, initializes concrete
state, then consumes Input at the existing camera initialization point. No slot
enters `Running`. Scope, observer layout, geometry, retained drawing, baseline,
loop, and dependencies retain their owners. Assets supplies the existing mesh
rather than introducing an asset service.

## Verification boundary

`LAWS.bend` fixes the default camera's exact value and proves that reset returns
the same initial camera for every camera. `PROOF.bend` supplies both proofs.
These are properties of the production camera controller used by the default
adapter.

Importing the example recipe into a proof file also imports Vulkan foreign
effects. The checker rejects that proof graph even for the default camera
adapter's equality to `Camera.initial()`. The shipped proof gate remains
unchanged. Registration completeness follows from the four required typed
fields. Native execution checks the startup behavior and mesh preservation.

The native example compiles with the actual default recipe. Window verification
compares its execution with the pre-change evidence saved in
`build/modules-before/window-evidence`.

Implementation checks run on November 3, 2026:

- `bend guide` completed before editing.
- `bend PROOF.bend` exited 0 with `ALL PROOFS CHECK`.
- `bend examples/scene-window.bend -o build/indexed-window` exited 0.
- `bend tools/verify.bend` exited 0. Pinned dependencies, native compatibility,
  component defaults, eight scene ticks, both offscreen index orders, exact color
  and depth, retained replay, rejected input recovery, and cleanup passed.
- `git diff --check` exited 0.

The independent native window verifier passed before and after the change on
an owned rootful Xwayland display with Vulkan validation enabled. The existing
`tools/compare-window-evidence.bend` compared all 13 deterministic replay,
camera, resize, and restore captures byte for byte. The replay and terminal logs
also matched exactly. Live movement, hidden ticks, hidden Close, Escape, rejected
input recovery, and cleanup passed. Every completed scope reported zero live
Vulkan objects.

The [native log](verification/2026-11-03-modules/native.log),
[window log](verification/2026-11-03-modules/window.log), and
[comparison log](verification/2026-11-03-modules/equivalence.log) record the runs.
The full before and after captures remain in the ignored `build/modules-before`
and `build/modules-after` directories. To repeat the comparison, run the native
window verifier before and after the change using the owned-display procedure in
[the baseline record](baseline-measurements.md#rerun), preserving each evidence
directory. Then run:

```sh
bend tools/compare-window-evidence.bend -o build/compare-window-evidence
./build/compare-window-evidence build/modules-before/window-evidence build/modules-after/window-evidence
```

## Throughput checkpoint

Architecture selection preceded implementation. Source, proofs, and documentation
share one contract and have one implementation owner. There is no independent
writing stream or runtime parallelism change. No performance claim is made.
