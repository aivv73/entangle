# PNG image source reference

Entangle loads PNG source images through the existing Asset API. The selected decoder is Jonlib's standalone `Png.decode` at commit `5e49707e346453f7d36c27d5ca0cb286e431973d` [S41]. Selection follows native, complete-pixel comparison with `emerging-ezimg@1.3.0.0`, hash `0x57618559b9b26dd8415f821176a3e692` [S43]. The [verification record](verification/2026-11-04-image-decoder/README.md) contains the inputs, results, and reproduction commands.

## Source values and public API

`Content.SourceImage` is `Data` with `width:U32`, `height:U32`, and `pixels:List<&2,U32>`. Its raw constructor follows the existing Content source types. `Content.image_valid` requires positive dimensions and exactly `width * height` words, calculated in `Nat`. It imposes no PNG admission limits.

Bend 2.0.39 reserves `Image` in Base for its quadtree image type. The implementation uses `SourceImage` instead of the synthesis's proposed `Image` name. Content still imports only Base and Components. The existing four-file source-only verifier compiles and runs this closure.

[`src/image-png.bend`](../src/image-png.bend) provides these entry points.

```bend
def decode(+bytes:List<&2,U32>) -> Result<&2,&2,Asset.Error,Content.SourceImage>
def load(path:String) -> IO(Result<&2,&2,Asset.Error,Content.SourceImage>)
```

The [example](../examples/image-assets.bend) calls `Asset.request`, `Asset.load` with `Png.load`, `Asset.lookup`, and `Asset.release`. Asset's generic cache and state machine are unchanged. A retained source image remains usable after cache release. A failed image stays failed until explicit release, request, and load.

## Pixel layout

The origin is the top left. Rows run left to right, followed by the next row. The list has exactly `width * height` numerical `0xRRGGBBAA` words. This is a numerical packing contract, not a host byte-order or upload ABI. Standard PNG alpha is straight. The adapter neither premultiplies nor unpremultiplies RGB; the native CgBI exception is described below.

Grayscale expands to RGB. Missing alpha becomes 255. Packed grayscale expands to the full 8-bit range. Palette entries expand to RGBA, including tRNS. Accepted 16-bit samples reduce to their high byte. Source-derived behavior compares 16-bit transparency keys at full width before reduction.

No gamma, ICC, transfer-function, orientation, or renderer color-management promise is made. Native CgBI handling preserves its decoded component bytes and premultiplied values without conversion. Such input therefore does not establish straight-alpha color meaning. It is a documented native extension tolerance, not a normalized CgBI import path.

The adapter consumes Jonlib's affine Array structurally from left to right, builds reusable list nodes, takes the logical pixel count, and discards capacity padding. It does not repeatedly call `Array.get` or cast an affine list to Data.

## Accepted variants

The source-derived profile covers the following combinations. Runtime observations exercise each listed depth and color family, with the specific interlaced cases named below.

| PNG color type | Jonlib standard profile | Ezimg public PNG entry |
| --- | --- | --- |
| 0, gray | 1, 2, 4, 8, 16 bits | 8 bits |
| 2, RGB | 8, 16 bits | 8 bits |
| 3, palette | 1, 2, 4, 8 bits, including tRNS | 8 bits, including tRNS |
| 4, gray and alpha | 8, 16 bits | 8 bits |
| 6, RGBA | 8, 16 bits | 8 bits |
| Interlace | None and Adam7 | None |

Observed Jonlib output matched every reference word on all 25 retained images. Those include both cat photographs, gray/gray-alpha/RGB/RGBA derivatives, palette+tRNS, packed gray and palette depths, four 16-bit families, RGB and RGBA Adam7, three packed Entangle captures, and Bendvy's RGB screenshot. This is not an exhaustive proof of every combination, filter, or compressed stream.

Ezimg's initial run returned exact pixels on 8 of those images, returned `None` on 15, and exited unsuccessfully with status 137 on June RGB8 and the Survivors screenshot under the harness resource limits. The independent review rerun had 7 exact results, the same 15 rejections, and 3 unsuccessful processes. Tabby RGB8 also returned status 137 on that rerun. Both logs are retained in the verification record. The process outcomes are not stable success rates or decoder rejections. Status 137 is consistent with signal 9, but the Process effect also returns 137 for a normal exit with that code. These logs do not distinguish those causes. No speed or memory comparison is claimed.

## Admission limits

These are Jonlib's unchanged standard profile limits. They apply to `decode` and to decoded file input.

| Quantity | Inclusive bound or rule | Evidence |
| --- | --- | --- |
| Encoded input | 2,097,152 elements, each 0 through 255 | Native exact-boundary success, one-over rejection, and non-byte rejection |
| Width and height | Each 1 through 4096 | Native 4096-wide and 4096-high images accepted, 4097 and zero rejected |
| Output pixels | At most 16,777,216 | Source checks and side-product arithmetic |
| Filtered bytes | At most 67,108,864 | Source gate and native 4096-square RGBA8 header rejection |
| Inflation length | Exactly the expected filtered length | Native short and overrun streams rejected |
| Stored source words | Exactly `width * height` | Full-image observations, source predicate, and conversion laws |

These bounds interact. A 4096 by 4096 RGBA8 image needs 67,112,960 filtered bytes because each row also has a filter byte, so that profile is rejected despite meeting the side and pixel bounds. Adam7 uses the sum of its pass lengths. The nominal maximum RGBA payload is 67,108,864 bytes. Array padding, word storage, list nodes, reference counts, and decoder intermediates require additional memory. Admission limits are not runtime heap guarantees. The full 16,777,216-pixel output was not allocated during verification.

The engine adds no duplicate header parser or arbitrary smaller cap. `decode.wide` is not used.

The candidate limits differ at the decoding boundary. The following ezimg findings come from its pinned `main.bend`, `src/png.bend`, and `src/inflate.bend`, not from maximum-size allocations.

| Quantity | Jonlib standard entry | Ezimg public PNG entry |
| --- | --- | --- |
| Encoded input | 2 MiB, checked before parsing | No explicit total-byte admission cap |
| Dimensions | Each 1 through 4096 | Positive U32 dimensions, with no smaller admission cap |
| Inflated output | Exact header-derived length, at most 64 MiB, enforced during inflation | No emitted-byte budget; the complete inflated list precedes raster validation |
| Final output | At most 16,777,216 RGBA words | No explicit pixel-count admission cap |
| Native packing | `0xRRGGBBAA` Array | `0xAARRGGBB` list |
| Failure value | Typed `Codec.Error` | Opaque `None` |

Ezimg calculates the scanline stride as U32 `width * channels` without an overflow guard. Its nominal dimension field range is not a qualified capacity guarantee. The 4097-side probes contain incomplete rasters, and the 2 MiB probes contain trailing data. Their `None` results therefore do not establish ezimg size limits.

## Errors and file reads

Engine codes use bit 31. The Linux native IO path preserves its original errno code and message. Each decoder variant maps exhaustively to a stable code.

| Code | Meaning | Observed or formal scope |
| --- | --- | --- |
| 2147483649 | `PNG BadHeader` | Invalid signature, unsupported depth, truncated chunks, duplicate IHDR |
| 2147483650 | `PNG BadByte` | A U32 input element above 255 |
| 2147483651 | `PNG BadSize` | Encoded limit, dimensions, filtered-byte limit. File precheck has the same code with a size-specific message |
| 2147483652 | `PNG Truncated` | Exhaustive mapping of Codec.Error. The pinned PNG implementation does not emit this variant |
| 2147483653 | `PNG BadStream` | Short or excessive inflation and invalid filter |
| 2147483654 | Output storage invariant | Adapter rejects a result that fails `Content.image_valid`. No retained PNG triggered it |
| 2147483655 | Exact-read mismatch | Real file growth and shrinkage after stat |
| Native 2, 21, 75 | Missing file, directory read, size overflow | Native code and message compared byte for byte with the adapter |

Error names are decoder categories. `BadHeader` does not identify a unique corruption cause. Ezimg exposes only `None`; its comparison reports do not infer a more specific error.

`load` opens the file, obtains a U32 size, rejects a stat above 2 MiB, reads `size + 1` bytes, closes the handle, and requires exactly the original size before decoding. Read and stat failures also close the handle. Native `File.size` rejects files above `UINT32_MAX` with EOVERFLOW. A sparse 4 GiB file exercised that path. Reading one extra byte detects growth or shrinkage during this staged read. It does not provide a filesystem snapshot. All recoverable failures return `Fail` and can enter Asset's cached Failed state.

## Integrity and malformed input policy

Jonlib ignores PNG CRC and zlib Adler32. Observed CRC-only and Adler-only damage decodes to unchanged pixels. Bytes after IEND are tolerated within the encoded input cap. The exercised CgBI raw-DEFLATE form is accepted without channel conversion or unpremultiplication. Duplicate IHDR, invalid filters, and short or excessive output are rejected. This describes the exercised policy, not a claim that every malformed PNG is rejected. Successful decoding does not verify integrity.

Ezimg checks CRC and Adler32 in its source, rejects the checksum-damage probes with `None`, and rejects the trailing-byte and CgBI probes. Its inflate implementation has no emitted-output cap. IHDR checks alone cannot bound hostile expansion. The comparison runs each candidate in a separate process with 24 GiB address-space and 30-second CPU limits, plus a 45-second wall deadline. The address-space allowance accommodates Bend's large virtual reservations. It is not a claim about resident memory or engine admission.

## Ownership and licenses

Only [`deps/jonlib-png`](../deps/jonlib-png/README.md)'s `png.bend`, `codec.bend`, and `inflate.bend` are vendored. They are unchanged at the exact commit pin and import only each other and Base. SHA-256 pins, Jonathan Peris's zlib license, stb_image's MIT alternative, and the relevant upstream notices are retained alongside them.

The losing codec appears only in comparison tooling, through its public `main.bend` entry. JPEG source comes into that comparison entry's import closure, but no JPEG decoder enters the engine. The [corpus license record](verification/2026-11-04-image-decoder/corpus/LICENSE.md) preserves the cat photographers' attribution, CC licenses, derivative notices, and the captured-image provenance.
