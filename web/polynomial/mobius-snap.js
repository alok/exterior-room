// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from FareyVision 2cd549a45ddb6056cf3596404754d96ad9e7132c,
// Farey/WebXR/mobius.js: actReal, isIntegral, polarAngle and nearestIntegral.
// Source-file SHA256 193a0df167da6ab54f9c496ef736df15326fc5db67dcea0087cee760577e32de.
// The original attribution to Harriss, Stange and Trettel remains in mobius.js.
// That separately pinned 63ad115 core is unchanged. New guards and exact integer
// composition below are Exterior Room code; they are not attributed to Stange.
// Snap is the canonical fundamental-domain/candidate algorithm, not a Lean proof
// of globally nearest lattice action. Its image still requires a Lean commit.
import { identity, multiply, inverse, act, normalize, determinant } from './mobius.js';

function finiteMatrix(g) {
  if (!Array.isArray(g) || g.length !== 4 || !g.every(Number.isFinite)) throw new TypeError('Möbius matrix must contain four finite numbers');
}
function bigMatrix(g, bound = Number.MAX_SAFE_INTEGER) {
  if (!Array.isArray(g) || g.length !== 4 || !g.every(n => Number.isSafeInteger(n) && Math.abs(n) <= bound)) throw new RangeError(`Integer matrix entries must be safe integers bounded by ${bound}`);
  return g.map(BigInt);
}
const bigDeterminant = ([p, q, r, s]) => p * s - q * r;
const bigMultiply = (g, h) => [g[0]*h[0]+g[1]*h[2],g[0]*h[1]+g[1]*h[3],g[2]*h[0]+g[3]*h[2],g[2]*h[1]+g[3]*h[3]];
const abs = n => n < 0n ? -n : n;
function gcd(a, b) { a = abs(a); b = abs(b); while (b) [a, b] = [b, a % b]; return a; }

/** Numeric action on the real projective line. Infinity is explicit; NaN is not a point. */
export function actReal(g, t) {
  finiteMatrix(g);
  if (typeof t !== 'number' || Number.isNaN(t)) throw new TypeError('Real projective point must be a number or Infinity');
  const [p, q, r, s] = g;
  if (!Number.isFinite(t)) return r === 0 ? Infinity : p / r;
  const d = r * t + s;
  return d === 0 ? Infinity : (p * t + q) / d;
}

/** Exact predicate on safely represented integer entries, rather than rounded Float determinant. */
export function isIntegral(g) {
  try { return bigDeterminant(bigMatrix(g)) === 1n; } catch { return false; }
}

/** Rotation in the polar decomposition, folded because g and -g act alike. */
export function polarAngle(g) {
  finiteMatrix(g);
  let theta = Math.atan2(g[2] - g[1], g[0] + g[3]);
  while (theta > Math.PI / 2) theta -= Math.PI;
  while (theta <= -Math.PI / 2) theta += Math.PI;
  return theta;
}

/** Canonical Snap candidate selection, with explicit rejection for invalid/unbounded results.
 * Reduce normalized g·i into |x|≤1/2, |z|≥1; choose γ or γS by residual polar turn.
 * The supplied preview remains numerical. Only a later accepted Lean receipt is authoritative. */
export function nearestIntegral(g) {
  finiteMatrix(g);
  const d = determinant(g);
  if (!(d > 0) || !Number.isFinite(d)) throw new RangeError('Snap needs a positive finite determinant');
  g = normalize(g);
  const S = [0, -1, 1, 0];
  let w = act(g, { x: 0, y: 1 }), m = [...identity], settled = false;
  for (let step = 0; step < 200; step++) {
    if (!Number.isFinite(w.x) || !(w.y > 0) || !Number.isFinite(w.y) || Math.abs(w.x) > 2 ** 20) throw new RangeError('Snap chart exceeded finite upper-half-plane precision');
    const n = Math.round(w.x); // Source convention: half-integers round toward +∞.
    if (!Number.isSafeInteger(n)) throw new RangeError('Snap translation exceeds safe integer precision');
    if (n) { w = { x: w.x - n, y: w.y }; m = multiply([1, -n, 0, 1], m); }
    if (!isIntegral(m)) throw new RangeError('Snap reduction exceeded exact integer precision');
    if (w.x * w.x + w.y * w.y < 1 - 1e-12) {
      w = act(S, w); m = multiply(S, m);
      if (m.some(x => Math.abs(x) > 2 ** 20)) throw new RangeError('Snap reduction exceeded the source finite range');
    }
    else { settled = true; break; }
  }
  if (!settled) throw new RangeError('Snap reduction did not converge within 200 steps');
  const gamma = inverse(m), candidates = [gamma, multiply(gamma, S)];
  const turn = c => Math.abs(polarAngle(multiply(inverse(c), g)));
  const best = turn(candidates[1]) < turn(candidates[0]) - 1e-12 ? candidates[1] : candidates[0];
  const sign = best[0] + best[3] > 0 || (best[0] + best[3] === 0 && (best[0] || best[2]) > 0) ? 1 : -1;
  const result = best.map(x => sign * x + 0);
  if (!isIntegral(result) || result.some(n => Math.abs(n) > 1_000_000)) throw new RangeError('Snapped matrix exceeds the exact Lean commit bounds');
  return result;
}

/** Exact LEFT composition of bounded integer representatives. Common scalar factors cancel
 * from J(M)/det(M), so reduce them before the transport bound check. No clipping or Float fallback.
 * Positive determinant matrices need not individually have determinant one: the Lean action
 * uses each matrix divided by its determinant's square root. */
export function composeInteger(generator, current, bound = 1_000_000) {
  if (!Number.isSafeInteger(bound) || bound < 1 || bound > 1_000_000) throw new RangeError('Composition bound must be an integer between 1 and 1000000');
  const a = bigMatrix(generator, bound), b = bigMatrix(current, bound);
  if (bigDeterminant(a) <= 0n || bigDeterminant(b) <= 0n) throw new RangeError('Composition requires positive exact determinants');
  let result = bigMultiply(a, b);
  const common = result.reduce((factor, n) => gcd(factor, n), 0n);
  result = result.map(n => n / common);
  if (result.some(n => abs(n) > BigInt(bound))) throw new RangeError('Composed matrix exceeds the exact Lean commit bounds');
  if (bigDeterminant(result) <= 0n) throw new RangeError('Composed determinant is not positive');
  return result.map(Number);
}
