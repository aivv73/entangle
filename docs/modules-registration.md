# Static startup registration

`src/modules.bend` requires four typed callbacks. `Core<A>` and
`Registration<A>` are generic over the application type. Registration selects
startup behavior in source. It has no runtime lookup or plugin lifecycle.

Assets returns a public `Create.Scene`. The executable calls `Create.compile`
once, passes the resulting geometry to Render, and passes its seeds to Core.
Input supplies a configurable public camera. The
[creation reference](public-creation.md#startup-callbacks) lists exact signatures.

The default recipe in `examples/scene-window-modules.bend` retains the original
100-entity scene. Core performs creation and the first tick. Render opens the
native window. The executable then initializes time, observation, retained
replay, and the input camera at their existing points. These callbacks do not
enter the running state.

The original registration evidence remains in
[the module verification record](verification/2026-11-03-modules/).
[Public creation evidence](verification/2026-11-03-public-creation/README.md)
covers the current signatures and the preserved demo. The pure proof graph
imports creation and input without importing renderer foreign effects.
