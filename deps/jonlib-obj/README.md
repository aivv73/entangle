# Jonlib standalone OBJ closure

The eight Bend files are byte-identical copies of `src/` at Jonlib S41 commit
`5e49707e346453f7d36c27d5ca0cb286e431973d`. Upstream is
<https://github.com/jonathanperis/jonlib/tree/5e49707e346453f7d36c27d5ca0cb286e431973d>.
`SHA256SUMS` pins every source and retained license/notice. There are no local
changes to upstream source or headers.

`obj.bend` imports `binary64_fma`, `binary64_add_sub`, `binary64_ops`, and
`binary64_narrow`. Their transitive closure adds `resize_numeric`, `float64`,
and `float64_ops`. Those eight modules close on Base. No umbrella, foreign
raylib runtime, overlay effects, LGPL math module, codec, or other dependency
is included. Existing native dependencies and pins are unchanged.

Original Jonlib code is copyright 2026 Jonathan Peris under the zlib license in
`LICENSE`. OBJ parsing adapts tinyobj_loader_c under its MIT license in
`LICENSES/tinyobj_loader_c.txt`. The file also contains raylib mesh assembly
under the zlib license in `LICENSES/raylib.txt`. Entangle never calls that
assembly. `THIRD_PARTY_NOTICES.md` preserves the scoped attribution and upstream
pin. The engine adapter has a deliberately stricter supported profile in
[the OBJ reference](../../docs/model-obj.md).
