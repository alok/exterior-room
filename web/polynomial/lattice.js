// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from FareyVision ca809d2 by Alok Singh with OpenAI Codex, 2026-10-23.
// Enumeration is accepted Lean data; these adapters only address it or convert it for drawing.
import {cloud,indexOfPoint,recordFor} from './lean-client.js';
export const latticeRadii=[4,6,8,10,12,16,24,48,96];
export const maxLatticeRadius=96;
export function enumerateLattice(radius,upperOnly=false){const l=cloud();if(l.catalogue||l.radius!==radius||l.upperOnly!==upperOnly)throw Error('Wait for the matching Lean ball cloud.');return l;}
export function acceptedLattice(){return cloud();}
export const tripleAt=(l,i)=>Array.from(l.abc.subarray(3*i,3*i+3));
export const indexOf=(l,p)=>indexOfPoint(p,l);
// Display membership, including the accepted cloud's filter. This does not compute
// arbitrary radius membership for a point absent from the Lean response.
export const inBall=(p,r)=>!cloud().catalogue&&cloud().radius===r&&indexOfPoint(p)>=0;
export const inCatalogue=(p,l=cloud())=>!!l.catalogue&&indexOfPoint(p,l)>=0;
export const isUpper=p=>recordFor(p).kind==='upper';
export const ballCount=r=>!cloud().catalogue&&cloud().radius===r&&!cloud().upperOnly?cloud().count:null;

// Packed renderer-only radial projection. Both signs yield the same image because
// their accepted XYZ numerator and Y denominator change sign together. Keep every
// interior source point, including coincident images of multiples/sign partners.
// Two linear passes allocate exactly the image buffer; no point lookup or per-point
// triple/record allocation is needed for a dense cloud.
export function projectedPositions(lattice,h=4,{visible=null,primitiveOnly=false}={}){
  if(!Number.isFinite(h)||h<=0)throw RangeError('Projection height must be positive and finite.');
  if(typeof primitiveOnly!=='boolean')throw TypeError('Projection primitive filter must be boolean.');
  if(visible!==null&&(!ArrayBuffer.isView(visible)&&!Array.isArray(visible)||visible.length!==lattice.count))throw RangeError('Projection visibility mask must match the accepted cloud.');
  const include=i=>(lattice.kind[i]===2||(!primitiveOnly&&lattice.kind[i]===3))&&(!primitiveOnly||lattice.divisor[i]===1)&&(!visible||visible[i]>0);
  let count=0;
  for(let i=0;i<lattice.count;i++)if(include(i))count++;
  const images=new Float32Array(3*count);let next=0;
  for(let i=0;i<lattice.count;i++){
    if(!include(i))continue;
    const at=3*i,y=lattice.xyz[at+1];
    if(y===0)throw Error('An accepted interior point has zero projection denominator.');
    images[next++]=lattice.xyz[at]*h/y;
    images[next++]=h;
    images[next++]=lattice.xyz[at+2]*h/y;
  }
  return images;
}
