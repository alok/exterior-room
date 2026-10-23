// SPDX-License-Identifier: GPL-3.0-or-later
// Renderer-only projection/appearance from the audited Starscape source bundle
// f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b:
// Fe(), Ie(), an(), $t(), and the packed-body .06 picking threshold. This is
// floating renderer math, not a Lean theorem or an alternate identity service.
// Display basis B(a,b,c)=(-b,a+c,c-a); radial projection commutes with the source
// viewer's X/Z sign reversal. Inputs remain unprojected transformed coordinates.
import {catalogueFade,catalogueOpacity,sourceRootVisible} from './catalogue-display.js';

export const sourcePickAlpha=.06;
const clamp01=x=>Math.min(1,Math.max(0,x));
const upper=kind=>kind===2||kind==='upper';
const nullKind=kind=>kind===0||kind==='null';
const isSource=lattice=>lattice.catalogue?.kind==='source';

function projectionOptions(progress,height){
  if(!Number.isFinite(progress)||!Number.isFinite(height)||height<=0)throw new RangeError('Source projection requires finite progress and positive height');
  return clamp01(progress);
}

/** A selected/paired marker follows its signed upper form even when its star
 * has faded out. Never test primitiveness or crop membership in this helper. */
export function sourceProjectionPoint(xyz,kind,progress,height,out=new Array(3)){
  const p=projectionOptions(progress,height),y=xyz[1];
  const j=upper(kind)&&p>0?1+(height/y-1)*p:1;
  out[0]=xyz[0]*j;out[1]=y*j;out[2]=xyz[2]*j;
  return out;
}

/** Base-order world positions for ray picking; root charts and crop opacity
 * must use the original xyz buffer. Reuse out during animation. */
export function sourceProjectionPositions(lattice,xyz,{progress=0,height=.6*(lattice.catalogue?.depth??1)}={},out=new Float32Array(3*lattice.count)){
  if(xyz.length<3*lattice.count||out.length!==3*lattice.count)throw new RangeError('Source projection buffers have the wrong size');
  const p=projectionOptions(progress,height),enabled=isSource(lattice);
  if(enabled&&(out===xyz||(out.buffer&&out.buffer===xyz.buffer&&out.byteOffset<xyz.byteOffset+xyz.byteLength&&xyz.byteOffset<out.byteOffset+out.byteLength)))throw new RangeError('Source world projection needs a separate output buffer');
  for(let i=0,k=0;i<lattice.count;i++,k+=3){
    const y=xyz[k+1],j=enabled&&lattice.kind[i]===2&&p>0?1+(height/y-1)*p:1;
    out[k]=xyz[k]*j;out[k+1]=y*j;out[k+2]=xyz[k+2]*j;
  }
  return out;
}

/** Source physical star radius in coefficient display units. Multiply by the
 * cloud's world scale before perspective raster sizing. Selection rings keep
 * their own alpha and minimum size; this does not decide marker visibility. */
export function sourceWorldRadius(delta,kind,divisor,y,{progress=0,height=1,eye=0,whole=1,sigma=1,focusEnabled=false,onPlane=false}={}){
  const p=projectionOptions(progress,height),e=clamp01(eye),w=clamp01(whole);
  let radius;
  if(upper(kind)){
    const q=Math.fround(Math.pow(-delta,.25)),d=.06*sigma*q/(y*Math.sqrt(y)),f=.15*sigma*(divisor===1?1:.72);
    radius=(1-p)*((1-e)*f+e*d*y)+p*d*height;
    if(focusEnabled&&onPlane)radius*=1+.35*(1-e)*(1-p);
  }else{
    const base=nullKind(kind)?.09:.075,rEye=(1-e)*base+e*(.01*Math.abs(y)+.004);
    radius=(1-w)*rEye+w*.15*sigma;
    if(focusEnabled&&onPlane)radius=.12;
  }
  return Math.fround(radius);
}

// No per-point allocations in the dense mask path. Crop/Euclidean distance and
// final body alpha use the source's Float32 packing before the picker compares.
function opacityAt(lattice,xyz,index,p,height,eye,whole,dust,screen,light,focusEnabled,onPlane){
  const k=3*index,y=xyz[k+1],kind=lattice.kind[index],crop=Math.fround(catalogueOpacity(lattice,xyz,index));
  if(!(crop>0))return 0;
  const base=light?.36:.45;
  let alpha;
  if(kind===2){
    const v=focusEnabled?(onPlane?2:(light?.32:.26)):1;
    let start=v>=1?base+(.95-base)*eye:v;
    const rho=Math.fround(Math.hypot(xyz[k],y,xyz[k+2]));
    start*=1-whole*(1-catalogueFade(rho,Math.round(.4*lattice.catalogue.depth)));
    const screenWeight=screen?1-eye:0;
    if(screenWeight>.001)start*=1-.75*screenWeight*clamp01((y-height)/3+.5)*(1-eye);
    alpha=crop*((1-p)*start+p*(v>=1?.95:v));
    if(lattice.divisor[index]!==1)alpha*=1-p;
  }else{
    const dustAlpha=dust?(light?.5:.42)*(kind===0?1.5:kind===1?1:.8)*(1-.6*eye):0;
    alpha=crop*((1-whole)*dustAlpha+whole*base*(1-eye));
    if(focusEnabled&&onPlane)alpha=crop*.9;
  }
  return Math.fround(Math.min(1,alpha));
}

function appearanceOptions(lattice,options){
  const {progress=0,height=.6*lattice.catalogue.depth,eye=0,whole=lattice.catalogue.whole===false?0:1,dust=lattice.catalogue.dust??false,screen=true,light=false,focusEnabled=false,planeMask=null}=options;
  return [projectionOptions(progress,height),height,clamp01(eye),clamp01(whole),dust,screen,light,focusEnabled,planeMask];
}

/** Packed source body alpha, before raster footprint/fog. Canonical appearance
 * is unchanged. An optional exact planeMask preserves base signed identities. */
export function sourceWorldOpacity(lattice,xyz,index,options={}){
  if(!isSource(lattice))return 1;
  const [p,h,e,w,d,s,l,f,mask]=appearanceOptions(lattice,options);
  return opacityAt(lattice,xyz,index,p,h,e,w,d,s,l,f,!!mask?.[index]);
}

/** Source picking excludes body alpha below .06, including most source-buffer
 * padding in Whole mode at lift. Root charts use catalogueVisibility instead. */
export function sourceWorldVisibility(lattice,xyz,options={},out=new Uint8Array(lattice.count)){
  if(out.length!==lattice.count||xyz.length<3*lattice.count)throw new RangeError('Source visibility buffers have the wrong size');
  if(!isSource(lattice)){out.fill(1);return out;}
  const [p,h,e,w,d,s,l,f,mask]=appearanceOptions(lattice,options);
  if(mask&&mask.length!==lattice.count)throw new RangeError('Source plane mask has the wrong size');
  for(let i=0;i<lattice.count;i++)out[i]=opacityAt(lattice,xyz,i,p,h,e,w,d,s,l,f,!!mask?.[i])>=sourcePickAlpha?1:0;
  return out;
}

/** Exact integer incidence for renderer focus only: -2C*a+B*b-2A*c=0.
 * This also covers null/exterior/lower forms, which the service's interior-only
 * necklace list omits. It is not a Lean proof or a replacement plane API. */
export function sourcePlaneMask(lattice,normal,out=new Uint8Array(lattice.count)){
  if(out.length!==lattice.count||lattice.abc.length!==3*lattice.count||!Array.isArray(normal)||normal.length!==3||!normal.every(Number.isSafeInteger))throw new RangeError('Source plane focus requires integer base data and a safe integer normal');
  let bound=0;
  for(const x of lattice.abc){if(!Number.isSafeInteger(x))throw new RangeError('Source plane focus requires integer base data');bound=Math.max(bound,Math.abs(x));}
  const [A,B,C]=normal;
  if((2*Math.abs(C)+Math.abs(B)+2*Math.abs(A))*bound<=Number.MAX_SAFE_INTEGER){
    for(let i=0,k=0;i<lattice.count;i++,k+=3)out[i]=-2*C*lattice.abc[k]+B*lattice.abc[k+1]-2*A*lattice.abc[k+2]===0?1:0;
  }else{
    const [a,b,c]=normal.map(BigInt);
    for(let i=0,k=0;i<lattice.count;i++,k+=3)out[i]=-2n*c*BigInt(lattice.abc[k])+b*BigInt(lattice.abc[k+1])-2n*a*BigInt(lattice.abc[k+2])===0n?1:0;
  }
  return out;
}

/** Source Jt(): root-body alpha is independent of Whole/eye/projection. Only
 * primitive base upper forms are root bodies; selection markers are separate. */
export function sourceRootOpacity(lattice,xyz,index,{planeMask=null,focusEnabled=planeMask!==null,light=false}={}){
  if(!isSource(lattice))return 1;
  if(!sourceRootVisible(lattice,index))return 0;
  return Math.fround(Math.fround(catalogueOpacity(lattice,xyz,index))*(focusEnabled&&!planeMask?.[index]?(light?.32:.26):1));
}

/** Source Jt()/Xt() apparent radius before raster minimum/cap. For a marker,
 * supply the accepted divisor to use its primitive representative's radius.
 * This does not replace or normalize the selected signed base identity. */
export function sourceRootRadius(xyz,delta,{model='half-plane',sigma=1,scale=1,divisor=1}={}){
  if(!(delta<0)||!(Number.isSafeInteger(divisor)&&divisor>0))return NaN;
  return model==='half-plane'?.06*sigma*scale*divisor/Math.abs(xyz[1]-xyz[2]):.06*sigma*scale*divisor*Math.pow(-delta,.25)/Math.pow(Math.abs(xyz[1]),1.5);
}

/** Source Xt(): root-only positive representative, primitive apparent radius,
 * and a minimum five-pixel ring. No catalogue, crop or body-alpha gate. */
export function sourceRootMarker(item,options={}){
  if(!item?.xyz||!(item.delta<0)||item.xyz[1]===0)return null;
  const s=item.xyz[1]<0?-1:1,xyz=item.xyz.map(v=>v*s),upper=options.model!=='klein';
  const p=upper?[xyz[0]/(xyz[1]-xyz[2]),Math.sqrt(-item.delta)/Math.abs(xyz[1]-xyz[2])]:[xyz[0]/xyz[1],xyz[2]/xyz[1]];
  const apparentRadius=sourceRootRadius(xyz,item.delta,{...options,divisor:item.divisor??1});
  if(!p.every(Number.isFinite)||!Number.isFinite(apparentRadius))return null;
  return {position:p,apparentRadius,radius:Math.max(5,apparentRadius+4)};
}

// GPU counterpart. Call catalogueOpacity and every appearance function with
// unprojected xyz; only sourceProjectionPosition is passed to modelViewMatrix.
export const sourceProjectionGLSL=`
bool sourceUpper(float kind){return kind>1.5&&kind<2.5;}
vec3 sourceProjectionPosition(vec3 xyz,float kind,vec2 projection){
  if(!sourceUpper(kind)||projection.x<=0.0)return xyz;
  return xyz*(1.0+(projection.y/xyz.y-1.0)*projection.x);
}
float sourceWorldRadius(float delta,float kind,float primitive,float y,vec2 projection,float eye,float whole,float sigma,float focus,float onPlane){
  float p=projection.x,radius;
  if(sourceUpper(kind)){
    float d=.06*sigma*pow(-delta,.25)/(y*sqrt(y));
    float f=.15*sigma*(primitive>.5?1.0:.72);
    radius=mix(mix(f,d*y,eye),d*projection.y,p);
    if(focus>.5&&onPlane>.5)radius*=1.0+.35*(1.0-eye)*(1.0-p);
  }else{
    float base=kind<.5?.09:.075;
    radius=mix(mix(base,.01*abs(y)+.004,eye),.15*sigma,whole);
    if(focus>.5&&onPlane>.5)radius=.12;
  }
  return radius;
}
float sourceWorldOpacity(vec3 xyz,float kind,float primitive,vec3 catalogue,vec2 projection,float eye,vec4 source,float focus,float onPlane){
  float crop=catalogueOpacity(xyz,kind,catalogue);
  if(crop<=0.0)return 0.0;
  float p=projection.x,whole=source.x,base=source.w>.5?.36:.45,alpha;
  if(sourceUpper(kind)){
    float v=focus>.5?(onPlane>.5?2.0:(source.w>.5?.32:.26)):1.0;
    float start=v>=1.0?mix(base,.95,eye):v;
    float cutoff=floor(.4*catalogue.x+.5);
    float radial=cutoff>0.0?1.0-smoothstep(.86*cutoff,cutoff,length(xyz)):0.0;
    start*=1.0-whole*(1.0-radial);
    float screenWeight=source.z>.5?1.0-eye:0.0;
    if(screenWeight>.001)start*=1.0-.75*screenWeight*clamp((xyz.y-projection.y)/3.0+.5,0.0,1.0)*(1.0-eye);
    alpha=crop*mix(start,v>=1.0?.95:v,p);
    if(primitive<.5)alpha*=1.0-p;
  }else{
    float category=kind<.5?1.5:kind<1.5?1.0:.8;
    float dust=source.y>.5?(source.w>.5?.5:.42)*category*(1.0-.6*eye):0.0;
    alpha=crop*mix(dust,base*(1.0-eye),whole);
    if(focus>.5&&onPlane>.5)alpha=crop*.9;
  }
  return min(1.0,alpha);
}`;
