// SPDX-License-Identifier: GPL-3.0-or-later
// QA ONLY. Synthetic devices, real Three.js WebXRManager and real WebGL rendering.
// This deliberately small runtime double is neither a WebXR polyfill nor a conformance implementation.
import { Matrix4, Quaternion, Vector3, PerspectiveCamera } from '../vendor/three.module.js';

const UNIT = new Vector3(1, 1, 1);
const FORWARD = new Vector3(0, 0, -1);
function numbers(value, length, label) {
  if (!Array.isArray(value) || value.length !== length || value.some(n => !Number.isFinite(n))) {
    throw new TypeError(`${label} must contain ${length} finite numbers`);
  }
  return value;
}
function rigidMatrix(position, orientation) {
  const q = new Quaternion().fromArray(numbers(orientation, 4, 'orientation'));
  if (q.lengthSq() < 1e-12) throw new RangeError('orientation must be a nonzero quaternion');
  return new Matrix4().compose(new Vector3().fromArray(numbers(position, 3, 'position')), q.normalize(), UNIT);
}
function transform(matrix, withInverse = true) {
  const p = new Vector3(), q = new Quaternion();
  matrix.decompose(p, q, new Vector3());
  const result = {
    matrix: new Float32Array(matrix.elements),
    position: Object.freeze({ x: p.x, y: p.y, z: p.z, w: 1 }),
    orientation: Object.freeze({ x: q.x, y: q.y, z: q.z, w: q.w }),
  };
  if (withInverse) result.inverse = transform(matrix.clone().invert(), false);
  return result;
}
function event(type, properties = {}) {
  return Object.assign(new Event(type), properties);
}

export class TestRigidTransform {
  constructor(position = {}, orientation = {}) {
    Object.assign(this, transform(rigidMatrix(
      [position.x ?? 0, position.y ?? 0, position.z ?? 0],
      [orientation.x ?? 0, orientation.y ?? 0, orientation.z ?? 0, orientation.w ?? 1],
    )));
  }
}

class TestReferenceSpace extends EventTarget {
  constructor(type, matrix = new Matrix4()) { super(); this.type = type; this._matrix = matrix; }
  getOffsetReferenceSpace(offset) {
    if (!offset?.matrix || offset.matrix.length !== 16) throw new TypeError('Expected a rigid transform');
    return new TestReferenceSpace(this.type, this._matrix.clone().multiply(new Matrix4().fromArray(offset.matrix)));
  }
}

export class TestXRFrame {
  constructor(session) { this.session = session; this.predictedDisplayTime = session.runtime.env.performance?.now() ?? 0; }
  _relative(matrix, referenceSpace) {
    if (!(referenceSpace instanceof TestReferenceSpace)) throw new TypeError('Unknown reference space');
    const origin = referenceSpace.type === 'viewer' ? this.session.runtime.viewer : new Matrix4();
    return origin.clone().multiply(referenceSpace._matrix).invert().multiply(matrix);
  }
  getViewerPose(referenceSpace) {
    const { runtime, renderState } = this.session;
    const layer = renderState.baseLayer;
    const width = layer?.framebufferWidth ?? 1280, height = layer?.framebufferHeight ?? 800;
    const eyes = runtime.stereo ? ['left', 'right'] : ['none'];
    return {
      transform: transform(this._relative(runtime.viewer, referenceSpace)), emulatedPosition: true,
      views: eyes.map(eye => {
        const eyeOffset = eye === 'none' ? 0 : eye === 'left' ? -0.032 : 0.032;
        const matrix = runtime.viewer.clone().multiply(new Matrix4().makeTranslation(eyeOffset, 0, 0));
        const camera = new PerspectiveCamera(runtime.fov, width / height / eyes.length, renderState.depthNear, renderState.depthFar);
        return { eye, transform: transform(this._relative(matrix, referenceSpace)), projectionMatrix: new Float32Array(camera.projectionMatrix.elements) };
      }),
    };
  }
  getPose(space, referenceSpace) {
    const controller = this.session.runtime.controllers.find(c => c.source.targetRaySpace === space || c.source.gripSpace === space);
    if (!controller || !controller.connected) return null;
    return { transform: transform(this._relative(controller.matrix, referenceSpace)), emulatedPosition: true };
  }
}

export class TestXRWebGLLayer {
  constructor(session, gl) {
    if (session.ended) throw new Error('Session has ended');
    this.session = session;
    // null is WebGL's actual onscreen default framebuffer. No image or renderer output is fabricated.
    this.framebuffer = null;
    const scale = Math.min(1, 1600 / gl.drawingBufferWidth, 1000 / gl.drawingBufferHeight);
    this.framebufferWidth = Math.max(2, Math.floor(gl.drawingBufferWidth * scale));
    this.framebufferHeight = Math.max(2, Math.floor(gl.drawingBufferHeight * scale));
    this.ignoreDepthValues = false;
    this.fixedFoveation = 0;
    this.antialias = !!gl.getContextAttributes()?.antialias;
  }
  getViewport(view) {
    if (!this.session.runtime.stereo) return { x: 0, y: 0, width: this.framebufferWidth, height: this.framebufferHeight };
    const half = Math.floor(this.framebufferWidth / 2);
    return { x: view.eye === 'right' ? half : 0, y: 0, width: view.eye === 'right' ? this.framebufferWidth - half : half, height: this.framebufferHeight };
  }
  static getNativeFramebufferScaleFactor() { return 1; }
}

export class TestXRSession extends EventTarget {
  constructor(runtime, options) {
    super();
    this.runtime = runtime; this.mode = 'immersive-vr'; this.ended = false;
    this.visibilityState = 'visible'; this.environmentBlendMode = 'opaque'; this.interactionMode = 'world-space';
    this.enabledFeatures = ['local', 'local-floor', 'viewer'].filter(f => f === 'viewer' || [...options.requiredFeatures ?? [], ...options.optionalFeatures ?? []].includes(f));
    this.renderState = { depthNear: 0.1, depthFar: 1000, baseLayer: null, inlineVerticalFieldOfView: null };
    this._pending = new Set(); this._connected = false; this.frames = 0;
  }
  get inputSources() { return this.runtime.controllers.filter(c => c.connected).map(c => c.source); }
  updateRenderState(state) {
    if (this.ended) throw new Error('Session has ended');
    if ('depthNear' in state && !(state.depthNear > 0)) throw new RangeError('depthNear must be positive');
    if ('depthFar' in state && !(state.depthFar > (state.depthNear ?? this.renderState.depthNear))) throw new RangeError('depthFar must exceed depthNear');
    Object.assign(this.renderState, state);
  }
  async requestReferenceSpace(type) {
    if (this.ended) throw new Error('Session has ended');
    if (!['local', 'local-floor', 'viewer'].includes(type)) throw new DOMException(`Unsupported reference space: ${type}`, 'NotSupportedError');
    return new TestReferenceSpace(type);
  }
  _connect() {
    if (this._connected || this.ended) return;
    this._connected = true;
    this.dispatchEvent(event('inputsourceschange', { session: this, added: this.inputSources, removed: [] }));
  }
  requestAnimationFrame(callback) {
    if (this.ended) return 0;
    const id = this.runtime.env.requestAnimationFrame(time => {
      this._pending.delete(id);
      if (this.ended) return;
      this._connect(); this.frames++; this.runtime.frames++;
      callback(time, new TestXRFrame(this));
    });
    this._pending.add(id); return id;
  }
  cancelAnimationFrame(id) { this.runtime.env.cancelAnimationFrame(id); this._pending.delete(id); }
  async end() {
    if (this.ended) return;
    this.ended = true;
    for (const id of this._pending) this.runtime.env.cancelAnimationFrame(id);
    this._pending.clear();
    for (const controller of this.runtime.controllers) for (const button of controller.source.gamepad.buttons) Object.assign(button, { pressed: false, touched: false, value: 0 });
    this.runtime.activeSession = null;
    this.runtime.log('sessionend');
    this.dispatchEvent(event('end', { session: this }));
  }
}

export class XRTestRuntime extends EventTarget {
  constructor(env) {
    super(); this.env = env; this.activeSession = null; this.sessions = 0; this.frames = 0;
    this.stereo = false; this.fov = 70; this.events = [];
    this.viewer = rigidMatrix([0, 1.6, 0], [0, 0, 0, 1]);
    this.controllers = ['right', 'left'].map((handedness, index) => ({
      connected: true, matrix: rigidMatrix([index === 0 ? 0.25 : -0.25, 1.35, -0.1], [0, 0, 0, 1]),
      source: {
        handedness, targetRayMode: 'tracked-pointer', profiles: ['generic-trigger-squeeze-thumbstick'],
        targetRaySpace: {}, gripSpace: {},
        gamepad: { id: 'QA synthetic controller', index, mapping: 'xr-standard', connected: true, timestamp: 0,
          axes: [0, 0, 0, 0], buttons: Array.from({ length: 6 }, () => ({ pressed: false, touched: false, value: 0 })), hapticActuators: [] },
      },
    }));
    this.xr = {
      isSessionSupported: async mode => mode === 'immersive-vr',
      requestSession: async (mode, options = {}) => {
        if (mode !== 'immersive-vr') throw new DOMException('Only immersive-vr is emulated', 'NotSupportedError');
        if (this.activeSession) throw new DOMException('An emulated session is already active', 'InvalidStateError');
        const unsupported = (options.requiredFeatures ?? []).filter(f => !['local', 'local-floor', 'viewer'].includes(f));
        if (unsupported.length) throw new DOMException(`Unsupported required features: ${unsupported.join(', ')}`, 'NotSupportedError');
        const session = new TestXRSession(this, options);
        this.activeSession = session; this.sessions++; this.log('sessionstart'); return session;
      },
      addEventListener: this.addEventListener.bind(this), removeEventListener: this.removeEventListener.bind(this),
    };
  }
  log(type, details = {}) { this.events.push({ type, ...details }); if (this.events.length > 60) this.events.shift(); }
  setStereo(value) { if (this.activeSession) throw new Error('Exit the session before changing stereo mode'); this.stereo = !!value; }
  setViewerPose(position, orientation = [0, 0, 0, 1]) { this.viewer = rigidMatrix(position, orientation); this.log('viewerpose', { position: [...position] }); }
  _controller(index) { const c = this.controllers[index]; if (!c) throw new RangeError('Controller index must be 0 or 1'); return c; }
  setControllerPose(index, position, orientation = [0, 0, 0, 1]) {
    this._controller(index).matrix = rigidMatrix(position, orientation); this.log('controllerpose', { index, position: [...position] });
  }
  aimController(index, origin, target) {
    const direction = new Vector3().fromArray(numbers(target, 3, 'target')).sub(new Vector3().fromArray(numbers(origin, 3, 'origin')));
    if (direction.lengthSq() < 1e-12) throw new RangeError('Target must differ from controller origin');
    this.setControllerPose(index, origin, new Quaternion().setFromUnitVectors(FORWARD, direction.normalize()).toArray());
  }
  setControllerConnected(index, connected) {
    const c = this._controller(index); if (c.connected === !!connected) return;
    c.connected = !!connected; c.source.gamepad.connected = c.connected;
    for (const button of c.source.gamepad.buttons) Object.assign(button, { pressed: false, touched: false, value: 0 });
    if (this.activeSession?._connected) this.activeSession.dispatchEvent(event('inputsourceschange', {
      session: this.activeSession, added: c.connected ? [c.source] : [], removed: c.connected ? [] : [c.source],
    }));
    this.log(c.connected ? 'connected' : 'disconnected', { index });
  }
  _input(index, family, pressed) {
    const session = this.activeSession, c = this._controller(index);
    if (!session || session.ended) throw new Error('Enter VR through the production app first');
    if (!c.connected) throw new Error('Controller is disconnected');
    session._connect();
    const button = c.source.gamepad.buttons[family === 'select' ? 0 : 1];
    if (button.pressed === pressed) return;
    Object.assign(button, { pressed, touched: pressed, value: pressed ? 1 : 0 });
    const emit = type => { this.log(type, { index }); session.dispatchEvent(event(type, { inputSource: c.source, frame: new TestXRFrame(session) })); };
    if (pressed) emit(`${family}start`);
    else { emit(family); emit(`${family}end`); }
  }
  press(index = 0) { this._input(index, 'select', true); }
  release(index = 0) { this._input(index, 'select', false); }
  squeeze(index = 0, pressed = true) { this._input(index, 'squeeze', pressed); }
  setAxes(index, axes) { this._controller(index).source.gamepad.axes = [...numbers(axes, 4, 'axes')].map(n => Math.max(-1, Math.min(1, n))); }
  snapshot() {
    return { evidence: 'EMULATED WEBXR — no headset evidence', presenting: !!this.activeSession, stereo: this.stereo,
      sessions: this.sessions, frames: this.frames, sessionFrames: this.activeSession?.frames ?? 0,
      framebuffer: this.activeSession?.renderState.baseLayer ? { width: this.activeSession.renderState.baseLayer.framebufferWidth, height: this.activeSession.renderState.baseLayer.framebufferHeight, kind: 'real canvas default framebuffer' } : null,
      viewer: Array.from(this.viewer.elements), controllers: this.controllers.map(c => ({ handedness: c.source.handedness, connected: c.connected, matrix: Array.from(c.matrix.elements), pressed: c.source.gamepad.buttons[0].pressed })), events: this.events.map(e => ({ ...e })) };
  }
}

export function installTestXR(env = window) {
  if (env.xrTestRuntime) return env.xrTestRuntime;
  const runtime = new XRTestRuntime(env);
  Object.defineProperty(env.navigator, 'xr', { configurable: true, value: runtime.xr });
  Object.defineProperty(env, 'XRWebGLLayer', { configurable: true, value: TestXRWebGLLayer });
  Object.defineProperty(env, 'XRRigidTransform', { configurable: true, value: TestRigidTransform });
  // Force Three's base-layer path. Composition layers and makeXRCompatible cannot use nonexistent hardware.
  Object.defineProperty(env, 'XRWebGLBinding', { configurable: true, value: undefined });
  for (const type of ['WebGLRenderingContext', 'WebGL2RenderingContext']) {
    if (env[type]) Object.defineProperty(env[type].prototype, 'makeXRCompatible', { configurable: true, value: async () => {} });
  }
  Object.defineProperty(env, 'xrTestRuntime', { configurable: true, value: runtime });
  return runtime;
}
