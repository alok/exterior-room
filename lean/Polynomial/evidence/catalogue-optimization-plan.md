# Cold catalogue implementation optimization

Scope: precompute the nine exact integer coefficients of `Mobius.rows`, then
hoist their `a` and `(a,b)` contributions outside the inner `c` loop in
`Catalogue.build`. Preserve every candidate, loop order, source cap, resource
budget, exclusion predicate, output field, and error. Do not modify any of the
17 existing theorem statements or proofs; differential execution is regression
evidence, not a new kernel proof of enumeration equivalence.

Before rebuilding, preserve the existing executable at
`/tmp/exteriorroom-polynomial-before-catalogue-hoist` and the original source at
`/tmp/exteriorroom-Catalogue-before-hoist.lean`. Compare complete protocol results
against that executable, including actual Source16 held-input matrices, warm
cache requests, membership, paging, source fixture configurations, and failures.
Measure cold requests separately from repeated cache hits. Run the existing
catalogue oracle tests after the differential comparison.

No build, benchmark, or server restart is permitted while the coordinated native
morph UI run is active. Build sequentially with at most two Lean threads after
the parent confirms the UI run has finished. If this narrow hoist is insufficient,
report the measured result before proposing a further implementation change.

The narrow hoist passed 57 full-response differential comparisons and 121 source
catalogue regressions, but the actual newest Source16 matrix still required about
1008 ms cold (baseline about 1506–1603 ms). The parent then authorized a bounded
second change: evaluate the same norm predicate by exact integer finite
differences, keeping the original cube and every filter/budget/cap unchanged.

For the weighted norm `Q(x)=2x₀²+x₁²+2x₂²`, fixed slope `u`, and
`B(x,u)=2x₀u₀+x₁u₁+2x₂u₂`, initialize at `c=-bound` with
`F=25Q(x)`, `d=25(2B(x,u)+Q(u))`, and `dd=50Q(u)`. Test `F` before advancing,
then assign `F←F+d` and `d←d+dd` after every candidate, even when excluded.
All three values are arbitrary-precision `Int`; no floating arithmetic or new
scan bounds are introduced. The recurrence and complete executable behavior are
checked independently and by differential execution; this is not a new kernel
proof of the whole enumerator.

The intermediate hoist executable is preserved at
`/tmp/exteriorroom-polynomial-after-catalogue-hoist` (SHA-256
`3eedd104a90e432cb631cc11725966fc5304bafdfb3b6f71e68b609f9741baa6`), with all six
sources at `/tmp/exteriorroom-polynomial-hoist-sources.G9zCgn`.

Final validation: the sequential build passed with zero warnings, and both public
proof-source files remain byte-identical to the original. The recurrence passed
60 complete protocol comparisons across nine scenarios against the original
binary, including both actual Source16 actions, signed/multiple identities,
depth12 exact norm-boundary witnesses, D5, small pages, source omissions, upper
caps, and errors/cache recovery. The 121 existing source catalogue checks also
passed. See `catalogue-recurrence-differential.json` and `catalogue-tests.json`.

The two actual Source16 cold requests measured 869.147 → 190.115 ms and
1504.133 → 268.040 ms in separate fresh processes. These are bounded local
wall-clock comparisons, not statistical or headset performance claims. The
candidate binary SHA-256 is
`d6f909065f501b827c8d5646aebe4b2dd723d06a6e9d5ba3ad2f183f6ede44c4`.

Two independent source reviewers checked the weighted recurrence and unconditional
loop advancement. A separate scratch Lean check verifies only its first- and
second-difference polynomial identities over all `Int`, using standard axioms;
the exact scratch source and result are in `catalogue-recurrence-identity-check.json`.
Neither scratch declaration is imported into the service. The public 17-law
contract is unchanged; whole-enumerator equivalence remains regression-tested.
