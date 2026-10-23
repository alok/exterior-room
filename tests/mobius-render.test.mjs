import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { Matrix4, Vector3 } from '../web/vendor/three.module.js';
import { identity, multiply, determinant, act, transvection, dragStep, pushforward, applyRows, pushforwardExact, upperToKlein, kleinToUpper } from '../web/polynomial/mobius.js';
import { coefficientsToDisplay, displayToCoefficients, coefficientRowsToDisplay, displayPushforward, displayMatrix4,
  transformDisplay, transformPackedPositions, projectedPositions, rootDiskPosition, rootDiskPositions,
  pointerToKlein, kleinToClient, pointerToUpper, quantizeMatrix, matrixFromIntegers, displayRowsFromReceipt, displayMatrix4FromReceipt,
  chartTransform, rootCoordinates, rootToClient, zoomChartAt, halfPlaneGeodesic } from '../web/polynomial/mobius-render.js';

const near = (a, b, tolerance = 1e-9) => {
  assert.equal(a.length, b.length);
  a.forEach((n, i) => assert.ok(Math.abs(n - b[i]) <= tolerance * Math.max(1, Math.abs(b[i])), `${n} != ${b[i]} (index ${i})`));
};
const T = [1, 1, 0, 1], S = [0, -1, 1, 0];
// These signed forms, S/T images and seed are from the pinned canonical mobius.test.js.
const forms = [[1, -1, 2], [1, 0, 1], [3, 2, 2], [13, 20, 34], [2, 1, 1], [-1, 1, -2]];
const delta = ([a, b, c]) => b * b - 4 * a * c;
const lorentz = ([x, y, z]) => x * x + z * z - y * y;
const rowsMultiply = (g, h) => [0, 1, 2].flatMap(i => [0, 1, 2].map(j => [0, 1, 2].reduce((sum, k) => sum + g[3 * i + k] * h[3 * k + j], 0)));
function lattice(points) {
  return { count: points.length, xyz: new Float32Array(points.flatMap(coefficientsToDisplay)),
    kind: new Uint8Array(points.map(p => delta(p) < 0 ? p[0] > 0 ? 2 : 3 : delta(p) === 0 ? 1 : 0)) };
}

test('canonical Möbius implementation is pinned byte-identically with preserved attribution', () => {
  const source = readFileSync(new URL('../web/polynomial/mobius.js', import.meta.url));
  assert.equal(createHash('sha256').update(source).digest('hex'), 'd2dbc833ca29bf7160e99f976aa433ca8a274a612d0e9f5d95b82aa6803f6886');
  assert.match(source.toString(), /Harriss, Stange and/);
});

test('display basis and row-major Matrix4 agree with canonical signed S/T images', () => {
  assert.deepEqual(coefficientsToDisplay([13, 20, 34]), [-20, 47, 21]);
  assert.equal(delta([13, 20, 34]), -1368);
  assert.deepEqual(pushforwardExact(T, [1, 0, 1]), [1n, -2n, 2n]);
  assert.deepEqual(pushforwardExact(S, [1, -1, 2]), [2n, 1n, 1n]);
  for (const abc of forms) {
    assert.deepEqual(displayToCoefficients(coefficientsToDisplay(abc)), abc);
    assert.equal(lorentz(coefficientsToDisplay(abc)), delta(abc));
    for (const g of [identity, T, S, multiply(T, S)]) {
      const expected = coefficientsToDisplay(pushforwardExact(g, abc).map(Number));
      near(transformDisplay(g, coefficientsToDisplay(abc)), expected);
      // Actual Three.js consumer checks row-major ordering, which fromArray would transpose.
      near(new Vector3(...coefficientsToDisplay(abc)).applyMatrix4(new Matrix4().set(...displayMatrix4(g))).toArray(), expected);
    }
  }
});

test('display conjugation is a composition action and preserves signed discriminants', () => {
  const g = transvection({ x: 0, y: 1 }, { x: 1.3, y: .6 });
  const h = multiply(T, transvection({ x: 2, y: 1 }, { x: -1, y: 2 }));
  near(displayPushforward(multiply(g, h)), rowsMultiply(displayPushforward(g), displayPushforward(h)), 1e-8);
  for (const abc of forms) {
    const xyz = coefficientsToDisplay(abc), moved = transformDisplay(g, xyz);
    near(moved, coefficientsToDisplay(applyRows(pushforward(g), abc)));
    near(transformDisplay(g, xyz.map(x => -x)), moved.map(x => -x));
    near([lorentz(moved)], [delta(abc)], 1e-8);
    near(rootDiskPosition(abc, g), upperToKlein(act(g, kleinToUpper(...rootDiskPosition(abc)))), 1e-8);
  }
});

test('packed preview retains base buffers, order and signed points for selection/color identities', () => {
  const source = lattice(forms), original = new Float32Array(source.xyz);
  const output = transformPackedPositions(source.xyz, T);
  assert.notEqual(output, source.xyz); assert.deepEqual(source.xyz, original);
  forms.forEach((abc, i) => near([...output.slice(i * 3, i * 3 + 3)], coefficientsToDisplay(applyRows(pushforward(T), abc)), 1e-6));
  assert.deepEqual(transformPackedPositions([], T), new Float32Array());
});

test('radial projection is recomputed after transformation and retains coincident signs/multiples', () => {
  const source = lattice([[1, 0, 1], [-1, 0, -1], [2, 0, 2], [1, 2, 1], [1, 3, 1]]);
  const projected = projectedPositions(source, T, 4);
  assert.equal(projected.length, 9);
  for (let i = 0; i < 3; i++) near([...projected.slice(i * 3, i * 3 + 3)], [8 / 3, 4, 4 / 3], 1e-6);
  const wrong = transformDisplay(T, [0, 4, 0]);
  assert.equal(wrong[1], 6); assert.notEqual(wrong[1], projected[1]);
  const roots = rootDiskPositions(source, T);
  assert.equal(roots.count, 3); assert.deepEqual([...roots.indices], [0, 1, 2]);
  for (let i = 0; i < 3; i++) near([...roots.positions.slice(i * 2, i * 2 + 2)], [2 / 3, 1 / 3], 1e-6);
  for (const abc of [[0, 0, 0], [1, 2, 1], [1, 3, 1], [-1, -2, -1]]) assert.equal(rootDiskPosition(abc, T), null);
  near(rootDiskPosition([-1, 1, -2], T), rootDiskPosition([1, -1, 2], T));
});

test('Klein pointer mapping uses CSS-pixel pan, upward v and reversible chart zoom', () => {
  const rect = { left: 80, top: 30, width: 500, height: 300 }, options = { pan: [31, -12], zoom: 1.7, padding: 16 };
  for (const uv of [[0, 0], [.2, -.4], [-.8, .1]]) {
    const pixel = kleinToClient(uv, rect, options);
    near(pointerToKlein(...pixel, rect, options), uv);
    const upper = pointerToUpper(...pixel, rect, options), expected = kleinToUpper(...uv);
    near([upper.x, upper.y], [expected.x, expected.y]);
  }
  near(kleinToClient([0, 0], rect, options), [361, 168]);
  assert.ok(kleinToClient([0, .3], rect, options)[1] < 168);
  assert.equal(pointerToKlein(...kleinToClient([1, 0], rect), rect), null);
  assert.equal(pointerToUpper(...kleinToClient([1.1, 0], rect), rect), null);
});

test('canonical drag composition makes a root follow successive Klein pointer anchors', () => {
  const rect = { left: 0, top: 0, width: 500, height: 500 };
  const abc = [13, 20, 34]; let g = [...identity];
  for (const target of [[.2, -.2], [-.3, .4], [.4, .2]]) {
    const previous = pointerToUpper(...kleinToClient(rootDiskPosition(abc, g), rect), rect);
    const next = pointerToUpper(...kleinToClient(target, rect), rect);
    g = dragStep(g, previous, next);
    near(rootDiskPosition(abc, g), target, 1e-8); near([determinant(g)], [1], 1e-9);
  }
});

test('UHP fit, signed roots and pointer conversion match the canonical source chart', () => {
  const rect={left:80,top:30,width:600,height:400},options={model:'half-plane',zoom:1,pan:[0,0]};
  assert.deepEqual(chartTransform(rect,options),{cx:380,cy:402,scale:250});
  near(rootToClient([0,2,0],-4,rect,options),[380,152]);
  assert.deepEqual(pointerToUpper(380,152,rect,options),{x:0,y:1});
  assert.equal(pointerToUpper(380,402,rect,options),null);
  assert.equal(pointerToUpper(380,403,rect,options),null);
  // Exact D5 image is (8,-23,22)/5, so its upper root is
  // 23/16 + i·5√7/16. Negative identities share that upper root.
  const xyz=[23/5,6,14/5],expected=[23/16,5*Math.sqrt(7)/16];
  near(rootCoordinates(xyz,-7),expected);
  near(rootCoordinates(xyz.map(x=>-x),-7),expected);
  const movedOptions={...options,zoom:1.7,pan:[31,-12]},pixel=rootToClient(xyz,-7,rect,movedOptions);
  const root=pointerToUpper(...pixel,rect,movedOptions);near([root.x,root.y],expected);
  assert.equal(rootCoordinates([1,1,1],0),null);
  assert.equal(rootCoordinates([1,1,1],-1),null);
});

test('UHP pointer-anchor zoom and transvection move the selected root without changing its identity', () => {
  const rect={left:20,top:40,width:720,height:480},original={model:'half-plane',zoom:1.3,pan:[22,-11]};
  const mouse=[412,189],before=pointerToUpper(...mouse,rect,original);
  const zoomed={...original,...zoomChartAt(...mouse,rect,original,2.4)};
  const after=pointerToUpper(...mouse,rect,zoomed);near([after.x,after.y],[before.x,before.y]);
  const xyz=coefficientsToDisplay([13,20,34]),d=-1368;
  const from=pointerToUpper(...rootToClient(xyz,d,rect,original),rect,original),target={x:.4,y:1.2};
  const g=dragStep(identity,from,target);
  near(rootCoordinates(transformDisplay(g,xyz),d),[target.x,target.y]);
  assert.deepEqual(xyz,[-20,47,21]);
});

test('UHP plane rendering uses moved semicircles and a symbolic infinite endpoint', () => {
  const ends=[[-1,1,0],[1,1,0]],g=matrixFromIntegers([3,1,1,2]);
  const points=halfPlaneGeodesic(ends.map(p=>transformDisplay(g,p)),{segments:8});
  near(points[0],[4/3,0]);near(points[4],[-1/3,5/3]);near(points[8],[-2,0]);
  const vertical=[[0,1,-1],[0,1,1]];
  assert.deepEqual(halfPlaneGeodesic(vertical,{top:7}),[[0,0],[0,7]]);
  near(halfPlaneGeodesic(vertical.map(p=>transformDisplay(T,p)),{top:7})[1],[1,7]);
  const transformed=halfPlaneGeodesic(vertical.map(p=>transformDisplay(g,p)),{segments:2});
  near(transformed[0],[3,0]);near(transformed[1],[7/4,5/4]);near(transformed[2],[1/2,0]);
});

test('release quantization uses positive exact determinant and commits J(M)/D, not quantum squared', () => {
  const g = transvection({ x: 0, y: 1 }, { x: 1, y: 1 });
  const M = quantizeMatrix(g, 10), [p, q, r, s] = M;
  const D = Number(BigInt(p) * BigInt(s) - BigInt(q) * BigInt(r));
  assert.notEqual(D, 100); assert.ok(D > 0);
  const preview = matrixFromIntegers(M); near([determinant(preview)], [1]);
  const receipt = { denominator: D, coefficientRows: pushforward(M) };
  near(displayRowsFromReceipt(receipt), displayPushforward(preview));
  near(displayMatrix4FromReceipt(receipt), displayMatrix4(preview));
  near(displayRowsFromReceipt({ ...receipt, coefficientRows: new Int32Array(receipt.coefficientRows) }), displayPushforward(preview));
  near(displayPushforward(matrixFromIntegers(M.map(n => -n))), displayPushforward(preview));
  assert.deepEqual(quantizeMatrix([2, 0, 0, 2], 10), [10, 0, 0, 10]);
  assert.deepEqual(quantizeMatrix([1, .3, 0, 1], 10), [10, 3, 0, 10]);
  // Conversion has no access to transport/commit state and cannot establish a Lean response's validity.
});

test('invalid charts, matrices and singular quantization fail without silent fallback', () => {
  assert.throws(() => displayPushforward([1, 0, 0, -1]), /positive determinant/);
  assert.throws(() => quantizeMatrix([1, 1, .99, 1], 1), /strictly positive/);
  assert.throws(() => quantizeMatrix([1, 200, 0, 1]), /bounded/);
  assert.throws(() => matrixFromIntegers([1, 0, 0, .5]), /integers/);
  assert.throws(() => transformPackedPositions([0, Infinity, 1], T), /finite Float32/);
  assert.throws(() => projectedPositions(lattice([[1, 0, 1]]), T, 1e308), /finite Float32/);
  assert.throws(() => pointerToKlein(0, 0, { left: 0, top: 0, width: 10, height: 10 }), /no disk/);
  assert.equal(pointerToKlein(NaN, 0, { left: 0, top: 0, width: 100, height: 100 }), null);
  assert.throws(() => displayRowsFromReceipt({ denominator: 0, coefficientRows: pushforward(T) }), /positive exact/);
});
