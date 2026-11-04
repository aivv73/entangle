# Asset cache design

Source assets need identity, load state, and release rules before E4 introduces
file formats. `creation.bend` already consumes copyable scene data, while the
renderers own native allocations. The cache belongs before scene compilation.

## Caller's view

Create a typed cache with a unique scope name. `request` returns a handle and
reserves `Loading` on a miss. `load` runs a caller-supplied synchronous loader,
and `lookup` returns `Loaded` or `Failed`. A second request shares the entry.
After copying a ready value into a scene, `release` evicts its source entry.
The compiled scene retains its data. See [the API reference](assets.md) and
[the executable example](../examples/assets.bend).

## Shape

`src/asset.bend` imports only Base. An affine `Cache<A>` owns a list of entries,
a scope name, and an unbounded monotonic identity counter. A copyable `Handle<A>`
contains the scope and identity. Exact string keys identify requests within one
cache. The payload type is part of both the cache and handle types.

The five public operations are `new`, `request`, `lookup`, `load`, and `release`.
They hide deduplication, state transitions, and stale-handle rejection. Loading
holds the cache until the loader returns, so release cannot race completion.
There is no asynchronous completion API or second writer.

## Synthesis decision

Three candidates compared weak handles with explicit eviction, affine leases
with ticket-counted ownership, and weak handles with external completion tickets.
The synchronous weak-handle design became the base. Observable `Loading` through
separate request and load operations comes from the lease candidate. Explicit
scope names come from the third candidate, removing the base's extra registry.

On API size, identity/release correctness, state semantics, Bend compatibility,
and verification feasibility, weak handles give the smallest adequate surface.
Leases prevent ordinary copying but still require explicit release in affine
Bend, and add ticket accounting to every consumer. External completion tickets
add a cancellation protocol that synchronous loading does not need. A registry
still needs its own unique namespace, so it does not remove the scope obligation.
All configured judges belong to the same model family; cross-family judging was
skipped. The coordinator compared all three designs against those five criteria.

## Accepted limits

- Release invalidates all handle copies. Handles observe entries; they do not own them.
- Scope names must be unique across cache lifetimes whose handles can coexist.
  Pure construction cannot mint globally unique identities. Constructors are
  public in Bend; the contract applies to caches advanced through the API.
- List lookup is linear. This small initial cache has no secondary index to maintain.
- Synchronous loaders must return failures as values. A loader that exits cannot
  return the cache. Loading has no background scheduling or timeout policy.
- Cached payloads are `Data`. Native resources retain their renderer-owned lifetime.

The implementation passes the root proof check, including 16 new asset laws,
real filesystem loading with recorded invocation counts, and two production ECS
ticks after scene-source release. Three deliberate Asset regressions are rejected
by their expected laws. A cross-payload handle also fails Bend's type checker.
