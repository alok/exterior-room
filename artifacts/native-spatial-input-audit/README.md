# Origin spatial-input review

Read-only source/SDK review, 2026-10-23. No tracking session, permission request, build, UI action or proof change was performed. This is a diagnosis plan, not an actual-input pass.

## Concrete coordinate risk

`PolynomialSpace.swift` places `root` under `AnchorEntity(.head)` with `.once`, then passes `value.convert(value.location3D, from: .local, to: root)` to `PolynomialSpatialInput.upperPoint`. That helper interprets the result as a vector **from the coefficient origin**, taking `(x/y,z/y)`. Collision preparation alone does not establish that the converted point has that origin.

Apple documents that the implicit head-anchor transform cannot be read by the app. Canonical's recorded failed run `87d4f0f` received 61 sky-drag callbacks but rejected directions as outside the cone; its direct and two-hop conversions agreed. Our published path has the same relevant placement/conversion structure. This is a shared structural risk, not proof that our unmeasured input produces the identical error. Replacing one conversion path with the other is not an evidence-supported fix.

Our root frame is otherwise independent of the numerical Möbius action, which moves the rendered coefficients. `PolynomialModel` checks drag ownership, placement and epoch before preview/commit; invalid directions re-anchor and cancellation retains accepted state. Those safeguards should remain.

## Narrow supported option

Apple's [head/device placement guidance](https://developer.apple.com/documentation/visionos/placing-entities-using-head-and-device-transform) documents authorization-free `WorldTrackingProvider` use in an immersive space, including Simulator. The returned pose is the **device pose**, not the wearer's head center.

For a separately tested candidate: check `isSupported` and `requiredAuthorizations.isEmpty`; run a dedicated session with only WorldTrackingProvider; wait for `.running`; query at `CACurrentMediaTime()`; require tracked, finite rigid coordinates; then stop the session on every path. Freeze the accepted pose for the placement epoch. Apply its complete translation and rotation under an ordinary world-stationary host, followed by the existing Origin nappe rotation. Do not add a persistent world anchor, authorization request or assumed head-height constant.

The current canonical candidate already guards Origin dragging on `currentDevicePose != nil`. It must not be described as having an established provisional-anchor drag race. For any adoption here, readiness should mean the explicit pose has been **installed in the renderer**, and any change of coordinate frame should cancel/re-anchor active input. A model pose value alone is not a measurement that the rendered frame is current. The candidate has not been assumed to pass actual input.

Local SDK contracts inspected:

- ARKit's Swift interface exposes provider state, support, required authorizations, `queryDeviceAnchor`, `originFromAnchorTransform`, `isTracked`, and the distinct `orientationTracked`/`tracked` states.
- `ARKit.framework/Headers/world_tracking.h` specifies a right-handed origin, mach-absolute seconds and a non-thread-safe device query; serialize queries.
- `_RealityKit_SwiftUI` has separate point/vector conversion overloads. Ray origins require point conversion; directions require vector conversion without translation.
- SwiftUI's [selection ray](https://developer.apple.com/documentation/swiftui/spatialeventcollection/event/selectionray) is optional targeting-event data, not a documented continuous gaze or head-center API. A missing ray does not imply that authorization-free world tracking is unavailable.

## Next actual-input diagnostic

Record raw callback phase and target entity **before** the target guard, alongside accepted-input counts. At gesture start record `startLocation3D`, current location, the explicit root/world transform, placement epoch and shell scale. Optionally record a targeted event's selection-ray origin and direction using their correct conversion types.

The initial collision hit in the true root frame should be consistent with the shell's scaled facet-to-vertex range (`shellInradius * scale` through `2.4 * scale`). Later drag locations need not remain ray/shell intersections, so do not use their lengths as a head-height estimate. Our shell scale can change with rendered reach; log it rather than assuming a 2.4 m sphere throughout.

Test both nappe orientations, a moved device/head, cancellation, and re-entry while preserving exact selected/pair identities until an explicitly requested Snap. Do not clamp an invalid direction into the cone to manufacture acceptance. These are remaining checks, not completed results.
