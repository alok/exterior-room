import test from 'node:test';
import assert from 'node:assert/strict';
import {catalogueFade,catalogueUniform,catalogueOpacity,catalogueVisibility,sourceRootVisible,sourceProjectionOpacity} from '../web/polynomial/catalogue-display.js';
import {interiorIndices,pickRoot} from '../web/polynomial/klein-data.js';
import {pointCloud,pointCloudMaterial} from '../web/polynomial/point-cloud.js';

const source=()=>({count:5,kind:new Uint8Array([2,2,3,1,0]),divisor:new Uint8Array([1,2,1,1,1]),
  delta:new Int32Array([-4,-16,-4,1,0]),xyz:new Float32Array([0,2,0,0,4,0,0,-2,0,3,0,4,0,0,10]),
  catalogue:{kind:'source',depth:10,otherRadius:10}});

test('source fade retains the interior, smoothly fades the outer14%, and rejects the boundary and beyond',()=>{
  assert.equal(catalogueFade(0,10),1);assert.equal(catalogueFade(8.6,10),1);
  assert.ok(Math.abs(catalogueFade(9.3,10)-.5)<1e-14);
  assert.equal(catalogueFade(10,10),0);assert.equal(catalogueFade(12,10),0);
  assert.equal(catalogueFade(0,0),0);assert.equal(catalogueFade(Infinity,10),0);
});

test('upper depth and other signed Euclidean radius use transformed display coordinates',()=>{
  const lattice=source(),xyz=lattice.xyz.slice();
  xyz.set([100,9.3,100],0); // upper uses Y, never Euclidean length
  xyz.set([0,9.3,0],6); // lower retains its accepted category and uses otherRadius
  lattice.catalogue.otherRadius=5;
  assert.ok(Math.abs(catalogueOpacity(lattice,xyz,0)-.5)<1e-6);
  assert.equal(catalogueOpacity(lattice,xyz,2),0);
  assert.equal(catalogueOpacity(lattice,xyz,3),0); // length exactly5
  xyz.set([2.79,0,3.72],9); // length4.65, midpoint of 4.3..5
  assert.ok(Math.abs(catalogueOpacity(lattice,xyz,3)-.5)<1e-6);
  assert.deepEqual([...lattice.xyz],[0,2,0,0,4,0,0,-2,0,3,0,4,0,0,10]);
});

test('base-order visibility mask excludes exactly faded-out catalogue points without compacting identities',()=>{
  const lattice=source(),out=new Uint8Array(lattice.count),xyz=lattice.xyz.slice();
  xyz[1]=10;xyz[4]=9.9;
  assert.equal(catalogueVisibility(lattice,xyz,out),out);
  assert.deepEqual([...out],[0,1,1,1,0]);
  assert.equal(lattice.count,5);assert.equal(lattice.divisor[1],2);
  assert.throws(()=>catalogueVisibility(lattice,xyz,new Uint8Array(4)));
});

test('canonical visibility and root eligibility stay unchanged, including negative signs and multiples',()=>{
  const lattice=source();delete lattice.catalogue;
  assert.deepEqual(catalogueUniform(lattice),[1,1,0]);
  assert.deepEqual([...catalogueVisibility(lattice,lattice.xyz)],[1,1,1,1,1]);
  assert.deepEqual([...interiorIndices(lattice)],[0,1,2]);
  assert.deepEqual([...interiorIndices(lattice,{model:'half-plane'})],[0,1]);
  assert.equal(sourceRootVisible(lattice,1),true);
});

test('source roots show primitive upper forms in either chart while every signed world identity remains present',()=>{
  const lattice=source(),snapshot=lattice.xyz.slice();
  assert.deepEqual([...interiorIndices(lattice)],[0]);
  assert.deepEqual([...interiorIndices(lattice,{model:'half-plane'})],[0]);
  assert.equal(sourceRootVisible(lattice,1),false);assert.equal(sourceRootVisible(lattice,2),false);
  assert.deepEqual(lattice.xyz,snapshot);assert.equal(lattice.count,5);
});

test('root selection ignores zero catalogue opacity and ineligible signs/multiples even with unfiltered candidates',()=>{
  const lattice=source(),all=new Uint32Array([0,1,2]),xyz=lattice.xyz.slice();
  assert.equal(pickRoot(lattice,xyz,all,300,0,0),0);
  xyz[1]=10; // primitive is now invisible; coincident double/lower cannot replace it
  assert.equal(pickRoot(lattice,xyz,all,300,0,0),-1);
});

test('audited animated projection fades only nonprimitive upper source stars, and the helper leaves world data intact',()=>{
  const lattice=source(),snapshot=lattice.xyz.slice();
  assert.deepEqual([0,.25,1].map(t=>sourceProjectionOpacity(lattice,1,t)),[1,.75,0]);
  for(const i of [0,2,3,4])assert.equal(sourceProjectionOpacity(lattice,i,1),1);
  assert.deepEqual(lattice.xyz,snapshot);assert.equal(lattice.count,5);
  delete lattice.catalogue;assert.equal(sourceProjectionOpacity(lattice,1,1),1);
  assert.throws(()=>sourceProjectionOpacity(lattice,1,NaN));
});

test('point cloud binds the exact base classification and source uniform without changing accepted positions',()=>{
  const lattice=source(),material=pointCloudMaterial(),points=pointCloud(lattice,material,false,'viridis');
  assert.deepEqual(material.uniforms.uCatalogue.value.toArray(),[10,10,1]);
  assert.deepEqual([...points.geometry.attributes.aKind.array],[2,2,3,1,0]);
  assert.equal(points.geometry.attributes.position.array,lattice.xyz);
  delete lattice.catalogue;const canonical=pointCloud(lattice,material,false,'viridis');
  assert.deepEqual(material.uniforms.uCatalogue.value.toArray(),[1,1,0]);
  points.geometry.dispose();canonical.geometry.dispose();material.dispose();
});
