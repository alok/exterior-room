# Native Vision Pro route

`native/ExteriorRoom.xcodeproj` is a separate visionOS application with bundle ID
`com.alok.ExteriorRoom`. It shares the browser's Lean-response contract, not its
renderer. The full instructions and provenance are in `native/README.md`.

## Implemented

- RealityKit vectors, directly draggable endpoint handles, a highlighted exterior
  product face, and a translucent volume built from Lean-exported vertices.
- Overview and inside placements.
- Browser-matched presets and vector colors, quarter-grid coordinate edits,
  vector selection, swap, flatten, reset, and volume visibility.
- In-space exact coefficient/volume receipt and clearly distinct exported,
  pending, live, and disconnected states.
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

Seven native model tests pass: preset parity, rational formatting, snapping,
rapid edits/out-of-order responses, failure preservation, invalid URL
invalidation and response rejection. The actual Swift model also passes a live
Lean unit → swap → flatten → reset → coordinate sequence. See
`native/evidence/model-tests.txt` and `native/evidence/bridge-tests.txt`.

The simulator captures revealed a window overlapping the geometry and an exit
that failed to restore the launch window. The scene now uses a separate controls
attachment beside the geometry in a dark immersive space, and opens its launch
window before dismissing that space. The final XCUITest passed with 0 failures in 130.352 seconds,
capturing 9 real simulator screenshots with a serialized capture handshake.
It verifies live connection, space entry, the unit/swap/flatten exact volumes
`1 → -1 → 0`, coordinate editing, preset selection, view/volume controls, reset
and return to the launch window.

- Test log: `native/evidence/ui-tests-20261023T030342Z.txt`
- Overview: `native/evidence/screenshots/20261023T030342Z/002-02-skew-overview.png`
- Swapped: `native/evidence/screenshots/20261023T030342Z/004-04-swapped.png`
- Flattened: `native/evidence/screenshots/20261023T030342Z/005-05-flattened.png`
- Inside placement: `native/evidence/screenshots/20261023T030342Z/007-07-inside.png`
- Restored launch window: `native/evidence/screenshots/20261023T030342Z/009-09-returned.png`
- Capture hashes/timing: `native/evidence/screenshots/20261023T030342Z/captures.json`

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
