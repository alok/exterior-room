// Read-only evaluation of canonical Farey modules; writes only this separate checkout.
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

const source = process.argv[2];
const sourceCommit = process.argv[3];
if (!source || !/^[0-9a-f]{40}$/.test(sourceCommit ?? '')) {
  throw new Error('Usage: node spatial_pair_fixture.mjs CANONICAL_FAREY_DIRECTORY OBSERVED_HEAD');
}
const files = ['WebXR/pair-plane.js', 'WebXR/lattice.js', 'WebXR/starscape-core.js', 'parity/fixtures.json'];
const hashes = Object.fromEntries(files.map(file => [file,
  createHash('sha256').update(readFileSync(resolve(source, file))).digest('hex')]));
const { pairPlane, inPairPlane } = await import(pathToFileURL(resolve(source, files[0])).href);
const { enumerateLattice, tripleAt } = await import(pathToFileURL(resolve(source, files[1])).href);
const { discriminant, polynomial, vector } = await import(pathToFileURL(resolve(source, files[2])).href);
const machine = JSON.parse(readFileSync(resolve(source, files[3]), 'utf8'));
const lattice = enumerateLattice(6);
const requests = [
  { name: 'actual-spatial-sphere', first: [1, -1, 2], second: [3, 0, 3] },
  { name: 'signed-primary', first: [-1, 1, -2], second: [3, 0, 3] },
  { name: 'signed-multiple-secondary', first: [1, -1, 2], second: [-3, 0, -3] },
  { name: 'same-direction', first: [3, 0, 3], second: [1, 0, 1] },
  { name: 'same-direction-opposite-sign', first: [3, 0, 3], second: [-1, 0, -1] },
];
const cases = requests.map(request => {
  const expected = pairPlane(request.first, request.second);
  const inspections = [request.first, request.second].map(point => ({
    point, polynomial: polynomial(point), delta: discriminant(point), xyz: vector(point),
  }));
  if (expected.error) return { ...request, expected, inspections };
  const indices = [], members = [];
  for (let i = 0; i < lattice.count; i++) {
    const point = tripleAt(lattice, i);
    if (discriminant(point) < 0 && inPairPlane(expected.normal, point)) {
      indices.push(i); members.push(point);
    }
  }
  return { ...request, expected, inspections, radius: 6, cloudTotal: lattice.count, indices, members };
});
const result = {
  schema: 'canonical-spatial-pair-contract-v1',
  provenance: { sourceDirectory: resolve(source), observedSourceCommit: sourceCommit, sourceSHA256: hashes,
    machineFixtureGeneratedFrom: machine.generatedFrom,
    scope: 'New actual-sphere cases evaluated from canonical modules; existing machine planes included separately. No UI or kernel-proof claim.' },
  machinePlanes: machine.planes, cases,
};
writeFileSync(new URL('fixtures/spatial-pair-contract.json', import.meta.url), `${JSON.stringify(result, null, 2)}\n`);
console.log(JSON.stringify({ cases: cases.length, validCounts: cases.filter(c => c.members).map(c => c.members.length), sourceCommit }));
