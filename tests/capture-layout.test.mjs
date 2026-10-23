import test from 'node:test';
import assert from 'node:assert/strict';
import {captureLayout,fitCaptureSource,sameCanvasSet} from '../web/qa/capture-layout.js';

test('one-canvas recording retains the existing bounds and aspect ratio',()=>{
  for(const source of [{width:2400,height:1600},{width:780,height:1688},{width:640,height:480}]){
    const layout=captureLayout([source]),rect=fitCaptureSource(source,layout.slots[0]);
    assert.ok(layout.width<=1280&&layout.height<=800);
    assert.ok(Math.abs(rect.width/rect.height-source.width/source.height)<1e-12);
    assert.ok(rect.x>=0&&rect.y>=0&&rect.x+rect.width<=layout.width+1e-10&&rect.y+rect.height<=layout.height+1e-10);
  }
});
test('paired canvases keep both aspect ratios, order and relative size within one bounded frame',()=>{
  const sources=[{width:1500,height:1600},{width:800,height:1200}],layout=captureLayout(sources);
  assert.ok(layout.width<=1280&&layout.height<=800);assert.equal(layout.slots.length,2);
  const [left,right]=sources.map((source,i)=>fitCaptureSource(source,layout.slots[i]));
  assert.ok(left.x+left.width<=right.x+1e-10);
  assert.ok(Math.abs(left.width/left.height-1500/1600)<1e-12);
  assert.ok(Math.abs(right.width/right.height-800/1200)<1e-12);
  assert.ok(Math.abs(left.width/right.width-1500/800)<1e-12);
  assert.ok(right.y>left.y); // shorter source is letterboxed, not vertically stretched
});
test('a source resize is fitted to its original slot without stretching or changing the output bounds',()=>{
  const layout=captureLayout([{width:800,height:800},{width:600,height:800}]);
  const slot=layout.slots[1],source={width:1200,height:300},rect=fitCaptureSource(source,slot);
  assert.equal(rect.width/rect.height,4);assert.ok(rect.y>slot.y);
  assert.ok(rect.x>=slot.x&&rect.x+rect.width<=slot.x+slot.width+1e-10);
});
test('canvas identity changes, disappearance and replacement invalidate recording, but the same sources do not',()=>{
  const three={},roots={},replacement={};
  assert.equal(sameCanvasSet([three,roots],[three,roots]),true);
  assert.equal(sameCanvasSet([three,roots],[three]),false);
  assert.equal(sameCanvasSet([three],[roots]),false);
  assert.equal(sameCanvasSet([three,roots],[three,replacement]),false);
  assert.equal(sameCanvasSet([three,roots],[roots,three]),false);
});
test('empty, oversized or invalid source descriptions fail explicitly',()=>{
  assert.throws(()=>captureLayout([]));assert.throws(()=>captureLayout(Array(3).fill({width:1,height:1})));
  for(const source of [{width:0,height:10},{width:NaN,height:10},{width:10,height:Infinity}])assert.throws(()=>captureLayout([source]));
});
