// SPDX-License-Identifier: GPL-3.0-or-later
// Offline source audit only. This script is not imported by the application.
// Evaluate the pinned source's numerical routines with inert renderer adapters;
// no DOM, network, WebGL, browser session, app state, or Lean service is used.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import fs from 'node:fs';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';

const sourcePath=process.argv[2]??'/tmp/exteriorroom-source-recrop-bundle.js';
const output=fileURLToPath(new URL('./fixtures/source-projection-morph.json',import.meta.url));
const bytes=fs.readFileSync(sourcePath),source=bytes.toString('utf8');
const sha=createHash('sha256').update(bytes).digest('hex');
assert.equal(sha,'f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b');
const extracted=[];
function routine(prefix){
  const start=source.indexOf(prefix);assert.ok(start>=0,prefix);
  const brace=source.indexOf('{',start);let end=brace+1,depth=1;
  while(depth&&end<source.length){depth+=(source[end]==='{')-(source[end]==='}');end++;}
  assert.equal(depth,0,prefix);
  const text=source.slice(start,end);
  extracted.push({prefix,characterOffset:start,sha256:createHash('sha256').update(text).digest('hex')});
  return text;
}
const pure=vm.createContext({});
vm.runInContext(['j','ae','we','Te','tt','nt','rt','at','ot','lt','ut','_e'].map(n=>routine(`function ${n}(`)).join('\n')+
  '\nvar it=600000,st=1.2,ct=1.2;',pure);
const renderCode=[routine('function an(){'),routine('function ht(){if(!l)'),
  routine('function W(){if(!l'),routine('function Nt('),routine('function Rt('),
  routine('function zt('),routine('function Bt('),routine('function $t('),
  ...['j','ae','Ae','Fe','Ie','ut','Yt'].map(n=>routine(`function ${n}(`))].join('\n');
const probes=[
  {name:'unit-selected',abc:[1,0,1]}, {name:'paired',abc:[1,1,1]},
  {name:'nonprimitive-upper',abc:[2,0,2]}, {name:'off-plane-upper',abc:[1,-1,2]},
  {name:'lower-on-plane',abc:[-1,0,-1]}, {name:'lower-off-plane',abc:[-1,1,-2]},
  {name:'null-on-plane',abc:[1,2,1]}, {name:'null-off-plane',abc:[0,0,1]},
  {name:'exterior-on-plane',abc:[0,1,0]}, {name:'exterior-off-plane',abc:[1,3,2]},
];
const profiles=[
  {name:'paired-whole-overview-dark',R:16,whole:true,dust:false,screen:true,eye:0,theme:'dark',normal:[1,0,-1]},
  {name:'paired-whole-mid-eye-dark',R:16,whole:true,dust:false,screen:true,eye:.5,theme:'dark',normal:[1,0,-1]},
  {name:'paired-whole-origin-dark',R:16,whole:true,dust:false,screen:true,eye:1,theme:'dark',normal:[1,0,-1]},
  {name:'unfocused-upper-only-light',R:16,whole:false,dust:false,screen:true,eye:0,theme:'light',normal:null},
  {name:'unfocused-dust-overview-dark',R:16,whole:false,dust:true,screen:false,eye:0,theme:'dark',normal:null},
  {name:'nonprimitive-selection',R:16,whole:true,dust:false,screen:true,eye:0,theme:'dark',normal:[1,0,-1],selected:[2,0,2]},
  {name:'lower-selection',R:16,whole:true,dust:false,screen:true,eye:0,theme:'dark',normal:[1,0,-1],selected:[-1,0,-1],second:[-1,-1,-1]},
  {name:'r6-extension-whole-overview-dark',R:6,whole:true,dust:false,screen:true,eye:0,theme:'dark',normal:[1,0,-1],outsideSourceUI:true},
];
const own=value=>JSON.parse(JSON.stringify(value));
const packed=value=>Array.from(new Float32Array(value));
function captureLayer(){
  const calls=[];
  return {calls,ensure(){},set(index,...args){calls[index]=args;},commit(count){this.count=count;},uniforms(){},points:{visible:false}};
}
function evaluate(profile,matrix,progress){
  const determinant=matrix[0]*matrix[3]-matrix[1]*matrix[2],g=matrix.map(x=>x/Math.sqrt(determinant));
  const otherRadius=profile.whole?Math.round(.4*profile.R):profile.dust?10:0;
  const catalogue=pure.lt(g,profile.R,otherRadius,true,0);
  const stars=captureLayer(),marks=captureLayer(),ghost=captureLayer();
  const calls={};
  const H={stars,marks,ghost,rayPos:new Float32Array(6*1200),rayCol:new Float32Array(8*1200),
    commitRays(count){calls.rayCount=count;},setScreen(...args){calls.screen=args;},
    setSelLabel(label,position){calls.selectedLabelPosition=position;},
    setRay(direction){calls.selectedRayDirection=direction;},
    setPlane(normal,endpoints,colour,opacity){calls.plane={normal,endpoints,opacity};}};
  const selected=profile.selected??[1,0,1],second=profile.second??(profile.normal?[1,1,1]:null);
  const context=vm.createContext({H,n:{R:profile.R,hf:.6,sigma:1,screen:profile.screen,dust:profile.dust,
    full:profile.whole,normal:profile.normal?.map(BigInt)??null,shell:null,
    sel:selected.map(BigInt),sel2:second?.map(BigInt)??null},
    a:{name:profile.theme,inkRgb:[0,0,0],anchors:[0,0,0,0,0],select:0,necklace:0,
      mutedRgb:[0,0,0],dust:profile.theme==='dark'?.42:.5},
    i:false,s:g,l:catalogue,u:null,d:new Float64Array(3*catalogue.n),f:new Float32Array(catalogue.n),
    m:new Float32Array(catalogue.n),p:Float32Array.from(catalogue.k,k=>k>0?k**.25:1),
    v:new Uint8Array(catalogue.n),b:profile.eye,S:progress,w:+profile.whole,E:1,
    vt:.06,yt:.15,bt:.004,G:[0,0,0],Je:{n:0},B:{},L:-1,I:-1,_:'',Te:false,
    K:{starA:{cur:1},plane:{cur:0}},
    re:()=>+profile.whole,ot:()=>Math.round(.4*profile.R),
    // Palette output, diagnostic labels, and identity ghost displacement are not fixture claims.
    x:()=>[0,0,0],Pt(){},be:()=>({offset:0}),At:()=>0,Ne:()=>''});
  vm.runInContext(renderCode+'\nW();ht();an();',context);
  const index=new Map();for(let i=0;i<catalogue.n;i++)index.set(Array.from(catalogue.abc.slice(3*i,3*i+3)).join(','),i);
  const points=probes.map(probe=>{
    const idx=index.get(probe.abc.join(','));
    if(idx===undefined)return {...probe,catalogued:false,body:null};
    const args=stars.calls[idx],raw=[...args.slice(0,4),args[7]],gpu=packed(raw);
    const rgbOmitted={sourceXYZ:raw.slice(0,3),radius:raw[3],alpha:raw[4]};
    return {...probe,catalogued:true,catalogueIndex:idx,sourceKind:catalogue.kind[idx],
      basePrimitive:!!catalogue.prim[idx],baseDiscriminant:-catalogue.k[idx],
      transformedABC:Array.from(context.d.slice(3*idx,3*idx+3)),
      cropFadeFloat32:context.f[idx],radialDistanceFloat32:context.m[idx],quarterRootFloat32:context.p[idx],
      planeMember:!!context.v[idx],body:{raw:rgbOmitted,packedFloat32:{sourceXYZ:gpu.slice(0,3),
        displayXYZ:[-gpu[0],gpu[1],-gpu[2]],radius:gpu[3],alpha:gpu[4],passesSourceAlphaPickGate:gpu[4]>=.06}}};
  });
  const markerPoints=[selected,...(second?[second]:[])];
  const markers=marks.calls.map((args,i)=>({baseABC:markerPoints[i],sourceXYZ:args.slice(0,3),
    radius:args[3],alpha:args[7],packedFloat32:packed([...args.slice(0,4),args[7]])}));
  const rays=points.filter(p=>p.catalogued&&p.basePrimitive&&p.sourceKind===0).map(point=>{
    const target=point.transformedABC,sourceXYZ=[target[1],target[0]+target[2],target[0]-target[2]];
    const scale=Math.max(1,.6*profile.R/sourceXYZ[1]),endpoint=sourceXYZ.map(x=>x*scale);
    let found=-1;
    for(let i=0;i<calls.rayCount;i++)if(endpoint.every((x,j)=>Math.abs(Math.fround(x)-H.rayPos[6*i+3+j])<1e-6)){found=i;break;}
    return {baseABC:point.abc,ray:found<0?null:{sourceIndex:found,
      packedPositions:Array.from(H.rayPos.slice(6*found,6*found+6)),
      packedAlpha:[H.rayCol[8*found+3],H.rayCol[8*found+7]]}};
  });
  return {profile:profile.name,settings:{...profile,hf:.6,height:.6*profile.R,sigma:1,projection:progress,
    selected,second,ordinaryViewer:true},matrix,determinant,normalizedMatrix:g,
    catalogue:{total:catalogue.n,upper:catalogue.nIn,otherRadius},points,markers,rays,
    screen:{height:calls.screen[0],opacityFactor:calls.screen[1]},selectedLabelPosition:calls.selectedLabelPosition,
    selectedRayDirection:calls.selectedRayDirection,plane:calls.plane??null};
}
const cases=[];
for(const profile of profiles)for(const matrix of [[1,0,0,1],[3,1,1,2]])for(const progress of [0,.5,1])cases.push(own(evaluate(profile,matrix,progress)));
// Independent invariants check the fixture harness, not a theorem about the source or renderer.
for(let i=0;i<cases.length;i+=3){
  const [start,middle,end]=cases.slice(i,i+3);
  for(let k=0;k<start.points.length;k++){
    const a=start.points[k],b=middle.points[k],c=end.points[k];if(!a.catalogued)continue;
    if(a.sourceKind===0&&a.cropFadeFloat32>0){
      assert.ok(Math.abs(c.body.raw.sourceXYZ[1]-end.settings.height)<1e-12);
      assert.ok(Math.abs(b.body.raw.sourceXYZ[1]-(a.body.raw.sourceXYZ[1]+end.settings.height)/2)<1e-12);
      if(!a.basePrimitive)assert.equal(c.body.raw.alpha,0);
      if(start.settings.eye===1){
        const r=a.body.raw.radius/a.body.raw.sourceXYZ[1];
        assert.ok(Math.abs(r-c.body.raw.radius/c.body.raw.sourceXYZ[1])<1e-12);
      }
    }else if(a.sourceKind!==0){assert.deepEqual(a.body,b.body);assert.deepEqual(a.body,c.body);}
  }
  assert.deepEqual(start.plane,end.plane);assert.deepEqual(start.screen,end.screen);
  assert.deepEqual(start.selectedRayDirection,end.selectedRayDirection);
  assert.equal(end.markers[0].alpha,1);
}
const fixture={schema:'source-projection-morph-audit-v1',sourceURL:'https://katestange.net/_astro/index.astro_astro_type_script_index_0_lang.kfTP0QEk.js',
  sourceSHA256:sha,canonicalHandoffCommit:'b3bd1fcb2097a6d2c009a56144f2936375c1209c',
  scope:'Offline evaluation of pinned source numerical functions with inert renderer adapters. Not app/DOM/GPU/headset execution or Lean proof. Colours and identity ghosts are excluded; CPU inputs and Float32 packing are recorded before camera/shader fog and minimum-pixel attenuation.',
  sourceDefaults:{R:48,depthMin:16,depthMax:80,theme:'light',hf:.6,heightMinFraction:.15,heightMaxFraction:1,screen:true,whole:false,dust:false,projection:0,sigma:1},
  sourceKindCodes:{0:'upper',1:'null',2:'exterior',3:'lower'},
  sourceToApplicationDisplay:'[-sourceX,sourceY,-sourceZ]',
  timing:{durationMillisecondsPerUnit:3500,elapsedFractions:[0,.25,.5,.75,1],easedProgress:[0,.25,.5,.75,1].map(t=>pure._e(t)),sliderImmediate:true,reducedMotionImmediate:true},
  extractedRoutines:extracted,cases};
fs.writeFileSync(output,JSON.stringify(fixture,null,2)+'\n');
console.log(JSON.stringify({output,cases:cases.length,sourceSHA256:sha,checked:'position/other-category/opacity/eye-ratio/marker/plane invariants'}));
