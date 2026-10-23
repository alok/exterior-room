// SPDX-License-Identifier: GPL-3.0-or-later
// Renderer-only floating-point helpers. These are not Lean proofs or exact commit receipts.
// mobius.js is copied byte-for-byte from FareyVision 63ad115422ab1141ca6d06732572385414b7a5cf,
// Farey/WebXR/mobius.js, SHA256 d2dbc833ca29bf7160e99f976aa433ca8a274a612d0e9f5d95b82aa6803f6886.
// Its mathematical attribution to Harriss, Stange and Trettel is preserved there; these adapter changes
// are new Exterior Room code, not attributed to Katherine Stange.
import { identity, determinant, pushforward, applyRows, kleinToUpper } from './mobius.js';

function finite(values, length, label) {
  if ((!Array.isArray(values) && !ArrayBuffer.isView(values)) || values.length !== length || Array.from(values).some(n => !Number.isFinite(n))) {
    throw new TypeError(`${label} must contain ${length} finite numbers`);
  }
  return values;
}
function matrix(g) {
  finite(g, 4, 'Möbius matrix');
  const d = determinant(g);
  if (!(d > 0) || !Number.isFinite(d)) throw new RangeError('Möbius preview requires a finite positive determinant');
  return g;
}
function integerMatrix(values, bound = 1_000_000) {
  finite(values, 4, 'Committed integer matrix');
  if (!Number.isSafeInteger(bound) || bound < 1 || Array.from(values).some(n => !Number.isSafeInteger(n) || Math.abs(n) > bound)) {
    throw new RangeError(`Committed matrix entries must be integers bounded by ${bound}`);
  }
  const [p, q, r, s] = Array.from(values, BigInt), d = p * s - q * r;
  if (d <= 0n) throw new RangeError('Quantized matrix must have strictly positive exact determinant');
  return d;
}
const cleanZero = n => n === 0 ? 0 : n;

/** Display basis B(a,b,c)=(-b,a+c,c-a), preserving signed identities. */
export function coefficientsToDisplay(abc) {
  const [a, b, c] = finite(abc, 3, 'Coefficients');
  return [-b, a + c, c - a].map(cleanZero);
}
/** B inverse. Fractional coefficients here are renderer numbers, never an exact Lean result. */
export function displayToCoefficients(xyz) {
  const [x, y, z] = finite(xyz, 3, 'Display point');
  return [(y - z) / 2, -x, (y + z) / 2].map(cleanZero);
}

/** Conjugate any coefficient action P by B: display action is B P B⁻¹, row-major. */
export function coefficientRowsToDisplay(rows) {
  finite(rows, 9, 'Coefficient rows');
  // Columns of B⁻¹ are the coefficients of display unit vectors eX,eY,eZ.
  const columns = [[0, -1, 0], [.5, 0, .5], [-.5, 0, .5]].map(v => coefficientsToDisplay(applyRows(rows, v)));
  return [0, 1, 2].flatMap(i => columns.map(column => column[i]));
}
/** Linear preview on display XYZ. For g∈SL₂(R), X²+Z²−Y² (the discriminant) is preserved. */
export function displayPushforward(g) { return coefficientRowsToDisplay(pushforward(matrix(g))); }
/** Row-major Matrix4 input: use THREE.Matrix4().set(...rows), NOT .fromArray(rows). */
export function displayRowsToMatrix4(rows) {
  finite(rows, 9, 'Display rows');
  return [rows[0], rows[1], rows[2], 0, rows[3], rows[4], rows[5], 0, rows[6], rows[7], rows[8], 0, 0, 0, 0, 1];
}
export function displayMatrix4(g) { return displayRowsToMatrix4(displayPushforward(g)); }
export function transformDisplay(g, xyz) { return applyRows(displayPushforward(g), finite(xyz, 3, 'Display point')).map(cleanZero); }

/** Copy packed positions in the same order. The original lattice and its base identities are untouched. */
export function transformPackedPositions(xyz, g) {
  if ((!Array.isArray(xyz) && !ArrayBuffer.isView(xyz)) || !Number.isSafeInteger(xyz.length) || xyz.length % 3) throw new TypeError('Packed XYZ length must be divisible by three');
  const rows = displayPushforward(g), output = new Float32Array(xyz.length);
  for (let i = 0; i < xyz.length; i += 3) {
    const x = xyz[i], y = xyz[i + 1], z = xyz[i + 2];
    output[i] = rows[0] * x + rows[1] * y + rows[2] * z;
    output[i + 1] = rows[3] * x + rows[4] * y + rows[5] * z;
    output[i + 2] = rows[6] * x + rows[7] * y + rows[8] * z;
    if (!Number.isFinite(output[i]) || !Number.isFinite(output[i + 1]) || !Number.isFinite(output[i + 2])) throw new RangeError('Transformed point exceeds finite Float32 rendering range');
  }
  return output;
}

function interiorCount(lattice) {
  if (!Number.isSafeInteger(lattice?.count) || lattice.count < 0 || lattice.xyz?.length !== lattice.count * 3 || lattice.kind?.length !== lattice.count) {
    throw new TypeError('Expected accepted packed lattice {count,xyz,kind}');
  }
  let count = 0;
  for (let i = 0; i < lattice.count; i++) if (lattice.kind[i] === 2 || lattice.kind[i] === 3) count++;
  return count;
}
/** Radial images must be recomputed AFTER the linear pushforward: h·(X′/Y′,1,Z′/Y′).
 * Both signs and all multiples remain separate entries, even when their images coincide.
 * Unlike a linear scene transform, this preserves the screen's fixed Y=h. */
export function projectedPositions(lattice, g = identity, height = 4) {
  if (!(height > 0) || !Number.isFinite(height)) throw new RangeError('Projection height must be finite and positive');
  const count = interiorCount(lattice), rows = displayPushforward(g), output = new Float32Array(3 * count);
  let next = 0;
  for (let i = 0; i < lattice.count; i++) {
    if (lattice.kind[i] !== 2 && lattice.kind[i] !== 3) continue;
    const at = 3 * i, x = lattice.xyz[at], y = lattice.xyz[at + 1], z = lattice.xyz[at + 2];
    const X = rows[0] * x + rows[1] * y + rows[2] * z;
    const Y = rows[3] * x + rows[4] * y + rows[5] * z;
    const Z = rows[6] * x + rows[7] * y + rows[8] * z;
    if (!Number.isFinite(Y) || Y === 0) throw new RangeError('Transformed interior point has no finite radial denominator');
    const u = X / Y, v = Z / Y;
    if (!Number.isFinite(u) || !Number.isFinite(v)) throw new RangeError('Nonfinite radial projection');
    output[next++] = u * height; output[next++] = height; output[next++] = v * height;
    if (!Number.isFinite(output[next - 3]) || !Number.isFinite(output[next - 2]) || !Number.isFinite(output[next - 1])) throw new RangeError('Radial projection exceeds finite Float32 rendering range');
  }
  return output;
}

/** Upper and lower signed forms use the same Klein root point. Boundary/exterior/zero return null. */
export function rootDiskPosition(abc, g = identity) {
  const base = coefficientsToDisplay(abc);
  // This is only a numerical chart-domain guard. App classification/labels still come from Lean.
  if (!(base[1] * base[1] > base[0] * base[0] + base[2] * base[2])) return null;
  const [x, y, z] = transformDisplay(g, base);
  if (y === 0) return null;
  const u = x / y, v = z / y;
  return Number.isFinite(u) && Number.isFinite(v) && u * u + v * v < 1 ? [u, v] : null;
}
/** Klein coordinates and their base lattice indices. Includes coincident signed/multiple entries. */
export function rootDiskPositions(lattice, g = identity) {
  const count = interiorCount(lattice), projection = projectedPositions(lattice, g, 1);
  const positions = new Float32Array(2 * count), indices = new Uint32Array(count);
  let next = 0;
  for (let i = 0; i < lattice.count; i++) {
    if (lattice.kind[i] !== 2 && lattice.kind[i] !== 3) continue;
    positions[2 * next] = projection[3 * next]; positions[2 * next + 1] = projection[3 * next + 2]; indices[next++] = i;
  }
  return { positions, indices, count };
}

function chart(rect, { zoom = 1, pan = [0, 0], padding = 16 } = {}) {
  if (![rect?.left, rect?.top, rect?.width, rect?.height, zoom, padding].every(Number.isFinite) || !(rect.width > 0) || !(rect.height > 0) || !(zoom > 0) || padding < 0) throw new RangeError('Klein chart needs a finite positive rectangle and zoom');
  finite(pan, 2, 'Pan');
  const radius = (Math.min(rect.width, rect.height) / 2 - padding) * zoom;
  if (!(radius > 0)) throw new RangeError('Klein chart padding leaves no disk');
  return { cx: rect.left + rect.width / 2 + pan[0], cy: rect.top + rect.height / 2 + pan[1], radius };
}
/** Client pixels → Klein (u,v), with +v upward. Pan is measured in CSS pixels, zoom dimensionless.
 * Boundary/outside pointers have no hyperbolic drag anchor and return null; no clamping occurs. */
export function pointerToKlein(clientX, clientY, rect, options) {
  if (!Number.isFinite(clientX) || !Number.isFinite(clientY)) return null;
  const { cx, cy, radius } = chart(rect, options), u = (clientX - cx) / radius, v = (cy - clientY) / radius;
  return u * u + v * v < 1 ? [u, v] : null;
}
export function kleinToClient(uv, rect, options) {
  const [u, v] = finite(uv, 2, 'Klein point'), { cx, cy, radius } = chart(rect, options);
  return [cx + u * radius, cy - v * radius];
}
export function pointerToUpper(clientX, clientY, rect, options) {
  if (options?.model === 'half-plane') {
    if (!Number.isFinite(clientX) || !Number.isFinite(clientY)) return null;
    const {cx,cy,scale}=chartTransform(rect,options), x=(clientX-cx)/scale, y=(cy-clientY)/scale;
    return y>1e-6 ? {x,y} : null;
  }
  const uv = pointerToKlein(clientX, clientY, rect, options); return uv ? kleinToUpper(...uv) : null;
}

/** Canonical UHP fit/pan/zoom, adapted from FareyVision 2cd549a roots-pane.js.
 * With model='klein' this preserves the previous disk convention. No model
 * defaults to UHP here; legacy pointerToUpper remains Klein without options.model. */
export function chartTransform(rect,{model='half-plane',zoom=1,pan=[0,0],padding=16}={}) {
  if(model==='klein'){const c=chart(rect,{zoom,pan,padding});return {cx:c.cx,cy:c.cy,scale:c.radius};}
  if(model!=='half-plane')throw new RangeError('Unknown roots chart model');
  if(![rect?.left,rect?.top,rect?.width,rect?.height,zoom].every(Number.isFinite)||rect.width<=0||rect.height<=0||zoom<=0)throw new RangeError('Roots chart needs a finite positive rectangle and zoom');
  finite(pan,2,'Pan');
  return {cx:rect.left+rect.width/2+pan[0],cy:rect.top+rect.height/2+(rect.height/2-28)*zoom+pan[1],scale:rect.width/2.4*zoom};
}
/** Drawn root from transformed XYZ and the accepted invariant discriminant.
 * This is rational→Float/square-root presentation, not a new classification. */
export function rootCoordinates(xyz,delta,model='half-plane') {
  const [x,y,z]=finite(xyz,3,'Displayed root');
  if(!(delta<0)||!Number.isFinite(delta))return null;
  if(model==='klein')return y!==0?[x/y,z/y]:null;
  if(model!=='half-plane')throw new RangeError('Unknown roots chart model');
  const denominator=y-z;
  if(denominator===0)return null;
  const result=[x/denominator,Math.sqrt(-delta)/Math.abs(denominator)];
  return result.every(Number.isFinite)?result:null;
}
export function rootToClient(xyz,delta,rect,options={}) {
  const p=rootCoordinates(xyz,delta,options.model),c=chartTransform(rect,options);
  return p?[c.cx+p[0]*c.scale,c.cy-p[1]*c.scale]:null;
}
/** Keep the chart point beneath the pointer fixed while zooming, as in source. */
export function zoomChartAt(clientX,clientY,rect,options,nextZoom) {
  if(!Number.isFinite(clientX)||!Number.isFinite(clientY))throw new RangeError('Zoom anchor must be finite');
  const before=chartTransform(rect,options),after=chartTransform(rect,{...options,zoom:nextZoom,pan:[0,0]});
  const x=(clientX-before.cx)/before.scale,y=(before.cy-clientY)/before.scale;
  return {zoom:nextZoom,pan:[clientX-after.cx-x*after.scale,clientY-after.cy+y*after.scale]};
}

/** Resize a visible chart without moving its model-space center. Canonical
 * UHP keeps cx/cy and scales by newWidth/oldWidth; our dimensionless zoom
 * therefore stays unchanged. Klein keeps the same zoom relative to its fitted
 * disk and the same model-space center. Hidden/zero rectangles are rejected:
 * callers retain the last visible rectangle and reset fit separately. */
export function resizeChart(oldRect,newRect,options={}) {
  const before=chartTransform(oldRect,options),zoom=options.zoom??1;
  const centerX=(oldRect.left+oldRect.width/2-before.cx)/before.scale;
  const centerY=(before.cy-oldRect.top-oldRect.height/2)/before.scale;
  const after=chartTransform(newRect,{...options,zoom,pan:[0,0]});
  return {zoom,pan:[newRect.left+newRect.width/2-after.cx-centerX*after.scale,
    newRect.top+newRect.height/2-after.cy+centerY*after.scale]};
}

/** Transformed null-cone directions → a UHP semicircle, or a vertical line if
 * one projective endpoint is infinity. Input retains homogeneous coordinates;
 * no finite stand-in is used for ∞. Returned samples are renderer-only. */
export function halfPlaneGeodesic(ends,{top=4,segments=128}={}) {
  if(!Array.isArray(ends)||ends.length!==2||!(top>0)||!Number.isFinite(top)||!Number.isInteger(segments)||segments<2)throw new RangeError('Geodesic requires two endpoints and a finite positive chart top');
  const values=ends.map(p=>{const [x,y,z]=finite(p,3,'Geodesic endpoint'),d=y-z;return Math.abs(d)<=1e-12*Math.max(1,Math.abs(x),Math.abs(y),Math.abs(z))?null:x/d;});
  if(values.every(x=>x===null))return [];
  if(values.some(x=>x===null)){const x=values.find(x=>x!==null);return [[x,0],[x,top]];}
  const [a,b]=values,center=(a+b)/2,radius=Math.abs(a-b)/2;
  return Array.from({length:segments+1},(_,i)=>{const theta=Math.PI*i/segments;return [center+radius*Math.cos(theta),radius*Math.sin(theta)];});
}

/** A bounded release quantization, not a certificate. Normalize first, round, and reject a
 * collapsed/reversed matrix instead of silently clamping. Send the result to Lean to commit.
 * The exact committed action is J(M)/det(M), not J(round(g))/quantum². */
export function quantizeMatrix(g, quantum = 10_000, bound = 1_000_000) {
  matrix(g);
  if (!Number.isSafeInteger(quantum) || quantum < 1 || quantum > bound) throw new RangeError('Quantization scale must be a positive bounded integer');
  const scale = quantum / Math.sqrt(determinant(g));
  const result = Array.from(g, n => cleanZero(Math.round(n * scale)));
  integerMatrix(result, bound);
  return result;
}
/** Convert an already accepted/bounded integer matrix to its normalized float preview.
 * This converts input; it does not establish that a commit request succeeded. */
export function matrixFromIntegers(values) {
  const d = integerMatrix(values), scale = 1 / Math.sqrt(Number(d));
  return Array.from(values, n => n * scale);
}
/** Convert coefficient rows from a bridge-validated Lean commit receipt. All proof/certificate
 * checking belongs to the bridge; this function does only finite rational→Float conversion. */
export function displayRowsFromReceipt(receipt) {
  if (!Number.isSafeInteger(receipt?.denominator) || receipt.denominator <= 0) throw new RangeError('Receipt denominator must be a positive exact integer');
  finite(receipt.coefficientRows, 9, 'Receipt coefficient rows');
  if (Array.from(receipt.coefficientRows).some(n => !Number.isSafeInteger(n))) throw new RangeError('Receipt coefficients must be exact safe integers');
  return coefficientRowsToDisplay(Array.from(receipt.coefficientRows, n => n / receipt.denominator));
}
export function displayMatrix4FromReceipt(receipt) { return displayRowsToMatrix4(displayRowsFromReceipt(receipt)); }
