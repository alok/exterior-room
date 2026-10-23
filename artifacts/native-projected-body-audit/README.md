# Native projected-body investigation

This bounded diagnostic investigates the sparse native projected cloud reported at Source depth 16. CPU counts are not evidence that RealityKit displayed the corresponding pixels. The offscreen macOS renderer is also not visionOS simulator or hardware acceptance.

Subsequent production simulator acceptance passed; its matched screenshots and
separate receipts are in the [native continuation](../../docs/NATIVE_PREVIEW_RENDER_UPDATE.md).

## Immutable semantic fixture

- Source catalogue: depth 16, identity matrix, Whole on, Dust off.
- Selected forms: `(1,0,1)` and `(1,1,1)`; exact pair normal `(1,0,-1)`.
- Screen on, height 9.6, star size 1, Overview.
- 4,406 accepted forms; progress 0, 0.5 and 1 use the same catalogue.

`export-lean.py` asks the existing compiled Lean service for the catalogue, pair and membership. `lean-d16.json` records the requests, responses and service binary hash. `run-plan.py` compiles the actual native CPU renderer functions; only the model's data declarations are extracted verbatim to avoid unrelated Observation macros. `cpu-receipt.json` records the source hashes and exact successful commands. The future reproduction command uses task-specific `/tmp` cache and executable paths; the retained first receipt records the original workspace paths.

From the repository root:

```sh
python3 artifacts/native-projected-body-audit/export-lean.py
python3 artifacts/native-projected-body-audit/run-plan.py
```

## CPU result

| Progress | Instanced bodies | Positive body alpha | Positive material alpha | Positive primitive upper bodies |
|---|---:|---:|---:|---:|
| 0 | 2,239 | 450 | 400 | 51 |
| 0.5 | 2,239 | 2,239 | 2,199 | 1,577 |
| 1 | 2,239 | 1,973 | 1,933 | 1,577 |

At progress 1 the primitive upper physical sphere radii range from 0.841 mm to 17.280 mm, with a median of 2.328 mm. The unit form's body opacity is 0.95. The 266 upper multiples remain instanced at zero alpha. Endpoint alpha quantization removes 40 otherwise positive bodies, all exterior/lower; it removes no positive upper body. The independent source oracle is in `../source-morph-oracle/`.

These observations rule out wholesale omission from the CPU plan. They do not establish a material, depth or footprint defect in RealityKit.

## Offscreen experiment

`render-probe.swift` consumes the exported actual sphere mesh, instance transforms, colors and already converted material opacities from `plan-d16.json`. It changes neither catalogue nor radius/alpha formula. One serial GPU job compares:

1. Fresh progress 0, followed by updates to 0.5 and 1.
2. Progress 1 after replacing the whole ModelComponent.
3. Fresh progress 1.
4. Cold/updated/fresh variants with `writesDepth=false`, `readsDepth=true`.
5. Fresh progress 1 with only zero-material-alpha batches omitted.

The fixed diagnostic camera is at `(0,1.6,0)`, looking along −Z, vertical FOV 60°, 1280×960. The cloud uses the native Overview position `(0,1.4,-3.1)` and native yaw/pitch. Guides and selection glyphs are excluded to isolate cloud behavior. Every capture waits four serial rendered frames. Material readback checks API state; only pixel comparisons test the offscreen GPU result. No application window, simulator or headset is opened.

The harness compiled successfully against the local macOS SDK. Its initial sandboxed execution exited in 0.128 seconds because `MTLCreateSystemDefaultDevice()` returned `nil` (`No Metal device`). It did not create a RealityRenderer or produce any capture. This was runtime unavailability, not an approval denial. `probe-execution.json` records that attempt; `gpu-run.txt` retains the error.

The parent subsequently ran the **same compiled binary** once through approved execution escalation, without OS permission changes. All nine captures completed in 8.303 seconds. `gpu-local-execution.json` records that run, and `gpu-ab-local/receipt.json` contains material readbacks, image hashes and pixel comparisons.

| P1 comparison | Changed RGB pixels | Nonblack pixel count |
|---|---:|---:|
| Updated versus fresh | 0 | 13,242 for both |
| Updated versus replaced ModelComponent | 0 | 13,242 for both |
| Default versus no cloud depth writes | 470 | 13,242 → 13,263 |
| Default versus omitted zero-alpha batches | 36 | 13,242 → 13,263 |

The updated/fresh captures also match with depth writes disabled. Every checked material readback matched its intended Float opacity. Default UnlitMaterial depth reads and writes remain enabled after assigning transparent blending.

Visual inspection of `fresh-p1.png`, `updated-p50.png` and `no-depth-writes-fresh-p1.png` shows the projected root pattern present, with small but visible bodies. This macOS body-only experiment does not reproduce the near-empty native simulator disk. It excludes stale material updates as the explanation **within this fixture and renderer context**. The modest zero-alpha/depth differences do not explain wholesale loss here. It does not establish visionOS behavior or visual parity with the browser.

## Guide isolation: reproduced defect

The separate `guide-probe.swift` preserves the body-probe source and adds the actual native screen, cutting-plane and cone geometry/material formulas. The pair's normal and endpoints come from the accepted Lean fixture. At Identity these formulas match the native renderer; source hashes and compile command are in `guide-execution.json`. The same fixed camera, bodies, radii and opacities are used throughout. `gpu-guides-execution.json` records the successful seven-capture run (11.046 seconds), and `gpu-guides-local/receipt.json` contains the results.

**The transparent guide fans reproduced the missing projected disk.** Visual inspection of `gpu-guides-local/body-plus-all-guides.png` shows the projected bodies absent. In `body-plus-all-guide-fans-no-depth-write.png`, setting only the fans' `writesDepth=false` restores the dense projected pattern. Guide lines retain their original depth behavior in this control.

| Guide control | Previously bright body pixels reduced below 25% brightness |
|---|---:|
| Screen only | 0 |
| Cutting plane only | 60 |
| Cone only | 3,842 |
| All guides, default depth writes | 800 |
| All guides, fan depth writes disabled | 0 |

The baseline has 12,289 pixels with maximum RGB above 16. This metric is a diagnostic: guides add their own light, so the combined-guide count is not the sum of individual counts. The all-guide fan fix changes 83,528 RGB pixels; unchanged nonblack counts do not mean unchanged body visibility.

The product's `PolynomialSpace.fan` now disables depth writes for these translucent reference surfaces. It preserves depth reads, colors, opacity, line behavior, geometry, accepted data and Lean boundaries. This is a demonstrated macOS RealityKit defect and fix; fresh visionOS simulator acceptance of the product remains separate.

## Optimization verification

The same renderer edit also reuses one unit box mesh for line geometry, skips redundant source material assignment when its actual alpha is unchanged, and records CPU stage timings under `POLYNOMIAL_GESTURE_DIAGNOSTICS=1`.

`optimization-probe.swift` compares those changes with the original operations while keeping the verified fan-depth correction in every capture. Seven serial captures completed in 7.539 seconds; provenance is in `optimization-execution.json` and `gpu-optimization-execution.json`, results in `gpu-optimization-local/receipt.json`.

- Cached versus unconditional material assignments produce **identical RGB pixels** at progress 0, 0.5 and 1. All 254 batch material readbacks match their intended Float alpha. Setters decrease from 762 to 458 across these three states; batch constructor counts remain 254.
- Shared unit-box lines versus individually generated boxes differ at **one of 1,228,800 pixels**, maximum channel difference 93, RMS channel difference 0.05656. Visual inspection confirms the same geometry and visible projected pattern. The images are therefore not claimed to be pixel-identical.

These are bounded rendering checks and operation counts, not a measured end-to-end latency improvement. The actual native build/UI acceptance and stage timing measurements remain separate.
