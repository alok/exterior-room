# Source projection numerical oracle

This project-only diagnostic investigates sparse native projection at reference commit `11c907b1`. It does not execute the app, GPU, simulator, native model tests or a build, and supplies no pixel or headset acceptance evidence.

Run from the repository root:

```sh
node artifacts/source-morph-oracle/analyze.mjs /tmp/exteriorroom-source-recrop-bundle.js
```

The local source bundle must have SHA256 `f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b`. The script reuses the source fixture extractor in memory, excludes its file writer, and records all 4,406 source `an()` outputs at projection 0, 0.5 and 1. It compares them with production JavaScript alpha/radius helpers, records input-file hashes, and writes [oracle.json](oracle.json). It never edits production files or existing fixtures.

The controlled state is Source depth 16, identity action, selected `(1,0,1)`, paired `(1,1,1)`, exact plane normal `(1,0,−1)`, Whole on, Dust off, Screen on, height fraction 0.6, overview eye, star size 1 and dark theme.

| Progress | Positive-opacity bodies | Primitive upper | Upper multiples | Other signed forms | Pickable at alpha ≥ .06 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 | 450 | 51 | 3 | 396 | 386 |
| 0.5 | 2,239 | 1,577 | 266 | 396 | 1,839 |
| 1 | 1,973 | 1,577 | 0 | 396 | 1,919 |

Thus full projection is expected to retain 1,577 positive-opacity primitive upper bodies. The native 16-level endpoint-bin expression predicts 1,933 positive material bodies overall at full projection, losing 40 faint bodies: 32 exterior and eight lower, **zero upper**. This quantization cannot account for missing projected upper stars. The prediction is arithmetic, not an observation of RealityKit materials.

The browser renders circular point sprites with a one-CSS-pixel minimum radius and area-based attenuation below that minimum. All Source body alphas are less than `.999`, so its fragment shader writes far-plane depth for those bodies. Native renders physical low-poly spheres without a camera-dependent minimum pixel footprint. Its material helper enables transparent blending but does not explicitly assign `readsDepth`, `writesDepth` or `opacityThreshold`; their runtime values were not measured. The local Xcode 27.2 simulator SDK declares `UnlitMaterial.readsDepth` and `writesDepth` for visionOS 2 and later.

At full projection, the primitive upper source radius has median `0.03879836` display units. That becomes `0.00232790 m` in native and `0.00620774` browser world units. The views also use different camera distance and framing; these physical radii do not establish pixel-size parity.

Suggested controlled experiments, for the renderer owner:

1. Confirm the settled native snapshot reports the exact progress, 4,406 identities and expected numerical counts before comparing images. This separates stale state/queued rendering from shader behavior.
2. Keep snapshot and camera fixed; hide Screen, cone and plane guides individually. A change isolates guide occlusion or compositing.
3. At settled full projection, temporarily omit zero-material-alpha cloud batches. Native retains 266 upper multiples whose alpha is zero, at projected positions shared with primitive roots. Browser explicitly discards alpha-zero fragments. Whether native transparent zero-alpha instances can occlude depends on unmeasured material/depth behavior; this experiment isolates that possibility. Also log actual depth settings and compare cloud-only `writesDepth=false, readsDepth=true`; do not assume platform defaults.
4. For the same primitive upper bodies and camera, compare physical spheres with a diagnostic minimum-footprint billboard path, or temporarily increase star size using the existing control. Count resolved image features separately from positive-opacity records.
5. Match the projected disk diameter on screen before comparing point density. Record camera, viewport and size settings; native physical scale and browser world scale differ.

These suggestions are experiments, not established causes. No production changes or screenshots were made by this audit.
