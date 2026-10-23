import test from 'node:test';
import assert from 'node:assert/strict';
import {PRESETS, clone, snap, fraction, validateResult, LeanQueue} from '../web/state.js';

// Transport fixtures, not a substitute for the Grassmann arithmetic tests.
const response = request => ({
  ok: true, ...clone(request), scale: 4,
  wedge: [16, 0, 0], swappedWedge: [-16, 0, 0], selfWedge: [0, 0, 0],
  volume: 64,
  vertices: [[0,0,0], [4,0,0], [0,4,0], [0,0,4], [4,4,0], [4,0,4], [0,4,4], [4,4,4]],
  checks: {antisymmetric: true, selfZero: true}, engine: 'test fixture', sourceCommit: 'test fixture',
});
const request = () => ({...clone(PRESETS.unit), id: 1});
const tick = () => new Promise(resolve => setImmediate(resolve));
function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return {promise, resolve, reject};
}

test('display fractions preserve exact signs, zero, and reduction', () => {
  assert.equal(fraction(16,16), '1');
  assert.equal(fraction(-24,16), '-3/2');
  assert.equal(fraction(3,64), '3/64');
  assert.equal(fraction(0,64), '0');
  assert.equal(fraction(-64,64), '-1');
});

test('display refuses invalid or inexact numeric representations', () => {
  for (const [n,d] of [[0.1,4],[1,0],[1,-4],[Infinity,4],[1,NaN],[Number.MAX_SAFE_INTEGER+1,4]]) {
    assert.equal(fraction(n,d), '?');
  }
});

test('drag quantization stays on the bounded integer lattice', () => {
  for (const n of [-100,-12.6,-3.2,0,0.49,0.6,12.6,100]) {
    const result=snap(n);
    assert.ok(Number.isInteger(result));
    assert.ok(result >= -12 && result <= 12);
  }
  assert.equal(snap(.6),1);
  assert.equal(snap(-3.2),-3);
});

test('fixture presets clone independently', () => {
  const copy=clone(PRESETS.unit);
  copy.a[0]=99;
  assert.equal(PRESETS.unit.a[0],4);
});

test('accepts a complete response matching the submitted edit', () => {
  const input=request(), output=response(input);
  assert.equal(validateResult(output,input),output);
});

test('rejects stale IDs, unsuccessful responses and wrong physical scale', () => {
  const input=request();
  for (const changes of [{id:0},{id:'1'},{ok:false},{scale:1},{scale:16}]) {
    assert.throws(()=>validateResult({...response(input),...changes},input));
  }
  assert.throws(()=>validateResult(null,input));
});

test('rejects responses whose echoed vectors differ from the request', () => {
  const input=request();
  for (const name of ['a','b','c']) {
    const output=response(input);
    output[name][0]+=1;
    assert.throws(()=>validateResult(output,input), /match this edit/);
  }
});

test('rejects malformed and unsafe exact coefficients', () => {
  const input=request();
  for (const name of ['wedge','swappedWedge','selfWedge']) {
    for(const value of [[1,2],[1,2,3,4],[1,2,.5],[1,2,Infinity],[1,2,Number.MAX_SAFE_INTEGER+1],null]) {
      assert.throws(()=>validateResult({...response(input),[name]:value},input));
    }
  }
});

test('rejects malformed volume and exported geometry', () => {
  const input=request();
  for(const value of [0.25,Infinity,NaN,Number.MAX_SAFE_INTEGER+1]) {
    assert.throws(()=>validateResult({...response(input),volume:value},input));
  }
  for(const vertices of [[],new Array(7).fill([0,0,0]),new Array(8).fill([0,0]),new Array(8).fill([0,0,.5])]) {
    assert.throws(()=>validateResult({...response(input),vertices},input));
  }
});

test('serializes execution, drops intermediate edits, and never renders an old answer', async () => {
  const calls=[], pending=[], rendered=[], statuses=[];
  const queue=new LeanQueue({
    transport:input=>{const d=deferred();calls.push(input);pending.push(d);return d.promise;},
    onResult:value=>rendered.push(value), onStatus:status=>statuses.push(status),
  });
  queue.submit(PRESETS.unit);
  queue.submit(PRESETS.skew);
  queue.submit(PRESETS.plane);
  assert.equal(calls.length,1);
  pending[0].resolve(response(calls[0]));
  await tick();
  assert.equal(calls.length,2);
  assert.equal(calls[1].id,3);
  assert.deepEqual(calls[1].a,PRESETS.plane.a);
  assert.equal(rendered.length,0);
  pending[1].resolve(response(calls[1]));
  await tick();
  assert.deepEqual(rendered.map(r=>r.id),[3]);
  assert.deepEqual(statuses,['pending','pending','pending','live']);
  assert.equal(queue.running,false);
});

test('freezes request coordinates before the caller can mutate them', async () => {
  const d=deferred(), source=clone(PRESETS.unit);let captured;
  const queue=new LeanQueue({transport:input=>{captured=input;return d.promise;},onResult:()=>{},onStatus:()=>{}});
  queue.submit(source);source.a[0]=12;
  assert.equal(captured.a[0],4);
  d.resolve(response(captured));await tick();
});

test('superseded transport errors cannot mark a newer edit as failed', async () => {
  const calls=[], pending=[], statuses=[];
  const queue=new LeanQueue({transport:input=>{const d=deferred();calls.push(input);pending.push(d);return d.promise;},onResult:()=>{},onStatus:status=>statuses.push(status)});
  queue.submit(PRESETS.unit);queue.submit(PRESETS.skew);
  pending[0].reject(new Error('old request disconnected'));await tick();
  assert.deepEqual(statuses,['pending','pending']);
  pending[1].resolve(response(calls[1]));await tick();
  assert.deepEqual(statuses,['pending','pending','live']);
});

test('latest transport failure leaves the last result intact and permits retry', async () => {
  const rendered=[], statuses=[];let fail=false;
  const queue=new LeanQueue({transport:async input=>{if(fail)throw Error('Lean unavailable');return response(input);},onResult:r=>rendered.push(r),onStatus:(state,message)=>statuses.push([state,message])});
  queue.submit(PRESETS.unit);await tick();
  fail=true;queue.submit(PRESETS.skew);await tick();
  assert.deepEqual(rendered.map(r=>r.id),[1]);
  assert.deepEqual(statuses.at(-1),['error','Lean unavailable']);
  assert.equal(queue.running,false);
  fail=false;queue.submit(PRESETS.skew);await tick();
  assert.deepEqual(rendered.map(r=>r.id),[1,3]);
  assert.equal(statuses.at(-1)[0],'live');
});

test('invalid server payload cannot become a displayed result', async () => {
  const rendered=[], statuses=[];
  const queue=new LeanQueue({transport:async input=>({...response(input),id:1000}),onResult:r=>rendered.push(r),onStatus:(state,message)=>statuses.push([state,message])});
  queue.submit(PRESETS.unit);await tick();
  assert.deepEqual(rendered,[]);
  assert.equal(statuses.at(-1)[0],'error');
  assert.match(statuses.at(-1)[1],/Unexpected Lean response/);
});
