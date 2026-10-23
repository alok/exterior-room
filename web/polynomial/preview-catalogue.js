// SPDX-License-Identifier: GPL-3.0-or-later
// Numerical preview policy only. Every candidate catalogue and plane membership
// still comes from executable Lean. This module never activates a cloud/action.
import {loadCatalogue,preparePlane,inspectWithRepresentative,cancelCloudLoad,retainCloudCandidate} from './lean-client.js';
import {needsSourceCatalogue} from './catalogue-policy.js';
import {quantizeMatrix,matrixFromIntegers} from './mobius-render.js';

const same=(a,b)=>a.length===b.length&&a.every((x,i)=>x===b[i]);
const samePoint=(a,b)=>a===null?b===null:Array.isArray(b)&&same(a,b);
const pointCopy=p=>Object.freeze([...p]);
async function prepare(point,second,lattice){
  const inspection=await inspectWithRepresentative(point);
  if(second){await inspectWithRepresentative(second);return preparePlane(point,second,lattice);}
  return inspection.kind==='exterior'?preparePlane(point,undefined,lattice):null;
}

/** One outstanding load, one replaceable target, and a separate accepted scene.
 * onReady receives {lattice,plane,matrix,point,second}; draw that lattice with the
 * current numerical action. Do NOT activate it during a held gesture.
 * finish(M) stops new preview work and drains the outstanding request. It returns
 * a prepared candidate only for the exact release matrix/context. The caller
 * still needs its exact action receipt before synchronously activating it.
 * cancel() revokes previews. complete() releases them after an accepted commit.
 */
export class PreviewCatalogue {
  constructor({load=loadCatalogue,prepare:prepareCandidate=prepare,cancelLoad=cancelCloudLoad,
    retain=retainCloudCandidate,onReady=()=>{},onError=()=>{},now=()=>performance.now(),
    schedule=(fn,ms)=>setTimeout(fn,ms),clearSchedule=id=>clearTimeout(id),minIntervalMs=150}={}){
    if(!Number.isFinite(minIntervalMs)||minIntervalMs<0)throw RangeError('Preview interval must be finite and nonnegative.');
    Object.assign(this,{load,prepare:prepareCandidate,cancelLoad,retain,onReady,onError,now,schedule,clearSchedule,minIntervalMs});
    this.session=null;this.inFlight=null;this.timer=null;this.lastStart=-Infinity;this.serial=0;
    this.starts=0;this.publications=0;this.lastError=null;
  }
  begin({lattice,depth=lattice?.catalogue?.depth,whole=lattice?.catalogue?.whole,dust=lattice?.catalogue?.dust,point,second=null}){
    if(this.session)this.cancel();
    if(lattice?.catalogue?.kind!=='source')return false;
    if(!Array.isArray(point)||point.length!==3||(second!==null&&(!Array.isArray(second)||second.length!==3)))throw TypeError('Preview requires the selected signed identities.');
    const context=Object.freeze({depth,whole,dust,point:pointCopy(point),second:second?pointCopy(second):null});
    this.session={id:++this.serial,alive:true,held:true,context,base:lattice,record:null,pending:null,latest:[...lattice.catalogue.matrix]};
    this.lastError=null;return true;
  }
  update(g){
    const session=this.session;if(!session?.alive||!session.held)return false;
    let matrix;
    try{matrix=quantizeMatrix(g);}catch(error){session.pending=null;this._clearTimer();this._error(error,session);return false;}
    session.latest=matrix;
    if(!this._needs(session,matrix)){session.pending=null;this._clearTimer();return false;}
    // Motion at the current requested matrix needs no duplicate trailing load.
    session.pending=this.inFlight?.session===session&&same(this.inFlight.matrix,matrix)?null:matrix;
    this._pump();return true;
  }
  async finish(matrix,context={}){
    matrixFromIntegers(matrix); // Same exact input bounds as the release transport.
    const session=this.session;if(!session?.alive)return null;
    session.held=false;session.pending=null;session.latest=[...matrix];this._clearTimer();
    if(this.inFlight)await this.inFlight.promise;
    if(this.session!==session||!session.alive)return null;
    const expected=session.context;
    for(const key of ['depth','whole','dust'])if(context[key]!==undefined&&context[key]!==expected[key])return null;
    for(const key of ['point','second'])if(context[key]!==undefined&&!samePoint(expected[key],context[key]))return null;
    const record=session.record?.value;
    return record&&same(record.matrix,matrix)?record:null;
  }
  cancel(){this._end(true);}
  complete(){this._end(false);}
  diagnostics(){
    const s=this.session;
    return {phase:s?(s.held?'preview':'release'):'idle',inFlight:!!this.inFlight,queued:!!s?.pending,
      displayedMatrix:s?.record?[...s.record.value.matrix]:null,
      requestedMatrix:this.inFlight?[...this.inFlight.matrix]:null,
      starts:this.starts,publications:this.publications,lastError:this.lastError};
  }
  _end(cancel){
    const s=this.session;if(s){s.alive=false;s.pending=null;s.record?.release();this.session=null;}
    this._clearTimer();if(cancel)this.cancelLoad();
  }
  _clearTimer(){if(this.timer!==null){this.clearSchedule(this.timer);this.timer=null;}}
  _needs(session,matrix){const c=session.context;return needsSourceCatalogue(session.record?.value.lattice.catalogue??session.base.catalogue,c.depth,matrix,c);}
  _error(error,session){
    if(this.session!==session||!session.alive)return;
    const message=error instanceof Error?error.message:String(error);
    if(message!==this.lastError){this.lastError=message;this.onError(error);}
  }
  _pump(){
    const session=this.session;if(this.inFlight||!session?.alive||!session.held||!session.pending)return;
    if(!this._needs(session,session.pending)){session.pending=null;return;}
    const delay=this.minIntervalMs-(this.now()-this.lastStart);
    if(delay>0){if(this.timer===null)this.timer=this.schedule(()=>{this.timer=null;this._pump();},delay);return;}
    this._clearTimer();const matrix=session.pending;session.pending=null;
    const job={session,matrix,promise:null};this.inFlight=job;this.lastStart=this.now();this.starts++;
    job.promise=this._run(job).finally(()=>{if(this.inFlight===job)this.inFlight=null;this._pump();});
  }
  async _run({session,matrix}){
    const current=()=>session.alive&&this.session===session,c=session.context;
    let release=null;
    try{
      const lattice=await this.load(c.depth,matrix,{whole:c.whole,dust:c.dust},{isCurrent:current});
      if(!lattice||!current())return;
      release=this.retain(lattice);
      const plane=await this.prepare(c.point,c.second,lattice);
      if(!current())return;
      if(plane?.error)throw Error(plane.error);
      // A completed old pose must not flash a far-away crop into the current
      // frame. During motion it can cover a nearby pose; release reuse is exact.
      const usable=session.held?!needsSourceCatalogue(lattice.catalogue,c.depth,session.latest,c):same(matrix,session.latest);
      if(!usable)return;
      const value=Object.freeze({lattice,plane,matrix:pointCopy(matrix),point:c.point,second:c.second});
      const previous=session.record;session.record={value,release};release=null;
      previous?.release();this.lastError=null;
      if(session.held){this.publications++;this.onReady(value);}
    }catch(error){this._error(error,session);}
    finally{release?.();}
  }
}
