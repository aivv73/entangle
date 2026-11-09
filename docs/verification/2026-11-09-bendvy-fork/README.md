# Use the aivv73 Bendvy fork

Historical source URL change, completed before the subsequent
[migration to the fork's current ECS](../2026-11-09-ecs-migration/README.md).
The migration record describes the current dependency revision.

## Acceptance and required evidence

Change `deps/bendvy` in `.gitmodules` to
`https://github.com/aivv73/bendvy.git`, and synchronize the existing checkout.
Retain the validated revision `16405fbeb75cd6da1eb8c79ea48d3532ee9a30ee`
in both the Git submodule and `toolchain.bend`. This is a source URL change;
the fork's current `master` has a different ECS API and is not selected.

Require a fresh dependency checkout fetched from the fork at that exact pin,
matching source trees, and a clean existing dependency checkout. Git submodule
configuration enforces the source URL; `tools/verify.bend:preflight` enforces
the revision through `toolchain.bend:dependencies`.

Build `tools/verify-workflow.bend`, select the `toolchain` profile, and retain
its source-specific receipt, including any environment precondition failure.
Also rebuild and execute the existing native headless scene verification to
check the production ECS ticks and batching behavior. No production verifier
or engine behavior changes, so no new laws or sensitivity controls are needed.
These checks do not qualify the fork's latest ECS API or repeat rendering,
window, or formal verification.

## Results

The [source checkout receipt](../../../build/verification/bendvy-fork-jYirtthW/source-check.log)
records a fresh repository initialized with the fork as `origin`, fetching
and checking out `16405fbeb75cd6da1eb8c79ea48d3532ee9a30ee` directly from it.
Its tree matches the existing dependency, both checkouts are clean, and the
parent submodule URL and existing dependency's `origin` both point to the fork
after `git submodule sync -- deps/bendvy`.

The rebuilt [native headless verifier](../../../build/verification/bendvy-fork-jYirtthW/headless.log)
passes all nine splits of eight production ticks. It checks zero-step behavior,
ownership, receipt identities, exact transform bits, and detached retention.
Commands, after activating the prepared toolchain:

```sh
bend tools/verify-headless-scene.bend -o build/verification/bendvy-fork-jYirtthW/verify-headless-scene
./build/verification/bendvy-fork-jYirtthW/verify-headless-scene +RTS --threads 1 --gpu off
```

The required `toolchain` [workflow receipt](../../../build/verification/workflow-FFiVx5W6/manifest.tsv)
has `state=failed`, `run.status=1`, and `toolchain.status=1`. The
[diagnostic](../../../build/verification/workflow-FFiVx5W6/toolchain.stderr)
reports the environment's pre-existing Clang distribution mismatch: installed
Clang 23.1.4 includes its upstream Git revision on the version line, while the
gate requires the bare `clang version 23.1.4` line. The installed target is
also `x86_64-unknown-linux-gnu`, rather than pinned `x86_64-pc-linux-gnu`.
The gate stops at the version check; it is not a pass. No compiler pins or
preflight checks were changed for this dependency URL update.

## State

Acceptance was recorded before implementation on November 9, 2026. The source
URL change, checkout verification, and native headless verification are complete
locally. The toolchain gate remains blocked by the existing environment
mismatch. The dependency commit and production sources are unchanged; the
workflow snapshot contains the changed URL and the acceptance record before
these result paragraphs were added. No publication or merge is claimed.
