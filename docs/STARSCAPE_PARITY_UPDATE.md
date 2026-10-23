# Starscape parity update — 23 October 2026

The primary app is now **Lean Starscape** at `http://127.0.0.1:8787/`.
The earlier exterior algebra experiment is preserved at `/exterior/`; none of
its functionality counts toward the Starscape contract. The canonical Farey
checkout and port 8778 were not modified.

## Concrete corrections

- Browser roots now default to the source upper half-plane. Coordinates, glyph
  radii, primitive-root picking, anchored wheel zoom and geodesics follow the
  pinned canonical browser `2cd549a` (0.15.7). Optional Klein remains available.
  Translucent coincident roots blend in source order; selected rings draw above
  stars. A numerical comparison of 32 visible R6/D5 roots differs by at most
  0.000018 pixels. This is a coordinate comparison, not a GPU image proof.
- Snap uses residual polar angle and the source tie rules. All 34 shared
  canonical fixtures pass in browser and native models. The earlier entrywise
  ranking incorrectly chose T⁴S for the vertical counterexample; it now chooses
  T⁴.
- Exact identities support coefficients ±1024 independently of the displayed
  crop. Browser text selection, native selection and paired absorption preserve
  hidden identities. Cloud bounds remain browser R96/native R12. Endpoint and
  matrix budgets remain enforced, with atomic rollback tests.
- Stationary Shift-click in the roots chart pairs a point; Shift-drag pans.
  Reset clears Snap-on-release and chart pan/zoom. Readouts distinguish shown
  approximate roots/endpoints from exact base identities. Polynomial display
  labels use spaced operators without altering Lean data.

## Actual UI evidence

Current [browser observations](../artifacts/screenshots/starscape-parity-20261023/ui-states.json)
come from the in-app browser, using real controls/pointer input and read-only
diagnostics. No application state was injected.

| Sequence | Verified result |
| --- | --- |
| Select unit; stationary Shift-click `(1,1,1)` | Pair `(1,0,1)/(1,1,1)`, plane `2a−2c=0`, endpoints −1/1, 22 members. |
| Drag unit root in upper half-plane | Lean accepts M `[10741,903,912,9387]`, determinant 100002231; root and paired geodesic move together. |
| Source vertical drag, then Snap and Identity | Real pointer drag accepts `[31623,11384,0,3162]`, determinant 99991926. Snap absorbs T⁴: `(13,20,34)→(13,−84,162)`, Δ−1368. Identity retains it. |
| D5 unit pair | Shown root `1+i`, endpoints `−2` and `4/3`; exact base labels and 22-member count retained. |
| 390×844 layout | Upper-half-plane/Klein selector and Exact move usable; temporary viewport override reset afterward. |
| Synthetic controller rays | Current Exact move → Snap → Reset → Exit runs actual app raycasts/handlers. Snap yields `(1,−3,4)`, Δ−7; Exit restores desktop. |
| Native simulator `081658Z` | Actual Snap/Identity/Reset controls after an explicitly declared vertical matrix preset; source T⁴ result retained, with hidden-crop label. One test, zero failures, 112.941 seconds. |

The [browser](../artifacts/videos/lean-starscape-browser-polar-snap.mp4) and
[native](../artifacts/videos/lean-starscape-native-polar-snap.mp4) silent clips
have inspected decoded frames and separate metadata. The browser recording
captures the canvas, excluding DOM controls. The native preset does not prove
that a gesture generated that matrix. The earlier actual native disk swipe
remains documented in its own dated receipt.

The browser [T⁴ 3D state](../artifacts/screenshots/starscape-parity-20261023/10-source-t4-3d.png)
was compared with the native video's T⁴ frame. Both retain the same signed
identity, polynomial and discriminant while showing the R6 signed double cone
and hiding the out-of-crop selected marker. Camera scale, sphere/disc size,
panel placement and chart model differ. This is corresponding-state inspection;
full visual or interaction parity has **not** been achieved.

Main Chrome permitted an existing-tab read, then timed out on refresh and
URL-based reattachment. Refresh outcome is uncertain. It is not an accepted
Chrome run; no new access or permissions were requested.

## Verification and proof boundary

- **107 Node tests**, **26 Python bridge tests** pass.
- Executable Lean comparison: **305 base-service requests**, **2,120,040 ordered
  points**, and **452 transformation requests** pass.
- Sequential Lean build passes with **17 unchanged general integer theorems**,
  16 axiom audits using standard axioms. No admitted theorem was added.
- **68 native model tests**, unsigned simulator build and the focused UI run
  pass. See [native receipt](../native/evidence/polar-snap-native-receipt.json).
- R96 radix ordering of 270,202 upper roots takes 2.28–7.45 ms in the recorded
  five-state CPU benchmark. This is not a headset frame-rate or GPU benchmark.

Lean computes exact clouds, inspections, planes and accepted rational actions.
Client floating-point previews and Snap candidate choice, transport, compiler,
rendering, cameras and physical input are outside the kernel proof boundary.
A successful Lean computation does not certify a rendered frame.

## Remaining same-app gaps

Native upper-half-plane view/picking/polynomial hover; native free-space hand or
controller transformations; dense native crops above R12; simultaneous wide
3D/roots layout; source dynamic transformed recropping; all source model/theme
choices and hash-URL state sharing. Physical headset operation, tracking and
comfort remain unverified. Current root text reports transformed approximations;
the plane equation remains explicitly labelled as the base plane during motion.

The precise operation matrix remains in [FUNCTIONAL_PARITY.md](FUNCTIONAL_PARITY.md).
These are unfinished requirements, not equivalent replacement features.
