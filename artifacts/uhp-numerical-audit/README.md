# Upper-half-plane numerical comparison

This bounded audit compares the new packed UHP coordinates with the actual
`RootsPane.computeStars` method from canonical FareyVision commit
`2cd549a45ddb6056cf3596404754d96ad9e7132c`. It reads pinned Git blobs; it does
not modify or operate the canonical application. No private notebook or media
is copied.

At R6, matrix `[3,1,1,2]` / √5, and a 600×400 chart, all **32 source-visible
upper stars** agree within **0.000017525 CSS pixels**. The fixture has 480 signed
forms and 55 upper roots; the other upper roots lie outside this chart viewport.
The small difference arises along the Float32 rendering path. This establishes
numerical agreement for this fixture, not a screenshot, shader, gesture, dense
performance or kernel-proof result.

The reference enumeration is adapted into the renderer's packed input shape
only inside the audit. Production classification and exact data still come from
Lean. [result.json](result.json) records source, implementation and script hashes.

Run from the repository root with Node and the read-only canonical checkout:

```sh
node artifacts/uhp-numerical-audit/compare.mjs \
  /Users/alokbeniwal/Documents/Codex/2026-10-21/task-7/FareyVision \
  > artifacts/uhp-numerical-audit/result.json
```

The script checks source hashes, the point counts and a 0.001px error tolerance.
The result is a snapshot of the named implementation hashes; rerun after a
relevant renderer change.

## Bounded dense ordering benchmark

The UHP renderer must draw smaller roots first, including faint translucent
copies. A depth winner incorrectly removes their contribution. The corrected
renderer uses four stable radix passes over the transformed Float32 denominator
to order the GPU indices, with depth testing/writing disabled for the stars.
The accepted coefficient identities and transport are unchanged.

[order-benchmark.json](order-benchmark.json) measures five R96 action states,
retaining all 270,202 upper roots from 1,852,484 signed cloud points. Ordering
took **2.28–7.45ms**; position fill plus ordering took **3.51–10.21ms** on this
arm64 Mac with Node 26.9.0. Index/order storage is **3,243,448 bytes**. Each output
was checked as a complete, stable permutation. These are CPU-stage timings,
excluding whole-cloud transformation, attribute copy, GPU upload/rendering and
input/display latency; they do not establish FPS or visual acceptance.

```sh
node artifacts/uhp-numerical-audit/benchmark-order.mjs \
  /Users/alokbeniwal/Documents/Codex/2026-10-21/task-7/FareyVision \
  > artifacts/uhp-numerical-audit/order-benchmark.json
```
