# Mesh replacement

Both renderers replace complete packed geometry without losing the owner on rejection. The [API reference](../../../../docs/mesh-replacement.md) describes the transaction and native trust boundary.

## Sub-features

- `replacement-offscreen` changes real RGBA coverage and range dispatch, rejects removed IDs, and preserves exact RGBA and D32 after invalid candidates.
- `replacement-retention` retires while a real submission is unobserved and another command remains executable but unsubmitted. Collection preserves both pairs through completion and the first reset, then removes exactly four native objects after the final reset. Old handle lookup succeeds before collection and fails after it. Submission of a sealed recording and reset before completion observation are rejected.
- `replacement-descriptors` runs the imported `tools/verify-buffer-retention.bend` helper with real uniform buffers, descriptor arrays, two sets, and two submissions. Completion of one submission, device idle, and command pool destruction preserve remaining owners. Rebinding retains earlier recorded sets. Partial slot rewrites and independent sets retain buffers until the last reference is removed. Freeing a set, resetting a pool, and destroying a pool release their allocations for later collection. New recording and descriptor writes cannot introduce sealed resources.
- `replacement-sampled-descriptors` runs `tools/verify-sampled-retention.bend` through the same driver. Two real submissions retain sampled descriptor arrays through rebinding, completion, reset, and idle. Recorded sets reject updates, free, pool reset, and pool destruction. Descriptors retain views and samplers; views retain images, and image bindings retain memory. Partial rewrites and independent sets prevent destruction until the last reference is released. Final overwrite, set free, pool reset, and pool destruction each permit explicit cleanup, with exact object counts and stale handles.
- `replacement-aliases` binds two real buffers to one allocation. Retirement rejects without sealing, and the bytes remain writable and readable. Destroying the alias permits retirement, which then rejects new aliases. Final collection restores the original live-object count.
- `replacement-rejection` records a reference to only the old index buffer. Paired retirement rejects before sealing either old allocation. Both old byte payloads remain readable and render identically. Prepared candidate resources disappear immediately.
- `replacement-window` captures changed X11 pixels, exact preserved and restored frames, repeated nonempty and empty replacements, hide/restore, and zero-object Close.
- `replacement-collection` checks publication before collection, hidden frame collection without acquisition, empty residents, explicit owner-returning collection, and successful measured writes including rejected candidates.

## Offscreen and retained-command verification

Run from the repository root with the pinned toolchain, clean pinned dependencies, a Vulkan device, and validation layers. Use a fresh evidence directory. No display is required.

```bash
set -euo pipefail
replacement_repo="$PWD"
mkdir -p build/verification
replacement_evidence=$(mktemp -d "$PWD/build/verification/replacement-XXXXXXXX")
mkdir -p "$replacement_evidence/bin" "$replacement_evidence/build"
git rev-parse HEAD > "$replacement_evidence/revision.txt"
find src tools -type f -name '*.bend' -print0 | sort -z | xargs -0 sha256sum > "$replacement_evidence/sources.sha256"
sha256sum LAWS.bend PROOF.bend >> "$replacement_evidence/sources.sha256"
bend PROOF.bend > "$replacement_evidence/proof.log" 2>&1
bend tools/verify-upload-boundary.bend -o "$replacement_evidence/bin/boundary"
"$replacement_evidence/bin/boundary" > "$replacement_evidence/boundary.log" 2>&1
bend tools/verify-mesh-replacement.bend -o "$replacement_evidence/bin/replacement"
sha256sum "$replacement_evidence"/bin/* > "$replacement_evidence/binaries.sha256"
(
  cd "$replacement_evidence"
  env -u DISPLAY -u WAYLAND_DISPLAY VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation \
    VK_LAYER_VALIDATE_SYNC=1 bin/replacement +RTS --threads 1 --gpu off
) > "$replacement_evidence/offscreen.log" 2>&1
printf '0\n' > "$replacement_evidence/run.status"
printf 'Evidence: %s\n' "$replacement_evidence"
```

Require `Mesh replacement offscreen and native retention verified; live Vulkan objects: 0` and no `Validation Error`, `SYNC-HAZARD`, or `VUID-`. Require the memory-alias, two-submission, descriptor-array, and all four `Sampled descriptors:` evidence lines. Inspect the generated `build/replacement-*.ppm` files. The driver checks exact red and green full-square coverage, the changed half-square range, and the empty clear image. It checks the real renderer and native registry, with no substitute allocator or injected failure. A submission described as unobserved remains pending in the registry until an explicit completion observation; this makes no assertion about how long the GPU is physically busy.

## X11 replacement verification

Use the main skill's fresh isolated runtime, owned Xwayland, validation environment, and doctor. Insert this block before its mesh `run window ...` command. The driver starts only the installed child executable and checks its own PID window.

```bash
cd "$entangle_repo"
run build-replacement-window bend tools/mesh-replacement-window.bend -o "$entangle_evidence/bin/replacement-window"
run build-replacement-driver bend tools/verify-mesh-replacement-window.bend -o "$entangle_evidence/bin/verify-replacement-window"
sha256sum "$entangle_evidence/bin/replacement-window" "$entangle_evidence/bin/verify-replacement-window" >> "$entangle_evidence/binaries.sha256"
mkdir -p "$entangle_evidence/replacement-window"
cp "$entangle_evidence/bin/replacement-window" "$entangle_runtime/build/indexed-window"
rm "$entangle_runtime/build/window-evidence"
ln -s "$entangle_evidence/replacement-window" "$entangle_runtime/build/window-evidence"
ln -s "$entangle_evidence/replacement-window/native.log" "$entangle_runtime/build/replacement-window.log"
cmp "$entangle_evidence/bin/replacement-window" "$entangle_runtime/build/indexed-window"
cd "$entangle_runtime"
run replacement-window timeout --signal=KILL 120s "$entangle_evidence/bin/verify-replacement-window"
rm build/replacement-window.log build/window-evidence
ln -s "$entangle_evidence/mesh" build/window-evidence
cp "$entangle_evidence/bin/mesh-playground" build/indexed-window
run doctor-after-replacement doctor
```

The driver sends `i` for invalid preservation, `b` for real recording rejection, `g` for green replacement, `e` for empty replacement, and `r` for red replacement. It waits for each app acknowledgement before checking pixels. Repeated cycles restore the exact first red frame. The app verifies cumulative successful writes, including both writes before recording rejection. It checks hidden-frame collection against actual live-object counts before visible drawing. Close must report `Mesh replacement window closed; live Vulkan objects: 0` without validation diagnostics. Inspect red, green, empty, preserved, and restored captures.

Run the existing offscreen/public-creation and mesh/cube-window regressions after renderer changes. Keep fixed-output gates sequential. The separate [native resource failure driver](resource-failures.md) covers genuine allocation failure and partial rollback. This replacement driver does not induce OOM, uncertain submission, device loss, or native reset/cleanup failure. Sampled-image checks bind descriptors in submitted commands without drawing or sampling texels. They establish retaining-reference behavior, not texture output or image-layout transitions. Other backends remain unexercised. No performance claim follows.
