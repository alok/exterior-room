// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from FareyVision ca809d2 by Alok Singh with OpenAI Codex, 2026-10-23.
// Renderer adapters for accepted Lean data. Floating projection/root conversion is not a proof.
import {recordFor,knownPolynomial} from './lean-client.js';
export const height=4;
export const examples=[[1,-1,2],[2,-2,4],[2,1,1],[1,0,1],[3,2,2]];
export const discriminant=p=>recordFor(p).delta;
export const vector=p=>[...recordFor(p).xyz];
export const kind=p=>recordFor(p).kind;
export const divisor=p=>recordFor(p).divisor;
export function positiveRepresentative(p){const r=recordFor(p);if(r.kind!=='upper'&&r.kind!=='lower')return null;return r.positiveRepresentative?[...r.positiveRepresentative]:(r.kind==='lower'?p.map(x=>-x):[...p]);}
export function project(p,h=height){
  const r=recordFor(p);if(r.kind!=='upper'||!Number.isFinite(h)||h<=0)return null;
  if(r.projection&&h===4)return r.projection.map(([n,d])=>n/d);
  return r.xyz.map(x=>x*h/r.xyz[1]);
}
export function upperRoot(p){const r=recordFor(p);if(r.kind!=='upper')return null;const q=r.root;return q?[q.real[0]/q.real[1],Math.sqrt(q.imaginary.radicand)/q.imaginary.denominator]:[-p[1]/(2*p[0]),Math.sqrt(-r.delta)/(2*p[0])];}
export const projectedRepresentative=(p,h=height)=>{const q=positiveRepresentative(p);return q?project(q,h):null;};
export function polynomial(p){
  const exact=knownPolynomial(p);if(exact!==null)return exact;
  // Immediate hover text formats Lean-exported integer coefficients; selected labels use Lean's string.
  const {point}=recordFor(p);
  const terms=[[point[0],'x²'],[point[1],'x'],[point[2],'']].filter(([n])=>n!==0);
  return terms.length?terms.map(([n,power],i)=>(n<0?'−':i?'+':'')+(power&&Math.abs(n)===1?'':Math.abs(n))+power).join(''):'0';
}
