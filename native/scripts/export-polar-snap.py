#!/usr/bin/env python3
"""Export current source-compatible floating-point Snap proposals; never a Lean proof."""
import base64
import hashlib
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
canonical = Path('/Users/alokbeniwal/Documents/Codex/2026-10-21/task-7/FareyVision')
commit = '2cd549a45ddb6056cf3596404754d96ad9e7132c'
source_path = 'Farey/WebXR/mobius.js'
source = subprocess.check_output(['git', '-C', str(canonical), 'show', commit + ':' + source_path])
shared_path = 'Farey/parity/fixtures.json'
shared_bytes = subprocess.check_output(['git', '-C', str(canonical), 'show', commit + ':' + shared_path])
shared = json.loads(shared_bytes)['mobius']['snap']
prior = json.loads((root / 'Resources/polynomial-snap-cases.json').read_text())
inputs = [{'name': c['name'], 'matrix': c['matrix']} for c in prior['cases']]
inputs += [{'name': 'recorded-source-' + str(i), 'matrix': c['gRecordedApprox']} for i, c in enumerate(shared)]
inputs += [{'name': 'negative-recorded-source', 'matrix': [-x for x in shared[0]['gRecordedApprox']]},
           {'name': 'nonfinite-image-of-i', 'matrix': [1e200, 0, 0, 1e-200]},
           {'name': 'unbounded-translation', 'matrix': [1, 1e300, 0, 1]}]
program = '''
const {nearestIntegral, normalize, transvection} = await import(process.env.POLAR_SNAP_MODULE);
let text = ''; for await (const chunk of process.stdin) text += chunk;
const cases = JSON.parse(text);
for (const angle of [0.3, Math.PI/4, Math.PI/4+2e-12, Math.PI/4-2e-12, -Math.PI/4])
  cases.push({name:`rotation-${angle}`,matrix:[Math.cos(angle),-Math.sin(angle),Math.sin(angle),Math.cos(angle)]});
cases.push({name:'declared-vertical-counterexample',matrix:normalize([50,18,0,5])});
cases.push({name:'computed-source-counterexample',matrix:transvection({x:-0.4,y:0.1},{x:-0.4,y:1})});
process.stdout.write(JSON.stringify(cases.map(c => ({...c,expected:nearestIntegral(c.matrix)}))));
'''
import os
environment = dict(os.environ, POLAR_SNAP_MODULE='data:text/javascript;base64,' + base64.b64encode(source).decode())
cases = json.loads(subprocess.check_output(['node', '--input-type=module', '-e', program],
    input=json.dumps(inputs).encode(), env=environment))
for c, fixture in zip(cases[len(prior['cases']):], shared):
    assert c['expected'] == fixture['gamma']
output = {'sourceCommit': commit, 'sourcePath': source_path,
          'sourceSha256': hashlib.sha256(source).hexdigest(),
          'sharedFixturePath': shared_path, 'sharedFixtureSha256': hashlib.sha256(shared_bytes).hexdigest(),
          'scope': 'Executed pinned canonical JavaScript polar-Snap proposals. Floating-point renderer regressions, not Lean computations or kernel theorems. Historical entrywise fixtures are preserved separately.',
          'cases': cases}
target = root / 'Resources/polynomial-polar-snap-cases.json'
target.write_text(json.dumps(output, indent=2) + '\n')
print(f'{len(cases)} source-compatible Snap cases -> {target}')
