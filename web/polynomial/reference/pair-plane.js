// SPDX-License-Identifier: GPL-3.0-or-later
// Independent coefficient-space implementation of the two-root construction.
import { discriminant } from './starscape-core.js';

const gcd = (a,b) => { a=a<0n?-a:a;b=b<0n?-b:b;while(b)[a,b]=[b,a%b];return a; };
const gcd3 = p => p.reduce(gcd,0n);
const cross = (p,q) => [p[1]*q[2]-p[2]*q[1],p[2]*q[0]-p[0]*q[2],p[0]*q[1]-p[1]*q[0]];
const primitive = p => {
  const divisor=gcd3(p), sign=p.find(x=>x!==0n)<0n?-1n:1n;
  return p.map(x=>x/divisor*sign);
};
const squareRoot = n => {
  let x=n, y=(x+1n)/2n;
  while(y<x){x=y;y=(x+n/x)/2n;}return x;
};
const rational = (p,q) => {
  const d=gcd(p,q), sign=q<0n?-1n:1n;p=p/d*sign;q=q/d*sign;
  return q===1n?String(p):`${p}/${q}`;
};

export function planeEquation([a,b,c]) {
  const terms=[];
  for(const [coefficient,variable] of [[-2*c,'a'],[b,'b'],[-2*a,'c']]) {
    if(!coefficient)continue;
    const magnitude=Math.abs(coefficient), term=`${magnitude===1?'':magnitude}${variable}`;
    terms.push(`${coefficient<0?'−':terms.length?'+':''}${term}`);
  }
  return `${terms.join(' ')} = 0`;
}

export function pairPlane(first,second) {
  for(const p of [first,second]) {
    if(!Array.isArray(p)||p.length!==3||!p.every(Number.isSafeInteger))return {error:'Use integer coefficient triples.'};
    const [a,b,c]=p.map(BigInt);
    if(b*b-4n*a*c>=0n)return {error:'Pair two complex-root points inside the cone (Δ < 0).'};
  }
  const p=first.map(BigInt), q=second.map(BigInt);
  // The normal polynomial n satisfies B_n(p) = n_b b − 2n_a c − 2n_c a = 0.
  const dual=([a,b,c])=>[-2n*c,b,-2n*a], raw=cross(dual(p),dual(q));
  if(raw.every(x=>x===0n))return {error:'These triples have the same primitive direction and root. Choose a different root.'};
  const plane=planeFromNormal(raw);
  if(plane.error)return plane;
  return {...plane,firstPrimitive:primitive(p).map(Number),secondPrimitive:primitive(q).map(Number)};
}

// Lorentz-orthogonal plane of a normal n = (A,B,C) with Δ_n > 0: −2C·a + B·b − 2A·c = 0. Its geodesic
// endpoints are the real roots of A t² + B t + C. Selecting an exterior triple in Stange's viewer uses
// that triple as n; a pair of interior stars uses the cross product of their duals.
export function planeFromNormal(normalInput) {
  const raw=normalInput.map(BigInt);
  if(raw.every(x=>x===0n))return {error:'The zero triple has no plane.'};
  const n=primitive(raw), [a,b,c]=n, delta=b*b-4n*a*c;
  if(delta<=0n)return {error:'These directions do not define a real geodesic.'};
  if(n.some(x=>x>BigInt(Number.MAX_SAFE_INTEGER)||x<-BigInt(Number.MAX_SAFE_INTEGER))||delta>BigInt(Number.MAX_SAFE_INTEGER))return {error:'This pair is too large for the finite renderer.'};
  let endpoints;
  if(a===0n) endpoints=[{label:rational(-c,b),value:Number(-c)/Number(b)},{label:'∞',value:Infinity}];
  else {
    const root=squareRoot(delta), exact=root*root===delta;
    endpoints=[-1n,1n].map(sign=>({
      label:exact?rational(-b+sign*root,2n*a):surd(-b,sign,delta,2n*a),
      value:(-Number(b)+Number(sign)*Math.sqrt(Number(delta)))/(2*Number(a))
    }));
  }
  const normal=n.map(Number);
  return {normal,equation:planeEquation(normal),endpoints};
}
// (p ± √d)/q with d = s²·r (r squarefree) written as (p' ± s'√r)/q' in lowest terms, e.g. −4 + √17.
function surd(p,sign,d,q){
  let s=1n,r=d;
  for(let f=2n;f*f<=r;f++)while(r%(f*f)===0n){r/=f*f;s*=f;}
  const g=gcd(gcd(p,s),q), sg=q<0n?-1n:1n;p=p/g*sg;s=s/g;q=q/g*sg;
  const radical=`${s===1n?'':s}√${r}`, head=p===0n?(sign<0n?'−':''):`${p}`.replace('-','−')+(sign<0n?' − ':' + ');
  const body=`${head}${radical}`;
  return q===1n?body:`(${body})/${q}`;
}

export function inPairPlane(normal,point) {
  const [a,b,c]=point.map(BigInt),[A,B,C]=normal.map(BigInt);
  return -2n*C*a+B*b-2n*A*c===0n;
}

export function coneDirections(plane) {
  return plane.endpoints.map(({value})=>{
    if(!Number.isFinite(value))return [0,1,1];
    const angle=2*Math.atan(value);return [Math.sin(angle),1,-Math.cos(angle)];
  });
}

// Finite display patch, clipped by |Y| ≤ radius and X²+Z² ≤ radius².
export function planeSection(normal,radius,segments=64) {
  const [A,B,C]=normal, [x,y,z]=[-B,-A-C,C-A];
  const horizontal=Math.hypot(x,z),length=Math.hypot(x,y,z);
  const u=[-z/horizontal,0,x/horizontal];
  const v=[-x*y/(horizontal*length),horizontal/length,-z*y/(horizontal*length)];
  return Array.from({length:segments+1},(_,i)=>{
    const angle=i/segments*2*Math.PI,d=u.map((q,j)=>q*Math.cos(angle)+v[j]*Math.sin(angle));
    const scale=radius/Math.max(Math.abs(d[1]),Math.hypot(d[0],d[2]));
    return d.map(q=>q*scale);
  });
}

export const necklaceMembers = (plane,points) => points.filter(p=>discriminant(p)<0&&inPairPlane(plane.normal,p));
