# Web boundary review

This review covered the JavaScript transport/state boundary, Three.js geometry
updates, pointer/XR interaction paths, and static responsive layout rules.
It did not use a browser or headset; the main agent owns visible browser testing.

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

The following were present in the reviewed implementation and should be checked
against the final app; this document is a review receipt, not final bug status.

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

Three XR integration concerns were reported for final correction:

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

The final source review confirms the reported changes: normal desktop
restoration listens to Three.js's `sessionend` event and explicitly resets world
placement and enables controls; a single nearest-hit query covers handles and
buttons; XR dragging preserves the center-to-hit offset. The proof link now
targets the existing `receipt.html` page. Together with the geometry and layout
changes above, all concrete findings in this review are addressed in source.
This is not a claim that a physical WebXR session was exercised.

Runtime acceptance is tracked separately in [VALIDATION.md](VALIDATION.md).
Browser launch and live swap were observed; the remaining browser workflow was
not completed because the browser automation connection stalled. Source-review
closure and passing helper tests do not mark those pending interactions as
verified.
