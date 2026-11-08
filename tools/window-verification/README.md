# Entangle window support

GitHub bend-vulkan `1900235` does not contain the window verification helpers
used by Entangle's previous Entire dependency. These files retain those helpers
from `a144f7dd4fb4835ca3d5ce17350fc850de049038`, with the already qualified
[Bend 2.0.40 patch](../../docs/verification/2026-11-07-bend-2.0.40/bend-vulkan.patch).
`existing.bend` retains the shared process, capture, and file helpers;
`check.bend` reads the central compiler pin. The input adapter's source and
package hash are in [input/README.md](input/README.md).

The production boundary is [src/vulkan-window.bend](../../src/vulkan-window.bend).
Its generated C uses the upstream native registry and X11 implementation.
The generator changes effect names, transports returned handle keys into the
upstream typed constructors, and retains the qualified `Press`, `Move`,
`Scroll`, and `Lost` conversion. Resource ownership and Vulkan handlers remain
upstream. The adapter requires the upstream registry to precede it in native
compilation; an unmet requirement fails the build.

After reviewing an upstream change, regenerate and check the adapter:

```sh
bend tools/window-verification/generate.bend -o build/generate-vulkan-window
./build/generate-vulkan-window --write
bend tools/window-verification/generate.bend
```

The workflow runs the correspondence check. Its source policy hashes the three
Bend modules declaring native effects. The owned window launcher runs the real
pointer probe, rejects a deliberate middle/right button regression through both
correspondence and observed events, then restores the passing source. Use the
[project verification workflow](../../docs/development.md) for the complete
native and window checks. The [update record](../../docs/verification/2026-11-08-bend-vulkan/README.md)
contains acceptance and source-specific results.
