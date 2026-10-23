# Native/browser coordinate audit

This local audit compares actual native and browser renderer coordinate code
using **69 frozen compiled-Lean action fixtures**. All three Float32 coordinates
agree numerically for every fixture: maximum native/browser difference **0**.
Eleven coordinate comparisons differ only in the sign of zero (`+0`/`−0`);
[result.json](result.json) lists them. This is exact numerical Float32 agreement,
not a claim of identical floating-point bit patterns.

The maximum absolute difference from each receipt's rational coordinate is
`1.5258789076710855e-6`; maximum relative difference is
`3.581875370119919e-8`, using `abs(error)/max(1,abs(reference))`. The reference
for these metrics is the exact integer numerator/denominator converted to a
JavaScript Number. These are measured numerical errors, not proved error bounds.

## Reproduce locally

From the repository root on a Mac with Swift and Node installed:

```sh
./artifacts/native-browser-coordinate-audit/scripts/run.sh
```

The wrapper verifies all input/script hashes, compiles the frozen native source
with an explicit temporary module cache, runs its real `mapDisplay` method,
then compares the output with the frozen browser adapter followed by Float32
packing. It also requires the recompiled native output to equal the original
audit output. The wrapper prints the temporary result directory; it neither
updates repository files nor stages or publishes anything, and performs no
network request or cleanup.

The exact underlying commands are in [run.sh](scripts/run.sh). The original
native runner is [main.swift](scripts/main.swift); the browser comparison and
D5 checks are [compare.mjs](scripts/compare.mjs). The successful rerun log is
[reproduction.txt](reproduction.txt). Results are retained in
[result.json](result.json), with the original native coordinates in
[original-native-positions.json](original-native-positions.json).

The recorded toolchain was Apple Swift 6.4 (`swiftlang-6.4.0.34.1`,
`clang-2100.3.34.1`), targeting `arm64-apple-macosx27.0.0`, and Node v26.9.0.

## Frozen inputs and scope

[source-manifest.json](source-manifest.json) records every input/script hash
and original path. The native source snapshot has SHA256
`36959d479d781daed8d0c2975801753a158d0f41dea549bdc9158e874e62b8bf`.
It was recovered read-only from the Git index and matches the original audit's
source recorded in `native/evidence/final-native-receipt.json`. Later native
normal/fade edits are intentionally outside this frozen comparison. No original
source or index entry was changed to prepare this directory.

- [PolynomialAction.swift](inputs/PolynomialAction.swift): actual native action
  validation and coordinate conversion, before the later normal/fade change.
- [Action fixtures](inputs/polynomial-action-cases.json): 69 accepted service
  receipts, including signed forms, integer generators, rational actions,
  bounds and scaled representatives.
- [mobius-render.js](inputs/mobius-render.js): actual browser adapter. The audit
  applies `displayRowsFromReceipt` to base display coordinates and rounds each
  result with `Math.fround`, matching the cloud's Float32 storage.
- [mobius.js](inputs/mobius.js): unchanged canonical module pinned to
  `63ad115422ab1141ca6d06732572385414b7a5cf`, preserving its original attribution.

This is **not visual, UI, device, frame-rate, or new Lean-proof evidence**. It
does not certify projection shaders, RealityKit meshes, subsequent edits, native
free dragging, or the later plane-fade correction. The fixtures are actual Lean
outputs; this audit itself is an ordinary compiled/JavaScript regression check.

## D5 matched calculations

For `M=(3,1,1,2)`, determinant 5, the accepted coefficient matrix is
`[[4,-2,1],[-4,7,-6],[1,-3,9]]/5`. In display basis
`(X,Y,Z)=(-b,a+c,c-a)`, its matrix is:

```text
F = [ 7/5   1    1/5  ]
    [  1   3/2   1/2  ]
    [ 1/5  1/2  11/10 ]
```

| Check | Expected value |
| --- | --- |
| Default `(1,-1,2)` after D5 | `(23/5, 6, 14/5)` in display coordinates |
| Nonlinear radial projection to Y=4 | `(46/15, 4, 28/15)` |
| Upper Origin orientation | `Rx(−π/2): (X,Y,Z) → (X,Z,−Y)`, giving direction proportional to `(23,14,−30)` |
| Unit-pair base Cartesian normal | `(0,0,−2)` |
| Transformed plane normal | `F^−T n = QFQ n = (−2/5,1,−11/5)`, `Q=diag(1,−1,1)`, length `√6` |
| Sample `(1,0,2)` after D5 | `(16/5,5,13/5)`; dot with transformed normal `−2` |
| Sample distance / R6 fade | `2/√6 ≈ 0.816496581`; fade `0.839926765` |

The orientation statement compares the inspected browser camera's inverse
rotation with the native upper-Origin root rotation before each device's view
projection. It does not assert identical camera placement, field of view or
pixels. The fade calculation is the expected correction target: the original
native renderer measured base-coordinate distance instead.

A separate source inspection found native finite cone guides transformed with
the action while the browser and canonical route kept those guides fixed.
That rendering-semantic discrepancy is not tested by this coordinate harness.
