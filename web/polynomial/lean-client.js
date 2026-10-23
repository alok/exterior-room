// SPDX-License-Identifier: GPL-3.0-or-later
// Exact discrete data comes only from the compiled Lean service. No algebra fallback.
export const SCHEMA='polynomial-space-v1';
export const SOURCE='ca809d2975a37a318a425e4b9dd73560b07faf39';
export const ACTION_SCHEMA='polynomial-mobius-v1';
export const ACTION_SOURCE='63ad115422ab1141ca6d06732572385414b7a5cf';
export const IDENTITY_BOUND=1024;
export const NORMAL_BOUND=4*IDENTITY_BOUND**2;
const IDENTITY_DELTA_BOUND=5*IDENTITY_BOUND**2;
// 6 B K² < 2^53 for identity bound B=1024 and unchanged matrix bound K=10^6.
const TRANSFORM_NUMERATOR_BOUND=6*IDENTITY_BOUND*1000000**2;
const kinds=['null','exterior','upper','lower'];
let serial=0, generation=0, transformGeneration=0, currentCloud=null;
const inspections=new Map(), planes=new Map(), memberships=new Map();
export function status(message,error=false){const e=document.getElementById('lean-status');if(e){e.textContent=message;e.dataset.error=String(error);}}
export async function request(body){
  const id=++serial, response=await fetch('/api/polynomial',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({...body,id}),signal:AbortSignal.timeout(15000)});
  const value=await response.json();
  if(!response.ok||value?.ok!==true)throw Error(value?.error||`Lean bridge returned ${response.status}`);
  if(value.id!==id||value.schema!==SCHEMA||value.sourceCommit!==SOURCE)throw Error('The Lean response identity or schema did not match.');
  return value;
}
const int=(n,bound)=>Number.isSafeInteger(n)&&Math.abs(n)<=bound;
const triple=(p,bound=NORMAL_BOUND)=>Array.isArray(p)&&p.length===3&&p.every(n=>int(n,bound));
const rational=q=>Array.isArray(q)&&q.length===2&&q.every(Number.isSafeInteger)&&q[1]>0;
const same=(a,b)=>a.every((n,i)=>n===b[i]);
const nonzero=p=>p.some(n=>n!==0);
const canonical=p=>nonzero(p)&&p.find(n=>n!==0)>0;
const pointInput=p=>triple(p,IDENTITY_BOUND)&&nonzero(p);
function freeze(value){if(value&&typeof value==='object'){for(const child of Object.values(value))freeze(child);Object.freeze(value);}return value;}
function classification(delta,kind,a){return delta===0?kind==='null':delta>0?kind==='exterior':a>0?kind==='upper':a<0&&kind==='lower';}
function matchesCloud(p,lattice){
  const i=indexOfPoint(p.point,lattice);if(i<0)return true;
  return p.delta===lattice.delta[i]&&p.kind===kinds[lattice.kind[i]]&&p.divisor===lattice.divisor[i]
    &&p.xyz.every((n,j)=>n===lattice.xyz[i*3+j]);
}
function validatePage(p,radius,upperOnly,offset,previous){
  if(p.radius!==radius||p.upperOnly!==upperOnly||p.offset!==offset||!int(p.total,2000000)||p.total<0||!int(p.count,16384)||p.count<0||offset+p.count>p.total)throw Error('Malformed Lean cloud header.');
  for(const [key,width,bound] of [['abc',3,96],['xyz',3,192],['delta',1,46080],['kind',1,3],['divisor',1,96]])
    if(!Array.isArray(p[key])||p[key].length!==width*p.count||!p[key].every(x=>int(x,bound)))throw Error(`Malformed Lean cloud ${key}.`);
  if(p.kind.some(x=>x<0)||p.divisor.some(x=>x<1))throw Error('Malformed Lean point classification.');
  if(p.onPlane!==null||p.necklace!==null)throw Error('Unexpected plane annotations in Lean cloud.');
  for(let i=0;i<p.count;i++){
    const j=i*3,a=p.abc[j],b=p.abc[j+1],c=p.abc[j+2],kind=kinds[p.kind[i]],d=p.divisor[i];
    if((a===0&&b===0&&c===0)||!classification(p.delta[i],kind,a)||(upperOnly&&kind!=='upper')
      ||p.xyz[j]!==-b||p.xyz[j+1]!==a+c||p.xyz[j+2]!==c-a||p.xyz.slice(j,j+3).some(n=>Math.abs(n)>radius)
      ||a%d!==0||b%d!==0||c%d!==0)throw Error('Inconsistent Lean cloud point.');
    if(previous){const cmp=a-previous[0]||c-previous[2]||b-previous[1];if(cmp<=0)throw Error('Lean cloud is not in canonical order.');}
    previous=[a,b,c];
  }
  const expected=offset+p.count===p.total?null:offset+p.count;
  if(p.nextOffset!==expected||(p.count===0&&expected!==null))throw Error('Non-progressing Lean cloud page.');
}
export async function loadCloud(radius,upperOnly=false){
  if(!int(radius,96)||radius<4||typeof upperOnly!=='boolean')throw Error('Invalid Lean cloud parameters.');
  const ticket=++generation;status(`Lean enumerating radius ${radius}…`);
  let offset=0, cloud=null;
  try{
  do{
    if(ticket!==generation)return null;
    const p=await request({op:'cloud',radius,upperOnly,offset,limit:16384});
    if(ticket!==generation)return null;
    const previous=offset?Array.from(cloud.abc.subarray(offset*3-3,offset*3)):null;
    validatePage(p,radius,upperOnly,offset,previous);
    if(!cloud)cloud={radius,upperOnly,count:p.total,abc:new Int16Array(p.total*3),xyz:new Float32Array(p.total*3),delta:new Int32Array(p.total),kind:new Uint8Array(p.total),divisor:new Uint8Array(p.total),maxInterior:0};
    if(p.total!==cloud.count)throw Error('Lean cloud changed between pages.');
    for(const key of ['abc','xyz'])cloud[key].set(p[key],offset*3);
    for(const key of ['delta','kind','divisor'])cloud[key].set(p[key],offset);
    for(const d of p.delta)cloud.maxInterior=Math.max(cloud.maxInterior,-d);
    offset=p.nextOffset;status(`Lean points ${Math.min(p.offset+p.count,p.total).toLocaleString()} / ${p.total.toLocaleString()}`);
    if(offset!==null)await new Promise(resolve=>requestAnimationFrame(resolve));
  }while(offset!==null);
  for(const inspection of inspections.values())if(!matchesCloud(inspection,cloud))throw Error('Lean cloud conflicts with a cached inspection.');
  currentCloud=cloud;memberships.clear();status(`Lean live · ${cloud.count.toLocaleString()} exact points`);return cloud;
  }catch(error){if(ticket!==generation)return null;status('Lean unavailable · previous cloud retained',true);throw error;}
}
export function cloud(){if(!currentCloud)throw Error('Lean cloud has not loaded.');return currentCloud;}
export function indexOfPoint(point,lattice=currentCloud){
  if(!lattice||!pointInput(point))return -1;let lo=0,hi=lattice.count-1;
  while(lo<=hi){const m=(lo+hi)>>1;let cmp=0;for(const j of [0,2,1]){cmp=lattice.abc[m*3+j]-point[j];if(cmp)break;}if(!cmp)return m;if(cmp<0)lo=m+1;else hi=m-1;}return -1;
}
export function recordFor(point){
  if(!pointInput(point))throw Error('Invalid Lean point lookup.');
  const cached=inspections.get(point.join());if(cached)return cached;
  const i=indexOfPoint(point);if(i<0)throw Error(`Point (${point}) has no accepted Lean data.`);
  return {point:[...point],xyz:Array.from(currentCloud.xyz.subarray(i*3,i*3+3)),delta:currentCloud.delta[i],kind:kinds[currentCloud.kind[i]],divisor:currentCloud.divisor[i]};
}
export async function inspect(point){
  if(!pointInput(point))throw Error('Invalid Lean point inspection input.');
  const submitted=[...point],key=submitted.join();if(inspections.has(key))return inspections.get(key);
  const p=await request({op:'inspect',point:submitted,height:4});
  if(!pointInput(p.point)||!same(p.point,submitted)||!triple(p.xyz,2*IDENTITY_BOUND)||!int(p.delta,IDENTITY_DELTA_BOUND)||!kinds.includes(p.kind)
    ||!classification(p.delta,p.kind,p.point[0])||typeof p.polynomial!=='string'||!p.polynomial.length||p.polynomial.length>100
    ||!int(p.divisor,IDENTITY_BOUND)||p.divisor<1||p.height!==4||!triple(p.primitive,IDENTITY_BOUND)||!canonical(p.primitive))throw Error('Malformed Lean point inspection.');
  const [a,b,c]=p.point,sign=p.point.find(n=>n!==0)<0?-1:1;
  if(!same(p.xyz,[-b,a+c,c-a])||p.primitive.some((n,i)=>sign*p.divisor*n!==p.point[i]))throw Error('Inconsistent Lean primitive or coordinates.');
  if(p.delta<0){
    const q=p.positiveRepresentative,orientation=p.kind==='lower'?-1:1;
    if(!pointInput(q)||q[0]<=0||q[2]<=0||q.some((n,i)=>n!==orientation*p.point[i]))throw Error('Malformed Lean positive representative.');
    if(!Array.isArray(p.projection)||p.projection.length!==3||!p.projection.every(rational)
      ||p.projection.some(([n,d],i)=>!int(n,8*IDENTITY_BOUND)||d>2*IDENTITY_BOUND||n*(q[0]+q[2])!==p.xyz[i]*orientation*4*d))throw Error('Malformed Lean rational projection.');
    const root=p.root;
    if(!root||!rational(root.real)||!int(root.real[0],IDENTITY_BOUND)||root.real[1]>2*IDENTITY_BOUND
      ||root.real[0]*(2*q[0])!==-q[1]*root.real[1]||!root.imaginary
      ||root.imaginary.radicand!==-p.delta||root.imaginary.denominator!==2*q[0])throw Error('Malformed Lean root descriptor.');
  }else if(p.positiveRepresentative!==null||p.projection!==null||p.root!==null)throw Error('Unexpected root data for a non-interior point.');
  if(currentCloud&&!matchesCloud(p,currentCloud))throw Error('Lean inspection conflicts with the accepted cloud.');
  inspections.set(key,freeze(p));return p;
}
export async function inspectWithRepresentative(point){
  const p=await inspect(point);
  if(p.positiveRepresentative&&!same(p.positiveRepresentative,p.point))await inspect(p.positiveRepresentative);
  return p;
}
const matrixInput=m=>Array.isArray(m)&&m.length===4&&m.every(n=>int(n,1000000));
// These checks validate a Lean receipt. They neither generate an action matrix
// nor provide transformed geometry when the service is unavailable.
function validateTransform(p,point,matrix){
  if(p.actionSchema!==ACTION_SCHEMA||p.actionSourceCommit!==ACTION_SOURCE
    ||!matrixInput(p.matrix)||!same(p.matrix,matrix)||!pointInput(p.point)||!same(p.point,point)
    ||!int(p.denominator,2000000000000)||p.denominator<=0
    ||!Array.isArray(p.coefficientRows)||p.coefficientRows.length!==9||!p.coefficientRows.every(n=>int(n,2000000000000))
    ||!triple(p.imageNumerator,TRANSFORM_NUMERATOR_BOUND)||!triple(p.xyzNumerator,TRANSFORM_NUMERATOR_BOUND)||!int(p.delta,IDENTITY_DELTA_BOUND)
    ||p.checks?.positiveDeterminant!==true||p.checks?.discriminantPreserved!==true)throw Error('Malformed Lean transform receipt.');
  const m=matrix.map(BigInt),denominator=BigInt(p.denominator),image=p.imageNumerator.map(BigInt);
  if(denominator!==m[0]*m[3]-m[1]*m[2]
    ||image.some((n,i)=>n!==point.reduce((sum,a,j)=>sum+BigInt(a)*BigInt(p.coefficientRows[3*i+j]),0n))
    ||p.xyzNumerator.some((n,i)=>BigInt(n)!==[-image[1],image[0]+image[2],image[2]-image[0]][i]))throw Error('Inconsistent Lean transform receipt.');
  const integral=image.every(n=>n%denominator===0n);
  if(integral?(!triple(p.image,TRANSFORM_NUMERATOR_BOUND)||p.image.some((n,i)=>BigInt(n)!==image[i]/denominator)):p.image!==null)throw Error('Inconsistent Lean integral image.');
  const known=inspections.get(point.join()),index=indexOfPoint(point);
  if((known&&p.delta!==known.delta)||(index>=0&&p.delta!==currentCloud.delta[index]))throw Error('Lean transform conflicts with the accepted point.');
  return p;
}
export function cancelTransformCommit(){++transformGeneration;}
export async function commitTransform(point,matrix,second){
  if(!pointInput(point)||!matrixInput(matrix)||(second!==undefined&&!pointInput(second)))throw Error('Invalid Lean transform input.');
  const submitted=[...point],submittedMatrix=[...matrix],submittedSecond=second===undefined?undefined:[...second];
  const m=submittedMatrix.map(BigInt);
  if(m[0]*m[3]-m[1]*m[2]<=0n)throw Error('Lean transform requires a positive determinant.');
  const ticket=++transformGeneration,cloudGeneration=generation;
  const current=()=>ticket===transformGeneration&&cloudGeneration===generation;
  try{
    const p=await request({op:'transform',point:submitted,matrix:submittedMatrix});
    if(!current())return null;
    validateTransform(p,submitted,submittedMatrix);
    let paired;
    if(submittedSecond){
      paired=await request({op:'transform',point:submittedSecond,matrix:submittedMatrix});
      if(!current())return null;
      validateTransform(paired,submittedSecond,submittedMatrix);
      if(p.denominator!==paired.denominator||!same(p.coefficientRows,paired.coefficientRows))throw Error('Lean pair transforms disagree on the action.');
    }
    return freeze(paired?{...p,second:paired}:p);
  }catch(error){if(!current())return null;throw error;}
}
const planeKey=(first,second)=>second?`pair:${first.join()};${second.join()}`:`normal:${first.join()}`;
const membershipKey=(l,normal)=>`${l.radius}:${l.upperOnly}:${normal.join()}`;
export function hasMembership(normal){return !!currentCloud&&triple(normal)&&memberships.has(membershipKey(currentCloud,normal));}
export function cachedPlane(first,second){const p=triple(first)&&(!second||pointInput(second))?planes.get(planeKey(first,second)):null;return p&&hasMembership(p.normal)?p:{error:'The exact Lean plane is not ready for this cloud.'};}
function endpointValue(e){
  if(!e||typeof e.label!=='string'||!e.label.length||e.label.length>100)throw Error('Malformed Lean endpoint label.');
  if(e.kind==='infinity')return Infinity;
  if(e.kind==='rational'&&int(e.numerator,NORMAL_BOUND+1000000)&&int(e.denominator,2*NORMAL_BOUND)&&e.denominator>0)return e.numerator/e.denominator;
  if(e.kind==='surd'&&int(e.p,NORMAL_BOUND)&&int(e.s,1000000)&&e.s>0&&int(e.r,1e12)&&e.r>0&&int(e.q,2*NORMAL_BOUND)&&e.q>0&&int(e.sign,1)&&Math.abs(e.sign)===1)return (e.p+e.sign*e.s*Math.sqrt(e.r))/e.q;
  throw Error('Malformed Lean endpoint descriptor.');
}
function primitiveDirection(raw,primitive){
  if(!triple(primitive)||!canonical(primitive))return false;
  const i=raw.findIndex(n=>n!==0);
  return i>=0&&primitive[i]!==0&&raw[i]%primitive[i]===0&&raw.every((n,j)=>n*primitive[i]===primitive[j]*raw[i]);
}
export async function preparePlane(first,second){
  if(!triple(first)||!nonzero(first)||(second&&(!pointInput(first)||!pointInput(second))))return {error:'Invalid Lean plane input.'};
  first=[...first];second=second?[...second]:undefined;
  const key=planeKey(first,second);let p=planes.get(key);
  if(!p){
    try{
      p=await request(second?{op:'pair',first,second}:{op:'plane',normal:first});
      const checks=second?['exterior','primitive','firstOnPlane','secondOnPlane','rawFirstOnPlane','rawSecondOnPlane']:['exterior','primitive'];
      if(!triple(p.normal)||!canonical(p.normal)||!triple(p.planeCoefficients,2*NORMAL_BOUND)||!triple(p.cartesianNormal,2*NORMAL_BOUND)
        ||typeof p.equation!=='string'||!p.equation.length||p.equation.length>100||!Array.isArray(p.endpoints)||p.endpoints.length!==2
        ||!checks.every(name=>p.checks?.[name]===true))throw Error('Malformed Lean plane.');
      const [a,b,c]=p.normal;
      if(!same(p.planeCoefficients,[-2*c,b,-2*a])||!same(p.cartesianNormal,[-b,-a-c,c-a])
        ||(second?(!primitiveDirection(first,p.firstPrimitive)||!primitiveDirection(second,p.secondPrimitive)):!primitiveDirection(first,p.normal)))throw Error('Inconsistent Lean plane identity.');
      p=freeze({...p,endpoints:p.endpoints.map(e=>({...e,value:endpointValue(e)}))});
    }catch(e){return {error:e.message};}
  }
  const l=cloud(),mk=membershipKey(l,p.normal);
  if(!memberships.has(mk)){
    const m=await request({op:'members',normal:p.normal,radius:l.radius,upperOnly:l.upperOnly});
    if(l!==currentCloud)throw Error('The Lean cloud changed while plane membership was loading.');
    if(m.radius!==l.radius||m.upperOnly!==l.upperOnly||m.total!==l.count||!int(m.count,l.count)||m.count<0
      ||!Array.isArray(m.indices)||m.indices.length!==m.count||m.indices.some((x,i)=>!int(x,l.count-1)||x<0||(i>0&&x<=m.indices[i-1])||(l.kind[x]!==2&&l.kind[x]!==3)))throw Error('Malformed Lean plane membership.');
    memberships.set(mk,new Set(m.indices));
  }
  planes.set(key,p);
  return p;
}
export function memberIndices(normal){if(!hasMembership(normal))throw Error('Lean plane membership is not ready for this cloud.');return memberships.get(membershipKey(currentCloud,normal));}
export function knownPolynomial(point){return pointInput(point)?inspections.get(point.join())?.polynomial??null:null;}
export function diagnostics(){return {schema:SCHEMA,sourceCommit:SOURCE,cloudCount:currentCloud?.count??0,cachedInspections:inspections.size,cachedPlanes:planes.size};}
