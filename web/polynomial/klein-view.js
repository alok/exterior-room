// SPDX-License-Identifier: GPL-3.0-or-later
// Renderer-only roots charts. UHP follows FareyVision 2cd549a roots-pane.js
// (SHA256 cbbbb4f0415d9cc534f5c0f4fd7287e5279c50bfb56581a1243fabb97ee1e87b).
// Its fit, radius, minimum footprint and square/disk threshold are preserved.
// UHP shows every accepted upper form; Klein also shows its negative partner.
// The accepted lattice is never changed and neither chart samples identities.
import * as THREE from 'three';
import {interiorIndices,fillRootPositions,orderRootsByRadius,rootSortWorkspace} from './klein-data.js';
import {chartTransform,rootCoordinates,halfPlaneGeodesic} from './mobius-render.js';

export class KleinView {
  constructor(canvas) {
    this.renderer=new THREE.WebGLRenderer({canvas,antialias:true});
    this.renderer.setPixelRatio(Math.min(devicePixelRatio,2));
    this.scene=new THREE.Scene();this.scene.background=new THREE.Color(0);
    this.camera=new THREE.OrthographicCamera(-1,1,1,-1,.1,10);this.camera.position.z=3;
    this.material=new THREE.ShaderMaterial({depthTest:false,depthWrite:false,transparent:true,uniforms:{size:{value:4},dpr:{value:1},halfPlane:{value:1},focus:{value:new THREE.Vector4()},fade:{value:new THREE.Vector2()},keep:{value:new THREE.Vector3()}},
      vertexShader:`attribute vec3 color; attribute vec3 aDisplay; attribute float aDelta;
        varying vec3 vColor; varying float vAlpha,vRadius; uniform float size,dpr,halfPlane; uniform vec4 focus; uniform vec2 fade; uniform vec3 keep;
        void main(){
          vColor=color;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);
          float radius;
          if(halfPlane>.5){
            radius=2.0*size/abs(aDisplay.y-aDisplay.z);
            vAlpha=radius<.08?0.0:min(1.0,pow(radius/.6,2.0));
            vRadius=max(radius,.6);
          }else{
            radius=size*pow(-aDelta,.25)/pow(abs(aDisplay.y),1.5);
            vAlpha=radius<1.0?radius*radius:1.0;
            if(radius>2.5)radius=2.5*pow(radius/2.5,1.0/3.0);
            vRadius=clamp(radius,1.0,9.0);
          }
          if(focus.w>.5&&aDisplay!=keep)vAlpha*=mix(1.0,fade.y,smoothstep(0.0,fade.x,abs(dot(focus.xyz,aDisplay))));
          gl_PointSize=2.0*vRadius*dpr;
        }`,
      fragmentShader:'varying vec3 vColor; varying float vAlpha,vRadius; uniform float halfPlane; void main(){if(vAlpha<=0.0)discard;if((halfPlane<.5||vRadius>=1.5)&&length(gl_PointCoord-vec2(.5))>.5)discard;gl_FragColor=vec4(vColor,vAlpha);}'});
    this.points=new THREE.Points(new THREE.BufferGeometry(),this.material);this.points.frustumCulled=false;this.scene.add(this.points);
    const circle=()=>new THREE.BufferGeometry().setFromPoints(Array.from({length:129},(_,i)=>new THREE.Vector3(Math.cos(i*Math.PI/64),Math.sin(i*Math.PI/64),0)));
    const overlay={transparent:true,depthTest:false,depthWrite:false};
    this.boundary=new THREE.Line(circle(),new THREE.LineBasicMaterial({color:0x4f8c96,...overlay}));this.boundary.renderOrder=1;this.scene.add(this.boundary);
    this.axes=new THREE.Group();this.scene.add(this.axes);
    this.axis=new THREE.LineSegments(new THREE.BufferGeometry(),new THREE.LineBasicMaterial({color:0x7896a8,...overlay}));this.axis.renderOrder=1;this.axes.add(this.axis);
    this.ticks=[[-1,'−1'],[-.5,'−½'],[0,'0'],[.5,'½'],[1,'1']].map(([x,text])=>{
      const canvas=document.createElement('canvas');canvas.width=96;canvas.height=40;
      const ctx=canvas.getContext('2d');ctx.font='22px system-ui,-apple-system,sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillStyle='#9fb2bd';ctx.fillText(text,48,20);
      const sprite=new THREE.Sprite(new THREE.SpriteMaterial({map:new THREE.CanvasTexture(canvas),...overlay}));sprite.renderOrder=1;sprite.userData.x=x;this.axes.add(sprite);return sprite;
    });
    this.markers=[0xffffff,0xffba6b].map(color=>{const line=new THREE.Line(circle(),new THREE.LineBasicMaterial({color,...overlay}));line.renderOrder=2;this.scene.add(line);return line;});
    this.chord=new THREE.Line(new THREE.BufferGeometry(),new THREE.LineBasicMaterial({color:0xffba6b,...overlay}));this.chord.renderOrder=1;this.scene.add(this.chord);
  }
  update({lattice,xyz,colors,revision,colorKey,model='half-plane'}) {
    if(this.lattice!==lattice||this.model!==model){
      this.lattice=lattice;this.model=model;const indices=interiorIndices(lattice,{model});
      this.indices=indices;this.points.geometry.dispose();this.points.geometry=new THREE.BufferGeometry();
      this.points.geometry.setAttribute('position',new THREE.BufferAttribute(new Float32Array(indices.length*3),3));
      this.points.geometry.setAttribute('aDisplay',new THREE.BufferAttribute(new Float32Array(indices.length*3),3));
      this.points.geometry.setAttribute('aDelta',new THREE.BufferAttribute(Float32Array.from(indices,i=>lattice.delta[i]),1));
      this.points.geometry.setAttribute('color',new THREE.BufferAttribute(new Uint8Array(indices.length*3),3,true));
      this.rootSort=model==='half-plane'?rootSortWorkspace(indices.length):null;
      if(this.rootSort)this.points.geometry.setIndex(new THREE.BufferAttribute(new Uint32Array(indices.length),1));
      this.revision=null;this.colorKey=null;
    }
    if(this.revision!==revision){
      const positions=this.points.geometry.attributes.position;
      fillRootPositions(xyz,this.indices,positions.array,{model,delta:lattice.delta});
      if(this.rootSort){
        const order=this.points.geometry.index;
        orderRootsByRadius(xyz,this.indices,order.array,this.rootSort);order.needsUpdate=true;
      }
      const displayed=this.points.geometry.attributes.aDisplay;
      for(let j=0;j<this.indices.length;j++){const k=this.indices[j]*3,n=j*3;displayed.array[n]=xyz[k];displayed.array[n+1]=xyz[k+1];displayed.array[n+2]=xyz[k+2];}
      displayed.needsUpdate=true;
      positions.needsUpdate=true;this.revision=revision;
    }
    if(this.colorKey!==colorKey){
      const attr=this.points.geometry.attributes.color;
      for(let j=0;j<this.indices.length;j++){const k=this.indices[j]*3,n=j*3;attr.array[n]=colors[k];attr.array[n+1]=colors[k+1];attr.array[n+2]=colors[k+2];}
      attr.needsUpdate=true;this.colorKey=colorKey;
    }
  }
  render({width,height,zoom,pan,padding,sigma,markers,ends,focus,fade,keep,model='half-plane'}) {
    if(width<1||height<1)return;
    if(this.width!==width||this.height!==height){this.renderer.setSize(width,height,false);this.width=width;this.height=height;}
    const {cx,cy,scale}=chartTransform({left:0,top:0,width,height},{model,zoom,pan,padding});
    Object.assign(this.camera,{left:-cx/scale,right:(width-cx)/scale,top:cy/scale,bottom:(cy-height)/scale});this.camera.updateProjectionMatrix();
    // Klein apparent-radius convention: Δ^(1/4)/|Y|^(3/2) gives exactly
    // 1/k for k-times a form, including the negative representative. The
    // minimum footprint/dimming and cap match the 3D renderer conventions.
    const upper=model==='half-plane';this.boundary.visible=!upper;this.axes.visible=upper;
    const u=this.material.uniforms;u.size.value=.03*sigma*scale;u.dpr.value=this.renderer.getPixelRatio();u.halfPlane.value=upper?1:0;u.focus.value.copy(focus);u.fade.value.copy(fade);u.keep.value.copy(keep);
    if(upper){
      const points=[new THREE.Vector3(this.camera.left,0,0),new THREE.Vector3(this.camera.right,0,0)];
      for(const sprite of this.ticks){const x=sprite.userData.x;points.push(new THREE.Vector3(x,0,0),new THREE.Vector3(x,-5/scale,0));sprite.position.set(x,-17/scale,0);sprite.scale.set(48/scale,20/scale,1);}
      this.axis.geometry.dispose();this.axis.geometry=new THREE.BufferGeometry().setFromPoints(points);
    }
    this.markers.forEach((marker,i)=>{
      const item=markers[i],xyz=item?.xyz||item,delta=item?.delta;
      const p=xyz&&(upper?xyz[1]>0:true)?(upper?rootCoordinates(xyz,delta,model):[xyz[0]/xyz[1],xyz[2]/xyz[1]]):null;
      marker.visible=!!p;
      if(p){marker.position.set(p[0],p[1],0);const radius=upper?Math.max(.06*sigma*scale/Math.abs(xyz[1]-xyz[2]),.6)+3:6;marker.scale.setScalar(radius/scale);}
    });
    this.chord.visible=!!ends;
    if(ends){
      const points=upper?halfPlaneGeodesic(ends,{top:Math.max(1,this.camera.top)}):ends.map(p=>[p[0]/p[1],p[2]/p[1]]);
      this.chord.geometry.dispose();this.chord.geometry=new THREE.BufferGeometry().setFromPoints(points.map(p=>new THREE.Vector3(p[0],p[1],0)));
    }
    this.renderer.render(this.scene,this.camera);
  }
}
