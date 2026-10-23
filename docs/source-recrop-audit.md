# Original-source catalogue audit — 2026-10-23

**Specification and fixtures only. No service, client, app or running-server behavior changed.**

The current demo matches canonical Farey's fixed signed Euclidean ball. Original
Starscape recataloguing is a different, two-part catalogue; transforming and
recropping that same ball would not reproduce it. Implementing the source rule
would also change membership at the identity, root multiplicity, and depth
semantics. The proposed transformed-ball implementation was held after this
distinction was verified.

## Evidence

- Canonical checkout read-only HEAD: `2a0ef3216a931bdcf6cdd9ba89a1baf6f4cfa46a`.
  `Farey/WebXR/starscape.js` rebuilds the canonical ball, then `setGroup` moves its
  positions without changing its identities. The comment near line 112 explicitly
  distinguishes this from the original viewer. `Farey/WebXR/lattice.js` defines
  its ball by `b² + 2a² + 2c² ≤ R²`.
- Original [Starscape / Lattice](https://katestange.net/starscape-lattice/) deployed
  [script](https://katestange.net/_astro/index.astro_astro_type_script_index_0_lang.kfTP0QEk.js),
  retrieved read-only on 2026-10-23. SHA-256:
  `f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b`.
  This matches the earlier local inspection copy byte for byte.
- Relevant minified functions: `at` (upper enumeration, character offset 30329),
  `ot` (other points), `lt` (concatenation, offset 31107), inner `ft` (refresh),
  inner `ht` (current transform and fades), `Jt` (roots), `cn` (integral absorption).
  Offsets refer to decoded JavaScript text, not UTF-8 byte offsets.
- [Source-run fixtures](../lean/Polynomial/fixtures/source-recrop-audit.json)
  contain the full ordered point lists returned by the source's pure catalogue
  functions. The deployed application was not driven or modified. Its complete
  script is not copied into this repository.

## Verified source rule

Write `p=(a,b,c)`, `Δ=b²−4ac`, and `p′=J(g)p`, where `g∈SL₂(ℝ)`.

1. Upper catalogue: every integer `a>0, Δ<0` with `a′+c′≤1.2R`.
   Enumeration order is ascending **a, then b, then c**. Multiples are retained.
   The implementation stops after 600,000 emissions, without a completeness
   marker. Floating square roots and small rounding tolerances select its bounds.
2. Other catalogue: nonzero integer triples excluding upper interior points,
   satisfying `b′²+(a′−c′)²+(a′+c′−center)²≤(1.2r)²`.
   These are appended in ascending a,b,c order. The current center is zero.
   `r=round(0.4R)` with Whole enabled (also during its transition); otherwise
   `r=10` with Dust enabled, or zero. Zero radius omits this catalogue.
3. Other-point enumeration uses a cube whose integer half-width is the floor of
   `||inverse(displayAction)||F · (1.2r+|center|)`. If that half-width exceeds 64,
   the source returns **no other points**, rather than an incomplete-prefix flag.

The upper catalogue is the same source of identities for both views, but the
roots pane draws only **primitive upper** points. The 3D lattice retains multiples
and fades nonprimitive points during projection. Null/exterior/lower points are
3D-only. Source display axes `(b,a−c,a+c)` are an orthogonal change of our
`(-b,a+c,c−a)` convention, so the norm predicate is unchanged.

The 1.2 multiplier is a catalogue buffer, not the visible cutoff. Upper depth
opacity is one through `0.86R`, falls by a cubic smoothstep, and is zero at and
beyond `R`. Other points use the analogous transformed radial fade at `r`.
Consequently a point exactly on the cutoff can be catalogued but have zero alpha.
Root visibility also depends on primitive status and the pane's viewport/glyph
tests; fixture visibility counts below concern the depth fade only.

The catalogue is reused while crop settings agree and the hyperbolic distance
between `g⁻¹·i` and the catalogue's saved `g₀⁻¹·i` is below `0.16`. All buffered
positions and fades still update under the current `g`. Initial load, depth
changes, and completed integral absorption force recataloguing. After Snap, the
source moves selected identities and returns to the identity action. It also
normalizes negative interior selections to the positive sign; canonical Farey
and this demo intentionally retain their already-authorized signed identities.

## Concrete differences and fixtures

The fixtures run source `lt(g,6,2,true,0)` for Whole mode at depth 6. Matrices are
normalized as `g=M/√det(M)` before calling the source. No browser/Lean output is
being inferred from the table.

| Matrix M | Upper buffer | Other buffer | Upper with nonzero depth fade | Primitive roots with nonzero depth fade | Other with nonzero radial fade |
|---|---:|---:|---:|---:|---:|
| Identity | 187 | 25 | 66 | 63 | 14 |
| T⁴ `[1,4,0,1]` | 187 | 25 | 66 | 63 | 14 |
| S `[0,-1,1,0]` | 187 | 25 | 66 | 63 | 14 |
| `[3,1,1,2]`, determinant 5 | 187 | 25 | 66 | 63 | 14 |
| T⁶ `[1,6,0,1]` | 187 | **0** | 66 | 63 | **0** |

T⁶ makes the source's other-point cube half-width 66, triggering its 64 limit.
The mathematical transformed other-point ball still has 25 identities: an
integral determinant-one action is a bijection of the integer lattice. Thus
matching the source's *code* and enumerating the complete *mathematical set* are
different contracts at this limit.

At the identity, our canonical full ball has 480 points. For example `(1,3,4)`
has Δ=−7 and depth 5, so it is a visible source upper point, but its canonical
squared ball norm is 43 and it lies outside R6. Conversely `(0,3,0)` is in the
canonical R6 ball and outside the source's padded other radius 2.4. This is why
a separate roots-only catalogue would need an explicit correspondence treatment
instead of silently claiming that every root is a displayed world point.

Verify the recorded sets independently with:

```sh
python3 lean/Polynomial/test_source_recrop_audit.py
```

This uses exact integer predicates and checks order, classifications, packed-list
hashes and depth/primitive counts. It is an offline specification test, **not a
Lean implementation or a fallback used by the application**.

## Exact contract for the remaining Lean implementation

For the existing bounded integer matrix `M=[p,q;r,s]`, let `D=ps−qr>0`,
`A=s²+q²`, `B=−rs−pq`, `C=r²+p²`, so `AC−B²=D²`.
The upper padded predicate is exactly
`a>0`, `b²<4ac`, `5(Aa+Bb+Cc)≤6RD`.
For source order, set `α=5A, β=5B, γ=5C, H=6RD`:

- `a < γH/(αγ−β²)`;
- for each a, `E=4a(γH−a(αγ−β²))`; skip if `E≤0`, otherwise
  `|γb+2aβ|≤isqrt(E−1)` gives the b interval;
- `floor(b²/(4a))+1 ≤ c ≤ floor((H−αa−βb)/γ)`.

The other padded predicate at center zero is
`25·(2aNum²+bNum²+2cNum²)≤36·r²·D²`, where `(aNum,bNum,cNum)=J(M)p`.
These calculations use Lean integers, with no float or JavaScript membership
fallback. Cached/paged results would need separate upper/other ranges, matrix,
depth, padding and completeness metadata; the current cloud's a,c,b binary search
cannot be reused for this ordering unchanged.

An implementation should retain the existing ±1024 identity and ±10⁶ matrix
bounds, reject a request before exceeding its candidate/output budgets, and
explicitly distinguish mathematical completeness from source truncation. Export
numerators remain within the existing safe-integer bound only while identities
stay within ±1024. Extreme actions can require identities outside that range.
No such protocol operation, proof, build, or UI claim was added by this audit.
