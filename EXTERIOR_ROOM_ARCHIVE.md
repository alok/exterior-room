# Exterior Room — preserved earlier experiment

This separate vector/wedge experiment is preserved at
[http://127.0.0.1:8787/exterior/](http://127.0.0.1:8787/exterior/).
The primary application is now [Lean Starscape](README.md). Exterior-algebra
operations do not contribute to Starscape parity.

Use the same `./scripts/run.sh` bridge. Drag colored vector tips or use coordinate
controls; Swap reverses orientation, and Flatten makes the signed volume zero.
Overview and Inside change the camera. Lengths use integer coordinates divided
by 4; area coefficients by 16; volume by 64.

The highlighted face is the bivector `a ∧ b` in basis `[e₁₂,e₁₃,e₂₃]`, not its
Euclidean magnitude. The solid depicts `a ∧ b ∧ c`; its coefficient is signed
volume. Every accepted edit uses the pinned Grassmann Lean kernels.

The native `ExteriorRoom` target is retained. Its earlier screenshots/tests are
historical evidence for this experiment only. Follow [native instructions](native/README.md)
and [exterior validation](docs/VALIDATION.md) for those routes.

Grassmann is pinned at `87e12dcfac41a0703bd0192f5e5a9b5e4c82d610`.
The [vendor manifest](lean/vendor/PROVENANCE.json) records 110 copied modules.
[Lean provenance](docs/lean-provenance.md), [wrapper proofs](lean/Exact/Proofs.lean)
and [axiom audit](lean/evidence/axiom-audit.txt) distinguish generic kernel
identities, executable computations and renderer-only behavior. These are not
new mathematical results attributed to Katherine Stange.
