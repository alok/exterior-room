# Native preview and projected-body diagnosis

This continuation starts from `11c907b`. It targets the two failures recorded in
[the source-morph checkpoint](SOURCE_MORPH_UPDATE.md): no completed native Lean
recrop during an actual held Roots drag, and a visibly sparse native projected
disk. The previous failures remain preserved with their original receipts.

Both targeted regressions now have passing simulator acceptance: projected stars
remain visible through the transparent guides, and the unchanged held-input test
accepts a temporary Lean catalogue before release. This closes these particular
failures, not the remaining free-space input, hover or physical-headset gaps.

## Preview scheduling

Source inspection identified two timing defects. A movement inside the 80 ms
render interval was discarded; a subsequent stationary hold supplied no new
input to retry it. Separately, the preview worker captured a candidate before
its 150 ms request-spacing delay, so a newer unsent candidate could not replace
that request. These are concrete code defects, but the old UI run lacked the
timing evidence needed to establish their contribution to that particular failure.

The correction retains the latest throttled input and processes it at the end
of the interval. Gesture ownership, scene revision and cancellation generations
prevent a deferred input from changing a later gesture or Reset scene. The
catalogue worker chooses the latest candidate after its spacing delay. A bounded,
opt-in trace records input, queue, transport, publication and release timing.

Exact accepted matrices, signed identities and pair state remain unchanged until
release validation. The render preview and temporary catalogue remain separate
from accepted state. The original UI assertion still requires an interim
catalogue before release; release acceptance alone does not satisfy it.

The first instrumented simulator run (`20261023T113815Z`) still failed that
assertion. It received two changed callbacks and one ended callback. The second
movement queued matrix `[16567,9107,16025,14845]`; its main-actor task started
760 ms later, and release cancelled it 718 ms after transport started. The same
catalogue request took 7–17 ms in three serial host measurements, with membership
under 2 ms. These measurements implicate app scheduling, but absence of a
main-actor response trace alone does not prove when the network completed.
Release correctly accepted 4,203 forms and 67 plane members, preserving the unit
form and its pair. This failed run remains part of the evidence.

Preview requests now start an immutable worker directly from the input callback.
The worker performs transport, decoding and response validation away from the
main actor; only the main actor can publish its result. Publication still checks
the scene revision, cancellation generation, active gesture and newest candidate.
Each worker reserves a bounded request-ID range, and rejects malformed short
pages before they can exhaust it. Worker timestamps are recorded at the event,
separately from the time the main actor resumes.

All **147 native model tests pass** in 9.376 seconds. Coverage includes a worker
finishing I/O and validation during 300 ms of deliberate main-actor occupation,
with publication deferred until that actor resumes. This is a scheduling
regression test, not a substitute for actual held input. The combined unsigned
simulator build also passes.

The next actual held-input run (`20261023T115041Z`) still failed. Worker start
was now 1.24 ms after queuing. The first cold catalogue response took 866 ms;
it was correctly withheld because a newer input had arrived. Release cancelled
the newer request before completion. A separate host measurement confirmed
1,516–1,679 ms for uncached equivalent matrices versus 6.78 ms when cached.
The earlier host baseline measured a warm cache; it did not measure cold Lean
computation. Both failed assertions remain intact.

## Exact Lean cold computation

The remaining delay came from the cold catalogue scan. It repeatedly rebuilt
the same coefficient transform and squared each candidate. The implementation
now hoists the constant transform and advances the weighted squared norm by
exact integer first and second differences along each inner scan. Candidate
order, signed identities, upper/other partition, caps and request budgets are
unchanged. This is executable Lean, with no JavaScript fallback or floating-point
substitution.

Sixty complete old/new protocol responses match, including ordered point arrays,
metadata, errors, paging, boundary cases and cache recovery. All 121 existing
catalogue checks pass. Fresh-process measurements for the two actual drag
matrices improve from **869 to 190 ms** and **1,504 to 268 ms**. These are bounded
host wall-time observations, not statistical benchmarks or headset performance.
The [optimization notes](../lean/Polynomial/evidence/catalogue-optimization-plan.md)
and [full comparison receipt](../lean/Polynomial/evidence/catalogue-recurrence-differential.json)
record commands, hashes and every case.

The 17 public laws and their proof files are unchanged. Two isolated polynomial
recurrence identities were also kernel-checked; their exact source and axiom
audit are saved in a [separate receipt](../lean/Polynomial/evidence/catalogue-recurrence-identity-check.json).
They are not imported into the service and do not prove whole-enumerator
equivalence; that claim remains covered by regression comparisons.

## Actual held-input acceptance

With the optimized backend, run `20261023T120502Z` passed the **unchanged** strict
assertion: accepted preview count increased from 0 to 1 during the actual Roots
hold. The newest catalogue published **1,233 ms before gesture end**, after the stale
first result was correctly discarded. Its 4,205 forms and 64 plane members used
matrix `[16491,8977,16312,14943]`. The newest catalogue HTTP response took 258 ms,
membership 2.73 ms, and the complete worker 287 ms. Exact release preserved the
unit form and its pair. The subsequent P50/P100 controls and Origin target-ready
checks passed in the same sequence. Origin target readiness is not evidence of
an actual free-space gesture.

The full sequence passes one test with zero failures in 66.969 seconds. The
26 bridge tests also pass against the current executable; their
[test output](../artifacts/preview-bridge-tests.txt) records the result.

The [actual UI receipt](../native/evidence/preview-recurrence-ui-120502.json)
contains the event timeline; the [silent accepted-hold clip](../artifacts/videos/lean-starscape-native-held-preview-accepted.mp4)
shows this run. The earlier [failed-hold clip](../artifacts/videos/lean-starscape-native-preview-worker-probe.mp4)
and its [frozen receipt](../native/evidence/preview-worker-native-receipt.json)
remain available. The earlier matched morph run below used the same native app
but the pre-optimization Lean binary; its receipt is not relabeled.

## Same-fixture numerical comparison

The controlled fixture is Source depth 16, Identity, selected `(1,0,1)`, paired
`(1,1,1)`, Whole on, Dust off, Screen on, height 9.6 and Overview. It contains
4,406 buffered forms. The pinned original-source evaluator, current browser
functions and native render-plan calculations agree on these body counts:

| Projection | Positive-opacity bodies | Primitive upper | Upper multiples | Other categories |
| --- | ---: | ---: | ---: | ---: |
| 0 | 450 | 51 | 3 | 396 |
| .5 | 2,239 | 1,577 | 266 | 396 |
| 1 | 1,973 | 1,577 | 0 | 396 |

Native's 16-level endpoint material bins reduce the last count to 1,933 positive
material instances, a loss of 40 outside the upper category. It loses no upper
stars and retains 266 zero-alpha upper multiples. That does not explain the
broadly sparse disk on its own; it motivates an invisible-instance/depth control.
At full projection the unit body has a 17.28 mm native radius and source alpha
.95; the median primitive upper radius is 2.328 mm. These are CPU values, not
counts of visible pixels. The [reproducible source
audit](../artifacts/source-morph-oracle/README.md) records the source hashes,
full-catalogue comparison, radius distributions and limits of this oracle.

## Guide occlusion reproduced

Nine serial macOS RealityRenderer captures completed in 8.303 seconds. Fresh,
updated and recreated full-projection cloud images were pixel-identical.
Removing zero-alpha batches changed 36 RGB pixels; disabling cloud depth writes
changed 470. Neither explained the missing disk in this body-only fixture.

A second seven-capture experiment added the exact native cone, screen and plane
guides. It reproduced the missing disk. Changing only the transparent fan
materials to `writesDepth=false` restored the projected stars. The nearly
transparent surfaces had been writing depth and hiding bodies behind them.
Body coordinates, radii, colors, opacity and catalogue were unchanged.

| Controlled offscreen render | Image |
| --- | --- |
| Existing guide depth writes | [Sparse disk](../artifacts/native-projected-body-audit/gpu-guides-local/body-plus-all-guides.png) |
| Only guide fan depth writes disabled | [Restored projected bodies](../artifacts/native-projected-body-audit/gpu-guides-local/body-plus-all-guide-fans-no-depth-write.png) |

The [render audit](../artifacts/native-projected-body-audit/README.md) includes
exact fixture data, probe source, hashes and pixel comparisons. This is a macOS
offscreen diagnosis; simulator acceptance of the production patch is separate.

That production acceptance subsequently passed in simulator run
`20261023T115306Z`: projection 0/.5/1, both animated directions, linked D5 Roots,
actual Roots swipe, shared pairing cancellation and Reset. Inspection of its
same-fixture images confirms the projected primitive pattern is now visible.
The browser screenshots below retain their explicit synthetic-XR setup banner;
they do not constitute physical-headset evidence.

| Source16 Identity, unit/pair, height 9.6 | Browser | Current native simulator |
| --- | --- | --- |
| Projection .5 | [Browser .5](../artifacts/screenshots/morph-final-20261023/03-identity-p50.png) | [Native .5](../native/evidence/screenshots/20261023T115306Z/002-source-morph-01-p50-unit-pair.png) |
| Projection 1 | [Browser 1](../artifacts/screenshots/morph-final-20261023/02-identity-p100.png) | [Native 1](../native/evidence/screenshots/20261023T115306Z/003-source-morph-02-p100-animated-unit-pair.png) |

These show corresponding root patterns, pair markers, cutting plane, cone and
lower cloud. They are not pixel-equal: camera scale, glyph footprint, materials
and control/window layout differ. Native's separate Roots window still occludes
part of the spatial scene when open.

The renderer now shares one unit box for guide lines and skips material setters
when the batch's actual opacity has not changed. A separate seven-capture
experiment found pixel-identical cached-material output at 0%, 50% and 100%,
with exact opacity readback. The shared line mesh changed one of 1,228,800 pixels
in its full-projection comparison. These checks establish the scoped rendering
equivalence; they do not measure a simulator latency or frame-rate improvement.

The existing 17 kernel-checked integer laws are unchanged. Numerical fixture
comparisons, queue tests, RealityKit draws and actual input tests each have
separate evidential limits. None establishes physical-headset acceptance.
