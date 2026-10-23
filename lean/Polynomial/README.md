# Exact signed polynomial space

This separate Lean service implements the canonical FareyVision coefficient-space math. It preserves the existing `wedge_service` and Exterior Room demonstration.

The pinned reference is FareyVision commit `ca809d2975a37a318a425e4b9dd73560b07faf39`, specifically `Farey/WebXR/starscape-core.js`, `lattice.js`, and `pair-plane.js`. Original source is GPL-3.0-or-later. The Lean port is a new implementation of those integer/rational formulas; it does not attribute its new proofs to the canonical application's author or to Katherine Stange. The original checkout remains untouched. Canonical source hashes and independently evaluated fixtures are recorded in `fixtures/polynomial-contract.json` at the project root.

The additional Möbius action is pinned separately to `63ad115422ab1141ca6d06732572385414b7a5cf`, `Farey/WebXR/mobius.js`. Its exact fixtures and source hashes are frozen in `Polynomial/fixtures/mobius-contract.json`; each hash was checked against the pinned Git blob. `Transform.lean` computes the coefficient pushforward for `g=M/√det(M)` as the exact rational matrix `J(M)/det(M)`, using only integer arithmetic. Base signed identities, labels and plane membership remain unchanged. Continuous pointer motion and rounding a preview matrix into bounded integer entries are explicitly outside this exact arithmetic contract.

`Core.lean` implements signed coefficient triples, discriminants, display coordinates, the exact coefficient ball, gcd/sign normalization, dual-cross pair normals, incidence, rational projections, and reduced rational/surd endpoint descriptions. `Main.lean` validates bounded requests and exposes those computations through the newline JSON contract in `PROTOCOL.md`. A single immutable cloud cache prevents page and membership requests from re-enumerating the lattice. The cloud contains all qualifying points, including both signs and nonprimitive multiples; no dense crop is sampled.

The nine general integer theorems in `Proofs.lean` prove:

- Displayed squared Euclidean norm equals `b²+2a²+2c²`.
- Displayed Lorentz form equals the discriminant `b²−4ac`.
- Scaling coefficients scales the discriminant quadratically, including sign reversal invariance.
- Displayed Cartesian-plane incidence equals coefficient-plane incidence.
- The actual unnormalized dual-cross pair normal contains both input points.
- Multiplying a normal by a nonzero factor preserves zero incidence.

These are kernel-checked identities of the actual Lean integer functions. The audit does not claim a proof of complete cloud enumeration, gcd normalization, square-factor extraction, radical root correctness, JSON handling, browser JavaScript, Float conversion, mesh construction, ray picking, palette/color appearance, or headset behavior. Those computational boundaries are tested separately. In particular, the service checks both incidences again after primitive normalization and refuses a pair if that exact runtime check fails.

`TransformProofs.lean` adds eight generic integer theorems: identity action; agreement between the returned row layout and the coefficient function; multiplication of determinants; composition of actions; discriminant scaling by determinant squared; covariance of plane incidence; compatibility with coefficient scaling; and reversal by the adjugate with its explicit denominator. Dividing each numerator image by its positive determinant therefore preserves the discriminant and incidence. These statements do not formalize the real square-root normalization, the upper-half-plane transvection, or the cursor chart.

Build sequentially using the locally installed Lean 4.35.0-rc3 toolchain:

```sh
python3 lean/Polynomial/build.py
python3 lean/Polynomial/test_service.py
python3 lean/Polynomial/test_transform.py
python3 lean/Polynomial/test_catalogue.py
```

The build passes `--wfail`, uses two Lean threads, has no external Lake dependencies, and writes its artifact cache inside the workspace. Sixteen axiom reports cover the relevant declarations and their dependencies; only standard Lean `propext`, `Classical.choice`, and `Quot.sound` appear.

The compiled executable passed 305 protocol requests: 13 canonical point fixtures, ten pair fixtures, eight normal fixtures, 100 additional integer inspections, 12 malformed/bounds cases, and complete cloud comparison at all eight canonical radii. Every coefficient, display coordinate, discriminant, category and gcd was checked for all 2,120,040 points across those crops, and each complete canonical-order Int16 hash matched. Radius 96 contains 1,852,484 points.

The transformation suite passed 452 requests: its original 313 cover 33 canonical generator images, three exact drag cases, 12 extreme inputs, 100 random bounded positive-determinant matrices, 30 composition/inverse/incidence cases, 13 invalid inputs, and cloud preservation across failed transformations. Extreme and random point inputs now exercise the expanded ±1024 identity bound while the cloud radius stays at most 96. Its independent oracle recovers coefficients by evaluating the binary form at three basis points. This tests the actual compiled JSON service rather than a substitute implementation.

Seventy requests retain the historical Snap/Identity arithmetic cases in `fixtures/snap-contract.json`, generated from canonical commit `6fea557bb0d0c786bed5223dc631cb1c06e94f16`. The fixture is unchanged: its former ±96 rejection cases are now accepted at ±1024. Another 69 requests exercise `fixtures/identity-bounds-contract.json`, including the corrected source polar-Snap counterexample pinned to `2cd549a45ddb6056cf3596404754d96ad9e7132c`: T⁴ sends [13,20,34] to [13,-84,162], including its signed multiple and exact paired plane. T⁹ is accepted; T¹⁰ exceeds the new bound. Four asymmetric pair cases reject oversized primary or secondary images. The suite also checks an expanded pair normal above 1,000,000, retains the existing endpoint factorization limit, and checks safe-integer extrema. Candidate selection is floating-point regression data, not a Lean theorem of nearest-matrix selection. Actual client atomic publication/rollback is tested separately in `tests/lean-client.test.mjs` and `tests/mobius-absorb.test.mjs`.

Regenerate that fixture data read-only from pinned Git blobs with `node lean/Polynomial/generate_snap_fixtures.mjs /path/to/FareyVision`. It evaluates the pinned mathematical module and the small actual absorption function with a state-only callback, without using the canonical working tree or opening its UI.

The latest local radius-96 run used 114 bounded pages. First-page generation and response took about 47 ms; the largest cached-page response took about 72 ms; exact necklace membership took about 13 ms. The entire paginated transfer plus independent Python validation took about 3.9 seconds. Maximum response size was 494,816 bytes. These are one-run native-process/pipe timings on this Mac, not browser GPU timing, frame rate, or physical-headset evidence. Exact results, timings, and executable/source fingerprints are in `evidence/`.

## Source depth catalogue

`Catalogue.lean` independently implements the original Starscape upper trace and
other-point catalogue using exact integer predicates for `J(M)/det(M)`. It
preserves base signed identities, multiples and deterministic a,b,c ordering.
Canonical ball arrays remain separate. `catalogue` and `membersCatalogue` are
documented in [PROTOCOL.md](PROTOCOL.md); original-source provenance, tested
floating-boundary differences, explicit source caps and conservative local
refusals are in the [source catalogue update](../../docs/SOURCE_CATALOGUE_UPDATE.md).
The compiled service passed 121 catalogue requests and exported 18 actual-response
cases for native decoder/render tests. This is executable Lean, with no new
enumeration-completeness theorem; the existing 17 algebraic laws are unchanged.
