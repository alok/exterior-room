// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from FareyVision ca809d2 by Alok Singh with OpenAI Codex, 2026-10-23.
// Exact planes/membership come from Lean. The copied functions below only tessellate the display.
import {cachedPlane,memberIndices,indexOfPoint,cloud} from "./lean-client.js";
export const pairPlane=(a,b)=>cachedPlane(a,b);
export const planeFromNormal=n=>cachedPlane(n);
// The Lean members response is an interior necklace, not arbitrary plane
// membership. Keep the legacy helper only for the domain that response answers.
export function inPairPlane(n,p){
  const lattice=cloud(),i=indexOfPoint(p,lattice);
  if(i<0||(lattice.kind[i]!==2&&lattice.kind[i]!==3))throw Error('Plane membership requires an accepted interior cloud point.');
  return memberIndices(n).has(i);
}
export function coneDirections(plane) {
  return plane.endpoints.map(({kind,value})=>{
    if(kind==='infinity'||value===Infinity)return [0,1,1];
    if(!Number.isFinite(value))throw Error('A finite Lean endpoint needs its numeric rendering value.');
    const angle=2*Math.atan(value);return [Math.sin(angle),1,-Math.cos(angle)];
  });
}
// Finite display patch, clipped by |Y| ≤ radius and X²+Z² ≤ radius².
export function planeSection(normal,radius,segments=64) {
  const [A,B,C]=normal, [x,y,z]=[-B,-A-C,C-A];
  const horizontal=Math.hypot(x,z),length=Math.hypot(x,y,z);
  if(!Number.isFinite(horizontal)||horizontal===0||!Number.isFinite(length)||!Number.isFinite(radius)||radius<=0||!Number.isInteger(segments)||segments<3)throw RangeError('A plane patch needs a valid normal, positive radius, and at least three segments.');
  const u=[-z/horizontal,0,x/horizontal];
  const v=[-x*y/(horizontal*length),horizontal/length,-z*y/(horizontal*length)];
  return Array.from({length:segments+1},(_,i)=>{
    const angle=i/segments*2*Math.PI,d=u.map((q,j)=>q*Math.cos(angle)+v[j]*Math.sin(angle));
    const scale=radius/Math.max(Math.abs(d[1]),Math.hypot(d[0],d[2]));
    return d.map(q=>q*scale);
  });
}
