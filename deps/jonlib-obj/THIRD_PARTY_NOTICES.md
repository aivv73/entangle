# Scoped third-party notices

Jonlib is an independent Bend library by Jonathan Peris. Original additions
are licensed under the zlib license retained in `LICENSE`.

## raylib

Ramon Santamaria (@raysan5) and contributors authored raylib. Jonlib pins raylib
6.2 at `02566453880e06bec97f5b8160fa6fe1e98397ca` from
<https://github.com/raysan5/raylib>. The zlib notice is retained verbatim in
`LICENSES/raylib.txt`. `obj.bend` contains the altered Bend adaptation of
`rmodels.c` LoadOBJ mesh assembly. Entangle uses the parser and attribute
construction, without calling that assembly or linking native raylib.

## tinyobj_loader_c

- Author: Syoyo Fujita and many contributors. Source:
  <https://github.com/syoyo/tinyobjloader-c>, as vendored by the pinned raylib
  commit in `src/external/tinyobj_loader_c.h` (with raylib's local changes).
- License: MIT; the notice is retained in
  [LICENSES/tinyobj_loader_c.txt](LICENSES/tinyobj_loader_c.txt).
- `src/obj.bend` is an altered Bend adaptation of its OBJ line splitting,
  `parseLine`, `tryParseDouble` (evaluated with Jonlib's checked binary64
  helpers), `my_atoi`, `fixIndex`, triangulation, the djb2 material hash table,
  the MTL parser (`tinyobj_parse_and_index_mtl_file`, `dynamic_fgets` line
  semantics) and the shape construction, used by `Model.load_for` and
  `Material.load_materials_for`.
