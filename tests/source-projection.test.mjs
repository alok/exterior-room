import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {sourceProjectionPoint,sourceProjectionPositions,sourceWorldOpacity,sourceWorldRadius,sourceWorldVisibility,sourcePlaneMask,sourcePickAlpha,sourceRootOpacity,sourceRootRadius,sourceRootMarker} from '../web/polynomial/source-projection.js';
import {catalogueVisibility} from '../web/polynomial/catalogue-display.js';
import {pointCloud,pointCloudMaterial} from '../web/polynomial/point-cloud.js';
import {applyRows,pushforward} from '../web/polynomial/mobius.js';

const audit=JSON.parse(fs.readFileSync(new URL('../lean/Polynomial/fixtures/source-projection-morph.json',import.meta.url)));
const rootsAudit=JSON.parse(fs.readFileSync(new URL('../lean/Polynomial/fixtures/source-roots-marker.json',import.meta.url)));
const kindMap=[2,0,1,3];
const near=(actual,expected,label)=>assert.ok(Math.abs(actual-expected)<=3e-6*Math.max(1,Math.abs(expected)),`${label}: ${actual} != ${expected}`);
function caseData(c){
  const points=c.points.filter(p=>p.catalogued&&p.body),s=c.settings;
  const lattice={count:points.length,abc:Float64Array.from(points.flatMap(p=>p.abc)),kind:Uint8Array.from(points,p=>kindMap[p.sourceKind]),divisor:Uint8Array.from(points,p=>p.basePrimitive?1:2),delta:Int32Array.from(points,p=>p.baseDiscriminant),
    xyz:Float32Array.from(points.flatMap(p=>{const[a,b,c]=p.transformedABC;return[-b,a+c,c-a];})),catalogue:{kind:'source',depth:s.R,otherRadius:c.catalogue.otherRadius,whole:s.whole,dust:s.dust}};
  const options={progress:s.projection,height:s.height,eye:s.eye,whole:Number(s.whole),dust:s.dust,screen:s.screen,light:s.theme==='light',sigma:s.sigma,focusEnabled:!!s.normal,planeMask:s.normal?sourcePlaneMask(lattice,s.normal):null};
  return {points,lattice,options};
}

test('source projection, physical radii, body alpha and picking agree with 48 pinned-source evaluated cases',()=>{
  assert.equal(audit.sourceSHA256,'f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b');
  assert.equal(audit.cases.length,48);
  let checked=0;
  for(const c of audit.cases){
    const {points,lattice,options}=caseData(c),xyz=lattice.xyz.slice(),world=sourceProjectionPositions(lattice,xyz,options),visible=sourceWorldVisibility(lattice,xyz,options);
    for(let i=0;i<points.length;i++){
      const p=points[i],want=p.body.packedFloat32,label=`${c.profile}/${c.matrix}/${options.progress}/${p.name}`;
      near(sourceWorldOpacity(lattice,xyz,i,options),want.alpha,`${label} alpha`);
      assert.equal(!!visible[i],want.passesSourceAlphaPickGate,`${label} picker`);
      if(p.cropFadeFloat32>0){
        near(sourceWorldRadius(lattice.delta[i],lattice.kind[i],lattice.divisor[i],xyz[3*i+1],{...options,onPlane:!!options.planeMask?.[i]}),want.radius,`${label} radius`);
        for(let j=0;j<3;j++)near(world[3*i+j],want.displayXYZ[j],`${label} xyz${j}`);
      }
      checked++;
    }
    assert.deepEqual(lattice.xyz,xyz,'projection must not overwrite accepted/display geometry');
  }
  assert.ok(checked>300,`checked ${checked} source body examples`);
});

test('source selection markers move independently of body crop, Whole fade and nonprimitive fade',()=>{
  for(const c of audit.cases){
    const {lattice,options}=caseData(c);
    for(const marker of c.markers){
      const [a,b,d]=applyRows(pushforward(c.normalizedMatrix),marker.baseABC),xyz=[-b,a+d,d-a];
      const [A,B,C]=marker.baseABC,delta=B*B-4*A*C,kind=delta<0?(A>0?2:3):delta===0?0:1;
      const out=sourceProjectionPoint(xyz,kind,options.progress,options.height);
      const want=marker.packedFloat32;
      for(let j=0;j<3;j++)near(out[j],want[j]*(j===1?1:-1),'independent marker');
    }
    assert.equal(lattice.count,lattice.kind.length);
  }
});

test('world and roots visibility intentionally differ; projection fades multiples without relabelling them',()=>{
  const lattice={count:3,kind:new Uint8Array([2,2,2]),divisor:new Uint8Array([1,2,1]),delta:new Int32Array([-4,-16,-64]),xyz:new Float32Array([0,2,0,0,4,0,0,8,0]),catalogue:{kind:'source',depth:16,otherRadius:6,whole:true}};
  assert.deepEqual([...catalogueVisibility(lattice,lattice.xyz)],[1,1,1]);
  assert.deepEqual([...sourceWorldVisibility(lattice,lattice.xyz,{progress:0})],[1,1,0]);
  assert.deepEqual([...sourceWorldVisibility(lattice,lattice.xyz,{progress:1})],[1,0,1]);
  assert.deepEqual(sourceProjectionPoint([0,4,0],2,1,9.6),[0,9.6,0]);
  assert.equal(lattice.divisor[1],2);
  assert.equal(sourceWorldOpacity(lattice,lattice.xyz,1,{progress:1}),0);
  assert.equal(sourcePickAlpha,.06);
  assert.throws(()=>sourceProjectionPositions(lattice,lattice.xyz,{progress:1},lattice.xyz),/separate output/);
});

test('lower, exterior and null positions stay signed and stationary; canonical geometry is unchanged',()=>{
  for(const kind of [0,1,3])assert.deepEqual(sourceProjectionPoint([-1,-3,-1],kind,1,9.6),[-1,-3,-1]);
  const lattice={count:2,kind:new Uint8Array([2,3]),xyz:new Float32Array([1,2,1,-1,-2,-1])},out=new Float32Array(6);
  assert.equal(sourceProjectionPositions(lattice,lattice.xyz,{progress:1,height:9.6},out),out);
  assert.deepEqual(out,lattice.xyz);
  assert.deepEqual([...sourceWorldVisibility(lattice,lattice.xyz)],[1,1]);
  assert.throws(()=>sourceProjectionPoint([1,2,1],2,NaN,1));
  assert.throws(()=>sourceProjectionPositions(lattice,lattice.xyz,{height:0}));
});

test('source plane display mask handles every signed category and falls back to exact BigInt cancellation',()=>{
  const lattice={count:6,abc:new Int32Array([1,0,1,-1,0,-1,1,2,1,0,1,0,1,-1,2,1,3,2])};
  assert.deepEqual([...sourcePlaneMask(lattice,[1,0,-1])],[1,1,1,1,0,0]);
  const large={count:2,abc:new Float64Array([1,0,-1,1,1,-1])},n=Number.MAX_SAFE_INTEGER;
  assert.deepEqual([...sourcePlaneMask(large,[n,1,n])],[1,0]);
  assert.throws(()=>sourcePlaneMask(lattice,[1.5,0,-1]));
  assert.throws(()=>sourcePlaneMask({count:1,abc:new Float64Array([.1,0,1])},[1,0,-1]));
});

test('source shader consumes the same unprojected coordinates and independent exact classification attrs',()=>{
  const {lattice}=caseData(audit.cases[0]),material=pointCloudMaterial(),points=pointCloud(lattice,material,false,'viridis');
  assert.equal(points.geometry.attributes.position.array,lattice.xyz);
  assert.deepEqual([...points.geometry.attributes.aPrimitive.array],[...lattice.divisor].map(d=>d===1?1:0));
  assert.equal(points.geometry.attributes.aOnPlane.count,lattice.count);
  assert.deepEqual(material.uniforms.uSource.value.toArray(),[1,0,1,0]);
  assert.ok(material.vertexShader.includes('sourceProjectionPosition(position,aKind,uProjection)'));
  assert.ok(material.vertexShader.includes('sourceWorldOpacity(position,aKind,aPrimitive'));
  assert.ok(material.vertexShader.includes('length(modelMatrix[0].xyz)'));
  points.geometry.dispose();material.dispose();
});

test('source root bodies use exact plane focus and crop only, independent of Whole and projection',()=>{
  const {lattice,options}=caseData(audit.cases[0]);
  for(let i=0;i<lattice.count;i++){
    const eligible=lattice.kind[i]===2&&lattice.divisor[i]===1;
    assert.equal(sourceRootOpacity(lattice,lattice.xyz,i,options),eligible?Math.fround(options.planeMask[i]?1:.26):0);
    assert.equal(sourceRootOpacity(lattice,lattice.xyz,i,{...options,whole:0,progress:1,eye:1}),sourceRootOpacity(lattice,lattice.xyz,i,options));
    assert.equal(sourceRootOpacity(lattice,lattice.xyz,i,{...options,light:true}),eligible?Math.fround(options.planeMask[i]?1:.32):0);
  }
  const offPlane=3,xyz=lattice.xyz.slice();xyz[3*offPlane+1]=lattice.catalogue.depth;
  assert.equal(sourceRootOpacity(lattice,xyz,offPlane,options),0);
});

test('source root selection rings retain signed/nonprimitive identity and use primitive apparent radius',()=>{
  for(const model of ['half-plane','klein']){
    const options={model,scale:100,sigma:1},primitive={xyz:[-1,2,0],delta:-3,divisor:1},double={xyz:[-2,4,0],delta:-12,divisor:2},lower={xyz:[2,-4,0],delta:-12,divisor:2};
    const expected=sourceRootMarker(primitive,options);
    for(const item of [double,lower]){
      const actual=sourceRootMarker(item,options);actual.position.forEach((v,i)=>near(v,expected.position[i],'signed root position'));
      near(actual.apparentRadius,expected.apparentRadius,'primitive root radius');near(actual.radius,expected.radius,'primitive root ring');
    }
    assert.equal(expected.radius,Math.max(5,expected.apparentRadius+4));
    assert.equal(expected.apparentRadius,sourceRootRadius(primitive.xyz,primitive.delta,options));
    assert.deepEqual(lower,{xyz:[2,-4,0],delta:-12,divisor:2});
    assert.equal(sourceRootMarker(double,{...options,sigma:0}).radius,5);
  }
  assert.equal(sourceRootMarker({xyz:[-1,0,0],delta:1}),null);
  assert.equal(sourceRootMarker({xyz:[0,1,1],delta:0}),null);
  assert.equal(sourceRootMarker(null),null);
});

test('root bodies and signed selection rings match 44 independently evaluated Jt/Xt source cases',()=>{
  assert.equal(rootsAudit.sourceSHA256,audit.sourceSHA256);assert.equal(rootsAudit.cases.length,44);
  const {R,sigma}=rootsAudit.settings,{scale}=rootsAudit.viewport;
  for(const c of rootsAudit.cases){
    const [a,b,d]=c.transformedABC,xyz=[-b,a+d,d-a],delta=-c.baseK,model=c.model===0?'klein':'half-plane';
    const marker=sourceRootMarker({xyz,delta,divisor:c.divisor},{model,sigma,scale});
    if(!c.marker){assert.equal(marker,null,`${c.name} noninterior marker`);continue;}
    marker.position.forEach((v,i)=>near(v,c.chart.applicationXY[i],`${c.name} chart position`));
    near(marker.apparentRadius,c.marker.rawRadius,`${c.name} source primitive radius`);
    near(marker.radius,c.marker.ringRadius,`${c.name} source ring radius`);
    if(c.body){
      const lattice={count:1,xyz,kind:[kindMap[c.sourceKind]],divisor:[c.divisor],delta:[delta],catalogue:{kind:'source',depth:R,otherRadius:Math.round(.4*R)}};
      near(sourceRootRadius(xyz,delta,{model,sigma,scale}),c.body.radius,`${c.name} body radius`);
      near(sourceRootOpacity(lattice,xyz,0,{planeMask:[Number(c.planeMember)]}),c.body.packedFloat32[4],`${c.name} body alpha`);
    }
  }
});
