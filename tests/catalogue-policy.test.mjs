import test from 'node:test';
import assert from 'node:assert/strict';
import {inverseBasePoint,catalogueDisplacement,needsSourceCatalogue} from '../web/polynomial/catalogue-policy.js';
const I=[1,0,0,1], catalogue={kind:'source',depth:6,matrix:I,whole:true,dust:false};
test('inverse-i refresh reference is projectively invariant',()=>{
  assert.deepEqual(inverseBasePoint(I),[0,1]);
  assert.deepEqual(inverseBasePoint([1,4,0,1]),[-4,1]);
  assert.deepEqual(inverseBasePoint([3,1,1,2]),[-.5,.5]);
  assert.deepEqual(inverseBasePoint([6,2,2,4]),[-.5,.5]);
  assert.equal(catalogueDisplacement(I,[-1,0,0,-1]),0);
});
test('source refresh threshold reuses close catalogue but refreshes meaningful motion',()=>{
  assert.equal(needsSourceCatalogue(catalogue,6,[100,1,0,100]),false);
  assert.equal(needsSourceCatalogue(catalogue,6,[100,17,0,100]),true);
  assert.equal(needsSourceCatalogue(catalogue,6,[3,1,1,2]),true);
  assert.equal(needsSourceCatalogue(catalogue,6,I,{force:true}),true);
});
test('catalogue settings and absence force a new exact request',()=>{
  assert.equal(needsSourceCatalogue(null,6,I),true);
  assert.equal(needsSourceCatalogue(catalogue,12,I),true);
  assert.equal(needsSourceCatalogue(catalogue,6,I,{whole:false}),true);
  assert.equal(needsSourceCatalogue(catalogue,6,I,{dust:true}),true);
  assert.throws(()=>inverseBasePoint([1,0,0,0]),RangeError);
});
