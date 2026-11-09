# PNG source images

Run the `images` profile through [the verification runner](../../../../docs/development.md#run-verification). It includes the Asset consumer checks, `tools/verify-images.bend` on the retained corpus, and law controls.

The decoder gate first requires the Bend version in `toolchain.bend` (currently
2.0.40). The standalone source closure needs no Jonlib compiler overlay; see the
[compatibility record](../../../../docs/verification/2026-11-09-jonlib-bend/README.md).
It then checks pinned source and corpus hashes, supported PNG variants and complete pixels against independent expectations, file limits, cache/release/retry, and production mutations. Inspect each nested driver result. A rejection, incomplete comparison, or process failure does not count as an exact image match.

Coverage is CPU source images. Texture upload, sampling, GPU layout transitions and textured rendering are separate. The allocation admission ceiling is not a proved heap-use ceiling. Read [the decoder contract](../../../../docs/image-decoder.md) for accepted variants and trust limits.
