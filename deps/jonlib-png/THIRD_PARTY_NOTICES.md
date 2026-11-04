## stb_image and stb_image_write

`src/bmp.bend`, `src/tga.bend`, `src/pnm.bend`, `src/png.bend`, `src/psd.bend`,
`src/pic.bend`, `src/gif.bend`, `src/gif_lzw.bend`, `src/gif_animation.bend`,
`src/hdr.bend`, `src/jpeg.bend` and `src/jpeg_write.bend` are altered, bounded Bend
adaptations of the BMP/TGA readers and writers, the PNM/PNG/PSD/PIC/GIF/HDR/JPEG readers
and the JPEG writer
in pinned raylib's `src/external/stb_image.h` and `stb_image_write.h`, by Sean
Barrett and contributors. Jonlib selects their MIT alternative, retained in
[LICENSES/stb-image.txt](LICENSES/stb-image.txt). It uses owned arrays and explicit
byte validation, preserves the exercised native pixel/export rules, and rejects
unsupported or truncated inputs. The native headers are used only by reference
tooling; no stb implementation is linked into the Bend candidate.
`src/jpeg_write.bend` adapts `stbi_write_jpg_core` at quality 90 (4:2:0, scaled
quality 20). That function is Jon Olick's public-domain `jo_jpeg`.
The formatted TGA channel-aware writer adapts `stb_image_write.h` lines 532–603
and the raylib `ExportImage`/`LoadImageColors` routing, retaining its row-bounded
RLE scan and component ordering in owned Bend arrays.
The formatted TGA memory adapter preserves the altered reader's checked rules,
adapting `stb_image.h` lines 5739–5753 and 5905–5922 for native output channels.
Indexed output uses palette depth independently of input index width; integer
packing retains native gray/gray-alpha/expanded RGB/RGBA output.
The formatted BMP memory adapter preserves the altered reader's checked rules,
adapting `stb_image.h` lines 5422–5443, 5482–5515, 5584–5591, 5707–5710 and
5728–5730 with raylib `rtextures.c` lines 461–471. Effective alpha-mask layout
retains native RGB/RGBA metadata independently of source bit depth or alpha
repair; integer packing preserves exact component bytes in owned Bend arrays.
The PNM formatted-memory adapter retains the altered `src/pnm.bend` reader's
checked header/byte/size rules and little-endian 16-to-8-bit reduction, adapting
`stb_image.h`'s `stbi__pnm_load` and `stbi__convert_16_to_8` behavior with integer
packing. It preserves native grayscale/RGB888 output rather than source depth.
The PNG formatted-memory adapter retains the altered `src/png.bend` reader's
checked domain, adapting `stb_image.h` lines 5119–5234 and 5284–5286 for native
component metadata, structural tRNS promotion and sticky palette channels across
later PLTE. Lines 1190–1203 and 1260–1273 supply final 16-to-8-bit high-byte
reduction after full-width transparency comparison; lines 4993–4994 and
5222–5223 retain the disabled CgBI conversion defaults. Integer packing exposes
exact grayscale/gray-alpha/RGB/RGBA bytes in owned Bend storage.
`tools/png_format_probe.py` executes the pinned unmodified reader only as an
independent native reference; its admission checks and observation protocol do
not link native PNG code into the Bend implementation.
The PIC formatted-memory adapter retains the altered `src/pic.bend` reader's
checked domain, adapting `stb_image.h` lines 6390–6416 and 6500–6538 with raylib
`rtextures.c` lines 461–471. The union of every validated packet channel mask
retains native RGB/RGBA metadata independently of output opacity or selected
input-sample totals. Integer repacking reuses owned Bend storage. The unmodified
native reader is only a reference; independently admitted complete inputs avoid
its failed-decode null-source conversion path.
The dedicated PIC file adapter reuses that unchanged checked decoder through
the existing bounded Base IO reader. Its file reference tooling additionally
anchors unmodified raylib `rtextures.c` file dispatch and `rcore.c` reads/token
selection; no native code is linked into the Bend implementation.
The upstream Softimage PIC reader credits Tom Seddon.
The upstream GIF reader credits Jean-Marc Lienher, with simplification by stb.
The upstream Radiance RGBE HDR reader credits Nicolas Schulz.

`src/inflate.bend` adapts the canonical DEFLATE decoding rules from the same
stb header to bounded owned output and tail-recursive extraction. Its raw API
also retains the observed empty-stored-block completion rule of raylib's
`DecompressData`. Native sinfl, stb and zlib are reference tooling only.
