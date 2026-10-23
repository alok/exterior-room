# Lean Starscape · visionOS

## Lean Starscape

The app's display name is **Lean Starscape**. Its stable Xcode scheme remains
`PolynomialRoom` and its bundle identifier remains `com.alok.PolynomialRoom`.
Use `-scheme PolynomialRoom` in the build command
below. Its Mac bridge is `/api/polynomial` on port 8787. `python3
native/scripts/export-polynomial.py` regenerates the bundled R6 cloud and signed
quadratic inspection from the actual Lean executable, with hashes and requests
in `native/Resources/polynomial-export-receipt.json`.

The native route draws 480 signed triples at R6, 3,608 at R12 and **28,832 at
R24**. The crop choices are R4, R6, R8, R10, R12 and R24; Dense selects R24.
Shared RealityKit mesh instances replace one rendering entity per point. This
path requires **visionOS 26 or later** (`MeshInstancesComponent` and
`LowLevelInstanceData`); it has no older-OS instancing fallback. The
renderer accepts at most 40,000 buffered identities; an oversized catalogue is
rejected as a whole and the previous accepted scene remains. R48/R96 and physical
headset performance are not verified. This route concerns quadratics `ax²+bx+c`,
not arbitrary-degree polynomials.

**Catalogue → Source depth** requests the separate executable-Lean source
catalogue. Switching from a smaller canonical crop starts at depth 16; smaller
source depths remain explicit extensions. Whole includes the other signed
categories; with Whole off, Dust adds the source's surrounding cloud. Source
D16 identity buffers 4,406 signed forms. Membership counts describe that padded
buffer, not only visible bodies. Source body opacity now includes the original
Whole radial fade, screen attenuation, plane highlight and nonprimitive fade;
the older D6 “80 visible” receipt measured only the trace-crop mask.

**Project/Lift** animates the source world geometry with the original cubic
3.5-second full-range timing. The progress controls scrub in quarter steps.
Upper bodies move toward height `0.6 × depth` (adjustable from 0.15 to 1 times
depth); their radii and alpha change with progress, and upper multiples disappear
at full projection. Lower/null/exterior bodies stay in place. Selected and paired
rings survive hidden/multiple identities. **Show screen** is independent of
projection progress; the cone and cutting plane remain unmorphed. Canonical ball
retains its earlier radial overlay. All of this is approximate renderer behavior.

During a source drag, at most one asynchronous Lean catalogue request runs with
one latest pending proposal, at least 150 ms between starts and the source's 0.16
inverse-i displacement threshold. Completed preview catalogues are ephemeral;
accepted action, identities and scene revision stay unchanged. Cancellation
restores the accepted scene. Release performs the complete exact transaction.
Mode/depth/Whole/Dust changes also stage every response before acceptance; failure
restores the previous scene and controls. Reset returns Canonical ball/R6/Whole
on/Dust off. Actual interim-preview input acceptance is recorded separately from
release acceptance in the latest receipt.

Semantic colors use RGB8 bins. Source opacity uses 16 quantized endpoint levels
per material, interpolated through the morph; exact per-body source calculations
remain separately tested against 408 Float32 body outputs in 48 source cases.
This stable partition avoids rebuilding entities on each morph tick. A recorded
D16 half-morph update took 270.3 ms with 254 material batches, versus 455.8 ms in the
earlier implementation. These are individual CPU rebuild observations, not FPS
or hardware benchmarks. Meshes, fades, clipping and root charts are approximate.

Collision chunks retain ranges into the accepted signed catalogue; picking
returns the stored identity, never a rounded inverse transform. Shared **Pair
next/Cancel** works across the main panel, Roots and spatial picking. The Origin
sky has a persistent input shell, root-local direction conversion, explicit
gesture ownership, cancellation and callback/rejection diagnostics. Actual
spatial input acceptance is distinct from its passing model tests. Physical
headset input and performance remain unverified.

The current source-morph/input work passes **147 model tests** and an unsigned
visionOS 27.2 simulator test build. Run `20261023T115306Z` passed the matched
morph sequence in 110.561 seconds: P0/P0.5/P1, timed Project/Lift, D5, an actual
Roots swipe, shared pairing cancellation and Reset. The transparent cone, screen
and plane fans now retain depth reads without writing depth, fixing the sparse
projected disk. Actual matched screenshots show the restored primitive pattern;
physical sphere footprint, materials, framing and window layout still differ
from the browser.

Run `20261023T120502Z` then passed the unchanged strict held-input test in
66.969 seconds. One validated temporary catalogue published **1.233 seconds
before gesture end**, after an obsolete response was discarded. The exact
released matrix `[16491,8977,16312,14943]` retained the unit/pair, 4,205 forms and
64 plane members. P50/P100 and Origin target readiness also passed. This run used
the exact-integer Lean cold-scan optimization; the preceding matched morph used
the same native app with the older backend.

See the [current held-input receipt](evidence/preview-recurrence-native-receipt.json)
and [diagnosis, matched screenshots and clips](../docs/NATIVE_PREVIEW_RENDER_UPDATE.md).
The original `110630Z`, `113815Z` and `115041Z` failed preview runs remain preserved;
release-only success was not counted as interim acceptance. No test assertion or
hold duration was weakened.

Actual free-space Origin and sphere-pairing input remain unverified in this app.
The supported Device Hub connection timed out (`timeoutReached −10005`) before
host input; this was an access failure, not permission denial or hardware evidence.
The existing native pointer-hover XCTest limitation remains. Physical headset
input, native R48/R96 and broader dense interaction performance remain unverified.

Reproduce the current model/build checks from `native/`:

```sh
swift test -j 2
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode-27.2.0-Beta.2.app/Contents/Developer \
xcodebuild -project ExteriorRoom.xcodeproj -scheme PolynomialRoom \
  -sdk xrsimulator27.2 \
  -destination 'platform=visionOS Simulator,id=1D261881-0A0F-4DE0-B704-12644E606348' \
  -derivedDataPath .build CODE_SIGNING_ALLOWED=NO ARCHS=arm64 \
  SWIFT_COMPILATION_MODE=wholemodule -jobs 2 build-for-testing
```

The existing background capture runner targets that owned simulator. These are
separate focused tests, not a claim that the entire UI suite passed:

```sh
# Passed matched morph run20261023T115306Z with restored projected bodies.
python3 scripts/run-ui-tests.py --scheme PolynomialRoom \
  --test-class PolynomialSourceMorphUITests \
  --test-name testSourceMorphLinkedRootsDragAndSharedPairing

# Passed unchanged strict held-preview run20261023T120502Z; requires the current Lean backend.
python3 scripts/run-ui-tests.py --scheme PolynomialRoom \
  --test-class PolynomialSourceMorphUITests \
  --test-name testActualSharedRootsPairAndHeldSourcePreview
```

The second command translates to
`-only-testing:PolynomialRoomUITests/PolynomialSourceMorphUITests/testActualSharedRootsPairAndHeldSourcePreview`
with `test-without-building`; its assertion is unchanged. The current run passes
through its final morph/Origin-ready steps; earlier failed runs remain historical
evidence. Coordinate foreground use with other simulator owners before reproducing
input tests.

Launch and Reset select `(1,-1,2)`, displaying `x² − x + 2`. Spacing is presentation
only; Lean's raw polynomial label remains unchanged. Next follows the canonical cycle:
`(1,-1,2) → (2,-2,4) → (2,1,1) → (1,0,1) → (3,2,2) → (−1,1,−2) → (1,2,1) → (1,3,1)`.
Next can retain an inspected point hidden by the current crop, including
`(2,-2,4)` at R6. The panel labels a hidden selection and disables Inhabit for it.
Manual Select and Pair accept only points in the currently accepted cloud;
invalid entry leaves the selection unchanged. A requested larger crop does not
make its points available before Lean accepts it.

Controls include signed selection and exact polynomial readouts, exterior and
paired cutting planes with Lean membership, radial projection, Viridis and the
six-anchor Stange reference palette, lower-half coloring, a 0.4–2.5 sphere-size
multiplier, cone visibility and plane-distance fade. The fade is approximate
renderer behavior; it retains the selected point and Lean-identified interior
plane members at full brightness. Glyphs have physical size and perspective;
they are not the browser's pixel-clamped point sprites.

Overview offers three stationary object orientations. Origin places the
coefficient origin once at the head center; its nappe toggle changes orientation.
The zero polynomial is not a selectable projective point. Inhabit places the
chosen point 35 cm ahead and 8 cm below the head center once, using native offset
`(0,−0.08,−0.35)` metres; later selection does not move the viewer. This differs
from the browser's `(0.1,0.12,0.1)` scene-coordinate offset.
Reset restores the canonical default, R6 and Overview, clears the pair and
filters, disables lower-half coloring, hides projection, and restores the cone.
It preserves the chosen palette, sphere-size multiplier and plane-fade setting,
matching the browser's Reset behavior.

Open **Roots…** for the linked upper-half-plane window. **Move** drags the shared
Möbius action; **Select** and **Pair** pick signed base identities from the drawn
roots. **Pan**, zoom buttons, pinch magnification and **Fit** change only the chart.
The window shares the accepted cloud, pair, palette, size and plane fade with the
3D scene. The orange semicircle or vertical geodesic comes from the accepted
Lean plane endpoints, then the current approximate display action. Selected,
paired and hovered roots show polynomial labels from validated Lean inspections.
Root bodies are upper-positive. Source selected/pair rings bypass crop and
primitive filtering and use the positive representative for chart placement only;
the stored signed selection remains unchanged. Close/reopen preserves the accepted action and selection.
The Klein disk remains available separately.

The Roots plot adapts the source's upper-half-plane coordinates, star-size rule,
brightness attenuation, chart fit/pan/zoom and label placement. Source picking
uses packed pre-raster alpha ≥ 0.05, hit radius max(7,r+4), and the original
distance−0.8min(r,12) ranking with first-catalogue tie order. Canonical ball
retains its existing nearest/half-pixel tie rule. Picking and continuous previews are floating-point UI behavior. A
release submits a declared bounded matrix to Lean, and the accepted response
updates the Roots window and 3D scene together. A cancelled preview restores the
accepted scene. The narrowed Roots window now stays within the captured guest
frame, but it still occludes part of the 3D scene; closing it exposes the geometry. Separate gesture ownership prevents a stale end/cancel from the
Klein disk from committing or cancelling a Roots preview, and vice versa.

Open **SL₂ transform** for T, T⁻¹, S, the `i → 1+i` checkpoint, Identity and Snap.
The checkpoint submits `M = [3,1,1,2]`, with determinant 5: Lean returns the exact
image of the default as `(8,−23,22)/5`. Continuous actions move the drawn geometry
while retaining its signed base triples. Canonical ball keeps its fixed crop;
Source depth can display an ephemeral Lean preview catalogue during a drag; release accepts the complete action and catalogue together. Choose
Origin to enable the Canvas Klein disk. Its implemented drag path previews an
approximate transvection; release proposes a bounded integer matrix to Lean.
Until that request is accepted, the previous exact action remains authoritative.
An actual simulator element swipe on the Klein disk now has verified callbacks,
Lean acceptance and visible 3D changes. Coordinate press-drags remain historically
unsuccessful, and physical input is unverified. The Move arrow buttons in Origin
remain a tested fallback through the same quantization and Lean acceptance path.

Snap proposes an integer determinant-one matrix using the canonical floating-point
modular-cell reduction and **residual polar-angle** comparison, including its
tie tolerance and sign convention. This corrects the earlier entrywise-distance
criterion: the recorded vertical transvection selects T⁴, not T⁴S.
It is not a proved globally
nearest-matrix algorithm. Lean computes the exact images of both selected and
paired signed triples. The app validates both bounds, refreshed inspections,
pair plane, membership and identity receipt before publishing the new scene
together. A failed request, either image outside the exact identity bound ±1024,
or a stale reply preserves
the entire previous pair and action. An integer image of one point alone does
not establish an SL₂(ℤ) action. Integer generators relabel selections only when
the combined normalized matrix is exactly integral with determinant one;
otherwise they retain a continuous action. **Snap on release** chooses this
relabeling path instead of a continuous commit; enabling it also Snaps immediately. Reset turns it off. **Identity** resets the action
and keeps already relabeled selections; Reset restores the canonical default.

**Source (13,20,34)** inspects the recorded source point even though it is hidden
at the smaller native crops up to R12. Starting from Identity, T relabels it to
`(13,−6,27)` with the same discriminant −1368; Identity keeps that new label.
The recorded vertical transvection Snaps to T⁴ and produces `(13,−84,162)`;
Identity preserves this label too. Exact identities can range to ±1024 while
the native canonical cloud remains capped at R24. These source examples remain
explicitly hidden when outside the current accepted crop.
The Source control does not enlarge the native cloud or make Inhabit
available for a hidden point.

Under a nonidentity action, root and cutting-plane readouts retain the exact
**Base** values and append approximate **shown** roots/endpoints. A drag preview
is labeled **preview**. Pending or failed actions retain the last accepted
readout; cancellation restores it. These shown values are renderer conversions
of Lean descriptors, not new exact Lean results.

Exact classification, gcd/sign representatives, projection ratios, plane normals,
endpoints and interior membership come from Lean. RealityKit draws approximate
root/projection positions, sampled cone/plane meshes, colors and physical sphere
sizes. It performs no discriminant, gcd or pair-plane fallback. Source body highlighting
classifies accepted signed triples against the Lean-supplied plane normal with
bounded integer arithmetic; this renderer-only incidence check is not a new Lean
proof or a replacement for the validated Lean membership response.
The decoder rejects unrecognized schema/source revisions, mismatched request
IDs, malformed arrays and inconsistent coordinate maps or descriptors. Pending
or failed requests preserve the accepted geometry and provenance; only an
accepted pair is drawn. These transport checks are not additional Lean proofs.

For a declared matrix M with positive determinant D, executable Lean returns the
integer rows and image numerators of the rational action `J(M)/D`. The eight
generic theorems in `lean/Polynomial/TransformProofs.lean` kernel-check the integer
action laws, including composition, discriminant scaling and plane-incidence
covariance. They do not prove pointer mapping, transvection, Snap choice,
quantization, Swift transport, renderer geometry or physical gestures. A rounded
drag sample is exact for the declared M only. The native fixtures are actual
compiled Lean exports; `Resources/polynomial-action-receipt.json` records their
requests and hashes. Canonical Snap fixture values are separately labeled as
browser floating-point regressions, not Lean results. See
[`lean/Polynomial/README.md`](../lean/Polynomial/README.md) for the full proof and
execution boundary.

Rendering and placement adapt the pinned FareyVision native sources at
`ca809d2975a37a318a425e4b9dd73560b07faf39`; source-file hashes are recorded in
`native/evidence/polynomial-source-manifest.json`. Transvection and coefficient
action conventions adapt `Farey/WebXR/mobius.js` at
`63ad115422ab1141ca6d06732572385414b7a5cf`. Historical Snap/absorption fixtures
at `6fea557bb0d0c786bed5223dc631cb1c06e94f16` are preserved; the corrected
polar criterion is pinned to `2cd549a45ddb6056cf3596404754d96ad9e7132c` in
`Resources/polynomial-polar-snap-cases.json` and its separate fresh receipt.
The Roots geometry/window additionally adapt `Farey/Sources/RootsPaneView.swift`
and `Farey/WebXR/roots-pane.js` at
`2a0ef3216a931bdcf6cdd9ba89a1baf6f4cfa46a`; their exact file hashes are recorded in
the new Roots receipt. The manifest records earlier borrowed files and hashes separately. The underlying visualization
credits Katherine Stange and Harriss–Stange–Trettel's *Algebraic Number Starscapes*.
The Lean adaptation is independent. Viridis credits Smith, van der Walt and
Firing (CC0). Source headers preserve GPL attribution.

The batched spatial renderer has no per-point hover effect; spatial polynomial
inspection requires selection. The Roots window implements an independent hover-polynomial
readout through `onContinuousHover`; actual pointer hover remains unverified
because public visionOS XCTest excludes its pointer-hover command. The model
suite tests validated hover responses, stale-response cancellation and cache
retention; those are not actual hover input tests.
Tracked controller support remains absent. Spatial pairing and Origin free-space
dragging are implemented; their actual input acceptance is recorded separately
from model tests in the latest receipt. Targeted spatial selection is gated to the accepted cloud in Overview
and rejects busy or preview states. Actual entity
gaze/pinch selection, physical-headset hand input, comfort and performance remain
unverified. The separate Exterior Room endpoint drag/cancellation also lacks
successful actual-gesture verification: its XCUI endpoint probe failed to
synthesize an event because Accessibility returned
`Received invalid activation point transform (nil)` in
[`ui-tests-20261023T055513Z.txt`](evidence/ui-tests-20261023T055513Z.txt).
The earlier Polynomial Room coordinate-drag failures remain recorded separately
from the successful element-swipe test `20261023T070446Z`. Model tests alone do
not establish gesture execution.

The historical polar-Snap [`polar-snap-model-tests.txt`](evidence/polar-snap-model-tests.txt)
receipt records **68 tests passed, zero failures**: 39 polynomial model tests,
12 action math/decoder tests, five appearance tests and 12 Exterior Room tests. Coverage
includes real Lean fixtures, exact and nonintegral actions, canonical Snap
candidates (34 current canonical cases), hidden-source T⁴ relabeling, the separated
identity/cloud bounds, safe-integer edge receipts, spaced labels, accepted/preview
readouts, atomic pair rollback, stale responses and cancellation of preview values.
The 27 new Lean receipts preserve earlier fixture sets. This is model/transport evidence, not an executed
gesture or headset receipt.

The historical [Roots model suite](evidence/roots-model-tests.txt) passed **88 tests,
zero failures**: 45 polynomial model tests, 14 Roots geometry tests, 12 action
math/decoder tests, five appearance tests and 12 Exterior Room tests. The new
coverage includes source fit/pan/zoom/resize/picking, signed base identities,
paired geodesics, accepted label retention, independent hover cancellation,
atomic pair inspection and cross-surface gesture ownership. The
[unsigned build](evidence/roots-build-for-testing.txt) succeeded. The
[focused Roots UI run](evidence/ui-tests-20261023T092615Z.txt) passed **one test,
zero failures in 72.046 seconds**, with six actual simulator screenshots and a
silent app-only recording. It used real chart taps to select `(1,0,1)` and pair
`(1,1,1)`, real chart swipes for Move and Pan, and actual zoom/Fit/Identity and
Close/reopen controls. The actual accepted swipe matrix was
`[24959,10694,18805,12064]`, determinant **100004706**; a
[separate compiled-Lean replay](evidence/roots-accepted-action-lean-replay.json)
confirms both images and discriminants −4/−3. No diagnostic action injection was
used. The [fresh Roots receipt](evidence/roots-native-receipt.json) records source,
model, build, UI and capture hashes.

The [silent Roots recording](../artifacts/videos/lean-starscape-native-linked-roots.mp4)
contains video only (H.264, 3840×2160, 50.716667 seconds); the
[video metadata](../artifacts/videos/lean-starscape-native-linked-roots-metadata.json)
records export and frame-review details.

The native Roots window floats in front of the immersive scene, partly covering
it; the browser uses adjacent panes. Three actual Zoom out presses frame both
D5 roots and the full geodesic in the comparison capture. Camera, physical sphere
sizes and window framing differ; these are matched states, not pixel parity.
Actual pointer hover, physical pinch zoom, interrupted-gesture cancellation,
physical tracked-hand/controller input and headset performance remain unverified.

Run its existing-simulator UI checks with `python3 native/scripts/run-ui-tests.py
--scheme PolynomialRoom` after `build-for-testing`. The silent simulator recording
begins after entering the app's immersive space and stops before leaving it.
See `docs/native.md` for dated verification receipts. A build or button-driven
simulator capture does not establish physical interaction. The latest polar-Snap
UI run passed one test with zero failures in 112.941 seconds, covering declared
M=(50,18,0,5), corrected T⁴ absorption, the true source point's T⁴/Identity result,
shown root/endpoints, T and Reset. Its five images were visually inspected.
See [the current receipt](evidence/polar-snap-native-receipt.json) and
[silent raw recording](evidence/screenshots/20261023T081658Z/lean-starscape-polar-snap.mov).
The diagnostics-only matrix preset is not a drag-gesture claim.
The [reviewed silent 1080p export](../artifacts/videos/lean-starscape-native-polar-snap.mp4)
and [metadata](../artifacts/videos/lean-starscape-native-polar-snap-metadata.json)
preserve this simulator sequence without trimming or a speed change.

## Exterior Room

This separate RealityKit app consumes the same exact integer response as the browser.
It has two explicit modes: **Lean export · preset playback** uses bundled JSON produced
by the Lean executable; **Live Lean · Mac bridge** sends bounded integer coordinates to
the local server. It does not implement a second exterior algebra engine in Swift.

The full immersive scene places controls beside three vectors, a translucent
parallelepiped, the `a ∧ b` face, and exact exported coefficients. Overview and
inside change scene placement/scale; the latter does not claim room mapping or
collision handling. In live mode, drag a colored endpoint and release to send
its quarter-unit snapped coordinates to Lean. Coordinate buttons, vector
selection, swap, flatten, reset and volume visibility mirror the browser.

During a drag, a translucent ghost preserves the initial grab offset and previews
the snapped endpoint. The accepted solid, original endpoint and coefficients stay
unchanged until a matching Lean response arrives. Both panels label the preview
and report whether the visible result came from a bundled export or the Mac.
Changing inputs or placement, cancelling the gesture, or leaving the space
discards the preview. Tracked-hand execution remains untested.

`python3 native/scripts/export-presets.py` reads the browser's `PRESETS`, sends
them to the compiled Lean executable, and writes the native JSON plus a SHA-256
receipt. There is no native/Python algebra fallback. Reduced fractions are
presentation only. The same negative half-way snapping rule is used in both UIs.

Build without signing or simulator boot:

```sh
cd native
/opt/homebrew/bin/xcodegen generate
DEVELOPER_DIR=/Applications/Xcode-27.2.0-Beta.2.app/Contents/Developer \
  xcodebuild -project ExteriorRoom.xcodeproj -scheme ExteriorRoom \
  -sdk xrsimulator27.2 -destination 'generic/platform=visionOS Simulator' \
  -derivedDataPath .build CODE_SIGNING_ALLOWED=NO ARCHS=arm64 -jobs 2 build
```

For a simulator, the default server is `http://127.0.0.1:8787`. A physical headset
must use a reachable Mac address and an explicitly LAN-bound server; localhost on
the headset refers to the headset. App Transport Security allows local networking.
No physical headset run or comfort/performance claim is made by a successful build.

The native bridge is HTTP; Lean executes on the Mac, not on visionOS. A failed live
request leaves the last accepted result visible and labels it as previous data.
Live connection intent persists across pending and failed requests: selecting a
preset still retries the bridge, while displaying that preset's bundled export
until a response is accepted. Offline launch and preset playback need no server.

Validate the same Swift JSON decoder used by the app, and optionally compare all
bundled exports against the running bridge:

```sh
DEVELOPER_DIR=/Applications/Xcode-27.2.0-Beta.2.app/Contents/Developer \
  xcrun swiftc -parse-as-library Sources/LeanModel.swift Tests/VerifyExports.swift \
  -o .build/verify-exports
.build/verify-exports Resources/presets.json http://127.0.0.1:8787
```

This is a transport/schema consistency check, not a second proof of the algebra.
It also drives the actual native model through unit → swap → flatten → reset →
coordinate-edit operations against the live Lean service.

Native model tests:

```sh
swift test --package-path native --scratch-path native/.build/swift-tests -j 2
```

`native/scripts/run-ui-tests.py` targets the task-owned simulator
`1D261881-0A0F-4DE0-B704-12644E606348` (Exterior Room QA 2026-10-23). Build the
UI tests with `build-for-testing` first; use `--simulator UUID` for another
task-owned simulator. The runner uses a serialized screenshot
handshake because visionOS does not support XCTest's ordinary screenshot API.
Each run records native screenshots, timing/hash receipts and an `.xcresult`.
It never targets the existing Farey simulator.

## Provenance

ImmersiveSpace lifecycle and RealityKit sphere/cylinder/transparent mesh patterns
are adapted from FareyVision at `8b32d7ae8f67fc47f381407bbcdf6f24e28de771`, files
`Farey/Sources/FareyVisionApp.swift`, `FareyImmersiveView.swift`, and
`LatticeRenderer.swift`, plus `Farey/scripts/capture_coordinator.py` and
`Farey/UITests/SimulatorCapture.swift`, GPL-3.0-or-later. Adaptation by Alok Singh with OpenAI
Codex, 2026-10-23: independent exterior-algebra scene and Lean JSON transport.
FareyVision's mathematical exhibit credits Katherine Stange; this app borrows
application patterns only and does not attribute the new algebra scene to her.

The existing Lean Calculator and its Clifford bridge were located as background
context but were not copied: its iCloud-local source reads timed out.

The focused Snap UI run `evidence/ui-tests-20261023T061442Z.txt` passed in
43.968 seconds (six images). The later directional-action/Snap-toggle UI run
`evidence/ui-tests-20261023T062243Z.txt` passed in 64.040 seconds (five images),
including actual accepted-matrix and visible 3D changes from Up/Right buttons.
Both have silent app-only videos and metadata beside their screenshots.

The immersive disk probe `061602Z` and launch-window probe `061935Z` produced
no accepted drag sample or matrix change; callback delivery is unresolved. They are retained as opt-in diagnostics, not passes. Select
one explicitly using `--test-name testActionCheckpointAndOriginDrag` or
`--test-name testWindowDiskDragAndImmersiveResult`; ordinary UI runs skip them.
The tested native interaction route uses the exact action/Snap and Move buttons.
See [the full native receipt](../docs/native.md) for evidence and remaining gaps.

The earlier local plane-fade follow-up passed **61 model tests**, an unsigned simulator
build and one focused UI test (**37.921 seconds**, zero failures). Plane fade now
uses transformed positions and the transported normal; cone reference guides
stay fixed while the cloud and cutting plane move. Four visually inspected
Identity/action/fade-off/projection captures and fresh source/evidence hashes
are linked in [the follow-up receipt](evidence/plane-fade-native-receipt.json).
The earlier 59-test baseline is preserved separately.

The subsequent bounded-target swipe follow-up passed **62 model tests**, an
unsigned build and two focused simulator UI tests: actual element swipe
(46.194 seconds) and matched rendering (33.101 seconds). The disk's interaction
target is now a centered 170×170 square matching its visible area. The probe used
`XCUIElement.swipeRight()` and recorded one recognized gesture, two change
callbacks and one release, with a newly accepted Lean matrix and the exact pair
retained. Bounds and input route changed together; this does not isolate the
cause of earlier coordinate-drag failures. The out-of-disk release committed the
last valid in-disk sample, not its final pointer coordinate.

See [the swipe receipt](evidence/klein-swipe-native-receipt.json),
[the actual Lean replay fixture](Resources/polynomial-swipe-case.json),
[the silent swipe recording](evidence/screenshots/20261023T070446Z/polynomial-klein-swipe.mov)
and [the refreshed matched-render recording](evidence/screenshots/20261023T070602Z/polynomial-matched-render.mov).
Tracked hands, controllers, physical headsets and actual gesture cancellation
remain unverified. No older failed probe has been relabeled as a pass.

Reviewed silent 1080p exports:
[actual disk swipe](../artifacts/videos/polynomial-native-klein-swipe.mp4),
[matched rendering](../artifacts/videos/polynomial-native-matched-render.mp4),
and [video metadata](../artifacts/videos/polynomial-current-native-video-metadata.json).
