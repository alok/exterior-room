import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {prepareAbsorption} from '../web/polynomial/mobius-absorb.js';

const SOURCE='ca809d2975a37a318a425e4b9dd73560b07faf39';
const copy=x=>structuredClone(x);
const rows=[
  {abc:[-1,0,-1],xyz:[0,-2,0],delta:-4,kind:3,divisor:1},
  {abc:[0,1,0],xyz:[-1,0,0],delta:1,kind:1,divisor:1},
  {abc:[0,0,1],xyz:[0,1,1],delta:0,kind:0,divisor:1},
  {abc:[1,0,1],xyz:[0,2,0],delta:-4,kind:2,divisor:1},
];
function page(request,offset=0,count=4){
  const selected=rows.slice(offset,offset+count),end=offset+selected.length;
  return {radius:request.radius,upperOnly:request.upperOnly,offset,count:selected.length,total:4,
    nextOffset:end===4?null:end,abc:selected.flatMap(r=>r.abc),xyz:selected.flatMap(r=>r.xyz),
    delta:selected.map(r=>r.delta),kind:selected.map(r=>r.kind),divisor:selected.map(r=>r.divisor),onPlane:null,necklace:null};
}
const upper={point:[3,-1,3],xyz:[1,6,0],delta:-35,kind:'upper',divisor:1,primitive:[3,-1,3],
  polynomial:'3x²−x+3',height:4,positiveRepresentative:[3,-1,3],projection:[[2,3],[4,1],[0,1]],root:{real:[1,6],imaginary:{radicand:35,denominator:6}}};
const lower={...copy(upper),point:[-3,1,-3],xyz:[-1,-6,0],kind:'lower',polynomial:'−3x²+x−3'};
const unit={point:[1,0,1],xyz:[0,2,0],delta:-4,kind:'upper',divisor:1,primitive:[1,0,1],
  polynomial:'x²+1',height:4,positiveRepresentative:[1,0,1],projection:[[0,1],[4,1],[0,1]],root:{real:[0,1],imaginary:{radicand:4,denominator:2}}};
const exterior={point:[0,1,0],xyz:[-1,0,0],delta:1,kind:'exterior',divisor:1,primitive:[0,1,0],
  polynomial:'x',height:4,positiveRepresentative:null,projection:null,root:null};
const plane={normal:[0,1,0],planeCoefficients:[0,1,0],cartesianNormal:[-1,0,0],equation:'b = 0',
  endpoints:[{kind:'rational',numerator:0,denominator:1,label:'0'},{kind:'infinity',label:'∞'}],checks:{exterior:true,primitive:true}};
const members=request=>({radius:request.radius,upperOnly:request.upperOnly,total:4,count:2,indices:[0,3]});
// Canonical source drag fixture: i → 1+i, M=[[3,1],[1,2]], g=M/√5.
const transform={actionSchema:'polynomial-mobius-v1',actionSourceCommit:'63ad115422ab1141ca6d06732572385414b7a5cf',
  matrix:[3,1,1,2],denominator:5,coefficientRows:[4,-2,1,-4,7,-6,1,-3,9],
  point:[1,0,1],imageNumerator:[5,-10,10],xyzNumerator:[10,15,5],image:[1,-2,2],delta:-4,
  checks:{positiveDeterminant:true,discriminantPreserved:true}};
const upperTransform={...copy(transform),point:upper.point,imageNumerator:[17,-37,33],xyzNumerator:[37,50,16],image:null,delta:-35};
function deferred(){let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};}
const tick=()=>new Promise(resolve=>setImmediate(resolve));
let sequence=0;
async function setup(t,handler,{frames}={}){
  const old={fetch:globalThis.fetch,document:globalThis.document,requestAnimationFrame:globalThis.requestAnimationFrame};
  const status={textContent:'',dataset:{}};
  globalThis.document={getElementById:id=>id==='lean-status'?status:null};
  globalThis.requestAnimationFrame=callback=>frames?frames.push(callback):queueMicrotask(()=>callback(0));
  globalThis.fetch=async(_url,options)=>{
    const request=JSON.parse(options.body),result=await handler(request);
    return {ok:result?.ok!==false,status:result?.ok===false?400:200,
      json:async()=>({ok:true,id:request.id,schema:'polynomial-space-v1',sourceCommit:SOURCE,...copy(result)})};
  };
  t.after(()=>Object.assign(globalThis,old));
  const client=await import(`../web/polynomial/lean-client.js?test=${++sequence}`);
  return {client,status};
}

test('lower out-of-crop inspection awaits and caches its positive representative',async t=>{
  const calls=[];
  const {client}=await setup(t,request=>{
    calls.push(request);
    if(request.op==='cloud')return page(request);
    return request.point[0]<0?lower:upper;
  });
  await client.loadCloud(4);
  const result=await client.inspectWithRepresentative(lower.point);
  assert.deepEqual(result.point,lower.point);
  assert.deepEqual(calls.filter(r=>r.op==='inspect').map(r=>r.point),[lower.point,upper.point]);
  assert.equal(client.indexOfPoint(upper.point),-1);
  assert.deepEqual(client.recordFor(upper.point).root,upper.root);
  assert.equal(client.recordFor(lower.point).polynomial,lower.polynomial);
  assert.equal(client.knownPolynomial(['3',-1,3]),null);
  assert.ok(Object.isFrozen(client.recordFor(upper.point).root));
});

test('representative failure preserves signed inspection and a retry fills only missing data',async t=>{
  let fail=true;const calls=[];
  const {client}=await setup(t,request=>{
    calls.push(request.point);if(request.point[0]>0&&fail)throw Error('Lean unavailable');
    return request.point[0]<0?lower:upper;
  });
  await assert.rejects(client.inspectWithRepresentative(lower.point),/unavailable/);
  assert.equal(client.knownPolynomial(lower.point),lower.polynomial);
  assert.throws(()=>client.recordFor(upper.point),/no accepted Lean data/);
  fail=false;await client.inspectWithRepresentative(lower.point);
  assert.deepEqual(calls,[lower.point,upper.point,upper.point]);
});

test('inspection rejects malformed root, representative and primitive metadata before caching',async t=>{
  let corrupt;
  const {client}=await setup(t,()=>{const result=copy(upper);corrupt(result);return result;});
  for(const change of [
    r=>r.root=null,r=>r.root.real=[1,0],r=>r.root.real=[2,6],r=>r.root.imaginary.radicand=36,
    r=>r.root.imaginary.denominator='6',r=>r.positiveRepresentative=[-3,1,-3],r=>r.positiveRepresentative=null,
    r=>r.primitive=[1,0,1],r=>r.primitive=[-3,1,-3],r=>r.divisor=0,r=>r.projection[0]=[4,3],r=>r.height=5,
  ]){
    corrupt=change;await assert.rejects(client.inspect(upper.point));
    assert.equal(client.diagnostics().cachedInspections,0);
  }
  corrupt=()=>{};await client.inspect(upper.point);
  assert.equal(client.diagnostics().cachedInspections,1);
});

test('non-interior inspections require null root, projection and representative',async t=>{
  const {client}=await setup(t,()=>({...exterior,root:copy(unit.root)}));
  await assert.rejects(client.inspect(exterior.point),/Unexpected root data/);
});

test('request coordinates are fixed before the caller mutates its array',async t=>{
  const gate=deferred();let submitted;
  const {client}=await setup(t,request=>{submitted=request;return gate.promise;});
  const point=[...upper.point],pending=client.inspect(point);point[0]=99;
  gate.resolve(upper);await pending;
  assert.deepEqual(submitted.point,upper.point);
  assert.throws(()=>client.recordFor([NaN,0,1]),/Invalid Lean point/);
  assert.equal(client.indexOfPoint([NaN,0,1]),-1);
});

test('cloud lookups accept canonical pages and reject unordered or duplicate points',async t=>{
  let corrupt=false;
  const {client}=await setup(t,request=>{
    const result=page(request);
    if(corrupt){result.abc.splice(3,3,...result.abc.slice(0,3));result.xyz.splice(3,3,...result.xyz.slice(0,3));result.delta[1]=-4;result.kind[1]=3;}
    return result;
  });
  const accepted=await client.loadCloud(4);
  assert.equal(client.indexOfPoint([0,0,1]),2);
  corrupt=true;await assert.rejects(client.loadCloud(6),/canonical order/);
  assert.equal(client.cloud(),accepted);
});

test('cloud validation rejects classification, geometry and inspection-cache conflicts',async t=>{
  let corrupt;
  const {client}=await setup(t,request=>{if(request.op==='inspect')return unit;const result=page(request);corrupt(result);return result;});
  await client.inspect(unit.point);
  for(const change of [r=>r.xyz[0]=1,r=>r.kind[0]=2,r=>r.divisor[0]=2,r=>r.delta[3]=-5,r=>r.onPlane=[]]){
    corrupt=change;await assert.rejects(client.loadCloud(4));
    assert.equal(client.diagnostics().cloudCount,0);
  }
});

test('an obsolete request failure cannot replace a newer accepted cloud or status',async t=>{
  const old=deferred();
  const {client,status}=await setup(t,request=>request.radius===4?old.promise:page(request));
  const earlier=client.loadCloud(4);const newer=await client.loadCloud(6);
  const liveStatus=status.textContent;old.reject(Error('old request failed'));
  assert.equal(await earlier,null);assert.equal(client.cloud(),newer);
  assert.equal(status.textContent,liveStatus);assert.equal(status.dataset.error,'false');
});

test('a superseded load paused at RAF does not send another stale page',async t=>{
  const frames=[],calls=[];
  const {client}=await setup(t,request=>{calls.push(request);return request.radius===4?page(request,0,2):page(request);},{frames});
  const earlier=client.loadCloud(4);await tick();assert.equal(frames.length,1);
  const newer=await client.loadCloud(6);frames[0](0);
  assert.equal(await earlier,null);assert.equal(client.cloud(),newer);
  assert.equal(calls.filter(r=>r.radius===4).length,1);
});

test('wrong page identity or changing total cannot publish a partial cloud',async t=>{
  let corrupt=false;
  const {client}=await setup(t,request=>{
    if(!corrupt)return page(request);
    if(request.offset===0)return page(request,0,2);
    return {...page(request,2,2),total:5,nextOffset:4};
  });
  const accepted=await client.loadCloud(4);corrupt=true;
  await assert.rejects(client.loadCloud(6),/changed between pages/);
  assert.equal(client.cloud(),accepted);
});

test('members must match cloud identity, count and interior ordered indices',async t=>{
  let corrupt;
  const {client}=await setup(t,request=>{
    if(request.op==='cloud')return page(request);if(request.op==='plane')return plane;
    const result=members(request);corrupt(result);return result;
  });
  await client.loadCloud(4);
  assert.equal(client.hasMembership(plane.normal),false);
  assert.throws(()=>client.memberIndices(plane.normal),/not ready/);
  for(const change of [r=>r.radius=6,r=>r.upperOnly=true,r=>r.total=5,r=>r.count=3,r=>r.indices=[3,0],r=>r.indices=[0,0],r=>r.indices=[0,1]]){
    corrupt=change;await assert.rejects(client.preparePlane(plane.normal),/Malformed Lean plane membership/);
    assert.equal(client.hasMembership(plane.normal),false);assert.ok(client.cachedPlane(plane.normal).error);
  }
  corrupt=()=>{};await client.preparePlane(plane.normal);
  assert.deepEqual([...client.memberIndices(plane.normal)],[0,3]);
  assert.ok(client.cachedPlane([0,'1',0]).error);
  await client.loadCloud(6);assert.ok(client.cachedPlane(plane.normal).error);
});

test('membership from a replaced cloud cannot become ready even for the same radius',async t=>{
  const gate=deferred();let captured;
  const {client}=await setup(t,request=>{
    if(request.op==='cloud')return page(request);if(request.op==='plane')return plane;
    captured=request;return gate.promise;
  });
  await client.loadCloud(4);const pending=client.preparePlane(plane.normal);await tick();
  await client.loadCloud(4);gate.resolve(members(captured));
  await assert.rejects(pending,/cloud changed/);
  assert.equal(client.hasMembership(plane.normal),false);assert.ok(client.cachedPlane(plane.normal).error);
});

test('a valid empty membership is distinct from membership not yet loaded',async t=>{
  const {client}=await setup(t,request=>request.op==='cloud'?page(request):request.op==='plane'?plane:{...members(request),count:0,indices:[]});
  await client.loadCloud(4);await client.preparePlane(plane.normal);
  assert.equal(client.hasMembership(plane.normal),true);assert.equal(client.memberIndices(plane.normal).size,0);
});

test('plane requires named checks, exact identity and typed endpoint descriptors',async t=>{
  let corrupt;
  const {client}=await setup(t,request=>{
    if(request.op==='cloud')return page(request);if(request.op==='members')return members(request);
    const result=copy(plane);corrupt(result);return result;
  });
  await client.loadCloud(4);
  for(const change of [r=>r.checks={},r=>r.cartesianNormal=[1,0,0],r=>r.normal=[0,2,0],r=>r.endpoints[0].denominator=0,
    r=>r.endpoints[0]={kind:'surd',p:0,sign:'1',s:1,r:2,q:1,label:'√2'}]){
    corrupt=change;assert.ok((await client.preparePlane(plane.normal)).error);assert.equal(client.diagnostics().cachedPlanes,0);
  }
});

test('transform commits only a complete immutable Lean receipt for the submitted point and matrix',async t=>{
  const calls=[];
  const {client}=await setup(t,request=>{calls.push(request);return request.point[0]===1?transform:upperTransform;});
  const accepted=await client.commitTransform(unit.point,transform.matrix,upper.point);
  assert.deepEqual(accepted.image,[1,-2,2]);assert.equal(accepted.denominator,5);
  assert.deepEqual(accepted.second.imageNumerator,[17,-37,33]);assert.equal(accepted.second.image,null);
  assert.deepEqual(calls.map(r=>({op:r.op,point:r.point,matrix:r.matrix})),[
    {op:'transform',point:unit.point,matrix:transform.matrix},{op:'transform',point:upper.point,matrix:transform.matrix},
  ]);
  assert.ok(Object.isFrozen(accepted.coefficientRows));assert.ok(Object.isFrozen(accepted.second));
});

test('transform validates bounds before contacting Lean and never manufactures a fallback',async t=>{
  let calls=0;
  const {client}=await setup(t,()=>{calls++;throw Error('Lean unavailable');});
  for(const bad of [[1,0,0,0],[1,0,0,-1],[1e6+1,0,0,1],[1,true,0,1],[1.1,0,0,1],[1,0,1],null])
    await assert.rejects(client.commitTransform(unit.point,bad),/Invalid Lean|positive determinant/);
  for(const bad of [[0,0,0],[1025,0,1],[1,'0',1]])await assert.rejects(client.commitTransform(bad,transform.matrix),/Invalid Lean/);
  assert.equal(calls,0);
  await assert.rejects(client.commitTransform(unit.point,transform.matrix),/Lean unavailable/);
  assert.equal(calls,1);
});

test('transform rejects malformed identities, missing checks and inconsistent exact certificates',async t=>{
  let corrupt;
  const {client}=await setup(t,()=>{const result=copy(transform);corrupt(result);return result;});
  for(const change of [
    r=>r.id=-1,r=>r.sourceCommit='other',r=>r.actionSchema='other',r=>r.actionSourceCommit='other',
    r=>r.point=[1,1,1],r=>r.matrix=[3,2,1,2],r=>r.denominator=6,r=>r.denominator='5',
    r=>r.coefficientRows.pop(),r=>r.coefficientRows[0]=2e12+1,r=>r.coefficientRows[0]=5,
    r=>r.imageNumerator[0]++,r=>r.xyzNumerator[0]++,r=>r.image=null,r=>r.image[0]=2,
    r=>r.checks={},r=>r.checks.discriminantPreserved='true',r=>r.delta=Number.NaN,
  ]){corrupt=change;await assert.rejects(client.commitTransform(unit.point,transform.matrix));}
  corrupt=()=>{};assert.deepEqual((await client.commitTransform(unit.point,transform.matrix)).image,transform.image);
});

test('a rational transform cannot claim an integral image or conflict with accepted point metadata',async t=>{
  let corrupt;
  const {client}=await setup(t,request=>{
    if(request.op==='inspect')return upper;
    const result=copy(upperTransform);corrupt(result);return result;
  });
  await client.inspect(upper.point);
  for(const change of [r=>r.image=[3,-7,6],r=>r.delta=-36]){
    corrupt=change;await assert.rejects(client.commitTransform(upper.point,transform.matrix),/integral image|accepted point/);
  }
});

test('superseded transform responses and failures cannot commit over a newer gesture',async t=>{
  const old=deferred();let calls=0;
  const {client}=await setup(t,()=>++calls===1?old.promise:upperTransform);
  const earlier=client.commitTransform(unit.point,transform.matrix);
  const accepted=await client.commitTransform(upper.point,transform.matrix);
  assert.deepEqual(accepted.point,upper.point);
  old.resolve({...transform,denominator:0});assert.equal(await earlier,null);
  const failed=deferred();globalThis.fetch=async()=>failed.promise;
  const pending=client.commitTransform(unit.point,transform.matrix);
  client.cancelTransformCommit();failed.reject(Error('obsolete unavailable'));
  assert.equal(await pending,null);
});

test('reset, crop changes and paired failure leave no partial accepted transform',async t=>{
  const gate=deferred();let calls=0;
  const {client}=await setup(t,request=>{
    if(request.op==='cloud')return page(request);
    calls++;return calls===1?transform:gate.promise;
  });
  const pending=client.commitTransform(unit.point,transform.matrix,upper.point);
  await tick();assert.equal(calls,2);
  await client.loadCloud(4);gate.resolve(upperTransform);assert.equal(await pending,null);
  globalThis.fetch=async(_url,options)=>{
    const request=JSON.parse(options.body);if(request.point[0]===3)throw Error('second unavailable');
    return {ok:true,json:async()=>({...copy(transform),ok:true,id:request.id,schema:client.SCHEMA,sourceCommit:SOURCE})};
  };
  await assert.rejects(client.commitTransform(unit.point,transform.matrix,upper.point),/second unavailable/);
});

test('transform snapshots caller inputs and checks both receipts use the same action',async t=>{
  const gate=deferred();let submitted;
  const {client}=await setup(t,request=>{submitted=request;return gate.promise;});
  const point=[...unit.point],matrix=[...transform.matrix];
  const pending=client.commitTransform(point,matrix);point[0]=96;matrix[0]=4;
  gate.resolve(transform);assert.deepEqual((await pending).matrix,transform.matrix);
  assert.deepEqual(submitted.point,unit.point);assert.deepEqual(submitted.matrix,transform.matrix);
  let calls=0;
  globalThis.fetch=async(_url,options)=>{
    const request=JSON.parse(options.body),result=copy(++calls===1?transform:upperTransform);
    // A different action can happen to agree on this selected point.
    if(calls===2){result.coefficientRows[0]++;result.coefficientRows[2]--;}
    return {ok:true,json:async()=>({...result,ok:true,id:request.id,schema:client.SCHEMA,sourceCommit:SOURCE})};
  };
  await assert.rejects(client.commitTransform(unit.point,transform.matrix,upper.point),/disagree on the action/);
});

const executable=fileURLToPath(new URL('../lean/.lake/build/bin/polynomial_service',import.meta.url));
test('actual compiled Lean responses pass inspection, cloud, plane and transform validation',
  {skip:!existsSync(executable)},async t=>{
  const {client}=await setup(t,request=>{
    const result=spawnSync(executable,[],{input:JSON.stringify(request)+'\n',encoding:'utf8',timeout:15000,maxBuffer:2*1024*1024});
    assert.equal(result.status,0,result.stderr||String(result.error));
    return JSON.parse(result.stdout);
  });
  const lattice=await client.loadCloud(6);assert.equal(lattice.count,480);
  const selected=await client.inspectWithRepresentative(lower.point);
  assert.deepEqual(selected.root,lower.root);assert.deepEqual(client.recordFor(upper.point).projection,upper.projection);
  const exactPair=await client.preparePlane([1,0,1],[1,1,1]);
  assert.deepEqual(exactPair.normal,[1,0,-1]);assert.ok(client.memberIndices(exactPair.normal).size>0);
  const irrational=await client.preparePlane([1,0,-2]);
  assert.equal(irrational.endpoints[0].kind,'surd');
  assert.deepEqual(irrational.endpoints.map(e=>e.value),[-Math.sqrt(2),Math.sqrt(2)]);
  await client.loadCloud(6,true);assert.equal(client.hasMembership(exactPair.normal),false);
  const drag=await client.commitTransform([1,-1,2],[3,1,1,2],[-1,1,-2]);
  assert.equal(drag.denominator,5);assert.equal(drag.image,null);
  assert.deepEqual(drag.coefficientRows,[4,-2,1,-4,7,-6,1,-3,9]);
  assert.deepEqual(drag.imageNumerator,[8,-23,22]);assert.deepEqual(drag.xyzNumerator,[23,30,14]);
  assert.deepEqual(drag.second.imageNumerator,[-8,23,-22]);
  const translation=await client.commitTransform([1,0,1],[1,1,0,1]);
  assert.deepEqual(translation.image,[1,-2,2]);
  const inversion=await client.commitTransform([1,-1,2],[0,-1,1,0]);
  assert.deepEqual(inversion.image,[2,1,1]);
  const boundary=await client.commitTransform([-1024,1024,1024],[1000000,-1000000,1000000,1000000]);
  assert.equal(boundary.denominator,2e12);assert.deepEqual(boundary.image,[-512,-2048,512]);
  const smallDeterminant=await client.commitTransform([-1024,1024,1024],[999999,999998,1000000,999999]);
  assert.equal(smallDeterminant.denominator,1);assert.ok(smallDeterminant.image.every(Number.isSafeInteger));
});

test('real Lean absorption accepts the source T⁴ seed and paired identity outside the R96 crop',
  {skip:!existsSync(executable)},async t=>{
  const {client}=await setup(t,request=>{
    const result=spawnSync(executable,[],{input:JSON.stringify(request)+'\n',encoding:'utf8',timeout:15000,maxBuffer:2*1024*1024});
    assert.equal(result.status,0,result.stderr||String(result.error));return JSON.parse(result.stdout);
  });
  const lattice=await client.loadCloud(6);
  const previous={point:[13,20,34],second:[1,0,1],action:[1,4,0,1]},snapshot=copy(previous);
  const accepted=await prepareAbsorption({matrix:previous.action,point:previous.point,second:previous.second,
    commit:client.commitTransform,inspect:client.inspectWithRepresentative,preparePair:client.preparePlane,isCurrent:()=>true});
  assert.deepEqual(previous,snapshot);assert.deepEqual(accepted.point,[13,-84,162]);assert.deepEqual(accepted.second,[1,-8,17]);
  assert.deepEqual(accepted.plane.normal,[10,-59,66]);assert.equal(client.recordFor(accepted.point).delta,-1368);
  assert.equal(client.indexOfPoint(accepted.point),-1);assert.equal(client.cloud(),lattice);assert.equal(lattice.count,480);
  const identity=await client.commitTransform(accepted.point,[1,0,0,1],accepted.second);
  assert.deepEqual(identity.image,accepted.point);assert.deepEqual(identity.second.image,accepted.second);
  const largePlane=await client.preparePlane([957,361,180],[983,640,735]);
  assert.deepEqual(largePlane.normal,[257617,1052910,150135]);assert.ok(client.hasMembership(largePlane.normal));
  const rejected=await client.preparePlane([664,713,945],[725,-705,1009]);
  assert.match(rejected.error,/bounded endpoint service/);
});

test('real Lean out-of-bound images on either side preserve the complete absorption input',
  {skip:!existsSync(executable)},async t=>{
  const calls=[];
  const {client}=await setup(t,request=>{
    calls.push(request);const result=spawnSync(executable,[],{input:JSON.stringify(request)+'\n',encoding:'utf8',timeout:15000,maxBuffer:2*1024*1024});
    assert.equal(result.status,0,result.stderr||String(result.error));return JSON.parse(result.stdout);
  });
  for(const [point,second,matrix] of [
    [[13,20,34],[1,0,1],[1,10,0,1]],[[1,0,1],[13,20,34],[1,10,0,1]],
    [[-400,400,-400],[1,0,1],[1,1,0,1]],[[1,0,1],[-400,400,-400],[1,1,0,1]],
  ]){
    const input={point,second,matrix},before=copy(input),start=calls.length;
    await assert.rejects(prepareAbsorption({...input,commit:client.commitTransform,inspect:client.inspectWithRepresentative,
      preparePair:client.preparePlane,isCurrent:()=>true}),/±1024/);
    assert.deepEqual(input,before);assert.deepEqual(calls.slice(start).map(r=>r.op),['transform','transform']);
  }
});
