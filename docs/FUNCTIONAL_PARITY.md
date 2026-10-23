# Lean-backed Starscape functional parity

The goal is the **same polynomial Starscape functionality implemented with Lean**:
signed coefficient points, linked roots and spatial views, cutting planes,
selection, Möbius motion and integer Snap. The signed coefficient double cone in
this project's Polynomial Room implements much of that contract, with the gaps
and evidence below. Its IAB desktop and synthetic WebXR checks establish partial
functional parity. They do not establish physical headset acceptance or complete
source-viewer parity. The exterior-algebra room is a separate example and does
not satisfy or replace this Starscape goal.

The [source-catalogue continuation](SOURCE_CATALOGUE_UPDATE.md) supersedes the
older crop and density statuses below: separate Source depth and Canonical ball
modes are implemented, with release-only recropping, explicit caps, and native
R24 batching. The dated rows remain evidence of their own runs.

The dated [validation receipt](POLYNOMIAL_VALIDATION.md) distinguishes exact-data
tests, real browser interaction, synthetic XR and native simulator results.
The [linked-roots continuation](LINKED_ROOTS_UPDATE.md) adds current simultaneous
browser panes, native UHP taps/drag and matched D5 visual inspection; earlier
receipts below retain their dates and source pins.

The canonical application also has a separate rational Farey L/R page at
`Farey/WebXR/farey.html`. Its mediants, continued fractions, projected selection,
and lessons are not polynomial operations. This polynomial contract does not
claim parity for that second route.

## Frozen reference and evidence

The original base-cloud reference capture used `FareyVision`, branch
`codex/farey-void-demo`, at
`ca809d2975a37a318a425e4b9dd73560b07faf39`. Its browser package is **0.14.0**;
`starscape.js` last changed in
`7be989f53f3ee73fa1e785ec8cd7d38fb12d4382`. The committed native target is
**0.11.0 (14)**. The older `8b32d7a` browser pin remains the provenance of the
previously borrowed Exterior Room helpers, not the baseline for this contract.

The [machine-readable fixtures](../fixtures/polynomial-contract.json) contain
18 pinned source hashes, 13 point cases, all eight browser crop counts and
ordered-cloud hashes, 10 pair cases, eight plane-normal cases, appearance data,
and interaction expectations. Browser mathematical outputs were evaluated by
importing the canonical pure modules read-only. Their bytes matched the pinned
commit. No browser or native UI was operated during this reconnaissance.

The canonical pure-function suites passed **24 tests, zero failures**:
`node --test Farey/WebXR/starscape-core.test.js Farey/WebXR/lattice.test.js
Farey/WebXR/appearance.test.js Farey/WebXR/pair-plane.test.js` from the canonical
repository root. Fixture JSON, all 13 point identities, eight category totals,
and rational-denominator consistency were also checked. These validate the
reference capture, not the new Lean implementation.

The canonical owner changed files during inspection. In particular,
`CuttingPlane.swift` gained an uncommitted `realRootDescription` extension and
`StarscapeControls.swift` began using it. The fixture records the observed
working-tree hashes separately from the committed hashes. Those added root
descriptions are not represented as committed `ca809d2` behavior. Existing
canonical UI tests, capture scripts, screenshots, and parity files were not
modified by this work.

Paths and line references below are relative to canonical `Farey/` at that pin.
The fixture is an independent implementation's regression oracle, not a proof
certificate. Preserve the canonical GPL notices and Katherine Stange
attribution when adapting code. The new Lean implementation and its proofs
must be attributed separately.

The canonical owner subsequently supplied the Möbius mathematical contract at
`63ad115422ab1141ca6d06732572385414b7a5cf`, then browser 0.15 Snap/Identity
behavior at `6fea557bb0d0c786bed5223dc631cb1c06e94f16`. The former remains the
byte-identical `mobius.js` provenance. A later audit against the canonical
notebook and `2cd549a45ddb6056cf3596404754d96ad9e7132c` found and corrected the
old entrywise Snap ranking: `mobius-snap.js` now uses the source-compatible
**residual polar-angle** criterion, its tie tolerance and canonical sign.
The [34 shared fixtures](../native/Resources/polynomial-polar-snap-cases.json)
were executed from that pinned canonical JavaScript and independently consumed
by browser tests. The recorded vertical-motion counterexample chooses `T⁴`,
where the old rule chose `T⁴S`. These are numerical proposal tests; Lean still
computes the exact accepted action separately. The historical 0.15.0 fixtures
remain historical evidence, not the latest Snap oracle.

The new upper-half-plane chart also follows `2cd549a`'s `roots-pane.js` fit,
coordinates, radius and picking rules. The notebook records browser 0.15.4's
behavior update and 0.15.5's packaging fix; neither means the older base capture
contained those features. All adaptations preserve the Harriss, Stange and
Trettel attribution. These later pins do not change the base cloud's `ca809d2`
fixture hashes. New Lean proofs, transport validation and UI staging belong to
this project.

## Implemented route and observed acceptance

Browser: `http://127.0.0.1:8787/polynomial/`. Native: the separate
`PolynomialRoom` scheme described in [native/README.md](../native/README.md).
Both consume the Mac's compiled Lean service at `/api/polynomial`; native also
has an explicitly labelled bundled Lean export for initial R6 playback.

| Behavior | Browser evidence | Native status / difference |
| --- | --- | --- |
| Exact signed identity, hidden multiple and negative point | Real IAB controls selected `(2,-2,4)` hidden at R6 and `(-1,1,-2)`; upper-only retained the negative identity while displaying 55 points. | Implemented and model-tested; exact-data provenance is live Lean or labelled bundled export. |
| Paired plane and projection | IAB form selection and synthetic controller rays both formed `(1,0,1)/(1,1,1)`. | The final base simulator run `055100Z` passed the same fixture, projection and later Reset checks. |
| Origin, Inhabit and Overview | IAB controls and pointer look observed; synthetic XR Origin/Overview and desktop-Origin restoration observed. | One-time head-relative placement is implemented. Native and browser Inhabit offsets differ. |
| Appearance and Reset | IAB Reset restored the base scene while retaining reference palette, size 2.5 and plane focus. The later R6 paired D5 sequence covers fade on/off and projection. | Final base simulator run passed palette, size, fade and Reset retaining these preferences; controls remain usable after Inhabit. The later 065009Z run verifies transformed plane fade and fixed cone guides through four matched captures; see the validation receipt. |
| Dense cloud | Canonical R96 retains 1,852,484 forms. Source depth96 renders 769,788 with upper cap declared; source depth24 has 14,966. These catalogues have different sets and ordering. | R24 now renders 28,832 canonical forms using shared sphere instances; source mode uses the same exact catalogue service with a 40,000-form budget. Browser full-range parity remains missing. |
| Linked roots chart | Actual IAB UHP Shift-click formed `(1,0,1)/(1,1,1)` with 22 members; its semicircle was visible. Direct UHP drag committed `[10741,903,912,9387]`, determinant 100002231. D5 displayed the unit root `1+i` and endpoints `−2, 1.333`. Earlier root-drag receipts used Klein and remain separate. | A separate linked UHP Roots window now supports actual tap/pair, Move swipe, Pan swipe, zoom/Fit and reopening. Final simulator run `092615Z` passed; D5 roots/geodesic and 3D were visually compared with browser. Earlier Klein swipe evidence remains separate. |
| Hover and selection | Browser owner observed a real pointer hover showing `x²−x+2`; synthetic rays selected and paired actual stars. | Cancellable Lean-backed Roots hover inspector implemented and model-tested; actual pointer hover unverified because visionOS XCUI excludes it. Actual Roots tap/pair passed. Spatial pair input and explicit controller bindings remain missing; physical gaze/pinch unverified. |
| XR controls | 32 in-world buttons implemented, including source Catalogue and Dust. Actual synthetic rays exercised both new controls and Whole/Exact move/Snap/exit in source mode. Separate synthetic tests now cover Exact move, T/T inverse, Identity, Snap, trigger drag/release and disconnect rollback, alongside the base controls; the full set is not exhaustively tested. | Native controls use SwiftUI/RealityKit rather than this controller panel. Neither route has physical-headset acceptance. |
| Source SL₂ motion | Exact rational action and atomic integer Snap are implemented. IAB directly dragged 2D roots and 3D Origin, and the R96 requested seed snapped to T; final regression coverage is tracked in the validation receipt. | Current model tests pass 88 cases, and `092615Z` verifies an actual UHP swipe accepted as `[24959,10694,18805,12064]`. The earlier polar-Snap model receipt passed 68 tests. Focused simulator run `081658Z` passed one test in 112.941s: declared action, paired T⁴ absorption, requested seed `(13,-84,162)` hidden with Δ−1368, Identity/source T/Reset and transformed readouts. The earlier `070446Z` bounded-target swipe produced callbacks and an accepted exact matrix, preserving both discriminants and plane incidence. Earlier coordinate press-drags remain unresolved; physical hands and native free-space dragging are unverified. |

The exact shared comparison is R6, full signed cloud, first `(1,0,1)` and second
`(1,1,1)`: canonical normal `(1,0,-1)`, plane **`2a − 2c = 0`**, endpoints
**`−1` and `1`**, and **22 displayed interior triples**. Multiples and both signs
are counted. The [browser pair](../artifacts/screenshots/polynomial-20261023/02-plane-projection.png)
and [native pair with projection](../native/evidence/screenshots/20261023T055100Z/007-poly-04-pair-projection.png)
show that same state, amber plane/member emphasis and projected disk. Camera
pose, scale, point shape, materials and control placement differ; this is not
pixel-identical rendering.

The preceding IAB UHP checkpoint used real pointer input: `(824,306)→(900,260)`
produced the accepted matrix above. A vertical drag `(676,639)→(676,306)`
produced `[31623,11384,0,3162]`, determinant `99991926`; actual Snap then chose
`T⁴`, relabelled the requested seed to **`(13,-84,162)`**, and Identity retained
that label. The [UI states](../artifacts/screenshots/starscape-parity-20261023/ui-states.json),
[shift-pair capture](../artifacts/screenshots/starscape-parity-20261023/03-final-shift-pair.png)
and [D5 readout capture](../artifacts/screenshots/starscape-parity-20261023/06-d5-pair-readouts.png)
record this pass.
This establishes those actions, not exhaustive acceptance of every new chart
state. The fresh [native polar-Snap receipt](../native/evidence/polar-snap-native-receipt.json)
uses actual controls with an explicitly declared diagnostic matrix; it is not
a new native drag recording. Main Chrome allowed a read, but subsequent reload
and rebind attempts timed out after 30 seconds; these fresh browser interactions
were performed in IAB.

## Exact mathematical interface

| Operation | Required semantics | Canonical source |
| --- | --- | --- |
| Inspect signed polynomial | Keep the exact integer triple `(a,b,c)` for `ax²+bx+c`. Neither sign nor common divisor is removed from selection, hover, position, or polynomial text. | `WebXR/starscape-core.js:4`; native `Packages/FareyCore/Sources/FareyCore/Starscape.swift:4` |
| Display coordinates | `(X,Y,Z)=(-b,a+c,c-a)`. Consequently `Δ=b²-4ac=X²+Z²-Y²`; `Y` and `Z` have equal parity. This transformed lattice has covolume 2. | `WebXR/starscape-core.js:16`; `WebXR/lattice.js:3` |
| Classify | For nonzero triples: `Δ=0` is null, `Δ>0` exterior, and `Δ<0` is upper when `a>0`, lower otherwise. The zero triple is excluded from the cloud and selection. | `WebXR/starscape-core.js:34`; native `CoefficientBall.swift:10` |
| Enumerate ball | Include every nonzero integer triple satisfying `b²+2a²+2c²≤R²`, including all multiples and sign partners. Upper-only adds `a>0 ∧ Δ<0`. Active browser order is ascending `a`, then `c`, then `b`. | `WebXR/lattice.js:12` |
| Positive representative | For `Δ<0`, negate a lower triple only for root/projection calculations. Keep its signed selected identity. Boundary/exterior triples have no interior representative. | `WebXR/starscape-core.js:52` |
| Radial projection | At `h=4`, project the positive representative to `4(-b,a+c,c-a)/(a+c)`. Normalized Klein coordinates are `(-b/(a+c),(c-a)/(a+c))`. Null/exterior/zero have no interior image. | `WebXR/starscape-core.js:17`; `WebXR/index.html:85` |
| Upper root | For the positive representative, `-b/(2a)+i√(-Δ)/(2a)`. The browser's three-decimal text is presentation, not an exact algebraic number. | `WebXR/starscape-core.js:21` |
| Exterior plane | An exterior normal `(A,B,C)` defines `-2Ca+Bb-2Ac=0`. Canonicalize the derived normal by gcd and first-nonzero-positive sign. | `WebXR/pair-plane.js:48` |
| Interior pair plane | Require two negative-discriminant triples. Cross their duals `(-2c,b,-2a)`, then canonicalize the normal. Reject proportional directions, including negative partners. Do not change either selected triple. | `WebXR/pair-plane.js:32` |
| Plane endpoints | Exact rational/surd roots of `At²+Bt+C`; if `A=0`, include its finite root and projective `∞`. Keep infinity symbolic in JSON. | `WebXR/pair-plane.js:49` |
| Necklace | Displayed points with `Δ<0` and exact plane membership. Count triples, including multiples and both signs; do not count distinct roots instead. | `WebXR/pair-plane.js:102`; `WebXR/starscape.js:113` |

Linear and constant affine polynomials need careful wording: a nonzero linear
polynomial has one finite root, and a nonzero constant has none. The extra root
at infinity is a **binary-quadratic/projective** convention. Do not silently
turn the canonical generic boundary/exterior captions into an affine-root claim.

| Fixture | Expected result |
| --- | --- |
| `(1,-1,2)` | `x²−x+2`, `Δ=-7`, position `(1,3,1)`, image `(4/3,4,4/3)`, root `(1+i√7)/2` |
| `(2,-2,4)` | `2x²−2x+4`, `Δ=-28`, position `(2,6,2)`; same image/root, different magnitude/color; outside R6 because squared radius is 44 |
| `(-1,1,-2)` | `−x²+x−2`, lower position `(-1,-3,-1)`; same image/root, signed identity retained |
| `(1,2,1)` | `Δ=0`, null; no interior image |
| `(1,3,1)` | `Δ=5`, exterior; it defines its own cutting plane |
| `(1,0,1)` paired with `(1,1,1)` | Normal `(1,0,-1)`, equation `2a −2c = 0`, endpoints `-1,1` |
| `(1,0,1)` paired with `(2,1,1)` | Normal `(1,-2,-1)`, endpoints `1−√2,1+√2` |
| `(1,0,1)` paired with `(1,0,4)` | Normal `(0,1,0)`, equation `b=0`, endpoints `0,∞` |
| `(1,0,1)` paired with `(-2,0,-2)` | Reject same projective direction; retain the previous valid state |

## Selection and state behavior

Browser launch selects `(1,-1,2)` with radius 6, whole signed lattice, cone on,
projection off, lower-half coloring off, Viridis, star size 1, plane focus off,
no second selection, and Overview (`WebXR/starscape.js:14`, `index.html:72`).

| Action | Observable contract |
| --- | --- |
| Primary selection | Set the exact signed triple and clear the pair/error; preserve camera placement. |
| Next | Cycle `(1,-1,2)`, `(2,-2,4)`, `(2,1,1)`, `(1,0,1)`, `(3,2,2)`, `(-1,1,-2)`, `(1,2,1)`, `(1,3,1)`. Unknown current selection advances to the first. |
| Crop/filter change | Retain selected identity even when hidden. State the hidden condition; omit its geometry marker. Do not clamp it to the crop edge or replace it. |
| Enter coefficients at original `ca809d2` reference | Browser requires exactly three signed integer tokens and a currently shown nonzero point. Rejection preserves selection. Native validates radius but permits entry hidden by its upper-only filter. |
| Current Lean Starscape coefficient entry | Accept exactly three safe integers within ±1024, excluding zero. A valid selection outside the current crop/filter retains its exact identity and is explicitly marked hidden; it is not clamped or replaced. Failed inspection preserves the prior state. This deliberately differs from the original reference's crop-limited text entry. |
| Pair | Shift-click or enter a second interior point. A successful pair keeps both signed identities. Invalid second input preserves the existing selection/pair and reports an error. |
| Exterior selection | Without a pair, automatically use the exterior triple's canonicalized Lorentz normal. Null/interior single selections have no plane. |
| Projection toggle | Show the `Y=4` disk, radial images of every displayed interior triple, selected ray/image, and current plane's Klein chord. Coincident images do not collapse the source cloud. |
| Reset | Return to Overview, `(1,-1,2)`, R6, whole=true, lower-color=false, projection=false, cone=true; clear pair/errors. **Browser Reset preserves palette, star-size, and plane-focus settings.** |

The second Next example is intentionally hidden at default R6. The original
reference's form rejects entering that point at R6, while Next selects it and
displays the hidden status. Current Lean Starscape also permits direct entry of
that hidden identity within its independent bound. Inhabit is disabled for a hidden selection unless already in egocentric
mode. Sources: `WebXR/starscape.js:130`, `:180`, `:343`, `:354`; native
`Sources/FareyVisionApp.swift:45`, `:54`, `:64`, `:92`, `:102`.

## Semantic color and size

Color derives from the **actual** discriminant, not the primitive triple's.
Interior palette position is `clamp(log(|Δ|/3)/log(240/3),0,1)`, independent of
crop radius. Default Viridis uses its interval `[0.2,1]`; boundary is `#f4f2ff`,
exterior `#7a5230`, and lower interior `#4d3a46`. Lower coloring is an opt-in
extension applying the same magnitude ramp to the negative partner. The browser
also offers six Stange-reference anchors interpolated in OKLab; canonical
native exposes only the default palette (`WebXR/appearance.js:4`, `:49`).

Browser glyph radius starts at `.013` world units times the size slider
(`.4…2.5`, default 1). Outside Origin, nonprimitive ramp-colored interior
points use `.72`; upper-interior plane members get `1.35` emphasis. In Origin,
both interiors instead use `.4|Δ|^(1/4)/√|a+c|`; null/exterior remain factor 1.
Perspective converts radius to pixels. Below 1px, keep a 1px footprint and dim
by the squared ratio; above 2.5px, grow by a cube root and cap at 9px. Selected
outlines add 1.25px (`WebXR/appearance.js:72`).

Overview fog dims by up to 55%; egocentric/XR disables it. Plane focus fades
nonmembers by Euclidean display distance to a 12% floor across `.5R`, exempting
the selected point. It does not alter colors, coefficients, or exact membership.
The browser cloud is unlit discs; native uses unlit spheres of physical radius
`.0075m`, with semantic radius factors but no browser pixel clamp. Native has
no star-size slider, alternate palette control, or plane-focus toggle at this
pin. These are presentation differences, not evidence of different mathematics.

## Transformations and spatial modes

The pinned `ca809d2` route implements display-coordinate mapping, radial
projection and Euclidean camera/object placement. Its translated pair fixture
is a second input, not an exposed `z↦z+1` operation. That limited implementation
does not cover the source viewer's SL₂(ℝ) motion during Origin drag.

The later `63ad115` contract specifies matrices `[p,q,r,s]`, root action
`z↦(pz+q)/(rz+s)`, and form pushforward `Q∘g⁻¹`:

```text
a′ = s²a − rsb + r²c
b′ = −2qsa + (ps+qr)b − 2prc
c′ = q²a − pqb + p²c
```

Drag steps compose a hyperbolic transvection on the left and normalize to
determinant one. General real transforms move drawn positions while preserving
the base integer identities; integer determinant-one matrices also have an
exact integer coefficient image. The implemented browser action has an explicit
boundary: continuous pointer/controller motion is a numerical preview; release
quantizes a bounded integer representative `M`, and compiled Lean computes the
exact rational action `J(M)/det(M)`. Only its matching accepted receipt updates
the committed action. Failed and stale requests retain the previous accepted
state. For `M=(3,1,1,2)`, determinant 5, `(1,-1,2)` maps to `(8,-23,22)/5`.

Generators compose on the **left**. An exact integral determinant-one action
is absorbed only after Lean computes both selected images, both new signed
identities are inspected within the ±1024 coefficient bound, and any pair plane
is prepared. An error at any stage retains the prior selection, pair and action.
Non-null integer images alone do not establish an integral SL₂ action. Snap
uses the current pinned residual polar-angle candidate-selection algorithm;
Lean checks the
chosen integer action and images, not that the candidate is globally nearest.
Identity clears the action and retains absorbed integer labels. The user
fixture is `(13,20,34) → T → (13,-6,27)`, with `Δ=-1368` unchanged.
The larger identity bound is separate from the unchanged R96 cloud bound:
an exact relabelled selection may be valid and explicitly hidden. Existing ±96
rejection receipts describe the earlier transport limit and do not test the new
±1024 boundary; fresh boundary/UI acceptance is tracked separately.

The primary 2D chart is now the canonical **upper half-plane**, with an optional
Klein disk. It draws every accepted upper-interior identity at
`x = X′/(Y′−Z′)`, `y = √(-Δ)/|Y′−Z′|`; its radius is
`.06·σ·scale/|Y′−Z′| = .03·σ·scale/a′`. A k-times form therefore has 1/k radius.
It uses the source's .6px minimum footprint with dimming, omits radii below
.08px, and uses squares below 1.5px and circles above. Like the source, larger
stars draw last so faint overlapping copies all contribute. A stable four-pass
radix order over the transformed Float32 denominators supplies the GPU index
buffer; it is recomputed on geometry changes, with no depth rejection of faint
stars. Float32 positions/order and GPU rasterization remain numerical renderer
approximations, not a pixel-equivalence claim. Upper-only
2D display does not remove signed lower forms from the accepted 3D cloud.

The optional Klein chart retains both signed copies. Its radius is
proportional to `|Δ|^(1/4)/|a′+c′|^(3/2)`, so a k-times form has 1/k radius before
pixel clamping, and it uses the same minimum-pixel dimming as the 3D view.
Colors remain based on each signed form's original accepted discriminant;
all appropriate interior identities and multiples get GPU vertices. Plane fade
uses the transformed display normal. Picking scans the transformed geometry.
Finite UHP plane endpoints form a semicircle; one infinite endpoint forms a
vertical line. Chart motion, square roots, tessellation and picking are renderer
calculations, not additional exact Lean computations. Existing UI evidence for
Klein does not automatically validate UHP; the fresh UHP actions above are
separately observed.
The [numerical source comparison](../artifacts/uhp-numerical-audit/README.md)
checks all 32 visible R6/D5 reference roots within 0.000018 CSS pixels. A separate
[bounded R96 CPU benchmark](../artifacts/uhp-numerical-audit/order-benchmark.json)
checks all 270,202 upper vertices across five action states: stable ordering took
2.28–7.45ms and position fill plus ordering took 3.51–10.21ms, using 3,243,448
bytes for index/order storage. These timings exclude GPU work, the rest of the
scene update and input/display latency; they are not a frame-rate claim.

Both views allow R96 without sampling; dense preview buffers update at most
ten times per second. The **base crop remains fixed**, as in the inspected
canonical Farey action path. Dynamic enumeration for a transformed viewport is
not implemented; a selected form can therefore move outside the displayed base
crop after integer absorption. Full original-source parity is not claimed. Camera
orbit/look and algebraic drag are explicit separate modes. See the
[source-action notes](source-drag-proposal.md) and
[acceptance receipt](POLYNOMIAL_VALIDATION.md).

| Mode | Browser implementation | Native implementation |
| --- | --- | --- |
| Overview | World center `(0,1.4,-3.1)`, scale `.16`; camera offset `(2.4,1.5,4.6)·max(1,R/8)`, FOV45, near `.05`. Orbit/pan/zoom remain user-controlled. Other side rotates 60° about display Y. | Stationary center `(0,1.4,-3.1)`, physical ball radius `.96m`, scale `.96/R`. Three fixed object views approximate browser framing. |
| Inhabit | Save Overview once; eye is selected displayed position plus world offset `(.10,.12,.10)`, FOV45, near `.008`; initially aim level toward the origin. | Place the selected point `(0,-.08,-.35)m` relative to the one-time head-center anchor. |
| Origin | Eye exactly at coefficient origin; FOV100; initially look along +Y. Up/level/down presets and mouse-look can inspect either nappe. Zero is not selectable and has no radial image. | One-time head-center anchor; rotate object by `Rx(-π/2)` for upper or `Rx(+π/2)` for lower. Nappe flip retains that anchor; an explicit new Origin press recenters. |
| Return | Inhabit toggles back to the saved Overview camera/projection. Home leaves egocentric mode and resets framing. Reset returns to default Overview. | Explicit Overview restores stationary placement; exiting the immersive space also resets placement. |

Selecting a new point while inhabiting must not move the eye/anchor. Desktop
W/A/S/D moves forward/back/left/right; Q/E moves down/up, at `.12m` per event.
Drag uses yaw/pitch in right-handed Euler YXZ at `.004rad/px`, pitch bounded to
`±π/2`. The camera plane readout is display ZX/YZ/XY, not coefficient planes.
Sources: `WebXR/starscape.js:290`, `:393`, `camera-planes.js:4`; native
`Sources/StarscapeRenderer.swift:19`, `:43`, `:61`, `:271`.

## Desktop, hover, and controller equivalents

| Function | Existing canonical input and behavior | Separate Lean route acceptance |
| --- | --- | --- |
| Pick point | A primary-pointer tap moving at most 5px selects the nearest center within about 10 CSS pixels; angle ties prefer nearer depth. | Same selected triple as the canonical rule, including signed multiples. |
| Hover | Exact signed polynomial above the hit point; no selection, pairing, or camera mutation. Dense results are valid only for the exact pointer, canvas rectangle, camera pose/projection, and lattice generation. | No stale or primitive-reduced polynomial labels. Clear on pointer leave/cancel, camera/crop changes, and XR entry/exit. |
| XR aim/select | Two controller rays; cyan hover rings and per-hand signed polynomial/discriminant readout. Trigger recomputes the current ray. In-world button hits take priority; otherwise use angular radius `.02rad`. | The visible per-hand preview must identify its own controller. Selection uses current input, not an old worker answer. |
| Existing XR buttons | Next, Projection, Reset, Exit. Current selection and plane equation appear in the world readout. | These four actions must work without leaving immersion. |
| Additional controller equivalents | Canonical XR has no pair, crop/filter, Origin/Inhabit, palette/size, or plane-focus buttons. | Exposing these desktop actions in the Lean route is new parity work. Verify each action separately; do not call it existing canonical XR behavior. |
| Native selection | Spatial tap/accessibility activation of `coefficient:a:b:c` entities; no polynomial hover inspector at this pin. | Preserve exact named identity; native simulator/model tests do not establish physical gaze/pinch behavior. |

XR preview movement tolerance is `.001rad` or origin movement `.001×target
distance`; a trigger still recomputes even below that tolerance. At 50,000
points and above, hover scans use a worker with at most one outstanding request
per input slot. Late results from an old generation/session are discarded.
Worker failure falls back to the synchronous scan. Sources:
`WebXR/input.js:7`, `starscape.js:365`, `:395`, `:405`, `:417`, `:429`, `:480`;
`hover-queries.js:1`.

## Dense rendering and count fixtures

| Radius | All signed points | Upper only | Null | Exterior |
| --- | ---: | ---: | ---: | ---: |
| 4 | 128 | 14 | 12 | 88 |
| 6 | 480 | 55 | 24 | 346 |
| 8 | 1,060 | 134 | 36 | 756 |
| 10 | 2,100 | 275 | 48 | 1,502 |
| 12 | 3,608 | 484 | 56 | 2,584 |
| 24 | 28,832 | 4,096 | 136 | 20,504 |
| 48 | 231,348 | 33,518 | 316 | 163,996 |
| 96 | 1,852,484 | 270,202 | 736 | 1,311,344 |

Lower count equals upper count in every whole signed ball. The browser stores
packed Int16 coefficient triples and Float32 integer display positions, and
draws the base cloud in one `GL_POINTS` draw. Dense crops are explicit options;
there is no random sampling or repeated decorative sprite population. At the original capture native used one entity per point and capped R12.
The current Lean native renderer batches shared sphere instances and supports
R24, with a 40,000-form budget. R48/R96 remain a native gap. Sources: `WebXR/lattice.js:5`, `:37`,
`point-cloud.js:87`; native `CoefficientBall.swift:34`.

The table lists the UI's choices. The canonical JavaScript enumeration function
accepts integer radii 1 through 96; this project's Lean protocol accepts 4 through
96. Neither is limited to the menu values. The older canonical
`coefficientLattice` helper capped at 12 is not the active dense-rendering path.

The fixture hashes encode all triples in canonical order as little-endian
Int16. A Lean implementation may page or cache computation, but must preserve
the full set, deterministic ordering where required by indices, exact counts,
and stable identity across picking/rendering. Keep dense builds explicit and
bounded; measured timings and frame rates must name the surface and machine.

## Acceptance boundary

Use the fixture cases to compare Lean's exact fields with this independent
canonical oracle. Separately exercise selection, invalid input, hidden states,
pair failure recovery, crop changes, projection, view restoration, hover
freshness, Reset's documented subset, and every implemented controller action.
Checking one screenshot or replacing a JavaScript label with “Lean” does not
test these behaviors.

The service has 17 kernel-checked general integer laws: nine cover display
norm, Lorentz/discriminant identity, scaling/sign invariance, equivalent plane
tests and pair incidence; eight cover identity, returned row layout, determinant
composition, action composition, discriminant and incidence transport, scaling
and adjugate/inverse behavior. Enumeration, classification, gcd/sign handling,
projection ratios, root descriptors, plane normalization/endpoints and membership
are executable Lean outputs, checked against the independent fixtures. A live
response is not a fresh kernel proof certificate. Enumeration completeness,
normalization/radical routines, JSON and compiler/runtime execution are tested
rather than covered by those 17 laws. Sixteen explicit axiom audits use only
`propext`, `Classical.choice` and `Quot.sound`.

Native bundled data are generated by the actual executable and carry an export
receipt. Immediate browser hover labels format accepted coefficient triples;
color interpolation, floating-point root/image conversion, mesh sampling,
camera transforms, ray picking, shaders, transport and physical input remain
outside the mathematical proof boundary. See [the proof source](../lean/Polynomial/Proofs.lean)
and [service protocol](../lean/Polynomial/PROTOCOL.md).

Remaining acceptance includes unexercised XR controls/failure combinations,
native physical/free-space drag, spatial pairing, broader dense hover/transform
freshness and actual headset input, compositor behavior and comfort. Native
R48/R96 density, actual native hover and explicit controller bindings remain gaps.
Browser now shows simultaneous 3D/UHP panes at widths of at least 1,000 pixels;
native now has a separately movable UHP window. URL state sharing, other source
models and theme choices remain missing. Source recataloguing is now a separate
mode, documented in the [current update](SOURCE_CATALOGUE_UPDATE.md). Refresh
during continuous previews and the source projection morph remain gaps. Main
Chrome was rechecked by URL and its `Emulation.setFocusEmulationEnabled` command
timed out; IAB acceptance is explicitly a different browser surface.
