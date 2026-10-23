// SPDX-License-Identifier: GPL-3.0-or-later
// Real Möbius transformations of the roots and the induced action on coefficient space, after Harriss, Stange and
// Trettel, Algebraic Number Starscapes §4.2.2. Original code; matrices are [p, q, r, s] for [[p, q], [r, s]].
//
// A form Q(x, y) = a x² + b xy + c y² is pushed forward by g as Q∘g⁻¹, which moves every root z to
// g·z = (pz + q)/(rz + s) and keeps Δ = b² − 4ac when det g = 1:
//   a′ = s²a − rs b + r²c,  b′ = −2qs a + (ps + qr) b − 2pr c,  c′ = q²a − pq b + p²c.
// These are continuous real transformations. Only integer matrices of determinant 1 (SL₂(ℤ)) map the integer
// lattice to itself; under any other g the base triples keep their exact integer identities and only the drawn
// positions move.

export const identity = Object.freeze([1, 0, 0, 1]);

export const multiply = (g, h) => [
  g[0] * h[0] + g[1] * h[2], g[0] * h[1] + g[1] * h[3],
  g[2] * h[0] + g[3] * h[2], g[2] * h[1] + g[3] * h[3],
];
export const determinant = g => g[0] * g[3] - g[1] * g[2];
/** Inverse of a determinant-one matrix. */
export const inverse = g => [g[3], -g[1], -g[2], g[0]];
/** Rescales to determinant 1, removing floating-point drift; a nonpositive determinant is not in SL₂(ℝ). */
export function normalize(g) {
  const d = determinant(g);
  if (!(d > 0) || !g.every(Number.isFinite)) return [...identity];
  const k = 1 / Math.sqrt(d);
  return g.map(x => x * k);
}

/** g·z for z = {x, y} in the upper half-plane (y > 0 is preserved when det g > 0). */
export function act(g, z) {
  const [p, q, r, s] = g;
  const nx = p * z.x + q, ny = p * z.y, dx = r * z.x + s, dy = r * z.y, d = dx * dx + dy * dy;
  return { x: (nx * dx + ny * dy) / d, y: (ny * dx - nx * dy) / d };
}

/** The matrix sending z to i: z ↦ (z − x)/y, scaled to determinant 1. */
export const toI = z => { const t = Math.sqrt(z.y); return [1 / t, -z.x / t, 0, t]; };
/** The symmetric positive-definite element of SL₂(ℝ) sending i to w: the pure translation along the geodesic. */
export function fromI(w) {
  const m = (w.x * w.x + w.y * w.y) / w.y, n = w.x / w.y, k = 1 / w.y, t = Math.sqrt(m + k + 2);
  return [(m + 1) / t, n / t, n / t, (k + 1) / t];
}
/** The hyperbolic transvection carrying z0 to z1 along their geodesic, with no extra rotation about z1. */
export function transvection(z0, z1) {
  const h = toI(z0);
  return multiply(inverse(h), multiply(fromI(act(h, z1)), h));
}
/** One drag step: the point that was under the pointer at z0 follows it to z1 (composed on the left). */
export const dragStep = (g, z0, z1) => normalize(multiply(transvection(z0, z1), g));

/** The 3×3 coefficient pushforward of g, row-major, acting on (a, b, c). */
export function pushforward(g) {
  const [p, q, r, s] = g;
  return [s * s, -r * s, r * r, -2 * q * s, p * s + q * r, -2 * p * r, q * q, -p * q, p * p];
}
export const applyRows = (m, [a, b, c]) => [
  m[0] * a + m[1] * b + m[2] * c, m[3] * a + m[4] * b + m[5] * c, m[6] * a + m[7] * b + m[8] * c,
];
/** Exact pushforward for an integer matrix in SL₂(ℤ), with BigInt coefficients; null for any other matrix. */
export function pushforwardExact(g, [a, b, c]) {
  if (!g.every(Number.isInteger) || determinant(g) !== 1) return null;
  const [p, q, r, s] = g.map(BigInt), [A, B, C] = [a, b, c].map(BigInt);
  return [s * s * A - r * s * B + r * r * C, -2n * q * s * A + (p * s + q * r) * B - 2n * p * r * C,
    q * q * A - p * q * B + p * p * C];
}

/** Our Klein coordinates (u, v) = (X/Y, Z/Y) of display (X, Y, Z) = (−b, a+c, c−a) to the upper root, or null. */
export function kleinToUpper(u, v) {
  const h = 1 - u * u - v * v;
  if (!(h > 0) || !(1 - v > 0)) return null;
  return { x: u / (1 - v), y: Math.sqrt(h) / (1 - v) };
}
/** The inverse: the Klein point of the form with root z, (1, −2x, |z|²) up to scale. */
export function upperToKlein(z) {
  const n = z.x * z.x + z.y * z.y;
  return [2 * z.x / (1 + n), (n - 1) / (1 + n)];
}
