// SPDX-License-Identifier: GPL-3.0-or-later
// Approximate renderer readouts from accepted display coordinates and Lean's exact Δ.
// These do not replace the exact base identities or certify floating-point rendering.
export function shownUpperRoot(xyz, delta) {
  if (!Array.isArray(xyz) || xyz.length !== 3 || !xyz.every(Number.isFinite) || !(delta < 0)) return null;
  const denominator = xyz[1] - xyz[2];
  if (denominator === 0) return null;
  const root = [xyz[0] / denominator, Math.sqrt(-delta) / Math.abs(denominator)];
  return root.every(Number.isFinite) ? root : null;
}
export function shownBoundaryRoot(xyz) {
  if (!Array.isArray(xyz) || xyz.length !== 3 || !xyz.every(Number.isFinite)) return null;
  const denominator = xyz[1] - xyz[2];
  // Null cone directions have arbitrary scale; use a relative cancellation threshold.
  if (Math.abs(denominator) <= 1e-12 * Math.max(...xyz.map(Math.abs))) return Infinity;
  const root = xyz[0] / denominator;
  return Number.isFinite(root) ? root : null;
}
export const approximateNumber = value => value === Infinity ? '∞' : value === null ? 'unavailable' : Number(value.toFixed(3)).toFixed(3);

// Display typography only; the exact signed coefficients and Lean transport label stay unchanged.
export const spacedPolynomial = label => label.trim().replace(/(?<!^)[+−-]/g, sign => ` ${sign==='-'?'−':sign} `);
