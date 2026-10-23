// SPDX-License-Identifier: GPL-3.0-or-later
// Offline renderer audit only. No app, UI, GPU, build, service, or network calls.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {sourceWorldOpacity,sourceWorldRadius,sourcePlaneMask} from '../../web/polynomial/source-projection.js';

const root=fileURLToPath(new URL('../../',import.meta.url));
const sourcePath=process.argv[2]??'/tmp/exteriorroom-source-recrop-bundle.js';
const output=fileURLToPath(new URL('./oracle.json',import.meta.url));
const sourceSHA256='f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b';
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
assert.equal(hash(fs.readFileSync(sourcePath)),sourceSHA256);

// Reuse the existing independently audited extraction/evaluation harness in
// memory. Its output-file writer is excluded. Capture all numerical bodies,
// not just the ten probe forms serialized by the ordinary fixture generator.
const harnessPath='lean/Polynomial/source_projection_fixture.mjs';
const harness=fs.readFileSync(root+harnessPath,'utf8');
const end=harness.indexOf('const cases=[]');assert.ok(end>0);
let setup=harness.slice(harness.indexOf('const sourcePath='),end);
assert.ok(setup.includes('const output=fileURLToPath('));
setup=setup.replace(/const output=.*?;\n/,'');
const context=vm.createContext({fs,vm,assert,createHash,process:{argv:['node','audit',sourcePath]}});
vm.runInContext(setup+`
  const originalCapture=captureLayer, layers=[];
  captureLayer=()=>{const layer=originalCapture();layers.push(layer);return layer;};
  const auditCases=[0,.5,1].map(progress=>evaluate(profiles[0],[1,0,0,1],progress));
  const all=pure.lt([1,0,0,1],16,6,true,0);
  globalThis.auditData={cases:auditCases,abc:Array.from(all.abc),kind:Array.from(all.kind),primitive:Array.from(all.prim),
    bodies:[0,1,2].map(i=>layers[3*i].calls.map(args=>packed([...args.slice(0,4),args[7]])))};
`,context);
const data=JSON.parse(JSON.stringify(context.auditData)),N=data.kind.length,kindMap=[2,0,1,3];
const lattice={count:N,abc:Int32Array.from(data.abc),kind:Uint8Array.from(data.kind,k=>kindMap[k]),
  divisor:Uint8Array.from(data.primitive,p=>p?1:2),delta:new Int32Array(N),xyz:new Float32Array(3*N),
  catalogue:{kind:'source',depth:16,otherRadius:6,whole:true,dust:false}};
for(let i=0;i<N;i++){
  const k=3*i,a=lattice.abc[k],b=lattice.abc[k+1],c=lattice.abc[k+2];
  lattice.delta[i]=b*b-4*a*c;lattice.xyz.set([-b,a+c,c-a],k);
}
const planeMask=sourcePlaneMask(lattice,[1,0,-1]);
const primitiveLattice={...lattice,divisor:new Uint8Array(N).fill(1)};
const settings={depth:16,matrix:[1,0,0,1],selected:[1,0,1],second:[1,1,1],normal:[1,0,-1],
  whole:true,dust:false,screen:true,heightFraction:.6,height:9.6,eye:0,sigma:1,theme:'dark'};
const options={height:9.6,whole:1,dust:false,eye:0,screen:true,light:false,sigma:1,focusEnabled:true,planeMask};
const quantiles=values=>{
  values.sort((a,b)=>a-b);
  if(!values.length)return null;
  return Object.fromEntries([['min',0],['p10',.1],['median',.5],['p90',.9],['max',1]].map(([key,q])=>[key,values[Math.floor((values.length-1)*q)]]));
};
const names=['null','exterior','upper','lower'];
const summaries=data.cases.map((c,caseIndex)=>{
  const progress=c.settings.projection,opts={...options,progress};
  const summary={progress,buffered:N,positiveBodies:0,pickableBodies:0,positiveByKind:Object.fromEntries(names.map(k=>[k,0])),
    positivePrimitiveUpper:0,positiveMultipleUpper:0,positiveOnPlane:0,positivePrimitiveUpperOnPlane:0,
    sourceBodyRadius:[],sourceUpperBodyRadius:[],sourcePrimitiveUpperBodyRadius:[],sourceBodyAlpha:[],
    nativeEndpointBinSimulation:{retainedInstances:0,positiveMaterialBodies:0,retainedZeroMaterialInstances:0,retainedZeroMaterialUpper:0,zeroMaterialDespitePositiveBody:0,zeroedByKind:Object.fromEntries(names.map(k=>[k,0])),maximumAlphaError:0},
    currentJSComparison:{maximumAlphaError:0,maximumRadiusError:0,disagreementsAbove2eMinus6:0}};
  for(let i=0;i<N;i++){
    const expected=data.bodies[caseIndex][i],alpha=sourceWorldOpacity(lattice,lattice.xyz,i,opts);
    const radius=sourceWorldRadius(lattice.delta[i],lattice.kind[i],lattice.divisor[i],lattice.xyz[3*i+1],{...opts,onPlane:!!planeMask[i]});
    const alphaError=Math.abs(alpha-expected[4]),radiusError=expected[4]>0?Math.abs(radius-expected[3]):0;
    summary.currentJSComparison.maximumAlphaError=Math.max(summary.currentJSComparison.maximumAlphaError,alphaError);
    summary.currentJSComparison.maximumRadiusError=Math.max(summary.currentJSComparison.maximumRadiusError,radiusError);
    if(alphaError>2e-6||radiusError>2e-6)summary.currentJSComparison.disagreementsAbove2eMinus6++;
    if(alpha>0){
      summary.positiveBodies++;summary.positiveByKind[names[lattice.kind[i]]]++;summary.sourceBodyRadius.push(radius);summary.sourceBodyAlpha.push(alpha);
      if(planeMask[i])summary.positiveOnPlane++;
      if(lattice.kind[i]===2){
        summary.sourceUpperBodyRadius.push(radius);
        if(lattice.divisor[i]===1){summary.positivePrimitiveUpper++;summary.sourcePrimitiveUpperBodyRadius.push(radius);if(planeMask[i])summary.positivePrimitiveUpperOnPlane++;}
        else summary.positiveMultipleUpper++;
      }
    }
    if(alpha>=.06)summary.pickableBodies++;
    // Port only the 11c907b RenderPlan's stable endpoint-bin expression. This
    // is a CPU prediction, not observed RealityKit material/pixel output.
    const start=data.bodies[0][i][4],end=sourceWorldOpacity(primitiveLattice,lattice.xyz,i,{...options,progress:1});
    const a=Math.round(start*15),b=Math.round(end*15);
    let materialAlpha=(a+(b-a)*progress)/15;
    if(lattice.kind[i]===2&&lattice.divisor[i]!==1)materialAlpha*=1-progress;
    if(expected[3]>0){
      summary.nativeEndpointBinSimulation.retainedInstances++;
      if(materialAlpha===0){summary.nativeEndpointBinSimulation.retainedZeroMaterialInstances++;if(lattice.kind[i]===2)summary.nativeEndpointBinSimulation.retainedZeroMaterialUpper++;}
    }
    if(materialAlpha>0)summary.nativeEndpointBinSimulation.positiveMaterialBodies++;
    if(alpha>0&&materialAlpha===0){summary.nativeEndpointBinSimulation.zeroMaterialDespitePositiveBody++;summary.nativeEndpointBinSimulation.zeroedByKind[names[lattice.kind[i]]]++;}
    summary.nativeEndpointBinSimulation.maximumAlphaError=Math.max(summary.nativeEndpointBinSimulation.maximumAlphaError,Math.abs(alpha-materialAlpha));
  }
  for(const key of ['sourceBodyRadius','sourceUpperBodyRadius','sourcePrimitiveUpperBodyRadius','sourceBodyAlpha'])summary[key]=quantiles(summary[key]);
  summary.physicalPrimitiveUpperRadius={native:Object.fromEntries(Object.entries(summary.sourcePrimitiveUpperBodyRadius).map(([k,v])=>[k,v*.06])),browser:Object.fromEntries(Object.entries(summary.sourcePrimitiveUpperBodyRadius).map(([k,v])=>[k,v*.16]))};
  return summary;
});
assert.deepEqual(summaries.map(x=>x.positiveBodies),[450,2239,1973]);
assert.deepEqual(summaries.map(x=>x.positivePrimitiveUpper),[51,1577,1577]);
assert.ok(summaries.every(x=>x.currentJSComparison.disagreementsAbove2eMinus6===0));
const files=[harnessPath,'web/polynomial/source-projection.js','web/polynomial/catalogue-display.js','web/polynomial/point-cloud.js','web/polynomial/appearance.js','web/polynomial/app.js',
  'native/Sources/PolynomialSourceMorph.swift','native/Sources/PolynomialRenderPlan.swift','native/Sources/PolynomialSpace.swift','native/Sources/PolynomialAppearance.swift'];
const result={schema:'source-projection-sparsity-oracle-v1',referenceCommit:'11c907b1',observedHEAD:execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(),
  sourceSHA256,files:Object.fromEntries(files.map(p=>[p,hash(fs.readFileSync(root+p))])),settings,catalogue:data.cases[0].catalogue,summaries,
  probes:data.cases.map(c=>({progress:c.settings.projection,points:c.points.filter(p=>['unit-selected','paired','nonprimitive-upper','off-plane-upper'].includes(p.name)).map(p=>({name:p.name,abc:p.abc,...p.body.packedFloat32}))})),
  rendererDifferences:{browser:{representation:'GL_POINTS circular antialias coverage',minimumRadiusCSSPixels:1,subminimumAlpha:'(raw radius / 1 CSS px)^2',kneeCSSPixels:2.5,maximumRadiusCSSPixels:9,
    depth:'Every Source body alpha is below .999, so vFaint=1 and fragment depth=1; material still depth-tests. Zero body alpha discards fragments.',scale:.16},
    native:{representation:'12-slice/8-ring instanced sphere, radius physical source radius times .96/depth',minimumPixelRadius:'No camera-dependent minimum footprint in PolynomialRenderPlan/PolynomialSpace',
      material:'UnlitMaterial(applyPostProcessToneMap:false), transparent opacity uses linearLightOpacity(endpoint-bin alpha,semantic RGB)',depth:'readsDepth/writesDepth/opacityThreshold not explicitly assigned in reviewed material() helper; runtime defaults not measured',zeroAlpha:'Crop-valid source radius>0 retains instance even when material alpha=0; an explicit browser fragment discard has no explicit native counterpart in app code',scale:.06},
    framing:'Browser R16 reset distance=sqrt(2.4²+1.5²+4.6²)*2≈10.80, FOV45. Native root at(0,1.4,-3.1), rotated, scale.06. Physical sizes alone do not establish angular/pixel-size parity.'},
  limits:['Offline extracted source numerical routines and current JavaScript helpers only; no UI/GPU/native model execution/build in this audit.',
    'Positive opacity is not a screen-space visible-pixel count; projection overlap, framing, occlusion, raster coverage and compositing remain unmeasured.',
    'Native endpoint-bin numbers simulate the reviewed Swift expression, not actual material blending.',
    'The source bundle must be supplied locally with the recorded SHA256; this script does not download it.',
    'Exact signed identity/action and Lean proof claims are unchanged. These are renderer diagnostics.']};
fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({output,buffered:N,positiveBodies:summaries.map(s=>s.positiveBodies),primitiveUpper:summaries.map(s=>s.positivePrimitiveUpper),sourceJSDisagreements:summaries.map(s=>s.currentJSComparison.disagreementsAbove2eMinus6)}));
