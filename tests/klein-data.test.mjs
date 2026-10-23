import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {interiorIndices,fillRootPositions,pickRoot,orderRootsByRadius,rootSortWorkspace} from '../web/polynomial/klein-data.js';
import {transformPackedPositions} from '../web/polynomial/mobius-render.js';
import {sourcePlaneMask,sourceRootOpacity} from '../web/polynomial/source-projection.js';
import {normalize} from '../web/polynomial/mobius.js';

const l={count:5,kind:new Uint8Array([2,3,2,0,1]),delta:new Int32Array([-4,-4,-16,1,0]),xyz:new Float32Array([0,2,0,0,-2,0,0,4,0,1,0,0,0,0,0])};

test('Source-only picking matches six independently evaluated bn source cases while Canonical retains its rule',()=>{
  const fixture=JSON.parse(fs.readFileSync(new URL('../lean/Polynomial/fixtures/source-roots-marker.json',import.meta.url)));
  assert.equal(fixture.sourceSHA256,'f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b');
  assert.equal(fixture.pickerCases.length,6);
  for(const c of fixture.pickerCases){
    const points=c.candidates,s=c.settings,count=points.length;
    const lattice={count,abc:Int32Array.from(points.flatMap(p=>p.abc)),xyz:Float32Array.from(points.flatMap(p=>{const[a,b,c]=p.abc;return[-b,a+c,c-a];})),kind:new Uint8Array(count).fill(2),divisor:new Uint8Array(count).fill(1),delta:Int32Array.from(points,p=>-p.baseK),catalogue:{kind:'source',depth:s.R,otherRadius:Math.round(.4*s.R)}};
    const xyz=transformPackedPositions(lattice.xyz,normalize(s.matrix)),planeMask=sourcePlaneMask(lattice,s.normal),model=s.model===0?'klein':'half-plane';
    const indices=interiorIndices(lattice,{model}),scale=fixture.viewport.scale;
    // Source model0's chart is translated up by one; our Klein center is zero.
    const cx=fixture.viewport.width/2-c.cursor[0],cy=fixture.viewport.height/2-(s.model===0?scale:0)-c.cursor[1];
    points.forEach((p,i)=>assert.equal(sourceRootOpacity(lattice,xyz,i,{planeMask}),p.alpha,`${c.name} packed alpha`));
    const index=pickRoot(lattice,xyz,indices,scale,cx,cy,10,{model,sigma:s.sigma,planeMask});
    assert.equal(index,c.expectedIndex,c.name);
    assert.deepEqual(index>=0?points[index].abc:null,c.expectedABC,c.name);
    if(c.name==='farther-larger-beats-centred-small'){
      const canonical={...lattice,catalogue:null};
      assert.equal(pickRoot(canonical,xyz,indices,scale,cx,cy,10,{model,sigma:s.sigma}),1,'canonical retains nearest-center/tie rule');
    }
  }
});
test('packed root buffer keeps every interior sign and multiple, excluding other classes',()=>{
  const indices=interiorIndices(l);assert.deepEqual([...indices],[0,1,2]);
  const original=l.xyz.slice(),moved=transformPackedPositions(l.xyz,[1,1,0,1]);
  const positions=fillRootPositions(moved,indices,new Float32Array(indices.length*3));
  assert.deepEqual(l.xyz,original);assert.equal(positions.length,9);
  for(let i=0;i<3;i++){assert.ok(Math.abs(positions[3*i]-2/3)<1e-6);assert.ok(Math.abs(positions[3*i+1]-1/3)<1e-6);assert.equal(positions[3*i+2],0);}
});
test('packed root picking uses transformed centers and prefers visible primitive over coincident multiples',()=>{
  const indices=interiorIndices(l),moved=transformPackedPositions(l.xyz,[1,1,0,1]);
  assert.equal(pickRoot(l,moved,indices,300,-200,100),0);
  assert.equal(pickRoot(l,moved,indices,300,0,0),-1);
  assert.equal(pickRoot(l,l.xyz,new Uint32Array([0,1]),300,0,0),0);
  assert.equal(pickRoot(l,l.xyz,new Uint32Array([1,2,0]),300,0,0),0);
});
test('half-pixel root ties choose apparent size, but a farther center outside the tie cannot win',()=>{
  const source={count:2,kind:new Uint8Array([2,2]),delta:new Int32Array([-16,-4])};
  assert.equal(pickRoot(source,new Float32Array([0,4,0,.002,2,0]),new Uint32Array([0,1]),300,0,0),1);
  assert.equal(pickRoot(source,new Float32Array([0,4,0,.004,2,0]),new Uint32Array([0,1]),300,0,0),0);
});

test('UHP keeps all upper multiples and preserves the accepted signed source buffers',()=>{
  const original=l.xyz.slice(),indices=interiorIndices(l,{model:'half-plane'});
  assert.deepEqual([...indices],[0,2]);
  const moved=transformPackedPositions(l.xyz,[1,1,0,1]);
  const positions=fillRootPositions(moved,indices,new Float32Array(6),{model:'half-plane',delta:l.delta});
  assert.deepEqual([...positions],[1,1,0,1,1,0]);
  assert.deepEqual(l.xyz,original);assert.equal(l.count,5);assert.equal(l.kind[1],3);
  assert.deepEqual([...interiorIndices(l,{model:'klein'})],[0,1,2]);
});

test('UHP picking follows canonical 1/a radius, primitive ties and large-star hit extent',()=>{
  const indices=interiorIndices(l,{model:'half-plane'}),options={model:'half-plane',sigma:1};
  // Unit has radius .03*400/1=12; its double has radius6. Both
  // centers are (0,1), and a 10px-away pointer still hits the unit.
  assert.equal(pickRoot(l,l.xyz,indices,400,-10,400,7,options),0);
  assert.equal(pickRoot(l,l.xyz,new Uint32Array([2]),400,-10,400,7,options),-1);
  assert.equal(pickRoot(l,l.xyz,new Uint32Array([2,0]),400,0,400,7,options),0);
  assert.equal(pickRoot(l,l.xyz,indices,400,-10,400,7,{...options,sigma:.4}),-1);
  const moved=transformPackedPositions(l.xyz,[1,1,0,1]);
  assert.equal(pickRoot(l,moved,indices,400,-400,400,7,options),0);
  assert.equal(pickRoot(l,moved,indices,400,0,400,7,options),-1);
});

test('UHP draw order blends faint coincident multiples before the larger root',()=>{
  // Accepted R96 forms (20,1,20),(40,2,40) have the same root and,
  // at source scale250, radii .375,.1875: both are translucent.
  const xyz=new Float32Array([-1,40,0,-2,80,0]),indices=new Uint32Array([0,1]);
  assert.deepEqual([...orderRootsByRadius(xyz,indices)],[1,0]);
  const opacity=[(.375/.6)**2,(.1875/.6)**2];
  let alpha=0;for(const i of orderRootsByRadius(xyz,indices))alpha=opacity[i]+alpha*(1-opacity[i]);
  assert.ok(Math.abs(alpha-.45013427734375)<1e-12);
  assert.ok(alpha>Math.max(...opacity),'both faint copies must contribute rather than depth-rejecting one');
});

test('stable radix root order matches descending transformed denominator and reuses bounded workspace',()=>{
  const denominators=[2,.125,8,2,1e-6,65536,128,8,1.5,3.5,1e7,.0001];
  const xyz=Float32Array.from(denominators.flatMap(d=>[0,d,0])),indices=Uint32Array.from(denominators.map((_,i)=>i));
  const order=new Uint32Array(indices.length),workspace=rootSortWorkspace(indices.length),original=xyz.slice();
  const expected=Array.from(indices).sort((i,j)=>xyz[3*j+1]-xyz[3*i+1]);
  assert.equal(orderRootsByRadius(xyz,indices,order,workspace),order);assert.deepEqual([...order],expected);
  // Reusing the buffers must reset the prior permutation and retain base order
  // for equal radii after an action changes their relative sizes.
  xyz[1]=64;xyz[10]=64;
  const expectedMoved=Array.from(indices).sort((i,j)=>xyz[3*j+1]-xyz[3*i+1]);
  assert.deepEqual([...orderRootsByRadius(xyz,indices,order,workspace)],expectedMoved);
  assert.ok([...order].indexOf(0)<[...order].indexOf(3));
  assert.equal(indices[0],0);assert.deepEqual(original,new Float32Array(denominators.flatMap(d=>[0,d,0])));
  assert.deepEqual([...orderRootsByRadius(new Float32Array(),new Uint32Array())],[]);
});
