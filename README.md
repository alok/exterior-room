# Lean Starscape

**Starscape’s signed polynomial space, driven by executable Lean.**

This project implements Katherine Stange’s Starscape/Lattice interactions with
an exact Lean computation service, a browser/WebXR renderer, and a native
visionOS renderer. The target is the same Starscape functionality: signed
polynomial selection, linked roots and coefficient space, cutting planes,
Möbius transformations, Snap, and spatial navigation.

The app opens at **[http://127.0.0.1:8787](http://127.0.0.1:8787)**.
The existing `/polynomial/` URL and `PolynomialRoom` Xcode scheme remain valid.
The repository name stays `alok/exterior-room`; its earlier vector/wedge
experiment is preserved separately at `/exterior/` and is not part of the
Starscape parity claim.

![Linked Lean-backed coefficient space and roots](artifacts/screenshots/linked-roots-20261023/01-paired-wide.png)

## Run locally

Use Python 3.10+, Xcode Command Line Tools, and elan with the pinned Lean compiler:

```sh
elan toolchain install leanprover/lean4:v4.35.0-rc3
./scripts/run.sh
```

Open port **8787** and keep the terminal running. `Ctrl-C` stops the bridge.
The script builds the Lean executables sequentially; subsequent runs reuse their
artifacts. There are no external Lake/Python packages or browser CDN dependencies.
Three.js and OrbitControls are bundled. After compiler installation, the demo
runs without an external network connection. Node.js is only needed for tests.

With executables already built, `python3 server.py` starts the bridge directly.
It binds to loopback by default. Port 8778 is reserved for the separate canonical
FareyVision checkout and is rejected here. GitHub contains source and evidence;
this is **not a hosted app or Lean compiled to WebAssembly**.

## Try the same Starscape operations

1. Inspect the default signed form `(1,−1,2)`, Δ = −7. **Next point** preserves
   a multiple’s distinct coefficients even when it shares another form’s root.
2. Select `(1,0,1)`, enter `(1,1,1)`, then **Pair entered point**. Lean returns
   `2a − 2c = 0`, endpoints −1 and 1, and 22 interior triples in the R6 crop.
3. Toggle projection, **Origin**, **Other side**, **Inhabit**, and Overview.
   Change size, palette and plane fade; Reset retains appearance preferences.
4. Drag the roots pane (choose **2D roots** in a narrow window); **Move forms** enables the corresponding
   coefficient-space manipulation in Origin. The accepted action moves the
   points, roots and cutting plane together. **Exact move** gives a repeatable
   rational checkpoint.
5. **Snap** absorbs the chosen integer symmetry into the signed identities.
   **Identity** resets the viewing action while preserving those new labels.
   Select `(13,20,34)` and apply **T** to obtain `(13,−6,27)`. The source
   vertical-drag counterexample followed by **Snap** instead absorbs **T⁴**,
   giving `(13,−84,162)`, still with Δ = −1368. Exact identities may be outside
   the displayed crop; the app retains them and explicitly marks them hidden.

[Two-minute guide](docs/SHOWCASE.md) · [behavior/parity matrix](docs/FUNCTIONAL_PARITY.md)

## What matches, and what is still missing

The [linked-roots update](docs/LINKED_ROOTS_UPDATE.md),
[polar-Snap checkpoint](docs/STARSCAPE_PARITY_UPDATE.md) and
[earlier validation receipt](docs/POLYNOMIAL_VALIDATION.md) separate arithmetic
checks, actual browser interactions, simulator interactions and synthetic XR.
Full functional or visual parity has **not** been established.

| Behavior | Current evidence and limits |
| --- | --- |
| Signed points, exact selection, pairs and cutting planes | Lean output compared against canonical fixtures. Both renderers show the same R6 pair, plane and 22 members. |
| Colors, size, fade and projection | Corresponding states visually inspected. Native physical spheres and browser pixel-sized discs differ; no pixel equality claim. |
| Linked Möbius motion, Snap and Identity | Browser 2D/3D pointer motion and synthetic controller motion tested. Native disk swipe and directional controls tested; native free-space hand/controller dragging remains missing. |
| Roots chart | Browser shows linked 3D/UHP panes together on wide windows, with an optional Klein model. Native now has a separate linked UHP Roots window with selection, pairing, labels and geodesics. Other source models and theme controls remain gaps. |
| Selection and hover | Browser polynomial hover and picking are exercised. Native Roots has actual simulator tap/pair evidence and a cancellable Lean hover inspector; its pointer-hover callback remains unverified because visionOS XCUI excludes hover. Physical gaze/pinch and explicit controller bindings are unverified. |
| Density and crop | Browser R96 has 1,852,484 signed forms; this simultaneous layout was exercised at R24/28,832. Native caps at R12/3,608. The fixed base crop differs from original Starscape's trace/other-point catalogues; [exact recrop specification and fixtures](docs/source-recrop-audit.md) are recorded, implementation remains missing. |
| Origin, Inhabit, Overview, Reset | Tested on each route. Camera offsets, field of view, materials and control layouts differ. |
| Headsets | Synthetic WebXR runs real Three.js rendering/handlers with supplied poses. visionOS Simulator runs the native app. Neither establishes physical tracking, compositor behavior, comfort or hardware performance. |

Main Chrome's existing URL-based connection was rechecked and failed with
`Debugger unattached`; current actual browser interaction evidence uses the
in-app browser. All limitations
remain visible rather than being inferred away from a successful Lean response.

## Proof and execution boundary

| Layer | What actually happens |
| --- | --- |
| Kernel-checked | 17 general integer identities cover coordinate/discriminant formulas, plane incidence and Möbius action laws. Sixteen axiom audits use only standard Lean axioms. |
| Executable Lean | A native Mac process enumerates signed clouds and computes inspections, symbolic roots, exact planes/membership and the rational action `J(M)/det(M)`. |
| Client preview and Snap choice | Floating-point dragging, quantization and choosing a candidate integer symmetry occur in the client. Lean computes the exact action of the submitted matrix. |
| Exported fixtures | Native preset data are generated by the actual executable with receipts. Live computations require the Mac bridge. |
| Rendering and transport | Three.js/RealityKit handle floating-point coordinates, meshes, colors, cameras and input. JSON, HTTP, compiler/runtime execution and renderers are outside the kernel proof boundary. |

A live result is an exact Lean calculation, **not a new proof certificate for
that request**. Enumeration completeness, gcd/radical normalization and the
compiler/runtime have tests; the 17 identities do not prove them.
[Proof source and receipts](lean/Polynomial/README.md) ·
[JSON protocol](lean/Polynomial/PROTOCOL.md) ·
[interactive boundary](web/polynomial/boundary.html).

## Native visionOS

Open `native/ExteriorRoom.xcodeproj` and choose **PolynomialRoom**. Bundle and
scheme names remain stable. The app uses RealityKit and the same Lean schemas.
Bundled preset playback works without the bridge; live results run on the Mac.
Lean does not execute inside visionOS. See [native instructions](native/README.md)
for the simulator build and existing test routes.
Use **Roots…** to open the linked upper-half-plane window; choose Select, Pair,
Move or Pan. Zoom/Fit changes the chart without changing the accepted action.

Device loopback refers to the device, not the Mac. A physical native route needs
a reachable Mac bridge; device signing/installation and physical acceptance are
not established here. WebXR also needs a secure context on a headset; the local
server does not configure HTTPS or public hosting.

## Tested evidence

- [Simultaneous 3D and roots video](artifacts/videos/lean-starscape-linked-panes.mp4):
  actual desktop D5, root drag, Snap and Identity on the shared unit/pair.
  [Current screenshots and states](artifacts/screenshots/linked-roots-20261023/)
  also cover hover, responsive layout, R24 and synthetic XR restoration.
- [Native linked Roots sequence](artifacts/videos/lean-starscape-native-linked-roots.mp4):
  actual simulator taps/pairing, D5, free root swipe, pan/zoom/Fit and reopening.
  [Matched D5 visual inspection and limits](docs/LINKED_ROOTS_UPDATE.md#matched-visual-inspection).
- [Current UHP drag/Snap video](artifacts/videos/lean-starscape-browser-polar-snap.mp4)
  and [native polar-Snap video](artifacts/videos/lean-starscape-native-polar-snap.mp4):
  the same T⁴ result through browser pointer motion versus a declared native
  matrix preset plus actual Snap controls. Input routes and charts differ.

- [Matched browser sequence](artifacts/videos/polynomial-browser-matched-render.mp4)
  and [native sequence](artifacts/videos/polynomial-native-matched-render.mp4):
  Identity → D5 → fade off → fade on with projection, using the same R6 pair.
- [Native disk swipe](artifacts/videos/polynomial-native-klein-swipe.mp4): actual
  simulator gesture, accepted Lean matrix, return to Overview.
- [Browser roots/Snap](artifacts/videos/polynomial-roots-snap.mp4) and
  [3D Origin motion](artifacts/videos/polynomial-origin-drag.mp4).
- [Synthetic XR motion](artifacts/videos/polynomial-xr-mobius.mp4): supplied
  controller poses, real application rendering and event handlers.

These silent app-only clips have dated [metadata and limits](artifacts/videos/README.md).
Older clips retain their original “Polynomial Room” label. They are not current
hardware evidence. This continuation passes **115 Node tests**, **88 native model
tests** (76 polynomial, 12 archive), one actual native Roots UI test and the
five-case source-catalogue audit.
The preceding checkpoint passed 26 bridge tests and the focused native polar-Snap UI test. Historical
62-test/swipe receipts remain dated records, not retested source hashes.

```sh
python3 lean/Polynomial/build.py
python3 lean/Polynomial/test_service.py
python3 lean/Polynomial/test_transform.py
python3 -m unittest discover -s tests -p 'test_*.py'
node --test tests/*.test.mjs
swift test --package-path native --scratch-path native/.build/swift-tests -j 2
```

The polynomial service comparison covers 305 requests and 2,120,040 ordered
points across tested crops. Another 452 requests cover rational transformations,
composition and pinned Snap absorption fixtures. These arithmetic tests are
separate from rendering and interaction acceptance.

## Attribution and preserved work

The polynomial-space construction follows **Katherine Stange** and the
Harriss–Stange–Trettel *Algebraic Number Starscapes* work. Pinned FareyVision
renderer modules and control patterns retain their notices and provenance;
see [the manifest](web/polynomial/PROVENANCE.json) and [NOTICE](NOTICE.md).
New Lean implementation and proofs are this project’s work, not attributed to Stange.

The combined distribution is **AGPL-3.0-or-later**; borrowed FareyVision files
retain GPL notices and Three.js retains MIT. The earlier Grassmann experiment
and its provenance remain in [the archive guide](EXTERIOR_ROOM_ARCHIVE.md).
No exterior-algebra feature is counted as Starscape functionality.
