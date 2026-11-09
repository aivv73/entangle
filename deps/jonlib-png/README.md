# Jonlib standalone PNG

Vendored from Jonlib commit `5e49707e346453f7d36c27d5ca0cb286e431973d`.
The source is https://github.com/jonathanperis/jonlib/tree/5e49707e346453f7d36c27d5ca0cb286e431973d.

`png.bend`, `codec.bend`, and `inflate.bend` are byte-for-byte copies of upstream `src/` files. There are no local source modifications. SHA-256 pins are in `SHA256SUMS`.
The only import closure is these three files and Base. Entangle calls the standard `Png.decode` entry. It does not call `decode.wide` or import the Jonlib umbrella.

## Bend version

Use **Bend 2.0.40**, the latest stable release checked on November 9, 2026,
with the compiler revision and Bun host pinned in
[`toolchain.bend`](../../toolchain.bend). This standalone decoder runs on the
stock compiler; Jonlib's full-library Bend 2.0.39 overlay is not required.
The decoder sources and their integrity hashes remain unchanged.

From the Entangle root, run `bend tools/verify-images.bend`. The driver checks
the Bend version before comparing the retained corpus pixel for pixel,
checking malformed input, limits, file ownership and cache behavior, and
running the production mutation controls and image consumer.

See the [Bend 2.0.40 compatibility record](../../docs/verification/2026-11-09-jonlib-bend/README.md)
for results and limits.

## Licenses and integration

Original additions are copyright 2026 Jonathan Peris under the zlib license in `LICENSE`. The PNG and DEFLATE code adapts stb_image by Sean Barrett and contributors under its MIT alternative in `LICENSES/stb-image.txt`. `THIRD_PARTY_NOTICES.md` preserves the relevant upstream notice, extracted from upstream lines 267 through 326.

No raylib, native stb, LGPL module, JPEG decoder, or codec registry is included. Entangle's new adapter is `src/image-png.bend`. Its behavior and trust limits are documented in `docs/image-decoder.md`.
