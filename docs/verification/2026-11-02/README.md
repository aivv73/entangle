# Native dependency baseline

The selected Bend compiler is the already installed and previously validated
2.0.39 release. Clang 23.1.4 targets `x86_64-pc-linux-gnu` on this machine.
No compiler upgrade is part of this change.

The direct dependencies are Git submodules:

- Bendvy `16405fbeb75cd6da1eb8c79ea48d3532ee9a30ee`, fetched from
  <https://github.com/dearlordylord/bendvy.git>.
- bend-vulkan `a144f7dd4fb4835ca3d5ce17350fc850de049038`, fetched from
  <entire://aws-eu-central-1.entire.io/et/bend-engine/bend-vulkan>.
- bend-collections `bc78c4f4cabb536a2a1dd6e308b6a8f0afafda7c`, retained at
  bend-vulkan's own gitlink. No other nested submodule is needed.

Bendvy's scheduled-health README records prior native validation on stock
Bend 2.0.37. Entangle validates that consumer on 2.0.39 together with Vulkan,
whose native effect ABI requires 2.0.39. Dependency sources are unmodified.
The combined program calls the upstream ordinary examples rather than
substituting an ECS or Vulkan implementation.

The installed compiler binary, Base definitions, and guide have SHA-256
fingerprints in `environment.log`. They document the installation inspected
here. Version checks are enforced by `tools/verify.bend`; this is not a
hermetic compiler distribution or a claim of bit-identical builds on another
machine. The installed compiler has no Git metadata, so no compiler source
commit is inferred from its version.

The compatibility gate exercises deferred command publication, a registered
schedule, component updates, an excluded entity, real GPU buffer transfer,
and Vulkan resource cleanup. It does not establish renderer integration,
window behavior, sanitizer coverage, or performance.

## Results

`bend tools/verify.bend` exited with status 0 on November 2, 2026.
[The native log](native.log) records the three revision checks, proof success,
complete scheduled-health output, successful host and GPU readback, and zero
live Vulkan objects. [The environment log](environment.log) records the
compiler versions, fingerprints, GPU, and driver. [result.json](result.json)
records the commands and scope in machine-readable form.

The check uses one Bend CPU thread with Bend GPU dispatch disabled. The
Vulkan buffer fill still executes on the NVIDIA GeForce GTX 1660 through
Vulkan. This hardware observation does not impose an NVIDIA requirement on
the example or engine.

The final dependency checkouts are clean. No traditional unit or mock tests
were added. `PROOF.bend` imports the existing upstream Vulkan laws and Bendvy
execution-plan laws; it does not introduce a formal claim about the foreign
ABI. No window verifier, full upstream suite, sanitizer, benchmark, or
Khronos validation-layer run was performed for this pinning change.
