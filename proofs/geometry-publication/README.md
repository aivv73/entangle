# Verify accepted geometry publication

Run from the repository root with the toolchain in `toolchain.bend`:

```bash
mkdir -p build
bend tools/verify-publication.bend -o build/verify-publication
./build/verify-publication --mutations +RTS --threads 1 --gpu off
```

The workflow runner includes this check in every profile that selects the
Bend laws. Require a baseline pass, all three named mutation rejections, and
a restored pass. Retain the printed `build/verification/publication-*` path.

## Production correspondence

`src/scene-geometry.bend:sealed` calls `published` immediately after successful
buffer retirement. The publication keeps the candidate buffers, ranges, and
active material bindings. It also retains the previous active materials,
previous retirement queue, and candidate retirement queue for later cleanup.

The runner extracts complete declarations from current production sources:

| Generated module | Production declarations |
| --- | --- |
| `native.bend` | The ten Vulkan handle types used by buffers and textures. |
| `buffer.bend` | `src/scene-buffer.bend:Buffer`. |
| `texture.bend` | `src/scene-texture.bend:Resource` and `Material`. |
| `materials.bend` | `src/scene-materials.bend:Binding`, `Resident`, `ownership`, and `retire`. |
| `production.bend` | `src/scene-geometry.bend:Buffers`, `Resident`, and `published`. |

Only module imports change. Type fields, constructors, and function bodies
are copied verbatim. Handle keys retain their production `U32` type, and
buffer capacities retain the pinned production `U64` type. There is no
symbolic driver, mock, alternative transition, or handle projection.
Missing or duplicate declaration markers fail extraction.
The existing source reader requires ASCII files below 1 MiB. Each proof
command has a five-minute execution limit. Exceeding either limit fails the
run and does not produce a passing receipt.

The `.bend.in` files contain the claims and proof terms. Each run copies them
to `LAWS.bend` and `PROOF.bend` beside freshly extracted modules in its evidence
directory. Run the driver, because an archived generated proof describes its
archived sources. The runner retains source hashes, generated
modules, verdicts, and separately generated mutation copies.

Directly importing the original effect modules into root `PROOF.bend` fails
Bend's foreign-effect proof-safety check. This extraction keeps that check
enabled and verifies the same pure definitions without importing effects.

## Claims and limits

`geometry_install_accept` covers arbitrary buffers, ranges, material lists,
and retirement lists. It checks the complete published value, including the
three retirement-list contributions. `material_ownership_cons` checks that
each binding contributes its complete owned resource list in order.

The claims have no finite list bound or handle-validity premise. The verdict
is a Bend frontend proof check. It is not a BendTT kernel verdict, a proof
that retirement succeeded, or a theorem about Vulkan lifetime, native handle
decoding, driver results, IO cleanup, or the call from `sealed` itself.
The maintenance audit must inspect that call and the entry paths that reach
it. Real renderer and resource drivers establish their observed behavior.

The three controls drop candidate buffers, discard prior material retirement,
and omit a binding's ownership. Each must exit one with `SOME PROOFS FAIL` and
the assertion named by `mutations.tsv`. A parse error, extraction rejection,
timeout, or foreign-effect rejection does not establish sensitivity.
