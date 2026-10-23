// SPDX-License-Identifier: GPL-3.0-or-later
export async function xrAvailability(xr, secureContext) {
  if (!secureContext) return { supported: false, message: 'VR needs HTTPS or localhost.' };
  if (!xr) return { supported: false, message: 'This browser does not expose WebXR. Desktop exploration is available.' };
  try {
    const supported = await xr.isSessionSupported('immersive-vr');
    return { supported, message: supported ? 'Immersive VR is available. Entry may require browser consent.' : 'No immersive VR device is available in this browser. Desktop exploration is available.' };
  } catch {
    return { supported: false, message: 'The browser could not check VR availability. Desktop exploration is available.' };
  }
}

export function controllerRay(controller, raycaster) {
  // Transient input can arrive between rendered frames, after Three.js updates only the local pose.
  controller.updateWorldMatrix(true, false);
  raycaster.ray.origin.setFromMatrixPosition(controller.matrixWorld);
  raycaster.ray.direction.set(0, 0, -1).transformDirection(controller.matrixWorld);
}

// XR frames overwrite the camera's projection, fov (from the headset) and zoom (to 1), so a saved
// view keeps them too. The projection is rebuilt from the current aspect, which follows the viewport.
export function captureView(camera, controls) {
  return { position: camera.position.clone(), quaternion: camera.quaternion.clone(), target: controls.target.clone(),
    fov: camera.fov, zoom: camera.zoom };
}

export function restoreView(view, camera, controls) {
  camera.position.copy(view.position);
  camera.quaternion.copy(view.quaternion);
  if (view.fov !== undefined) { camera.fov = view.fov; camera.zoom = view.zoom; camera.updateProjectionMatrix(); }
  controls.target.copy(view.target);
  // A disabled OrbitControls (first-person or Origin) would still clamp and re-aim the restored pose.
  if (controls.enabled !== false) controls.update();
}
