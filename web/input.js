// SPDX-License-Identifier: GPL-3.0-or-later
// Three.js raycasting does not exclude an object whose visible flag is false.
export function visibleIntersections(raycaster, objects) {
  return raycaster.intersectObjects(objects.filter(object => object.visible));
}

export class TapSelection {
  active = new Set();
  candidate = null;
  begin(event) {
    this.active.add(event.pointerId);
    this.candidate = this.active.size === 1 && event.button === 0
      ? { id: event.pointerId, x: event.clientX, y: event.clientY } : null;
  }
  move(event) {
    if (this.candidate && Math.hypot(event.clientX - this.candidate.x, event.clientY - this.candidate.y) > 5) this.candidate = null;
  }
  end(event) {
    const candidate = this.candidate, single = this.active.size === 1;
    this.candidate = null;
    this.active.delete(event.pointerId);
    return !!(candidate && candidate.id === event.pointerId && single
      && Math.hypot(event.clientX - candidate.x, event.clientY - candidate.y) <= 5);
  }
  cancel(event) {
    this.active.delete(event.pointerId);
    this.candidate = null;
  }
}

// Point glyphs are only a few pixels wide, so selection measures each center's angle from the ray
// instead of hitting mesh surfaces. Returns the index of the closest center within maxAngle, or -1.
// Equal angles prefer the nearer center; centers closer than minDistance (clipped) are skipped.
export function nearestToRay(origin, direction, centers, maxAngle, minDistance=0) {
  const [ox,oy,oz]=origin, length=Math.hypot(...direction), [dx,dy,dz]=direction.map(v=>v/length);
  let best=-1, bestAngle=maxAngle, bestAlong=Infinity;
  centers.forEach(([x,y,z],i)=>{
    const vx=x-ox, vy=y-oy, vz=z-oz, along=vx*dx+vy*dy+vz*dz;
    if(along<=minDistance)return;
    const angle=Math.atan2(Math.hypot(vy*dz-vz*dy,vz*dx-vx*dz,vx*dy-vy*dx),along);
    if(angle<bestAngle-1e-12||(angle<=bestAngle+1e-12&&along<bestAlong)){best=i;bestAngle=angle;bestAlong=along;}
  });
  return best;
}

// The same rule over packed xyz coordinates, for clouds too large to hold as arrays of triples.
export function nearestToRayPacked(origin, direction, xyz, count, maxAngle, minDistance=0) {
  const [ox,oy,oz]=origin, length=Math.hypot(...direction), dx=direction[0]/length, dy=direction[1]/length, dz=direction[2]/length;
  let best=-1, bestAngle=maxAngle, bestAlong=Infinity;
  for(let i=0;i<count;i++){
    const vx=xyz[3*i]-ox, vy=xyz[3*i+1]-oy, vz=xyz[3*i+2]-oz, along=vx*dx+vy*dy+vz*dz;
    if(along<=minDistance)continue;
    const angle=Math.atan2(Math.hypot(vy*dz-vz*dy,vz*dx-vx*dz,vx*dy-vy*dx),along);
    if(angle<bestAngle-1e-12||(angle<=bestAngle+1e-12&&along<bestAlong)){best=i;bestAngle=angle;bestAlong=along;}
  }
  return best;
}
