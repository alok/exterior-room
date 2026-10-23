# Web boundary review

This review covered the JavaScript transport/state boundary, Three.js geometry
updates, pointer/XR interaction paths, and static responsive layout rules.
The source review and helper tests did not run a browser or headset. Separate
browser interaction results and inspected screenshots are recorded in
[VALIDATION.md](VALIDATION.md).

## Executed checks

`node --test tests/*.test.mjs` passed **18 tests** with no failures.

The tests exercise:

- Exact fraction formatting and rejection of unsafe numeric inputs.
- Integer lattice snapping and independent preset snapshots.
- Rejection of mismatched request IDs, wrong scales, changed input vectors,
  malformed coefficients, and malformed exported vertices.
- One active transport request, coalescing to the latest edit, and suppression
  of superseded successes and failures.
- Retaining the last accepted result on transport failure and recovering on a
  later edit.
- Unavailable XR fallback, controller rays using current parent/local poses,
  and desktop camera/projection restoration without inappropriate control
  updates.

The fixed response data in these tests are transport fixtures. They do not
validate exterior algebra. The Lean executable's arithmetic checks are separate.

## Findings sent to implementation owner

These historical findings were sent to the implementation owner. Their final
source status is recorded below.

1. The opaque ground at `y = -0.66` occluded legal negative-y vectors and parts
   of their volume. Inputs span `[-3,3]` world units; summed vertices can reach
   `-9`. The grid/ground should not conceal accepted geometry.
2. WebXR hid DOM result and connection status without an equivalent in-world
   readout. Exact coefficients and stale/error state must remain visible in VR.
3. Mutated wire and area-wire positions did not recompute bounding spheres.
   Three.js `setFromPoints` updates coordinates but leaves the sphere cached.
4. The volume position attribute was replaced on every response. Updating its
   fixed buffer avoids repeatedly allocating WebGL buffers during dragging.
5. Failure in awaited XR setup could leave OrbitControls disabled and a
   requested session active. Error cleanup should restore desktop state and
   close any partially initialized session. XR exit should restore the saved
   view mode as well as its camera.
6. The proof link targeted `/source-receipt`, while the server route at review
   time was `/api/provenance`.
7. At desktop width and roughly 500px viewport height, fixed controls beginning
   at 310px overlapped bottom metrics and could be clipped. Short landscape
   windows need a dedicated layout or scrollable controls.

Source evidence for the geometry concerns comes from the vendored Three.js
0.180.0 implementation (`BufferGeometry.setFromPoints`,
`BufferGeometry.computeBoundingSphere`, and `WebGLAttributes`).

## Follow-up review

The revised implementation removes the opaque ground, reuses the volume
position buffer, recomputes wire bounding spheres, includes an in-world result
and connection-status card, and makes short-window controls scrollable.

Three further XR integration concerns were reported and subsequently corrected:

- The app's session `end` listener was registered before Three.js's listener.
  It therefore ran while `renderer.xr.isPresenting` was still true and entered
  the XR branch of `setView` during supposed desktop restoration. Three.js's
  `sessionend` event fires after its own teardown and is the appropriate normal
  completion signal; partial setup failure still needs explicit cleanup.
- Separate handle-first and button-second selection listeners allow a vector
  behind a nearer visible button to intercept the press. Select the nearest
  hit among both categories.
- XR dragging stores surface-hit distance and then treats that hit as the
  vector's center. Retain the center-to-hit offset, as desktop dragging does,
  to prevent a jump when a grab begins.

The new XR helper tests do not simulate the WebXR session lifecycle and do not
establish headset interaction, visibility, or performance.

## Corrections confirmed in source

The final source review confirms these corrections:

- The opaque ground is removed. Mutable geometry refreshes its bounds, and the
  volume reuses its fixed position buffer.
- Normal desktop restoration listens to Three.js's `sessionend` event after
  teardown, explicitly resets world placement, and enables controls. Failed XR
  setup also restores the saved desktop camera and cleans up the requested
  session.
- A single nearest-hit query covers handles and buttons. XR dragging retains
  the center-to-hit offset and commits the final pose on `selectend`.
- Presets, coordinate edits, swap, flatten, and view changes cancel active
  desktop/controller drags. Reset also reaches this cancellation path. A held
  drag therefore cannot overwrite a discrete edit or use the previous scene
  transform after a view change.
- Shared volume-visibility logic hides both the volume mesh and its wire;
  reset restores volume visibility along with the Skew vectors and Overview.
- The in-world controls include presets, vector selection, quarter-unit
  coordinate buttons, swap, flatten, reset, volume visibility, view, and exit.
  The in-world readout includes the ordered bivector basis, exact coefficients,
  signed volume, and current computation/error status.
- Hidden XR canvases are not redrawn. Visible button textures update only when
  their label or active state changes. Entry makes the panel visible before
  refreshing, so initial entry and re-entry still draw current content.
- The proof link targets the existing `receipt.html` page. Responsive rules
  address clipped mobile content and short-window title/control overlap.

The last source review found no new blocking issue. All concrete findings above
are addressed in source, and the 18 JavaScript helper tests pass. These results
do not establish runtime behavior in an immersive WebXR session.

## Separate runtime evidence

The supplemental in-app-browser run exercised live presets, swap, flatten,
quarter-unit keyboard editing, pointer dragging, Inside, volume visibility,
reset, and the proof panel. Its saved 390×844 and 900×500 captures show the
revised responsive layouts. Matching browser/native captures were inspected
for exact values and visible geometry; the renderers use different cameras,
materials, scales, and control layouts.

Main Chrome's earlier launch and live swap remain verified. Its latest retry
recovered DOM reads and refreshed the demo, but screenshot capture timed out
and a Unit click timed out before dispatch. A later successful reload was
followed by stalled read-only diagnostics. Main Chrome interaction acceptance
therefore remains pending. Immersive WebXR and native tracked-hand dragging
remain untested. See the [validation receipt](VALIDATION.md) for action-level
results, screenshot links, and the exact limits of that evidence.
