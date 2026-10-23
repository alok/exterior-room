import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from '../web/vendor/three.module.js';
import {xrAvailability, controllerRay, captureView, restoreView} from '../web/xr-support.js';

const near = (actual, expected, epsilon=1e-10) => {
  assert.equal(actual.length, expected.length);
  actual.forEach((n,i)=>assert.ok(Math.abs(n-expected[i]) < epsilon, `${n} != ${expected[i]}`));
};

test('unavailable or rejected XR remains an explicit desktop fallback', async () => {
  assert.equal((await xrAvailability(undefined,true)).supported,false);
  let probed=false;
  assert.equal((await xrAvailability({isSessionSupported:async()=>{probed=true;return true;}},false)).supported,false);
  assert.equal(probed,false);
  assert.equal((await xrAvailability({isSessionSupported:async()=>{throw Error('device unavailable');}},true)).supported,false);
  assert.equal((await xrAvailability({isSessionSupported:async mode=>mode==='immersive-vr'},true)).supported,true);
});

test('controller ray consumes current parent and local pose before a rendered frame', () => {
  const root=new THREE.Group(), controller=new THREE.Group();root.add(controller);
  root.position.set(1,2,3);root.rotation.y=Math.PI/2;root.scale.setScalar(2);
  controller.position.set(0,0,-1);
  const raycaster=new THREE.Raycaster();
  controllerRay(controller,raycaster);
  near(raycaster.ray.origin.toArray(),[-1,2,3]);
  near(raycaster.ray.direction.toArray(),[-1,0,0]);
  assert.ok(Math.abs(raycaster.ray.direction.length()-1)<1e-10);
  // No explicit updateMatrixWorld call between the two poses.
  root.position.set(3,4,5);controller.position.set(0,0,-2);
  controllerRay(controller,raycaster);
  near(raycaster.ray.origin.toArray(),[-1,4,5]);
});

test('desktop view snapshots are independent and restore headset-mutated projection', () => {
  const camera=new THREE.PerspectiveCamera(42,1.5,.025,100);
  camera.position.set(6,4,8);camera.lookAt(-.6,1,0);camera.zoom=1.3;camera.updateProjectionMatrix();
  let updates=0;
  const controls={target:new THREE.Vector3(-.6,1,0),enabled:true,update(){updates++;}};
  const view=captureView(camera,controls), originalQuaternion=camera.quaternion.toArray();
  camera.position.set(0,1.6,0);camera.quaternion.identity();camera.fov=90;camera.zoom=1;
  controls.target.set(0,0,0);camera.aspect=2;
  restoreView(view,camera,controls);
  near(camera.position.toArray(),[6,4,8]);
  near(camera.quaternion.toArray(),originalQuaternion);
  near(controls.target.toArray(),[-.6,1,0]);
  assert.equal(camera.fov,42);assert.equal(camera.zoom,1.3);assert.equal(camera.aspect,2);assert.equal(updates,1);
  const expected=new THREE.PerspectiveCamera(42,2,.025,100);expected.zoom=1.3;expected.updateProjectionMatrix();
  near(camera.projectionMatrix.elements,expected.projectionMatrix.elements);
});

test('restore does not let disabled OrbitControls clamp an egocentric pose', () => {
  const camera=new THREE.PerspectiveCamera();
  const controls={target:new THREE.Vector3(1,0,0),enabled:false,update(){throw Error('disabled control update');}};
  camera.position.set(.1,.2,.3);const view=captureView(camera,controls);
  camera.position.set(10,10,10);controls.target.set(20,20,20);
  restoreView(view,camera,controls);
  near(camera.position.toArray(),[.1,.2,.3]);near(controls.target.toArray(),[1,0,0]);
});
