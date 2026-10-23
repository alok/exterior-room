// SPDX-License-Identifier: GPL-3.0-or-later
// Packed numerical renderer helpers; identity/classification come from Lean.
// UHP formulas/picking adapted from FareyVision 2cd549a45ddb6056cf3596404754d96ad9e7132c,
// Farey/WebXR/roots-pane.js (SHA256 cbbbb4f0415d9cc534f5c0f4fd7287e5279c50bfb56581a1243fabb97ee1e87b).
// The source attribution to Harriss, Stange and Trettel is preserved in mobius.js.
import {sourceRootVisible,catalogueOpacity} from './catalogue-display.js';
import {sourceRootOpacity} from './source-projection.js';
export function interiorIndices(lattice,{model='klein'}={}){
  const lower=model==='klein';
  const eligible=i=>(lattice.kind[i]===2||(lower&&lattice.kind[i]===3))&&sourceRootVisible(lattice,i);
  let count=0;for(let i=0;i<lattice.count;i++)if(eligible(i))count++;
  const indices=new Uint32Array(count);let next=0;
  for(let i=0;i<lattice.count;i++)if(eligible(i))indices[next++]=i;
  return indices;
}
export function fillRootPositions(xyz,indices,positions,{model='klein',delta}={}){
  const upper=model==='half-plane';
  for(let j=0;j<indices.length;j++){
    const i=indices[j],k=i*3,n=j*3,d=upper?xyz[k+1]-xyz[k+2]:xyz[k+1];
    positions[n]=xyz[k]/d;positions[n+1]=upper?Math.sqrt(-delta[i])/Math.abs(d):xyz[k+2]/d;positions[n+2]=0;
    // A singular Float chart has no drawable location; keep its accepted base
    // identity, and place the numerical vertex outside the clipped view.
    if(!Number.isFinite(positions[n])||!Number.isFinite(positions[n+1])){positions[n]=1e20;positions[n+1]=1e20;}
  }
  return positions;
}

export function rootSortWorkspace(length){
  return {keys:new Float32Array(length),other:new Uint32Array(length),counts:new Uint32Array(256)};
}
/** UHP source draws smaller stars first, including translucent faint stars.
 * Radius is proportional to 1/|Y′−Z′|. Stable four-pass radix ordering of that
 * positive Float32 denominator avoids a comparison sort and preserves base
 * order on ties. Indices address renderer vertices, never change identities. */
export function orderRootsByRadius(xyz,indices,order=new Uint32Array(indices.length),workspace=rootSortWorkspace(indices.length)){
  const n=indices.length,{keys,other,counts}=workspace;
  if(order.length!==n||keys.length!==n||other.length!==n||counts.length!==256)throw new RangeError('Root ordering workspace has the wrong size');
  const bits=new Uint32Array(keys.buffer,keys.byteOffset,n);
  for(let j=0;j<n;j++){const k=3*indices[j],d=Math.abs(xyz[k+1]-xyz[k+2]);keys[j]=Number.isFinite(d)?d:0;order[j]=j;}
  let input=order,output=other;
  for(let shift=0;shift<32;shift+=8){
    counts.fill(0);
    for(let j=0;j<n;j++)counts[(~bits[input[j]]>>>shift)&255]++;
    let offset=0;
    for(let b=0;b<256;b++){const count=counts[b];counts[b]=offset;offset+=count;}
    for(let j=0;j<n;j++){const value=input[j];output[counts[(~bits[value]>>>shift)&255]++]=value;}
    [input,output]=[output,input];
  }
  return order;
}

export function pickRoot(lattice,xyz,indices,scale,cx,cy,maxDistance=10,{model='klein',sigma=1,planeMask=null,light=false}={}){
  const upper=model==='half-plane';
  if(lattice.catalogue?.kind==='source'){
    // Source bn(): the packed root-body alpha gate is .05 (3D uses .06).
    // Its cursor score accounts for apparent radius rather than canonical's
    // half-pixel center tie. Neither body alpha nor picking depend on morph.
    const opacityOptions={planeMask,light};let best=-1,score=Infinity;
    for(let j=0;j<indices.length;j++){
      const i=indices[j];if(sourceRootOpacity(lattice,xyz,i,opacityOptions)<.05)continue;
      const k=3*i,y=xyz[k+1],denominator=upper?y-xyz[k+2]:y,inv=scale/denominator;
      const dx=cx+xyz[k]*inv,dy=cy-(upper?Math.sqrt(-lattice.delta[i])*Math.abs(inv):xyz[k+2]*inv);
      const radius=Math.fround(upper?.06*sigma*Math.abs(inv):.06*sigma*scale*Math.pow(-lattice.delta[i],.25)/Math.pow(Math.abs(y),1.5));
      const distance=Math.hypot(dx,dy);if(!Number.isFinite(radius)||distance>Math.max(7,radius+4))continue;
      const candidate=distance-.8*Math.min(radius,12);
      if(candidate<score){score=candidate;best=i;}
    }
    return best;
  }
  let nearest=Infinity;
  for(let j=0;j<indices.length;j++){
    const i=indices[j];if(!sourceRootVisible(lattice,i)||catalogueOpacity(lattice,xyz,i)<=0)continue;
    const k=3*i,denominator=upper?xyz[k+1]-xyz[k+2]:xyz[k+1],inv=scale/denominator;
    const dx=cx+xyz[k]*inv,dy=cy-(upper?Math.sqrt(-lattice.delta[i])*Math.abs(inv):xyz[k+2]*inv),d=dx*dx+dy*dy;
    const hit=upper?Math.max(maxDistance,.06*sigma*Math.abs(inv)):maxDistance;
    if(d<=hit*hit)nearest=Math.min(nearest,d);
  }
  if(nearest===Infinity)return -1;
  // Canonical roots picking: centers within half a pixel are tied, and the
  // largest visible star wins. In this Klein chart its unclamped apparent
  // radius is proportional to |Δ|^.25/|Y|^1.5, so primitive forms beat multiples.
  // Coincident negative partners have the same radius; prefer the upper one.
  const limit=(Math.sqrt(nearest)+.5)**2;let best=-1,largest=-Infinity;
  for(let j=0;j<indices.length;j++){
    const i=indices[j];if(!sourceRootVisible(lattice,i)||catalogueOpacity(lattice,xyz,i)<=0)continue;
    const k=3*i,denominator=upper?xyz[k+1]-xyz[k+2]:xyz[k+1],inv=scale/denominator;
    const dx=cx+xyz[k]*inv,dy=cy-(upper?Math.sqrt(-lattice.delta[i])*Math.abs(inv):xyz[k+2]*inv);
    const radius=upper?.06*sigma*Math.abs(inv):Math.abs(lattice.delta[i])**.25/Math.abs(xyz[k+1])**1.5;
    if(!Number.isFinite(radius))continue;
    const hit=upper?Math.max(maxDistance,radius):maxDistance;
    if(!(dx*dx+dy*dy<=Math.min(limit,hit*hit)))continue;
    if(radius>largest+1e-12||(Math.abs(radius-largest)<=1e-12&&lattice.kind[i]===2&&lattice.kind[best]!==2)){best=i;largest=radius;}
  }
  return best;
}
