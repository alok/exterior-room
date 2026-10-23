# Polynomial Room validation — 2026-10-23

This receipt distinguishes exact arithmetic, actual browser interaction,
synthetic WebXR and native simulator checks. It does not establish complete
source-viewer parity or physical-headset acceptance. Dense/Snap browser regression, the final primitive picker and synthetic XR
controller motion have actual UI checks. Native disk dragging now has an accepted
XCUIElement swipe, with gesture callbacks and a replayed Lean result. Earlier
coordinate press-drag failures remain separate historical evidence.

## Exact data and automated checks

- [Lean build](../lean/Polynomial/evidence/build-result.json): Lean
  `v4.35.0-rc3`, zero warnings, **17 general integer theorems**. The 16 explicit
  [axiom audits](../lean/Polynomial/evidence/axiom-audit.txt) report only
  `propext`, `Classical.choice` and `Quot.sound`.
- [Compiled-service comparison](../lean/Polynomial/evidence/service-tests.json):
  305 requests, 13 point fixtures, 10 pairs, eight plane normals, eight cloud
  radii, all **2,120,040 ordered points**, 100 additional points and 12 invalid
  cases passed. R96 contains 1,852,484 points with ordered hash
  `069d4ab4008491dfa26fb881a8d8c0df1004a272fb986e85c721a7b69f5daca5`.
- [Transform service checks](../lean/Polynomial/evidence/transform-tests.json):
  **385 requests passed**, including 33 canonical generator cases, exact
  rational drag representatives, 100 random positive-determinant matrices,
  composition/inverse/incidence, and 72 Snap/Identity checks. The latter include
  signed pairs and asymmetric image-bound rejection. This is arithmetic
  regression evidence, not client atomicity or gesture evidence.
- [Current Node receipt](../artifacts/polynomial-action-node-tests.txt):
  **91 tests passed**, with no failures or skips. Coverage includes transport,
  accepted renderer adapters, action commit/cancel races, left composition,
  Snap staging/rollback, all-point Klein buffers and the synthetic runtime.
  These do not establish browser/GPU behavior.
- [Python receipt](../artifacts/polynomial-python-tests.txt): 26 bridge tests
  passed. [Native action model receipt](../native/evidence/action-model-tests.txt):
  the original **59 tests passed**, including exact action and Snap models.
  The later [plane-fade model run](../native/evidence/plane-fade-model-tests.txt)
  passes **61 tests**, adding transformed-normal and distance-fade regressions.
  The current [swipe model run](../native/evidence/klein-swipe-model-tests.txt)
  passes **62 tests**, including the actual captured swipe replay and an
  outside-disk last-valid-preview retention check.

The separately reproducible [native/browser coordinate audit](../artifacts/native-browser-coordinate-audit/README.md)
compiles the frozen native adapter from before the fade correction and compares
it with the browser adapter over all 69 shared action fixtures. Float32
coordinates agree numerically; 11 coordinate
comparisons differ only in the sign of zero. Maximum absolute rounding error
against rational coordinates is about `1.526e−6`. This is adapter arithmetic
evidence, not a proof of rendering, appearance, gestures or pixel equality,
and does not certify subsequent source edits.

The nine original laws concern display norm, Lorentz/discriminant identity,
scaling/sign invariance and pair incidence. Eight action laws cover identity,
row layout, determinant/action composition, discriminant/incidence transport,
scaling and adjugate behavior. Enumeration completeness, gcd normalization,
radical simplification, numerical nearest-candidate Snap, JSON and compiled
execution are tested rather than proved by these statements. Rendering,
interaction and device behavior are outside the Lean kernel boundary.

## Real browser UI: IAB

The browser owner exercised the production page and local Lean bridge in IAB.
The [base snapshots](../artifacts/screenshots/polynomial-20261023/browser-checks.json)
record Next's hidden R6 multiple, another visible point, signed negative
selection, upper-only retention of that hidden negative selection, form-created
pairing, projection, Origin and pointer look, Inhabit, Reset, full R96 rendering,
390-pixel mobile layout and Next, proportional-pair rejection preserving the
accepted pair, and Reset retaining palette/size/plane-focus preferences.

A real pointer hover returned `x²−x+2`; its
[saved receipt](../artifacts/screenshots/polynomial-20261023/hover-check.json)
and [capture](../artifacts/screenshots/polynomial-20261023/11-hover.png) concern
that observation, not exhaustive dense-hover freshness.

Useful base captures:

- [Overview](../artifacts/screenshots/polynomial-20261023/01-overview.png)
- [Exact pair and projection](../artifacts/screenshots/polynomial-20261023/02-plane-projection.png)
- [Origin](../artifacts/screenshots/polynomial-20261023/03-origin.png)
- [All R96 points](../artifacts/screenshots/polynomial-20261023/04-dense96.png)
- [390-pixel mobile](../artifacts/screenshots/polynomial-20261023/09-mobile390.png)

The shared pair is `(1,0,1)/(1,1,1)` in the full R6 cloud: normal `(1,0,-1)`,
plane **`2a − 2c = 0`**, endpoints **−1 and 1**, and **22 displayed interior
triples**, counting both signs and multiples. Browser/native images were
visually compared; geometry, category colors and the plane agree, while camera,
scale, glyph material and UI placement differ. The browser capture has its
controls scrolled; exact readouts are established by the state receipt, not by
claiming that hidden text is visible in that image.

Main Chrome remains a separate acceptance gap. Debugger attachment failed with
an observed connection error, so completed interactions used IAB. The
[connection record](../artifacts/screenshots/polynomial-20261023/chrome-connection.json)
is a tool failure, not an approval denial. No Chrome pass or new grant is implied.

## Möbius action and Snap browser checks

The [action snapshots](../artifacts/screenshots/polynomial-20261023/mobius-browser-checks.json)
record the exact preset `M=(3,1,1,2)`, `D=5`: `(1,-1,2)` becomes
`(8,-23,22)/5`, and paired unit form `(1,0,1)` becomes `(5,-10,10)/5`.
Real pointer input moved the 2D roots and released to an accepted Lean matrix.
A separate 50×20-pixel drag in 3D Origin committed while preserving the camera.
These are actual input handlers and Lean requests, not injected app state.

- [Exact rational action](../artifacts/screenshots/polynomial-20261023/12-exact-move.png)
- [Transformed roots and plane](../artifacts/screenshots/polynomial-20261023/13-exact-roots-plane.png)
- [2D direct drag](../artifacts/screenshots/polynomial-20261023/14-roots-drag.png)
- [3D Origin drag](../artifacts/screenshots/polynomial-20261023/15-origin-drag.png)

The [dense/Snap receipt](../artifacts/screenshots/polynomial-20261023/mobius-snap-checks.json)
contains a repeated real R96 roots drag with the requested `(13,20,34)` and
paired unit `(1,0,1)`. The numerical held preview became canonical candidate
`T=(1,1,0,1)`. Lean atomically relabelled them to `(13,-6,27)` and `(1,-2,2)`,
then reset the displayed matrix to Identity. The resulting plane was
`42a+b−20c=0`, endpoints `−3/2` and `7/5`, with 200 displayed interior members.
Identity retained both new labels; Shift-pan retained the action and identities.
A separate 50×20-pixel **R96 3D Origin drag** committed
`M=(9636,1078,1078,10498)` with `Δ=-1368`, while the camera position,
quaternion and FOV remained unchanged.

The same receipt's definitive `asymmetric-pair-accepted` and
`asymmetric-rejection-retains-both` states verify atomic failure: unit paired
with `(-40,40,-40)` would map the second form under T to `(-40,120,-120)`.
The ±96 image bound rejected it; both prior identities and action were retained.
An earlier `asymmetric-before` snapshot had no accepted pair and is not used
as rollback evidence.

- [R96 requested source](../artifacts/screenshots/polynomial-20261023/16-r96-source-roots.png)
- [Held preview](../artifacts/screenshots/polynomial-20261023/17-r96-drag-held.png)
- [Accepted Snap](../artifacts/screenshots/polynomial-20261023/18-r96-snap-T.png)
- [Identity retaining the relabel](../artifacts/screenshots/polynomial-20261023/19-identity-retains-relabel.png)
- [Final paired Snap](../artifacts/screenshots/polynomial-20261023/20-final-paired-snap.png)
- [Dense Origin action](../artifacts/screenshots/polynomial-20261023/21-r96-origin-move.png)
- [Asymmetric rejection](../artifacts/screenshots/polynomial-20261023/22-paired-snap-rejection.png)

The dense hover probe exposed an incorrect tie rule: the old picker chose a
large multiple at a coincident root. The final pure picker now follows the
source rule—within a half-pixel tie, prefer the largest apparent glyph, then
upper over a same-size negative partner—with three passing packed-data tests.
The [final QA receipt](../artifacts/screenshots/polynomial-20261023/mobius-qa-checks.json)
loaded that correction: actual R96 center hover displayed
`x²+1`, and a real click selected `(1,0,1)`. This is a separate completed check,
not an inference from the earlier in-flight hover/click snapshot. The historical
relabel receipt now explicitly says “Last Snap”. The
[primitive-pick capture](../artifacts/screenshots/polynomial-20261023/23-dense-primitive-pick.png)
shows the corrected state. Silent app recordings show the actual
[R96 roots drag, Snap and Identity](../artifacts/videos/polynomial-roots-snap.mp4)
and [3D Origin drag and return](../artifacts/videos/polynomial-origin-drag.mp4).
The QA recorder captures the active app canvas; surrounding DOM controls may
therefore be outside the video, while saved state/captures carry the readouts.

Both views retain all accepted source identities. The R96 roots buffer has
**540,404 vertices**, including coincident signs/multiples; no sampling is used.
The [CPU microbenchmark](../artifacts/polynomial-dense-cpu-benchmark.json), run
on this arm64 Mac with Node v26.9.0, measured 1,852,484-point transforms at
8.4–11.3 ms, packed root coordinates at 1.7–4.3 ms and the final two-pass
roots pick at 2.1–5.9 ms.
It uses the pinned reference cloud whose full content was independently matched
to Lean. It is not a browser/GPU or headset frame-rate measurement. Dense preview
buffers update at most ten times per second; release commits the final pose.
Actual IAB snapshots report all 540,404 roots and all 1,852,484 3D points; the
measured CPU motion stage was about 3.8–8.6 ms and roots update/render submission
about 0.2–3.3 ms. These stage timers omit full-frame/GPU completion and are not
frame-rate claims.

The pane uses a Klein chart; canonical 0.15 uses the upper half-plane. Our
apparent-radius rule `|Δ|^(1/4)/|a′+c′|^(3/2)` is the origin-perspective rule in
Klein coordinates and gives 1/k size along k-times forms before pixel clamping.
Color uses each accepted discriminant and selected palette; plane fade uses the
transformed display normal. These are renderer conventions, not Lean proofs or
pixel-identical source behavior. Source transformed recropping is not implemented.

## Synthetic WebXR in a real browser

The [base XR snapshots](../artifacts/screenshots/polynomial-20261023/xr-checks.json)
use the explicitly flagged [QA runtime](../web/qa/README.md). Synthetic head and
controller poses feed the production Three.js XR manager, raycasts and event
handlers. The Lean requests and WebGL rendering are real; the devices, session
and compositor interface are synthetic.

Observed base actions include entry, Next, Projection, Reset, Origin, Overview,
ray-selection of `(1,0,1)`, Pair aim and ray-pairing with `(1,1,1)`, projection,
Exit and re-entry. A desktop Origin pose and FOV100 were restored after XR
Reset/Exit. A deliberately delayed Lean request retained rendering and allowed
Exit while `dataBusy=true`. Left-controller Next/Exit also ran in stereo.

- [Synthetic Origin](../artifacts/screenshots/polynomial-20261023/06-emulated-origin.png)
- [Synthetic stereo](../artifacts/screenshots/polynomial-20261023/08-emulated-stereo.png)
- [Final base pair](../artifacts/screenshots/polynomial-20261023/10-final-xr-pair.png)

The [new motion QA receipt](../artifacts/screenshots/polynomial-20261023/mobius-qa-checks.json)
separately exercises the new controls and production controller handlers:
entry → Exact move (`D=5`, image `(8,-23,22)`) → Identity → T relabel
`(1,-3,4)` → Identity retaining that label → T inverse restoring the default.
Move forms entered Origin; a held trigger and moving controller ray produced
a numerical preview, then release committed `M=(10408,1283,1283,9766)`,
`D=99998439`, with `Δ=-7`. A second preview followed by controller disconnect
restored the previous accepted matrix. Reconnection and unpressed aiming did
not change it. Snap, Overview and clean Exit also ran.

The [motion capture](../artifacts/screenshots/polynomial-20261023/24-xr-mobius-origin.png)
and [silent XR motion recording](../artifacts/videos/polynomial-xr-mobius.mp4)
are explicitly synthetic-device evidence. There are **30 implemented in-world
buttons**; these receipts cover the stated subset, not every button or all
failure combinations. No receipt establishes real headset permissions,
tracking, hand joints, physical controller ergonomics, compositor behavior,
comfort or hardware performance.

## Native simulator

The final base UI run
[`20261023T055100Z`](../native/evidence/ui-tests-20261023T055100Z.txt) passed:
**one test, zero failures, 140.911 seconds**, with 14 screenshots. It verified
the default, hidden multiple, shared pair/projection, size, palette, fade,
Origin/Inhabit→Overview, Dense R12 (3,608 points), Reset retaining appearance
preferences, and Leave. The
[pair](../native/evidence/screenshots/20261023T055100Z/006-poly-04-pair.png) and
[pair/projection](../native/evidence/screenshots/20261023T055100Z/007-poly-04-pair-projection.png)
captures show the same exact fixture as the browser. An earlier failing run
exposed point entities intercepting panel controls; the final fix limits spatial
point picking to Overview while keeping exact selection controls available in
Origin and Inhabit.

The separate Snap UI run
[`20261023T061442Z`](../native/evidence/ui-tests-20261023T061442Z.txt) passed:
**one test, zero failures, 43.968 seconds**, with six captures and a video in
[its evidence directory](../native/evidence/screenshots/20261023T061442Z/).
It verified the requested seed as a hidden exact identity, T absorption to
`(13,-6,27)`, Identity retaining that label, a rational-action checkpoint, Snap
and Reset. The [silent export](../artifacts/videos/polynomial-native-snap.mp4)
is available separately; raw simulator recordings stay local.
This is button-driven Snap evidence. The native R12 crop cannot
render the requested seed; it is explicitly shown as hidden.

A prior native drag probe synthesized input but produced no matrix change.
Its misleadingly named `drag-accepted` capture is **not** acceptance evidence.
The lifecycle rerun `061602Z` and launch-window run `061935Z` both reported
“No drag sample yet” and no matrix change. Later source review found that the
status was updated only after a coordinate guard, so these observations cannot
distinguish missing callbacks from rejected samples. Neither is a successful
drag. Those historical coordinate press-drag failures remain unexplained; the
later element-swipe route below does establish current callback delivery.

Native directional controls use the same numerical-preview → quantized-matrix
→ Lean-acceptance pipeline. Focused UI run
[`20261023T062243Z`](../native/evidence/ui-tests-20261023T062243Z.txt) passed:
**one test, zero failures, 64.040 seconds**, with five captures. Up and Right
accepted matrices and visibly changed the 3D geometry; enabling Snap, Identity
and Reset also passed. The
[evidence directory](../native/evidence/screenshots/20261023T062243Z/) includes
a recording receipt; its [silent 39.47-second export](../artifacts/videos/polynomial-native-directional.mp4)
is available in the local package. This is a functional alternative control
path, not evidence that free dragging works on a physical device or in the
simulator. Physical gaze/pinch,
tracked hands and real headset launch remain unverified. Native has no exact
hover-polynomial inspector or explicit GameController bindings.

The subsequent local renderer correction transports the plane normal with the
same accepted action as the points, then measures fade in transformed display
coordinates. For the unit pair under `M=(3,1,1,2)`, the normal changes from
`(0,0,−2)` to `(−2/5,1,−11/5)`. Native finite cone guides now remain fixed,
matching the browser; the selected cutting plane continues to transform.
These are renderer corrections, not additions to the Lean theorem set.

The [focused simulator run](../native/evidence/ui-tests-20261023T065009Z.txt)
passed **one test, zero failures, 37.921 seconds**, following a successful
[simulator build](../native/evidence/plane-fade-build-for-testing.txt).
The [fresh native receipt](../native/evidence/plane-fade-native-receipt.json)
records the corrected sources, tests and capture hashes.
The matching [IAB state receipt](../artifacts/screenshots/polynomial-20261023/paired-fade-recheck.json)
records the same R6 pair `(1,0,1)/(1,1,1)`, 22 members, and D5 action.
The following actual screenshots were inspected together:

| State | Browser/IAB | Native simulator |
| --- | --- | --- |
| Identity, fade on | [Capture 27](../artifacts/screenshots/polynomial-20261023/27-paired-fade-identity.png) | [Identity](../native/evidence/screenshots/20261023T065009Z/001-plane-fade-01-identity-overview.png) |
| D5, fade on | [Capture 28](../artifacts/screenshots/polynomial-20261023/28-paired-fade-D5.png) | [D5](../native/evidence/screenshots/20261023T065009Z/002-plane-fade-02-rational-overview.png) |
| D5, fade off | [Capture 29](../artifacts/screenshots/polynomial-20261023/29-paired-D5-fade-off.png) | [Fade off](../native/evidence/screenshots/20261023T065009Z/003-plane-fade-03-fade-off-overview.png) |
| D5, fade on, projection | [Capture 30](../artifacts/screenshots/polynomial-20261023/30-paired-D5-projection.png) | [Projection](../native/evidence/screenshots/20261023T065009Z/004-plane-fade-04-rational-projection.png) |

Both sequences show fixed cone guides, the transformed plane and point cloud,
restored off-plane context when fade is disabled, and the recomputed radial
projection. Camera scale, materials and UI placement differ; pixel-level opacity
agreement was not measured. These four states were subsequently repeated in
native run [`070602Z`](../native/evidence/ui-tests-20261023T070602Z.txt),
**one test, zero failures, 33.101 seconds**, and freshly recorded on both routes:
[browser, 53.88 seconds](../artifacts/videos/polynomial-browser-matched-render.mp4)
and [native, 15.13 seconds](../artifacts/videos/polynomial-native-matched-render.mp4).
Actual exported frames include all four states. Durations differ because input
and observation timing differ; these are corresponding sequences, not synchronized
or pixel-identical videos. The browser records its canvas, excluding DOM controls;
the native recording includes the app panel. Both are silent and exclude the host
desktop. Earlier native action clips predate the renderer correction.

## Native disk swipe accepted

The Canvas/GeometryReader input target now measures 170 × 170 points around the
154-point disk, centered in its panel, instead of stretching across the panel.
The gesture threshold and mathematical preview code are unchanged. Diagnostics
also expose local start/current coordinates. The supported element-swipe route
was inspected read-only in canonical commit
`2ec43e8879bddb0b17546bc1d9263903e0983e85`.

Focused run [`070446Z`](../native/evidence/ui-tests-20261023T070446Z.txt) passed
**one test, zero failures, 46.194 seconds**. Actual `XCUIElement.swipeRight()`
produced recognized/changed/ended counts **1/2/1**, zero cancellations and no
Origin/busy guard rejection. Starting from D5 in Origin, it accepted
**M = [13876, 5301, 5706, 9386], D = 99,992,630**. The selected pair remained
`(1,0,1)/(1,1,1)`, with discriminants −4/−3 and 22 base-plane members.
The [actual bridge replay](../native/Resources/polynomial-swipe-case.json)
checks both exact transformed plane incidences as zero. The unchanged 69
canonical action fixtures also pass in the 62-test model suite.

The release coordinate `(239.1,85)` lies outside the 170-point target. The
preview rejected that point and the release committed the last valid in-disk
sample. The intermediate coordinate itself was not logged; its accepted matrix
was logged and replayed. No directional-button fallback was used in this test.
The [16.82-second silent clip](../artifacts/videos/polynomial-native-klein-swipe.mp4)
shows the resulting Origin geometry and its return to Overview. Its
[receipt](../native/evidence/klein-swipe-native-receipt.json) records source,
input, fixture and capture hashes.

The input route and target bounds changed together; no old-wide-target swipe
A/B test was run. This success establishes current simulator gesture wiring and
Lean acceptance, without identifying the cause of earlier coordinate press-drag
failures. Physical tracked hands, real controllers, native free-space SL₂ drag
and actual gesture cancellation remain unverified. Floating-point preview and
quantization remain client behavior, not additional Lean proofs.

The native cap remains R12; it uses physical spheres and a one-time head anchor.
Its Inhabit offset `(0,−0.08,−0.35)` m differs from browser `(0.1,0.12,0.1)` scene
units. The matching fixtures demonstrate semantic geometry/readout agreement,
not identical cameras or pixels. See [native/README.md](../native/README.md),
[the parity contract](FUNCTIONAL_PARITY.md) and
[source-action notes](source-drag-proposal.md) for the remaining differences.
