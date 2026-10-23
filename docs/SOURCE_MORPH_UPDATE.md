# Source projection and live recropping — 23 October 2026

This checkpoint continues the same Starscape app from `1a8212f`. The primary
entry remains `/polynomial/` (also served at `/`). The separate canonical Farey
checkout and port 8778 were not modified.

## What changed

Source depth mode now interpolates upper stars onto its screen, using the
source radial morph, cubic easing and size/opacity rules. Lower and exterior
stars remain in place. Screen visibility is independent of projection and its
height defaults to 0.6 × depth. Selected and paired identities survive recrops,
and their markers are independent of the primitive body catalogue. The roots
chart uses unprojected coordinates throughout the morph.

During a held Möbius drag, one bounded queue asks executable Lean for catalogues
at quantized preview matrices. A candidate can replace the rendered catalogue
without changing the accepted action. Escape, controller disconnect and stale
requests restore or preserve accepted state. Release accepts the exact rational
action and a matching catalogue together. There is at most one request in
flight, a replaceable pending request and a 150 ms minimum between starts.

Source starts at depth 16; the source website defaults to 48. Existing smaller
depths remain explicit extensions. No density increase is claimed as a
performance improvement. The cone uses source bounds +R/−0.3R. The cutting
plane reuses and clips our tessellation to the source bounds; this is a
renderer adaptation, not an identical mesh or a new proof.

## Browser interaction evidence

Actual DOM controls and mouse input were used in the supported in-app browser.
The main Chrome attachment still timed out while enabling focus emulation;
this is not a passed main-Chrome acceptance run. No new access was obtained.

- Source D16 identity: 4,406 buffered forms, 3,725 upper and 681 other.
- Unit/pair `(1,0,1)/(1,1,1)`: selected Y is 2, 5.8 and 9.6 at projection
  0, 0.5 and 1; the upper-half-plane roots and exact signed labels stay fixed.
- Exact D5 matrix `[3,1,1,2]`: the unit has exact image `(5,−10,10)/5`,
  discriminant −4 and root 1+i; paired endpoints are −2 and 4/3.
- Held roots drag: rendered catalogue 4,219; accepted catalogue still 4,406
  and accepted matrix still D5. Escape restores 4,406. Releasing the same
  gesture accepts `[16193,8203,5184,8801]` and 4,219 forms. The selected exact
  image is `(104331457,−312278230,329502458)/99990241`.
- Actual midpoint hover/click selects the visible unit; a lower selection
  stays at `(0,−2,0)` as the screen height changes. A 390×844 responsive roots
  drag accepts a new matrix; Reset returns the 480-form canonical R6 scene.
- Synthetic WebXR trigger-held motion renders a 4,234-form preview while
  retaining 4,406 accepted forms. Release accepts `[10937,1568,1568,9368]`;
  disconnect during the next preview rolls back to that exact accepted state.
  These are production raycasts/handlers under an emulator, not headset input.

The D16 desktop scene measured a median 16.7 ms / p90 17.9 ms interval over
60 frames on the M4 Max in-app browser. It used 13 world draw calls and about
0.3 MB of counted cloud/point CPU buffers. This is a vsync-capped desktop
sample, not a VR frame-rate guarantee or a density stress test.

## Native interaction and matched screenshots

The current unsigned simulator build and **141 model tests** pass. The refreshed
`20261023T111156Z` UI sequence passed one test with zero failures in 144.799 s.
Actual input exercised projection 0/.5/1, animated Project/Lift, D5, a Roots
swipe accepted by Lean, shared pairing cancellation, closing Roots, Reset and
leaving immersion. The swipe accepted `[22885,10556,14031,10842]` and 4,229 forms.
That gesture differs from the browser drag, so its matrix is not a same-input
cross-client fixture.

The separate `20261023T110630Z` test **failed its held-preview assertion** after
58.407 s. Main-panel Pair next followed by an actual Roots point tap succeeded.
The subsequent drag delivered two changed callbacks and one release, accepting
`[16567,9107,16025,14845]` and 4,203 forms while preserving the unit and pair.
It observed zero completed interim catalogues. The test remains unchanged:
release acceptance is not continuous-preview acceptance. Available diagnostics
do not establish whether a preview request reached transport before release
cancelled it. Model queue/cancellation tests do not resolve this UI failure.

These corresponding states were visually inspected, rather than inferred from
their mathematical fixtures:

| State | Browser | Native | Observation |
| --- | --- | --- | --- |
| D16 Identity, unit/pair, projection .5 | [Browser .5](../artifacts/screenshots/morph-final-20261023/03-identity-p50.png) | [Native .5](../native/evidence/screenshots/20261023T111156Z/002-source-morph-01-p50-unit-pair.png) | Selected/paired markers move between lattice and screen; cone, plane and lower cloud persist. Native visible upper density and camera framing differ. |
| Same identities and action, projection 1 | [Browser 1](../artifacts/screenshots/morph-final-20261023/02-identity-p100.png) | [Native 1](../native/evidence/screenshots/20261023T111156Z/003-source-morph-02-p100-animated-unit-pair.png) | Markers reach the disk in both. The native disk looks much sparser despite positive body/instance counts; projected-body visual parity is unresolved. |
| D5, same signed pair and UHP roots | [Browser D5](../artifacts/screenshots/morph-final-20261023/12-production-source-d5.png) | [Native D5](../native/evidence/screenshots/20261023T111156Z/004-source-morph-03-d5-p100-linked-roots.png) | Both show root 1+i and endpoints −2, 4/3 with retained labels. World projection differs (.5 versus 1), so this is a roots-only comparison. Native Roots covers part of 3D; browser panes are adjacent. |

Native uses physical spheres and 16-level endpoint opacity bins. Numerical
source-radius/alpha tests do not certify their visible footprint or blending.
The main control panel is moved left and Roots now fits inside the guest frame;
closing Roots reveals the full scene. This improves framing but does not achieve
simultaneous-view layout parity. Recorded CPU update timings are single update
measurements, not native frame-rate or headset-performance evidence.

A persistent Origin collision shell and root-local drag mapping are implemented
and model-tested. Actual host input could not begin: supported Device Hub
attachment timed out twice with `timeoutReached −10005` before returning its UI.
No permission denial or host input occurred. The foreground was released to the
canonical owner. Origin free-space dragging and sphere-based spatial pairing
therefore remain unverified in this app; the canonical owner's evidence does
not substitute for a test here.

## Verification boundary

The **17 general kernel-checked integer laws are unchanged**. Executable Lean
enumerates exact signed catalogues, computes discriminants and planes, and
accepts rational transformations. Sampled preview catalogues use that same
executable; a floating-point animation frame is not an exact Lean result.

The 48-case source fixture (eight profiles × two matrices × three progress values) independently evaluates the inspected source
functions. It tests numerical positions, sizes, opacity and marker rules; it
is not kernel evidence. An additional 44 independently evaluated root-rendering
cases and six source-picker cases cover signed rings, exact plane emphasis,
alpha thresholds and hit ranking. The native and browser renderers use their own
floating-point matrices, shaders/materials, clipping, hit testing and camera
code. Correct transport or successful Lean computation does not establish
renderer correctness. See [the source audit](source-projection-morph-audit.md).

## Remaining acceptance

Native continuous held-preview recropping, projected-body visible density,
free-space input, sphere-based pairing and pointer hover remain acceptance gaps.
Physical Vision Pro/Quest input, tracking, comfort and frame rate remain
unverified. Source theme/model/hash-URL completeness, continuous Whole/eye
transitions and additional source decorations remain gaps. Source depth
recropping and projection are no longer intentionally different math.

## Reproduce and inspect

Run `python3 server.py --port 8787` from the repository with its existing
Lean build, then open [the local app](http://127.0.0.1:8787/polynomial/).
Choose Source depth, select the unit and pair `(1,1,1)`, scrub projection,
then drag the upper-half-plane chart. Try Escape during a held drag, then
repeat and release. The page marks preview and accepted state separately.

- [160-test browser receipt](../artifacts/source-morph-node-tests.txt)
- [26-test bridge / 121-request catalogue receipt](../artifacts/source-morph-bridge-tests.txt)
- [Browser interaction states and video hashes](../artifacts/source-morph-browser-receipt.json)
- [Silent browser clip](../artifacts/videos/lean-starscape-browser-morph.mp4)
- [Silent emulated-WebXR clip](../artifacts/videos/lean-starscape-webxr-morph.mp4)
- [Native tests, source hashes and input limitations](../native/evidence/source-morph-native-receipt.json)
- [Silent current native morph/Roots clip](../artifacts/videos/lean-starscape-native-source-morph.mp4)
- [Silent native held-preview diagnostic clip](../artifacts/videos/lean-starscape-native-source-input.mp4)

The browser clip records the actual 3D and roots canvases; DOM controls are
excluded. The XR clip identifies synthetic input in its evidence stripe.
Decoded frames were inspected and all four files have no audio stream.
