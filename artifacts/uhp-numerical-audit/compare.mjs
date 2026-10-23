import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {interiorIndices,fillRootPositions} from '../../web/polynomial/klein-data.js';
import {transformPackedPositions,chartTransform,matrixFromIntegers} from '../../web/polynomial/mobius-render.js';

const repo=process.argv[2];
if(!repo)throw new Error('Usage: node artifacts/uhp-numerical-audit/compare.mjs /path/to/FareyVision');
const pin='2cd549a45ddb6056cf3596404754d96ad9e7132c';
const hash=s=>createHash('sha256').update(s).digest('hex');
const blobs=Object.fromEntries(['mobius.js','roots-pane.js','lattice.js'].map(name=>[name,execFileSync('git',['show',`${pin}:Farey/WebXR/${name}`],{cwd:repo,encoding:'utf8'})]));
assert.equal(hash(blobs['mobius.js']),'193a0df167da6ab54f9c496ef736df15326fc5db67dcea0087cee760577e32de');
assert.equal(hash(blobs['roots-pane.js']),'cbbbb4f0415d9cc534f5c0f4fd7287e5279c50bfb56581a1243fabb97ee1e87b');
const dataURL=s=>'data:text/javascript;base64,'+Buffer.from(s).toString('base64');
// Only the import URL is rewritten. The pinned method under comparison is
// executed unchanged, without constructing a canvas or opening a browser.
const {RootsPane}=await import(dataURL(blobs['roots-pane.js'].replace("'./mobius.js'",JSON.stringify(dataURL(blobs['mobius.js'])))));
const {enumerateLattice}=await import(dataURL(blobs['lattice.js']));
const source=enumerateLattice(6);
const delta=Int32Array.from({length:source.count},(_,i)=>{const k=i*3,a=source.abc[k],b=source.abc[k+1],c=source.abc[k+2];return b*b-4*a*c;});
// Reference-only fixture adaptation; production classification comes from Lean.
const lattice={...source,delta,kind:Uint8Array.from({length:source.count},(_,i)=>delta[i]<0?(source.abc[3*i]>0?2:3):delta[i]===0?0:1)};
const indices=interiorIndices(lattice,{model:'half-plane'}),matrix=[3,1,1,2],g=matrixFromIntegers(matrix);
const xyz=transformPackedPositions(lattice.xyz,g),positions=fillRootPositions(xyz,indices,new Float32Array(indices.length*3),{model:'half-plane',delta});
const rect={left:0,top:0,width:600,height:400},chart=chartTransform(rect);
const view={cx:0,cy:(rect.height/2-28)/(rect.width/2.4),scale:rect.width/2.4};
const receiver={data:{abc:lattice.abc,count:lattice.count,g,sigma:1},ensureView:()=>view,size:()=>({w:rect.width,h:rect.height})};
const canonical=RootsPane.prototype.computeStars.call(receiver);
let maxPixelError=0;
for(let k=0;k<canonical.index.length;k++){
  const j=indices.indexOf(canonical.index[k]);assert.notEqual(j,-1);
  maxPixelError=Math.max(maxPixelError,Math.abs(chart.cx+positions[3*j]*chart.scale-canonical.x[k]),Math.abs(chart.cy-positions[3*j+1]*chart.scale-canonical.y[k]));
}
assert.equal(lattice.count,480);assert.equal(indices.length,55);assert.equal(canonical.index.length,32);
assert.ok(maxPixelError<.001,`Pixel error ${maxPixelError} exceeds .001px numerical tolerance`);
const implementationPaths=['web/polynomial/klein-data.js','web/polynomial/mobius-render.js','web/polynomial/mobius.js'];
console.log(JSON.stringify({
  status:'passed',scope:'Numerical differential against actual pinned computeStars; no GPU, UI, visual or Lean-proof assertion.',
  sourceCommit:pin,sourcePathPrefix:'Farey/WebXR/',sourceSha256:Object.fromEntries(Object.entries(blobs).map(([p,s])=>[p,hash(s)])),
  implementationSha256:Object.fromEntries(implementationPaths.map(p=>[p,hash(readFileSync(new URL('../../'+p,import.meta.url)))])),
  scriptSha256:hash(readFileSync(new URL(import.meta.url))),runtime:process.version,platform:`${process.platform}/${process.arch}`,
  fixture:{radius:6,matrix,denominator:5,viewport:rect,sigma:1,model:'half-plane'},
  allSignedPoints:lattice.count,upperVertices:indices.length,canonicalVisible:canonical.index.length,compared:canonical.index.length,
  maxPixelError,tolerancePixels:.001
},null,2));
