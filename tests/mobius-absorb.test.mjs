import test from 'node:test';
import assert from 'node:assert/strict';
import { integralRepresentative, prepareAbsorption } from '../web/polynomial/mobius-absorb.js';

const T = [1, 1, 0, 1], source = [13, 20, 34], image = [13, -6, 27];
const second = [-2, -1, -1], secondImage = [-2, 3, -2];
function fixture(overrides = {}) {
  const calls = [], input = { matrix: [...T], point: [...source], second: [...second] }, plane = { equation: 'test exact plane' };
  let current = true;
  const receipt = { image: [...image], second: { image: [...secondImage] } };
  const args = { ...input,
    commit: async (p, m, s) => { calls.push(['commit', p, m, s]); return receipt; },
    inspect: async p => { calls.push(['inspect', p]); },
    preparePair: async (p, s) => { calls.push(['pair', p, s]); return plane; },
    isCurrent: () => current, ...overrides };
  return { args, input, receipt, plane, calls, cancel: () => { current = false; } };
}
function deferred() { let resolve, reject; const promise = new Promise((yes, no) => { resolve = yes; reject = no; }); return { promise, resolve, reject }; }

test('integer representative uses exact positive square/divisibility checks', () => {
  assert.deepEqual(integralRepresentative([10000, 10000, 0, 10000]), T);
  assert.deepEqual(integralRepresentative([-10000, -10000, 0, -10000]), T.map(n => n === 0 ? 0 : -n));
  assert.deepEqual(integralRepresentative([1_000_000, 0, 0, 1_000_000]), [1, 0, 0, 1]);
  assert.equal(integralRepresentative([3, 1, 1, 2]), null); // determinant 5 is not a square.
  assert.equal(integralRepresentative([1, 0, 0, 4]), null); // determinant 4, but entries not divisible by 2.
  assert.equal(integralRepresentative([1, 0, 0, -1]), null);
  assert.equal(integralRepresentative([.5, 0, 0, 2]), null);
});

test('Snap stages both signed identities and their exact plane without mutating caller state', async () => {
  const f = fixture(), original = structuredClone(f.input);
  const result = await prepareAbsorption(f.args);
  assert.deepEqual(result, { point: image, second: secondImage, receipt: f.receipt, plane: f.plane });
  assert.deepEqual(f.calls.map(c => c[0]), ['commit', 'inspect', 'inspect', 'pair']);
  assert.deepEqual(f.calls[1][1], image); assert.deepEqual(f.calls[2][1], secondImage);
  assert.deepEqual(f.input, original); assert.notEqual(result.point, f.receipt.image); assert.notEqual(result.second, f.receipt.second.image);
});

test('a single-point absorption does not inspect or prepare an absent partner', async () => {
  const f = fixture({ second: null }); delete f.receipt.second;
  const result = await prepareAbsorption(f.args);
  assert.equal(result.second, null); assert.equal(result.plane, null);
  assert.deepEqual(f.calls.map(c => c[0]), ['commit', 'inspect']);
});

test('asymmetric bounds, nonintegral images and non-SL2 matrices cannot partially absorb', async () => {
  for (const badField of ['selected', 'second']) {
    const f = fixture(), original = structuredClone(f.input);
    if (badField === 'selected') f.receipt.image = [1025, 0, 1]; else f.receipt.second.image = [-2, 3, -1025];
    await assert.rejects(prepareAbsorption(f.args), /±1024/);
    assert.deepEqual(f.calls.map(c => c[0]), ['commit']); assert.deepEqual(f.input, original);
  }
  const fractional = fixture(); fractional.receipt.image = null;
  await assert.rejects(prepareAbsorption(fractional.args), /integer triple/);
  assert.equal(fractional.calls.length, 1);
  const notSL2 = fixture({ matrix: [1, 0, 0, 2] }); // Even if this particular point's image happened to be integral.
  await assert.rejects(prepareAbsorption(notSL2.args), /determinant-one/); assert.equal(notSL2.calls.length, 0);
});

test('either signed-point inspection failure preserves the original selection and skips the plane', async () => {
  for (const failureAt of [0, 1]) {
    let inspected = 0;
    const f = fixture({ inspect: async () => { if (inspected++ === failureAt) throw Error('Point inspection failed'); } }), original = structuredClone(f.input);
    await assert.rejects(prepareAbsorption(f.args), /Point inspection failed/);
    assert.equal(inspected, failureAt + 1); assert.deepEqual(f.input, original);
    assert.ok(!f.calls.some(c => c[0] === 'pair'));
  }
});

test('cancellation after commit or either inspection stops later work', async () => {
  for (const at of ['commit', 'first', 'second']) {
    const f = fixture(); let inspected = 0;
    f.args.commit = async () => { if (at === 'commit') f.cancel(); return f.receipt; };
    f.args.inspect = async () => { inspected++; if (at === 'first' && inspected === 1 || at === 'second' && inspected === 2) f.cancel(); };
    assert.equal(await prepareAbsorption(f.args), null);
    assert.equal(inspected, at === 'commit' ? 0 : at === 'first' ? 1 : 2);
    assert.ok(!f.calls.some(c => c[0] === 'pair'));
  }
});

test('cancellation during pair preparation suppresses stale success and failure', async () => {
  for (const reject of [false, true]) {
    const pending = deferred(), started = deferred(), f = fixture({ preparePair: async () => { started.resolve(); return pending.promise; } });
    const result = prepareAbsorption(f.args); await started.promise; f.cancel();
    if (reject) pending.reject(Error('Old pair request failed')); else pending.resolve(f.plane);
    assert.equal(await result, null); assert.deepEqual(f.input.point, source); assert.deepEqual(f.input.second, second);
  }
});

test('current pair errors throw and current null commits return no absorption', async () => {
  const f = fixture({ preparePair: async () => ({ error: 'Coincident projective forms' }) });
  await assert.rejects(prepareAbsorption(f.args), /Coincident projective forms/);
  const absent = fixture({ commit: async () => null }); assert.equal(await prepareAbsorption(absent.args), null);
  assert.equal(absent.calls.length, 0);
});
