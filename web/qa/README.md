# Emulated WebXR QA harness

Open `http://127.0.0.1:8787/qa/xr.html`, or append `?route=polynomial` for the polynomial room. The server and compiled Lean executables must already be running normally. The harness does not supply a mathematical fallback.

This is **EMULATED WEBXR**, not headset evidence. It is a small local runtime double written against the vendored Three.js 0.180.0 `WebXRManager` and `WebXRController`. It is not IWER, a browser extension, a WebXR polyfill, or a WebXR conformance implementation. It requests no new permissions or credentials.

## Integration

Only the explicitly flagged production page loads the QA bootstrap, before any module constructs a renderer:

```js
if (new URLSearchParams(location.search).get('qaXR') === '1') {
  await import('/qa/xr-bootstrap.js');
}
await import('./app.js');
```

Normal application visits do not load the runtime. A flagged page permanently displays an emulation banner. Reload without the flag to restore the browser's unmodified XR environment.

The bootstrap signals readiness after installation and the banner exist. The parent accepts that signal only from its current same-origin app iframe, checks the runtime itself, and also waits up to 20 seconds when the document's `load` event precedes a dynamic import. Runtime readiness does not mean the production app or Lean data have finished loading; wait for the app's Enter VR button to become enabled.

## What runs for real

- The production app, its exact Lean HTTP transport and compiled computations.
- The vendored Three.js WebXRManager session setup, controller connections, frame updates, raycasting, scene transforms, session teardown, and desktop restoration.
- WebGL shaders and geometry rendering to the real app canvas's default framebuffer. The synthetic `XRWebGLLayer.framebuffer` is `null`, the WebGL default framebuffer, rather than an XR compositor target. Framebuffer resolution is capped at 1600 × 1000 to keep the Mac responsive.
- App handlers receive synthetic `selectstart`, `select`, `selectend`, squeeze, and input-source connection events through the session. The harness never calls production math or interaction handlers directly.

## Synthetic subset and limitations

`navigator.xr` provides only `immersive-vr`; session/reference-space/frame objects provide the subset consumed by this Three.js build. `local`, `local-floor` and `viewer` spaces, rigid offsets, a configurable head pose, two tracked-pointer controller poses, mono or a 64 mm stereo eye separation, perspective projection, depth ranges, animation frames, trigger/squeeze, and controller disconnection/reconnection are supported. Unsupported required features reject; optional hand tracking is not enabled. Hands/joints, real tracking, permissions, real browser immersive presentation, projection/composition layers, compositor behavior, depth sensing, hit testing, anchors, haptics, transient pointers, device loss, reference-space resets, timing deadlines, and physical controller ergonomics are not tested. Gamepad axes exist, but the current QA UI does not manipulate them.

In a flagged page only, the runtime overrides `navigator.xr`, `XRWebGLLayer`, `XRRigidTransform`, `XRWebGLBinding`, and `makeXRCompatible`. The last two force Three's base-layer path and permit a non-headset context. These are deliberate emulation differences. There is no attempt to certify browser security checks or opaque framebuffer semantics.

Controller event frames use the latest synthetic pose, including a pose changed between rendered frames. RAF callbacks use a browser animation scheduler; pose sequences are deterministic but wall-clock timing is not. The test does not prove renderer correctness or any mathematical theorem. Real headset and native/simulator results remain separate acceptance categories.

## Interaction recipe

1. Load a route. Use the production app's own **Enter VR** button. Verify the in-world geometry/readout and diagnostic frame counter.
2. Choose a known panel coordinate, press **Load coordinates**, then **Aim controller**. Inspect the real ray/hover. **Click trigger** supplies a press/release. The coordinate presets are fixtures, not app action shortcuts; if panel placement changes, the fixture should fail to hit.
3. For a real controller drag: enter a visible handle's world coordinates as the ray target; aim, **Trigger down**, change origin/target, **Aim controller**, then **Trigger up**. Check the actual resulting Lean receipt independently. Moving before release also covers the between-frame final-pose case.
4. Exercise Inside/Overview, Reset, and Exit through the actual ray/button intersection. Confirm the desktop camera is restored. Re-enter using the production Enter VR button; verify controllers reconnect and work.
5. Test Disconnect while a trigger is held, then Reconnect. Inspect app cancellation behavior rather than assuming it passed from the synthetic event log.
6. Exit, select side-by-side stereo, then re-enter; verify both eye views. Use viewport presets for independent responsive-layout checks. Stereo is a rendering test, not evidence of physical stereoscopic comfort.

The device interface is `iframe.contentWindow.xrTestRuntime`; its methods alter only synthetic device state. `snapshot()` is read-only diagnostic data. Pose setters use meters and quaternions `[x,y,z,w]`; `aimController(index, origin, target)` directs local `-Z` toward the target. `press/release(index)`, `squeeze(index, boolean)`, `setControllerConnected(index, boolean)`, `setViewerPose(position, quaternion)`, and `setStereo(boolean)` are explicit runtime test hooks. Application acceptance must inspect production results as well as these diagnostics.

The polynomial fixtures cover all 30 current panel buttons, including motion, generator composition and Snap. Their world coordinates are four columns at X = −0.36, −0.12, 0.12, 0.36; rows begin at Y = 1.25 and descend by 0.10; Z = −1.15. The first row is Next / Projection / Reset / Exit. Row seven is T: z+1 / S: −1/z / T inverse / Exact move; row eight is Snap / Toggle Snap release. The Identity fixture retains its original `polynomial-undo-motion` key, and the three generators retain their original `polynomial-set-*` keys for existing test sequences; the displayed labels and production behavior now use left composition. These are fixed test coordinates, not production-state introspection.

## Silent recording

**Start recording** captures the actual visible app canvases at up to 1280 × 800 / 24 fps, plus a 36-pixel evidence stripe (maximum total height 836 pixels). The stripe says **DESKTOP BROWSER** outside an XR session and **EMULATED WEBXR** during a synthetic session; neither is headset evidence. It uses `canvas.captureStream` + `MediaRecorder`; it never requests a microphone, display capture, camera, or an upload. Stop exposes a local download link. It automatically stops at 120 seconds or approximately 64 MB. The video excludes DOM controls outside the app canvases; this is appropriate for the in-world XR panels, but cannot alone certify desktop DOM behavior. Unsupported recording APIs report a failure. Always inspect the downloaded clip for actual rendered content before treating it as evidence.

When both production canvases are visible, the recorder captures **3D on the left and roots on the right** in the same clip. Each canvas supplies its own silent video track; the compositor reads those video frames, avoiding discarded WebGL backbuffer reads. It preserves both source aspect ratios and their relative backing-pixel sizes, with letterboxing where needed. The stripe explicitly identifies paired canvases. With one visible canvas, it records that canvas alone. These are separately delivered canvas streams, not synchronized compositor or physical-device evidence; the latest available frames can differ in capture timing.

If a view change adds, hides, replaces or switches a source canvas, or enters/exits XR, recording stops with an explicit message. The same check applies while waiting for the initial frames. A resize that retains the same canvases fits each current frame into its original slot without stretching. Start a separate clip for a new canvas set; the harness never silently records a hidden stale view. Only known production canvases (`#scene`, `#canvas`, `#viewport canvas`, and `#klein-canvas`) are eligible; offscreen texture/readout canvases are excluded.

A static desktop scene may not redraw immediately after recording is armed.
The status then says it is waiting for a rendered frame from each source. Use an ordinary scene
control, such as Identity, to redraw both views; XR frames normally arrive continuously. Startup can be stopped and fails explicitly after 30 seconds without all initial frames.

## Automated and manual evidence

`node --test tests/xr-runtime.test.mjs` checks the runtime's session teardown/reentry, fresh event-frame poses through the actual vendored Three controller and raycaster, reference spaces/stereo/depth, disconnect/reconnect, framebuffer/viewport mapping, unsupported capability rejection, and explicit installation. These Node tests do not create a browser or GPU. Browser screenshots, video, real WebGL rendering, application Lean-result assertions, and actual WebXRManager entry/exit require a separate browser run by the browser owner. Passing these tests alone does not pass app acceptance.

`node --test tests/capture-layout.test.mjs` checks single/paired output bounds, aspect preservation, resize letterboxing and source identity changes. It does not run MediaRecorder or certify recorded pixels; paired-video acceptance requires a browser recording and inspection of the downloaded clip.
