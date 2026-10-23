# Two-minute local demo

Run `./scripts/run.sh` from the repository, then open
[Lean Starscape](http://127.0.0.1:8787/). The compiler and all browser
assets are local. GitHub is a source/download link, not a live hosted app.

1. Start with `(1,−1,2)`, Δ = −7. Select **Next point** to show a multiple keeps
   its own signed polynomial identity, even when the current crop hides it.
2. Enter `(1,0,1)` and **Select**. Enter `(1,1,1)` and **Pair entered point**.
   The native Lean process returns `2a − 2c = 0`, endpoints −1 and 1, and 22 members
   in Canonical ball. Switch **Catalogue → Source depth**: the same signed pair
   remains, with 24 buffered plane members (10 with nonzero depth fade).
3. Use **Exact move** to show the same pair under D5. Source depth now has
   19 buffered plane members (9 with nonzero depth fade), shown unit root `1+i`,
   and endpoints approximately −2 and 1.333. Toggle **Project to Klein disk**
   for a radial overlay, then **Origin** to view it from the cone tip.
4. Drag the upper-half-plane roots (choose **2D roots** on a narrow screen).
   Release asks Lean to accept an exact
   rational action and recrop the source catalogue. **Escape** cancels a held drag. **Move forms**
   in 3D enters Origin and enables the corresponding geometry drag.
5. For the source Snap example, select `(13,20,34)` (it may be hidden by the crop).
   Apply **T**: the signed identity becomes `(13,−6,27)`, with Δ still −1368.
   **Identity** keeps that relabeling. A larger roots drag with **Snap on release**
   can absorb the same symmetry; see the [recording](../artifacts/videos/polynomial-roots-snap.mp4).

The plain-language claim is: **“These renderers interact with actual executable
Lean. General algebraic identities are kernel-checked; the scene, gestures and
transport are tested software.”** A live computation is not a freshly generated
kernel proof. Lean runs on the Mac; it is not embedded in the browser or visionOS.

For the native route, open `native/ExteriorRoom.xcodeproj`, choose
`PolynomialRoom`, and use the task-owned visionOS Simulator.
Use the same port-8787 bridge. The saved [native clip](../artifacts/videos/polynomial-native-simulator.mp4)
and [browser controller clip](../artifacts/videos/polynomial-controller-sequence.mp4)
are available if someone has no build environment. The latter uses synthetic
WebXR input and says so on screen; neither clip establishes physical-headset use.

Credit Katherine Stange and Harriss–Stange–Trettel for the polynomial-space
construction; credit this project separately for its new Lean implementation.
The earlier vector/wedge experiment remains archived at `/exterior/`; it is
separate work and does not establish Starscape parity.

See [the functional matrix](FUNCTIONAL_PARITY.md) before making a parity claim.
Native/browser layouts and camera placement differ; native currently caps the
cloud at R24/40,000 forms, while the browser explicitly supports R96. Source
depth has a different point set and reports its own caps; the original source
projection morph and continuously recropping preview remain gaps. Physical headset tests
and main Chrome connection acceptance are still separate gaps.
Native generators, Snap, directional movement and a direct disk element-swipe
have passed simulator UI tests. Choose Origin before moving inside the native
Klein disk; directional buttons remain the convenient fallback. The tested swipe
commits its last valid in-disk preview when the release leaves the disk. Physical
hand input and historical coordinate press-drag failures remain unverified.

Fresh silent comparison clips show Identity → D5 → fade off → projection:
[browser](../artifacts/videos/polynomial-browser-matched-render.mp4) and
[native](../artifacts/videos/polynomial-native-matched-render.mp4).
The [native swipe clip](../artifacts/videos/polynomial-native-klein-swipe.mp4)
shows actual simulator gesture delivery and Lean acceptance. These local clips
include the current transformed-plane fade and fixed cone guides.

The current [source-catalogue browser clip](../artifacts/videos/lean-starscape-source-catalogue.mp4)
shows both panes together through D5, real dragging, Snap and Identity.
[Current acceptance](SOURCE_CATALOGUE_UPDATE.md) lists source counts, exact
boundary discrepancies, matching native results and remaining input gaps.
