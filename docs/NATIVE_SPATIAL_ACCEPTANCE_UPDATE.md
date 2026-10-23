# Native spatial acceptance continuation

This work follows published checkpoint `42f7ec09`. The target remains the same
Starscape behavior, with executable Lean providing exact accepted arithmetic.
The 17 public laws and the Lean service binary are unchanged. Sphere picking,
device placement and rendering are outside that proof boundary.

## Exact sphere-pair contract

The operator probe starts in Overview with primary `(1,-1,2)`, Canonical R6, and
Pair next armed. An actual sphere click must resolve raw identity `(3,0,3)`,
retain the primary, and accept normal `(1,-2,-1)`, equation
`2a −2b −2c = 0`, endpoints `1±√2`, and 18 members. It then selects `(3,0,3)`
through the ordinary field and requires an actual click on the same sphere to
return the same-primitive-direction error. Rejection must retain the accepted
scene and leave Pair next armed. No injected model action can satisfy the
spatial callback assertions.

This is a different fixture from primary `(1,0,1)` paired with `(1,1,1)`, whose
plane has 22 R6 members. Their counts must not be compared as the same scene.
Raw `(3,0,3)` and primitive `(1,0,1)` remain distinct catalogue identities.

The [source comparison](../lean/Polynomial/fixtures/spatial-pair-contract.json)
records the exact canonical source revision and evaluated modules; the
[native cases](../lean/Polynomial/fixtures/spatial-pair-native-cases.json) are
actual Lean responses. Two native regressions check acceptance and rejection.
The initial harness build passes 149 model tests; its [frozen manifest](../native/evidence/spatial-pair-build-manifest.json)
is a dated pre-device-pose baseline, not a receipt for later source changes.

**Actual sphere pairing has not passed in this app.** The prepared operator test
has not been started: host access failed before it could be driven reliably.

## Explicit native placement

The candidate replaces the implicit head-anchor frame for successful Origin and
Inhabit placement with one fully tracked, finite rigid **device** pose. The
coordinate approach follows canonical source `65d50122`; provenance is recorded
in [the implementation](../native/Sources/PolynomialDevicePose.swift). A device
pose is not the wearer's head or eye center. Apple's [placement documentation](https://developer.apple.com/documentation/visionos/placing-entities-using-head-and-device-transform)
explains that distinction and the authorization-free tracking route.

The app checks provider support and requires an empty authorization requirement
before starting its own session. It accepts one pose within a bounded deadline and
stops that session on success, failure, cancellation and timeout. A late startup
that ignores cancellation receives a compensating stop. There is no permission
request, persistent world anchor, assumed head height or cone clamp.

The measured pose is frozen for a placement epoch. Origin dragging is enabled
only after the renderer acknowledges installation of that exact pose and nappe.
A nappe flip retains the pose but cancels input and waits for the new orientation
to be installed. Overview, Reset and leaving invalidate old queries and
acknowledgements. If a pose is unavailable, temporary head placement remains
visible with an explicit status and spatial dragging disabled; the Roots and
directional controls remain available.

All **169 model tests pass**. These include fake-session late-start cleanup,
stale result rejection, installation gating, and the renderer's shared Origin
transform helper checked against independently calculated world points for a
translated, rotated device pose in both nappes. They do not exercise real
tracking or establish that an actual sky drag reaches its target.

The canonical app has a separate actual-input pass for its implementation.
That evidence motivated this change but does not count as a Lean Starscape
input pass. Our opt-in probes require real external sphere/sky input and remain
unstarted while the supported host-control connection is unavailable.

## Regression acceptance on the candidate

The unsigned visionOS simulator build passes. The unchanged
`PolynomialSourceMorphUITests.swift` then passed both existing actual-XCUI
sequences on our own simulator:

| Sequence | Result | Observed behavior |
| --- | --- | --- |
| Held preview, `20261023T124456Z` | 1 pass, 0 failures, 79.454 s | Actual Roots pair tap, held drag with an interim Lean catalogue before release, final P50/P100 and Origin placement |
| Matched morph, `20261023T124640Z` | 1 pass, 0 failures, 99.466 s | P0/P50/P100, animated Project/Lift, D5, actual Roots swipe, pairing cancellation and Reset |

The held run published 4,208 temporary forms 1.764 seconds before release.
Release accepted matrix `[16519,9024,16210,14909]`, 4,206 forms and 64 members,
preserving the unit/pair. The interim and final actions are distinct; their
counts are not interchangeable. The separate morph run's final swipe accepted
`[22885,10556,14031,10842]` and 4,229 forms. These are input traces, not a claim
that every gesture produces the same matrix or that these runs measured cold
service performance.

The [frozen UI receipt](../native/evidence/device-pose-ui-regression-receipt.json)
links the exact build, logs, parsed states and 13 screenshots. The Origin capture
visibly reports **Device pose installed** and shows the surrounding projected
lattice, with spatial changed/ended counts both zero. This is an actual placement
observation, not a free-space-drag pass.

A subsequent test-only build adds Reset/Exit/re-entry assertions to the optional
Origin operator probe. Its [separate manifest](../native/evidence/device-pose-operator-build-manifest.json)
confirms the product app and Lean backend are byte-identical to the passing
regressions; only the test binary changed. That operator probe has not run.

| Matched Source16 identity, unit/pair, full projection | Evidence |
| --- | --- |
| Browser, existing unchanged implementation | [Browser capture](../artifacts/screenshots/morph-final-20261023/02-identity-p100.png) |
| Native candidate, 4,406 forms | [Fresh native capture](../native/evidence/screenshots/20261023T124640Z/003-source-morph-02-p100-animated-unit-pair.png) |
| Native Origin after accepted Roots drag | [Installed device-pose capture](../native/evidence/screenshots/20261023T124456Z/006-source-input-05-origin-ready-for-host-probe.png) |

Inspection confirms the projected star pattern, selected/pair locations and
cutting plane remain visible. Camera scale, glyph footprint, material appearance
and control layout differ. The floating native Roots window can still occlude
the 3D view; closing it restores the unobstructed view. Full visual parity is
not established.

Fresh silent app-only clips: [held preview and Origin placement, 66.41 s](../artifacts/videos/lean-starscape-native-device-pose-preview.mp4)
and [morph/Roots regression, 87.25 s](../artifacts/videos/lean-starscape-native-device-pose-morph.mp4).
Both decode successfully and contain zero audio streams. Representative video
frames at preview 24/45/64 s and morph 20/40/80 s were inspected against the
saved states. [Export receipt](../native/evidence/device-pose-videos.json) records
commands, hashes and scope; raw simulator MOVs remain local.

## Supported access diagnosis

The canonical owner prepared a shared Device Hub window and released it for our
QA simulator. Supported computer control read that window and the unique
`Exterior Room QA 2026-10-23` row. The single action selecting that row timed out
after 30 seconds; a fresh attachment and a read-only inventory also timed out.
The canonical owner's subsequent public accessibility read confirmed our exact
QA UUID was selected, resolving that action's uncertain outcome. One attachment
attempt after this new evidence still timed out. There was no sphere click, sky
drag, or timed operator test. Repeating the same attachment route was stopped.

A separate read-only simulator query confirmed our UUID
`1D261881-0A0F-4DE0-B704-12644E606348` was booted. The first sandboxed query could
not reach CoreSimulator, while the authorized unsandboxed query succeeded;
the sandbox refusal is not evidence that the simulator crashed. No access grant,
permission change, alternative host-input mechanism or canonical checkout edit
was made. The shared window was preserved and foreground control released.

Main Chrome's URL attachment also timed out at
`Emulation.setFocusEmulationEnabled`. Existing in-app-browser evidence remains
separate from main-Chrome acceptance.

## Bounded density and preparation checks

The [Lean receipt](../lean/Polynomial/evidence/spatial-pair-density.json) records
48 passing requests: 24 exact pairing/fixture requests and 24 density requests.
Fresh-process Source16 queries for the three recorded drag matrices took
174–274 ms. These wall times are bounded local observations.

Source24 identity contains 14,966 forms and is complete. The transformed
Source24 cases require other-category scan bounds 72 or 85, beyond the source's
64 bound. They correctly report `complete=false` and omit that block, retaining
12,150, 12,177 or 12,176 upper forms. No omitted identities are synthesized.
Those cases cannot establish full signed-density parity merely by finishing
quickly.

The [native CPU benchmark](../artifacts/native-render-plan-benchmark/README.md)
uses actual Lean responses and current native validators/render-plan code,
compiled with `-Onone`. Twelve configurations cover identity and the accepted
drag matrix at depth 16/24 and morph progress 0/.5/1. Each has one warmup and
three measured calls. Mean `PolynomialRenderPlan.make` time is 15–16 ms at depth 16,
54 ms for complete depth-24 identity, and 44–45 ms for the incomplete transformed
depth-24 case. This does not measure RealityKit, collision generation, GPU work,
UI latency, FPS or a physical headset.

## Remaining acceptance

- Actual native sphere pairing and same-direction rejection through public
  simulator input.
- Actual free-space Origin drag in both nappes, with exact selection/pair/plane
  retained, followed by Reset and exit/re-entry.
- Actual native pointer hover: the supported visionOS XCTest command excludes
  pointer hover; model hover tests are not a substitute.
- Physical headset gaze/pinch, WebXR controller tracking and performance.
- Broader dense interaction responsiveness and identical visual framing across
  renderers.

The strict held-preview test and restored projected-body regression remain
intact and pass again above. Their previous passing [screenshots, clips and receipts](NATIVE_PREVIEW_RENDER_UPDATE.md)
remain preserved as dated evidence.
