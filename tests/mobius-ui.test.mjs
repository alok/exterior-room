import test from 'node:test';
import assert from 'node:assert/strict';
import { MobiusAction } from '../web/polynomial/mobius-ui.js';
import { identity, act } from '../web/polynomial/mobius.js';
import { displayPushforward, displayRowsFromReceipt, matrixFromIntegers } from '../web/polynomial/mobius-render.js';

// Test fixtures stand in for bridge-validated responses, never for production Lean transport.
function receipt(point, matrix, second) {
  const [p, q, r, s] = matrix.map(BigInt), D = p * s - q * r;
  const rows = [s*s,-r*s,r*r,-2n*q*s,p*s+q*r,-2n*p*r,q*q,-p*q,p*p];
  const image = [0, 1, 2].map(i => rows.slice(3 * i, 3 * i + 3).reduce((n, x, j) => n + x * BigInt(point[j]), 0n));
  const result = { point: [...point], matrix: [...matrix], denominator: Number(D), coefficientRows: rows.map(Number),
    imageNumerator: image.map(Number), xyzNumerator: [-image[1],image[0]+image[2],image[2]-image[0]].map(Number),
    image: image.every(n => n % D === 0n) ? image.map(n => Number(n / D)) : null,
    delta: point[1] ** 2 - 4 * point[0] * point[2], checks: { positiveDeterminant: true, discriminantPreserved: true } };
  if (second) result.second = receipt(second, matrix);
  return Object.freeze(result);
}
function fixture() {
  const requests = []; let cancellations = 0;
  const action = new MobiusAction((point, matrix, second) => new Promise((resolve, reject) => requests.push({ point, matrix, second, resolve, reject })), () => { cancellations++; });
  return { action, requests, get cancellations() { return cancellations; }, accept(index = requests.length - 1) {
    const r = requests[index], result = receipt(r.point, r.matrix, r.second); r.resolve(result); return result;
  } };
}
const near = (a, b, tolerance = 1e-10) => { assert.equal(a.length, b.length); a.forEach((n, i) => assert.ok(Math.abs(n - b[i]) < tolerance * Math.max(1, Math.abs(b[i])), `${n} != ${b[i]}`)); };

test('continuous preview becomes accepted only after a matching receipt and uses its actual denominator', async () => {
  const f = fixture(), action = f.action, point = [1, -1, 2];
  assert.equal(action.phase, 'identity'); assert.equal(action.active, false);
  assert.equal(action.begin({ x: 0, y: 1 }), true); assert.equal(action.move({ x: 1, y: 1 }), true);
  assert.equal(action.phase, 'preview'); assert.equal(action.receipt, null);
  near([act(action.g, { x: 0, y: 1 }).x, act(action.g, { x: 0, y: 1 }).y], [1, 1]);
  const preview = [...action.g], accepted = action.commit(point); point[0] = 50;
  assert.equal(action.phase, 'pending'); assert.equal(action.receipt, null); assert.equal(action.begin({ x: 0, y: 1 }), false);
  assert.deepEqual(f.requests[0].point, [1, -1, 2]); assert.deepEqual(action.g, preview);
  const answer = f.accept(); assert.notEqual(answer.denominator, 10_000 ** 2);
  assert.equal(await accepted, answer); assert.equal(action.phase, 'accepted'); assert.equal(action.active, true);
  assert.deepEqual(action.rows, displayRowsFromReceipt(answer));
  near(action.g, matrixFromIntegers(answer.matrix)); assert.deepEqual(action.accepted, action.g);
});

test('failed or null commits restore the preceding accepted action and receipt', async () => {
  const f = fixture(), action = f.action;
  const initial = action.commit([1, 0, 1], null, [1, 1, 0, 1]), first = f.accept(); await initial;
  const accepted = [...action.g], rows = action.rows;
  action.begin({ x: 0, y: 1 }); action.move({ x: -.3, y: 1.7 });
  const failure = action.commit([1, 0, 1]); f.requests[1].reject(new Error('Lean offline'));
  await assert.rejects(failure, /Lean offline/);
  assert.equal(action.phase, 'accepted'); assert.equal(action.receipt, first); assert.deepEqual(action.g, accepted); assert.deepEqual(action.rows, rows);
  const superseded = action.commit([1, 0, 1], null, [0, -1, 1, 0]); f.requests[2].resolve(null);
  assert.equal(await superseded, null); assert.equal(action.receipt, first); assert.deepEqual(action.g, accepted);
});

test('cancel/reset invalidate pending completions without resurrecting a stale action', async () => {
  const f = fixture(), action = f.action;
  const pending = action.commit([1, -1, 2], null, [1, 1, 0, 1]);
  action.cancel(); f.accept(); assert.equal(await pending, null);
  assert.equal(action.phase, 'identity'); assert.deepEqual(action.g, [...identity]); assert.equal(action.receipt, null);
  const staleFailure = action.commit([1, -1, 2], null, [0, -1, 1, 0]);
  action.reset(); f.requests[1].reject(new Error('Old transport failed'));
  assert.equal(await staleFailure, null); assert.equal(action.phase, 'identity'); assert.equal(action.active, false);
  assert.ok(f.cancellations >= 3);
});

test('newer commit wins even when the older successful response arrives last', async () => {
  const f = fixture(), action = f.action;
  const old = action.commit([1, -1, 2], null, [1, 1, 0, 1]);
  const current = action.commit([-1, 1, -2], null, [0, -1, 1, 0]);
  const currentAnswer = f.accept(1); await current; const rows = action.rows;
  f.accept(0); assert.equal(await old, null);
  assert.equal(action.receipt, currentAnswer); assert.deepEqual(action.rows, rows); assert.equal(action.phase, 'accepted');
});

test('selection inspection preserves the action and requests the exact signed selected and pair forms', async () => {
  const f = fixture(), action = f.action;
  const initial = action.commitMatrix([1, -1, 2], [3, 1, 1, 2]); f.accept(); await initial;
  const matrix = [...action.matrix], g = [...action.g], rows = action.rows;
  const selected = [-1, 1, -2], second = [2, 1, 1], inspection = action.inspectSelection(selected, second);
  selected[0] = 99; second[0] = 99;
  assert.deepEqual(f.requests[1].point, [-1, 1, -2]); assert.deepEqual(f.requests[1].second, [2, 1, 1]); assert.deepEqual(f.requests[1].matrix, matrix);
  const answer = f.accept(); await inspection;
  assert.deepEqual(action.g, g); assert.deepEqual(action.matrix, matrix); assert.deepEqual(action.rows, rows);
  assert.deepEqual(action.receipt.point, [-1, 1, -2]); assert.deepEqual(action.receipt.second.point, [2, 1, 1]);
  assert.equal(action.receipt, answer); assert.equal(action.phase, 'accepted');
});

test('exact matrix presets preserve the submitted integers, determinant and small rational image', async () => {
  const f = fixture(), action = f.action, M = [3, 1, 1, 2], point = [1, -1, 2];
  const pending = action.commitMatrix(point, M, [-1, 1, -2]);
  M[0] = 99; point[0] = 99;
  assert.deepEqual(f.requests[0].matrix, [3, 1, 1, 2]); assert.deepEqual(f.requests[0].point, [1, -1, 2]);
  assert.deepEqual(f.requests[0].second, [-1, 1, -2]);
  const answer = f.accept(); await pending;
  assert.equal(answer.denominator, 5); assert.deepEqual(answer.imageNumerator, [8, -23, 22]);
  assert.deepEqual(answer.second.imageNumerator, [-8, 23, -22]); assert.deepEqual(action.matrix, [3, 1, 1, 2]);
  assert.deepEqual(action.rows, displayRowsFromReceipt(answer));
  await assert.rejects(action.commitMatrix([1, 0, 1], [1, .1, 0, 1]), /integers/);
  assert.equal(f.requests.length, 1); assert.equal(action.receipt, answer); assert.equal(action.phase, 'accepted');
});

test('a canceled selection inspection suppresses both stale success and stale failure', async () => {
  const f = fixture(), action = f.action;
  const initial = action.commit([1, -1, 2], null, [1, 1, 0, 1]); f.accept(); await initial;
  const first = action.inspectSelection([-1, 1, -2]); action.cancel(); f.accept();
  assert.equal(await first, null); assert.deepEqual(action.receipt.point, [1, -1, 2]);
  const second = action.inspectSelection([2, 1, 1]); action.reset(); f.requests[2].reject(new Error('Stale inspection failure'));
  assert.equal(await second, null); assert.equal(action.receipt, null); assert.equal(action.phase, 'identity');
});

test('current inspection errors retain the accepted receipt, and invalid quantization starts no request', async () => {
  const f = fixture(), action = f.action;
  const initial = action.commit([1, -1, 2], null, [1, 1, 0, 1]), first = f.accept(); await initial;
  const inspection = action.inspectSelection([2, 1, 1]); f.requests[1].reject(new Error('Current inspection failed'));
  await assert.rejects(inspection, /Current inspection failed/); assert.equal(action.receipt, first);
  await assert.rejects(action.commit([1, -1, 2], null, [1, 0, 0, -1]), /positive determinant/);
  assert.equal(f.requests.length, 2); assert.equal(action.receipt, first); assert.deepEqual(action.rows, displayRowsFromReceipt(first));
  near(action.rows, displayPushforward(matrixFromIntegers(first.matrix)));
});
