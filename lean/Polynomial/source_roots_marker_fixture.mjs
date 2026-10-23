// SPDX-License-Identifier: GPL-3.0-or-later
// Offline audit: execute pinned source Jt/Xt with inert renderer adapters.
// Specification: preserve signed base identities; record raw CPU point and ring
// inputs in Klein/UHP charts, including hidden, nonprimitive and lower selections.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import fs from 'node:fs';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';

const sourcePath=process.argv[2]??'/tmp/exteriorroom-source-recrop-bundle.js';
const output=fileURLToPath(new URL('./fixtures/source-roots-marker.json',import.meta.url));
const bytes=fs.readFileSync(sourcePath),source=bytes.toString('utf8');
const sha=createHash('sha256').update(bytes).digest('hex');
assert.equal(sha,'f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b');
const extractedRoutines=[];
function routine(prefix){
  const start=source.indexOf(prefix);assert.ok(start>=0,prefix);
  let end=source.indexOf('{',start)+1,depth=1;
  while(depth&&end<source.length){depth+=(source[end]==='{')-(source[end]==='}');end++;}
  assert.equal(depth,0,prefix);
  const text=source.slice(start,end);
  extractedRoutines.push({prefix,characterOffset:start,sha256:createHash('sha256').update(text).digest('hex')});
  return text;
}
const code=[...['j','ae','we','Te','tt','nt','rt','at','ot','lt','ut','Ue','me','he','qt','Jt','Xt','Yt','Nt','Rt','zt','Bt','bn'].map(name=>routine(`function ${name}(`)),
  routine('function ht(){if(!l)')].join('\n');
const probes=[
  {name:'unit-selected',abc:[1,0,1]},
  {name:'paired',abc:[1,1,1]},
  {name:'nonprimitive-selected',abc:[2,0,2]},
  {name:'lower-selected',abc:[-1,0,-1]},
  {name:'lower-nonprimitive-selected',abc:[-2,0,-2]},
  {name:'off-plane-upper',abc:[1,-1,2]},
  {name:'fade-band',abc:[1,0,14]},
  {name:'crop-boundary',abc:[1,0,15]},
  {name:'absent-crop-selected',abc:[13,20,34]},
  {name:'null-selected',abc:[1,2,1]},
  {name:'exterior-selected',abc:[1,0,-1]},
];
function layer(){return {calls:[],ensure(){},set(index,...args){this.calls[index]=args;},commit(count){this.count=count;},uniforms(){},points:{visible:false}};}
const cases=[];
for(const matrix of [[1,0,0,1],[3,1,1,2]])for(const model of [0,2]){
  const determinant=matrix[0]*matrix[3]-matrix[1]*matrix[2],g=matrix.map(x=>x/Math.sqrt(determinant));
  const stars=layer(),marks=layer();
  const U={width:800,height:600,view:{cx:0,cy:0,scale:100},stars,marks,ghost:layer(),
    toScreen(x,y){return [this.width/2+(x-this.view.cx)*this.view.scale,this.height/2-(y-this.view.cy)*this.view.scale];}};
  const context=vm.createContext({U,s:g,y:model,n:{R:16,sigma:1,shell:null,normal:[1,0,-1],sel:null,sel2:null},
    a:{name:'dark',select:0,inkRgb:[0,0,0]},i:false,u:null,h:0,g:'',I:-1,
    vt:.06,Kt:new Float64Array(3),qe:{layer:new Int32Array(0)},B:{},G:[0,0,0],
    // Palette, labels, notification and identity ghost rendering are excluded.
    Pt(){},x:()=>[0,0,0],At:()=>0,nn(){},Dn(){},be:()=>({offset:0})});
  vm.runInContext(code+`
    var it=600000,st=1.2,ct=1.2;
    var l=lt(s,n.R,Math.round(.4*n.R),true,0),d=new Float64Array(3*l.n),
      f=new Float32Array(l.n),m=new Float32Array(l.n),v=new Uint8Array(l.n),c;
    for(let k=0;k<l.n;k++)v[k]=+(-2*l.abc[3*k+2]+2*l.abc[3*k]===0);
    ht();Jt();`,context);
  const index=new Map();for(let k=0;k<context.l.n;k++)index.set(Array.from(context.l.abc.slice(3*k,3*k+3)).join(','),k);
  const bodyIndex=new Map();for(let k=0;k<context.qe.n;k++)bodyIndex.set(context.qe.layer[k],k);
  for(const probe of probes){
    const abc=probe.abc,idx=index.get(abc.join(',')),bi=idx===undefined?undefined:bodyIndex.get(idx);
    const raw=bi===undefined?null:stars.calls[bi];
    context.n.sel=abc.map(BigInt);context.Jt();
    const marker=context.Xt(abc.map(BigInt)),ring=marks.count?marks.calls[0]:null;
    const transformed=Array.from(context.ae(context.j(g),...abc));
    let chart=null;
    if(marker){
      const t=transformed[0]+transformed[2],a=new Float64Array(3);
      context.me(-transformed[1]/t,(transformed[2]-transformed[0])/t,model,a);
      chart={sourceXY:[a[0],a[1]],applicationXY:[a[0],a[1]-(model===0?1:0)],radiusFactor:a[2],he:context.he(model)};
    }
    const divisor=context.Te(...abc),K=4*abc[0]*abc[2]-abc[1]*abc[1];
    cases.push({name:probe.name,matrix,determinant,model,abc,baseK:K,divisor,
      basePrimitive:divisor===1,catalogued:idx!==undefined,sourceKind:idx===undefined?null:context.l.kind[idx],
      planeMember:idx===undefined?(-2*abc[2]+2*abc[0]===0):!!context.v[idx],transformedABC:transformed,
      cropFadeFloat32:idx===undefined?null:context.f[idx],chart,
      body:raw?{screenXY:[raw[0],-raw[1]],radius:raw[3],alpha:raw[7],packedFloat32:Array.from(new Float32Array([...raw.slice(0,4),raw[7]]))}:null,
      marker:marker?{screenXY:[marker.x,marker.y],rawRadius:marker.r,ringRadius:ring[3],alpha:ring[7],packedFloat32:Array.from(new Float32Array([...ring.slice(0,4),ring[7]]))}:null});
  }
}
for(const c of cases){
  if(c.marker){assert.equal(c.marker.ringRadius,Math.max(5,c.marker.rawRadius+4));assert.equal(c.marker.alpha,1);}
  if(!c.basePrimitive||c.baseK<=0||c.abc[0]<0)assert.equal(c.body,null);
  if(c.body){const focus=c.planeMember?1:.26;assert.ok(Math.abs(c.body.alpha-c.cropFadeFloat32*focus)<1e-14);}
}
// A handful of actual Jt bodies, restricted to named candidate subsets. bn is
// evaluated on their real Float32 arrays in source order, without invented radii.
function pickerCase(name,R,sigma,points,cursorFor){
  const stars=layer(),U={width:800,height:600,view:{cx:0,cy:0,scale:100},stars,marks:layer(),ghost:layer(),
    toScreen(x,y){return[400+x*100,300-y*100];}};
  const context=vm.createContext({U,s:[1,0,0,1],y:0,n:{R,sigma,shell:null,normal:[1,0,-1],sel:null,sel2:null},
    a:{name:'dark',select:0,inkRgb:[0,0,0]},i:false,u:null,h:0,g:'',I:-1,
    vt:.06,Kt:new Float64Array(3),qe:{layer:new Int32Array(0)},B:{},G:[0,0,0],
    Pt(){},x:()=>[0,0,0],At:()=>0,nn(){},Dn(){},be:()=>({offset:0})});
  vm.runInContext(code+`
    var it=600000,st=1.2,ct=1.2;
    var l=lt(s,n.R,0,true,0),d=new Float64Array(3*l.n),
      f=new Float32Array(l.n),m=new Float32Array(l.n),v=new Uint8Array(l.n),c;
    for(let k=0;k<l.n;k++)v[k]=+(-2*l.abc[3*k+2]+2*l.abc[3*k]===0);
    ht();Jt();`,context);
  const keys=new Set(points.map(p=>p.join(','))),candidates=[];
  for(let k=0;k<context.qe.n;k++){
    const idx=context.qe.layer[k],abc=Array.from(context.l.abc.slice(3*idx,3*idx+3));
    if(!keys.has(abc.join(',')))continue;
    const raw=stars.calls[k],packed=Array.from(new Float32Array([...raw.slice(0,4),raw[7]]));
    candidates.push({abc,baseK:context.l.k[idx],planeMember:!!context.v[idx],
      cropFadeFloat32:context.f[idx],screenXY:[packed[0],-packed[1]],radius:packed[3],alpha:packed[4]});
  }
  assert.equal(candidates.length,points.length);
  const pos=new Float32Array(3*candidates.length),rad=new Float32Array(candidates.length),col=new Float32Array(4*candidates.length);
  candidates.forEach((p,k)=>{pos.set([p.screenXY[0],-p.screenXY[1],0],3*k);rad[k]=p.radius;col[4*k+3]=p.alpha;});
  context.U.stars={pos,rad,col};context.qe={n:candidates.length,layer:Int32Array.from(candidates,(_,i)=>i)};
  const cursor=cursorFor(candidates),expectedIndex=context.bn(...cursor);
  return {name,settings:{R,sigma,model:0,normal:[1,0,-1],theme:'dark',matrix:[1,0,0,1]},
    candidates,cursor,expectedIndex,expectedABC:expectedIndex<0?null:candidates[expectedIndex].abc};
}
const pickerCases=[
  pickerCase('farther-larger-beats-centred-small',24,10/3,[[1,0,1],[10,1,10]],p=>p[1].screenXY),
  pickerCase('equal-score-keeps-first-source-candidate',24,10/3,[[10,-1,10],[10,1,10]],()=>[400,200]),
  pickerCase('focus-crop-alpha-above-gate',25,1,[[1,0,23]],p=>p[0].screenXY),
  pickerCase('focus-crop-alpha-below-gate',26,1,[[1,0,24]],p=>p[0].screenXY),
  pickerCase('seven-pixel-hit-boundary-inclusive',16,1,[[1,0,1]],()=>[407,200]),
  pickerCase('past-seven-pixel-hit-boundary',16,1,[[1,0,1]],()=>[407.0000001,200]),
];
assert.deepEqual(pickerCases.map(c=>c.expectedIndex),[0,0,0,-1,0,-1]);
const fixture={schema:'source-roots-marker-audit-v1',
  sourceURL:'https://katestange.net/_astro/index.astro_astro_type_script_index_0_lang.kfTP0QEk.js',sourceSHA256:sha,
  scope:'Direct pinned-source numerical Jt/Xt evaluation. Inert adapters omit RGB, labels, ghost layer and GPU attenuation. Not UI/headset execution or Lean proof.',
  viewport:{width:800,height:600,scale:100,cx:0,cy:0},settings:{R:16,sigma:1,theme:'dark',normal:[1,0,-1],whole:true,ordinaryViewer:true},
  sourceKindCodes:{0:'upper',1:'null',2:'exterior',3:'lower'},
  coordinateNote:'source chart Klein centre=(0,1); application Klein centre=(0,0). UHP unchanged. Packed Float32 is [screenX,-screenY,0,radius,alpha].',
  pickerNote:'Each picker case restricts actual Jt output to the listed candidates, preserving source order and Float32 packing. Expected index is from direct source bn. No other catalogue bodies participate.',
  extractedRoutines,cases,pickerCases};
fs.writeFileSync(output,JSON.stringify(fixture,null,2)+'\n');
console.log(JSON.stringify({output,cases:cases.length,pickerCases:pickerCases.length,sourceSHA256:sha}));
