// SPDX-License-Identifier: GPL-3.0-or-later
// Module worker for exact XR hover queries (see hover-queries.js). It owns one transferred copy of a lattice
// generation's display coordinates and answers each query with the trigger's own nearestToRayPacked.
import { nearestToRayPacked } from './input.js';
let generation = null, xyz = null, count = 0;
self.onmessage = ({ data }) => {
  if (data.type === 'lattice') { generation = data.generation; xyz = data.xyz; count = data.count; return; }
  if (data.type !== 'query') return;
  // A query for a lattice this worker does not hold gets index null, which the main thread discards.
  if (data.generation !== generation) { self.postMessage({ type: 'result', hand: data.hand, request: data.request, generation: data.generation, index: null, ms: 0 }); return; }
  const t = performance.now();
  const index = nearestToRayPacked(data.origin, data.direction, xyz, count, data.maxAngle, data.minDistance);
  self.postMessage({ type: 'result', hand: data.hand, request: data.request, generation, index, ms: performance.now() - t });
};
