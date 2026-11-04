# Public scene creation

A Bend application describes meshes, colors, transforms, and a camera, compiles the scene, and advances separate instances through production ECS ticks.

## Sub-features

- `creation-public` creates three instances through the public example and advances two ticks.
- `creation-sharing` keeps entity identities separate while identical mesh/material pairs share packed geometry.
- `creation-validation` rejects invalid mesh indices, tints, transforms, and camera configurations.
- `creation-empty` accepts empty scenes and empty geometry.
- `creation-render` draws compiled ranges with the expected colors and depth and can replay retained drawing data.

## How to get to it (user POV)

Use `Vertex`, `Mesh`, and `Basic` from `src/content.bend`. Use `Instance`, `Scene`,
and `Camera` from `src/creation.bend`, then call `Create.compile`. The runnable
public entry is `examples/public-creation.bend`, linked from the root README.
See `docs/content.md` for the source contract and `docs/public-creation.md` for
compilation and errors.

The source-only cache path is `examples/content-assets.bend`. Run
`tools/verify-assets.bend` to check production loading, exact retained source
values after release, and compilation from only Base, Asset, Content, and
Components. The driver prints `Mesh and material source caches verified after
release; source-only closure compiled and ran without Creation or Vulkan.`

## Driving it with native Bend executables

Preconditions: run from the repository root with the pinned compiler and dependencies. The public example requires no display. The supplemental creation driver requires a Vulkan device for real rendering, but no display.

- **Create and advance.** Run this independent block. It retains fresh binaries, command output, and the exit code after the processes finish.

```bash
set +e
mkdir -p build/verification
creation_evidence=$(mktemp -d "$PWD/build/verification/creation-XXXXXXXX")
printf 'Evidence: %s\n' "$creation_evidence"
(
  set -ex
  bend examples/public-creation.bend -o "$creation_evidence/public-creation"
  "$creation_evidence/public-creation" +RTS --threads 1 --gpu off
  bend tools/verify-creation.bend -o "$creation_evidence/verify-creation"
  env -u DISPLAY -u WAYLAND_DISPLAY "$creation_evidence/verify-creation" +RTS --threads 1 --gpu off
) > "$creation_evidence/run.log" 2>&1
creation_status=$?
printf '%s\n' "$creation_status" > "$creation_evidence/run.status"
cat "$creation_evidence/run.log"
test "$creation_status" -eq 0
```

- **Observe public completion.** Require `Public instances completed two production ECS ticks.` from the actual example.
- **Observe state and rendering.** Require the driver's `Public creation verified:` result with four distinct ECS entities, three used pairs, ranges `3,3,6`, two ticks, and zero live Vulkan objects. Also require the empty-geometry/rejection result and the configured-camera result. The driver checks exact real readbacks and retained observations.

- **Check the window adapter when affected.** Insert this block before `run window ...` in the main skill's launch recipe. It uses the owned display and redirects the creation driver's historical capture path. Require red, green, and white captured geometry and `Public creation X11 gate passed with validation and zero live Vulkan objects.` in `creation-window.log`.

```bash
cd "$entangle_repo"
run build-creation-window bend tools/creation-window-app.bend -o "$entangle_evidence/bin/creation-window"
run build-creation-window-driver bend tools/verify-creation-window.bend -o "$entangle_evidence/bin/verify-creation-window"
sha256sum "$entangle_evidence/bin/creation-window" "$entangle_evidence/bin/verify-creation-window" >> "$entangle_evidence/binaries.sha256"
mkdir -p "$entangle_evidence/creation-window"
ln -s "$entangle_evidence/creation-window" "$entangle_runtime/docs/verification/2026-11-03-public-creation"
ln -s "$entangle_evidence/creation-window/native.log" "$entangle_runtime/build/public-creation-window.log"
cp "$entangle_evidence/bin/creation-window" "$entangle_runtime/build/indexed-window"
cd "$entangle_runtime"
run creation-window timeout --signal=KILL 120s "$entangle_evidence/bin/verify-creation-window"
cp "$entangle_evidence/bin/mesh-playground" "$entangle_runtime/build/indexed-window"
run doctor-after-creation doctor
```

## Gotchas

- The public example has three instances. The supplemental verifier has four. Do not substitute one expected count for the other.
- A mesh reference identifies packed geometry, not an ECS entity.
- `--gpu off` disables Bend GPU dispatch. The rendering driver still calls Vulkan.
- The independent CLI block does not prove the X11 creation adapter. Report the window check separately.
- The CLI processes are short-lived and start no display. The optional window check uses the main launch block's display and cleanup. Evidence remains after either path exits.
