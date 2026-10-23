# Native render-plan CPU benchmark

This bounded local benchmark calls the current `PolynomialRenderPlan.make` with fresh executable-Lean catalogues and the current native transport validators. It measures only the CPU preparation function, compiled explicitly with **`-Onone`**, in a standalone arm64 macOS process. It does not measure RealityKit, GPU submission, collision generation, UI latency, frame rate, or headset performance.

The corrected baseline compiled successfully in 2.398 seconds and its single serial benchmark process completed in 1.967 seconds, including decoding, validation, summaries and file output. Each of the 12 configurations has one excluded warmup and three measured calls. The table shows the measured calls only; individual samples and warmups are preserved in [results.json](results.json).

| Catalogue | Progress | Buffered | Batches | Instances | Positive bodies | Mean ms | Min ms | Max ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Identity, depth 16 | 0 | 4,406 | 254 | 2,239 | 450 | 16.439 | 16.024 | 17.192 |
| Identity, depth 16 | 0.5 | 4,406 | 254 | 2,239 | 2,239 | 15.841 | 15.655 | 16.038 |
| Identity, depth 16 | 1 | 4,406 | 254 | 2,239 | 1,973 | 16.089 | 15.691 | 16.353 |
| Released matrix, depth 16 | 0 | 4,205 | 468 | 2,417 | 458 | 15.815 | 15.450 | 16.349 |
| Released matrix, depth 16 | 0.5 | 4,205 | 468 | 2,417 | 2,417 | 15.455 | 15.101 | 15.730 |
| Released matrix, depth 16 | 1 | 4,205 | 468 | 2,417 | 2,130 | 15.550 | 15.235 | 15.734 |
| Identity, depth 24 | 0 | 14,966 | 427 | 8,387 | 2,070 | 54.106 | 53.816 | 54.500 |
| Identity, depth 24 | 0.5 | 14,966 | 427 | 8,387 | 8,387 | 54.007 | 53.379 | 55.172 |
| Identity, depth 24 | 1 | 14,966 | 427 | 8,387 | 7,437 | 54.545 | 54.231 | 54.852 |
| Released matrix, depth 24 **incomplete** | 0 | 12,176 | 676 | 6,982 | 263 | 44.134 | 43.159 | 44.759 |
| Released matrix, depth 24 **incomplete** | 0.5 | 12,176 | 676 | 6,982 | 6,982 | 44.555 | 44.159 | 45.157 |
| Released matrix, depth 24 **incomplete** | 1 | 12,176 | 676 | 6,982 | 5,907 | 45.011 | 44.529 | 45.646 |

“Positive bodies” means glyph opacity greater than zero; it is not a count of screen pixels or perceptually visible objects. Instances include retained zero-alpha material batches for stable morph buffers. The results also report positive-material instances, primitive upper positive bodies and a consumed glyph checksum. Counts and checksum agreed across warmup and all three measurements for every configuration.

## Input scope and completeness

The released matrix is exactly `[16491, 8977, 16312, 14943]`, from `ui.releasedMatrix` in [the native acceptance receipt](../../native/evidence/preview-recurrence-native-receipt.json), run `20261023T120502Z`. Its receipt hash is recorded with the captured input. The benchmark does not rerun that UI acceptance.

| Catalogue | Upper block | Other signed block | Complete | Other scan bound | Limited by other scan bound |
|---|---:|---:|---|---:|---|
| Identity, depth 16 | 3,725 | 681 | true | 10 | false |
| Released, depth 16 | 3,529 | 676 | true | 51 | false |
| Identity, depth 24 | 11,842 | 3,124 | true | 16 | false |
| Released, depth 24 | 12,176 | **0** | **false** | **85** | **true** |

The transformed depth-24 catalogue contains only the upper block because the unchanged Source catalogue guard skips the other block when the required scan bound exceeds 64. It has `complete=false`, `sourceLimited.otherScanBound=true`, `otherScanBound=85`, and `sourceLimited.upperCap=false`. Its timing is **not a like-for-like full signed catalogue comparison** with identity depth 24. No skipped identities were synthesized or added locally.

One unchanged Lean service process handled nine sequential requests: one exact pair, and all catalogue pages plus membership for each of four datasets. Each catalogue happened to fit in one page; pagination and terminal offsets were checked. The native `PolynomialCataloguePage`, `PolynomialCatalogueMetadata`, `PolynomialCatalogueMembers`, and `PolynomialPlane` checks accepted the captured responses. Page ordering and complete accumulation were also checked outside timing. Membership validation checks received entries against accepted points; it does not independently prove that the service omitted none.

## Exact benchmark settings and timing boundary

- Selected polynomial `[1,0,1]`, paired polynomial `[1,1,1]`; accepted pair normal `[1,0,-1]`.
- Source mode; Whole true, Dust false; Overview (`origin=false`, `eye=0`); star size and sigma 1; screen enabled with height fraction 0.6; dark theme; lower coloring false; palette `viridis`.
- `sourceMorph.hasPlane=true`. Incidence is computed from accepted signed base identities using the actual native helper. Accepted membership indices set the necklace flags. Display rows are the exact accepted integer coefficient rows divided by their denominator, converted to Double.
- `planeFocus=false`, `normal=nil`, `keep=[1,0,1]`, matching the current model's default focus setting and the existing unit/pair fixture. `projection=true` is held constant for all three progress values; SourceMorph handles the body interpolation and the separate radial output remains empty. This constant flag is explicit rather than a claim about the P0 toggle state.
- Only the `PolynomialRenderPlan.make(...)` invocation lies between the two `DispatchTime.now().uptimeNanoseconds` readings. Input decoding, membership/incidence setup, settings construction, summaries, checksum consumption, output and teardown lie outside this interval.
- A verbatim data-declaration prefix of `PolynomialModel.swift` is compiled before `enum PolynomialCatalogueMode:` to avoid compiling the unrelated Observable app model. All appearance, action, catalogue, Source morph and render-plan functions come directly from the unchanged current native source files.

The project Debug setting explicitly uses `SWIFT_OPTIMIZATION_LEVEL=-Onone` at [project.pbxproj:668](../../native/ExteriorRoom.xcodeproj/project.pbxproj#L668). The benchmark sets that same optimization level explicitly, but runs against the macOS SDK as a standalone program; it is not the visionOS app build. Source hashes, compiler version, exact commands, input hash and compiled binary hash are in [execution.json](execution.json). Source files and the Lean service hash were unchanged after execution. Peak RSS was not collected.

## Receipt and reproduction

Run from the repository root, with the already built `lean/.lake/build/bin/polynomial_service` present:

```sh
python3 artifacts/native-render-plan-benchmark/export-lean.py
python3 artifacts/native-render-plan-benchmark/run-benchmark.py
```

These commands overwrite this diagnostic's generated input/results. The standalone binary is `/tmp/exteriorroom-render-plan-benchmark`; the reused compiler module cache is `/tmp/exteriorroom-native-plan-module-cache`. No product source, canonical checkout, UI or GPU is changed or exercised.

- [Fresh Lean input and complete raw metadata](lean-input.json), [requests](lean-requests.json), [export output](export.log).
- [Exact compile/run commands](commands.txt), [compiler output](compile.log), [benchmark output](benchmark.log), [execution and hashes](execution.json).
- [Machine-readable corrected baseline](results.json), [benchmark source](benchmark.swift), [compile/run wrapper](run-benchmark.py).

An initial run used a mapped plane normal with `planeFocus=true` following an incorrect assumption about the default. The correction arrived after that short run had finished. Its source, commands, log and receipt are retained separately in [preliminary-focus-enabled](preliminary-focus-enabled/); the main table reports only the corrected `planeFocus=false` run. The four Lean datasets were reused unchanged, and there were no additional service captures or benchmark configurations beyond this correction.

This diagnostic measures approximate native rendering code consuming executable-Lean results. It adds no theorem or kernel-checked performance claim. Existing renderer attribution to Katherine Stange remains unchanged in the actual source; these measurements are not attributed to her.
