// SPDX-License-Identifier: GPL-3.0-or-later
// Input manipulation and transport only. Exterior products live in Lean.
export const PRESETS = {
  skew: {a:[7,1,1], b:[-2,6,1], c:[1,1,7]},
  unit: {a:[4,0,0], b:[0,4,0], c:[0,0,4]},
  plane: {a:[8,0,0], b:[0,7,0], c:[4,4,0]},
};
export const clone = value => JSON.parse(JSON.stringify(value));
export const snap = value => Math.max(-12, Math.min(12, Math.round(value)));
export function fraction(n, d) {
  if (!Number.isSafeInteger(n) || !Number.isSafeInteger(d) || d <= 0) return '?';
  let a=Math.abs(n),b=d; while(b){const r=a%b;a=b;b=r;}
  return d/a===1 ? String(n/a) : `${n/a}/${d/a}`;
}
export function validateResult(result, request) {
  if (!result || result.ok !== true || result.id !== request.id || result.scale !== 4) throw Error('Unexpected Lean response.');
  const triple = a => Array.isArray(a) && a.length===3 && a.every(Number.isSafeInteger);
  for(const k of ['a','b','c']) if(!triple(result[k]) || result[k].some(n=>Math.abs(n)>12) || JSON.stringify(result[k])!==JSON.stringify(request[k])) throw Error('Lean response does not match this edit.');
  // Protocol bounds follow the input box. These checks do not compute an exterior product.
  for(const k of ['wedge','swappedWedge','selfWedge']) if(!triple(result[k]) || result[k].some(n=>Math.abs(n)>288)) throw Error('Invalid exact coefficients.');
  for(const k of ['volume','swappedVolume','repeatedVolume']) if(!Number.isSafeInteger(result[k]) || Math.abs(result[k])>10368) throw Error('Invalid exact volume.');
  const checks=['antisymmetric','selfZero','volumeAntisymmetric','repeatedVolumeZero'];
  if(!checks.every(name=>result.checks?.[name]===true)
    || result.selfWedge.some(n=>n!==0) || result.repeatedVolume!==0
    || result.swappedWedge.some((n,i)=>n!==-result.wedge[i]) || result.swappedVolume!==-result.volume) throw Error('Lean result checks failed.');
  if(!Array.isArray(result.vertices) || result.vertices.length!==8 || !result.vertices.every(triple)) throw Error('Invalid geometry from Lean.');
  // Check the exported vertex ordering and echoed inputs before accepting a mesh.
  // The renderer still uses the exported vertices; this is not a fallback result.
  const {a,b,c}=result, add=(u,v)=>u.map((n,i)=>n+v[i]);
  const expected=[[0,0,0],a,b,c,add(a,b),add(a,c),add(b,c),add(add(a,b),c)];
  if(result.vertices.some((vertex,i)=>vertex.some((n,j)=>n!==expected[i][j]))) throw Error('Lean geometry does not match this edit.');
  return result;
}
// A single active request; edits coalesce. A superseded answer never renders.
export class LeanQueue {
  constructor({transport, onResult, onStatus}) { Object.assign(this,{transport,onResult,onStatus}); this.next=0; this.waiting=null; this.running=false; }
  submit(vectors) {this.waiting={...clone(vectors),id:++this.next};this.onStatus('pending');void this.drain();}
  async drain() {
    if(this.running)return;this.running=true;
    while(this.waiting){const request=this.waiting;this.waiting=null;const start=performance.now();
      try{const result=validateResult(await this.transport(request),request);if(request.id===this.next){this.onResult(result,performance.now()-start);this.onStatus('live');}}
      catch(error){if(request.id===this.next)this.onStatus('error',error.message);}
    }this.running=false;
  }
}
