# Deployed source projection morph audit

This is a numerical and source-code audit of the original Starscape projection control. Its target is the deployed source, independently of the canonical Farey implementation and this application's renderer. The morph moves upper-interior glyphs radially to a disk at `Y = hf·R`; it is not a projection to the canonical overlay's fixed `Y = 4`.

## Provenance and reproducibility

- Source: `https://katestange.net/_astro/index.astro_astro_type_script_index_0_lang.kfTP0QEk.js`, saved at `/tmp/exteriorroom-source-recrop-bundle.js`.
- SHA-256: `f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b` (77,016 bytes).
- Canonical handoff read at `b3bd1fcb2097a6d2c009a56144f2936375c1209c`. This is contextual provenance; the deployed script is the numerical authority for this audit.
- Generator: [source_projection_fixture.mjs](../lean/Polynomial/source_projection_fixture.mjs).
- Results: [source-projection-morph.json](../lean/Polynomial/fixtures/source-projection-morph.json), 48 cases.

Run `node lean/Polynomial/source_projection_fixture.mjs [path-to-pinned-script]`. The generator verifies the source hash, extracts and evaluates the actual catalogue, transform, crop, membership and `an()` rendering routines in isolated Node VM contexts, and captures their calls to inert renderer adapters. It performs no network, DOM, WebGL, app or Lean execution. Extracted function offsets and hashes are recorded in the JSON. Colour helpers, diagnostic labels and identity-ghost displacement are excluded from the fixture claim.

The cases cover projection progress `0, .5, 1` under identity and `M = [3,1,1,2]` (determinant 5). Eight profiles cover Whole, Dust, light/dark, eye progress `0,.5,1`, no plane, paired plane, nonprimitive selection and lower selection. Ten probe forms cover selected, paired, nonprimitive upper, other upper, lower, null and exterior cases. Most profiles use source-supported `R=16`; a separately labelled `R=6` extension demonstrates a compatibility pitfall. Original source defaults are `R=48`, light theme, Screen on, Whole off, Dust off, projection zero, `hf=.6`, star size one. Its depth control accepts `16…80`; `hf` accepts `.15…1`.

These are numerical fixtures and independent harness checks. They do not enlarge the existing 17 kernel-checked algebraic laws, prove a floating renderer correct, or constitute browser/headset acceptance evidence.

## Coordinates and scalar inputs

Let `P∈[0,1]` be projection progress, `e∈[0,1]` eye progress toward Origin, and `W∈[0,1]` Whole progress. Let `R` be source depth, `h=hf·R`, and `σ` star size. For the transformed coefficients `(a′,b′,c′)`, write:

```text
Y = a′ + c′
source XYZ = (b′, Y, a′ − c′)
application display XYZ = (−b′, Y, c′ − a′)
```

Source category codes are `0 upper, 1 null, 2 exterior, 3 lower`. These differ from the application's codes. Primitivity remains that of the base integer form; it is not recomputed from floating transformed coefficients. The base discriminant is `Δ=b²−4ac` and the source stores `k=−Δ`.

The source crop function is:

```text
ut(distance, cutoff) = 1                         when distance ≤ .86 cutoff
                     = 0                         when distance ≥ cutoff
                     = 1 − t²(3−2t)              otherwise
t = (distance − .86 cutoff) / (.14 cutoff)
```

Transformed coefficients are stored as Float64. For upper forms, the trace fade `U=ut(Y,R)` is calculated from that transformed trace and stored as Float32. The norm `ρ=√(b′²+(a′−c′)²+Y²)` and fourth-root factor `q=k^.25` are independently cached as Float32. Other categories use their radial crop fade. The morph uses these unprojected quantities; it does not recrop using the projected coordinates.

When `U≤0`, `an()` writes zero position, radius and opacity for the body and skips it. Selection markers are evaluated independently and can remain visible for such a form.

## Upper-interior position, radius and opacity

Only upper-interior bodies move. Source `Fe` computes:

```text
j = 1 + (h/Y − 1)P
position(P) = j · sourceXYZ
```

Thus the endpoint lies on `Y=h`, and the midpoint lies halfway along the original radial segment. Lower, null and exterior bodies do not move with `P`. Neither base identity nor action matrix is changed by this morph. The separate 2D roots diagram does not morph.

The physical radius combines an ordinary lattice radius and an angular size:

```text
d = .06 σ q / (Y√Y)
f = .15 σ · (primitive ? 1 : .72)
r0 = (1−e)f + e·dY
rP = (1−P)r0 + P·dh
```

For a highlighted member of the active plane or shell, multiply `rP` by `1+.35(1−e)(1−P)`. At Origin (`e=1`), radius and position scale together, so projection preserves the angular appearance of an upper glyph. The screen-space renderer can subsequently apply minimum size, fog and GPU limits.

For ordinary-view opacity, define the focus value `V`:

- `1` with no active plane/shell;
- `2` for an exact plane member or shell match;
- `.26` in dark theme or `.32` in light theme for an off-filter form.

Let `themeBase=.45` dark or `.36` light. The unprojected starting opacity is:

```text
start = V≥1 ? themeBase + (.95−themeBase)e : V
start *= 1 − W·(1 − ut(ρ, round(.4R)))
screenFactor = screen ? 1−e : 0
if screenFactor > .001:
    start *= 1 − .75·screenFactor·clamp((Y−h)/3+.5,0,1)·(1−e)
end = V≥1 ? .95 : V
alpha = U · ((1−P)start + P·end)
if nonprimitive: alpha *= 1−P
```

The source then clamps the maximum to one and packs Float32. Whole therefore adds a radial fade to upper bodies, in addition to their catalogue trace fade. At `P=1`, primitive on-plane or unfocused upper bodies have opacity `.95U`, off-plane ones have `VU`, and nonprimitive bodies vanish. A selected nonprimitive ring does not vanish.

The `?talk=geo` presentation has separate staged controls. The formulas and fixtures here describe the ordinary viewer, not that presentation.

## Lower, null and exterior bodies

These bodies retain the unprojected transformed position. Their radius and opacity do not depend on `P`:

```text
rbase = null ? .09 : .075
rEye = rbase + (.01·abs(Y)+.004−rbase)e
radius = (1−W)rEye + W(.15σ)
themeDust = dark ? .42 : .5
categoryFactor = null ? 1.5 : exterior ? 1 : .8
dustAlpha = dust ? themeDust·categoryFactor·(1−.6e) : 0
wholeAlpha = themeBase·(1−e)
alpha = U·((1−W)dustAlpha + W·wholeAlpha)
```

An exact member of an active plane overrides those values with `radius=.12` and `alpha=.9U`, independently of eye, Whole, Dust and projection. Source outside-category counters are incremented before this override; they are not reliable final world-visibility counts.

## Selected, paired and hovered markers

Source `an()` calls `$t` directly for selection markers, bypassing catalogue membership, crop and base primitivity. Upper-interior markers follow the same radial position morph, including hidden or nonprimitive selections. Lower, null and exterior markers stay at their transformed positions.

Selected and paired rings have opacity one; hover has opacity `.6`. Their physical radius is `.32(1−e)+.02e`, with minimum six screen pixels and ring width `1.6`. They do not inherit the body opacity. The selected 3D label follows the selected ring. Rings themselves are not world-cloud pick targets.

For any interior selected form, the selected ray uses the positive-trace representative and extends to `Y=1.03R`, independently of projection. In particular, a lower selection can retain its negative-side marker while its ray points to the positive side. This is source behavior, not an identity rewrite in the service.

Ordinary auxiliary screen rays are restricted to primitive upper forms with positive crop fade, require `screenFactor>.001`, and are capped at 1,200 in catalogue order. They extend from the origin to `max(1,h/Y)·XYZ`, with endpoints unchanged by `P`. With `strength=clamp(d/.004−1,0,1)`, their endpoint opacity is:

```text
(dark ? .13 : .16) · screenFactor · (.35+.65sin(πP)) · strength · U
```

The origin opacity is `.15` times that value. Ray positions and opacity are packed as Float32. Their brightness peaks halfway through projection; their geometry does not interpolate.

The separate 2D routine `Jt()` draws only base-primitive upper bodies with positive trace fade. Ordinary-view body opacity is `U·(V≥1 ? 1 : V)`: neither Whole's extra radial fade nor projection progress enters it. Its radius uses the root-chart Jacobian and base discriminant, without the 3D plane-member radius boost. Selected/paired root rings call `Xt()` directly, bypassing catalogue/crop/primitivity; opacity is one and screen radius is `max(5, primitive-root apparentRadius+4)`. Hover opacity is `.55`, and an already selected/paired identity is not drawn again as hover. `Xt()` chooses the positive-trace representative for the root position and a primitive representative for ring sizing; it need not rewrite the signed selected identity.

## Disk, plane, cone and camera

Screen is a separate control, defaulting on. Its disk is centered at `(0,h,0)` with radius `h` and is visible when `screenFactor>.001`. Its opacity depends on Screen and eye progress, not on projection progress. The disk base opacity is `(light?.07:.05)·screenFactor`, the rim-shader coefficient is `.03·screenFactor`, and the rim-line opacity is `.6·screenFactor`. Project/Lift does not toggle Screen. Moving the source height slider enables Screen.

The ordinary cutting plane and boundary lines remain unchanged at `P=0,.5,1`. For a transformed coefficient normal `(A′,B′,C′)`, its source Cartesian normal is proportional to `(B′,−(A′+C′),A′−C′)`. The mesh is a disk of radius `1.5R`, clipped to `Y∈[−.3R,R]` and radial distance at most `R`. Opacity outside the cone is multiplied by `.22`. Base and rim-shader coefficients are `.12` and `.04` times `theme.surface` (`1` dark, `1.35` light). Endpoint cone-generator lines run from `Y=−.3R` to `R`, opacity `.8`. There is no projection-driven morph from the cutting plane to a chord. Radially moved on-plane points remain on the same plane.

For the fixture plane `[1,0,−1]`, identity gives unit Cartesian normal `[0,0,1]` and real endpoints `−1,+1`. Under D5 the transformed coefficient normal is `[.6,.4,−1.6]`, giving unit Cartesian normal approximately `[.1632993162,.4082482905,.8981462390]` and endpoints `−2,4/3`. The JSON records the actual source outputs and confirms they are unchanged by `P`.

The cone extends over upper heights `0…R` and lower heights `−.3R…0`. Its geometry does not change with projection. Let `t=(1−e)·coneShow`: cone-base opacity is `.025·theme.surface·t`, cone-rim-shader coefficient is `.1·theme.surface·t`, axes opacity `.45(1−e)`, rulings opacity `(light?.16:.1)·t`, and top-rim opacity `.35·coneShow+.35e`. These are eye/cone effects. The ordinary plane is not eye-faded by the projection routine.

Project/Lift itself leaves the camera pose and field of view unchanged. The separate eye transition takes 3,200 ms; at Origin the camera is at the origin looking along `+Y` with up `−Z`. The identity-ghost lattice is also not morphed by `P`; its separate action/eye/style treatment is excluded from these fixtures.

## Timing and recataloguing

Project/Lift duration is `3500·abs(target−current)` milliseconds. Normalized elapsed time `u` is clamped and eased by:

```text
ease(u) = 4u³                         if u < .5
        = 1 − (−2u+2)³/2             otherwise
```

Elapsed fractions `0,.25,.5,.75,1` yield progress `0,.0625,.5,.9375,1`. Direct slider changes and reduced-motion changes are immediate. Projection progress only marks the 3D view dirty; it neither refreshes the catalogue nor redraws the roots diagram.

By contrast, a group drag updates the action and requests catalogue work on each sample. A rendered frame can refresh the catalogue when settings change or the inverse-basepoint displacement reaches `.16`; transformed positions and fades are updated between refreshes. The deployed source therefore recatalogues during motion, not only after release. Projection itself does not alter the source catalogue domain. See [source-recrop-audit.md](source-recrop-audit.md) for the independent catalogue arithmetic and bounds.

The source routes pointer cancellation through its pointer-release handler, which may Snap. That behavior is not a recommendation to discard this application's accepted-state rollback on cancellation.

## Packing, drawing and picking boundary

The JSON records both raw JavaScript-double calls and their Float32-packed position/radius/alpha values. Actual projected screen opacity also depends on camera depth, fog, point-size thresholds and GPU limits, none of which are simulated by the inert fixture adapter.

The source point shader computes pixel radius from physical radius, projection-matrix focal scale, half viewport height, depth and device-pixel ratio. It applies fog and quadratically attenuates undersized points before enforcing the minimum size. Ordinary stars use a `.6`-pixel minimum and marks use six pixels. The maximum depends on the GPU's point-size range. Depth test and depth write are disabled.

The world picker uses packed pre-fog alpha at least `.06`, projected depth greater than `.01`, and a hit threshold of `max(7, projectedRadius+3)` pixels. Thus positive crop fade, drawable body opacity, world-pick eligibility, viewport visibility and final pixel visibility are distinct quantities. Previously recorded source depth-mask counts must not be relabelled as full source-opacity or visible-pixel counts.

The `R=6` extension is especially illustrative: in Whole mode, `round(.4R)=2`, so the unit form's norm of two is at the additional radial cutoff. At projection zero its body can have zero alpha even though its trace fade is positive; its selected ring remains visible. This is one reason source-supported depth 16 is the appropriate initial source-morph comparison.

## Checks completed and remaining acceptance

The generator completed with 48 cases and checked midpoint/end positions, nonprimitive fade-out, Origin radius-to-height invariance, unchanged other-category bodies, unchanged screen/plane/ray arguments and retained selected-marker opacity. Those assertions check the extraction harness and the captured numerical behavior.

Browser and native implementations consume these fixtures separately. Their current integration, UI acceptance, camera-specific screen appearance, XR behavior and physical-headset behavior are not asserted by this audit. No app/native file, canonical checkout, Lean theorem, external service or published commit was changed as part of producing these fixtures and this document.
