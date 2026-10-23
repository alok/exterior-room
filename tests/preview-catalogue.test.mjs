import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {PreviewCatalogue} from '../web/polynomial/preview-catalogue.js';
import {matrixFromIntegers,quantizeMatrix} from '../web/polynomial/mobius-render.js';
import * as client from '../web/polynomial/lean-client.js';

const I=[1,0,0,1],point=[1,0,1],second=[1,1,1],base={catalogue:{kind:'source',depth:6,matrix:I,whole:true,dust:false}};
const deferred=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};};
const tick=()=>new Promise(resolve=>setImmediate(resolve));
const translation=t=>[1,t,0,1];
function harness(overrides={}){
  let now=0,nextTimer=0,active=0,maxActive=0;
  const timers=new Map(),calls=[],ready=[],errors=[],pins=new Map();
  const coordinator=new PreviewCatalogue({
    load:(depth,matrix,settings,options)=>{
      const d=deferred(),call={depth,matrix:[...matrix],settings,options,...d};calls.push(call);active++;maxActive=Math.max(maxActive,active);
      return d.promise.finally(()=>active--);
    },
    prepare:async()=>({normal:[1,0,-1]}),
    retain:lattice=>{pins.set(lattice,(pins.get(lattice)??0)+1);let live=true;return ()=>{if(live){live=false;pins.set(lattice,pins.get(lattice)-1);}};},
    cancelLoad:()=>{},onReady:r=>ready.push(r),onError:e=>errors.push(e.message),now:()=>now,
    schedule:(fn,ms)=>{const id=++nextTimer;timers.set(id,{at:now+ms,fn});return id;},clearSchedule:id=>timers.delete(id),...overrides,
  });
  function resolve(index){const call=calls[index],lattice={catalogue:{kind:'source',depth:call.depth,matrix:call.matrix,...call.settings}};call.resolve(lattice);return lattice;}
  function advance(ms){now+=ms;for(const [id,t]of [...timers])if(t.at<=now){timers.delete(id);t.fn();}}
  const begin=()=>coordinator.begin({lattice:base,point,second});
  return {coordinator,calls,ready,errors,pins,resolve,advance,begin,timers,get maxActive(){return maxActive;}};
}

test('held-preview refresh uses inverse-i threshold and exact quantized transport without activating a cloud',async()=>{
  const h=harness();h.begin();
  assert.equal(h.coordinator.update(translation(.1)),false);assert.equal(h.calls.length,0);
  assert.equal(h.coordinator.update(translation(.2)),true);assert.equal(h.calls.length,1);
  assert.deepEqual(h.calls[0].matrix,quantizeMatrix(translation(.2)));
  const candidate=h.resolve(0);await tick();assert.equal(h.ready[0].lattice,candidate);assert.equal(h.pins.get(candidate),1);
  assert.equal(h.coordinator.update(translation(.3)),false,'distance must use the new preview catalogue');
  assert.deepEqual(h.ready[0].point,point);assert.deepEqual(h.ready[0].second,second);
  h.coordinator.complete();assert.equal(h.pins.get(candidate),0);
});

test('rapid motion coalesces to one latest target, never overlaps loads, and skips a far stale crop',async()=>{
  const h=harness();h.begin();h.coordinator.update(translation(.2));
  for(const t of [.4,.6,1,1.4])h.coordinator.update(translation(t));
  assert.equal(h.calls.length,1);assert.equal(h.coordinator.diagnostics().queued,true);
  const stale=h.resolve(0);await tick();assert.equal(h.ready.length,0);assert.equal(h.pins.get(stale),0);
  h.advance(149);assert.equal(h.calls.length,1);h.advance(1);assert.equal(h.calls.length,2);
  assert.deepEqual(h.calls[1].matrix,quantizeMatrix(translation(1.4)));
  h.resolve(1);await tick();assert.equal(h.ready.length,1);assert.equal(h.maxActive,1);
  assert.equal(h.coordinator.diagnostics().queued,false);
});

test('a nearby newer pose may use a completed buffer while keeping the current numerical action outside this coordinator',async()=>{
  const h=harness();h.begin();h.coordinator.update(translation(.2));h.coordinator.update(translation(.25));
  h.resolve(0);await tick();h.advance(200);
  assert.equal(h.ready.length,1);assert.equal(h.calls.length,1,'a close trailing target must not trigger an unnecessary load');
  assert.deepEqual(h.ready[0].matrix,quantizeMatrix(translation(.2)));
});

test('cancel and new gesture invalidate old success/failure while preserving the one-flight bound',async()=>{
  let cancels=0;const h=harness({cancelLoad:()=>cancels++});h.begin();h.coordinator.update(translation(.2));
  h.coordinator.cancel();assert.equal(h.calls[0].options.isCurrent(),false);h.begin();h.coordinator.update(translation(1));
  assert.equal(h.calls.length,1);h.calls[0].reject(Error('old network failure'));await tick();h.advance(150);
  assert.equal(h.errors.length,0);assert.equal(h.calls.length,2);h.resolve(1);await tick();
  assert.equal(h.ready.length,1);assert.equal(h.maxActive,1);assert.equal(cancels,1);
  const candidate=h.ready[0].lattice;h.coordinator.cancel();assert.equal(h.pins.get(candidate),0);
});

test('release drains the in-flight candidate, drops queued work and reuses only an exact matrix and signed context',async()=>{
  const h=harness();h.begin();h.coordinator.update(translation(.2));h.coordinator.update(translation(1));
  const M=quantizeMatrix(translation(.2)),finished=h.coordinator.finish(M,{point,second,depth:6,whole:true,dust:false});
  h.resolve(0);const record=await finished;assert.ok(record);assert.deepEqual(record.matrix,M);assert.equal(h.ready.length,0);
  h.advance(1000);assert.equal(h.calls.length,1);
  assert.equal(await h.coordinator.finish(M.map(x=>x*2)),null,'projectively equivalent but nonidentical matrices cannot reuse metadata');
  assert.equal(await h.coordinator.finish(M,{second:[-1,-1,-1]}),null);
  assert.equal(await h.coordinator.finish(M,{depth:12}),null);
  h.coordinator.complete();assert.equal(h.pins.get(record.lattice),0);
});

test('a mismatched release or cancellation cannot promote a pending preview',async()=>{
  const h=harness();h.begin();h.coordinator.update(translation(.2));
  const release=h.coordinator.finish(quantizeMatrix(translation(.4)));h.resolve(0);assert.equal(await release,null);
  h.begin();h.advance(150);h.coordinator.update(translation(1));
  const cancelled=h.coordinator.finish(quantizeMatrix(translation(1)));h.coordinator.cancel();h.resolve(1);
  assert.equal(await cancelled,null);assert.equal(h.ready.length,0);
});

test('failed membership keeps the previous preview and never publishes a partial candidate',async()=>{
  let fail=false;const h=harness({prepare:async()=>{if(fail)throw Error('membership failed');return {normal:[1,0,-1]};}});
  h.begin();h.coordinator.update(translation(.2));const first=h.resolve(0);await tick();
  fail=true;h.advance(150);h.coordinator.update(translation(1));const second=h.resolve(1);await tick();
  assert.equal(h.ready.length,1);assert.equal(h.pins.get(first),1);assert.equal(h.pins.get(second),0);assert.deepEqual(h.errors,['membership failed']);
  assert.equal(await h.coordinator.finish(quantizeMatrix(translation(1))),null);
});

test('a cancelled plane preparation cannot publish, and invalid or canonical previews do not issue requests',async()=>{
  const plane=deferred(),h=harness({prepare:()=>plane.promise});
  assert.equal(h.coordinator.begin({lattice:{radius:6},point}),false);assert.equal(h.coordinator.update(translation(1)),false);
  h.begin();assert.equal(h.coordinator.update([0,0,0,0]),false);assert.equal(h.calls.length,0);
  h.coordinator.update(translation(.2));const candidate=h.resolve(0);await tick();h.coordinator.cancel();plane.resolve({normal:[1,0,-1]});await tick();
  assert.equal(h.ready.length,0);assert.equal(h.pins.get(candidate),0);
});

const executable=fileURLToPath(new URL('../lean/.lake/build/bin/polynomial_service',import.meta.url));
test('actual Lean preview stages catalogue and exact pair membership, restores on cancel, then commits only after an exact action receipt',
  {skip:!existsSync(executable)},async t=>{
  const saved={fetch:globalThis.fetch,document:globalThis.document,requestAnimationFrame:globalThis.requestAnimationFrame};
  t.after(()=>Object.assign(globalThis,saved));globalThis.document={getElementById:()=>null};globalThis.requestAnimationFrame=fn=>queueMicrotask(fn);
  globalThis.fetch=async(_url,options)=>{
    const result=spawnSync(executable,[],{input:options.body+'\n',encoding:'utf8',timeout:15000,maxBuffer:8*1024*1024});
    assert.equal(result.status,0,result.stderr||String(result.error));const value=JSON.parse(result.stdout);
    return {ok:value.ok,status:value.ok?200:400,json:async()=>value};
  };
  const accepted=await client.loadCatalogue(6,I);await client.preparePlane(point,second,accepted);client.activateCloud(accepted);
  let ready=deferred();const h=new PreviewCatalogue({minIntervalMs:0,onReady:r=>{client.setRenderCloud(r.lattice);ready.resolve(r);},onError:e=>ready.reject(e)});
  h.begin({lattice:accepted,point,second});const g=matrixFromIntegers([3,1,1,2]);h.update(g);
  const preview=await ready.promise;assert.equal(client.cloud(),accepted);assert.equal(client.diagnostics().catalogue.cacheKey,accepted.catalogue.cacheKey);
  const i=Array.from({length:preview.lattice.count},(_,i)=>i).find(i=>client.indexOfPoint(Array.from(preview.lattice.abc.slice(3*i,3*i+3)),accepted)<0);
  const previewOnly=Array.from(preview.lattice.abc.slice(3*i,3*i+3));assert.ok(client.recordFor(previewOnly));
  assert.ok(client.memberIndices(preview.plane.normal,preview.lattice).size>0);
  h.cancel();assert.equal(client.cloud(),accepted);assert.throws(()=>client.recordFor(previewOnly),/no accepted Lean data/);
  assert.equal(client.hasMembership(preview.plane.normal,preview.lattice),false);
  ready=deferred();h.begin({lattice:accepted,point,second});h.update(g);await ready.promise;
  const M=quantizeMatrix(g),release=await h.finish(M,{point,second});assert.ok(release);
  const receipt=await client.commitTransform(point,M,second);assert.deepEqual(receipt.matrix,release.matrix);assert.equal(client.cloud(),accepted);
  client.activateCloud(release.lattice);h.complete();assert.equal(client.cloud(),release.lattice);
  assert.equal(client.cachedPlane(point,second).error,undefined);
});
