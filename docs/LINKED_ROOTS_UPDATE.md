# Linked roots parity — 2026-10-23

This continuation starts from published checkpoint `3771975`. It adds the
canonical simultaneous browser layout and a native upper-half-plane window.
It does not establish full source-viewer or physical-headset parity.

## Browser: actual interaction evidence

At widths of at least 1,000 CSS pixels, the 3D coefficient space and roots chart
are visible together. Narrower windows retain the 3D/2D switch. Both consume the
same accepted Lean cloud and action; chart pan/zoom only changes presentation.
Resizing preserves the roots chart's model-space center and scales with width.
Selection, pair and hover labels now render inside the roots canvas, including
right-edge flipping; they are present in app-only video.

The actual in-app browser sequence checked:

- Click the unit root, then Shift-click `(1,1,1)`: selected `(1,0,1)`, plane
  `2a−2c=0`, endpoints −1/1 and 22 R6 members in both views.
- Hover the distinct `(1,−1,2)` root: visible `x²−x+2` while the selected and
  paired labels remain visible.
- Drag the unit root: both canvases move and Lean accepts the quantized action.
  The exact image of the unit form was
  `(87088346,−52653054,122778125)/99997289`, with discriminant −4.
- Exact move `M=[3,1,1,2]`: selected root `1+i`, pair endpoints −2 and 4/3,
  same accepted plane in 3D and its semicircle in 2D.
- Shift-pan and wheel zoom preserve the accepted matrix. Widths 900 and 390
  exercise the compact layout; returning to 1280 restores both panes. Temporary
  viewport overrides were reset. The mobile chart starts below the attribution.
  Two additional regressions were fixed and exercised: Reset after resizing a
  hidden roots pane fits the current size, and resizing during a held root drag
  cancels the preview without submitting a matrix. Wheel zoom clears old hover.
- R24 draws all 28,832 accepted world points and 4,096 upper roots together;
  Exact move remains interactive. Historical R96 evidence predates this layout.
- Aimed synthetic XR controllers perform Exact move and Snap. Exit restores
  both wide panes, chart state and camera (position roundoff below `5e−16`).
  Compact roots-only entry/exit also restores its chosen pane.

[Screenshots and read-only states](../artifacts/screenshots/linked-roots-20261023/)
include the input sequence and accepted matrices. Early controller attempts
that loaded coordinates without pressing Aim are labelled as no-ops; only the
subsequent aimed trigger actions count as controller evidence.
[The browser receipt](../artifacts/linked-roots-browser-receipt.json) records
the final source/evidence hashes and checks the accepted states, including
the two resize regressions and both XR restoration routes.

[Silent paired browser video](../artifacts/videos/lean-starscape-linked-panes.mp4)
is 24.150 seconds, 1104×836, video-only. It captures the actual 3D and roots
canvases: the same unit/pair, D5, a real pointer drag, Snap and Identity. The
recorder composites independent canvas streams; it does not guarantee their
frames represent an identical instant. Its stripe labels desktop input, and
DOM controls are excluded. This clip's final Snap absorbs T into the unit/pair;
it is a different sequence from the earlier source vertical-drag T⁴ fixture.

The main Chrome connection was retried by the production URL and failed with
`Debugger unattached`. That supported route is unavailable; no new connection,
permissions or installation was attempted. All current browser acceptance is
from the in-app browser, not main Chrome.

## Native: actual linked-window input

The separate **Roots…** window now displays upper-half-plane roots from the
same accepted Lean cloud as RealityKit. Select, Pair, Move and Pan modes provide
tap selection, pairing, Möbius drag and chart-only movement. Labels, transformed
geodesics, plane fade, zoom and Fit are linked to the shared state. A busy or
preview state blocks stale spatial selection. Gesture completion is owned by
its originating surface, so a cancelled older window cannot commit another
surface's preview.

The final simulator run `20261023T092615Z` passed one UI test with zero failures
in 72.046 seconds. It used actual root taps to select `(1,0,1)` and pair
`(1,1,1)`, then checked the 22 members, D5, three Zoom out presses, a real Move
swipe, a real Pan swipe, zoom, Fit, Identity and closing/reopening with selection
retained. The swipe submitted `M=[24959,10694,18805,12064]`, determinant
`100004706`. A separate replay through executable Lean retained discriminants
−4 and −3. This is an accepted simulator gesture, not a preset standing in for
input. The 88 native model tests (76 polynomial, 12 preserved archive tests)
and unsigned simulator build also passed.

[Native receipt](../native/evidence/roots-native-receipt.json) ·
[Exact accepted-action replay](../native/evidence/roots-accepted-action-lean-replay.json) ·
[Silent native sequence](../artifacts/videos/lean-starscape-native-linked-roots.mp4)

The cancellable hover inspector is implemented and model-tested. Actual native
pointer hover remains **unverified**: the public visionOS XCUI route does not
expose hover. No simulated callback is presented as physical input evidence.
Native free-space SL₂ dragging, spatial pair input and explicit controller
bindings remain missing. Physical gaze/pinch and headset tracking are untested.

## Matched visual inspection

The [browser D5 capture](../artifacts/screenshots/linked-roots-20261023/11-d5-full-geodesic-matched.png)
and [native D5 capture](../native/evidence/screenshots/20261023T092615Z/003-roots-02-d5-linked-views.png)
were inspected at the same R6 unit/pair, matrix `[3,1,1,2]` and plane-fade-on
state. Both show the selected root `1+i`, the labelled pair, semicircle with
endpoints −2 and 4/3, fixed cone and transformed cutting plane. The browser
was wheeled out to zoom 0.5; native used three Zoom out presses. These framing
actions preserved the accepted matrix.

This closes the native UHP chart gap, not pixel equality: the native floating
window partly occludes its 3D scene, while browser panes are side by side.
Camera scale, point shapes, materials, label spacing and control placement
differ. Native and browser free drags use different input paths and yield
different accepted matrices; their drag screenshots are not same-state pairs.
The two clips also have different timing and are not a synchronized comparison.

## Exact source catalogue gap

The [source audit](source-recrop-audit.md) resolves what recropping actually
means. Original Starscape combines a padded upper trace catalogue with a
smaller ball of other forms; canonical Farey and this demo use a fixed signed
Euclidean ball. These differ even at identity (212 buffered source forms versus
480 canonical R6 forms). Source roots display primitive upper forms; the pinned
canonical contract retains multiples. The source also silently drops all other
forms when its scan bound exceeds 64, as the T⁶ fixture demonstrates.

Five source-run catalogues containing 1,035 points are independently checked by
exact integer predicates, order and hashes. This is specification evidence,
not a new Lean operation. No catalogue behavior was silently changed to make the
counts appear equal. Source-style recataloguing remains a functional gap.

## Proof boundary

The existing 17 kernel-checked integer laws are unchanged. No new theorem
claims that a canvas, hover, gesture, floating root coordinate, HTTP response or
RealityKit scene is correct. Lean supplies accepted exact identities, plane data
and rational action rows; the clients perform approximate display and input.
The browser changes pass 115 Node tests. The original-source catalogue audit is
a separate offline test, not a fallback used by the app.
