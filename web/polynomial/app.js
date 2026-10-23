// SPDX-License-Identifier: GPL-3.0-or-later
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { examples, vector, project, upperRoot, discriminant, divisor, height, kind, positiveRepresentative, polynomial } from './starscape-core.js';
import { xrAvailability, controllerRay, captureView, restoreView } from './xr-support.js';
import { TapSelection, nearestToRayPacked } from './input.js';
import { HoverQueries } from './hover-queries.js';
import { cameraPlaneLabel } from './camera-planes.js';
import { coefficientColor, gradientCSS, paletteRange, categoryPalettes, glyphRadius, glyphScale, outlinePixels, sourceRadiusFactor, sourceRadiusFactorFromData, drawnPixels } from './appearance.js';
import { acceptedLattice, tripleAt, latticeRadii, projectedPositions } from './lattice.js';
import { pointCloudMaterial, pointCloud, fillColors, fillFactors } from './point-cloud.js';
import { pairPlane, planeFromNormal, planeSection, coneDirections, inPairPlane } from './pair-plane.js';
import {IDENTITY_BOUND,loadCloud,loadCatalogue,activateCloud,cancelCloudLoad,indexOfPoint, inspectWithRepresentative, preparePlane, memberIndices, status as leanStatus, diagnostics, commitTransform, cancelTransformCommit} from './lean-client.js';
import {identity,kleinToUpper} from './mobius.js';
import {matrixFromIntegers,pointerToUpper,chartTransform,rootToClient,zoomChartAt,resizeChart} from './mobius-render.js';
import {MobiusAction} from './mobius-ui.js';
import {nearestIntegral,composeInteger} from './mobius-snap.js';
import {prepareAbsorption,integralRepresentative} from './mobius-absorb.js';
import {KleinView} from './klein-view.js';
import {needsSourceCatalogue} from './catalogue-policy.js';
import {catalogueVisibility,sourceRootVisible} from './catalogue-display.js';
import {pickRoot} from './klein-data.js';
import {shownUpperRoot,shownBoundaryRoot,approximateNumber,spacedPolynomial} from './display-readouts.js';
const $ = id => document.getElementById(id);
let radius = 6, whole = true, symmetricColor = false, projectionVisible = false;
let catalogueMode='canonical',dust=false,visiblePoints=null;
let selected = examples[0], lattice = null, cloudMesh, imageMesh;
let session = null, savedView = null, startingXR = false;
let inhabited=false, overviewView=null, lookDrag=null, look={yaw:0,pitch:0};
let hoverPointer=null, hoverFrame=0, hoverShown=null; // desktop pointer hover (see refreshHover)
const overviewFov=45, originFov=100;
let categories='viridis', glyphKey=null, focusGlyphs=[], sigma=1, planeFocus=false;
let latticeGeneration=0, secondSelection=null, pairMessage='', pairGlyphs=[], planeMembers=new Set(), originMode=false, timings={}, colorKey='', factorKey='';
let dataBusy=false, initialized=false,operationError='';
const action=new MobiusAction(commitActionAndCatalogue,()=>{cancelTransformCommit();cancelCloudLoad();});
let displayXYZ=null,pickLattice=null,actionGeometryLattice=null,actionGeometryRevision=-1,renderRows=null;
let rootsView=false,mobiusMode=false,mobiusGesture=null,mobiusFrame=0,lastActionPaint=0;
const rootsVisible=()=>!session&&(rootsView||innerWidth>=1000);
const spaceVisible=()=>!!session||!rootsView||innerWidth>=1000;
let rootsRect=null;
let motionTicket=0,lastAbsorption=null,snapOnRelease=false;
const diskView={model:'half-plane',zoom:1,pan:[0,0],padding:20};
const dataControls=['next','whole','radius','catalogue-mode','dust','reset','coefficient','pair-add','pair-clear','mobius-demo'];
async function runData(action){
  if(dataBusy)return;dataBusy=true;operationError='';clearHover();
  for(const id of dataControls)$(id).disabled=true;
  try{await action();$('fatal').hidden=true;reportCatalogue();}
  catch(error){operationError=error.message;leanStatus(error.message,true);$('status').textContent=error.message;if(!initialized){$('fatal').hidden=false;$('fatal').textContent=`Lean data unavailable: ${error.message}. Start the local bridge and reload.`;}}
  finally{dataBusy=false;for(const id of dataControls)$(id).disabled=false;syncCatalogueControls();if(initialized){update();render();}}
}
function reportCatalogue(){
  if(!lattice)return;
  const c=lattice.catalogue;
  leanStatus(`Lean live · ${lattice.count.toLocaleString()} ${c?'catalogued forms':'exact points'}${c&&!c.complete?' · source limit reached':''}`);
}
function syncCatalogueControls(){
  $('catalogue-mode').value=catalogueMode;$('radius').value=String(radius);$('whole').checked=whole;$('dust').checked=dust;
  $('dust-control').hidden=catalogueMode!=='source';$('dust').disabled=dataBusy||catalogueMode!=='source'||whole;
  $('crop-label').textContent=catalogueMode==='source'?'Depth':'Radius';
  for(const option of $('radius').querySelectorAll('optgroup option'))option.textContent=catalogueMode==='source'?`${option.value} · source depth`:`${option.value} · ${fixtureCounts[option.value].toLocaleString()} points`;
}
async function prepareSelection(point,second=null,candidate){
  await inspectWithRepresentative(point);
  if(second){await inspectWithRepresentative(second);return preparePlane(point,second,candidate);}
  return kind(point)==='exterior'?preparePlane(point,undefined,candidate):null;
}
async function stageCloud(nextRadius,nextWhole,nextMode,nextDust,matrix,point,second,isCurrent){
  try{
  const candidate=nextMode==='source'
    ?await loadCatalogue(nextRadius,matrix,{whole:nextWhole,dust:nextDust},{isCurrent})
    :await loadCloud(nextRadius,!nextWhole,{activate:false,isCurrent});
  if(!candidate||!isCurrent())return null;
  const plane=await prepareSelection(point,second,candidate);
  if(!isCurrent())return null;
  if(plane?.error)throw Error(plane.error);
  return candidate;
  }catch(error){if(!isCurrent())return null;throw error;}
}
function acceptCloud(candidate){
  if(!activateCloud(candidate))throw Error('The catalogue request was superseded; accepted state retained.');
}
async function commitActionAndCatalogue(point,matrix,second){
  const ticket=motionTicket,isCurrent=()=>ticket===motionTicket;
  const receipt=await commitTransform(point,matrix,second);
  if(!receipt||!isCurrent())return null;
  if(catalogueMode==='source'&&needsSourceCatalogue(lattice.catalogue,radius,matrix,{whole,dust})){
    const candidate=await stageCloud(radius,whole,catalogueMode,dust,matrix,point,second,isCurrent);
    if(!candidate||!isCurrent())return null;
    acceptCloud(candidate);rebuild();
  }
  return receipt;
}
async function changeCloud(nextRadius,nextWhole,reset=false,nextMode=catalogueMode,nextDust=dust){
  if(dataBusy)return;
  cancelMobiusInteraction();
  return runData(async()=>{
    const ticket=motionTicket,isCurrent=()=>ticket===motionTicket;
    const next=reset?examples[0]:selected,second=reset?null:secondSelection;
    if(reset){nextMode='canonical';nextDust=false;}
    const candidate=await stageCloud(nextRadius,nextWhole,nextMode,nextDust,reset?identity:action.matrix,next,second,isCurrent);
    if(!candidate||!isCurrent())return;
    acceptCloud(candidate);radius=nextRadius;whole=nextWhole;catalogueMode=nextMode;dust=nextDust;
    if(reset){action.reset();mobiusMode=false;lastAbsorption=null;snapOnRelease=false;resetRootsChart();}
    if(reset){if(!session)leaveInhabit();selected=next;secondSelection=null;pairMessage='';symmetricColor=false;projectionVisible=false;$('cone').checked=true;$('symmetric-color').checked=false;}
    syncCatalogueControls();rebuild();
    if(!inhabited)resetView();initialized=true;
  });
}
let renderer;
try { renderer = new THREE.WebGLRenderer({ antialias: true }); }
catch {
  $('fatal').hidden = false;
  $('fatal').textContent = 'WebGL is unavailable. The source links and mathematical explanation remain available.';
  document.querySelectorAll('.controls button, .controls input, .controls select').forEach(c => { c.disabled = true; });
  $('debug-toggle').disabled = true;
  $('xr').textContent = 'VR unavailable without WebGL';
  throw Error('WebGL unavailable');
}
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.xr.enabled = true; renderer.xr.setReferenceSpaceType('local-floor');
$('viewport').append(renderer.domElement);
const kleinCanvas=document.createElement('canvas');kleinCanvas.id='klein-canvas';kleinCanvas.hidden=true;kleinCanvas.tabIndex=0;kleinCanvas.setAttribute('aria-label','Upper half-plane of roots. Drag to move forms; Shift-drag to pan; wheel to zoom.');document.body.append(kleinCanvas);
const kleinView=new KleinView(kleinCanvas);
renderer.domElement.tabIndex = 0;
renderer.domElement.setAttribute('role', 'img');
renderer.domElement.setAttribute('aria-label', 'Signed integer coefficient lattice in and around a double cone');
const scene = new THREE.Scene(); scene.background = new THREE.Color(0);
const camera = new THREE.PerspectiveCamera(45, 1, 0.05, 60);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = false; controls.minDistance = 1; controls.maxDistance = 20;
controls.listenToKeyEvents(renderer.domElement);
const world = new THREE.Group(); world.position.set(0, 1.4, -3.1); scene.add(world);
const scale = 0.16, physical = p => new THREE.Vector3(...p).multiplyScalar(scale);
const cloud = new THREE.Group(), disk = new THREE.Group(), cone = new THREE.Group(), focus = new THREE.Group();
world.add(cloud, disk, cone, focus);
// Unlit discs: the drawn color is exactly the legend color, with no shading or tone mapping.
const sphere = new THREE.SphereGeometry(glyphRadius, 12, 8);
const cloudMaterial = pointCloudMaterial();
const white = new THREE.MeshBasicMaterial({ color: 0xffffff });
const imageMaterial = new THREE.PointsMaterial({ color: 0x54e9f5, size: 2, sizeAttenuation: false });
const selectionMaterial=new THREE.MeshBasicMaterial({color:0xffffff,side:THREE.BackSide});
const pairMaterial=new THREE.MeshBasicMaterial({color:0xffba6b,side:THREE.BackSide});
function pointColor(point) {
  return new THREE.Color().setRGB(...coefficientColor(point,symmetricColor,categories),THREE.SRGBColorSpace);
}
function disposeChildren(group) {
  for (const object of [...group.children]) {
    group.remove(object);
    if (object.geometry && object.geometry !== sphere) object.geometry.dispose();
    if (object.material && ![white,imageMaterial,cloudMaterial,selectionMaterial,pairMaterial].includes(object.material)) object.material.dispose();
    object.dispose?.();
  }
}
function lines(paths,color,opacity=1) {
  const vertices=[];
  for(const path of paths) for(let i=1;i<path.length;i++) vertices.push(...path[i-1],...path[i]);
  const geometry=new THREE.BufferGeometry(); geometry.setAttribute('position',new THREE.Float32BufferAttribute(vertices,3));
  return new THREE.LineSegments(geometry,new THREE.LineBasicMaterial({color,transparent:opacity<1,opacity}));
}
function circle(h) {
  return Array.from({length:65},(_,i)=>[scale*Math.abs(h)*Math.cos(i*Math.PI/32),scale*h,scale*Math.abs(h)*Math.sin(i*Math.PI/32)]);
}
function surface(h,isDisk,opacity) {
  const vertices=[],ring=circle(h);
  for(let i=0;i<64;i++) vertices.push(0,isDisk?h*scale:0,0,...ring[i],...ring[i+1]);
  const geometry=new THREE.BufferGeometry(); geometry.setAttribute('position',new THREE.Float32BufferAttribute(vertices,3));
  return new THREE.Mesh(geometry,new THREE.MeshBasicMaterial({color:0x54e9f5,transparent:true,opacity,side:THREE.DoubleSide,depthWrite:false}));
}
const matrix = new THREE.Matrix4();
function movedXYZ(xyz){const m=renderRows??action.rows,[x,y,z]=xyz;return [m[0]*x+m[1]*y+m[2]*z,m[3]*x+m[4]*y+m[5]*z,m[6]*x+m[7]*y+m[8]*z];}
const displayedVector=p=>movedXYZ(vector(p));
function displayedImage(p){const v=displayedVector(p);return v.map(x=>x*height/v[1]);}
function refreshActionGeometry(){
  if(actionGeometryLattice===lattice&&actionGeometryRevision===action.revision)return;
  const started=performance.now();
  actionGeometryLattice=lattice;actionGeometryRevision=action.revision;
  renderRows=action.rows;
  // Within a catalogue, signed identities never change under viewing motion.
  // A new accepted catalogue replaces the buffer atomically after Lean returns.
  const attr=cloudMesh.geometry.attributes.position;
  {
    if(attr.array===lattice.xyz)cloudMesh.geometry.setAttribute('position',new THREE.BufferAttribute(lattice.xyz.slice(),3));
    displayXYZ=cloudMesh.geometry.attributes.position.array;
    const m=renderRows;let extent=radius;
    for(let i=0;i<lattice.count;i++){
      const k=i*3,x=lattice.xyz[k],y=lattice.xyz[k+1],z=lattice.xyz[k+2];
      displayXYZ[k]=m[0]*x+m[1]*y+m[2]*z;displayXYZ[k+1]=m[3]*x+m[4]*y+m[5]*z;displayXYZ[k+2]=m[6]*x+m[7]*y+m[8]*z;
      extent=Math.max(extent,Math.abs(displayXYZ[k]),Math.abs(displayXYZ[k+1]),Math.abs(displayXYZ[k+2]));
    }
    cloudMesh.geometry.attributes.position.needsUpdate=true;camera.far=Math.max(20+8*radius*scale,extent*scale*4);camera.updateProjectionMatrix();
  }
  visiblePoints=lattice.catalogue?catalogueVisibility(lattice,displayXYZ):null;
  let pickXYZ=displayXYZ;
  if(visiblePoints){pickXYZ=displayXYZ.slice();for(let i=0;i<lattice.count;i++)if(!visiblePoints[i])pickXYZ.fill(NaN,i*3,i*3+3);}
  pickLattice={...lattice,xyz:pickXYZ};
  if(imageMesh){disk.remove(imageMesh);imageMesh.geometry.dispose();imageMesh=null;}
  invalidateSpatialQueries();
  timings.motion=performance.now()-started;
}
function rebuild() {
  // A new lattice generation: worker answers still in flight for the old one are dropped on arrival.
  glyphKey=null;latticeGeneration++;hoverQueries.reset();showHover(null);diskHoverIndex=null;
  disposeChildren(cloud); disposeChildren(disk); disposeChildren(cone);
  let t=performance.now();
  lattice = acceptedLattice();
  timings.enumerate=performance.now()-t;t=performance.now();
  cloudMesh = pointCloud(lattice, cloudMaterial, symmetricColor, categories); cloudMesh.scale.setScalar(scale); cloud.add(cloudMesh);
  colorKey=[radius,whole,symmetricColor,categories].join();factorKey=[radius,whole,symmetricColor,''].join();
  timings.attributes=performance.now()-t;imageMesh=null;
  // Overview distance is 5.4·R/8 (resetView); far clipping and zoom limits leave room beyond the whole ball.
  camera.far=20+8*radius*scale;camera.updateProjectionMatrix();controls.maxDistance=Math.max(20,8*radius*scale);
  disk.add(surface(height,true,0.1), lines([circle(height)],0x54e9f5,0.8));
  for(const sign of [-1,1]) {
    const h=radius*sign;
    cone.add(surface(h,false,0.018));
    cone.add(lines([circle(h),...Array.from({length:8},(_,i)=>[[0,0,0],circle(h)[i*8]])],0x7896a8,0.26));
  }
  refreshActionGeometry();
}
const origin = new THREE.Mesh(sphere,white); world.add(origin);
const shown=p=>{const i=indexOfPoint(p,lattice);return i>=0&&(!visiblePoints||visiblePoints[i]!==0);};
const latticePoints=()=>Array.from({length:lattice.count},(_,i)=>tripleAt(lattice,i));
// Interior displayed triples on the Lorentz plane −2C·a + B·b − 2A·c = 0 (exact membership from the current Lean identity contract).
function visibleMemberIndices(normal){return [...memberIndices(normal)].filter(i=>!visiblePoints||visiblePoints[i]);}
function planeInteriorMembers(normal){return visibleMemberIndices(normal).map(i=>tripleAt(lattice,i));}
// Color and size attributes are O(n) to fill, so refill only when their inputs change.
// Radial images of every interior point on the screen y = height, built only once projection is shown.
function buildImages(){
  const t=performance.now(),images=projectedPositions({...lattice,xyz:displayXYZ},height,{visible:visiblePoints,primitiveOnly:!!lattice.catalogue});
  const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.BufferAttribute(images,3));
  imageMesh=new THREE.Points(geometry,imageMaterial);imageMesh.scale.setScalar(scale);imageMesh.frustumCulled=false;disk.add(imageMesh);
  timings.images=performance.now()-t;
}
function refreshColors(){
  const key=[radius,whole,symmetricColor,categories].join();if(key===colorKey)return;colorKey=key;
  const t=performance.now();fillColors(lattice,symmetricColor,categories,cloudMesh.geometry.attributes.color.array);
  cloudMesh.geometry.attributes.color.needsUpdate=true;timings.colors=performance.now()-t;
}
function refreshFactors(planeKey){
  const key=[radius,whole,symmetricColor,planeKey].join();if(key===factorKey)return;factorKey=key;
  const t=performance.now();
  const indices=currentPlane()?memberIndices(currentPlane().normal):new Set();
  fillFactors(lattice,symmetricColor,i=>lattice.kind[i]===2&&indices.has(i),cloudMesh.geometry.attributes.aFactor.array);
  cloudMesh.geometry.attributes.aFactor.needsUpdate=true;timings.factors=performance.now()-t;
}
function selectPoint(point,asPair=false) {
  if(dataBusy)return;
  cancelMobiusInteraction();
  return runData(async()=>{
    const ticket=motionTicket;
    try{
    const result=await prepareSelection(asPair?selected:point,asPair?point:null);
    if(ticket!==motionTicket)return;
    if(result?.error){pairMessage=result.error;return;}
    const hadAction=!!action.receipt,receipt=await action.inspectSelection(asPair?selected:point,asPair?point:null);
    if(ticket!==motionTicket||(hadAction&&!receipt))return;
    if(asPair)secondSelection=[...point];else{selected=[...point];secondSelection=null;}
    pairMessage='';
    }catch(error){if(ticket===motionTicket)throw error;}
  });
}
// As in Stange's viewer: two interior stars span a plane, and a selected exterior triple is a plane's normal.
function currentPlane(){
  if(secondSelection){const p=pairPlane(selected,secondSelection);return p.error?null:p;}
  if(kind(selected)==='exterior'){const plane=planeFromNormal(selected);if(!plane.error)return plane;}
  return null;
}
function updatePair() {
  $('pair-status').textContent=pairMessage;$('pair-status').hidden=!pairMessage;
  const plane=currentPlane();
  $('pair-details').hidden=!plane;$('pair-clear').hidden=!secondSelection;
  const focusUniform=cloudMaterial.uniforms.uFocus.value;focusUniform.w=0;
  if(!plane){refreshFactors('');return;}
  if(planeFocus){const [A,B,C]=plane.normal,m=action.rows,normalMap=new THREE.Matrix3().set(...m).invert().transpose(),n=new THREE.Vector3(-B,-A-C,C-A).applyMatrix3(normalMap).normalize();focusUniform.set(n.x,n.y,n.z,1);cloudMaterial.uniforms.uFocusFade.value.x=0.5*radius;}
  cloudMaterial.uniforms.uKeep.value.set(...displayedVector(selected));
  const members=planeInteriorMembers(plane.normal);
  planeMembers=new Set(members.map(p=>p.join()));refreshFactors(plane.normal.join());
  if(secondSelection){
    const root=upperRoot(positiveRepresentative(secondSelection));
    $('pair-second').textContent=`Second point: (${secondSelection.join(', ')}) · Δ = ${discriminant(secondSelection)} · root ${root[0].toFixed(3)} + ${root[1].toFixed(3)}i`;
  } else $('pair-second').textContent=`Cutting plane with normal (${plane.normal.join(', ')}): the plane Lorentz-orthogonal to the selected exterior triple.`;
  $('pair-equation').textContent=`${action.active?'Base plane (moves with forms)':'Plane'}: ${plane.equation}`;
  const endpointBase=plane.endpoints.map(p=>p.label).join(' and ');
  const endpointShown=action.active?coneDirections(plane).map(movedXYZ).map(shownBoundaryRoot).map(approximateNumber).join(' and '):null;
  $('pair-endpoints').textContent=endpointShown?`Shown endpoints ≈ ${endpointShown} · base: ${endpointBase}`:`Geodesic endpoints: ${endpointBase}`;
  const secondVisible=!secondSelection||shown(secondSelection);
  $('pair-count').textContent=`${members.length} ${lattice.catalogue?'depth-visible':'displayed'} complex-root points lie exactly in this plane (amber rings).${lattice.catalogue?` ${memberIndices(plane.normal).size} members in the buffered catalogue.`:''} Multiples remain separate points.${secondVisible?'':' The second point is hidden by this filter/crop.'}`;
  const ring=new THREE.InstancedMesh(sphere,pairMaterial,members.length);
  focus.add(ring);pairGlyphs.push({mesh:ring,points:members,indices:visibleMemberIndices(plane.normal)});
  const boundary=planeSection(plane.normal,radius).map(p=>physical(movedXYZ(p)).toArray()), vertices=[];
  for(let i=1;i<boundary.length;i++)vertices.push(0,0,0,...boundary[i-1],...boundary[i]);
  const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(vertices,3));
  const sheet=new THREE.Mesh(geometry,new THREE.MeshBasicMaterial({color:0xffba6b,transparent:true,opacity:0.045,side:THREE.DoubleSide,depthWrite:false}));sheet.name='pair-plane';focus.add(sheet);
  focus.add(lines([boundary],0xffba6b,0.35));
  const directions=coneDirections(plane).map(movedXYZ);
  focus.add(lines(directions.map(p=>[p.map(x=>-radius*scale*x),p.map(x=>radius*scale*x)]),0xffba6b,0.7));
  if(secondSelection&&secondVisible) {
    const marker=new THREE.Mesh(sphere,pairMaterial);marker.position.copy(physical(displayedVector(secondSelection)));
    focus.add(marker);focusGlyphs.push({mesh:marker,extra:outlinePixels,point:secondSelection});
  }
  if(projectionVisible)focus.add(lines([directions.map(p=>p.map(x=>height*scale*x/p[1]))],0xffba6b,0.9));
}
function update() {
  if(!initialized)return;
  refreshActionGeometry();
  refreshColors();planeMembers=new Set();
  disposeChildren(focus);focusGlyphs=[];pairGlyphs=[];glyphKey=null; disk.visible=projectionVisible;if(projectionVisible&&!imageMesh)buildImages(); cone.visible=$('cone').checked;
  const inCloud=shown(selected);
  if(inCloud) {
    focus.add(lines([[[0,0,0],physical(displayedVector(selected)).toArray()]],0xbacbd6,0.35));
    const marker=new THREE.Mesh(sphere,selectionMaterial);
    marker.position.copy(physical(displayedVector(selected)));focus.add(marker);focusGlyphs.push({mesh:marker,extra:outlinePixels,point:selected});
  }
  const representative=positiveRepresentative(selected);
  if(projectionVisible && representative && inCloud) {
    const image=physical(displayedImage(representative));focus.add(lines([[[0,0,0],image.toArray()]],0xffffff));
    const marker=new THREE.Mesh(sphere,white);marker.position.copy(image);focus.add(marker);focusGlyphs.push({mesh:marker,extra:0});
  }
  $('point-state').textContent=`(a,b,c) = (${selected.join(', ')}) · Δ = ${discriminant(selected)}`;
  $('polynomial-state').textContent=`f(x) = ${spacedPolynomial(polynomial(selected))}`;
  const root=representative?upperRoot(representative):null;
  const shownRoot=root&&action.active?shownUpperRoot(displayedVector(selected),discriminant(selected)):null;
  const rootLabel=shownRoot?`${action.phase==='preview'?'Preview':'Shown'} upper root ≈ ${shownRoot.map(approximateNumber).join(' + ')}i · base ${root.map(approximateNumber).join(' + ')}i`:root?`Upper root: ${root.map(approximateNumber).join(' + ')}i${kind(selected)==='lower'?' · sign-flipped representative':''}`:kind(selected)==='null'?(selected[0]===0?'Boundary: double root at infinity':'Boundary: repeated real root'):'Exterior: two real projective roots (possibly ∞)';
  $('root-state').textContent=rootLabel;
  $('coefficient').value=selected.join(',');$('projection').checked=projectionVisible;
  $('status').textContent=operationError||(inCloud?'':'The selected point is hidden by this filter or crop.');
  syncCatalogueControls();
  const cat=lattice.catalogue;
  $('catalogue-status').textContent=cat?`${cat.upperCount.toLocaleString()} upper + ${cat.otherCount.toLocaleString()} other buffered forms · primitive upper roots only${!cat.complete?' · source limit: '+[cat.sourceLimited.upperCap?'upper cap':'',cat.sourceLimited.otherScanBound?'other scan omitted':''].filter(Boolean).join(', '):''}. Recrops on accepted release; signed selections persist.`:'Fixed signed ball · both signs and multiples retained.';
  $('inhabit').disabled=!inCloud&&!inhabited;
  updatePair();
  renderer.domElement.setAttribute('aria-description',`Selected coefficient point ${selected.join(', ')}. ${kind(selected)} region. ${lattice.count} points. Both cone halves ${cone.visible?'shown':'hidden'}.`);
  const [lo,hi]=paletteRange, reach=lattice.maxInterior;
  $('palette-bar').style.background=gradientCSS(categories);
  $('palette-label').textContent=`Upper interior |Δ| (log, ${categories==='viridis'?'Viridis 0.2–1':'Stange anchors'}) · crop reaches ${reach}`;
  for(const type of ['exterior','null','lower'])$(`swatch-${type}`).style.background=categoryPalettes[categories][type];
  $('palette-low').textContent=lo;$('palette-high').textContent=hi;
  updateMobiusReadout();
  render();
}
function actionCaption(){
  if(action.phase==='preview')return 'Numerical preview · release to ask Lean';
  if(action.phase==='pending'||absorptionPending)return 'Pending Lean · changes are not accepted';
  if(lastAbsorption&&!action.receipt)return 'Identity action · last Snap shown below';
  return action.receipt?`Lean accepted · ${lattice?.catalogue?'source depth catalogue':'fixed base crop'} · signed identities retained`:'Identity action · base integer labels';
}
let absorptionPending=false;
function updateMobiusReadout(){
  $('mobius-status').textContent=actionCaption()+(radius>12?' · dense preview ≤10 updates/s':'');
  const r=action.receipt;
  $('mobius-result').textContent=r&&action.phase==='accepted'?`Lean image (a′,b′,c′) = (${r.imageNumerator.join(', ')}) / ${r.denominator} · Δ = ${r.delta}`:lastAbsorption&&!r?`Last Snap from Lean: (${lastAbsorption.before.join(', ')}) → (${lastAbsorption.receipt.image.join(', ')}) · Δ = ${lastAbsorption.receipt.delta}`:'';
  $('mobius-drag').setAttribute('aria-pressed',String(mobiusMode));$('mobius-drag').textContent=mobiusMode?'Move forms ON':'Move forms';
  for(const id of ['mobius-drag','mobius-demo','mobius-clear','mobius-t','mobius-s','mobius-t-inverse','mobius-snap'])$(id).disabled=dataBusy;
  $('snap-release').disabled=dataBusy;$('snap-release').checked=snapOnRelease;
}
function queueActionRender(){
  if(mobiusFrame)return;
  const delay=radius>12?Math.max(0,100-(performance.now()-lastActionPaint)):0;
  mobiusFrame=setTimeout(()=>{mobiusFrame=0;lastActionPaint=performance.now();if(initialized)update();},delay);
}
function cancelMobiusInteraction(){
  motionTicket++;mobiusGesture=null;absorptionPending=false;action.cancel();clearHover();diskHoverIndex=null;
  kleinCanvas.classList.remove('is-dragging');
  lookDrag=null;tap.active.clear();tap.candidate=null;
  if(initialized){refreshActionGeometry();queueActionRender();}
}
function clearMotion(){
  if(dataBusy)return;cancelMobiusInteraction();
  return runData(async()=>{
    const ticket=motionTicket,isCurrent=()=>ticket===motionTicket;
    let candidate=null;
    if(catalogueMode==='source'){
      candidate=await stageCloud(radius,whole,catalogueMode,dust,identity,selected,secondSelection,isCurrent);
      if(!candidate||!isCurrent())return;
      acceptCloud(candidate);
    }
    action.reset();mobiusMode=false;if(candidate)rebuild();queueActionRender();
  });
}
function previewTo(z){
  if(!mobiusGesture||!z)return;
  if(!mobiusGesture.moved){action.begin(mobiusGesture.anchor);mobiusGesture.moved=true;}
  if(Math.hypot(z.x-action.anchor.x,z.y-action.anchor.y)<1e-9)return;
  if(action.move(z))queueActionRender();
}
async function absorbMatrix(matrix){
  const ticket=++motionTicket,before=[...selected];absorptionPending=true;updateMobiusReadout();
  try{
    const result=await prepareAbsorption({matrix,point:selected,second:secondSelection,commit:commitTransform,inspect:inspectWithRepresentative,preparePair:preparePlane,isCurrent:()=>ticket===motionTicket});
    if(!result||ticket!==motionTicket)return;
    if(!result.second&&kind(result.point)==='exterior'){
      const plane=await preparePlane(result.point);if(ticket!==motionTicket)return;
      if(plane?.error)throw Error(plane.error);
    }
    let candidate=null;
    if(catalogueMode==='source'){
      candidate=await stageCloud(radius,whole,catalogueMode,dust,identity,result.point,result.second,()=>ticket===motionTicket);
      if(!candidate||ticket!==motionTicket)return;
      acceptCloud(candidate);
    }
    selected=[...result.point];secondSelection=result.second?[...result.second]:null;pairMessage='';
    lastAbsorption={before,receipt:result.receipt};action.reset();if(candidate)rebuild();diskHoverIndex=null;clearHover();
  }catch(error){if(ticket!==motionTicket)return;action.cancel();throw error;}
  finally{if(ticket===motionTicket)absorptionPending=false;}
}
function finishMobiusGesture(){
  const moved=mobiusGesture?.moved;mobiusGesture=null;
  if(!moved)return;
  runData(async()=>{
    if(snapOnRelease){try{await absorbMatrix(nearestIntegral(action.g));}catch(error){action.cancel();throw error;}}
    else{const pending=action.commit(selected,secondSelection);updateMobiusReadout();await pending;}
  });
}
function setRootsView(value){
  cancelMobiusInteraction();rootsView=value;
  $('roots-view').setAttribute('aria-pressed',String(value));$('space-view').setAttribute('aria-pressed',String(!value));
  controls.enabled=spaceVisible()&&!inhabited&&!session;resize();
}
function setMobiusMode(value){
  if(dataBusy)return;cancelMobiusInteraction();mobiusMode=value;
  if(value&&spaceVisible()){if(session)spatialMode('origin');else enterOrigin();}
  updateMobiusReadout();
}
function commitPreset(M){
  if(dataBusy)return;cancelMobiusInteraction();
  runData(async()=>{const pending=action.commitMatrix(selected,M,secondSelection);updateMobiusReadout();await pending;});
}
function composeGenerator(generator){
  if(dataBusy)return;cancelMobiusInteraction();
  runData(async()=>{
    const M=composeInteger(generator,action.matrix),gamma=integralRepresentative(M);
    if(gamma)await absorbMatrix(gamma);
    else{const pending=action.commitMatrix(selected,M,secondSelection);updateMobiusReadout();await pending;}
  });
}
function snapMotion(){
  if(dataBusy)return;const g=[...action.g];cancelMobiusInteraction();
  runData(async()=>absorbMatrix(nearestIntegral(g)));
}
$('space-view').onclick=()=>setRootsView(false);$('roots-view').onclick=()=>setRootsView(true);
$('mobius-drag').onclick=()=>setMobiusMode(!mobiusMode);$('mobius-clear').onclick=clearMotion;
$('mobius-demo').onclick=()=>commitPreset([3,1,1,2]);$('mobius-snap').onclick=snapMotion;
$('snap-release').onchange=()=>{snapOnRelease=$('snap-release').checked;if(snapOnRelease)snapMotion();};
$('mobius-t').onclick=()=>composeGenerator([1,1,0,1]);$('mobius-s').onclick=()=>composeGenerator([0,-1,1,0]);$('mobius-t-inverse').onclick=()=>composeGenerator([1,-1,0,1]);
let diskHoverIndex=null,diskHoverTime=0;
function diskPixel(index){const k=3*index;return rootToClient([displayXYZ[k],displayXYZ[k+1],displayXYZ[k+2]],lattice.delta[index],kleinCanvas.getBoundingClientRect(),diskView);}
function diskPick(x,y){
  const started=performance.now(),r=kleinCanvas.getBoundingClientRect(),{scale,cx,cy}=chartTransform(r,diskView);
  const index=pickRoot(lattice,displayXYZ,kleinView.indices,scale,cx-x,cy-y,diskView.model==='half-plane'?7:10,{model:diskView.model,sigma});timings.rootPick=performance.now()-started;return index;
}
function drawKlein(){
  if(!displayXYZ||!rootsVisible()||kleinView.renderer.getContext().isContextLost())return;
  const started=performance.now(),r=kleinCanvas.getBoundingClientRect(),plane=currentPlane();
  if(r.width<=0||r.height<=0)return;
  kleinView.update({lattice,xyz:displayXYZ,colors:cloudMesh.geometry.attributes.color.array,revision:actionGeometryRevision,colorKey,model:diskView.model});
  const marker=p=>({xyz:displayedVector(p),delta:discriminant(p),label:spacedPolynomial(polynomial(p))});
  const hover=diskHoverIndex!==null&&diskHoverIndex>=0&&diskHoverIndex<lattice.count?marker(tripleAt(lattice,diskHoverIndex)):null;
  kleinView.render({width:r.width,height:r.height,...diskView,sigma,markers:[selected,secondSelection].map(p=>p&&shown(p)&&positiveRepresentative(p)?marker(p):null),hover,ends:plane?coneDirections(plane).map(movedXYZ):null,focus:cloudMaterial.uniforms.uFocus.value,fade:cloudMaterial.uniforms.uFocusFade.value,keep:cloudMaterial.uniforms.uKeep.value});
  timings.roots=performance.now()-started;
  if(!hoverPointer)showHover(null);
}
kleinCanvas.addEventListener('pointerdown',e=>{
  if(dataBusy||e.button!==0)return;e.preventDefault();clearHover();diskHoverIndex=null;drawKlein();kleinCanvas.setPointerCapture(e.pointerId);
  const anchor=pointerToUpper(e.clientX,e.clientY,kleinCanvas.getBoundingClientRect(),diskView);
  mobiusGesture={source:'disk',pointer:e.pointerId,start:[e.clientX,e.clientY],last:[e.clientX,e.clientY],anchor,moved:false,pan:e.shiftKey};kleinCanvas.classList.add('is-dragging');
});
kleinCanvas.addEventListener('pointermove',e=>{
  if(mobiusGesture?.source==='disk'&&mobiusGesture.pointer===e.pointerId){
    if(mobiusGesture.pan){if(!mobiusGesture.moved&&Math.hypot(e.clientX-mobiusGesture.start[0],e.clientY-mobiusGesture.start[1])<4)return;diskView.pan[0]+=e.clientX-mobiusGesture.last[0];diskView.pan[1]+=e.clientY-mobiusGesture.last[1];mobiusGesture.last=[e.clientX,e.clientY];mobiusGesture.moved=true;drawKlein();return;}
    if(mobiusGesture.anchor&&Math.hypot(e.clientX-mobiusGesture.start[0],e.clientY-mobiusGesture.start[1])>=4)previewTo(pointerToUpper(e.clientX,e.clientY,kleinCanvas.getBoundingClientRect(),diskView));
  }else if(!dataBusy&&(radius<=12||performance.now()-diskHoverTime>=100)){hoverPointer=null;diskHoverTime=performance.now();diskHoverIndex=diskPick(e.clientX,e.clientY);drawKlein();}
});
kleinCanvas.addEventListener('pointerup',e=>{
  const g=mobiusGesture;if(!g||g.source!=='disk'||g.pointer!==e.pointerId)return;
  kleinCanvas.classList.remove('is-dragging');
  if(g.pan&&g.moved){mobiusGesture=null;return;}
  if(g.moved){previewTo(pointerToUpper(e.clientX,e.clientY,kleinCanvas.getBoundingClientRect(),diskView));finishMobiusGesture();}
  else{mobiusGesture=null;const i=diskPick(e.clientX,e.clientY);if(i>=0)selectPoint(tripleAt(lattice,i),e.shiftKey);}
});
kleinCanvas.addEventListener('pointercancel',cancelMobiusInteraction);
kleinCanvas.addEventListener('pointerleave',()=>{diskHoverIndex=null;drawKlein();});
kleinCanvas.addEventListener('wheel',e=>{e.preventDefault();if(mobiusGesture)return;diskHoverIndex=null;Object.assign(diskView,zoomChartAt(e.clientX,e.clientY,kleinCanvas.getBoundingClientRect(),diskView,THREE.MathUtils.clamp(diskView.zoom*Math.exp(-e.deltaY*.0015),.5,8)));drawKlein();},{passive:false});
function resetRootsChart(){
  diskView.zoom=1;diskView.pan=[0,0];diskHoverIndex=null;rootsRect=null;
  if(rootsVisible()){
    const r=kleinCanvas.getBoundingClientRect();
    if(r.width>0&&r.height>0)rootsRect={left:r.left,top:r.top,width:r.width,height:r.height};
  }
}
$('roots-model').onchange=()=>{cancelMobiusInteraction();diskView.model=$('roots-model').value;resetRootsChart();kleinCanvas.setAttribute('aria-label',`${diskView.model==='half-plane'?'Upper half-plane':'Klein disk'} of roots. Drag to move forms; Shift-drag to pan; wheel to zoom.`);resize();};
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&mobiusGesture){e.preventDefault();cancelMobiusInteraction();}});
const tempLocal=new THREE.Vector3(),tempWorld=new THREE.Vector3();
// Which of her size causes applies: the origin-eye rule in Origin mode, plane emphasis for upper members.
const radiusFactor=p=>sigma*sourceRadiusFactorFromData(discriminant(p),kind(p),divisor(p),displayedVector(p)[1],{origin:originMode,onPlane:!originMode&&kind(p)==='upper'&&planeMembers.has(p.join()),symmetric:symmetricColor});
function updateGlyphSizes(){
  if(!cloudMesh)return;
  camera.updateMatrixWorld();world.updateMatrixWorld(true);
  const height=renderer.domElement.clientHeight;
  const key=camera.matrixWorld.elements.join(',')+'|'+height+'|'+camera.zoom+'|'+session+'|'+camera.fov;
  if(key===glyphKey)return;glyphKey=key;
  // Her overview fog: alpha falls by up to 55% between d−0.7R and d+0.9R from the eye (none in eye mode).
  const d=camera.position.distanceTo(controls.target), R=radius*scale, u=cloudMaterial.uniforms;
  u.uFog.value.set(Math.max(0.1*scale,d-0.7*R),d+0.9*R,inhabited||session?0:0.55);
  u.uHalfH.value=height/2;u.uGlyph.value=glyphRadius*sigma;u.uDpr.value=renderer.getPixelRatio();u.uOrigin.value=originMode?1:0;
  for(const item of pairGlyphs) {
    item.points.forEach((p,i)=>{
      const j=item.indices[i],k=3*j;tempLocal.fromArray(displayXYZ,k).multiplyScalar(scale);
      tempWorld.copy(tempLocal).applyMatrix4(world.matrixWorld).applyMatrix4(camera.matrixWorldInverse);
      const size=session?1.2:glyphScale(-tempWorld.z,height,camera.fov,camera.zoom,0.65,sigma*sourceRadiusFactorFromData(lattice.delta[j],lattice.kind[j],lattice.divisor[j],displayXYZ[k+1],{origin:originMode,onPlane:!originMode&&lattice.kind[j]===2,symmetric:symmetricColor}));
      matrix.makeScale(size,size,size);matrix.setPosition(tempLocal);item.mesh.setMatrixAt(i,matrix);
    });
    item.mesh.instanceMatrix.needsUpdate=true;item.mesh.computeBoundingSphere();
  }
  origin.visible=!eyeAtOrigin();
  for(const item of [{mesh:origin,extra:0},...focusGlyphs]){
    tempWorld.copy(item.mesh.position).applyMatrix4(world.matrixWorld).applyMatrix4(camera.matrixWorldInverse);
    item.mesh.scale.setScalar(session?(item.extra?1.4:1):glyphScale(-tempWorld.z,height,camera.fov,camera.zoom,item.extra,item.point?radiusFactor(item.point):1));
  }
}
function render(){if(!initialized)return;if(rootsVisible())drawKlein();if(!spaceVisible())return;if(dataBusy){if(session)updateAims();renderer.render(scene,camera);return;}if(!renderer.getContext().isContextLost()){updateGlyphSizes();if(session){updateMobiusController();updateAims();}renderer.render(scene,camera);if(!$('debug').hidden)showDebug();if(hoverPointer&&!session){if(hoverShown&&hoverShown!==hoverKey(hoverPointer.x,hoverPointer.y))showHover(null);scheduleHover();}}}
// Debug overlay: closed by default; reads only counters that already exist, and only while open.
let frameMeasure=null, frameRequest=null;
function showDebug(){
  if($('debug').hidden)return;
  const info=renderer.info.render, attributes=cloudMesh.geometry.attributes, ms=x=>x===undefined?'—':`${x.toFixed(1)} ms`;
  const buffers=new Set([...Object.values(lattice).filter(ArrayBuffer.isView).map(a=>a.buffer),...Object.values(attributes).map(a=>a.array.buffer)]);
  const bytes=[...buffers].reduce((n,b)=>n+b.byteLength,0);
  const gl=renderer.getContext(),ext=gl.getExtension('WEBGL_debug_renderer_info');
  const rows=[
    ['Distinct lattice points (exact)',lattice.count.toLocaleString()],
    ['Bound (exact)',lattice.catalogue?`source depth ${radius}; buffered trace/other catalogue`:`b²+2a²+2c² ≤ ${radius}²${whole?'':', a>0, Δ<0'}`],
    ['GL point primitives (measured, last frame)',info.points.toLocaleString()],
    ['Triangles (measured, last frame)',info.triangles.toLocaleString()],
    ['Draw calls (measured, last frame)',info.calls],
    ['Accept Lean cloud (measured CPU)',ms(timings.enumerate)],
    ['Fill point buffers (measured CPU)',ms(timings.attributes)],
    ['Recolor (measured CPU)',ms(timings.colors)],
    ['Size factors (measured CPU)',ms(timings.factors)],
    ['Klein images (measured CPU)',ms(timings.images)],
    ['Last click pick (measured CPU)',ms(timings.pick)],
    ['XR hover queries',lattice.count<hoverWorkerPoints?'main thread (small crop)':hoverQueries.failed?'main thread (worker unavailable)':'worker'],
    ['Worker scan / round trip (measured)',`${ms(hoverQueries.lastQueryMs)} / ${ms(hoverQueries.lastLatencyMs)}`],
    ['Lattice copy for worker (measured CPU)',ms(hoverQueries.copyMs)],
    ['Last transferred worker buffer',`${hoverQueries.copyBytes.toLocaleString()} bytes`],
    ['Cloud + point CPU buffers (counted)',`${(bytes/1048576).toFixed(1)} MB`],
    ['Main-realm JS heap (Chrome; excludes worker)',performance.memory?`${(performance.memory.usedJSHeapSize/1048576).toFixed(0)} MB`:'unavailable'],
    ['Frame interval, 60 frames (measured, vsync-capped)',frameMeasure??'not measured'],
    ['GL renderer',ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER)],
  ];
  $('debug-rows').replaceChildren(...rows.flatMap(([k,v])=>{const dt=document.createElement('dt'),dd=document.createElement('dd');dt.textContent=k;dd.textContent=v;return [dt,dd];}));
}
function closeDebug(){
  if(frameRequest!==null)cancelAnimationFrame(frameRequest);
  frameRequest=null;$('debug-frames').disabled=false;
  $('debug').hidden=true;$('debug-toggle').setAttribute('aria-expanded','false');$('debug-toggle').focus();
}
$('debug-toggle').onclick=()=>{if(!$('debug').hidden){closeDebug();return;}$('debug').hidden=false;$('debug-toggle').setAttribute('aria-expanded','true');render();};
$('debug-close').onclick=closeDebug;
document.addEventListener('keydown',event=>{if(event.key==='Escape'&&!$('debug').hidden){event.preventDefault();event.stopPropagation();closeDebug();}},true);
$('debug-frames').onclick=()=>{
  if(frameRequest!==null||$('debug').hidden)return;
  $('debug-frames').disabled=true;
  const times=[];let last=performance.now();
  const step=now=>{
    frameRequest=null;if($('debug').hidden)return;
    times.push(now-last);last=now;render();
    if(times.length<60)frameRequest=requestAnimationFrame(step);
    else{times.sort((a,b)=>a-b);frameMeasure=`median ${times[30].toFixed(1)} ms · p90 ${times[54].toFixed(1)} ms`;$('debug-frames').disabled=false;showDebug();}
  };
  frameRequest=requestAnimationFrame(step);
};

const eyeAtOrigin=()=>inhabited&&camera.position.distanceTo(world.position)<1e-9;
function showLocation() {
  if(!inhabited)return;
  const p=camera.position.clone().sub(world.position).divideScalar(scale);
  $('location').textContent=`Eye (x,y,z): ${p.toArray().map(x=>x.toFixed(2)).join(', ')} · ${cameraPlaneLabel(camera.quaternion)}`;
  $('origin-note').hidden=!eyeAtOrigin();
  $('origin').setAttribute('aria-pressed',String(eyeAtOrigin()));
}
// Explicit yaw/pitch avoid re-deriving angles from a quaternion at the poles, so the eye can look exactly along ±Y.
function applyLook(){
  camera.quaternion.setFromEuler(new THREE.Euler(look.pitch,look.yaw,0,'YXZ'));
  controls.target.copy(camera.position).add(camera.getWorldDirection(new THREE.Vector3()));
  showLocation();render();
}
function beginEgocentric(){
  if(!inhabited)overviewView=captureView(camera,controls);
  inhabited=true;controls.enabled=false;camera.near=0.008;
  $('navigation').hidden=false;$('inhabit').textContent='Return to overview';$('view').disabled=true;
  renderer.domElement.focus({preventScroll:true});
}
function enterInhabit() {
  cancelMobiusInteraction();mobiusMode=false;
  beginEgocentric();originMode=false;camera.fov=overviewFov;camera.updateProjectionMatrix();
  camera.position.copy(world.position).add(physical(displayedVector(selected))).add(new THREE.Vector3(0.10,0.12,0.10));
  const aim=world.position.clone();aim.y=camera.position.y;camera.lookAt(aim);
  const e=new THREE.Euler().setFromQuaternion(camera.quaternion,'YXZ');look={yaw:e.y,pitch:e.x};applyLook();
}
// The coordinate origin is the zero polynomial: no unique root or projective point, and radial projection is
// undefined. Every line of sight from it is one projective class of nonzero forms, and looking along +Y the perspective image of the upper nappe is the Klein disk.
function enterOrigin() {
  cancelMobiusInteraction();
  beginEgocentric();originMode=true;glyphKey=null;camera.fov=originFov;camera.updateProjectionMatrix();
  camera.position.copy(world.position);look={yaw:0,pitch:Math.PI/2};applyLook();
}
function leaveInhabit() {
  if(!inhabited)return;
  cancelMobiusInteraction();mobiusMode=false;
  inhabited=false;originMode=false;glyphKey=null;controls.enabled=true;camera.near=0.05;camera.fov=overviewFov;camera.updateProjectionMatrix();
  if(overviewView)restoreView(overviewView,camera,controls);overviewView=null;
  $('navigation').hidden=true;$('inhabit').textContent='Inhabit';$('view').disabled=false;
  $('origin').setAttribute('aria-pressed','false');render();
}
function moveEye(direction) {
  if(!inhabited)return;
  if(mobiusMode){cancelMobiusInteraction();mobiusMode=false;updateMobiusReadout();}
  const forward=camera.getWorldDirection(new THREE.Vector3());
  const right=new THREE.Vector3(1,0,0).applyQuaternion(camera.quaternion);
  const delta=direction==='forward'?forward:direction==='back'?forward.negate():direction==='right'?right:direction==='left'?right.negate():new THREE.Vector3(0,direction==='up'?1:-1,0);
  delta.multiplyScalar(0.12);camera.position.add(delta);controls.target.add(delta);showLocation();render();
}
$('inhabit').onclick=()=>inhabited?leaveInhabit():enterInhabit();
// Origin is a location preset inside the egocentric mode; the Inhabit button alone toggles back to the overview.
$('origin').onclick=enterOrigin;
for(const button of document.querySelectorAll('[data-look]'))button.onclick=()=>{look.pitch={up:Math.PI/2,level:0,down:-Math.PI/2}[button.dataset.look];applyLook();renderer.domElement.focus({preventScroll:true});};
for(const button of document.querySelectorAll('[data-move]'))button.onclick=()=>{moveEye(button.dataset.move);renderer.domElement.focus({preventScroll:true});};
function resetView(){controls.target.copy(world.position);camera.position.copy(world.position).add(new THREE.Vector3(2.4,1.5,4.6).multiplyScalar(Math.max(1,radius/8)));controls.update();}
function resize(){
  if(session)return;
  const r=$('viewport').getBoundingClientRect();if(r.width<=0||r.height<=0)return;
  for(const key of ['left','top','width','height','right','bottom'])kleinCanvas.style[key]='';
  if(innerWidth<1000)Object.assign(kleinCanvas.style,{left:`${r.left}px`,top:`${r.top}px`,width:`${r.width}px`,height:`${r.height}px`,right:'auto',bottom:'auto'});
  kleinCanvas.hidden=!rootsVisible();renderer.domElement.style.visibility=spaceVisible()?'visible':'hidden';
  if(!rootsVisible()&&mobiusGesture?.source==='disk')cancelMobiusInteraction();
  controls.enabled=spaceVisible()&&!inhabited;
  if(rootsVisible()){
    const next=kleinCanvas.getBoundingClientRect();
    if(rootsRect&&mobiusGesture?.source==='disk'&&['left','top','width','height'].some(key=>next[key]!==rootsRect[key]))cancelMobiusInteraction();
    if(rootsRect&&(next.width!==rootsRect.width||next.height!==rootsRect.height)){
      Object.assign(diskView,resizeChart(rootsRect,next,diskView));
    }
    rootsRect={left:next.left,top:next.top,width:next.width,height:next.height};
  }
  camera.aspect=r.width/r.height;camera.updateProjectionMatrix();renderer.setSize(r.width,r.height);render();
}
$('next').onclick=()=>{const sequence=[...examples,[-1,1,-2],[1,2,1],[1,3,1]];const i=sequence.findIndex(p=>p.every((x,j)=>x===selected[j]));selectPoint(sequence[(i+1)%sequence.length]);};
// Her Star size control (0.4–2.5) scales every star radius.
$('star-size').oninput=()=>{sigma=Number($('star-size').value);$('star-size-value').textContent=sigma.toFixed(2);glyphKey=null;render();};
$('plane-focus').onchange=()=>{planeFocus=$('plane-focus').checked;update();};
$('palette').onchange=()=>{categories=$('palette').value;update();};
$('projection').onchange=()=>{projectionVisible=$('projection').checked;update();};
$('cone').onchange=update;
$('whole').onchange=()=>changeCloud(radius,$('whole').checked);
$('catalogue-mode').onchange=()=>changeCloud(radius,whole,false,$('catalogue-mode').value,dust);
$('dust').onchange=()=>changeCloud(radius,whole,false,catalogueMode,$('dust').checked);
$('symmetric-color').onchange=()=>{symmetricColor=$('symmetric-color').checked;update();};
$('radius').onchange=()=>changeCloud(Number($('radius').value),whole);
$('view').onclick=()=>{camera.position.sub(controls.target).applyAxisAngle(new THREE.Vector3(0,1,0),Math.PI/3).add(controls.target);controls.update();};
$('reset').onclick=()=>changeCloud(6,true,true);
function selectEntered(asPair=false) {
  const parts=$('coefficient').value.split(',').map(s=>s.trim()),next=parts.map(Number);
  if(parts.length!==3||parts.some(s=>!/^[-+]?\d+$/.test(s))||!next.every(n=>Number.isSafeInteger(n)&&Math.abs(n)<=IDENTITY_BOUND)||!next.some(n=>n!==0)) {
    $('status').textContent=`Choose a nonzero integer triple with each coefficient between −${IDENTITY_BOUND} and ${IDENTITY_BOUND}. The current selection is unchanged.`;return;
  }
  selectPoint(next,asPair);
}
$('coefficient-form').onsubmit=event=>{event.preventDefault();selectEntered();};
$('pair-add').onclick=()=>selectEntered(true);
$('pair-clear').onclick=()=>{if(dataBusy)return;cancelMobiusInteraction();secondSelection=null;pairMessage='';update();$('pair-add').focus({preventScroll:true});};
const raycaster=new THREE.Raycaster(),pointer=new THREE.Vector2(),tap=new TapSelection();
// The ray is mapped into lattice units (a uniform scale and translation keep angles), then searched exactly.
function rayInLattice(ray){
  cloudMesh.updateMatrixWorld(true);
  const inverse=new THREE.Matrix4().copy(cloudMesh.matrixWorld).invert();
  return {origin:ray.origin.clone().applyMatrix4(inverse).toArray(),direction:ray.direction.clone().transformDirection(inverse).toArray(),minDistance:session?0:camera.near/scale};
}
function pickIndex(ray,maxAngle){
  const t=performance.now(), local=rayInLattice(ray);
  const i=nearestToRayPacked(local.origin,local.direction,pickLattice.xyz,lattice.count,maxAngle,local.minDistance);
  timings.pick=performance.now()-t;
  return i;
}
function pickPoint(ray,maxAngle,asPair=false){const i=pickIndex(ray,maxAngle);if(i>=0)selectPoint(tripleAt(lattice,i),asPair);}
// Desktop clicks select the nearest center within about 10 CSS pixels of the pointer.
const clickAngle=r=>10*2*Math.tan(camera.fov*Math.PI/360)/(r.height*camera.zoom);
function pointerRay(x,y){const r=renderer.domElement.getBoundingClientRect();pointer.set(2*(x-r.left)/r.width-1,1-2*(y-r.top)/r.height);raycaster.setFromCamera(pointer,camera);return {ray:raycaster.ray.clone(),angle:clickAngle(r)};}
function selectAt(event){if(dataBusy||!initialized)return;const {ray,angle}=pointerRay(event.clientX,event.clientY);pickPoint(ray,angle,event.shiftKey);}
function upperFromRay(ray){
  const local=rayInLattice(ray),[ox,oy,oz]=local.origin,[dx,dy,dz]=local.direction;
  if(Math.abs(dy)<1e-9)return null;
  const y=Math.sign(dy)*height,t=(y-oy)/dy;if(t<=0)return null;
  return kleinToUpper((ox+t*dx)/y,(oz+t*dz)/y);
}
renderer.domElement.addEventListener('pointerdown',e=>{
  if(dataBusy)return;tap.begin(e);showHover(null);
  if(mobiusMode&&eyeAtOrigin()&&e.button===0){
    const anchor=upperFromRay(pointerRay(e.clientX,e.clientY).ray);
    if(anchor){mobiusGesture={source:'space',pointer:e.pointerId,anchor,start:[e.clientX,e.clientY],moved:false};renderer.domElement.setPointerCapture(e.pointerId);return;}
  }
  if(inhabited){lookDrag={x:e.clientX,y:e.clientY};renderer.domElement.setPointerCapture(e.pointerId);}
});renderer.domElement.addEventListener('pointermove',e=>{
  diskHoverIndex=null;
  tap.move(e);
  if(mobiusGesture?.source==='space'&&mobiusGesture.pointer===e.pointerId){
    if(Math.hypot(e.clientX-mobiusGesture.start[0],e.clientY-mobiusGesture.start[1])>=4)previewTo(upperFromRay(pointerRay(e.clientX,e.clientY).ray));return;
  }
  if(e.pointerType==='touch')hoverPointer=null;else hoverPointer={x:e.clientX,y:e.clientY};
  // The label belongs to the previous position until the next frame recomputes it, so it is hidden now.
  showHover(null);if(!e.buttons&&!lookDrag)scheduleHover();
  if(!inhabited||!lookDrag)return;
  look.yaw-=(e.clientX-lookDrag.x)*0.004;
  look.pitch=THREE.MathUtils.clamp(look.pitch-(e.clientY-lookDrag.y)*0.004,-Math.PI/2,Math.PI/2);
  lookDrag={x:e.clientX,y:e.clientY};applyLook();
});renderer.domElement.addEventListener('pointerup',e=>{
  lookDrag=null;
  if(mobiusGesture?.source==='space'&&mobiusGesture.pointer===e.pointerId){
    const moved=mobiusGesture.moved;if(moved)previewTo(upperFromRay(pointerRay(e.clientX,e.clientY).ray));
    if(moved){tap.cancel(e);finishMobiusGesture();}else{mobiusGesture=null;if(tap.end(e))selectAt(e);}return;
  }
  if(tap.end(e)&&!session)selectAt(e);scheduleHover();
});renderer.domElement.addEventListener('pointerleave',clearHover);renderer.domElement.addEventListener('pointercancel',e=>{lookDrag=null;tap.cancel(e);cancelMobiusInteraction();clearHover();});
renderer.domElement.addEventListener('keydown',e=>{const move={w:'forward',s:'back',a:'left',d:'right',q:'down',e:'up'}[e.key.toLowerCase()];if(inhabited&&move){e.preventDefault();moveEye(move);return;}if(e.key==='Escape'&&inhabited){leaveInhabit();return;}if(e.key==='Home'){e.preventDefault();leaveInhabit();resetView();}if(['+','=','-'].includes(e.key)){e.preventDefault();if(inhabited){moveEye(e.key==='-'?'back':'forward');return;}const d=camera.position.distanceTo(controls.target),n=THREE.MathUtils.clamp(d*(e.key==='-'?1.1:1/1.1),controls.minDistance,controls.maxDistance);camera.position.sub(controls.target).multiplyScalar(n/d).add(controls.target);controls.update();}});
controls.addEventListener('change',render);window.addEventListener('resize',resize);new ResizeObserver(resize).observe($('viewport'));
// Controller equivalents use the same accepted data/state actions as desktop.
let xrMode='overview',xrPair=false,xrWorldSaved=null;
function invalidateSpatialQueries(){latticeGeneration++;hoverQueries.reset();hoverGeneration=null;for(const aim of aims){aim.target=aim.shown=null;aim.next=0;aim.line.visible=aim.ring.visible=false;}glyphKey=null;}
function spatialMode(mode){
  if(!session){if(mode==='origin')enterOrigin();else if(mode==='inhabit')enterInhabit();else leaveInhabit();return;}
  cancelMobiusInteraction();if(mode!=='origin')mobiusMode=false;
  if(mode==='inhabit'&&!shown(selected))return;
  xrMode=mode;originMode=mode==='origin';glyphKey=null;
  const eye=renderer.xr.getCamera().getWorldPosition(new THREE.Vector3());
  world.quaternion.identity();invalidateSpatialQueries();
  if(mode==='overview')world.position.copy(xrWorldSaved.position);
  else world.position.copy(eye).sub(mode==='origin'?new THREE.Vector3():physical(displayedVector(selected)).add(new THREE.Vector3(.10,.12,.10)));
}
function spatialMove(direction){
  if(!session){moveEye(direction);return;}
  cancelMobiusInteraction();mobiusMode=false;
  const eye=renderer.xr.getCamera(),q=eye.quaternion;
  const v=direction==='forward'?new THREE.Vector3(0,0,-1).applyQuaternion(q):direction==='back'?new THREE.Vector3(0,0,1).applyQuaternion(q):direction==='left'?new THREE.Vector3(-1,0,0).applyQuaternion(q):new THREE.Vector3(1,0,0).applyQuaternion(q);
  world.position.addScaledVector(v,-.12);originMode=false;invalidateSpatialQueries();
}
const xrPanel=new THREE.Group();xrPanel.position.set(0,1,-1.15);xrPanel.visible=false;scene.add(xrPanel);const xrTargets=[];
const xrActions=[
  ['Next',()=>$('next').click()],['Projection',()=>$('projection').click()],['Reset',async()=>{await changeCloud(6,true,true);if(session)spatialMode('overview');xrPair=false;}],['Exit',()=>session?.end()],
  ['Origin',()=>spatialMode('origin')],['Inhabit',()=>spatialMode('inhabit')],['Overview',()=>spatialMode('overview')],['Other side',()=>{cancelMobiusInteraction();world.rotateY(-Math.PI/3);invalidateSpatialQueries();}],
  [()=>`${catalogueMode==='source'?'Depth':'R'} ${radius}`,()=>changeCloud(latticeRadii[(latticeRadii.indexOf(radius)+1)%latticeRadii.length],whole)],['Whole',()=>$('whole').click()],['Lower color',()=>$('symmetric-color').click()],['Cone',()=>$('cone').click()],
  [()=>xrPair?'Pair aim ON':'Pair aim',()=>{xrPair=!xrPair;}],['Clear pair',()=>$('pair-clear').click()],['Plane fade',()=>$('plane-focus').click()],['Colors',()=>{categories=categories==='viridis'?'reference':'viridis';$('palette').value=categories;update();}],
  ['Size −',()=>{sigma=Math.max(.4,sigma-.2);$('star-size').value=sigma;$('star-size-value').textContent=sigma.toFixed(2);glyphKey=null;}],['Size +',()=>{sigma=Math.min(2.5,sigma+.2);$('star-size').value=sigma;$('star-size-value').textContent=sigma.toFixed(2);glyphKey=null;}],['Forward',()=>spatialMove('forward')],['Back',()=>spatialMove('back')],
  ['Left',()=>spatialMove('left')],['Right',()=>spatialMove('right')],
  [()=>mobiusMode?'Move forms ON':'Move forms',()=>setMobiusMode(!mobiusMode)],['Identity',clearMotion],
  ['T: z+1',()=>composeGenerator([1,1,0,1])],['S: -1/z',()=>composeGenerator([0,-1,1,0])],['T inverse',()=>composeGenerator([1,-1,0,1])],['Exact move',()=>commitPreset([3,1,1,2])],
  ['Snap',snapMotion],[()=>snapOnRelease?'Snap release ON':'Snap release OFF',()=>{snapOnRelease=!snapOnRelease;if(snapOnRelease)snapMotion();}],
  [()=>catalogueMode==='source'?'Source depth':'Canonical ball',()=>changeCloud(radius,whole,false,catalogueMode==='source'?'canonical':'source',dust)],
  [()=>catalogueMode!=='source'||whole?'Dust n/a':dust?'Dust ON':'Dust OFF',()=>{if(catalogueMode==='source'&&!whole)$('dust').click();}]
];
for(const [i,[label,action]] of xrActions.entries()){
  const canvas=document.createElement('canvas');canvas.width=320;canvas.height=128;
  const button=new THREE.Mesh(new THREE.PlaneGeometry(.22,.085),new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(canvas)}));
  button.position.set((i%4-1.5)*.24,.25-Math.floor(i/4)*.10,0);button.userData={canvas,labelProvider:label,action:()=>{if(!dataBusy||label==='Exit')action();}};
  xrTargets.push(button);xrPanel.add(button);
}
function updateXRButtons(){
  for(const b of xrTargets){const label=typeof b.userData.labelProvider==='function'?b.userData.labelProvider():b.userData.labelProvider;if(label===b.userData.label)continue;b.userData.label=label;const ctx=b.userData.canvas.getContext('2d');ctx.fillStyle='#142b38';ctx.fillRect(0,0,320,128);ctx.fillStyle='#fff';ctx.font='34px system-ui';ctx.textAlign='center';ctx.fillText(label,160,78);b.material.map.needsUpdate=true;}
}
// XR aiming. The hover preview and the trigger use the same rule (aimTarget): an in-world button hit first,
// otherwise the lattice center nearest the controller ray within aimAngle. The trigger recomputes on its own
// ray, so after any movement, even below aimStale, it can pick a different point than the last preview; dense
// crops are not fully disambiguated. The viewer-facing ring uses distance × tan(aimAngle) as an approximate angular-scale cue, not a mathematical locus.
// Hover is cyan and never changes the selection; the selected point keeps its white outline.
const aimAngle=0.02, aimStale=0.001, aimColor=0x9fdcff;
const describe=p=>`(${p.join(', ')}) · ${spacedPolynomial(polynomial(p))} · Δ = ${discriminant(p)}`;
const readoutCanvas=document.createElement('canvas');readoutCanvas.width=1024;readoutCanvas.height=190;
const readoutTexture=new THREE.CanvasTexture(readoutCanvas);
const readout=new THREE.Mesh(new THREE.PlaneGeometry(0.94,0.175),new THREE.MeshBasicMaterial({map:readoutTexture,transparent:true}));
readout.position.y=0.405;xrPanel.add(readout);let readoutText='';
function showReadout(lines){
  const text=lines.join('\n');if(text===readoutText)return;readoutText=text;
  const ctx=readoutCanvas.getContext('2d');ctx.clearRect(0,0,1024,190);ctx.fillStyle='#0b1218d9';ctx.fillRect(0,0,1024,190);
  ctx.font='28px ui-monospace,Menlo,monospace';lines.forEach((line,i)=>{ctx.fillStyle=line.includes(' aim ')?'#9fdcff':'#f0f5f8';ctx.fillText(line,18,40+i*44);});
  readoutTexture.needsUpdate=true;
}
// Crops at least this large answer hover in a module worker; smaller ones scan in well under a millisecond.
const hoverWorkerPoints=50000;
const hoverQueries=new HoverQueries(()=>new Worker(new URL('./aim-worker.js',import.meta.url),{type:'module'}));
// Desktop pointer hover names the exact signed polynomial of the point a click there would select: the same
// angular radius and nearest-center scan as selectAt. It never selects, pairs or moves the camera. Crops of
// hoverWorkerPoints or more ask the worker on their own slot with one query in flight, so pointer motion never
// scans a dense crop on the UI thread. Unlike the XR preview's angular tolerance, a worker answer is shown only
// for exactly the inputs it was asked with (hoverKey): in dense crops half a CSS pixel can change the picked
// point, so any pointer, canvas, camera or lattice change hides the label until the current query returns.
const pointerSlot='pointer';
hoverQueries.onsettled=slot=>{if(slot===pointerSlot)scheduleHover();};
hoverQueries.onfailed=()=>scheduleHover();
// Everything the click rule depends on: pointer, canvas rect (angle and ray), camera pose and projection, lattice.
function hoverKey(x,y){
  const r=renderer.domElement.getBoundingClientRect();
  return [x,y,r.left,r.top,r.width,r.height,latticeGeneration,...camera.matrixWorld.elements,...camera.projectionMatrix.elements].join();
}
function scheduleHover(){if(!hoverFrame)hoverFrame=requestAnimationFrame(refreshHover);}
function refreshHover(){
  hoverFrame=0;
  if(!hoverPointer&&diskHoverIndex!==null)return;
  if(dataBusy||!initialized||!hoverPointer||!spaceVisible()||session||startingXR||lookDrag||mobiusGesture||tap.active.size||renderer.getContext().isContextLost()){showHover(null);return;}
  const {ray,angle}=pointerRay(hoverPointer.x,hoverPointer.y);
  if(lattice.count>=hoverWorkerPoints&&hoverQueries.available){
    const key=hoverKey(hoverPointer.x,hoverPointer.y), result=hoverQueries.result(pointerSlot);
    const fresh=result?.generation===latticeGeneration&&result.ray.key===key;
    showHover(fresh&&result.index>=0?result.index:null,key);
    // Busy: the settling answer reschedules this, which then asks again with the latest inputs.
    if(!fresh&&!hoverQueries.busy(pointerSlot)){const local=rayInLattice(ray);hoverQueries.request(pointerSlot,latticeGeneration,pickLattice,local.origin,local.direction,angle,local.minDistance,{key});}
  } else {const index=pickIndex(ray,angle);showHover(index>=0?index:null,hoverKey(hoverPointer.x,hoverPointer.y));}
}
// Forget the pointer as well as the label: leaving, cancelling, and XR entry (by mouse or keyboard, with the mouse
// still resting on the canvas) or exit must not let a later frame or worker answer re-show it.
function clearHover(){hoverPointer=null;showHover(null);}
// key: the hoverKey the index was computed for; render() hides the label as soon as the current key differs.
function showHover(index,key=null){
  const label=$('hover-label');
  if(index===null){label.hidden=true;label.dataset.point='';hoverShown=null;return;}
  hoverShown=key;
  const point=tripleAt(lattice,index), r=renderer.domElement.getBoundingClientRect();
  const v=new THREE.Vector3().fromArray(displayXYZ,3*index).applyMatrix4(cloudMesh.matrixWorld).project(camera);
  const x=r.left+(v.x+1)*r.width/2, y=r.top+(1-v.y)*r.height/2, text=$('hover-text');
  text.textContent=spacedPolynomial(polynomial(point));label.dataset.point=point.join();
  label.style.transform=`translate(${x}px,${y}px)`;label.hidden=false;
  // The ring stays on the center; the text sits above right, flipping and then clamping to stay on the canvas.
  const w=text.offsetWidth, h=text.offsetHeight, margin=4;
  let left=x+12+w>r.right-margin?-12-w:12, top=y-26<r.top+margin?12:-26;
  left=Math.min(Math.max(left,r.left+margin-x),r.right-margin-w-x);top=Math.min(Math.max(top,r.top+margin-y),r.bottom-margin-h-y);
  text.style.left=`${left}px`;text.style.top=`${top}px`;
}
function pointTarget(index,ray){
  const point=new THREE.Vector3().fromArray(displayXYZ,3*index).applyMatrix4(cloudMesh.matrixWorld);
  return {index,point,distance:point.distanceTo(ray.origin)};
}
const rayMoved=(ray,from,distance=1)=>ray.direction.angleTo(from.direction)>aimStale||ray.origin.distanceTo(from.origin)>aimStale*distance;
// One staleness test for a hand: the preview is hidden, and a dense hand re-queries, under exactly the same condition.
const aimStaleFor=(aim,ray)=>rayMoved(ray,aim.scanned,aim.target?.distance??1);
function aimTarget(controller){
  controllerRay(controller,raycaster);
  const hit=raycaster.intersectObjects(xrTargets)[0];
  if(hit)return {button:hit.object,distance:hit.distance};
  if(dataBusy)return null;
  const index=pickIndex(raycaster.ray,aimAngle);
  return index<0?null:pointTarget(index,raycaster.ray);
}
const aims=[0,1].map(i=>{
  const controller=renderer.xr.getController(i);scene.add(controller);
  const line=new THREE.Line(new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(),new THREE.Vector3(0,0,-1)]),new THREE.LineBasicMaterial({color:aimColor,transparent:true,opacity:0.35}));
  line.visible=false;controller.add(line);
  const ring=new THREE.Mesh(new THREE.RingGeometry(0.8,1,48),new THREE.MeshBasicMaterial({color:aimColor,transparent:true,opacity:0.9,side:THREE.DoubleSide,depthWrite:false}));
  ring.visible=false;ring.renderOrder=10;scene.add(ring);
  const aim={controller,line,ring,target:null,shown:null,next:0,source:null,scanned:new THREE.Ray(),index:i};
  controller.addEventListener('connected',e=>{aim.source=e.data;});
  controller.addEventListener('disconnected',()=>{if(mobiusGesture?.aim===aim)cancelMobiusInteraction();aim.source=null;aim.target=aim.shown=null;line.visible=ring.visible=false;});
  controller.addEventListener('selectstart',()=>{
    aim.suppressSelect=false;
    if(!session||dataBusy||!mobiusMode||xrMode!=='origin'||mobiusGesture)return;
    controllerRay(controller,raycaster);if(raycaster.intersectObjects(xrTargets).length)return;
    const anchor=upperFromRay(raycaster.ray);if(!anchor)return;
    aim.suppressSelect=true;mobiusGesture={source:'xr',aim,anchor,moved:false};
  });
  controller.addEventListener('selectend',()=>{
    if(mobiusGesture?.aim!==aim)return;
    // Consume the actual release pose, even if it arrived between frames.
    updateMobiusController();
    if(mobiusGesture?.moved)finishMobiusGesture();
    else{mobiusGesture=null;const target=aimTarget(controller);if(target&&!target.button)selectPoint(tripleAt(lattice,target.index),xrPair);}
  });
  controller.addEventListener('select',()=>{
    if(aim.suppressSelect){aim.suppressSelect=false;return;}
    const target=aimTarget(controller);aim.target=target;aim.scanned.copy(raycaster.ray);aim.generation=latticeGeneration;
    if(target)aim.source?.gamepad?.hapticActuators?.[0]?.pulse?.(0.3,30);
    if(target?.button)target.button.userData.action();else if(target)selectPoint(tripleAt(lattice,target.index),xrPair);
  });
  return aim;
});
let hoverGeneration=null;
function updateMobiusController(){
  if(mobiusGesture?.source!=='xr'||dataBusy)return;
  controllerRay(mobiusGesture.aim.controller,raycaster);
  const z=upperFromRay(raycaster.ray);if(!z)return;
  const previous=action.anchor??mobiusGesture.anchor;
  if(Math.hypot(z.x-previous.x,z.y-previous.y)>1e-6)previewTo(z);
}
function updateAims(){
  updateXRButtons();
  const now=performance.now(), eye=renderer.xr.getCamera();
  // Once per rebuilt lattice (radius, filter or reset), drop both hands' in-flight and answered worker queries.
  if(hoverGeneration!==latticeGeneration){hoverQueries.reset();hoverGeneration=latticeGeneration;}
  for(const aim of aims){
    aim.shown=null;
    if(!aim.source){aim.line.visible=aim.ring.visible=false;continue;}
    // A rebuilt lattice (radius, filter or reset) invalidates cached indices, positions and scan deadlines.
    if(aim.generation!==latticeGeneration){aim.target=null;aim.next=0;}
    aim.controller.updateWorldMatrix(true,false);cloudMesh.updateMatrixWorld();
    // A preview is shown only for the ray it was computed from: once the ray has moved more than aimStale it is
    // hidden until a newer answer arrives, while the trigger always recomputes on the current ray with the same
    // rule. Small crops, or a browser without a working module worker, scan here on the UI thread, waiting in
    // proportion to the scan's measured cost.
    controllerRay(aim.controller,raycaster);
    if(!dataBusy&&lattice.count>=hoverWorkerPoints&&hoverQueries.available){
      // Dense crops: buttons are hit-tested here (cheap, and they take priority); the point query runs in the worker.
      // The preview shows the latest answer for this generation, judged stale against the ray it was asked for.
      const hit=raycaster.intersectObjects(xrTargets)[0], result=hoverQueries.result(aim.index);
      if(hit){aim.target={button:hit.object,distance:hit.distance};aim.scanned.copy(raycaster.ray);}
      else if(result?.generation===latticeGeneration){aim.target=result.index<0?null:pointTarget(result.index,result.ray);aim.scanned.copy(result.ray);}
      else{aim.target=null;aim.scanned.copy(raycaster.ray);}
      aim.generation=latticeGeneration;
      if(!hit&&!hoverQueries.busy(aim.index)&&(result?.generation!==latticeGeneration||aimStaleFor(aim,raycaster.ray))){
        const local=rayInLattice(raycaster.ray);
        hoverQueries.request(aim.index,latticeGeneration,pickLattice,local.origin,local.direction,aimAngle,local.minDistance,raycaster.ray.clone());
      }
    } else if(dataBusy||now>=aim.next){const t=performance.now();aim.target=aimTarget(aim.controller);aim.scanned.copy(raycaster.ray);aim.generation=latticeGeneration;const cost=performance.now()-t;aim.next=now+(cost>4?8*cost:0);}
    const stale=aimStaleFor(aim,raycaster.ray);
    const target=aim.shown=stale?null:aim.target;
    aim.line.visible=true;aim.line.scale.z=target?target.distance:0.6;
    aim.ring.visible=!!target?.point;
    if(target?.point){aim.ring.position.copy(target.point);aim.ring.quaternion.copy(eye.quaternion);aim.ring.scale.setScalar(Math.max(target.distance*Math.tan(aimAngle),0.004));}
  }
  for(const button of xrTargets)button.material.color.setScalar(aims.some(a=>a.shown?.button===button)?1.6:1);
  // One aim line per connected hand, named by the input source's handedness, so each ring has its trigger.
  const hands=aims.filter(a=>a.source).sort((a,b)=>(a.source.handedness==='right')-(b.source.handedness==='right'));
  const aimLines=hands.map(a=>{
    const hand={left:'Left',right:'Right'}[a.source.handedness]??`Hand ${a.index+1}`;
    return `${hand} aim${' '.repeat(Math.max(1,6-hand.length))}${a.shown?.button?a.shown.button.userData.label:a.shown?describe(tripleAt(lattice,a.shown.index)):'—'}`;
  });
  const plane=currentPlane(),receipt=action.receipt;
  const actionLine=action.phase==='preview'||action.phase==='pending'?actionCaption():receipt?`Lean image (${receipt.imageNumerator.join(',')})/${receipt.denominator}`:null;
  showReadout([...aimLines,`Base        ${describe(selected)}`,...(actionLine?[actionLine]:plane?[`Plane       ${plane.equation}`]:[])]);
}
async function checkXR(){const availability=await xrAvailability(navigator.xr,isSecureContext);$('xr').disabled=!availability.supported;$('xr').textContent=availability.supported?'Enter VR':'VR unavailable here';$('xr-status').textContent=availability.message;}
let xrInteractionSaved=null;
function restoreDesktopFromXR(){
  cancelMobiusInteraction();
  session=null;clearHover();hoverQueries.reset();for(const aim of aims){aim.target=null;aim.line.visible=aim.ring.visible=false;}
  if(xrInteractionSaved){rootsView=xrInteractionSaved.rootsView;mobiusMode=xrInteractionSaved.mobiusMode;xrInteractionSaved=null;}
  kleinCanvas.hidden=!rootsVisible();renderer.domElement.style.visibility=spaceVisible()?'visible':'hidden';
  $('roots-view').setAttribute('aria-pressed',String(rootsView));$('space-view').setAttribute('aria-pressed',String(!rootsView));
  controls.enabled=spaceVisible()&&!inhabited;
  if(xrWorldSaved){world.position.copy(xrWorldSaved.position);world.quaternion.copy(xrWorldSaved.quaternion);originMode=xrWorldSaved.originMode;}
  xrWorldSaved=null;xrPair=false;xrPanel.visible=false;document.body.classList.remove('immersive');renderer.setAnimationLoop(null);
  if(savedView)restoreView(savedView,camera,controls);savedView=null;resize();checkXR();
}
$('xr').onclick=async()=>{
  if(startingXR||session)return;startingXR=true;clearHover();$('xr').disabled=true;
  xrInteractionSaved={rootsView,mobiusMode};mobiusMode=false;
  cancelMobiusInteraction();if(rootsView)setRootsView(false);
  savedView=captureView(camera,controls);xrWorldSaved={position:world.position.clone(),quaternion:world.quaternion.clone(),originMode};xrMode='overview';originMode=false;
  try{
    session=await navigator.xr.requestSession('immersive-vr',{optionalFeatures:['local-floor']});
    // Size the mirror before Three locks rendering to the immersive layer.
    document.body.classList.add('immersive');const r=$('viewport').getBoundingClientRect();renderer.setSize(r.width,r.height);
    await renderer.xr.setSession(session);controls.enabled=false;xrPanel.visible=true;renderer.setAnimationLoop(render);
  }catch(error){await session?.end().catch(()=>{});restoreDesktopFromXR();operationError='VR entry was cancelled or unavailable. The browser scene remains usable.';$('status').textContent=operationError;}
  finally{startingXR=false;}
};
renderer.xr.addEventListener('sessionend',restoreDesktopFromXR);
renderer.domElement.addEventListener('webglcontextlost',e=>{e.preventDefault();cancelMobiusInteraction();hoverQueries.reset();$('fatal').hidden=false;$('fatal').textContent='3D graphics paused. Waiting for the browser to restore the graphics context; reload if it does not recover.';controls.enabled=false;$('xr').disabled=true;session?.end().catch(()=>{});});
renderer.domElement.addEventListener('webglcontextrestored',()=>{$('fatal').hidden=true;controls.enabled=spaceVisible()&&!session&&!inhabited;resize();update();checkXR();});
kleinCanvas.addEventListener('webglcontextlost',e=>{e.preventDefault();cancelMobiusInteraction();$('fatal').hidden=false;$('fatal').textContent='2D graphics paused. Waiting for the browser to restore the graphics context; reload if it does not recover.';});
kleinCanvas.addEventListener('webglcontextrestored',()=>{$('fatal').hidden=true;update();});
for(const canvas of [renderer.domElement,kleinCanvas])canvas.addEventListener('lostpointercapture',e=>{if(mobiusGesture?.pointer===e.pointerId)cancelMobiusInteraction();else tap.cancel(e);});
window.addEventListener('blur',()=>{if(mobiusGesture||tap.active.size)cancelMobiusInteraction();});
// Labels are pinned fixture metadata; accepted counts and coordinates always come from Lean.
const fixtureCounts={24:28832,48:231348,96:1852484};
for(const option of $('radius').querySelectorAll('optgroup option'))option.textContent=`${option.value} · ${fixtureCounts[option.value].toLocaleString()} points`;
await changeCloud(6,true);resize();checkXR();
// Read-only diagnostics for reproducible app acceptance, never a second implementation.
window.polynomialDiagnostics=()=>({...diagnostics(),selected:[...selected],second:secondSelection?[...secondSelection]:null,radius,whole,catalogueMode,dust,visiblePointCount:visiblePoints?visiblePoints.reduce((n,v)=>n+v,0):lattice.count,visibleRootCount:(()=>{let n=0;for(let i=0;i<lattice.count;i++)if((lattice.kind[i]===2||(diskView.model==='klein'&&lattice.kind[i]===3))&&sourceRootVisible(lattice,i)&&(!visiblePoints||visiblePoints[i]))n++;return n;})(),catalogue:lattice.catalogue??null,projectionVisible,inhabited,originMode,categories,sigma,planeFocus,dataBusy,xr:!!session,xrMode,xrPair,rootsView,panes:{space:spaceVisible(),roots:rootsVisible(),wide:innerWidth>=1000},mobiusMode,snapOnRelease,lastAbsorption,rootsChart:{...diskView,pan:[...diskView.pan]},timings:{...timings},rootsRender:{points:kleinView.renderer.info.render.points,calls:kleinView.renderer.info.render.calls},action:{phase:action.phase,matrix:[...action.matrix],g:[...action.g],imageNumerator:action.receipt?.imageNumerator,denominator:action.receipt?.denominator,delta:action.receipt?.delta,displayedSelection:displayedVector(selected)},world:{position:world.position.toArray(),quaternion:world.quaternion.toArray()},xrButtons:xrTargets.map(b=>({label:b.userData.label,position:b.getWorldPosition(new THREE.Vector3()).toArray()})),view:{position:camera.position.toArray(),quaternion:camera.quaternion.toArray(),fov:camera.fov},render:{points:renderer.info.render.points,calls:renderer.info.render.calls},projectedSelection:(()=>{const r=renderer.domElement.getBoundingClientRect(),v=physical(displayedVector(selected)).applyMatrix4(world.matrixWorld).project(camera);return{x:r.left+(v.x+1)*r.width/2,y:r.top+(1-v.y)*r.height/2};})()});
