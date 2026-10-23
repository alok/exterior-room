# Exterior Room · visionOS

This separate RealityKit app consumes the same exact integer response as the browser.
It has two explicit modes: **Lean export · preset playback** uses bundled JSON produced
by the Lean executable; **Live Lean · Mac bridge** sends bounded integer coordinates to
the local server. It does not implement a second exterior algebra engine in Swift.

The full immersive scene places controls beside three vectors, a translucent
parallelepiped, the `a ∧ b` face, and exact exported coefficients. Overview and
inside change scene placement/scale; the latter does not claim room mapping or
collision handling. In live mode, drag a colored endpoint and release to send
its quarter-unit snapped coordinates to Lean. Coordinate buttons, vector
selection, swap, flatten, reset and volume visibility mirror the browser.

`python3 native/scripts/export-presets.py` reads the browser's `PRESETS`, sends
them to the compiled Lean executable, and writes the native JSON plus a SHA-256
receipt. There is no native/Python algebra fallback. Reduced fractions are
presentation only. The same negative half-way snapping rule is used in both UIs.

Build without signing or simulator boot:

```sh
cd native
/opt/homebrew/bin/xcodegen generate
DEVELOPER_DIR=/Applications/Xcode-27.2.0-Beta.2.app/Contents/Developer \
  xcodebuild -project ExteriorRoom.xcodeproj -scheme ExteriorRoom \
  -sdk xrsimulator27.2 -destination 'generic/platform=visionOS Simulator' \
  -derivedDataPath .build CODE_SIGNING_ALLOWED=NO ARCHS=arm64 -jobs 2 build
```

For a simulator, the default server is `http://127.0.0.1:8787`. A physical headset
must use a reachable Mac address and an explicitly LAN-bound server; localhost on
the headset refers to the headset. App Transport Security allows local networking.
No physical headset run or comfort/performance claim is made by a successful build.

The native bridge is HTTP; Lean executes on the Mac, not on visionOS. A failed live
request leaves the last accepted result visible and labels it as previous data.

Validate the same Swift JSON decoder used by the app, and optionally compare all
bundled exports against the running bridge:

```sh
DEVELOPER_DIR=/Applications/Xcode-27.2.0-Beta.2.app/Contents/Developer \
  xcrun swiftc -parse-as-library Sources/LeanModel.swift Tests/VerifyExports.swift \
  -o .build/verify-exports
.build/verify-exports Resources/presets.json http://127.0.0.1:8787
```

This is a transport/schema consistency check, not a second proof of the algebra.
It also drives the actual native model through unit → swap → flatten → reset →
coordinate-edit operations against the live Lean service.

Native model tests:

```sh
swift test --package-path native --scratch-path native/.build/swift-tests -j 2
```

`native/scripts/run-ui-tests.py` targets the task-owned simulator
`1D261881-0A0F-4DE0-B704-12644E606348` (Exterior Room QA 2026-10-23). Build the
UI tests with `build-for-testing` first; use `--simulator UUID` for another
task-owned simulator. The runner uses a serialized screenshot
handshake because visionOS does not support XCTest's ordinary screenshot API.
Each run records native screenshots, timing/hash receipts and an `.xcresult`.
It never targets the existing Farey simulator.

## Provenance

ImmersiveSpace lifecycle and RealityKit sphere/cylinder/transparent mesh patterns
are adapted from FareyVision at `8b32d7ae8f67fc47f381407bbcdf6f24e28de771`, files
`Farey/Sources/FareyVisionApp.swift`, `FareyImmersiveView.swift`, and
`LatticeRenderer.swift`, plus `Farey/scripts/capture_coordinator.py` and
`Farey/UITests/SimulatorCapture.swift`, GPL-3.0-or-later. Adaptation by Alok Singh with OpenAI
Codex, 2026-10-23: independent exterior-algebra scene and Lean JSON transport.
FareyVision's mathematical exhibit credits Katherine Stange; this app borrows
application patterns only and does not attribute the new algebra scene to her.

The existing Lean Calculator and its Clifford bridge were located as background
context but were not copied: its iCloud-local source reads timed out.
