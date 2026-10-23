import test from 'node:test';
import assert from 'node:assert/strict';
import {shownUpperRoot,shownBoundaryRoot,approximateNumber,spacedPolynomial} from '../web/polynomial/display-readouts.js';
import {transformDisplay,matrixFromIntegers} from '../web/polynomial/mobius-render.js';
import {act} from '../web/polynomial/mobius.js';
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-10,`${a} != ${b}`);
test('shown roots follow the accepted D5 geometry while signed base identities persist',()=>{
 const g=matrixFromIntegers([3,1,1,2]);
 for(const [xyz,delta,z] of [[[0,2,0],-4,{x:0,y:1}],[[1,3,1],-7,{x:.5,y:Math.sqrt(7)/2}]]){
  const moved=transformDisplay(g,xyz),root=shownUpperRoot(moved,delta),expected=act(g,z);
  near(root[0],expected.x);near(root[1],expected.y);
  assert.deepEqual(shownUpperRoot(moved.map(x=>-x),delta),root);
 }
 assert.deepEqual(shownUpperRoot(transformDisplay(g,[0,2,0]),-4),[1,1]);
});
test('shown cutting-plane endpoints follow D5 including a projective infinity',()=>{
 const g=matrixFromIntegers([3,1,1,2]);
 near(shownBoundaryRoot(transformDisplay(g,[-1,1,0])),-2);
 near(shownBoundaryRoot(transformDisplay(g,[1,1,0])),4/3);
 assert.equal(shownBoundaryRoot([0,1,1]),Infinity);
 assert.equal(shownBoundaryRoot(transformDisplay(g,[-4,5,3])),Infinity);
 assert.equal(approximateNumber(Infinity),'∞');assert.equal(approximateNumber(-0.00001),'0.000');
});
test('noninterior and invalid shown-root inputs remain unavailable',()=>{
 assert.equal(shownUpperRoot([0,2,0],0),null);
 assert.equal(shownUpperRoot([NaN,2,0],-4),null);
 assert.equal(shownUpperRoot([0,1,1],-4),null);
 assert.equal(shownBoundaryRoot([Infinity,1,1]),null);
});

test('polynomial typography spaces binary operators without changing a leading sign',()=>{
 assert.equal(spacedPolynomial('−x²−x+2'),'−x² − x + 2');
 assert.equal(spacedPolynomial('2x²+2'),'2x² + 2');
 assert.equal(spacedPolynomial('−1'),'−1');
});
