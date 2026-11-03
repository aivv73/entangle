# Offscreen rendering

An application can render ECS drawing data to an image without opening a window, retain earlier drawing data, and inspect exact color and depth results.

## Sub-features

- `render-image` writes a 1024×256 image from the real Vulkan renderer.
- `render-depth` checks depth and exact coverage with both index orders.
- `render-retained` renders earlier drawing data after later world updates.
- `render-cleanup` returns zero live Vulkan objects, including the terminal Action path.

## How to get to it (user POV)

Build and run `examples/scene-render.bend`. The root README's `bend tools/verify.bend` also builds and executes this example as part of the full native gate. Rendering returns a readback and the example writes `build/scene-render.ppm`.

## Driving it with the native renderer example

Preconditions: the pinned toolchain, all dependencies, Vulkan development headers and loader, and a Vulkan device. No display is required. Run the following independent block from the repository root.

- **Render and inspect.** The native compile commands match `tools/verify.bend`. An isolated current directory redirects the example's fixed image path.

```bash
set +e
mkdir -p build/verification
render_evidence=$(mktemp -d "$PWD/build/verification/render-XXXXXXXX")
printf 'Evidence: %s\n' "$render_evidence"
mkdir -p "$render_evidence/build"
(
  set -ex
  bend examples/scene-render.bend -o "$render_evidence/scene-render.c"
  clang -std=c11 -O2 "$render_evidence/scene-render.c" -lpthread -lm -ldl -o "$render_evidence/scene-render"
  cd "$render_evidence"
  env -u DISPLAY -u WAYLAND_DISPLAY ./scene-render --threads 1 --gpu off
  test -s build/scene-render.ppm
) > "$render_evidence/run.log" 2>&1
render_status=$?
printf '%s\n' "$render_status" > "$render_evidence/run.status"
cat "$render_evidence/run.log"
test "$render_status" -eq 0
```

- **Observe output.** Require `Terminal Action cleanup verified.` and `Public Vulkan renderer verified in both index orders; live Vulkan objects=0; image=build/scene-render.ppm`. Inspect the retained `build/scene-render.ppm` under the printed evidence path with an image viewer.
- **Observe correctness.** The executable compares each coverage and D32 byte against its numerical oracle and checks retained drawing data against the production world. Keep its exit code and full log alongside the image.

## Gotchas

- The image alone cannot prove depth behavior. The native executable's exact readback checks must pass.
- Removing display variables does not remove the Vulkan requirement. `--gpu off` controls Bend dispatch, not renderer allocation.
- This offscreen pipeline does not establish window presentation or parity for arbitrary mesh winding.
- The output directory is evidence, including its `build` subdirectory. Do not delete it as temporary runtime state. The process exits by itself and starts no server.
