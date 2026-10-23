// SPDX-License-Identifier: GPL-3.0-or-later
// Renderer-side refresh policy only. Lean enumerates every accepted catalogue.
// Source cache displacement is measured between inverse images of i. Numeric
// threshold decisions are not kernel proofs and never determine membership.
export function inverseBasePoint(matrix) {
  if(!Array.isArray(matrix)||matrix.length!==4||!matrix.every(Number.isFinite))throw new TypeError('Expected a finite action matrix');
  const [p,q,r,s]=matrix,d=p*s-q*r,n=p*p+r*r;
  if(!(d>0)||!(n>0))throw new RangeError('Expected positive determinant');
  return [(-(p*q+r*s)/n)||0,d/n];
}
export function catalogueDisplacement(first,second) {
  const [x,y]=inverseBasePoint(first),[u,v]=inverseBasePoint(second);
  return 2*Math.asinh(Math.hypot(x-u,y-v)/(2*Math.sqrt(y*v)));
}
export function needsSourceCatalogue(catalogue,depth,matrix,{whole=true,dust=false,force=false}={}) {
  return force||catalogue?.kind!=='source'||catalogue.depth!==depth||catalogue.whole!==whole||catalogue.dust!==dust
    ||catalogueDisplacement(catalogue.matrix,matrix)>=.16;
}
