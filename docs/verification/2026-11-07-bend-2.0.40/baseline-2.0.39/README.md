# Current geometry under Bend 2.0.39

The original OBJ record uses the older position/RGB vertex format. The current
production format also includes UVs and normals. Its full packed-word baseline
comes from a real Bend 2.0.39 build of `tools/model-obj/native.bend`, using the
current production sources and Clang 23.1.4.

The build and run are retained under
`build/bend-upgrade/baseline-2.0.39`. The executable ran in its own directory
with its own copy of the OBJ corpus record and a separate
`build/model-obj` output directory. Khronos and synchronization validation were
enabled. `runtime.log` records both independently checked source/ECS/offscreen
consumers and zero-object shutdown.

The two packed files compare byte for byte with Bend 2.0.40 output, including
every UV/normal word, index, and range. Both versions' state, RGBA, and D32
outputs also match the original OBJ record. `verify-math` retains those
historical comparisons and reads only the expanded packed format from here.
No original evidence was overwritten or normalized to discard fields.

`revision.txt`, `dependencies.txt`, `source.sha256`, and `source.patch` record
the source baseline. The hashes were captured before changing the math
verifier's retained-file path. That verifier is outside this native consumer's
dependency closure. `compiler.sha256` identifies the original 2.0.39 executable
and Base. `binary.sha256` identifies the retained native executable.
