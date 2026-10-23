// SPDX-License-Identifier: GPL-3.0-or-later
// Exact XR hover queries off the UI thread. The worker runs the same nearestToRayPacked as the trigger, over
// its own copy of one lattice generation's display coordinates. Protocol invariants:
// - each lattice generation is copied once and transferred; positions never change within a generation, and
//   the main thread keeps its own array for drawing and for the trigger's synchronous pick;
// - a hand posts nothing while it has a query physically outstanding in the worker, even one made obsolete by
//   reset(); so the worker's queue holds at most one query per hand plus the lattice sent with it;
// - a result is accepted only if it answers that hand's current request for the same generation; reset()
//   forgets accepted and current requests, so late answers after a rebuild, session end or context loss are
//   ignored (they still clear the hand's outstanding slot);
// - any worker error, or a throwing postMessage, marks the queries failed and terminates the worker; callers
//   then use the synchronous path. Handlers are bound to their own worker and ignore it once replaced.
// - onsettled(hand), if set, runs whenever a hand's outstanding query is answered, accepted or not, and
//   onfailed() once when the queries fail, so a caller that renders on demand (desktop hover) can show the
//   answer, ask again or fall back without waiting for more input; neither runs for a replaced worker.
export class HoverQueries {
  constructor(createWorker) {
    this.createWorker = createWorker;
    this.worker = null; this.failed = false;
    this.sentGeneration = null; this.nextRequest = 1;
    this.outstanding = new Map(); this.pending = new Map(); this.results = new Map(); this.onsettled = null; this.onfailed = null;
    this.copyMs = undefined; this.copyBytes = 0; this.lastQueryMs = undefined; this.lastLatencyMs = undefined;
  }
  get available() {
    if (this.failed) return false;
    if (!this.worker) {
      try {
        const worker = this.createWorker();
        this.worker = worker;
        worker.onmessage = event => { if (this.worker === worker) this.receive(event.data); };
        worker.onerror = worker.onmessageerror = () => { if (this.worker === worker) this.fail(); };
      } catch { this.fail(); }
    }
    return !this.failed;
  }
  busy(hand) { return this.outstanding.has(hand); }
  // origin and direction are in lattice display units; ray is the world ray it came from, kept for staleness.
  request(hand, generation, lattice, origin, direction, maxAngle, minDistance, ray) {
    if (!this.available || this.outstanding.has(hand)) return false;
    const request = this.nextRequest++;
    try {
      if (this.sentGeneration !== generation) {
        const t = performance.now(), xyz = lattice.xyz.slice(), bytes = xyz.byteLength;
        this.worker.postMessage({ type: 'lattice', generation, xyz, count: lattice.count }, [xyz.buffer]);
        this.copyMs = performance.now() - t; this.copyBytes = bytes; this.sentGeneration = generation;
      }
      this.worker.postMessage({ type: 'query', hand, request, generation, origin, direction, maxAngle, minDistance });
    } catch { this.fail(); return false; }
    this.outstanding.set(hand, request);
    this.pending.set(hand, { request, generation, ray, sent: performance.now() });
    return true;
  }
  receive(message) {
    if (message?.type !== 'result') return;
    const settled = this.outstanding.get(message.hand) === message.request;
    if (settled) this.outstanding.delete(message.hand);
    this.accept(message);
    if (settled) this.onsettled?.(message.hand);
  }
  accept(message) {
    const pending = this.pending.get(message.hand);
    if (!pending || pending.request !== message.request || pending.generation !== message.generation) return;
    this.pending.delete(message.hand);
    if (message.index === null) return;
    this.lastQueryMs = message.ms; this.lastLatencyMs = performance.now() - pending.sent;
    this.results.set(message.hand, { generation: pending.generation, ray: pending.ray, index: message.index });
  }
  result(hand) { return this.results.get(hand) ?? null; }
  reset() { this.pending.clear(); this.results.clear(); }
  fail() {
    if (this.failed) return;
    this.failed = true;
    const worker = this.worker; this.worker = null;
    try { worker?.terminate(); } catch {}
    this.outstanding.clear(); this.reset();
    this.onfailed?.();
  }
}
