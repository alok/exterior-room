// SPDX-License-Identifier: GPL-3.0-or-later
// Exact enumeration of the displayed coefficient ball into typed arrays: every integer triple once,
// no sampling. The ball is X²+Y²+Z² ≤ R² in display coordinates (X,Y,Z) = (−b, a+c, c−a), i.e.
// b² + 2a² + 2c² ≤ R², so each (a,c) column contributes |b| ≤ ⌊√(R² − 2a² − 2c²)⌋.
export const latticeRadii = [4, 6, 8, 10, 12, 24, 48, 96];
export const maxLatticeRadius = 96;

const isqrt = n => { let m = Math.floor(Math.sqrt(n)); while (m * m > n) m--; while ((m + 1) * (m + 1) <= n) m++; return m; };
export const inBall = ([a, b, c], radius) => (a !== 0 || b !== 0 || c !== 0) && b * b + 2 * a * a + 2 * c * c <= radius * radius;
export const isUpper = ([a, b, c]) => a > 0 && b * b - 4 * a * c < 0;

function forEachTriple(radius, upperOnly, visit) {
  const r2 = radius * radius;
  for (let a = -radius; a <= radius; a++) {
    const ra = r2 - 2 * a * a; if (ra < 0) continue;
    for (let c = -radius; c <= radius; c++) {
      const rc = ra - 2 * c * c; if (rc < 0) continue;
      const m = isqrt(rc);
      for (let b = -m; b <= m; b++) {
        if (a === 0 && b === 0 && c === 0) continue;
        if (upperOnly && !(a > 0 && b * b - 4 * a * c < 0)) continue;
        visit(a, b, c);
      }
    }
  }
}

// Number of distinct triples in the whole ball, from the column formula alone.
export function ballCount(radius) {
  const r2 = radius * radius; let n = 0;
  for (let a = -radius; a <= radius; a++) for (let c = -radius; c <= radius; c++) {
    const rc = r2 - 2 * a * a - 2 * c * c; if (rc >= 0) n += 2 * isqrt(rc) + 1;
  }
  return n - 1;
}

export function enumerateLattice(radius, upperOnly = false) {
  if (!Number.isInteger(radius) || radius < 1 || radius > maxLatticeRadius) throw RangeError(`radius must be an integer in 1..${maxLatticeRadius}`);
  let count = 0;
  forEachTriple(radius, upperOnly, () => { count++; });
  const abc = new Int16Array(3 * count), xyz = new Float32Array(3 * count);
  let i = 0, maxInterior = 0;
  forEachTriple(radius, upperOnly, (a, b, c) => {
    abc[3 * i] = a; abc[3 * i + 1] = b; abc[3 * i + 2] = c;
    xyz[3 * i] = 0 - b; xyz[3 * i + 1] = a + c; xyz[3 * i + 2] = c - a;
    const delta = b * b - 4 * a * c; if (-delta > maxInterior) maxInterior = -delta;
    i++;
  });
  return { radius, upperOnly, count, abc, xyz, maxInterior };
}

export const tripleAt = (lattice, i) => [lattice.abc[3 * i], lattice.abc[3 * i + 1], lattice.abc[3 * i + 2]];
export function indexOf(lattice, [a, b, c]) {
  for (let i = 0; i < lattice.count; i++) if (lattice.abc[3 * i] === a && lattice.abc[3 * i + 1] === b && lattice.abc[3 * i + 2] === c) return i;
  return -1;
}
