# Jonlib standalone PNG

Vendored from Jonlib commit `5e49707e346453f7d36c27d5ca0cb286e431973d`.
The source is https://github.com/jonathanperis/jonlib/tree/5e49707e346453f7d36c27d5ca0cb286e431973d.

`png.bend`, `codec.bend`, and `inflate.bend` are byte-for-byte copies of upstream `src/` files. There are no local source modifications. SHA-256 pins are in `SHA256SUMS`.
The only import closure is these three files and Base. Entangle calls the standard `Png.decode` entry. It does not call `decode.wide` or import the Jonlib umbrella.

Original additions are copyright 2026 Jonathan Peris under the zlib license in `LICENSE`. The PNG and DEFLATE code adapts stb_image by Sean Barrett and contributors under its MIT alternative in `LICENSES/stb-image.txt`. `THIRD_PARTY_NOTICES.md` preserves the relevant upstream notice, extracted from upstream lines 267 through 326.

No raylib, native stb, LGPL module, JPEG decoder, or codec registry is included. Entangle's new adapter is `src/image-png.bend`. Its behavior and trust limits are documented in `docs/image-decoder.md`.
