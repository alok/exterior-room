# Polynomial space protocol v1

Separate executable: `lean/.lake/build/bin/polynomial_service`. One JSON request and response per line; stdout is flushed after each reply. Common response fields are `ok`, echoed `id`, `schema: "polynomial-space-v1"`, `engine: "Lean 4.35.0-rc3"`, and `sourceCommit: "ca809d2975a37a318a425e4b9dd73560b07faf39"`. Errors also contain `error` and do not replace the current cached cloud.

`cloud`: `{id,op:"cloud",radius,upperOnly?:false,offset?:0,limit?:16384,normal?:[A,B,C]}`. Radius is an integer 4..96; offset is 0..2,000,000; limit is 1..16,384. Cache holds at most one point array keyed by radius/filter. Enumeration is canonical `a,c,b` order. Result fields:

- `radius`, `upperOnly`, `offset`, `count`, `total`, `nextOffset` (integer or null).
- `abc`, `xyz`: flat arrays of `3*count` integers. `xyz=(-b,a+c,c-a)`.
- `delta`: `count` integer discriminants.
- `kind`: integer category codes 0=null, 1=exterior, 2=upper, 3=lower.
- `divisor`: positive gcd of each triple's absolute coordinates.
- `onPlane`, `necklace`: null if no normal was supplied; otherwise boolean arrays of length count. `onPlane` means `-2Ca+Bb-2Ac=0`; `necklace` additionally requires negative discriminant, on either nappe, retaining multiples.

`members`: `{id,op:"members",radius,upperOnly?:false,normal:[A,B,C]}` uses the same cached cloud. Returns `radius`, `upperOnly`, `total` (cloud count), `count` (membership count), and `indices` of exact interior plane members in canonical cached cloud order. This avoids redownloading the cloud when a plane changes.

`catalogue`: `{id,op:"catalogue",depth,matrix:[p,q,r,s],whole?:true,dust?:false,offset?:0,limit?:16384}` implements the separately audited original-source catalogue predicates. Depth is 4..96, matrix entries are integers ±1,000,000 with positive determinant, and paging bounds match `cloud`. The existing canonical `cloud` operation is unchanged. The process keeps one canonical cloud and one source catalogue independently; either cache is replaced only after a complete successful computation. A domain or resource error retains the old cache.

`membersCatalogue`: `{id,op:"membersCatalogue",depth,matrix,whole?:true,dust?:false,normal:[A,B,C]}` addresses the same source catalogue. Normals have the existing ±4,194,304 bound and must be nonzero. It returns strictly increasing catalogue `indices` satisfying both Δ<0 and exact incidence on the original signed coefficients. Both signs and multiples are retained; this is buffer membership, not rendered visibility.

Both operations add these identical catalogue metadata fields:

- `catalogueSchema:"source-catalogue-v1"`, `catalogueSourceSHA256:"f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b"`.
- Exact echoes `depth`, `matrix`, `whole`, `dust`, and `cacheKey` formatted `source-catalogue-v1:DEPTH:p,q,r,s:WHOLE:DUST`, with booleans encoded as 1/0. Matrix entries are not rescaled or reduced for the key.
- Positive `denominator=det(matrix)` and nine row-major `coefficientRows=J(matrix)`, bounded by 2×10¹² as in `transform`.
- `otherRadius`: `floor((2*depth+2)/5)` when Whole, otherwise 10 when Dust, otherwise 0. `padding:[6,5]`.
- `upperCount` ≤600,000, `otherCount`, and `total=upperCount+otherCount` ≤2,000,000.
- `sourceLimited:{upperCap:Bool,otherScanBound:Bool}` and `complete=!(upperCap||otherScanBound)`. These report the original source's early-stop rules; a successful reply can be incomplete.
- `otherScanBound`: exact nonnegative integer inverse-display Frobenius enclosure, computed by integer division and square root. It is zero when no other catalogue is requested and is always below 10¹⁵ under input bounds.

Catalogue pages additionally return `offset`, `count`, `nextOffset`, packed `abc`, `xyz`, `delta`, `kind`, `divisor`, and `primitive` (boolean, exactly `divisor==1`). `onPlane` and `necklace` are null. Identity coordinates are ±1024, base XYZ ±2048, |Δ|≤5,242,880, divisor 1..1024. Coordinates are base identities, not transformed floating positions. The first `upperCount` points are upper interior in ascending **a,b,c** order; the appended other points are independently ascending a,b,c. This differs from canonical cloud a,c,b order, and the two sorted partitions must not be treated as one sorted array. `membersCatalogue` adds echoed `normal`, membership `count`, and `indices` instead of point/paging arrays.

Exact padded predicates, for D=det M and `(aNum,bNum,cNum)=J(M)(a,b,c)`:

- Upper: a>0, Δ<0, `5*(aNum+cNum)≤6*depth*D`.
- Other: nonzero and not upper interior, `25*(2*aNum²+bNum²+2*cNum²)≤36*otherRadius²*D²`.

The upper enumerator stops at 600,000 emissions and conservatively sets `upperCap=true` even if that emission happened to be its last. If the other scan bound exceeds 64, no other points are emitted and `otherScanBound=true`. These reproduce source resource behavior with explicit metadata. Local safety limits instead reject the entire operation: conservative upper a/c identity envelopes ≤1024; every emitted coordinate ≤1024; at most 2,000,000 upper (a,b) columns, 4,000,000 combined candidate columns/other cube positions, and 2,000,000 output points. For example T¹² at depth6 is conservatively refused by its c-envelope1043 even though its actual187 upper points would fit. No silent clipping occurs at the local identity/resource boundaries.

The service uses exact rational 6/5 padding, not the deployed source's floating tolerances. Five audited source catalogues agree exactly, but universal byte parity is not claimed: at depth6, M=[200000,0,1,1000000], the exact upper catalogue has92 points and excludes [1,0,11]; the source's +10⁻⁹ bound tolerance admits it among93 points. Here `5*traceNumerator−6*depth*D=55>0`.

Opacity, primitive-only root presentation, projection fading, the source's refresh-distance threshold, and interaction transactions remain client behavior. `complete` describes the padded mathematical catalogue subject to the reported source limits, not whether a glyph is visible. Catalogue enumeration is executable Lean integer code, regression-tested independently; it does not add a kernel theorem proving enumeration completeness. The existing17 generic algebraic laws remain unchanged.

`inspect`: `{id,op:"inspect",point:[a,b,c],height?:4}` accepts nonzero integer point coordinates in [-1024,1024] independent of the finite cloud crop (radius at most 96). Height is an integer 1..24. Result fields: `point`, exact signed `polynomial` label, `delta`, `kind` string, `xyz`, `divisor`, canonical gcd/sign `primitive`, and `positiveRepresentative` (null unless delta<0). Only root/projection uses the latter; the selected polynomial remains signed and unreduced.

`projection` is null or three normalized exact `[numerator,denominator]` ratios at the requested height. `root` is null or `{real:[numerator,denominator],imaginary:{radicand,denominator}}`, representing `real + i*sqrt(radicand)/denominator` without claiming a floating-point square root is exact.

`plane`: `{id,op:"plane",normal:[A,B,C]}`. `pair`: `{id,op:"pair",first:[a,b,c],second:[a,b,c]}`. Input points are bounded by 1024; plane normals by 4,194,304 per coordinate, including normals supplied to `cloud` and `members`. A normal must be nonzero and exterior; its normalized discriminant must not exceed 1,000,000,000,000 to bound endpoint factorization work. Pair inputs must be interior, with distinct projective directions; a pair outside that endpoint budget is explicitly rejected. Outputs include canonical primitive first-nonzero-positive `normal`, `planeCoefficients:[-2C,B,-2A]`, `cartesianNormal:[-B,-A-C,C-A]`, `equation`, `endpoints`, and `checks`. Pair additionally supplies `firstPrimitive` and `secondPrimitive`.

Each endpoint is `{kind:"rational",numerator,denominator,label}`, `{kind:"surd",p,sign,s,r,q,label}` representing `(p+sign*s*sqrt(r))/q`, or `{kind:"infinity",label:"∞"}`. Surd factors and rational fractions are reduced for canonical labels. Numeric rendering is a consumer responsibility.

`transform`: `{id,op:"transform",matrix:[p,q,r,s],point:[a,b,c]}`. The matrix has four integer entries in [-1,000,000,1,000,000], with positive determinant `D=p*s-q*r`. The signed nonzero point has integer entries in [-1024,1024]. This operation adds the coefficient pushforward convention from canonical FareyVision `63ad115422ab1141ca6d06732572385414b7a5cf` (`WebXR/mobius.js` and its fixtures), independently of the original cloud source pin. Interpret the matrix as `g=M/√D`. The exact coefficient action is `J(M)/D`; no square root or floating point is computed by this service.

The reply adds `actionSchema:"polynomial-mobius-v1"`, `actionSourceCommit`, echoed `matrix` and `point`, positive `denominator:D`, and nine row-major integer `coefficientRows`. They are `[s²,-rs,r², -2qs,ps+qr,-2pr, q²,-pq,p²]`. `imageNumerator` and `xyzNumerator` are three integer numerators sharing denominator D. `delta` is the unchanged base discriminant. `image` is an exact integer triple if each image numerator is divisible by D, otherwise null. `checks` contains `positiveDeterminant:true` and the actual integer check `discriminantPreserved:true`. The base point's sign, multiplicity, label and membership identity remain unchanged. All returned integers are within JavaScript's exact integer range under these bounds.

For example M=[3,1,1,2] has D=5: the exact source fixture's drag from i to 1+i sends coefficients [1,-1,2] to [8,-23,22]/5. Integer determinant-one matrices include the exact T, T⁻¹ and S fixtures. If a client rounds a continuous floating-point drag matrix to bounded integers, the result is exact only for that declared matrix; the rounding and pointer trajectory are outside Lean's proof boundary. A client must preserve this distinction and must not replace a failed commit with locally claimed exact output.

Historical Snap/Identity fixtures at `6fea557bb0d0c786bed5223dc631cb1c06e94f16` remain unchanged in `Polynomial/fixtures/snap-contract.json`; their `serviceInputsWithin96` fields record the former identity limit. The corrected source polar-Snap contract is pinned to `2cd549a45ddb6056cf3596404754d96ad9e7132c` in `fixtures/identity-bounds-contract.json`. Its recorded gesture chooses T⁴ and sends [13,20,34] to [13,-84,162]; with partner [1,0,1], the accepted new pair is [13,-84,162]/[1,-8,17] with normal [10,-59,66]. Absorption replaces both signed identities by their exact γ-images, then resets the action to identity. Identity afterward preserves those new triples. This is client state management, not a new service operation. A non-null `image` does not establish that the action is integral: M=[3,1,1,2] maps [1,0,1] to an integer triple despite its nonintegral normalized action.

The transformation output may exceed the ±1024 identity bound of `inspect`, `pair`, and subsequent `transform` calls. For example T¹⁰ sends [13,20,34] to [13,-240,1134], and T sends [-400,400,-400] to [-400,1200,-1200]. Before committing absorption, clients must validate every resulting selected/paired triple and refresh inspection/pair data, then publish the entire new state atomically. If any image, inspection, or pair request fails, retain the previous selection, pair and accepted action. The service itself is stateless for these operations; its rejection cannot undo a client-side partial update. Absorbed identities outside the current cloud remain exact selections; increasing the identity limit does not enumerate a larger cloud.

The numeric bounds are deliberate: for identity magnitude B=1024 and matrix magnitude K=1,000,000, coefficient rows are at most 2K² and D at most 2K². The a/c numerators are at most 3BK², and the b/display numerators at most 6BK²=6,144,000,000,000,000, below 2⁵³−1. Base |Δ|≤5B²=5,242,880; inspection display coordinates are at most 2B. Primitive pair normals are bounded by 4B² because every raw dual-cross coordinate has a common factor of two; their dual/display coefficients are at most 8B². Endpoint numerators/denominators remain safe integers under these bounds and the unchanged Δ≤10¹² factorization cap. Client certificate comparisons use BigInt where products can exceed the safe-number range. These engineering bounds are tested separately from the generic Lean algebraic identities.

The original pinned Farey browser at `ca809d2` implemented Euclidean viewing rotations. Stange's source viewer does implement SL₂(ℝ) drag; the separately pinned `63ad115` action core now supplies its mathematical convention and fixtures. Pointer mapping, continuous preview, camera rotation, palette interpolation, pixel sizes, cone/plane mesh sampling, ray picking, and appearance remain renderer operations, outside the Lean proof statements.

Build: `python3 lean/Polynomial/build.py`. This uses the installed pinned Lean release, two worker threads, workspace-local cache, and sequential module builds. The existing `wedge_service` protocol and implementation are preserved.
