import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {performance} from 'node:perf_hooks';
import {interiorIndices,fillRootPositions,orderRootsByRadius,rootSortWorkspace} from '../../web/polynomial/klein-data.js';
import {transformPackedPositions,matrixFromIntegers} from '../../web/polynomial/mobius-render.js';
const repo=process.argv[2];if(!repo)throw new Error('Pass the read-only canonical checkout path');
const pin='2cd549a45ddb6056cf3596404754d96ad9e7132c';
const code=execFileSync('git',['show',`${pin}:Farey/WebXR/lattice.js`],{cwd:repo,encoding:'utf8'});
const {enumerateLattice}=await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
const source=enumerateLattice(96),delta=new Int32Array(source.count),kind=new Uint8Array(source.count);
for(let i=0;i<source.count;i++){const k=3*i,a=source.abc[k],b=source.abc[k+1],c=source.abc[k+2];delta[i]=b*b-4*a*c;kind[i]=delta[i]<0?(a>0?2:3):delta[i]===0?0:1;}
const lattice={...source,delta,kind},indices=interiorIndices(lattice,{model:'half-plane'});
assert.equal(source.count,1852484);assert.equal(indices.length,270202);
const order=new Uint32Array(indices.length),workspace=rootSortWorkspace(indices.length),positions=new Float32Array(indices.length*3);
const samples=[];
for(const matrix of [[1,0,0,1],[3,1,1,2],[1,1,0,1],[1,-1,0,1],[10741,903,912,9387]]){
  const xyz=transformPackedPositions(source.xyz,matrixFromIntegers(matrix));
  const start=performance.now();fillRootPositions(xyz,indices,positions,{model:'half-plane',delta});const filled=performance.now();
  orderRootsByRadius(xyz,indices,order,workspace);const sorted=performance.now();
  const seen=new Uint8Array(indices.length);
  for(let j=0;j<order.length;j++){
    assert.equal(seen[order[j]],0);seen[order[j]]=1;
    if(j){const previous=order[j-1],current=order[j];assert.ok(workspace.keys[previous]>=workspace.keys[current]);if(workspace.keys[previous]===workspace.keys[current])assert.ok(previous<current);}
  }
  samples.push({matrix,fillPositionsMs:filled-start,stableOrderingMs:sorted-filled,combinedMs:sorted-start,permutationAndStableOrderVerified:true});
}
const sha=p=>createHash('sha256').update(readFileSync(new URL(p,import.meta.url))).digest('hex');
console.log(JSON.stringify({status:'passed',scope:'Bounded Node CPU stages, five R96 action states. Excludes cloud generation, whole-cloud transformation, attribute copy, GPU upload, GPU frame, browser input and display latency; not an FPS claim.',
  sourceCommit:pin,runtime:process.version,platform:`${process.platform}/${process.arch}`,allSignedPoints:source.count,upperVertices:indices.length,
  sourceLatticeSha256:createHash('sha256').update(code).digest('hex'),
  implementationSha256:{'web/polynomial/klein-data.js':sha('../../web/polynomial/klein-data.js'),'web/polynomial/mobius-render.js':sha('../../web/polynomial/mobius-render.js')},
  scriptSha256:sha('./benchmark-order.mjs'),orderingPasses:4,orderingStorageBytes:order.byteLength+workspace.keys.byteLength+workspace.other.byteLength+workspace.counts.byteLength,
  samples,maxOrderingMs:Math.max(...samples.map(s=>s.stableOrderingMs)),maxCombinedMs:Math.max(...samples.map(s=>s.combinedMs))},null,2));
