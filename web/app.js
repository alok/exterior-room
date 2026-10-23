// SPDX-License-Identifier: GPL-3.0-or-later
// Exterior Room, Alok Singh with OpenAI Codex, 2026.
import * as THREE from 'three';
import {OrbitControls} from './vendor/OrbitControls.js';
import {visibleIntersections} from './input.js';
import {xrAvailability, controllerRay, captureView, restoreView} from './xr-support.js';
import {PRESETS, clone, snap, fraction, LeanQueue} from './state.js';

const $=id=>document.getElementById(id);
const colors={a:0xff9175,b:0x67e4c8,c:0xb8a0ff};
const scene=new THREE.Scene();scene.background=new THREE.Color(0x081018);scene.fog=new THREE.FogExp2(0x081018,.035);
const renderer=new THREE.WebGLRenderer({canvas:$('scene'),antialias:true,alpha:false,powerPreference:'low-power'});
renderer.setPixelRatio(Math.min(devicePixelRatio,1.7));renderer.setSize(innerWidth,innerHeight);renderer.xr.enabled=true;
renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.15;
const camera=new THREE.PerspectiveCamera(42,innerWidth/innerHeight,.025,100);camera.position.set(7,5,8);
const controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.dampingFactor=.08;controls.minDistance=.7;controls.maxDistance=25;controls.maxPolarAngle=Math.PI*.95;
scene.add(new THREE.HemisphereLight(0xcfeaff,0x314052,2.0));
const key=new THREE.DirectionalLight(0xffffff,2.7);key.position.set(2,8,5);scene.add(key);
const rim=new THREE.PointLight(0x53dfc0,18,18);rim.position.set(-5,2,-2);scene.add(rim);

const world=new THREE.Group();scene.add(world);
const stage=new THREE.Group();world.add(stage);
const floor=new THREE.GridHelper(32,64,0x284249,0x172830);floor.position.y=-.65;floor.material.transparent=true;floor.material.opacity=.5;world.add(floor);
// A grid supplies orientation without hiding legal geometry below the origin.
const origin=new THREE.Mesh(new THREE.SphereGeometry(.045,16,12),new THREE.MeshBasicMaterial({color:0xe9f2ed}));stage.add(origin);
function line(points,color,opacity=1){const g=new THREE.BufferGeometry().setFromPoints(points);const m=new THREE.LineBasicMaterial({color,transparent:opacity<1,opacity});return new THREE.Line(g,m);}
for(let i=0;i<3;i++){const end=new THREE.Vector3();end.setComponent(i,4.5);stage.add(line([new THREE.Vector3(),end],0x597572,.3));const neg=end.clone().multiplyScalar(-.35);stage.add(line([neg,new THREE.Vector3()],0x597572,.14));}
function label(text,color,size=.27){const canvas=document.createElement('canvas');canvas.width=256;canvas.height=128;const c=canvas.getContext('2d');c.font='italic 76px Georgia';c.textAlign='center';c.textBaseline='middle';c.fillStyle=color;c.fillText(text,128,66);const texture=new THREE.CanvasTexture(canvas);const sprite=new THREE.Sprite(new THREE.SpriteMaterial({map:texture,transparent:true,depthTest:false}));sprite.scale.set(size*2,size,1);return sprite;}
for(const [name,p] of [['x',[4.65,0,0]],['y',[0,4.65,0]],['z',[0,0,4.65]]]){const s=label(name,'#7f9b96',.2);s.position.set(...p);stage.add(s);}

const unitY=new THREE.Vector3(0,1,0),handles={},arrows={},labels={};
const handleGeo=new THREE.SphereGeometry(.11,28,18),shaftGeo=new THREE.CylinderGeometry(.016,.016,1,12),coneGeo=new THREE.ConeGeometry(.064,.18,20);
for(const name of ['a','b','c']){
  const material=new THREE.MeshStandardMaterial({color:colors[name],emissive:colors[name],emissiveIntensity:.25,roughness:.25,metalness:.25});
  const handle=new THREE.Mesh(handleGeo,material);handle.userData.vector=name;stage.add(handle);handles[name]=handle;
  const shaft=new THREE.Mesh(shaftGeo,material),tip=new THREE.Mesh(coneGeo,material);stage.add(shaft,tip);arrows[name]={shaft,tip};
  const s=label(name,'#'+colors[name].toString(16),.35);stage.add(s);labels[name]=s;
}
const volumeMaterial=new THREE.MeshPhysicalMaterial({color:0x7695a3,transparent:true,opacity:.13,side:THREE.DoubleSide,depthWrite:false,roughness:.25,metalness:.05});
const volumeGeometry=new THREE.BufferGeometry();volumeGeometry.setAttribute('position',new THREE.Float32BufferAttribute(new Float32Array(108),3));const volumeMesh=new THREE.Mesh(volumeGeometry,volumeMaterial);volumeMesh.renderOrder=1;stage.add(volumeMesh);
const areaGeometry=new THREE.BufferGeometry();const areaMesh=new THREE.Mesh(areaGeometry,new THREE.MeshPhysicalMaterial({color:0x69d9c3,transparent:true,opacity:.24,side:THREE.DoubleSide,depthWrite:false,roughness:.4}));areaMesh.renderOrder=2;stage.add(areaMesh);
const wire=new THREE.LineSegments(new THREE.BufferGeometry(),new THREE.LineBasicMaterial({color:0xb0d9d0,transparent:true,opacity:.48}));stage.add(wire);
const areaWire=new THREE.LineLoop(new THREE.BufferGeometry(),new THREE.LineBasicMaterial({color:0x6de8c6,transparent:true,opacity:.85}));stage.add(areaWire);
// Vertex order is exported by Lean: [0,a,b,c,a+b,a+c,b+c,a+b+c].
const faces=[[0,1,4,2],[0,3,5,1],[0,2,6,3],[3,6,7,5],[2,4,7,6],[1,5,7,4]];
const edges=[[0,1],[0,2],[0,3],[1,4],[1,5],[2,4],[2,6],[3,5],[3,6],[4,7],[5,7],[6,7]];
let vectors=clone(PRESETS.skew),selected='a',current=null,lastLatency=0,mode='overview',showVolume=true,savedView=null,connectionState='pending';
stage.visible=false;
function updateGeometry(result){
  const vs=result.vertices.map(p=>new THREE.Vector3(...p.map(n=>n/result.scale)));
  const triangles=[];for(const [a,b,c,d]of faces)for(const i of[a,b,c,a,c,d])triangles.push(...vs[i].toArray());
  volumeGeometry.attributes.position.array.set(triangles);volumeGeometry.attributes.position.needsUpdate=true;volumeGeometry.computeVertexNormals();volumeGeometry.computeBoundingSphere();
  areaGeometry.setFromPoints([vs[0],vs[1],vs[4],vs[0],vs[4],vs[2]]);areaGeometry.computeVertexNormals();areaGeometry.computeBoundingSphere();
  wire.geometry.setFromPoints(edges.flatMap(e=>e.map(i=>vs[i])));areaWire.geometry.setFromPoints([vs[0],vs[1],vs[4],vs[2]]);
  wire.geometry.computeBoundingSphere();areaWire.geometry.computeBoundingSphere();stage.visible=true;
  for(const name of ['a','b','c']){
    const p=new THREE.Vector3(...result[name].map(n=>n/4)),length=p.length(),dir=p.clone().normalize();handles[name].position.copy(p);labels[name].position.copy(p).add(new THREE.Vector3(.13,.23,0));
    const {shaft,tip}=arrows[name];shaft.position.copy(p).multiplyScalar(.5);shaft.scale.y=length;shaft.quaternion.setFromUnitVectors(unitY,dir.lengthSq()?dir:unitY);tip.position.copy(p).addScaledVector(dir,-.12);tip.quaternion.copy(shaft.quaternion);shaft.visible=tip.visible=length>.05;
  }
  volumeMaterial.color.setHex(result.volume<0?0xca8f80:result.volume===0?0xa18ad0:0x7695a3);
  updateVolumeVisibility();
  $('wedge').textContent=`(${result.wedge.map(n=>fraction(n,16)).join(', ')})`;
  $('volume').textContent=fraction(result.volume,64);
  $('orientation').textContent=result.volume>0?'positive':result.volume<0?'negative':'flat · zero';
  $('orientation').className='orientation '+(result.volume<0?'negative':result.volume===0?'zero':'');
  $('proof-checks').textContent=`This execution: a ∧ a = (${result.selfWedge.join(', ')})\nSwapped: (${result.swappedWedge.map(n=>fraction(n,16)).join(', ')})\nRequest #${result.id} · ${lastLatency.toFixed(1)} ms round trip`;
  $('proof-checks').style.whiteSpace='pre-line';
}
const queue=new LeanQueue({
  transport:async request=>{const r=await fetch('/api/evaluate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(request),signal:AbortSignal.timeout(6000)});const data=await r.json();if(!r.ok||!data.ok)throw Error(data.error||`Bridge returned ${r.status}`);return data;},
  onResult:(result,ms)=>{current=result;lastLatency=ms;updateGeometry(result);},
  onStatus:(status,error)=>{connectionState=status;document.body.classList.toggle('pending',status!=='live');$('connection').dataset.state=status;$('connection-text').textContent=status==='live'?`Lean live · ${lastLatency.toFixed(0)} ms`:status==='pending'?'Lean computing · last result shown':'Lean unavailable · result stale';$('error').hidden=status!=='error';if(error)$('error').textContent=`${error} Start the local Lean bridge, then move a vector to retry. Displayed geometry is the last accepted result.`;drawXRReadout();}
});
function submit(){queue.submit(vectors);refreshCoordinates();document.querySelectorAll('[data-preset]').forEach(b=>b.classList.toggle('active',JSON.stringify(vectors)===JSON.stringify(PRESETS[b.dataset.preset])));}
function select(name){selected=name;document.querySelectorAll('[data-vector]').forEach(b=>{b.classList.toggle('selected',b.dataset.vector===name);b.setAttribute('aria-pressed',b.dataset.vector===name);});for(const k of Object.keys(handles))handles[k].scale.setScalar(k===name?1.25:1);refreshCoordinates();}
for(const [i,axis]of ['x','y','z'].entries()){
  const row=document.createElement('div');row.className='coord';const lab=document.createElement('label');lab.htmlFor=`axis-${axis}`;lab.textContent=axis;const input=document.createElement('input');input.id=lab.htmlFor;input.type='range';input.min='-12';input.max='12';input.step='1';input.setAttribute('aria-label',`Selected vector ${axis} coordinate, quarter units`);const output=document.createElement('output');output.htmlFor=input.id;output.id=`value-${axis}`;input.addEventListener('input',()=>{cancelDrags();vectors[selected][i]=Number(input.value);submit();});row.append(lab,input,output);$('coordinates').append(row);
}
function refreshCoordinates(){for(const [i,axis]of ['x','y','z'].entries()){$(`axis-${axis}`).value=vectors[selected][i];$(`axis-${axis}`).style.accentColor='#'+colors[selected].toString(16);$(`axis-${axis}`).setAttribute('aria-valuetext',`${vectors[selected][i]/4} units`);$(`value-${axis}`).textContent=fraction(vectors[selected][i],4);}refreshXRControls();}
document.querySelectorAll('[data-vector]').forEach(b=>b.onclick=()=>select(b.dataset.vector));
document.querySelectorAll('[data-preset]').forEach(b=>b.onclick=()=>{cancelDrags();vectors=clone(PRESETS[b.dataset.preset]);submit();});
$('swap').onclick=()=>{cancelDrags();[vectors.a,vectors.b]=[vectors.b,vectors.a];submit();};$('flatten').onclick=()=>{cancelDrags();vectors.c=[...vectors.b];select('c');submit();};
$('reset').onclick=()=>{vectors=clone(PRESETS.skew);showVolume=true;updateVolumeVisibility();select('a');setView('overview');submit();};
function setView(view){
  cancelDrags();mode=view;$('overview').classList.toggle('active',mode==='overview');$('inside').classList.toggle('active',mode==='inside');$('overview').setAttribute('aria-pressed',mode==='overview');$('inside').setAttribute('aria-pressed',mode==='inside');
  world.position.set(0,0,0);world.scale.setScalar(1);
  if(renderer.xr.isPresenting){world.scale.setScalar(mode==='inside'?.85:.5);world.position.set(...(mode==='inside'?[.1975,.6475,-1.3525]:[.425,.925,-2.725]));refreshXRControls();return;}
  controls.enabled=true;
  if(mode==='overview'){const mobile=innerWidth<761,compact=innerHeight<600;camera.fov=42;camera.position.set(mobile?8:compact?6:4.8,mobile?5.7:compact?4.3:3.5,mobile?9:compact?6.8:5.4);controls.target.set(mobile?.6:-1.05,mobile?0:compact?.1:.25,mobile?.6:0);controls.minDistance=2;}
  else {camera.fov=75;camera.position.set(.8,.85,1.1);controls.target.set(0,0,0);controls.minDistance=.15;}
  camera.updateProjectionMatrix();
  controls.update();
}
$('overview').onclick=()=>setView('overview');$('inside').onclick=()=>setView('inside');
function updateVolumeVisibility(){volumeMesh.visible=showVolume&&current?.volume!==0;wire.visible=showVolume;$('volume-toggle').setAttribute('aria-pressed',showVolume);}
$('volume-toggle').onclick=()=>{showVolume=!showVolume;updateVolumeVisibility();refreshXRControls();};
function proof(open){$('proof-panel').hidden=!open;$('proof-toggle').setAttribute('aria-expanded',open);if(open)$('proof-close').focus();}
$('proof-toggle').onclick=()=>proof($('proof-panel').hidden);$('proof-close').onclick=()=>proof(false);
window.addEventListener('keydown',e=>{if(e.key==='Escape')proof(false);if(e.target instanceof HTMLInputElement)return;if(['a','b','c'].includes(e.key))select(e.key);});
$('download').onclick=()=>{if(!current)return;const url=URL.createObjectURL(new Blob([JSON.stringify({...current,display:{lengthScale:4,areaScale:16,volumeScale:64},notice:'Native Lean calculation. Rendering and transport are not kernel-verified.'},null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download=`exterior-room-${current.id}.json`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};

const raycaster=new THREE.Raycaster(),pointer=new THREE.Vector2(),plane=new THREE.Plane(),hit=new THREE.Vector3();let drag=null;
function pointerRay(event){const r=renderer.domElement.getBoundingClientRect();pointer.set((event.clientX-r.left)/r.width*2-1,-(event.clientY-r.top)/r.height*2+1);raycaster.setFromCamera(pointer,camera);}
renderer.domElement.addEventListener('pointerdown',event=>{
  if(event.button!==0||renderer.xr.isPresenting)return;pointerRay(event);const object=visibleIntersections(raycaster,Object.values(handles))[0]?.object;if(!object)return;
  event.stopImmediatePropagation();select(object.userData.vector);controls.enabled=false;renderer.domElement.setPointerCapture(event.pointerId);plane.setFromNormalAndCoplanarPoint(camera.getWorldDirection(new THREE.Vector3()),object.getWorldPosition(new THREE.Vector3()));raycaster.ray.intersectPlane(plane,hit);drag={id:event.pointerId,name:selected,offset:object.getWorldPosition(new THREE.Vector3()).sub(hit)};renderer.domElement.style.cursor='grabbing';
},true);
renderer.domElement.addEventListener('pointermove',event=>{
  if(renderer.xr.isPresenting)return;pointerRay(event);
  if(drag&&event.pointerId===drag.id){if(raycaster.ray.intersectPlane(plane,hit)){const p=stage.worldToLocal(hit.clone().add(drag.offset));const next=p.toArray().map(n=>snap(n*4));if(next.some((n,i)=>n!==vectors[drag.name][i])){vectors[drag.name]=next;submit();}}return;}
  renderer.domElement.style.cursor=visibleIntersections(raycaster,Object.values(handles)).length?'grab':'default';
});
function endDrag(event){if(drag?.id===event.pointerId){drag=null;controls.enabled=true;renderer.domElement.style.cursor='default';}}
renderer.domElement.addEventListener('pointerup',endDrag);renderer.domElement.addEventListener('pointercancel',endDrag);renderer.domElement.addEventListener('lostpointercapture',endDrag);

const xrControllers=[];let xrSession=null,xrStarting=false,savedMode='overview';
for(let i=0;i<2;i++){
  const controller=renderer.xr.getController(i);scene.add(controller);xrControllers.push(controller);
  const laser=line([new THREE.Vector3(),new THREE.Vector3(0,0,-5)],0x96ccc4,.6);controller.add(laser);
  controller.addEventListener('selectstart',()=>{controllerRay(controller,raycaster);const found=visibleIntersections(raycaster,[...Object.values(handles),...xrButtons])[0];if(!found)return;if(found.object.userData.action){found.object.userData.action();return;}select(found.object.userData.vector);controller.userData.drag={name:selected,distance:found.distance,offset:found.object.getWorldPosition(new THREE.Vector3()).sub(found.point)};});
  controller.addEventListener('selectend',()=>{updateXRDrag(controller);delete controller.userData.drag;});
}
// In-world controls make the important actions usable without DOM overlays.
const xrPanel=new THREE.Group();scene.add(xrPanel);xrPanel.visible=false;const xrButtons=[];
function xrButton(text,x,y,action,active=()=>false){
  const canvas=document.createElement('canvas');canvas.width=512;canvas.height=144;
  const texture=new THREE.CanvasTexture(canvas);
  const mesh=new THREE.Mesh(new THREE.PlaneGeometry(.30,.10),new THREE.MeshBasicMaterial({map:texture,side:THREE.DoubleSide}));
  mesh.position.set(x,y,0);mesh.userData.action=action;
  let previousLabel,previousActive;
  mesh.userData.redraw=()=>{const label=typeof text==='function'?text():text,enabled=active();if(label===previousLabel&&enabled===previousActive)return;previousLabel=label;previousActive=enabled;const ctx=canvas.getContext('2d');ctx.fillStyle=enabled?'#235b56':'#14282e';ctx.fillRect(0,0,512,144);ctx.strokeStyle=enabled?'#6de8c6':'#466b6b';ctx.lineWidth=4;ctx.strokeRect(2,2,508,140);ctx.fillStyle='#e9efec';ctx.font='38px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(label,256,72);texture.needsUpdate=true;};
  xrPanel.add(mesh);xrButtons.push(mesh);return mesh;
}
function refreshXRControls(){if(!xrPanel.visible)return;for(const button of xrButtons)button.userData.redraw();}
for(const [i,name] of ['skew','unit','plane'].entries())xrButton(name[0].toUpperCase()+name.slice(1),(i-1)*.33,.23,()=>{cancelDrags();vectors=clone(PRESETS[name]);submit();},()=>JSON.stringify(vectors)===JSON.stringify(PRESETS[name]));
for(const [i,name] of ['a','b','c'].entries())xrButton('Move '+name,(i-1)*.33,.11,()=>select(name),()=>selected===name);
for(const [i,axis] of ['x','y','z'].entries()){
  const y=-.01-i*.12;
  xrButton(axis+' − ¼',-.33,y,()=>{cancelDrags();vectors[selected][i]=snap(vectors[selected][i]-1);submit();});
  xrButton(()=>selected+'.'+axis+' = '+fraction(vectors[selected][i],4),0,y,()=>{},()=>true);
  xrButton(axis+' + ¼',.33,y,()=>{cancelDrags();vectors[selected][i]=snap(vectors[selected][i]+1);submit();});
}
xrButton('Swap a ↔ b',-.33,-.37,()=>$('swap').click());xrButton('Flatten c = b',0,-.37,()=>$('flatten').click());xrButton(()=>showVolume?'Volume on':'Volume off',.33,-.37,()=>$('volume-toggle').click(),()=>showVolume);
xrButton('Reset',-.33,-.49,()=>$('reset').click());xrButton(()=>mode==='inside'?'Inside':'Overview',0,-.49,()=>setView(mode==='inside'?'overview':'inside'));xrButton('Exit VR',.33,-.49,()=>xrSession?.end());
const xrReadout=document.createElement('canvas');xrReadout.width=1536;xrReadout.height=640;
const xrReadoutTexture=new THREE.CanvasTexture(xrReadout);
const xrReceipt=new THREE.Mesh(new THREE.PlaneGeometry(.96,.40),new THREE.MeshBasicMaterial({map:xrReadoutTexture,side:THREE.DoubleSide}));xrReceipt.position.y=.50;xrPanel.add(xrReceipt);
function drawXRReadout(){
  if(!xrPanel.visible)return;
  const ctx=xrReadout.getContext('2d');ctx.fillStyle='#101f28';ctx.fillRect(0,0,1536,640);
  ctx.fillStyle='#e9efec';ctx.font='46px Georgia';ctx.fillText('EXTERIOR ROOM',48,65);
  ctx.fillStyle=connectionState==='live'?'#6de8c6':'#ffb399';ctx.font='38px sans-serif';ctx.fillText($('connection-text').textContent,48,132);
  ctx.fillStyle='#e9efec';ctx.font='48px Georgia';ctx.fillText(current?`a ∧ b = ${$('wedge').textContent}`:'Waiting for exact Lean geometry',48,215);
  ctx.fillStyle='#b5cbc5';ctx.font='34px sans-serif';ctx.fillText('coefficients of e₁₂, e₁₃, e₂₃',48,267);
  ctx.fillStyle='#e9efec';ctx.font='48px Georgia';ctx.fillText(current?`a ∧ b ∧ c = ${$('volume').textContent}`:'',48,343);
  ctx.fillStyle='#b5cbc5';ctx.font='34px sans-serif';ctx.fillText('Exact Lean on the Mac · floating-point picture',48,411);
  ctx.fillText('Kernel laws: self-wedge = 0; swap reverses volume.',48,467);
  ctx.fillText('Grab a tip or edit quarter-unit coordinates below.',48,523);
  ctx.fillStyle=connectionState==='live'?'#b5cbc5':'#ffb399';ctx.fillText(connectionState==='live'?'Live calculation ≠ a new kernel proof.':'Previous result only · reconnect the Mac bridge.',48,587);
  xrReadoutTexture.needsUpdate=true;
}
const available=await xrAvailability(navigator.xr,isSecureContext);$('xr-note').textContent=available.message;$('xr-button').disabled=!available.supported;$('xr-button').title=available.message;
function restoreDesktop(){xrSession=null;xrStarting=false;document.body.classList.remove('xr');xrPanel.visible=false;floor.visible=true;for(const c of xrControllers)delete c.userData.drag;setView(savedMode);world.position.set(0,0,0);world.scale.setScalar(1);controls.enabled=true;if(savedView)restoreView(savedView,camera,controls);$('xr-button').disabled=!available.supported;}
renderer.xr.addEventListener('sessionend',restoreDesktop);
$('xr-button').onclick=async()=>{
  if(xrStarting||xrSession)return;xrStarting=true;$('xr-button').disabled=true;savedView=captureView(camera,controls);savedMode=mode;let requested;
  try{requested=await navigator.xr.requestSession('immersive-vr',{optionalFeatures:['local-floor','hand-tracking']});xrSession=requested;controls.enabled=false;await renderer.xr.setSession(requested);document.body.classList.add('xr');xrPanel.visible=true;floor.visible=false;xrPanel.position.set(-.65,1.25,-1.55);setView('overview');drawXRReadout();}
  catch(error){try{await requested?.end();}catch{}restoreDesktop();$('error').hidden=false;$('error').textContent=`Could not enter VR: ${error.message}`;}
  finally{xrStarting=false;}
};

function cancelDrags(){for(const controller of xrControllers)delete controller.userData.drag;if(drag){const pointerId=drag.id;drag=null;if(renderer.domElement.hasPointerCapture(pointerId))renderer.domElement.releasePointerCapture(pointerId);renderer.domElement.style.cursor='default';}controls.enabled=!renderer.xr.isPresenting;}
let lastXRSubmit=0;
function updateXRDrag(controller){const d=controller.userData.drag;if(!d)return;controllerRay(controller,raycaster);const p=stage.worldToLocal(raycaster.ray.at(d.distance,new THREE.Vector3()).add(d.offset));const next=p.toArray().map(n=>snap(n*4));if(next.some((n,i)=>n!==vectors[d.name][i])){vectors[d.name]=next;submit();}}
renderer.setAnimationLoop(time=>{
  if(!renderer.xr.isPresenting)controls.update();
  else if(time-lastXRSubmit>65){for(const controller of xrControllers)updateXRDrag(controller);lastXRSubmit=time;}
  renderer.render(scene,camera);
});
window.addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight);});
select('a');setView('overview');submit();
// Read-only diagnostics for local browser verification, without a math fallback.
window.exteriorRoom={get result(){return current;},get state(){return clone(vectors);},get mode(){return mode;},get view(){return {showVolume,wireVisible:wire.visible,volumeVisible:volumeMesh.visible,xrPresenting:renderer.xr.isPresenting,camera:camera.position.toArray(),target:controls.target.toArray(),controlsEnabled:controls.enabled};},get renderer(){return {calls:renderer.info.render.calls,triangles:renderer.info.render.triangles};},projectHandle(name){const p=handles[name].getWorldPosition(new THREE.Vector3()).project(camera);return {x:(p.x+1)*innerWidth/2,y:(1-p.y)*innerHeight/2};}};
