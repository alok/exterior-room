// Local renderer audit. This does not create or verify Lean proof certificates.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {displayRowsFromReceipt,coefficientsToDisplay} from '../inputs/mobius-render.js';
const root=new URL('../',import.meta.url),read=p=>readFileSync(new URL(p,root),'utf8');
const manifest=JSON.parse(read('source-manifest.json'));
for(const [path,entry] of Object.entries(manifest.files))assert.equal(createHash('sha256').update(readFileSync(new URL(path,root))).digest('hex'),entry.sha256,`Snapshot changed: ${path}`);
if(process.argv.includes('--verify')){console.log('All pinned input/script hashes verified.');process.exit(0);}
const source=JSON.parse(read('inputs/polynomial-action-cases.json')).cases;
const native=JSON.parse(readFileSync(process.argv[2],'utf8')),original=JSON.parse(read('original-native-positions.json'));
assert.equal(source.length,69);assert.deepEqual(native,original,'Recompiled frozen native source differs from the original read-only audit');
const points=[],signedZeroDifferences=[];let maxAbsolute=0,maxRelative=0,maxNativeJS=0;
for(let i=0;i<source.length;i++){
  const {name,response:receipt}=source[i],rows=displayRowsFromReceipt(receipt),xyz=coefficientsToDisplay(receipt.point);
  assert.equal(native[i].name,name);
  const browser=[0,1,2].map(j=>Math.fround(rows[3*j]*xyz[0]+rows[3*j+1]*xyz[1]+rows[3*j+2]*xyz[2]));
  const expected=receipt.xyzNumerator.map(x=>x/receipt.denominator);
  native[i].xyz.forEach((value,j)=>{
    assert.ok(value===browser[j],`Native/browser numerical Float32 mismatch: ${name}/${j}`);
    if(value===0&&browser[j]===0&&!Object.is(value,browser[j]))signedZeroDifferences.push({name,axis:j,nativeNegativeZero:Object.is(value,-0),browserNegativeZero:Object.is(browser[j],-0)});
  });
  for(let j=0;j<3;j++){
    const e=Math.abs(browser[j]-expected[j]);maxAbsolute=Math.max(maxAbsolute,e);maxRelative=Math.max(maxRelative,e/Math.max(1,Math.abs(expected[j])));maxNativeJS=Math.max(maxNativeJS,Math.abs(native[i].xyz[j]-browser[j]));
  }
  points.push({name,nativeXYZ:native[i].xyz,browserFloat32XYZ:browser,exactNumerator:receipt.xyzNumerator,denominator:receipt.denominator});
}
const d5=source.find(x=>x.name==='rational/default').response,F=displayRowsFromReceipt(d5);
const mul=(A,v)=>[0,1,2].map(i=>A[3*i]*v[0]+A[3*i+1]*v[1]+A[3*i+2]*v[2]);
// Independent covector check: for Lorentz F and Q=diag(1,-1,1), F^-T=QFQ.
const normal0=[0,0,-2],q=v=>[v[0],-v[1],v[2]],normal=q(mul(F,q(normal0)));
const expectedNormal=[-.4,1,-2.2];normal.forEach((x,i)=>assert.ok(Math.abs(x-expectedNormal[i])<1e-12));
const p=mul(F,coefficientsToDisplay([1,0,2])),dot=normal.reduce((s,x,i)=>s+x*p[i],0),distance=Math.abs(dot)/Math.hypot(...normal),t=distance/3,fade=1-.88*t*t*(3-2*t);
assert.ok(Math.abs(dot+2)<1e-12);assert.ok(Math.abs(fade-.8399267649983406)<1e-12);
const xyz=d5.xyzNumerator.map(x=>x/d5.denominator),originView=[xyz[0],xyz[2],-xyz[1]],projection=xyz.map(x=>4*x/xyz[1]);
const result={passed:true,scope:'Actual compiled frozen native PolynomialAction.mapDisplay versus frozen browser receipt conversion and Float32 cloud packing. Coordinate/render-math comparison only; no visual, UI, hardware, fresh Lean proof or final native fade-fix claim.',fixtureCount:source.length,equalityConvention:'Exact numeric Float32 equality (===), treating +0 and -0 as the same coordinate; not a bitwise-equality claim.',signedZeroDifferences,maxNativeBrowserDifference:maxNativeJS,maxAbsoluteFromRational:maxAbsolute,maxRelativeFromRational:maxRelative,relativeErrorDefinition:'abs(Float32 - exactNumerator/denominator) / max(1, abs(exactNumerator/denominator)); the rational reference is converted to JS Number for this metric.',d5:{matrix:d5.matrix,denominator:d5.denominator,coefficientRows:d5.coefficientRows,displayRows:F,defaultXYZ:{exact:['23/5','6','14/5'],numeric:xyz},projectionY4:{exact:['46/15','4','28/15'],numeric:projection},originUpperView:{exact:['23/5','14/5','-6'],numeric:originView,law:'Rx(-pi/2) maps (X,Y,Z) to (X,Z,-Y) in both implementations before device-specific view/projection.'},unitPairNormal:{base:normal0,exact:['-2/5','1','-11/5'],numeric:normal,norm:'sqrt(6)'},fadeSample:{point:[1,0,2],transformedXYZ:p,normalDot:dot,distance,fadeR6:fade,note:'Expected transformed-distance fade; original audited native renderer used base-distance fade. This audit does not certify the later native fix.'}},environment:{node:process.version,platform:process.platform,arch:process.arch},points};
const output=process.argv[3]??fileURLToPath(new URL('result.json',root));writeFileSync(output,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({passed:result.passed,fixtureCount:result.fixtureCount,signedZeroDifferenceCount:signedZeroDifferences.length,maxNativeBrowserDifference:maxNativeJS,maxAbsoluteFromRational:maxAbsolute,maxRelativeFromRational:maxRelative,output},null,2));
