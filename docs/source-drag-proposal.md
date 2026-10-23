# Source drag contract and Lean action

Updated 2026-10-23 after the canonical owner supplied the exact action. The original read-only audit at `45e29bf` found only an SL₂(ℝ) behavior assertion. Canonical commit `63ad115422ab1141ca6d06732572385414b7a5cf` now supplies `Farey/WebXR/mobius.js`, its tests, `Farey/BEHAVIOR_NOTEBOOK.md`, and `Farey/parity/fixtures.json.mobius`. The original checkout remains untouched.

## Pinned behavior

The source audit records one matrix g, initially the identity. Dragging after a four-pixel threshold maps the previous/current pointer positions through the chart to upper-half-plane points z₀/z₁. It left-composes the transvection carrying z₀ to z₁ and normalizes the determinant. Shift-drag pans, the wheel zooms, a short click selects, and an invalid chart anchor does not move the action. Origin-view dragging uses a view ray's Klein point. Base signed integer identities, labels and plane membership remain unchanged; the geometry moves.

For g = [[p,q],[r,s]], the coefficient pushforward is Q ↦ Q∘g⁻¹:

```
a′ = s²a − rsb + r²c
b′ = −2qsa + (ps+qr)b − 2prc
c′ = q²a − pqb + p²c
```

The canonical exact fixtures include T, T⁻¹, S, and the transvection from i to 1+i: g = [[3,1],[1,2]]/√5. That drag sends [1,−1,2] to [8,−23,22]/5 and preserves discriminant −7. The source's transformed recropping and optional integer release snap are separate behavior details; this action operation does not implement them.

## Implemented arithmetic boundary

`lean/Polynomial/PROTOCOL.md` defines the additive `transform` operation. The existing cloud pin `ca809d2`, schema, cache and wedge service are preserved. The action has its own source pin and action schema. Input M is a bounded integer 2×2 matrix with determinant D>0, interpreted as g=M/√D. The coefficient action is exactly J(M)/D, so the square root cancels and the executable needs only integer arithmetic. It returns exact rational coefficient rows and the selected point's numerator/display numerator; it preserves the original signed point identity.

The supplied exact drag therefore has an exact representation. Arbitrary continuous floating-point preview matrices require an explicitly declared rounding step before an exact commit. The returned result is exact for the submitted integer M; neither that rounding nor the source's pointer trajectory is kernel-verified. A failed commit must not be replaced by locally claimed exact arithmetic.

The renderer can use the accepted row action to move its existing cloud and plane geometry without transferring all 1,852,484 points on every pointer event. This service does not change crop membership, camera state, selection identity, labels, or incidence membership.

`TransformProofs.lean` checks identity, returned row layout, composition order, determinant multiplication, discriminant scaling, incidence covariance, coefficient scaling, and reversal by the adjugate. Exact division by D yields discriminant/incidence preservation. These are algebraic integer identities; they do not formalize real-valued transvection or square-root normalization, pointer mapping, Float rendering, crop dynamics, or headset behavior.

## Evidence and remaining integration boundary

The pinned fixture subset is `lean/Polynomial/fixtures/mobius-contract.json`, including four source hashes verified against the actual `63ad115` Git blobs. `test_transform.py` tests the actual compiled executable against those fixtures and an independent binary-form evaluation oracle. Its original 313 requests pass, including extreme matrices, composition/inverse/incidence, invalid inputs and cloud-cache preservation. An additional 72 requests now check Snap/Identity arithmetic against `fixtures/snap-contract.json`, generated from pinned `6fea557` Git blobs: the user seed, signed pairs, Identity preserving absorbed labels, and both sides of a paired bounds failure. The combined transformation suite has 385 passing requests. The original 305-request polynomial suite also passes, including every point in all eight crops.

Snap's nearest-integral candidate computation remains a floating-point canonical regression fixture. The existing exact operation validates the chosen γ-images; clients own atomic absorption into selection/pair state. A transformed integer image can exceed the service's ±96 input bounds, so clients must validate both images and refresh their inspection/pair data before changing any accepted state. A non-null integer image alone does not prove the action lies in SL₂(ℤ).

Browser/native gesture integration and observed UI behavior are owned by their corresponding agents and documented separately. This arithmetic receipt makes no claim of physical-headset validation. No source-contract blocker remains for the implemented exact action.
