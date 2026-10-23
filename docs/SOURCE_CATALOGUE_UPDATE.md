**Source catalogue update — 2026-10-23**

The browser now offers a Lean-backed **Source depth** catalogue alongside the
existing **Canonical ball**. Source depth implements the original Starscape's
upper trace catalogue and separate other-point catalogue. It is not a transformed
Euclidean ball. The browser acceptance below covers actual UI interaction and
compiled Lean responses. Native catalogue/rendering acceptance is separately
recorded below; neither route has physical-headset acceptance.

This update follows the earlier [source audit](source-recrop-audit.md), whose
“specification only” status describes that earlier checkpoint. The executable
implementation is now [Catalogue.lean](../lean/Polynomial/Catalogue.lean), exposed
through `catalogue` and `membersCatalogue` in the
[protocol](../lean/Polynomial/PROTOCOL.md). It uses the existing local Mac Lean
bridge. This is not a hosted, standalone browser mathematics service.

The three provenance records remain distinct:

- Canonical signed ball: FareyVision
  `ca809d2975a37a318a425e4b9dd73560b07faf39`.
- Exact coefficient action: FareyVision
  `63ad115422ab1141ca6d06732572385414b7a5cf`.
- Original [Starscape](https://katestange.net/starscape-lattice/) catalogue:
  deployed script SHA-256
  `f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b`,
  recorded with its source URL in the audit and fixtures.

Both modes use the same signed identity `(a,b,c)` for `ax²+bx+c`, with
`Δ=b²−4ac` and display coordinates `(-b,a+c,c−a)`. Their arrays, ordering and
membership indices are independent. Canonical mode keeps its fixed ball
`b²+2a²+2c²≤R²`, in a,c,b order. Source mode has two a,b,c-ordered partitions:
upper first, then other. Consumers must not apply canonical binary-search order
or cached plane indices to a source catalogue. Switching modes preserves the
selected signed triple and pair, including identities hidden by the new crop.
The source viewer's Snap can normalize negative interior selections to positive
ones; this application retains its signed selection contract.

For an integer matrix `M=[p,q;r,s]`, `D=ps−qr>0`, let
`(aNum,bNum,cNum)=J(M)(a,b,c)`. Lean computes integer predicates for the rational
action `J(M)/D`; the interpretation `g=M/√D` introduces no square root in the
service. At source depth `R`, the buffered sets are:

- Upper: `a>0`, `Δ<0`, and `5(aNum+cNum)≤6RD`.
- Other: nonzero, not upper interior, and
  `25(2aNum²+bNum²+2cNum²)≤36r²D²`.

Here `r=round(0.4R)` with Whole enabled, `r=10` with Whole off and Dust enabled,
and `r=0` otherwise. Padding is exactly `6/5`. Upper enumeration derives strict
discriminant bounds using integer square roots and floor division. Other
enumeration uses the source's inverse-map Frobenius cube enclosure. That map is
from coefficient coordinates to `(b′,a′−c′,a′+c′)`, not a display-to-display
Lorentz matrix: confusing those bases changes the scan limit.

Buffer membership is different from visibility. Browser shaders and picking
masks apply the source's cubic fade from `0.86R` to `R` for upper transformed
depth, and from `0.86r` to `r` for the other transformed radial distance. A point
at the cutoff can be in the exact buffer with zero opacity. These distances,
fades, roots, meshes and picks are approximate display calculations. In the
counts below, “depth-visible” means positive crop opacity, not viewport inclusion,
an unobstructed pixel, or a frame-rate measurement.

Source roots display **primitive upper base identities only**, using Lean's
`divisor==1`. The 3D catalogue keeps its signed points and multiples. Primitivity
is not recomputed after the rational action: for example, `M=[2,0,0,1]` maps base
`[2,0,2]` to `[1,0,4]`, but the base remains nonprimitive and is excluded from
source roots. Root filtering never replaces a selected polynomial by its
primitive representative.

The current Projection control adds a radial image overlay. In source mode the
overlay uses depth-visible primitive upper forms; it does not move world stars
along their rays. The original viewer's continuous projection morph and its
nonprimitive fading during that morph are **not implemented** by this toggle.
The separately tested `sourceProjectionOpacity` helper is intentionally unwired;
its tests are not evidence that the source morph runs in the application.

The browser refresh policy compares the hyperbolic distance between `g⁻¹·i` and
the cached catalogue's `g₀⁻¹·i`, using the source threshold **0.16**. A committed
action below the threshold can reuse its buffered identities while geometry and
fades update. A changed mode, depth or Whole/Dust setting loads the corresponding
catalogue; Snap stages the relabeled pair against the identity-action catalogue.
Action, catalogue and plane preparation must succeed before publication, and
stale requests cannot publish a replacement.

There remains a timing difference from the original viewer: during a continuous
drag, this application previews the current buffer and requests a new exact
catalogue after release and Lean acceptance. The original can refresh during
motion. Thus newly entering forms may be absent during a long preview and appear
on accepted release. The threshold decision and drag quantization are renderer
policy, not Lean proofs; the accepted result is exact for the declared integer
matrix, not for the entire continuous pointer path.

The service reports source limits explicitly:

- Upper enumeration stops at 600,000 emissions and sets `upperCap=true`.
  Even an exactly full final emission is conservatively marked incomplete.
- If the other scan half-width exceeds 64, it emits no other points and sets
  `otherScanBound=true`. T⁶ at depth6 exercises this omission.
- `complete` is false if either source limit applies. It does not mean that
  every buffered point is visible.

Local limits instead reject the whole request and retain the prior cache:
depth 4…96, matrix entries ±1,000,000, signed identities ±1024, conservative upper
a/c envelopes ≤1024, at most 2,000,000 upper columns, 4,000,000 combined candidate
columns/cube positions, and 2,000,000 output points. Pages contain at most 16,384
points. For example T¹² at depth6 is conservatively refused because its c-envelope
is 1043 even though its actual 187 upper points would fit within 913. The service
does not silently clip those local domain failures. Canonical and source caches
are separate; failed requests do not replace either accepted cache.

Exact arithmetic deliberately exposes differences from the deployed source's
floating bounds. Both are covered by service regression cases:

- At depth6, `M=[200000,0,1,1000000]` produces 92 exact upper points. The source
  produces 93 because its `+10⁻⁹` tolerance admits `[1,0,11]`, although
  `5·traceNumerator−6RD=55>0`.
- At depth12, `M=[1,5,−5,1]` is a normalized rotation. Exact enumeration retains
  `[0,6,0]` on the other radius6 boundary and gives 425 other points. Source
  floating arithmetic evaluates its squared norm slightly above 36 and omits
  it, returning 396 other points.

Universal byte-for-byte parity with the floating source is therefore not claimed.
The five initial source-run fixtures do agree exactly with the corresponding
compiled Lean outputs, including order.

Recorded browser acceptance is in
[browser-states.json](../artifacts/screenshots/catalogue-20261023/browser-states.json).
It distinguishes the accepted catalogue matrix from the live action matrix and
records completion flags and signed selections.

| Browser state | Buffered upper + other | Depth-visible points | Result |
|---|---:|---:|---|
| Source depth6, Whole, identity | 187 + 25 = 212 | 80 | Complete |
| Source depth6, upper only | 187 + 0 = 187 | 66 | Complete |
| Source depth6, Dust | 187 + 3,124 = 3,311 | 1,866 | Complete |
| Source depth6, D5 action | 187 + 25 = 212 | 80 | Complete; pair retained |
| Actual drag, depth6 | 164 + 32 = 196 | 102 | Complete; accepted release recrop |
| Source depth24, Whole, identity | 11,842 + 3,124 = 14,966 | 8,387 | Complete; 5,637 depth-visible primitive roots |
| Source depth96, Whole, identity | 600,000 + 169,788 = 769,788 | 489,520 | Upper cap reported; 326,765 depth-visible primitive roots |

Depth96 has `otherScanBound=64`, so its other catalogue is present;
`sourceLimited.upperCap=true` is the reason `complete=false`. The uncapped
mathematical upper count is 804,301. Its returned upper prefix ends at
`[61,−14,22]`; `[61,−14,23]` is the first omitted identity.

The D5 browser pair used `[1,0,1]` and `[1,1,1]` with `M=[3,1,1,2]`.
Its exact plane has 19 buffered interior members and 9 depth-visible members.
See [the final D5 pair screenshot](../artifacts/screenshots/catalogue-20261023/08-final-source-D5.png).
The actual drag accepted `M=[12548,1918,2638,8373]`, `D=100004720`, and replaced
the buffer with 196 forms. Subsequent Snap relabeled the pair to
`[1,−2,2]` and `[1,−1,1]`; Identity preserved those absorbed labels.
Selecting `[1,3,4]` and switching catalogues retained the same signed identity:
it is visible in Source depth6 and hidden in the Canonical R6 ball.
See also [depth24](../artifacts/screenshots/catalogue-20261023/05-source-depth24.png)
and [the explicit depth96 limit](../artifacts/screenshots/catalogue-20261023/06-source-depth96-limit.png).

The [build receipt](../lean/Polynomial/evidence/build-result.json) records zero
warnings and the unchanged 17 generic integer laws, with 16 axiom reports using
only standard Lean axioms. The catalogue is executable Lean integer code, but
**no kernel theorem of enumeration completeness was added**. Gcd normalization,
JSON transport, cache policy, Float conversion, visibility, browser interaction
and headset behavior are outside those 17 algebraic proofs.

The [catalogue service receipt](../lean/Polynomial/evidence/catalogue-tests.json)
records 121 requests, five source fixture cases and 18 exported actual-response
cases. Tests include independent upper enumeration, ordering, signed/multiple
identities, base primitivity, both floating-boundary discrepancies, source caps,
conservative refusal and cache recovery. The recorded
[Node run](../artifacts/catalogue-node-tests.txt) passed 138 tests with no failures,
including refresh policy, display/picking masks and decoder regressions.
These are test results, not extensions of the kernel proof boundary.

Native acceptance uses the actual visionOS Simulator app, shared sphere instances
and a 40,000-form budget, with menu choices through depth/radius 24. The final
`100946Z` UI test passed in 108.059 seconds, after 114 native model tests and an
unsigned build. It exercised canonical R24 (28,832 instances in 111 color batches),
source R6 unit/pair, D5, primitive projection, Identity, Whole off, Dust and Reset.
The initial R24 CPU scene update took 498.0 ms; D5 took 117.2 ms. These are update
timings, not FPS or hardware performance. R48/R96 remain unavailable natively.
See the [native receipt](../native/evidence/catalogue-native-receipt.json).

Matched D5 has 212 buffered forms, 80 positive-opacity world points, 19 exact
buffered plane members, 9 visible rings and 63 primitive projected forms on each
route. Browser rendering submits 212 world vertices and discards zero-opacity
ones; native draws 80 sphere instances, so raw draw counts are not interchangeable.
The native [D5 view](../native/evidence/screenshots/20261023T100946Z/003-catalogue-02-source-d5-linked-pair.png)
and [projection view](../native/evidence/screenshots/20261023T100946Z/004-catalogue-02b-primitive-upper-projection.png)
were inspected against the [browser D5 view](../artifacts/screenshots/catalogue-20261023/08-final-source-D5.png)
and [projection view](../artifacts/screenshots/catalogue-20261023/10-source-D5-projection.png).
Both roots charts show the selected unit root at 1+i, its paired root and the
same geodesic endpoints. Native has a separately floating Roots window that
occludes much of the 3D scene in these captures; browser panes are side by side.
Physical sphere sizes, camera scale, lighting/background and layout differ.
This is matched-state inspection, not pixel equality or complete visual parity.

An intermediate native UI capture showed 88 positive-opacity instances where the
browser showed 80. Its exact eight-point cause was not reproduced in a separate
Double replay. The final native implementation uses Float32 display coordinates
for clipping and an explicit cutoff guard; all 56 exact D5 cutoff forms now have
zero opacity and no picking proxies in regression tests. Actual final UI showed 80.
Source radial projection was also corrected to use base-primitive upper identities,
matching the browser’s 63. These are renderer fixes, not changes to Lean identities.

Native targeted spatial taps carry stored signed identities through bounded
collision chunks; their real input acceptance remains unverified after batching.
Spatial pairing, free-space hand/controller drag, native pointer-hover callback,
physical gaze/pinch and headset comfort/compositor behavior remain gaps. The
previous Roots-window tap/swipe tests remain historical evidence; the current
source test uses actual control taps and does not fabricate hover or spatial input.

Further actual browser checks passed: Escape cancelled a held root drag and
restored the accepted D5 action, catalogue key and pair; source controls worked
in a 390×844 app iframe; fixed synthetic controller rays toggled Catalogue,
Whole and Dust, applied Exact move and Snap, then exited XR with both desktop
panes restored. All 32 panel controls are wired; this was focused coverage,
not an exhaustive test of every combination. The [silent paired browser clip](../artifacts/videos/lean-starscape-source-catalogue.mp4)
shows D5, a second real drag, Snap and Identity. This video’s drag accepted
`[15101,5070,3255,7715]` with 193 forms; it is a different pointer sequence from
the 196-form screenshot case above. Both retained the same signed pair before
Snap, which absorbed T in each sequence. The app-only clip contains no DOM
controls or audio; the state receipt supplies the associated accepted values.

Production-tab console inspection returned no errors. The QA tab recorded one
`MutationObserver.observe` Node-type error during initial load; its origin was
not resolved (the app and harness sources contain no MutationObserver). The
subsequent actual recording and controller sequence succeeded. This is retained
as an observed diagnostic rather than silently classified as an app pass.

The [native source-catalogue clip](../artifacts/videos/lean-starscape-native-catalogue.mp4)
is a silent app-only simulator recording of the final UI sequence. Its floating
Roots panel occlusion is present in the footage; no hidden geometry is inferred
to have passed visual inspection. The [browser receipt](../artifacts/source-catalogue-browser-receipt.json)
and [native receipt](../native/evidence/catalogue-native-receipt.json) retain
source hashes and precise acceptance categories.
