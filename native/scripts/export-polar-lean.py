#!/usr/bin/env python3
"""Export exact polar-Snap regression receipts from the actual compiled Lean service."""
import hashlib
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[2]
binary = root / 'lean/.lake/build/bin/polynomial_service'
matrix, gamma = [50,18,0,5], [1,4,0,1]
items = []
def ask(process, name, **request):
    request['id'] = len(items)+1
    process.stdin.write(json.dumps(request)+'\n'); process.stdin.flush()
    response = json.loads(process.stdout.readline())
    assert response['id'] == request['id']
    items.append({'name':name, 'request':request, 'response':response})
    return response

binary_hash = hashlib.sha256(binary.read_bytes()).hexdigest()
with subprocess.Popen([str(binary)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True) as process:
    for label,point in [('unit',[1,0,1]),('pair',[1,1,1]),('source',[13,20,34])]:
        ask(process,'counterexample-'+label,op='transform',matrix=matrix,point=point)
        image = ask(process,'T4-'+label,op='transform',matrix=gamma,point=point)['image']
        inspected = ask(process,'inspect-T4-'+label,op='inspect',point=image)
        assert inspected['ok']
        ask(process,'identity-T4-'+label,op='transform',matrix=[1,0,0,1],point=image)
    pair = ask(process,'pair-T4',op='pair',first=[1,-8,17],second=[1,-7,13])
    assert pair['ok']
    ask(process,'members-T4',op='members',radius=6,upperOnly=False,normal=pair['normal'])
    for label,point in [('positive',[1024,-1024,1024]),('negative',[-1024,1024,-1024])]:
        assert ask(process,'inspect-identity-bound-'+label,op='inspect',point=point)['ok']
        receipt=ask(process,'T-identity-bound-'+label,op='transform',matrix=[1,1,0,1],point=point)
        assert receipt['ok']
        assert not ask(process,'inspect-over-identity-bound-'+label,op='inspect',point=receipt['image'])['ok']
    assert ask(process,'pair-identity-bound-first',op='pair',first=[1024,-1024,1024],second=[1,0,1])['ok']
    assert ask(process,'pair-identity-bound-second',op='pair',first=[1,0,1],second=[-1024,1024,-1024])['ok']
    first,second=[957,361,180],[983,640,735]
    assert ask(process,'inspect-large-normal-first',op='inspect',point=first)['ok']
    assert ask(process,'inspect-large-normal-second',op='inspect',point=second)['ok']
    wide=ask(process,'pair-large-normal',op='pair',first=first,second=second)
    assert wide['ok'] and wide['normal']==[257617,1052910,150135]
    ask(process,'members-large-normal',op='members',radius=6,upperOnly=False,normal=wide['normal'])
    ask(process,'transform-safe-integer-edge',op='transform',matrix=[999999,1000000,-1000000,1000000],point=[1024,-1024,1024])
    process.stdin.close(); process.wait(timeout=15)
assert hashlib.sha256(binary.read_bytes()).hexdigest()==binary_hash
target=root/'native/Resources/polynomial-polar-lean-cases.json'
target.write_text(json.dumps({'generator':'lean/.lake/build/bin/polynomial_service','generatorSha256':binary_hash,
    'scriptSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'scope':'Actual Lean action/inspection/pair/membership responses. Exact identity bound1024 is independent of cloudradius96. Includes source(13,20,34) T4 absorption, asymmetric1024-bound rejections and expanded validpairnormal; no fallback arithmetic.',
    'cases':items},indent=2)+'\n')
print(f'{len(items)} actual Lean receipts -> {target}')
