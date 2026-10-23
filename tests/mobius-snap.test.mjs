import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import { identity, multiply, inverse, transvection, act, pushforwardExact } from '../web/polynomial/mobius.js';
import { matrixFromIntegers, displayPushforward } from '../web/polynomial/mobius-render.js';
import { actReal, isIntegral, nearestIntegral, composeInteger, polarAngle } from '../web/polynomial/mobius-snap.js';

const T = [1, 1, 0, 1], S = [0, -1, 1, 0];
const near = (a, b) => a.forEach((n, i) => assert.ok(Math.abs(n - b[i]) <= 1e-9 * Math.max(1, Math.abs(b[i])), `${n} != ${b[i]}`));

test('browser proposals match all 34 shared pinned canonical polar-Snap cases', () => {
  const fixture = JSON.parse(readFileSync(new URL('../native/Resources/polynomial-polar-snap-cases.json', import.meta.url), 'utf8'));
  assert.equal(fixture.sourceCommit, '2cd549a45ddb6056cf3596404754d96ad9e7132c');
  assert.equal(fixture.sourceSha256, '193a0df167da6ab54f9c496ef736df15326fc5db67dcea0087cee760577e32de');
  assert.equal(fixture.cases.length, 34);
  for (const {name, matrix, expected} of fixture.cases) {
    // Our transport reports an explicit error for a rejected proposal; source
    // null and our throw both preserve the preceding accepted UI state.
    if (expected === null) assert.throws(() => nearestIntegral(matrix), RangeError, name);
    else assert.deepEqual(nearestIntegral(matrix), expected, name);
  }
});

test('canonical Snap fixtures preserve integer actions and choose the translation neighbor', () => {
  assert.deepEqual(nearestIntegral(identity), [1, 0, 0, 1]);
  for (const M of [T, S, inverse(T), multiply(T, S), multiply(multiply(T, T), S)]) {
    const result = nearestIntegral(M);
    assert.ok(isIntegral(result)); assert.ok(result.every((n, i) => n === M[i]) || result.every((n, i) => n === -M[i]));
  }
  assert.deepEqual(nearestIntegral(transvection({ x: 0, y: 1 }, { x: .1, y: 1.05 })), [1, 0, 0, 1]);
  const snapped = nearestIntegral(multiply(transvection({ x: 0, y: 1 }, { x: .05, y: 1.1 }), T));
  assert.ok(isIntegral(snapped));
  near(Object.values(act(snapped, { x: 0, y: 1 })), Object.values(act(T, { x: 0, y: 1 })));
});

test('source polar Snap counterexample chooses T⁴, not the old entrywise T⁴S', () => {
  // Recorded source gesture and its independent analytic transvection. Expected
  // outputs were checked against FareyVision 2cd549a WebXR/mobius.js.
  const recorded = [3.162278103784889, 1.1384199665329495, 4.037e-16, .31622772165519336];
  const analytic = transvection({x: -.4, y: .1}, {x: -.4, y: 1});
  const T4 = [1, 4, 0, 1], oldChoice = [4, -1, 1, 0];
  for (const g of [recorded, analytic]) {
    const entrywise = c => c.reduce((sum, x, i) => sum + (x - g[i]) ** 2, 0);
    assert.ok(entrywise(oldChoice) < entrywise(T4), 'fixture must expose the old ranking defect');
    assert.deepEqual(nearestIntegral(g), T4);
    assert.deepEqual(nearestIntegral(g.map(x => -x)), T4);
    assert.deepEqual(pushforwardExact(nearestIntegral(g), [1, 0, 1]), [1n, -8n, 17n]);
  }
});

test('polar Snap preserves source half-integer rounding, sign and rotation tie tolerance', () => {
  for (const [translation, snapped] of [[-1.5,-1],[-.5,0],[.5,1],[1.5,2]]) {
    assert.deepEqual(nearestIntegral([1,translation,0,1]), [1,snapped,0,1]);
  }
  const rotation = a => [Math.cos(a), -Math.sin(a), Math.sin(a), Math.cos(a)];
  assert.deepEqual(nearestIntegral(rotation(Math.PI/4)), [...identity]);
  assert.deepEqual(nearestIntegral(rotation(Math.PI/4 + 1e-13)), [...identity]);
  assert.deepEqual(nearestIntegral(rotation(Math.PI/4 + 1e-10)), S);
  assert.deepEqual(nearestIntegral(rotation(Math.PI/4 - 1e-10)), [...identity]);
  assert.equal(polarAngle([0,1,-1,0]), Math.PI/2);
  assert.deepEqual(nearestIntegral(S.map(x => -x)), S);
  assert.deepEqual(nearestIntegral(T.map(x => 23*x)), T);
});

test('user seed snapped by T has the new exact signed identity and unchanged discriminant', () => {
  const seed = [13, 20, 34], snapped = nearestIntegral(T);
  const image = pushforwardExact(snapped, seed);
  assert.deepEqual(image, [13n, -6n, 27n]);
  assert.equal(image[1] ** 2n - 4n * image[0] * image[2], -1368n);
  assert.deepEqual(pushforwardExact(identity, image), image);
  assert.deepEqual(pushforwardExact(snapped, seed.map(n => -n)), image.map(n => -n));
});

test('generator composition is LEFT ordered and preserves normalized rational action', () => {
  assert.deepEqual(composeInteger(T, S), [1, -1, 1, 0]);
  assert.notDeepEqual(composeInteger(T, S), composeInteger(S, T));
  assert.deepEqual(composeInteger(inverse(T), composeInteger(T, S)), S);
  const current = [3, 1, 1, 2], composed = composeInteger(T, current);
  assert.deepEqual(composed, [4, 3, 1, 2]);
  near(displayPushforward(matrixFromIntegers(composed)), displayPushforward(multiply(T, matrixFromIntegers(current))));
});

test('BigInt composition reduces common factors before checking the transport bound', () => {
  assert.deepEqual(composeInteger([1_000_000, 0, 0, 1_000_000], [1_000_000, 0, 0, 1_000_000]), [1, 0, 0, 1]);
  assert.deepEqual(composeInteger([10000, 10000, 0, 10000], [30000, 10000, 10000, 20000]), [4, 3, 1, 2]);
  assert.throws(() => composeInteger(T, [1, 1_000_000, 0, 1]), /commit bounds/);
  assert.throws(() => composeInteger([1, 0, 0, -1], identity), /positive exact/);
  assert.throws(() => composeInteger(T, [.5, 0, 0, 2]), /safe integers/);
});

test('real projective action includes infinity and invalid Snap never silently resets identity', () => {
  assert.equal(actReal(T, Infinity), Infinity); assert.equal(actReal(S, 0), Infinity); assert.equal(actReal(S, Infinity), 0);
  assert.equal(actReal(T, -1), 0); assert.equal(actReal([2, 1, 1, 1], 1), 1.5);
  assert.equal(isIntegral([1, 0, 0, -1]), false); assert.equal(isIntegral([1, 0, 0, 1]), true);
  assert.throws(() => nearestIntegral([NaN, 0, 0, 1]), /finite/);
  assert.throws(() => nearestIntegral([1, 0, 0, -1]), /positive finite/);
  assert.throws(() => nearestIntegral([1, 1_000_001, 0, 1]), /commit bounds/);
  assert.throws(() => nearestIntegral([1, 2 ** 20 + 1, 0, 1]), /finite upper-half-plane/);
  assert.throws(() => nearestIntegral([1, Infinity, 0, 1]), /finite/);
  assert.throws(() => nearestIntegral([1e308, 0, 0, 1e308]), /positive finite/);
  assert.throws(() => nearestIntegral([1, 0, 0, 0]), /positive finite/);
  assert.throws(() => actReal(T, NaN), /number or Infinity/);
});
