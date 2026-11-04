# Corpus licenses and attribution

The JPEG sources and all PNG derivatives keep their source licenses.

- `june.jpg`, `june-rgb8.png`, `june-adam7.png`, and every `cat-*.png` derive from **June odd-eyed-cat.jpg**, by **Keith Kissel**. They use [CC BY 2.0](https://creativecommons.org/licenses/by/2.0/). [Source page](https://commons.wikimedia.org/wiki/File:June_odd-eyed-cat.jpg). Changes include resizing, metadata removal, grayscale conversion, alpha addition, quantization, bit-depth changes, and interlace changes, as recorded in `tools/image-decoder/corpus.bend`.
- `tabby.jpg`, `tabby-rgb8.png`, and `tabby-palette4.png` derive from **Cat November 2010-1a.jpg**, by **Alvesgaspar**. These derivatives use [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). [Source page](https://commons.wikimedia.org/wiki/File:Cat_November_2010-1a.jpg). Changes include resizing, metadata removal, and palette quantization.
- `mesh-palette4.png`, `materials-palette2.png`, and `scene-palette1.png` are unmodified Entangle runtime captures. Their original paths are recorded in the verification README.
- `survivors-rgb8.png` is an unmodified copy of `deps/bendvy/assets/survivors-example.png`, from Bendvy contributors. Bendvy offers MIT or Apache-2.0, with third-party assets retaining their respective licenses. This record selects its MIT license, retained in `bendvy-LICENSE-MIT.txt`. The image illustrates [the Survivors example](https://github.com/dearlordylord/bendvy-ecs-examples). No separate image attribution was present in the pinned dependency's README or asset directory.
- `layout.png`, `width4096.png`, and `height4096.png` are generated numeric verification images under Entangle's license.

The cat photographs are verification inputs. They are not engine runtime dependencies. `sources.txt` retains the download URLs and original attribution record. `SHA256SUMS` pins the exact distributed JPEG and PNG bytes.
