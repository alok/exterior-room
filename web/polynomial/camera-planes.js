// SPDX-License-Identifier: GPL-3.0-or-later
import { Euler } from 'three';

// Camera orientation C = R_y(zx) R_x(yz) R_z(xy), the existing YXZ factorization.
// These oriented planes use the right-handed display basis, not coefficient (a,b,c).
export function cameraPlaneAngles(quaternion) {
  const e = new Euler().setFromQuaternion(quaternion, 'YXZ');
  return { zx: e.y, yz: e.x, xy: e.z };
}
export function cameraPlaneLabel(quaternion) {
  const p = cameraPlaneAngles(quaternion);
  const degrees = x => `${Math.round(x * 180 / Math.PI)}°`;
  return `ZX (e_z∧e_x) ${degrees(p.zx)} · YZ (e_y∧e_z) ${degrees(p.yz)} · XY (e_x∧e_y) ${degrees(p.xy)}`;
}
