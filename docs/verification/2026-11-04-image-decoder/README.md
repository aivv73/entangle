# PNG decoder selection and runtime evidence

The goal is to select one qualified PNG decoder and load its CPU source values through Entangle's existing Asset API. The implementation selects Jonlib's standalone PNG at S41 commit `5e49707e346453f7d36c27d5ca0cb286e431973d`. The alternative is the public `main.bend.decode_png` entry from emerging-ezimg S43, version `1.3.0.0`, hash `0x57618559b9b26dd8415f821176a3e692`.

The base is `181d82b4e4a9e778626ea25d5f085f235214659d`, preserving the preceding internal mesh/material work. The local implementation branch is `feat/image-decoder`. Publication and independent review belong to the parent. This record creates no additional Trail.

## Observed selection result

Every successful result was compared by width, height, exact logical count, and every numerical RGBA word against independent ImageMagick raw output. The comparer converts ezimg's native `0xAARRGGBB` into `0xRRGGBBAA` before comparison.

| Corpus | Jonlib | Ezimg public entry |
| --- | --- | --- |
| 25 images | 25 exact, 0 rejected, 0 terminated | 8 exact, 15 `None`, 2 terminated |
| 20 error/policy probes | 6 exact, 14 rejected | 1 exact, 19 `None` |
| Total 45 inputs per candidate | 31 exact, 14 rejected | 9 exact, 34 `None`, 2 terminated |

The two terminations are June RGB8 at 320 by 260 and Bendvy's Survivors RGB8 screenshot at 800 by 394. Their native statuses were 137, which the installed Process effect encodes as `128 + signal`. The harness sets a 24 GiB address-space limit, 30-second CPU limit, and 45-second wall timeout per candidate invocation. The evidence establishes signal 9, not its cause. No wall timeout occurred in the final run. There is no performance or resident-memory claim.

[`comparison.log`](comparison.log) records all 90 candidate outcomes. `None` remains an opaque rejection. It is never relabeled as CRC, size, or unsupported-format failure without another exposed diagnostic.

## Retained inputs and independent references

[`manifest.txt`](manifest.txt) records all 25 PNG headers as observed by ImageMagick. [`corpus/SHA256SUMS`](corpus/SHA256SUMS) pins every distributed PNG and source JPEG. [`reference-SHA256SUMS`](reference-SHA256SUMS) records the generated raw RGBA references for the 45 inputs. Normal verification uses the retained PNG bytes and regenerates raw references offline.

The original prepared June RGB8, June Adam7, tabby RGB8, and tabby palette4 files were copied byte for byte from the parent's corpus. The additional profile images derive from the same approved cat sources. The other four retained files come from these exact paths.

- `docs/verification/2026-11-03-mesh-playground/initial.png` becomes `mesh-palette4.png`.
- `docs/verification/2026-11-03-public-creation/materials.png` becomes `materials-palette2.png`.
- `build/scene-render.png` becomes `scene-palette1.png`.
- `deps/bendvy/assets/survivors-example.png` becomes `survivors-rgb8.png`.

[`corpus/LICENSE.md`](corpus/LICENSE.md) and [`corpus/sources.txt`](corpus/sources.txt) preserve Keith Kissel's CC BY 2.0 attribution, Alvesgaspar's CC BY-SA 3.0 attribution and derivative license, and capture provenance. The photographic JPEGs are preparation inputs, not engine codecs.

[`tools/image-decoder/corpus.bend`](../../../tools/image-decoder/corpus.bend) contains the profile manifest, ImageMagick commands, and raw-reference extraction. References for 16-bit PNGs use explicit big-endian 16-bit RGBA extraction followed by high-byte selection in Bend. ImageMagick's rounded 8-bit reduction is not used for those references. The tool also checks reference byte counts against the stated dimensions.

The 3 by 2 layout image retains asymmetric RGB values and alpha bytes 0, 1, 127, 128, 254, and 255. Full-image equality exercises row order, word packing, alpha, and capacity-padding removal. Both codecs match this image. Each non-power-of-two photo count also checks that array padding does not escape into source pixels.

[`tools/image-decoder/probes.bend`](../../../tools/image-decoder/probes.bend) emits small real PNG files using stored DEFLATE, PNG CRC, and Adler32. Probes alter checksums, chunk order, signature, profile, sides, expected expansion, filters, input length, and the native CgBI mode. The non-byte probe is an API input property. Its probe file is valid PNG, and both native entry wrappers replace one U32 list element with 256 before decoding. It cannot be represented as a physical byte value.

## Production behavior

[`runtime.log`](runtime.log) records the production adapter rather than the candidate wrappers. All 25 images pass complete-pixel comparison through both `Png.decode` and `Png.load`. The same executable exercises real `Asset.load` calls with a full 320 by 260 cat image.

The first actual load succeeds. The file is then emptied. Repeated request and load retain the same cached pixels and perform no new loader call. After release, the retained full image still matches the reference. A fresh request reads the empty file and caches its failure. Repairing the file leaves that failure unchanged on repeated load. Release, request, and load finally recover. The sidecar records exactly three actual loader invocations.

The file verifier also observes native errors 2, 75, and 21, preserving their messages byte for byte. A sparse 4 GiB file exercises native size overflow. Separately staged real file growth and shrinkage exercise the adapter's exact-read mismatch. Sixty-four repetitions of success, decoder failure, missing file, oversized file, stat overflow, and directory-read paths retain the same descriptor count. Source inspection confirms close-before-decode on successful reads and closure on all recoverable read/stat branches.

The four isolated source mutations reverse Array traversal, rotate packed words, lower the encoded input limit, and lower the maximum side. Each mutated native build succeeds, then the real verifier fails for the expected pixel or boundary reason. The final log contains those four detections. They do not alter the working production sources.

[`assets.log`](assets.log) records the existing Asset verifier. Its four-file source-only closure still compiles and runs without decoder, Creation, or Vulkan imports.

## Formal scope and trust limits

[`proof.log`](proof.log) reports `ALL PROOFS CHECK` from `bend PROOF.bend`. New root laws cover conversion leaf/order rules, tail preservation and count over a reusable structural witness of Array trees, capacity count, the source storage rule, logical padding removal for arbitrary words, exact-read rejection, and all five Codec.Error mappings. The witness exists only for proofs and never enters the production image representation.

This is the Bend frontend result. The whole root was not rerun with `--verdict`. These laws do not prove the PNG parser, inflate implementation, native IO, compiler, ImageMagick, or every malformed-input path. No complete PNG correctness theorem is claimed.

The [PNG reference](../../image-decoder.md) separates the source-derived profile from observed cases. It documents CRC/Adler tolerance, trailing bytes, CgBI's unconverted native values, error categories, inclusive limits, and heap limits. The maximum 16,777,216-pixel output was not allocated. Success is decoding, not integrity verification.

## Reproduce

Run from the repository root with the pinned compiler and dependencies available. [`environment.txt`](environment.txt) records Bend, ImageMagick, Clang, and the native platform used for this run.

```sh
mkdir -p build
bend tools/verify-images.bend -o build/verify-images
./build/verify-images +RTS --threads 1 --gpu off
bend tools/verify-assets.bend -o build/verify-assets
./build/verify-assets +RTS --threads 1 --gpu off
bend PROOF.bend
git diff --check
```

The ordinary image check uses no network and imports no losing codec. It checks source/corpus hashes, regenerates references, runs production image and file properties, runs the four mutation controls, and runs the public example. The main `tools/verify.bend` invokes this check as part of its existing sequence. The broad renderer/UI sequence was not rerun for this importer-only change.

The optional candidate comparison needs the cached ezimg package. The qualifier checks that its version name resolves to the exact required hash, then compiles both public native candidates. Run the ordinary image check first to populate the corpus and probes.

```sh
bend tools/image-decoder/qualify.bend -o build/image-comparison/qualify
./build/image-comparison/qualify +RTS --threads 1 --gpu off
```

To regenerate photo variants from the retained original JPEGs, use the following command. This writes build artifacts and prints their headers. It does not replace the pinned corpus. ImageMagick versions or PNG metadata can change encoded bytes, so review both hashes and pixels before replacing a distributed input.

```sh
bend tools/image-decoder/regenerate.bend
```

## Architecture choices

The parent's selected design keeps source representation in Content and codec/file policy in `src/image-png.bend`. Bend Base already reserves the name `Image`, so the concrete type is `Content.SourceImage`, as in the original design C sketch. No Asset API, cache state, renderer, ECS, shader, texture upload, or registry is added.

Model the Domain shaped the reusable source value. Boundary Discipline kept admission and errors at the PNG boundary. Build the Lever produced the retained corpus, native comparator, verifier, and mutation controls. Prove It Works required exact pixels and real cache/file execution before selection. The design exploration and independent final review belong to the parent. This implementation had one writer and spawned no agents.
