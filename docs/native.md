# Native Vision Pro routes

**Lean Starscape** is the primary native route in
`native/ExteriorRoom.xcodeproj`, with stable scheme `PolynomialRoom` and bundle
identifier `com.alok.PolynomialRoom`. It consumes the exact polynomial service
on the Mac. The earlier Exterior Room scheme remains a separate archived demo.
The full instructions and provenance are in `native/README.md`.

The latest polar-Snap follow-up below separates current behavior from the
historical build/UI receipts. Native upper-half-plane Roots, hover polynomial
readouts and free-space controller SL₂ dragging remain gaps; this is not a claim
of complete canonical Starscape parity.

## Archived Exterior Room

## Implemented

- RealityKit vectors, directly draggable endpoint handles, a highlighted exterior
  product face, and a translucent volume built from accepted Lean vertices.
- Overview and inside placements.
- Browser-matched presets and vector colors, quarter-grid coordinate edits,
  vector selection, swap, flatten, reset, and volume visibility.
- In-space exact coefficient/volume receipt and clearly distinct exported,
  pending, live, and disconnected states.
- Persistent live-connection intent across pending/failed requests and preset
  changes; separate, accurate provenance for the visible accepted result.
- A translucent, snapped drag ghost that preserves the initial grab offset.
  The accepted solid, endpoint and coefficients stay unchanged; a preview label
  distinguishes the proposed edit. Input/view changes cancel stale gestures.
- An editable Mac bridge URL and asynchronous, cancellable requests; accepted
  responses must match the requested sequence and input coordinates.
- Bundled Lean-exported presets for offline playback. Swift does not recompute
  the algebra. All rendering uses approximate `Float` coordinates.

## Verified build

The arm64 visionOS Simulator build and `build-for-testing` succeeded with Xcode 27.2 beta and
`CODE_SIGNING_ALLOWED=NO`. The generated bundle's identifier and
`NSAppTransportSecurity.NSAllowsLocalNetworking = true` were inspected.
Build output is at `native/.build/Build/Products/Debug-xrsimulator/ExteriorRoom.app`;
the latest local build transcript is `native/evidence/build-for-testing.txt`.

The first restricted-shell compile could not run Apple's Swift macro plugins
(`sandbox-exec: sandbox_apply: Operation not permitted`). An approved local
unsigned-build escalation completed successfully. This was a build environment
restriction, not a remaining source error.

## Runtime boundary

The already booted Vision Pro simulator was inspected read-only and found to be
running `com.alok.FareyVision`. Exterior Room was not installed or launched there.
A separate task-owned simulator, `Exterior Room QA 2026-10-23`, was created at
`1D261881-0A0F-4DE0-B704-12644E606348` for native UI interaction and screenshot
tests. No physical headset was modified or used. Hardware hand tracking, comfort
and headset performance remain untested.

Twelve Exterior Room model tests pass, including strict response-schema and proof-check rejection: preset parity, rational formatting, snapping,
rapid edits/out-of-order responses, failure preservation, invalid URL
invalidation, response rejection, pending/failed preset live-intent preservation,
result provenance, preview labeling and offset-preserving snapped drag proposals.
The actual Swift model also passes a live
Lean unit → swap → flatten → reset → coordinate sequence. See
`native/evidence/model-tests.txt` and `native/evidence/bridge-tests.txt`.

The simulator captures revealed a window overlapping the geometry and an exit
that failed to restore the launch window. The scene now uses a separate controls
attachment beside the geometry in a dark immersive space, and opens its launch
window before dismissing that space. The final XCUITest passed with 0 failures in 126.317 seconds,
capturing 9 real simulator screenshots with a serialized capture handshake.
It verifies export/Mac provenance labels, live connection, space entry, the unit/swap/flatten exact volumes
`1 → -1 → 0`, coordinate editing, preset selection, view/volume controls, reset
and return to the launch window.

- Test log: `native/evidence/ui-tests-20261023T031413Z.txt`
- Overview: `native/evidence/screenshots/20261023T031413Z/002-02-skew-overview.png`
- Swapped: `native/evidence/screenshots/20261023T031413Z/004-04-swapped.png`
- Flattened: `native/evidence/screenshots/20261023T031413Z/005-05-flattened.png`
- Inside placement: `native/evidence/screenshots/20261023T031413Z/007-07-inside.png`
- Restored launch window: `native/evidence/screenshots/20261023T031413Z/009-09-returned.png`
- Capture hashes/timing: `native/evidence/screenshots/20261023T031413Z/captures.json`

The final overview and restored launch window screenshots were visually inspected.
The inside capture follows an edit of c.x to 1/2 and therefore displays volume
289/64, rather than the unedited skew preset's 147/32. Targeted endpoint dragging
is implemented, but this UI run exercises coordinate buttons rather than a
tracked-hand drag. Physical-headset interaction is not verified. Inside is a
chosen scene placement/scale, not a measurement of the user's physical position
or a guarantee that every edited shape surrounds their eyes.

Earlier logs and screenshots retain failed-test/layout evidence. The successful
run above is the final tested state; `.xcresult` bundles are local build artifacts.

The Lean executable runs on the Mac. This native route does not bundle Lean's
runtime or claim on-device kernel checking. Physical-headset live use requires
an explicitly reachable Mac bridge; the default loopback address only works
from the Mac/simulator context.

## Lean Starscape (stable PolynomialRoom scheme)

The same project provides the independent `PolynomialRoom` scheme and
`com.alok.PolynomialRoom` app, displayed as **Lean Starscape**. It preserves Exterior Room and consumes
`/api/polynomial` from the Mac bridge. Launch with the instructions in
`native/README.md`; the default remains loopback port 8787.

The canonical default/reset is `(1,-1,2)`, displaying `x² − x + 2`. Next follows all
eight canonical triples, including `(2,-2,4)`, whose exact identity remains
selected when the R6 crop hides its geometry. Entered selection/pair coordinates
must occur in the current accepted Lean cloud. Filtering and selecting do not
move an inhabited viewpoint. Native Inhabit places the point at `(0,−0.08,−0.35)`
metres relative to its once-captured head anchor, while the browser uses
`(0.1,0.12,0.1)` scene offsets; the camera placements are not numerically identical.
Reset restores the scene while retaining palette, size and plane-fade preferences. Failed requests retain accepted geometry, selection,
pair and provenance; pending pair geometry is never displayed as accepted.

Controls include signed point selection, exact polynomial/discriminant/root
readouts, pair and exterior cutting planes, exact interior membership rings,
projection, Overview/Origin/Inhabit and Origin nappe flip, three overview angles,
R4/6/8/10/12 crops, upper-only and lower color, Viridis/Stange palettes, size
0.4–2.5, plane-distance fade, cone visibility and Reset. R12 has 3,608 points;
this native cap is explicit and differs from the browser's optional R96 crop.

Lean computes the signed triples, categories, gcd/sign representatives, selected
projection ratios, roots as rational/radical descriptors, plane normals/equations,
endpoints and exact interior membership. The 21 bundled fixture responses come
from the actual compiled service (`native/scripts/export-polynomial.py`), not a
Swift implementation of that math. Generic theorem checking happens when the
Lean modules build; loading or rendering a response does not run a new kernel
proof. The native app does not embed the Lean runtime.

RealityKit performs approximate floating-point rendering, picking, palette
interpolation, distance fading, camera placement, meshes and perspective. Native
glyphs are physical spheres, so browser pixel-footprint clamping/brightness is
not reproduced exactly. The Stange palette is the pinned viewer's six-anchor
OKLab approximation; this is not a new mathematical result attributed to her.
The pinned source commit and original file hashes are recorded in
`native/evidence/polynomial-source-manifest.json`, and all reused code retains
its GPL/CC0 attribution.

The native route exposes system hover highlighting and selection inspection.
It does not yet expose the canonical upper-half-plane Roots window, root picking,
a hover-polynomial readout or explicit GameController bindings. The Klein disk
is an action surface, not that missing Roots view. Simulator panel interactions are not evidence of tracked-hand,
physical-controller, headset comfort or hardware-performance parity.

Build receipt: `native/evidence/polynomial-build-for-testing.txt` (unsigned
arm64 simulator build). That initial baseline had 32 passing native tests: 17 polynomial model tests, 3 presentation tests and
12 exterior tests. Coverage includes canonical fixture classifications/order, default/Next/wrap,
hidden selection and entry rejection, placement retention, accepted-only pairs,
reset, stale responses, transport rejection, and exact descriptor validation, required named plane/pair checks, palette anchors and
distance-fade retention.
Results are recorded in `native/evidence/model-tests.txt`.

The initial polynomial UI run produced ten screenshots and a silent app-only
video in `native/evidence/screenshots/20261023T052520Z/`. It exercised both signs,
plane membership, projection, Origin/flip/Inhabit, Dense, Reset and successful
Leave/return. One assertion failed because the UI localized `3608` as `3,608`;
the corrected expanded run `20261023T053349Z` passed with 13 captures in
197.622 seconds, including canonical default/Next and palette/fade controls.
Visual review then revealed a clipped title in the denser controls panel; the
attachment height was expanded and lifted. Final capture below supersedes these
intermediate layout recordings.


### Final polynomial baseline receipt

`native/evidence/ui-tests-20261023T055100Z.txt` passed one simulator test with
zero failures in 140.911 seconds. The 14 captures and their hashes are in
`native/evidence/screenshots/20261023T055100Z/`:

- `001-poly-00-canonical-default.png`: canonical `(1,-1,2)` default.
- `002-poly-00-hidden-multiple.png`: retained `(2,-2,4)` hidden at R6.
- `006-poly-04-pair.png` / `007-poly-04-pair-projection.png`: matched pair
  `(1,0,1)` and `(1,1,1)`, plane `2a −2c = 0`, endpoints `−1,1`, 22 members,
  projection off/on.
- `008-poly-04-palette-plane-focus.png`: Stange palette, size1.20, plane fade.
- `010-poly-06-origin.png`, `011-poly-07-origin-lower.png`,
  `012-poly-08-inhabit.png`: anchored placements.
- `013-poly-09-dense.png`: 3,608 points at R12 after returning to Overview.
- `014-poly-10-reset.png`: canonical R6 reset while preserving palette, size
  and plane-fade preferences.

The test also verifies space exit and return to the launch window. The matched
plane, projection, dense and earlier layout captures were visually inspected.
`polynomial-parity.mov` is the app-only silent recording; `video-metadata.json`
confirms a single H.264 video stream, 3840×2160, 124.836667 seconds, and no audio
stream. The capture coordinator stops recording before space exit.

The regression discovered nearby point colliders intercepting panel taps during
Inhabit. Spatial point picking is now enabled only in Overview; Origin/Inhabit
use the exact selection controls. This makes Overview, Dense and Reset reachable
from an inhabited view. This limitation is visible in the placement hint.

Public XCUI slider adjustment failed to synthesize an event on visionOS. The
slider remains available; accessible size −/+ buttons were added and verified
instead. No slider-gesture or tracked-hand claim follows from the button test.

The later SL₂ action extension is separate from this baseline receipt; it needs
its own build/model/UI evidence before being described as verified.

### SL₂ action and atomic Snap

The native SL₂ panel uses `/api/polynomial` transform receipts. For a bounded
integer matrix `M` with positive determinant `D`, Lean computes the exact
coefficient action `J(M)/D`, its selected-point image, and the discriminant
preservation check. Native code validates the response provenance, echoed input,
required checks and bounded linear arithmetic before acceptance. It does not
square the large image numerators in Int64. The native process does not execute
the Lean kernel; the generic laws were checked when the Lean modules were built.

The `i → 1+i` checkpoint requests `M=[3,1,1,2]`, `D=5`. At the canonical default
`(1,-1,2)`, the exact displayed image is `(8/5,-23/5,22/5)`. Floating-point
transvections, the pointer-to-Klein-disk mapping, approximate drag previews,
quantization and the modular Snap proposal are renderer/input behavior. A
release sends a declared integer sample back to Lean. During a pending or failed
request the previous accepted geometry and receipt remain visible.

T, T⁻¹ and S compose on the left. If the normalized combined matrix is exactly
an integer determinant-one matrix, the model obtains Lean images of **both**
selected points, checks the exact identity bounds (now ±1024, separately from
the cloud radius), inspects the new points, and
rebuilds their exact pair plane and displayed membership. It publishes these
labels and the identity action together only after every response is accepted.
Snap follows the same transaction after choosing its integer proposal. A single
integral point image is insufficient to authorize absorption: the rational
checkpoint maps `(1,0,1)` integrally despite its normalized matrix not belonging
to SL₂(ℤ). Tests explicitly reject that shortcut. Any failure, including just
one out-of-range pair image, retains the entire previous selection, pair, plane,
cloud membership and action.

The explicit `Source (13,20,34)` button preserves the user's canonical source
fixture. Native R12 does not display that point; the interface labels the
selection as hidden and disables Inhabit. T produces `(13,-6,27)` with Δ=-1368;
Identity preserves that absorbed label. Reset restores `(1,-1,2)` and keeps the
existing palette, size and plane-fade preferences.
The current polar criterion also supports the recorded T⁴ result
`(13,-84,162)` with the same discriminant; this remains valid but hidden at R12.

The 3D renderer transforms the finite base cloud and cutting-plane vertices
with the accepted action. Cone reference guides remain fixed after the local
correction documented below. Radial images are recomputed after the action.
It does not recrop the transformed infinite lattice as the canonical viewer can.
Native maximum radius remains R12. The transformation drag surface is a SwiftUI
Klein disk; a native free-space tracked-hand/controller SL₂ drag is not
implemented or claimed. Native point picking remains Overview-only.

Action and Snap provenance is recorded in
`native/evidence/polynomial-source-manifest.json`: browser action formulas at
`63ad115422ab1141ca6d06732572385414b7a5cf` and Snap/control semantics at
`6fea557bb0d0c786bed5223dc631cb1c06e94f16`, with original file hashes. The native
adaptation preserves Katherine Stange visualization attribution and does not
attribute its new Lean proofs to her.
The current polar-Snap criterion follows `2cd549a45ddb6056cf3596404754d96ad9e7132c`
and has a separate fixture/receipt below. Earlier entrywise-distance fixtures
remain historical evidence, not the current Snap definition.

`native/evidence/action-model-tests.txt` records **59 tests, zero failures**:
12 exterior, 35 polynomial model, 9 action/Snap and 3 appearance tests. Actual
Lean fixtures include 69 action responses, and 20 pinned browser Snap proposal
fixtures are explicitly renderer-only. Coverage includes stale replies, preview
cancellation, atomic pair relabeling, final-membership failure rollback, either
pair image beyond bounds, and exact normalization versus merely integral images.
`native/evidence/action-build-for-testing.txt` records the unsigned simulator
build. These model/build results are separate from simulator gesture evidence.

The first action UI attempt, `20261023T060432Z`, verified the rational checkpoint,
Origin and Identity controls but failed because a synthesized disk drag did not
change the accepted matrix. Its third image was named `drag-accepted` before the
assertion outcome; that filename is **not** a success claim. Subsequent focused
runs use `drag-unconfirmed` when the matrix does not change.

The separate exterior endpoint gesture probe, `20261023T055513Z`, found the
endpoint accessibility element but XCUI rejected its drag with **“Received
invalid activation point transform (nil) from Accessibility.”** This is an
unverified gesture, not a passed endpoint or cancellation interaction. Model
preview/cancellation tests do not remove that simulator driver limitation.

### Native Snap UI receipt

`native/evidence/ui-tests-20261023T061442Z.txt` passed one focused test with zero
failures in **43.968 seconds**. Its six screenshots in
`native/evidence/screenshots/20261023T061442Z/` show the exact source fixture,
T absorption, Identity retention, rational checkpoint, Snap absorption and
Reset. The source fixture and Identity screenshots were visually inspected;
the retained hidden label and disabled Inhabit are visible. The panel now scrolls
instead of clipping controls or attribution.

`polynomial-snap.mov` is a 27.86-second app-only silent H.264 recording at
3840×2160 (9,365,269 bytes); `video-metadata.json` confirms no audio stream.
The prior `061243Z` run reached the same behavior but failed three exact-text
assertions because SwiftUI localized the discriminant as `-1,368`; the display
now explicitly formats the integer as `-1368`, and the passing run above
supersedes it. This Snap control receipt does not certify a drag gesture.

### Final directional-action UI receipt

`native/evidence/ui-tests-20261023T062243Z.txt` passed one focused test with zero
failures in **64.040 seconds**. The five images in
`native/evidence/screenshots/20261023T062243Z/` show the rational checkpoint at
Origin, accepted Up and Right samples, Snap plus Identity, and Reset. Both
accepted-action screenshots were visually inspected: the exact matrices and
fractions change, and the visible stars move. These are real button
interactions, not a successful drag gesture. The Move arrows use the same
transvection-preview, quantization and exact Lean acceptance pipeline. Enabling
Snap immediately performs absorption; Reset disables Snap.

`polynomial-directional-action.mov` is a 39.463333-second silent app-only H.264
recording at 3840×2160 (3,902,178 bytes); its metadata is saved alongside it.
That action-baseline model receipt has **59 passing tests** including directional
sample acceptance, Origin/busy/bounds guards, immediate Snap-toggle behavior,
Snap-on-release cancellation and Reset clearing the toggle. There are 69 actual
Lean action fixtures with their export receipt.

The follow-up immersive disk probe `061602Z` failed after 53.133 seconds; its
`gesture-diagnostic.json` records the reported accessibility rectangle and the
unchanged `No drag sample yet` state. A separate launch-window probe `061935Z`
also failed after 72.663 seconds with no accepted sample or matrix change.
Callback delivery remains unresolved: the old status changed only after the
Origin/busy guard, so rejected callbacks were not distinguished from missing input.
Both retained the previous accepted scene. These failures do not establish
whether physical tracked-hand input would work. They remain opt-in diagnostics
via their explicit `--test-name` values; ordinary UI runs skip them and do not
count them as passes. No further coordinate-synthesis attempts were made.

The action baseline used base coordinates for its plane-opacity distance
heuristic. The local follow-up below corrects that renderer mismatch.

### Local plane-fade and reference-guide correction

The native renderer now measures plane-fade distance using transformed point
positions and the transported plane normal. For the display action `F`, the
normal is `Q F Q n = inverseTranspose(F) n`, where `Q = diag(1, -1, 1)`.
This floating-point renderer conversion consumes accepted Lean coefficient
rows; it adds no Lean theorem or Swift-side kernel check. Cone rings, spokes
and translucent fans remain fixed reference guides, matching the browser.
The cutting plane and cloud continue to transform, and radial projection is
recomputed after the action.

The new receipt is [plane-fade-native-receipt.json](../native/evidence/plane-fade-native-receipt.json).
It hashes the changed sources, tests, build log, UI log and actual captures.
The earlier 59-test [baseline receipt](../native/evidence/final-native-receipt.json)
is preserved with its historical limitations. The current validation is:

- **61 model tests, zero failures:** [model log](../native/evidence/plane-fade-model-tests.txt).
  Two added regressions use an actual Lean-exported determinant-five action
  to check normal transport, numerical fade, sign symmetry, selected/member
  retention and invalid-input guards.
- **Unsigned simulator build passed:** [build log](../native/evidence/plane-fade-build-for-testing.txt).
- **One focused UI test, zero failures, 37.921 seconds:**
  [UI log](../native/evidence/ui-tests-20261023T065009Z.txt).
  The matched fixture is radius 6, pair `(1, 0, 1)` / `(1, 1, 1)`,
  plane `2a − 2c = 0`, 22 members, Overview, and matrix `(3, 1, 1, 2)`.

Four new screenshots were captured and visually inspected:

1. [Identity with plane fade](../native/evidence/screenshots/20261023T065009Z/001-plane-fade-01-identity-overview.png).
2. [Accepted rational action with plane fade](../native/evidence/screenshots/20261023T065009Z/002-plane-fade-02-rational-overview.png).
3. [The same action with fade disabled](../native/evidence/screenshots/20261023T065009Z/003-plane-fade-03-fade-off-overview.png).
4. [The same action with radial projection](../native/evidence/screenshots/20261023T065009Z/004-plane-fade-04-rational-projection.png).

The captures show fixed cone guides, the moved cutting plane and cloud,
restored off-plane context when fade is disabled, and recomputed projection.
Camera placement and materials differ from the browser. This follow-up has
screenshots, not a new interaction video.

At this stage, the drag investigation found a diagnostic flaw: the previous status update
occurred after the Origin/busy guard. New opt-in diagnostics count changed/end
callbacks and record guard rejection before that guard. They compile, but the
failed drag probes were not repeated. Earlier probes establish no accepted
sample or matrix change; callback delivery remains unresolved. Neither these
diagnostics nor model tests verify tracked-hand input, physical controllers,
or an actual drag/cancel interaction. At that stage, the validated native action
route was the exact action, Snap and Move buttons. The subsequent element-swipe
result below is separate evidence. All follow-up work remains local.

### Actual Klein-disk swipe and refreshed matched video

The disk's interaction target now matches its visible area: a 170×170 inner
Canvas/GeometryReader, centered within the full-width controls. Its drawn disk
remains 154 points across, and its drag threshold and algebra are unchanged.
The element-level `swipeRight()` route follows the actual successful canonical
test at `2ec43e8879bddb0b17546bc1d9263903e0983e85`; the source hashes are in
[the fresh swipe receipt](../native/evidence/klein-swipe-native-receipt.json).
Both target bounds and input route changed, so this test does not isolate which
change explains the previous coordinate-press failures. It does establish that
the native gesture wiring and Lean acceptance path execute in this simulator.

The [actual swipe UI run](../native/evidence/ui-tests-20261023T070446Z.txt)
passed one test with zero failures in **46.194 seconds**. It recorded one
recognized gesture, two change callbacks, one end callback, zero cancellations
and no Origin/busy rejection. The accepted matrix changed from `(3,1,1,2)` to
`(13876,5301,5706,9386)`, with determinant **99992630**. The selected `(1,0,1)`,
paired `(1,1,1)`, base plane `2a − 2c = 0` and 22 interior members remained.
No action button was used as a substitute for the swipe.

The recorded local start was `(85,85)` and release was `(239.1,85)`. That final
coordinate is outside the disk: `PolynomialActionPreview.update` rejects it and
preserves the last valid in-disk preview, which `commitActionDrag` submits on
release. The final pointer coordinate itself was not accepted as a Klein point.
The valid intermediate coordinate was not separately logged; the exact matrix
that reached Lean was. Cancellation remains a separate, unverified UI path.

The [captured-matrix fixture](../native/Resources/polynomial-swipe-case.json)
replays that exact matrix through the real local Lean service for both selected
triples. Exact image numerators are `(120655432,-257863284,220643977)` and
`(67098916,-97375642,147087301)`, each over `99992630`. Their discriminants remain
`-4` and `-3`; both lie on the transported plane. Python rational diagnostics
and a bounded Int64 regression check these receipt values; neither adds a new
kernel theorem. The full [model suite](../native/evidence/klein-swipe-model-tests.txt)
passes **62 tests**, zero failures, and the [unsigned simulator build](../native/evidence/klein-swipe-build-for-testing.txt)
passed. The original 69-case Lean fixture set is preserved.

The separate [matched-render UI run](../native/evidence/ui-tests-20261023T070602Z.txt)
passed one test with zero failures in **33.101 seconds**. It records radius 6,
the same pair, Overview, Identity with plane fade, determinant-five action,
fade disabled, then fade enabled with projection. All seven new screenshots
across the two runs were visually inspected, including the moved Origin stars
and accepted Overview scene.

- [Swipe recording](../native/evidence/screenshots/20261023T070446Z/polynomial-klein-swipe.mov)
  and [three capture hashes](../native/evidence/screenshots/20261023T070446Z/captures.json).
- [Refreshed matched-render recording](../native/evidence/screenshots/20261023T070602Z/polynomial-matched-render.mov)
  and [four capture hashes](../native/evidence/screenshots/20261023T070602Z/captures.json).

These are task-owned simulator app-only recordings. Prior coordinate-drag
failures remain historical evidence; they were not rerun or reclassified.
Physical tracked-hand/controller input, free-space SL₂ dragging and actual
gesture cancellation remain unverified. No hardware or canonical simulator was
used, and no publication or upload occurred.

The reviewed 1920×1080 H.264 exports contain video only:
[swipe, 16.816667 seconds](../artifacts/videos/polynomial-native-klein-swipe.mp4)
and [matched rendering, 15.133333 seconds](../artifacts/videos/polynomial-native-matched-render.mp4).
Their final frames include accepted Overview and projection respectively;
[export metadata](../artifacts/videos/polynomial-current-native-video-metadata.json)
records the delivery hashes and inspection details.

### Current polar Snap, exact identities and shown readouts

The app is now displayed as **Lean Starscape**, while its scheme and bundle ID
remain `PolynomialRoom` and `com.alok.PolynomialRoom`. This change accompanies a
behavior correction, not a full-parity claim: the native upper-half-plane Roots
window and its picking/hover readouts are still absent.

Canonical commit `2cd549a45ddb6056cf3596404754d96ad9e7132c` corrects Snap to
compare the absolute polar angle of the residual action, with its tie tolerance
and sign convention. Native Snap now matches this rule. The recorded vertical
transvection chooses T⁴ rather than the old entrywise-distance candidate T⁴S.
The [34 current source cases](../native/Resources/polynomial-polar-snap-cases.json)
include the counterexample, sign equivalence, half-integer ties, rotations and
finite guards; they are floating-point regression fixtures, not Lean proofs.
Their pinned JavaScript source and shared canonical fixture hashes are embedded.
The old 20-case fixture and previous receipts are preserved.

The exact identity bound is now **±1024**, independently of the cloud's service
radius cap 96 and native display cap 12. Pair normals accept ±4,194,304, with the
existing endpoint-discriminant work cap retained. Declared action numerators
are bounded by 6,144,000,000,000,000, below the JSON safe-integer limit. The app
does not square these large numerators in Int64. The
[27 new actual Lean responses](../native/Resources/polynomial-polar-lean-cases.json)
cover source T⁴ absorption, expanded pair normals, the safe-integer edge and
asymmetric out-of-bound pair rollback. No cloud-radius bound was loosened.

Under a nonidentity action, the selected root and plane endpoint labels show
their exact **Base** descriptors plus approximate **shown** positions. Preview
values are marked **preview**; pending or failed actions retain accepted values,
and cancellation restores them. These conversions belong to rendering. Spaced
polynomial typography, such as `13x² − 84x + 162`, leaves the raw Lean label intact.

The current [model suite](../native/evidence/polar-snap-model-tests.txt) passed
**68 tests, zero failures**: 39 polynomial model, 12 action/Snap, 5 appearance
and 12 Exterior tests. The [unsigned build-for-testing](../native/evidence/polar-snap-build-for-testing.txt)
passed. The [focused UI run](../native/evidence/ui-tests-20261023T081658Z.txt)
passed **one test, zero failures, 112.941 seconds** on the existing task-owned
simulator. It used actual buttons with a diagnostics-only declared matrix
`M=(50,18,0,5)`, determinant 250; no gesture is claimed for this fixture.

All five screenshots were visually inspected:

1. [Declared counterexample](../native/evidence/screenshots/20261023T081658Z/001-polar-snap-01-declared-counterexample.png): unit root shown at `3.600 + 10.000i`, pair endpoints `−6.400, 13.600`, exact base identities retained.
2. [Polar T⁴ absorption](../native/evidence/screenshots/20261023T081658Z/002-polar-snap-02-t4-absorbed.png): selected `(1,−8,17)`, identity action and refreshed pair plane; Identity preserves the relabeling.
3. [Canonical source T⁴](../native/evidence/screenshots/20261023T081658Z/003-polar-snap-03-canonical-source-t4.png): `(13,20,34)` becomes `(13,−84,162)`, Δ `−1368`, explicitly hidden at R12; Identity retains it.
4. [Canonical source T](../native/evidence/screenshots/20261023T081658Z/004-polar-snap-04-canonical-source-t.png): `(13,−6,27)`, same discriminant.
5. [Reset](../native/evidence/screenshots/20261023T081658Z/005-polar-snap-05-reset.png): canonical `(1,−1,2)`, identity action, no pair.

The [raw app-only recording](../native/evidence/screenshots/20261023T081658Z/lean-starscape-polar-snap.mov)
and [capture hashes/timings](../native/evidence/screenshots/20261023T081658Z/captures.json)
are preserved. The [fresh receipt](../native/evidence/polar-snap-native-receipt.json)
hashes the changed sources, fixtures, model/build/UI logs and these captures.
This run verifies panel controls and displayed results on a simulator. Physical
input, actual gesture cancellation, free-space controller SL₂ action and native
Roots-window parity remain unverified or unimplemented as stated above.

The [reviewed 1080p export](../artifacts/videos/lean-starscape-native-polar-snap.mp4)
is H.264 video only, 76.20 seconds and 1,269,454 bytes. Actual frames at 2, 38
and 75 seconds were inspected, showing the transformed pair, hidden source T⁴
identity and Reset. [Export metadata](../artifacts/videos/lean-starscape-native-polar-snap-metadata.json)
records hashes, source receipt, exact conversion and inspection details. There
is no trim or speed change; frame-boundary duration rounding adds 30 milliseconds
relative to the raw MOV. No app sources changed for this export.
