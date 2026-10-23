// SPDX-License-Identifier: GPL-3.0-or-later
// Generate data from pinned canonical Git blobs without modifying or importing its working tree.
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { writeFileSync } from 'node:fs';

const source = process.argv[2];
if (!source) throw Error('Usage: node lean/Polynomial/generate_snap_fixtures.mjs /path/to/FareyVision');
const pin = '6fea557bb0d0c786bed5223dc631cb1c06e94f16';
const names = ['WebXR/mobius.js', 'WebXR/mobius.test.js', 'WebXR/starscape.js', 'WebXR/mobius-checks.js',
  'WebXR/starscape-core.js', 'WebXR/pair-plane.js', 'BEHAVIOR_NOTEBOOK.md', 'parity/fixtures.json'];
const blobs = Object.fromEntries(names.map(name => [name,
  execFileSync('git', ['show', `${pin}:Farey/${name}`], { cwd: source })]));
const moduleURL = text => `data:text/javascript;base64,${Buffer.from(text).toString('base64')}`;
const math = await import(moduleURL(blobs['WebXR/mobius.js']));
const coreURL = moduleURL(blobs['WebXR/starscape-core.js']);
const plane = await import(moduleURL(blobs['WebXR/pair-plane.js'].toString().replace("'./starscape-core.js'", JSON.stringify(coreURL))));
const { identity, multiply, inverse, transvection, nearestIntegral, pushforwardExact, isIntegral } = math;
const T = [1, 1, 0, 1], S = [0, -1, 1, 0];
const candidates = [
  ['identity', identity], ['T', T], ['S', S], ['T-inverse', inverse(T)],
  ['T-S', multiply(T, S)], ['T-T-S', multiply(multiply(T, T), S)],
  ['small-drag', transvection({ x: 0, y: 1 }, { x: 0.1, y: 1.05 })],
  ['near-T', multiply(transvection({ x: 0, y: 1 }, { x: 0.05, y: 1.1 }), T)],
];
const starscape = blobs['WebXR/starscape.js'].toString();
const absorbFunction = starscape.match(/function absorb\(gamma\)\{[\s\S]*?\n\}/)?.[0];
const identityHandler = starscape.match(/\$\('g-identity'\)\.onclick=\(\)=>setGroup\(identity\);/)?.[0];
if (!absorbFunction || !identityHandler) throw Error('Pinned absorption/Identity contract changed.');
// Execute the actual small state transition with its rendering callback replaced by a state-only sink.
const transition = new Function('pushforwardExact', 'isIntegral', 'identity', 'gamma', 'initial', `
  let selected=[...initial.selected], secondSelection=initial.second&&[...initial.second], group=[...initial.group];
  const setGroup=g=>{group=[...g];};
  const snapshot=()=>({selected:[...selected],second:secondSelection&&[...secondSelection],group:[...group]});
  ${absorbFunction}
  absorb(gamma);const afterAbsorb=snapshot();setGroup(identity);
  return {afterAbsorb,afterIdentity:snapshot()};
`);
const planeSummary = (first, second) => {
  if (!second) return null;
  const p = plane.pairPlane(first, second);
  if (p.error) return p;
  return { normal: p.normal, equation: p.equation, endpoints: p.endpoints.map(e => e.label) };
};
const states = [
  ['recorded-user-seed', [13, 20, 34], null],
  ['user-seed-paired', [13, 20, 34], [1, 0, 1]],
  ['negative-multiple-pair', [-26, -40, -68], [-2, 0, -2]],
  ['mixed-sign-pair', [13, 20, 34], [-2, 0, -2]],
  ['first-image-out-of-bounds', [96, -96, 96], [1, 0, 1]],
  ['second-image-out-of-bounds', [1, 0, 1], [-96, 96, -96]],
];
const absorptions = states.map(([id, selected, second]) => {
  const before = { selected, second, group: T };
  const result = transition(pushforwardExact, isIntegral, identity, T, before);
  const after = result.afterAbsorb;
  return { id, gamma: T, before, ...result,
    planeBefore: planeSummary(selected, second), planeAfter: planeSummary(after.selected, after.second),
    serviceInputsWithin96: [after.selected, after.second].filter(Boolean).every(p => p.every(x => Math.abs(x) <= 96)) };
});
const result = {
  sourceCommit: pin, sourceFileSHA256: Object.fromEntries(names.map(name => [name, createHash('sha256').update(blobs[name]).digest('hex')])),
  generation: 'Pinned canonical nearestIntegral and actual absorb function; renderer callback replaced by a state sink. No UI execution.',
  boundary: 'Snap candidate selection is floating-point canonical regression data, not a Lean theorem or proof of globally nearest SL2Z.',
  nearestIntegral: candidates.map(([id, matrix]) => ({ id, matrixApprox: matrix, gamma: nearestIntegral(matrix) })),
  absorbFunction, identityHandler, absorptions,
};
writeFileSync(new URL('./fixtures/snap-contract.json', import.meta.url), JSON.stringify(result, null, 2)+'\n');
console.log(`Wrote ${candidates.length} Snap candidates and ${absorptions.length} absorption cases from ${pin}.`);
