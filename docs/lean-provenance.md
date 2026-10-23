# Lean implementation and proof boundary

The application executes Lean code from the local Grassmann project. It does not substitute a JavaScript determinant for that computation.

## Source

- Original checkout: Alok's Grassmann Lean repository, clean when inspected.
- Pinned commit: `87e12dcfac41a0703bd0192f5e5a9b5e4c82d610`.
- Toolchain: `leanprover/lean4:v4.35.0-rc3`.
- License: AGPL-3.0-or-later; original license is retained at `lean/vendor/LICENSE`.
- `lean/vendor/PROVENANCE.json` lists the 110 copied Lean modules in dependency order and records each file's SHA-256 digest. Every copied source is unchanged.
- No original checkout files or global toolchain files are modified. The build uses the already installed toolchain, no external Lake packages, and a cache inside `lean/.cache`.

The core reusable modules are:

| Module | Reused behavior |
| --- | --- |
| `Grassmann/Kernel/Generated/R3.lean` | Generated Euclidean 3-space kernels |
| `Grassmann/Kernel/R3WedgeLaws.lean` | Generated wedge equals ordered coordinate formula and the reference loop; self-wedge vanishes under explicit scalar laws |
| `Grassmann/Kernel/R3TopWedgeLaws.lean` | Generated grade-2/grade-1 wedge equals the top-coordinate formula and reference loop |
| `Grassmann/Examples/OrientedVolume.lean` | Executable `((a ∧ b) ∧ c)`, exact e123 coefficient, formula/reference theorems, integer repeated-first-vector cancellation |

`Exact/Kernel.lean` freezes the same generated provider used by the upstream theorems. Its `wedge` calls actual `TA.wedgeF`; its `volume` calls the upstream `OrientedVolume.coefficient`. The service observes the resulting blade coefficients at masks 3, 5, 6 and 7.

## Coordinates and schema

Each request is one line of JSON with an `id` and three integer arrays of length three, `a`, `b`, `c`. Every coordinate must lie in [-12,12]. An integer is one quarter of a world unit. Input vectors therefore range from -3 to 3 world units per axis.

The success response echoes the inputs and `id`, has `ok:true`, and supplies:

- `scale:4`
- `wedge`, `swappedWedge`, `selfWedge`: integer coefficients in `[e12,e13,e23]`, divided by 16 for world area units.
- `volume`, `swappedVolume`, `repeatedVolume`: integer e123 coefficients, divided by 64 for world volume units.
- `vertices`: eight integer triples in order `[0,a,b,c,a+b,a+c,b+c,a+b+c]`.
- `checks`: runtime equalities for antisymmetry, self-zero, swapped-volume sign, and repeated-volume zero.
- `engine` and `sourceCommit`.

Errors have `ok:false`, an echoed id when it was parseable, and an `error` string. Lean uses unbounded `Int`; this bound also keeps all outputs comfortably within JavaScript's exact-integer range.

## What the proofs cover

Upstream formula/refinement theorems connect the concrete generated provider with its mathematical coordinate expressions. Upstream `integer_selfFirst` proves that the exact triple coefficient is zero when its first two vectors are equal. The separate `Exact/Proofs.lean` file proves nine additional integer statements, including generated-wedge antisymmetry and direct service-wrapper laws:

- `service_volume_swap`: swapping the first two vectors negates the volume.
- `service_volume_self`: repeating the first vector gives zero volume.
- `service_wedge_self`: the service's actual generated self-wedge is a stored zero bivector.
- `service_volume_add_dependent`: choosing the third vector to be the exact sum of the first two gives zero volume.

These theorems hold for arbitrary integer inputs. The last theorem requires the exact sum; clamping its coordinates would change that premise. This audit does not claim a general theorem characterizing every linearly dependent triple.

These statements concern exact integer operations and the explicit generated provider. They do not prove the browser renderer, mesh geometry, JSON transport, hand/controller input, coordinate quantization, native Swift code, or compiler/runtime correctness. Mesh coordinates and camera operations use approximate floating-point values.

The imported source contains `implemented_by` caches, generated-code machinery and some `unsafe` implementation helpers. Those are not custom logical axioms, but a theorem about logical definitions alone does not certify every native implementation detail. The app executes the frozen generated kernels; integration tests compare their actual JSON output with an independently written integer oracle. Axiom reports and runtime tests are recorded separately so neither is presented as the other.

## Local verification

Run `python3 lean/build.py` to compile each module and object sequentially with two Lean worker threads, then link the service. The script passes `--no-cache` to prohibit downloading package build caches, keeps artifact storage inside the workspace, and requests a warning-free build. This intentionally limits concurrency for Mac responsiveness.

Run `python3 lean/test_service.py` to test actual executable output against independent integer wedge and determinant calculations, including malformed inputs and degenerate geometry. Evidence is written under `lean/evidence/`.

Recorded result: the complete build passed with zero warnings. All 11 audited declarations use only `propext`, `Classical.choice`, and/or `Quot.sound`, with no `sorryAx` or custom axioms. The compiled executable passed 255 valid cases and eight malformed/out-of-range cases. The unit-world-cube request `[4,0,0]`, `[0,4,0]`, `[0,0,4]` returned wedge `[16,0,0]` and signed volume `64`, corresponding to area 1 and volume 1 after scaling. See `build-result.json`, `axiom-audit.txt`, `service-tests.json`, `unit-cube-response.json`, and `source-verification.json` in that evidence directory.

Other inspected repositories were not used: SciLean's Float3 cross product brings a broader mathlib/BLAS stack and nearby admitted proof obligations; GeometricLean has an older nightly toolchain and several external dependencies. Grassmann provides the smallest existing exact computation/proof path for this demo.
