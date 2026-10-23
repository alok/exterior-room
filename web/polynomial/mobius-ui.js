// SPDX-License-Identifier: GPL-3.0-or-later
// Preview/commit coordination. Continuous pointer motion is numerical renderer
// work; only a matching compiled-Lean receipt becomes an accepted action.
import {identity,dragStep} from './mobius.js';
import {quantizeMatrix,matrixFromIntegers,displayPushforward,displayRowsFromReceipt} from './mobius-render.js';

export class MobiusAction {
  constructor(commit,cancel){this.transport=commit;this.cancelTransport=cancel;this.ticket=0;this.revision=0;this.reset();}
  get active(){return this.receipt!==null||this.phase==='preview'||this.phase==='pending';}
  get rows(){return this.phase==='preview'||this.phase==='pending'?displayPushforward(this.g):this.receipt?displayRowsFromReceipt(this.receipt):displayPushforward(identity);}
  reset(){this.cancelTransport();this.ticket++;this.g=[...identity];this.accepted=[...identity];this.matrix=[...identity];this.receipt=null;this.phase='identity';this.anchor=null;this.revision++;}
  cancel(){this.cancelTransport();this.ticket++;this.g=[...this.accepted];this.phase=this.receipt?'accepted':'identity';this.anchor=null;this.revision++;}
  begin(z){if(this.phase==='pending')return false;this.anchor={...z};this.g=[...this.accepted];this.phase='preview';return true;}
  move(z){
    if(!this.anchor||this.phase!=='preview')return false;
    const next=dragStep(this.g,this.anchor,z);
    if(!next.every(Number.isFinite)||Math.max(...next.map(Math.abs))>16)return false;
    this.g=next;this.anchor={...z};this.revision++;return true;
  }
  async commit(point,second=null,g=this.g){
    let matrix;try{matrix=quantizeMatrix(g);}catch(error){this.cancel();throw error;}
    return this._commitMatrix(point,matrix,second,g);
  }
  // Presets already supply exact integers. Preserve M and its actual determinant;
  // only continuous numerical gestures need release quantization.
  async commitMatrix(point,matrix,second=null){
    let preview;try{preview=matrixFromIntegers(matrix);}catch(error){this.cancel();throw error;}
    return this._commitMatrix(point,[...matrix],second,preview);
  }
  async _commitMatrix(point,matrix,second,g){
    const ticket=++this.ticket;
    this.g=[...g];this.phase='pending';this.anchor=null;this.revision++;
    try{
      const receipt=await this.transport([...point],[...matrix],second?[...second]:undefined);
      if(ticket!==this.ticket)return null;
      if(!receipt){this.cancel();return null;}
      this.receipt=receipt;this.matrix=[...receipt.matrix];this.g=matrixFromIntegers(receipt.matrix);this.accepted=[...this.g];this.phase='accepted';this.revision++;return receipt;
    }catch(error){if(ticket!==this.ticket)return null;this.cancel();throw error;}
  }
  async inspectSelection(point,second=null){
    if(!this.receipt)return null;
    const ticket=++this.ticket;
    try{
      const receipt=await this.transport([...point],[...this.matrix],second?[...second]:undefined);
      if(ticket!==this.ticket)return null;
      if(!receipt)throw Error('The selected action was superseded.');
      this.receipt=receipt;this.revision++;return receipt;
    }catch(error){if(ticket!==this.ticket)return null;throw error;}
  }
}
