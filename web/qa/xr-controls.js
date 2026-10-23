// SPDX-License-Identifier: GPL-3.0-or-later
import { Euler, Quaternion } from '../vendor/three.module.js';

const $ = id => document.getElementById(id), frame = $('app');
const routes = { exterior: '/exterior/?qaXR=1', polynomial: '/polynomial/?qaXR=1' };
// Fixed geometric fixtures from polynomial/app.js's panel. They supply rays,
// not action dispatches, and intentionally do not introspect production button positions.
const polynomialFixtures = [
  ['next', 'Next'], ['projection', 'Projection'], ['reset', 'Reset'], ['exit', 'Exit'],
  ['origin', 'Origin'], ['inhabit', 'Inhabit'], ['overview', 'Overview'], ['other-side', 'Other side'],
  ['radius', 'Cycle radius'], ['whole', 'Whole'], ['lower-color', 'Lower color'], ['cone', 'Cone'],
  ['pair', 'Pair aim'], ['clear-pair', 'Clear pair'], ['plane-fade', 'Plane fade'], ['colors', 'Colors'],
  ['size-down', 'Size −'], ['size-up', 'Size +'], ['forward', 'Forward'], ['back', 'Back'],
  ['left', 'Left'], ['right', 'Right'],
  ['move-forms', 'Move forms'], ['undo-motion', 'Identity'],
  ['set-t', 'T: z+1'], ['set-s', 'S: −1/z'], ['set-t-inverse', 'T inverse'], ['exact-move', 'Exact move'],
  ['snap', 'Snap'], ['snap-release', 'Toggle Snap release'],
];
const fixtures = {
  'exterior-flatten': [-.65, .88, -1.55], 'exterior-view': [-.65, .76, -1.55],
  'exterior-reset': [-.98, .76, -1.55], 'exterior-exit': [-.32, .76, -1.55],
  ...Object.fromEntries(polynomialFixtures.map(([key], i) => [`polynomial-${key}`,
    [Number(((i % 4 - 1.5) * .24).toFixed(2)), Number((1.25 - Math.floor(i / 4) * .10).toFixed(2)), -1.15]])),
};
for (const [key, label] of polynomialFixtures) {
  const option = document.createElement('option'); option.value = `polynomial-${key}`; option.textContent = `Polynomial · ${label}`; $('fixture').append(option);
}
function runtime() {
  const value = frame.contentWindow?.xrTestRuntime;
  if (!value) throw new Error('QA runtime is not installed yet. The app must load xr-bootstrap.js before its production module when ?qaXR=1.');
  return value;
}
function status(message) { $('status').textContent = message; }
function action(id, fn) { $(id).addEventListener('click', async () => { try { const message = await fn(); status(typeof message === 'string' ? message : `${$(id).textContent}: supplied synthetic input. Verify the app result separately.`); } catch (error) { status(error.message); } }); }
function vector(prefix) {
  const result = ['x', 'y', 'z'].map(axis => Number($(prefix + '-' + axis).value));
  if (result.some(n => !Number.isFinite(n))) throw new Error('Pose coordinates must be finite numbers.');
  return result;
}
function setVector(prefix, value) { ['x', 'y', 'z'].forEach((axis, i) => { $(prefix + '-' + axis).value = value[i]; }); }
const index = () => Number($('controller').value);
let readyTimer = null, readyRuntime = null, expectedURL = null;
function markRuntimeReady() {
  if (frame.contentWindow?.location.href !== expectedURL) return false;
  const value = frame.contentWindow?.xrTestRuntime;
  if (!value) return false;
  clearTimeout(readyTimer); readyTimer = null;
  if (readyRuntime !== value) {
    readyRuntime = value;
    status('QA runtime installed. When the app’s Enter VR button is enabled, enter and then aim/click a synthetic controller.');
  }
  return true;
}
function waitForRuntime() {
  clearTimeout(readyTimer);
  if (markRuntimeReady()) return;
  status('App document loaded; waiting for its asynchronous QA runtime bootstrap…');
  const deadline = performance.now() + 20_000;
  function check() {
    if (markRuntimeReady()) return;
    if (performance.now() >= deadline) { readyTimer = null; status('QA runtime did not become ready within 20 seconds. Check that xr-bootstrap.js is imported before the app module with ?qaXR=1.'); return; }
    readyTimer = setTimeout(check, 200);
  }
  readyTimer = setTimeout(check, 200);
}
function load() {
  stopRecording();
  const route = routes[$('route').value];
  clearTimeout(readyTimer); readyTimer = null; readyRuntime = null; expectedURL = new URL(route, location.href).href;
  frame.src = route; $('standalone').href = route;
  const message = 'Loading the actual production app with explicit QA emulation.'; status(message); return message;
}
action('load', load);
frame.addEventListener('load', waitForRuntime);
window.addEventListener('message', e => {
  if (e.origin === location.origin && e.source === frame.contentWindow && e.data?.type === 'exterior-room-qa-xr-ready') markRuntimeReady();
});
function resizeViewport() {
  const value = $('viewport').value;
  if (value === 'fit') { frame.style.width = '100%'; frame.style.height = '100%'; }
  else { const [w, h] = value.split(',').map(Number); frame.style.width = `${w}px`; frame.style.height = `${h}px`; }
}
$('viewport').addEventListener('change', resizeViewport);
$('stereo').addEventListener('change', () => { try { runtime().setStereo($('stereo').checked); status('Synthetic view layout changed. Enter VR to render it.'); } catch (e) { $('stereo').checked = runtime().stereo; status(e.message); } });
action('viewer-apply', () => {
  const yaw = Number($('viewer-yaw').value) * Math.PI / 180, pitch = Number($('viewer-pitch').value) * Math.PI / 180;
  runtime().setViewerPose(vector('viewer'), new Quaternion().setFromEuler(new Euler(pitch, yaw, 0, 'YXZ')).toArray());
});
action('viewer-home', () => { setVector('viewer', [0, 1.6, 0]); $('viewer-yaw').value = 0; $('viewer-pitch').value = 0; runtime().setViewerPose([0, 1.6, 0]); });
action('fixture-load', () => setVector('target', fixtures[$('fixture').value]));
action('aim', () => runtime().aimController(index(), vector('origin'), vector('target')));
action('press', () => runtime().press(index()));
action('release', () => runtime().release(index()));
action('click', () => { const r = runtime(); r.press(index()); if (r.activeSession) r.release(index()); });
action('squeeze-down', () => runtime().squeeze(index(), true));
action('squeeze-up', () => runtime().squeeze(index(), false));
action('disconnect', () => runtime().setControllerConnected(index(), false));
action('reconnect', () => runtime().setControllerConnected(index(), true));
action('end', () => runtime().activeSession?.end());

// This records only the real app canvas. The extra stripe is a disclosed evidence label, never invented UI.
// There are no getUserMedia/getDisplayMedia calls, audio tracks, networking, or uploads.
let capture = null, captureStarting = false, downloadURL = null;
function stopRecording() { if (capture && capture.recorder.state !== 'inactive') capture.recorder.stop(); }
function visibleAppCanvas() {
  const doc = frame.contentDocument, view = frame.contentWindow;
  if (!doc || !view) return null;
  // The roots pane and 3D pane have distinct canvases. Prefer the visible roots pane,
  // then the known production scene, and never capture an offscreen texture/readout canvas.
  const candidates = [...new Set(['#klein-canvas', 'canvas#scene', 'canvas#canvas', '#viewport canvas', 'canvas']
    .flatMap(selector => [...doc.querySelectorAll(selector)]))];
  return candidates.find(canvas => {
    const rect = canvas.getBoundingClientRect(), style = view.getComputedStyle(canvas);
    return canvas.width > 0 && canvas.height > 0 && rect.width > 0 && rect.height > 0 &&
      style.display !== 'none' && style.visibility !== 'hidden' && style.visibility !== 'collapse' && Number(style.opacity) !== 0;
  }) ?? null;
}
action('record', async () => {
  if (capture || captureStarting) throw new Error('A recording is already running or starting.');
  const source = visibleAppCanvas();
  if (!source) throw new Error('No visible rendered app canvas found.');
  if (!window.MediaRecorder || !HTMLCanvasElement.prototype.captureStream) throw new Error('This browser does not support canvas MediaRecorder. No clip has been captured.');
  // Read via the canvas's video track. Direct drawImage(WebGLCanvas) in the parent RAF can race
  // the child's renderer and copy an already-discarded backbuffer when preserveDrawingBuffer is false.
  captureStarting = true; $('record').disabled = true;
  $('recording-status').textContent = 'Waiting for the next rendered app frame; interact with the scene to begin.';
  const sourceStream = source.captureStream(24);
  const video = document.createElement('video'); video.muted = true; video.playsInline = true; video.srcObject = sourceStream;
  try { await video.play(); } catch (error) { sourceStream.getTracks().forEach(track => track.stop()); captureStarting = false; $('record').disabled = false; throw error; }
  const maxScale = Math.min(1, 1280 / source.width, 800 / source.height);
  const canvas = document.createElement('canvas'); canvas.width = Math.round(source.width * maxScale); canvas.height = Math.round(source.height * maxScale) + 36;
  const context = canvas.getContext('2d');
  const stream = canvas.captureStream(24);
  const mime = ['video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm', 'video/mp4'].find(type => MediaRecorder.isTypeSupported(type));
  let recorder;
  try { recorder = new MediaRecorder(stream, mime ? { mimeType: mime, videoBitsPerSecond: 2_500_000 } : {}); }
  catch (error) { [...stream.getTracks(), ...sourceStream.getTracks()].forEach(track => track.stop()); video.pause(); video.srcObject = null; captureStarting = false; $('record').disabled = false; throw error; }
  const record = { recorder, stream, sourceStream, video, chunks: [], bytes: 0, raf: null, timeout: null, source, route: $('route').value };
  capture = record; captureStarting = false;
  function draw() {
    if (visibleAppCanvas() !== source) {
      record.stopReason = 'The visible app canvas changed. Recording stopped; start a new clip for the current view.';
      stopRecording(); return;
    }
    context.fillStyle = '#080f16'; context.fillRect(0, 0, canvas.width, canvas.height);
    if (video.readyState >= 2) context.drawImage(video, 0, 36, canvas.width, canvas.height - 36);
    context.fillStyle = '#4a2c00'; context.fillRect(0, 0, canvas.width, 36);
    context.fillStyle = '#fff3cd'; context.font = 'bold 12px system-ui';
    const emulatedSession = !!frame.contentWindow?.xrTestRuntime?.activeSession;
    context.fillText(emulatedSession ? 'EMULATED WEBXR · no headset evidence' : 'DESKTOP BROWSER · no headset evidence', 10, 14);
    context.font = '11px system-ui'; context.fillText(emulatedSession ? 'Actual app canvas · synthetic device input' : 'Actual app canvas · desktop input', 10, 29);
    if (recorder.state !== 'inactive') record.raf = requestAnimationFrame(draw);
  }
  recorder.ondataavailable = e => { if (e.data.size) { record.chunks.push(e.data); record.bytes += e.data.size; } if (record.bytes > 64 * 1024 * 1024) stopRecording(); };
  recorder.onstop = () => {
    cancelAnimationFrame(record.raf); clearTimeout(record.timeout);
    [...stream.getTracks(), ...sourceStream.getTracks()].forEach(track => track.stop()); video.pause(); video.srcObject = null; capture = null;
    const blob = new Blob(record.chunks, { type: recorder.mimeType || 'video/webm' });
    if (downloadURL) URL.revokeObjectURL(downloadURL);
    downloadURL = URL.createObjectURL(blob); const link = $('download');
    link.textContent = 'Download silent app clip';
    link.href = downloadURL; link.download = `exterior-room-${record.route}-APP-CANVAS-${new Date().toISOString().replaceAll(':', '-')}.${blob.type.includes('mp4') ? 'mp4' : 'webm'}`; link.hidden = false;
    $('recording-status').textContent = `${(blob.size / 1024 / 1024).toFixed(2)} MB · ${blob.type} · no audio · canvas ${source.id || '(unnamed)'}`;
    if (record.stopReason) status(record.stopReason);
    $('record').disabled = false; $('stop').disabled = true;
  };
  recorder.onerror = e => { status(`Recording failed: ${e.error?.message ?? 'MediaRecorder error'}`); stopRecording(); };
  recorder.start(1000); draw(); record.timeout = setTimeout(stopRecording, 120_000);
  $('record').disabled = true; $('stop').disabled = false; $('download').hidden = true;
  $('recording-status').textContent = 'Recording canvas only, silent · automatically stops at 120 seconds / 64 MB.';
  return 'Recording the actual app canvas. The evidence stripe identifies desktop or emulated XR frames.';
});
action('stop', () => { stopRecording(); return 'Stopping the silent app-canvas recording.'; });
window.addEventListener('pagehide', () => { stopRecording(); if (downloadURL) URL.revokeObjectURL(downloadURL); });
setInterval(() => {
  const r = frame.contentWindow?.xrTestRuntime;
  if (r) { const snapshot = r.snapshot(); $('diagnostics').textContent = JSON.stringify(snapshot, null, 2); $('stereo').checked = snapshot.stereo; }
}, 750);
const selected = new URLSearchParams(location.search).get('route');
if (Object.hasOwn(routes, selected)) $('route').value = selected;
load();
