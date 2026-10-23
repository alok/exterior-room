// SPDX-License-Identifier: GPL-3.0-or-later
// Renderer-only source-catalogue clipping. Accepted signed integer identities,
// discriminants and divisors remain supplied by Lean and are never changed here.
// The matching CPU visibility rule is for picking, not a mathematical certificate.
// Audited source bundle SHA256:
// f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b.
// Its ut() supplies the .86..1 smoothstep; roots skip nonprimitive forms.
// The source authors' attribution remains in mobius.js and the repository notices.
export const catalogueFadeStart = .86;

export function catalogueUniform(lattice) {
  const c=lattice?.catalogue;
  if(c?.kind!=='source')return [1,1,0];
  if(!Number.isFinite(c.depth)||c.depth<=0||!Number.isFinite(c.otherRadius)||c.otherRadius<0)throw new RangeError('Source catalogue needs positive depth and nonnegative otherRadius');
  return [c.depth,c.otherRadius,1];
}

/** Complement of GLSL smoothstep(.86*cutoff,cutoff,distance).
 * An absent/zero other radius hides that category, including its origin. */
export function catalogueFade(distance,cutoff) {
  if(!(cutoff>0)||!Number.isFinite(distance))return 0;
  const t=Math.min(1,Math.max(0,(distance-catalogueFadeStart*cutoff)/((1-catalogueFadeStart)*cutoff)));
  return 1-t*t*(3-2*t);
}

/** Upper forms fade by transformed Y=a′+c′; every other signed form uses
 * transformed Euclidean display radius. No base identity is recategorized. */
export function catalogueOpacity(lattice,xyz,index) {
  const c=lattice.catalogue;if(c?.kind!=='source')return 1;
  const k=3*index,x=xyz[k],y=xyz[k+1],z=xyz[k+2];
  return catalogueFade(lattice.kind[index]===2?y:Math.hypot(x,y,z),lattice.kind[index]===2?c.depth:c.otherRadius);
}

/** Base-order picking mask. Recompute only when catalogue or displayed geometry
 * changes; do not compact/relabel the accepted cloud. Reuses an optional output. */
export function catalogueVisibility(lattice,xyz,out=new Uint8Array(lattice.count)) {
  if(out.length!==lattice.count||xyz.length<3*lattice.count)throw new RangeError('Catalogue visibility buffers have the wrong size');
  const [depth,otherRadius,enabled]=catalogueUniform(lattice);
  if(!enabled){out.fill(1);return out;}
  for(let i=0;i<lattice.count;i++){
    const k=3*i,d=lattice.kind[i]===2?xyz[k+1]:Math.hypot(xyz[k],xyz[k+1],xyz[k+2]);
    out[i]=catalogueFade(d,lattice.kind[i]===2?depth:otherRadius)>0?1:0;
  }
  return out;
}

/** The source roots catalogue contains primitive upper forms only. The 3D
 * cloud still contains every accepted signed identity, including multiples. */
export function sourceRootVisible(lattice,index) {
  return lattice.catalogue?.kind!=='source'||(lattice.kind[index]===2&&lattice.divisor[index]===1);
}

/** Audited source world-projection factor: its nonprimitive upper branch uses
 * `ie *= 1-c`, where c is continuous projection progress. Primitive upper and
 * all other categories retain their opacity. This helper is intentionally NOT
 * wired to the demo's radial-overlay toggle: that toggle does not move world
 * stars along their rays and has no source-style projection transition. */
export function sourceProjectionOpacity(lattice,index,progress) {
  if(!Number.isFinite(progress))throw new RangeError('Projection progress must be finite');
  if(lattice.catalogue?.kind!=='source'||lattice.kind[index]!==2||lattice.divisor[index]===1)return 1;
  return 1-Math.min(1,Math.max(0,progress));
}

// Shared with the production shaders: same cutoff metrics and smoothstep edges.
// Call only with transformed display coordinates and accepted base classification.
export const catalogueFadeGLSL=`
float catalogueOpacity(vec3 xyz,float kind,vec3 catalogue){
  if(catalogue.z<.5)return 1.0;
  bool upper=kind>1.5&&kind<2.5;
  float cutoff=upper?catalogue.x:catalogue.y;
  if(cutoff<=0.0)return 0.0;
  float distance=upper?xyz.y:length(xyz);
  return 1.0-smoothstep(.86*cutoff,cutoff,distance);
}`;
