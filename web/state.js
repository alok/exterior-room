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
  for(const k of ['a','b','c']) if(!triple(result[k]) || JSON.stringify(result[k])!==JSON.stringify(request[k])) throw Error('Lean response does not match this edit.');
  for(const k of ['wedge','swappedWedge','selfWedge']) if(!triple(result[k])) throw Error('Invalid exact coefficients.');
  if(!Number.isSafeInteger(result.volume) || !Array.isArray(result.vertices) || result.vertices.length!==8 || !result.vertices.every(triple)) throw Error('Invalid geometry from Lean.');
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
