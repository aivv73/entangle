# Asset API

[`src/asset.bend`](../src/asset.bend) caches copyable Bend source data. It imports
only Base and requires no window, Vulkan device, or ECS world.

## Public operations

Import the module as `Asset`. Each operation takes the payload type `A:Data`
as its first argument. The cache is affine and must be passed to the next call.

| Operation | Arguments after `A` | Result |
| --- | --- | --- |
| `new` | `scope:String` | `Cache<A>` |
| `request` | `cache, key:String` | `Cache<A> & Handle<A>` |
| `lookup` | `cache, handle` | `Cache<A> & Maybe<&2,State<A>>` |
| `load` | `cache, handle, loader` | `IO(Cache<A>)` |
| `release` | `cache, handle` | `Cache<A>` |

The loader has type `String -> IO(Result<&2,&2,Asset.Error,A>)`.
`Asset.Error{code:U32,message:String}` preserves loader error information.
Other definitions in the module are implementation helpers.

## Identity and state

`Handle<A>` contains a cache scope and an unbounded natural identity. It is
copyable and typed by its payload. `lookup` returns `None` for a released handle
or a handle from a different scope. Valid entries have one of these states:

| State | Meaning |
| --- | --- |
| `Loading{}` | Requested; the synchronous loader has not run. |
| `Loaded{value:A}` | The loader returned `Done{value}`. |
| `Failed{error:Error}` | The loader returned `Fail{error}`. |

`request` uses exact string equality. A repeated key returns the same handle
without changing its state, including loading and failed entries. Different path
spellings are different keys. Each cache uses one consistent loader policy and
interpretation of its keys; canonicalization belongs to the application.

`load` invokes the supplied loader only for a valid `Loading` entry. Loaded,
failed, released, and foreign-scope handles perform no IO. The cache remains
owned by the call until loading finishes. There are no background jobs, retries,
timeouts, or concurrent completion messages. Loaders return recoverable errors
as `Fail`; calling `IO.die` or exiting prevents the cache from being returned.

## Release rules

`release` evicts the entry in any state and invalidates every copy of its handle.
Repeated release is harmless. Unknown and foreign-scope handles preserve the cache.
Releasing `Loading` prevents its loader from running later. It cannot interrupt a
loader already running synchronously.

After release, requesting the same key allocates a fresh identity. Old handles
remain invalid. Retry consists of release, request, and load. Failures remain
cached until release, even if the underlying file changes.

Handles are weak references: copying or dropping one has no effect on the cache.
Dropping the cache releases all references it holds. Already returned values and
compiled scenes keep their own data. Native buffers remain owned by the renderer
and follow the existing [geometry retirement rules](mesh-replacement.md).

A scope name must be unique across cache lifetimes whose handles can coexist.
Recreating a cache with the same scope restarts its counter and can alias old
handles. Use a fresh scope for a new lifetime. Distinct scopes reject each other's
handles even when their counters and keys coincide. Bend exports constructors;
these guarantees assume caches and handles created and advanced through this API.

## Executable examples

The [procedural source example](../examples/content-assets.bend) loads
`Content.Mesh` and `Content.Material` into separate production caches. It copies
out both values, releases their handles, verifies that lookup returns missing,
and returns the retained sources. Its dependency closure contains only Base,
Asset, Content, and Components. It requires no scene compiler, ECS, or Vulkan.
The public scene example reuses its procedural triangle.

The [mesh and material reference](content.md) defines source validation, exact
identity, tint semantics, and future importer adapter obligations. Asset stays
generic and does not validate payloads or certify renderer admission.

The [file example](../examples/assets.bend) reads a regular file with a 1 MiB
limit, closes its file handle, and prints `Loading`, a byte count or error, then
`Missing` after release. Its loader returns bytes without format decoding.
It rejects short reads and length changes between sizing and reading; it does
not promise a filesystem snapshot during concurrent writes.

```sh
mkdir -p build
bend examples/content-assets.bend -o build/content-assets
./build/content-assets +RTS --threads 1 --gpu off
bend examples/assets.bend -o build/assets
./build/assets README.md +RTS --threads 1 --gpu off
bend examples/asset-scene.bend -o build/asset-scene
./build/asset-scene +RTS --threads 1 --gpu off
```

The [scene example](../examples/asset-scene.bend) caches the existing public scene,
copies it out, releases its handle, compiles the scene, and advances two production
ECS ticks. Its source comes from Bend; it is not a file importer.

The existing `Modules.Assets` startup callback remains `Unit -> Create.Scene`.
This cache is a separate data service. It does not change startup registration,
insert entities, load textures, or assign compiled `MeshRef` values.

## Verification and limits

Formal claims in [LAWS.bend](../LAWS.bend) cover hit and miss transitions,
terminal-state stability, completion preserving keys, eviction, stale-handle
lookup and loading, scope rejection, and preservation of the identity counter.
The root command checks proofs with the Bend frontend, not the BendTT kernel.

```sh
mkdir -p build/verification
bend PROOF.bend
bend tools/verify-assets.bend -o build/verify-assets
./build/verify-assets +RTS --threads 1 --gpu off
```

The runtime driver creates a fresh evidence directory, records real loader calls,
and changes files to check caching and explicit retry. It rejects stale and
wrong-scope handles, preserves an unrelated asset, then runs the scene example.
It also compiles and runs the procedural example from an inventory containing
only its four source files, proving that no Creation or Vulkan dependency is
needed. Exact mesh and material comparison checks retained values after release.
The default [`tools/verify.bend`](../tools/verify.bend) gate includes this driver.

Storage uses a sequential list with linear lookup. Capacity policy, automatic
eviction, reference counting, hot reload, dependency graphs, and performance
claims are outside this API. [The design note](asset-design.md) records alternatives.
