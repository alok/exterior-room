import test from 'node:test';
import assert from 'node:assert/strict';
import { Matrix4, Vector3, Quaternion, WebXRController, Raycaster, Mesh, PlaneGeometry, MeshBasicMaterial, DoubleSide } from '../web/vendor/three.module.js';
import { XRTestRuntime, TestXRFrame, TestXRWebGLLayer, TestRigidTransform, installTestXR } from '../web/qa/xr-runtime.js';
import { controllerRay } from '../web/xr-support.js';

function scheduler() {
  let id = 0, time = 0;
  const pending = new Map();
  return {
    navigator: {}, performance: { now: () => time },
    requestAnimationFrame: callback => { pending.set(++id, callback); return id; },
    cancelAnimationFrame: token => pending.delete(token),
    step() { time += 1000 / 60; const callbacks = [...pending.values()]; pending.clear(); for (const callback of callbacks) callback(time); },
    get pending() { return pending.size; },
  };
}
const near = (a, b, epsilon = 1e-6) => { assert.equal(a.length, b.length); a.forEach((v, i) => assert.ok(Math.abs(v - b[i]) < epsilon, `${v} != ${b[i]}`)); };

test('synthetic tracking reaches real Three controller raycasts, including an input between frames', async () => {
  const env = scheduler(), runtime = new XRTestRuntime(env);
  const session = await runtime.xr.requestSession('immersive-vr', { optionalFeatures: ['local-floor', 'hand-tracking'] });
  assert.ok(!session.enabledFeatures.includes('hand-tracking'));
  const reference = await session.requestReferenceSpace('local-floor');
  const controller = new WebXRController(), targetRay = controller.getTargetRaySpace();
  session.addEventListener('inputsourceschange', e => { for (const input of e.added) if (input.handedness === 'right') controller.connect(input); });
  const events = [], raycaster = new Raycaster();
  const flatten = new Mesh(new PlaneGeometry(.30, .10), new MeshBasicMaterial({ side: DoubleSide }));
  flatten.position.set(-.65, .88, -1.55); flatten.updateMatrixWorld(true);
  for (const type of ['selectstart', 'select', 'selectend']) session.addEventListener(type, e => {
    controller.update(e.inputSource, e.frame, reference);
    controllerRay(targetRay, raycaster);
    events.push({ type, hit: raycaster.intersectObject(flatten).length > 0, origin: raycaster.ray.origin.toArray() });
  });
  session.requestAnimationFrame((_, frame) => controller.update(session.inputSources[0], frame, reference));
  env.step();
  // No second rendered frame: the event frame must carry the fresh pose, not the previous RAF pose.
  runtime.aimController(0, [.25, 1.35, -.1], [-.65, .88, -1.55]); runtime.press();
  assert.equal(events[0].hit, true); assert.equal(events[0].type, 'selectstart');
  runtime.aimController(0, [.55, 1.35, -.1], [1, 2, -2]); runtime.release();
  assert.deepEqual(events.map(e => e.type), ['selectstart', 'select', 'selectend']);
  assert.equal(events[2].hit, false); near(events[2].origin, [.55, 1.35, -.1]);
  await session.end();
});

test('exit cancels queued frames, releases input, and allows a clean reconnecting session', async () => {
  const env = scheduler(), runtime = new XRTestRuntime(env), calls = [];
  const first = await runtime.xr.requestSession('immersive-vr');
  first.addEventListener('end', () => calls.push('end'));
  first.addEventListener('inputsourceschange', e => calls.push(`connected:${e.added.length}`));
  const loop = () => { calls.push('frame'); first.requestAnimationFrame(loop); };
  first.requestAnimationFrame(loop); env.step(); runtime.press();
  assert.equal(env.pending, 1); assert.equal(runtime.controllers[0].source.gamepad.buttons[0].pressed, true);
  await assert.rejects(runtime.xr.requestSession('immersive-vr'), { name: 'InvalidStateError' });
  await first.end(); await first.end(); env.step();
  assert.deepEqual(calls, ['connected:2', 'frame', 'end']); assert.equal(env.pending, 0);
  assert.equal(runtime.controllers[0].source.gamepad.buttons[0].pressed, false);
  assert.equal(first.requestAnimationFrame(() => assert.fail('Ended session frame')), 0);
  assert.throws(() => runtime.press(), /Enter VR/);
  const second = await runtime.xr.requestSession('immersive-vr');
  let connected = 0; second.addEventListener('inputsourceschange', e => { connected += e.added.length; });
  second.requestAnimationFrame(() => {}); env.step();
  assert.equal(connected, 2); assert.equal(runtime.snapshot().sessions, 2); assert.equal(second.frames, 1);
  await second.end();
});

test('reference spaces and stereo views have correct rigid transforms and projection depth', async () => {
  const runtime = new XRTestRuntime(scheduler()); runtime.setStereo(true);
  runtime.setViewerPose([1, 1.6, -2], [0, Math.sin(Math.PI / 4), 0, Math.cos(Math.PI / 4)]);
  const session = await runtime.xr.requestSession('immersive-vr'), frame = new TestXRFrame(session);
  const local = await session.requestReferenceSpace('local-floor');
  const offset = local.getOffsetReferenceSpace(new TestRigidTransform({ x: 1, y: 1.6, z: -2 }));
  const pose = frame.getViewerPose(offset); near([pose.transform.position.x, pose.transform.position.y, pose.transform.position.z], [0, 0, 0]);
  const left = new Vector3().setFromMatrixPosition(new Matrix4().fromArray(pose.views[0].transform.matrix));
  const right = new Vector3().setFromMatrixPosition(new Matrix4().fromArray(pose.views[1].transform.matrix));
  assert.ok(Math.abs(left.distanceTo(right) - .064) < 1e-6);
  assert.ok(pose.views.every(v => [...v.projectionMatrix].every(Number.isFinite)));
  const before = pose.views[0].projectionMatrix[14]; session.updateRenderState({ depthNear: .5, depthFar: 50 });
  assert.notEqual(frame.getViewerPose(local).views[0].projectionMatrix[14], before);
  const viewerSpace = await session.requestReferenceSpace('viewer');
  near([...frame.getViewerPose(viewerSpace).transform.matrix], new Matrix4().elements);
  assert.throws(() => runtime.setStereo(false), /Exit the session/);
  await session.end();
});

test('disconnect cancels pressed input and removes pose until explicit reconnect', async () => {
  const env = scheduler(), runtime = new XRTestRuntime(env), session = await runtime.xr.requestSession('immersive-vr');
  const changes = []; session.addEventListener('inputsourceschange', e => changes.push([e.added.length, e.removed.length]));
  session.requestAnimationFrame(() => {}); env.step(); runtime.press(); runtime.setControllerConnected(0, false);
  const frame = new TestXRFrame(session), reference = await session.requestReferenceSpace('local');
  assert.equal(frame.getPose(runtime.controllers[0].source.targetRaySpace, reference), null);
  assert.throws(() => runtime.press(), /disconnected/); assert.equal(session.inputSources.length, 1);
  runtime.setControllerConnected(0, true);
  assert.equal(runtime.controllers[0].source.gamepad.buttons[0].pressed, false);
  assert.notEqual(frame.getPose(runtime.controllers[0].source.targetRaySpace, reference), null);
  assert.deepEqual(changes, [[2, 0], [0, 1], [1, 0]]); await session.end();
});

test('layer renders to the actual default framebuffer with bounded mono/stereo viewports', async () => {
  const runtime = new XRTestRuntime(scheduler()), session = await runtime.xr.requestSession('immersive-vr');
  const layer = new TestXRWebGLLayer(session, { drawingBufferWidth: 3200, drawingBufferHeight: 1800, getContextAttributes: () => ({ antialias: true }) });
  session.updateRenderState({ baseLayer: layer });
  assert.equal(layer.framebuffer, null); assert.equal(layer.framebufferWidth, 1600); assert.equal(layer.framebufferHeight, 900);
  assert.deepEqual(layer.getViewport({ eye: 'none' }), { x: 0, y: 0, width: 1600, height: 900 });
  await session.end(); runtime.setStereo(true);
  const next = await runtime.xr.requestSession('immersive-vr');
  const stereo = new TestXRWebGLLayer(next, { drawingBufferWidth: 801, drawingBufferHeight: 600, getContextAttributes: () => ({}) });
  assert.deepEqual(stereo.getViewport({ eye: 'left' }), { x: 0, y: 0, width: 400, height: 600 });
  assert.deepEqual(stereo.getViewport({ eye: 'right' }), { x: 400, y: 0, width: 401, height: 600 });
  await next.end();
});

test('unsupported capabilities and invalid poses fail instead of pretending hardware support', async () => {
  const runtime = new XRTestRuntime(scheduler());
  assert.equal(await runtime.xr.isSessionSupported('immersive-ar'), false);
  await assert.rejects(runtime.xr.requestSession('immersive-ar'), { name: 'NotSupportedError' });
  await assert.rejects(runtime.xr.requestSession('immersive-vr', { requiredFeatures: ['hand-tracking'] }), { name: 'NotSupportedError' });
  assert.throws(() => runtime.setViewerPose([NaN, 1, 0]), /finite/);
  assert.throws(() => runtime.setControllerPose(0, [0, 0, 0], [0, 0, 0, 0]), /nonzero/);
  assert.throws(() => runtime.aimController(0, [0, 0, 0], [0, 0, 0]), /differ/);
  const session = await runtime.xr.requestSession('immersive-vr');
  await assert.rejects(session.requestReferenceSpace('bounded-floor'), { name: 'NotSupportedError' });
  await session.end();
});

test('installation is explicit, page scoped and idempotent; no context is created', async () => {
  const env = scheduler(); env.WebGL2RenderingContext = class {};
  const runtime = installTestXR(env);
  assert.equal(env.navigator.xr, runtime.xr); assert.equal(installTestXR(env), runtime);
  assert.equal(env.XRWebGLBinding, undefined); assert.equal(env.XRWebGLLayer, TestXRWebGLLayer);
  await new env.WebGL2RenderingContext().makeXRCompatible();
  assert.equal(runtime.snapshot().presenting, false);
  assert.match(runtime.snapshot().evidence, /no headset evidence/);
});
