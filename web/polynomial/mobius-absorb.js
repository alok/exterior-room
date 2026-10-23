// SPDX-License-Identifier: GPL-3.0-or-later
// Transaction preparation only. No UI, selected-point mutation, fallback algebra or fabricated receipt.
import { isIntegral } from './mobius-snap.js';
import { IDENTITY_BOUND } from './lean-client.js';

function safePoint(point, label) {
  if (!Array.isArray(point) || point.length !== 3 || !point.every(n => Number.isSafeInteger(n) && Math.abs(n) <= IDENTITY_BOUND) || !point.some(n => n !== 0)) {
    throw new RangeError(`${label} must be a nonzero integer triple within the supported ±${IDENTITY_BOUND} coefficient bound`);
  }
  return [...point];
}

/** M/√det(M) is an integral determinant-one matrix exactly when the positive
 * integer determinant is a square and every entry is divisible by its square root.
 * This is a BigInt domain check, not a Lean proof or an accepted action receipt. */
export function integralRepresentative(matrix) {
  if (!Array.isArray(matrix) || matrix.length !== 4 || !matrix.every(n => Number.isSafeInteger(n) && Math.abs(n) <= 1_000_000)) return null;
  const [p, q, r, s] = matrix.map(BigInt), D = p * s - q * r;
  if (D <= 0n) return null;
  // D≤2·10^12 here. Correct the numeric seed using exact arithmetic, then check the square.
  let root = BigInt(Math.floor(Math.sqrt(Number(D))));
  while ((root + 1n) * (root + 1n) <= D) root++;
  while (root * root > D) root--;
  if (root * root !== D) return null;
  const values = [p, q, r, s];
  if (values.some(n => n % root !== 0n)) return null;
  const result = values.map(n => Number(n / root));
  return isIntegral(result) ? result : null;
}

/** Prepare Snap absorption atomically: commit the SL₂(Z) action, inspect BOTH new
 * signed identities, then prepare their exact plane. The caller may assign these
 * values and reset its action to identity only after this returns a non-null object.
 * Every suspension checks isCurrent; stale success and stale failure return null.
 * Latest failures throw, leaving caller-owned arrays/state untouched. */
export async function prepareAbsorption({ matrix, point, second = null, commit, inspect, preparePair, isCurrent }) {
  try {
    if (!isCurrent()) return null;
    if (!isIntegral(matrix) || matrix.some(n => Math.abs(n) > 1_000_000)) throw new RangeError('Snap absorption requires an exact determinant-one integer matrix within the commit bounds');
    const source = safePoint(point, 'Selected base point'), partner = second === null ? null : safePoint(second, 'Second base point');
    const receipt = await commit([...source], [...matrix], partner ? [...partner] : undefined);
    if (!isCurrent() || !receipt) return null;
    // Validate the pair together before inspecting either side: no asymmetric partial acceptance.
    const newPoint = safePoint(receipt.image, 'Snapped selected image');
    const newSecond = partner ? safePoint(receipt.second?.image, 'Snapped second image') : null;
    await inspect([...newPoint]);
    if (!isCurrent()) return null;
    if (newSecond) {
      await inspect([...newSecond]);
      if (!isCurrent()) return null;
    }
    let plane = null;
    if (newSecond) {
      plane = await preparePair([...newPoint], [...newSecond]);
      if (!isCurrent()) return null;
      if (plane?.error) throw new Error(`Snapped pair could not be prepared: ${plane.error}`);
      if (!plane) throw new Error('Snapped pair returned no exact plane');
    }
    return { point: newPoint, second: newSecond, receipt, plane };
  } catch (error) {
    if (!isCurrent()) return null;
    throw error;
  }
}
