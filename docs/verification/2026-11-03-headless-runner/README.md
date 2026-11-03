# Headless runner verification

Design C keeps one generic `advance` operation over the caller's affine state.
Explicit `Scene.create` avoids hiding a startup tick. A's startup facade was
omitted. No production scene, scheduler, or window implementation changed.

The runner imports only Base. The verification record owns no second world.
The unchanged observed reference supplies the numerical and identity oracles.
The CPU gate owns the reference's expected stdout so the full graphics verifier
can reuse it without pulling graphics into the CPU command.

## Commands and results

Run from the repository root.

```sh
bend PROOF.bend
bend tools/verify-headless.bend
bend tools/verify-headless-isolated.bend > docs/verification/2026-11-03-headless-runner/isolated.log 2>&1
bend tools/verify.bend
git diff --check
```

`bend PROOF.bend` exited 0 and reported `ALL PROOFS CHECK` in
[proof.log](proof.log). This is the standard checker result, not `--verdict`.
`bend tools/verify-headless.bend` exited 0 in [cpu.log](cpu.log).
It executed the direct production specialization, unchanged observed reference,
and all nine split replays. Each replay validated 100 entities through eight
real production ticks, including zero before and after bootstrap.
`bend tools/verify.bend` exited 0 in [full.log](full.log).
Its existing Vulkan compatibility and both renderer index orders passed,
including exact color, depth, repeat, replay, and zero-live-object cleanup.
`git diff --check` exited 0.

The fresh isolation command exited 0 in [isolated.log](isolated.log).
It rebuilt and executed all three CPU programs inside the restricted root.

## Isolation

[`tools/verify-headless-isolated.bend`](../../../tools/verify-headless-isolated.bend)
uses Base IO and the installed Bubblewrap.
Unshare, Docker, and Clang are installed. No new container manager is needed.
The Bend tool copies files into a new temporary root without modifying the host root.
It derives standard C headers with Clang's dependency output under the same
`-std=c11 -O2` flags as the gate. It supplies only the selected project CPU
sources, Bendvy source, the pinned Bend and Clang binaries, linker, standard CPU
libraries, C startup objects, and required Base CPU effects.

The Bubblewrap command uses `--unshare-all`. Network, IPC, PID, and UTS
isolation are required by that option. User and cgroup isolation follow
Bubblewrap's supported-namespace policy and are not separate acceptance claims.
The root is read-only. Only a fresh build directory, temporary files, and the
minimal device filesystem are writable. No host root or sysfs is mounted.
The cleared environment has no display variables or display sockets.
The root has no Vulkan checkout, graphics headers, loader, ICDs, GPU devices,
CUDA SDK, or Metal SDK. The compiler itself resolves imports against these
available sources. There is no custom lexical import scanner.

`isolated-files.txt` lists every staged file, including the supplied Bendvy
source superset. It is a filesystem manifest, not an exact transitive import
list. Successful checking with unavailable graphics sources establishes that
the executed entry points do not require those imports on this pinned compiler.
`toolchain.sha256` identifies the copied binaries. The Bend tool records the Bendvy
revision. It does not download dependencies or use the network.

This is a fresh build and execution on the host Linux kernel and CPU through
filesystem and namespace isolation. It is not a VM, a different CPU platform,
or evidence about future compiler versions. Base still declares unused graphics
effects. No graphics effect implementations are supplied to the isolated root.
No performance claim is made.

The isolation orchestration is Bend to follow the project's language rule.
It reuses the CPU gate's process and failure helpers. Standard utilities discover
ELF dependencies and C headers and copy files. Bend parses their output and
traverses the staged file lists. No embedded shell program runs the orchestration.
The host-side tool is not supplied to the isolated root. The supplied CPU gate
and scene verifier remain listed in `isolated-files.txt`.
