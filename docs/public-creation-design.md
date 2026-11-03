# Public creation design

A startup description owns values rather than caller-assigned asset IDs.
Compilation produces one set of ECS seeds and one immutable geometry catalog.
This keeps the Core and Render callbacks consistent without another mutable
asset owner.

The selected candidate proposed mesh and material IDs in ECS. The final contract
instead materializes each used mesh/material pair as the existing `MeshRef`.
This preserves the two-column schema, extraction shape, movement routes, and
Bendvy entity identities. Basic material tint is baked into vertex colors once,
so existing shaders display it without a new rendering lifecycle.

Structural equality and first-occurrence order make packing deterministic for a
given description. A repeated pair shares geometry. Different tints of the same
mesh receive separate ranges. The renderers resolve these references without
sorting entities, so draw order and matrix pushes retain their previous meaning.
Empty geometry uses absent buffers and zero-count ranges rather than placeholder
Vulkan handles.

The reusable camera owns the target and lens as well as the orbit. Projection
scale preserves the demonstration's old float arithmetic without approximating
an inverse field of view. Target-zero projection retains the exact old matrix.
The demonstration still owns its tick-one framing. Input reset preserves target
and projection while restoring the original orbit defaults.

The first generated reference remains 7. This small compatibility choice keeps
the existing demonstration, independent pixel oracle, and replay digests
unchanged. It does not expose resource ID allocation to public callers.

The former fixed bootstrap recipe moved to `examples/scene-seeds.bend`.
`Scene.create` now accepts seeds, but its reservation, queue, publication, and
failure ownership remain unchanged. One executable startup compilation supplies
both Core and Render. The separate headless example constructs public values
without importing Vulkan.

The material X11 fixture initially used the offscreen camera's positive Y scale.
The existing window pipeline culls the opposite winding under that projection.
The fixture now uses the window convention's negative Y projection, as the
production orbit camera does. Neither source indices nor renderer culling were
changed to satisfy the check.

Startup creation is the limit of this change. A second interactive application,
runtime resource mutation, persistent GPU scene storage, and new parallelism
remain outside this item. The [reference](public-creation.md) describes the
shipped API, and the [evidence record](verification/2026-11-03-public-creation/README.md)
reports checks against the production implementation.
