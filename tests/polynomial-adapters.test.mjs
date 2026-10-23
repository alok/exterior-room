import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import * as reference from '../web/polynomial/reference/starscape-core.js';
import * as referenceAppearance from '../web/polynomial/reference/appearance.js';
import * as referencePlanes from '../web/polynomial/reference/pair-plane.js';
import {enumerateLattice} from '../web/polynomial/reference/lattice.js';
import {projectedPositions} from '../web/polynomial/lattice.js';
import * as appearance from '../web/polynomial/appearance.js';
import * as core from '../web/polynomial/starscape-core.js';
import * as client from '../web/polynomial/lean-client.js';
import {coneDirections,planeSection,inPairPlane} from '../web/polynomial/pair-plane.js';
import {pointCloudMaterial,pointCloud,fillColors,fillFactors} from '../web/polynomial/point-cloud.js';

const fixture=JSON.parse(readFileSync(new URL('../fixtures/polynomial-contract.json',import.meta.url)));
const gcd=(a,b)=>{a=Math.abs(a);b=Math.abs(b);while(b)[a,b]=[b,a%b];return a;};
const points=enumerateLattice(6),triples=Array.from({length:points.count},(_,i)=>Array.from(points.abc.subarray(3*i,3*i+3)));
const kinds=['null','exterior','upper','lower'];
// Independent test oracle only. Production never imports these reference modules.
const accepted={...points,delta:Int32Array.from(triples,reference.discriminant),kind:Uint8Array.from(triples,p=>kinds.indexOf(reference.kind(p))),divisor:Uint8Array.from(triples,p=>p.reduce(gcd,0))};
const packedOnly={...accepted,get abc(){throw Error('Packed rendering must not read/search coefficient triples.');}};
const near=(actual,expected,tolerance=1e-12)=>{
  assert.equal(actual.length,expected.length);
  actual.forEach((v,i)=>assert.ok(Math.abs(v-expected[i])<=tolerance,`${v} != ${expected[i]}`));
};

test('packed projection preserves every signed interior image without coefficient lookup',()=>{
  const expected=triples.flatMap(p=>reference.projectedRepresentative(p)??[]);
  const images=projectedPositions(packedOnly);
  // IEEE signed zero is not a different point; every nonzero Float32 coordinate
  // must still match the canonical projection exactly.
  near(images,new Float32Array(expected),0);
  assert.equal(images.byteLength,3*110*Float32Array.BYTES_PER_ELEMENT);
  const axisImageCount=Array.from({length:images.length/3},(_,i)=>images[3*i]===0&&images[3*i+2]===0).filter(Boolean).length;
  assert.ok(axisImageCount>1,'coincident images must retain signs and multiples');
  near(projectedPositions(packedOnly,8),new Float32Array(expected.map(x=>x*2)),0);
  assert.throws(()=>projectedPositions(packedOnly,0),RangeError);
  assert.throws(()=>projectedPositions(packedOnly,Infinity),RangeError);
  assert.throws(()=>projectedPositions({count:1,kind:new Uint8Array([2]),xyz:new Float32Array([1,0,1])}),/denominator/);
});

test('source projection filters accepted visibility and primitive upper points without dropping canonical defaults',()=>{
  const visible=Float32Array.from({length:accepted.count},(_,i)=>i%3===0?0:i%3===1?.15:1);
  for(const primitiveOnly of [false,true]){
    const expected=triples.flatMap((p,i)=>visible[i]>0&&(!primitiveOnly||(accepted.kind[i]===2&&accepted.divisor[i]===1))
      ?reference.projectedRepresentative(p)??[]:[]);
    near(projectedPositions(packedOnly,4,{visible,primitiveOnly}),new Float32Array(expected),0);
  }
  const primitive=triples.flatMap((p,i)=>accepted.kind[i]===2&&accepted.divisor[i]===1?reference.projectedRepresentative(p):[]);
  near(projectedPositions(packedOnly,4,{primitiveOnly:true}),new Float32Array(primitive),0);
  assert.equal(projectedPositions(packedOnly,4,{visible:new Uint8Array(accepted.count)}).length,0);
  assert.throws(()=>projectedPositions(packedOnly,4,{visible:new Uint8Array(accepted.count-1)}),/mask/);
  assert.throws(()=>projectedPositions(packedOnly,4,{visible:new DataView(new ArrayBuffer(accepted.count))}),/mask/);
  assert.throws(()=>projectedPositions(packedOnly,4,{primitiveOnly:'yes'}),/boolean/);
});

test('packed colors and plane size factors match canonical semantic appearance',()=>{
  const normal=[1,0,-1];
  const onPlane=i=>referencePlanes.inPairPlane(normal,triples[i]);
  for(const symmetric of [false,true]){
    for(const palette of ['viridis','reference']){
      const expected=Uint8Array.from(triples.flatMap(p=>referenceAppearance.coefficientColor(p,symmetric,palette).map(x=>Math.round(x*255))));
      assert.deepEqual(fillColors(packedOnly,symmetric,palette),expected);
    }
    const expected=Float32Array.from(triples,(p,i)=>referenceAppearance.sourceRadiusFactor(p,{symmetric,onPlane:reference.kind(p)==='upper'&&onPlane(i)}));
    assert.deepEqual(fillFactors(packedOnly,symmetric,onPlane),expected);
  }
});

test('packed radius factors retain origin and nonprimitive semantics for both signs',()=>{
  for(const point of fixture.pointCases.filter(p=>p.id!=='zero_excluded')){
    for(const origin of [false,true])for(const symmetric of [false,true])for(const onPlane of [false,true]){
      const options={origin,symmetric,onPlane};
      const expected=referenceAppearance.sourceRadiusFactor(point.abc,options);
      near([appearance.sourceRadiusFactorFromData(point.discriminant,point.kindCode,point.divisor,point.displayXYZ[1],options)],[expected]);
      near([appearance.sourceRadiusFactorFromData(point.discriminant,point.kind,point.divisor,point.displayXYZ[1],options)],[expected]);
    }
  }
});

test('point geometry sends accepted discriminants as exact float attributes',()=>{
  const material=pointCloudMaterial(),mesh=pointCloud(packedOnly,material,false,'viridis');
  try{
    assert.equal(mesh.geometry.attributes.position.array,accepted.xyz);
    assert.ok(mesh.geometry.attributes.aDelta.array instanceof Float32Array);
    assert.deepEqual(Array.from(mesh.geometry.attributes.aDelta.array),Array.from(accepted.delta));
    assert.equal(mesh.geometry.attributes.aDelta.count,accepted.count);
    assert.equal(mesh.geometry.attributes.color.count,accepted.count);
    assert.equal(mesh.geometry.attributes.aFactor.count,accepted.count);
    assert.equal(mesh.frustumCulled,false);
  }finally{mesh.geometry.dispose();material.dispose();}
});

test('cone directions distinguish explicit infinity from missing endpoint data',()=>{
  for(const item of fixture.pairCases.filter(p=>!p.expected.error)){
    const canonical=referencePlanes.pairPlane(item.first,item.second);
    const adapted={endpoints:item.expected.endpoints.map(e=>e.kind==='infinity'?{kind:'infinity'}:{kind:'rational',value:e.approx})};
    const expected=referencePlanes.coneDirections(canonical);
    coneDirections(adapted).forEach((direction,i)=>near(direction,expected[i]));
  }
  assert.throws(()=>coneDirections({endpoints:[{kind:'rational',numerator:1,denominator:2}]}),/numeric rendering value/);
  assert.throws(()=>coneDirections({endpoints:[{value:NaN}]}),/numeric rendering value/);
});

test('plane tessellation preserves the canonical display plane and finite clipping',()=>{
  for(const item of fixture.normalCases.filter(p=>!p.expected.error)){
    const normal=item.expected.normal,[A,B,C]=normal;
    const section=planeSection(normal,6);
    assert.deepEqual(section,referencePlanes.planeSection(normal,6));
    for(const [x,y,z] of section){
      assert.ok(Math.abs(-B*x-(A+C)*y+(C-A)*z)<1e-10);
      assert.ok(Math.abs(y)<=6+1e-12&&Math.hypot(x,z)<=6+1e-12);
    }
  }
  for(const args of [[[0,0,0],6],[[1,0,-1],0],[[1,0,-1],6,0]])assert.throws(()=>planeSection(...args),RangeError);
});

const service=fileURLToPath(new URL('../lean/.lake/build/bin/polynomial_service',import.meta.url));
test('scalar adapters consume compiled Lean results and refuse unknown or unsupported exact data',{skip:!existsSync(service)},async t=>{
  const saved={fetch:globalThis.fetch,document:globalThis.document,requestAnimationFrame:globalThis.requestAnimationFrame};
  t.after(()=>{for(const [name,value]of Object.entries(saved)){if(value===undefined)delete globalThis[name];else globalThis[name]=value;}});
  globalThis.document={getElementById:()=>null};
  globalThis.requestAnimationFrame=callback=>setImmediate(callback);
  // Exercise the real executable without needing a live HTTP server or UI.
  globalThis.fetch=async(_url,options)=>{
    const raw=execFileSync(service,[],{input:options.body+'\n',encoding:'utf8',maxBuffer:2*1024*1024});
    const value=JSON.parse(raw.trim());
    return {ok:value.ok,status:value.ok?200:400,json:async()=>value};
  };
  await client.loadCloud(6);
  const base=await client.inspect([1,-1,2]);
  const representative=core.positiveRepresentative([1,-1,2]);
  representative[0]=99;
  assert.deepEqual(base.positiveRepresentative,[1,-1,2],'adapter must not expose the cached representative for mutation');
  assert.equal(core.polynomial([1,-1,2]),'x²−x+2');
  near(core.vector([1,-1,2]),[1,3,1]);
  near(core.project([1,-1,2]),[4/3,4,4/3]);
  assert.equal(core.project([1,-1,2],0),null);
  assert.equal(core.project([1,-1,2],Infinity),null);
  await client.inspect([-2,2,-4]);await client.inspect([2,-2,4]);
  assert.equal(core.polynomial([-2,2,-4]),'−2x²+2x−4');
  assert.deepEqual(core.vector([-2,2,-4]),[-2,-6,-2]);
  near(core.projectedRepresentative([-2,2,-4]),[4/3,4,4/3]);
  near(core.upperRoot(core.positiveRepresentative([-2,2,-4])),[.5,Math.sqrt(7)/2]);
  for(const point of [[1,-1,2],[-2,2,-4]]){
    near(appearance.coefficientColor(point),referenceAppearance.coefficientColor(point));
    near([appearance.sourceRadiusFactor(point,{origin:true})],[referenceAppearance.sourceRadiusFactor(point,{origin:true})]);
  }
  assert.throws(()=>core.polynomial([96,96,96]),/no accepted Lean data/);
  const plane=await client.preparePlane([1,0,1],[1,1,1]);
  assert.deepEqual(plane.normal,[1,0,-1]);
  assert.equal(inPairPlane(plane.normal,[1,0,1]),true);
  assert.equal(inPairPlane(plane.normal,[1,0,2]),false);
  assert.throws(()=>inPairPlane(plane.normal,[1,2,1]),/interior cloud point/);
  assert.throws(()=>inPairPlane(plane.normal,[2,-2,4]),/interior cloud point/);
});
