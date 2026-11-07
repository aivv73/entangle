# Verify accepted geometry publication

Run from the repository root with the toolchain in `toolchain.bend`:

```bash
mkdir -p build
bend tools/verify-publication.bend -o build/verify-publication
./build/verify-publication --mutations +RTS --threads 1 --gpu off
```

The workflow runner includes this check in every profile that selects the
Bend laws. Require a baseline pass, all ten named mutation rejections, and
a restored pass. Retain the printed `build/verification/publication-*` path.

## Production correspondence

`src/scene-geometry.bend:sealed` calls `published` immediately after successful
buffer retirement. The publication keeps the candidate buffers, ranges, and
active material bindings. It also retains the previous active materials,
previous retirement queue, and candidate retirement queue for later cleanup.

The runner extracts complete declarations from current production sources:

| Generated module | Production declarations |
| --- | --- |
| `native.bend` | The ten Vulkan handle types, `VkResult`, and `Entry.finish`. |
| `buffer.bend` | `src/scene-buffer.bend:Buffer`. |
| `texture.bend` | `src/scene-texture.bend:Resource`, `Material`, `Release`, and `releasing`. |
| `materials.bend` | `src/scene-materials.bend:Binding`, `Resident`, `ownership`, `retire`, `collected`, `collected_resident`, and `disposed`. |
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
to `LAWS.bend` and `PROOF.bend` beside freshly extracted modules, appending the
word-pattern proof emitted by `error-proof.bend`. U32 literal patterns lower to
structural bit matches; the generator covers the 32 possible first differing
bits and eliminates the one excluded word. This is universal U32 coverage,
not an enumeration of selected error codes. Run the driver, because an archived generated proof describes its
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

Five cleanup claims preserve the remaining queue after a released resource,
retain the entire pending resource suffix on deferred or failed cleanup, preserve
active bindings, and report deferred disposal. The non-deferred error theorem
covers every U32 except the separately checked lifetime-deferred code. These
claims describe the pure cleanup decisions; actual resource destruction and
recursive effect execution require the bounded native and real Vulkan checks.
Two additional claims check `releasing` directly: a failed destruction retains
the failed resource and full suffix, and successful destruction continues the
remaining cleanup action. The IO-valued claims compare the actual pure control
definitions; they do not dispatch foreign effects.

The claims have no finite list bound or handle-validity premise. The verdict
is a Bend frontend proof check. It is not a BendTT kernel verdict, a proof
that retirement succeeded, or a theorem about Vulkan lifetime, native handle
decoding, driver results, IO cleanup, or the call from `sealed` itself.
The maintenance audit must inspect that call and the entry paths that reach
it. Real renderer and resource drivers establish their observed behavior.

The ten controls drop candidate buffers, discard prior material retirement,
omit binding ownership, discard successful/deferred/failed queue state, drop
active bindings, hide pending disposal, forget a failed resource, and skip the
remaining cleanup action. Each must exit one with `SOME PROOFS FAIL` and
the assertion named by `mutations.tsv`. A parse error, extraction rejection,
timeout, or foreign-effect rejection does not establish sensitivity.
