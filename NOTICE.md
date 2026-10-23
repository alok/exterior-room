# Exterior Room — source and attribution

Exterior Room is a separate spatial algebra demonstration by Alok Singh with
OpenAI Codex, October 2026. It is not an official Lean, Meta, Apple, or Grassmann.jl
product. The Lean backend investigation and implementation used GPT-6 Astra at
ultra reasoning effort; app integration used the parent Codex model. No separate
"ultracode" execution mode was available or claimed.

## Lean mathematics and execution

The actual wedge and triple-wedge operations come from Alok's local Grassmann
repository, revision `87e12dcfac41a0703bd0192f5e5a9b5e4c82d610`.
See `docs/lean-provenance.md` and `lean/vendor/PROVENANCE.json` for the exact
dependency closure, hashes, licenses, proof names, and executable boundary.
The vendored code is a pinned snapshot, not a modification of that checkout.

## FareyVision reuse

Two utility modules are copied unchanged from the local FareyVision repository,
revision `8b32d7ae8f67fc47f381407bbcdf6f24e28de771`:

- `Farey/WebXR/input.js` → `web/input.js` (visible-object ray filtering).
- `Farey/WebXR/xr-support.js` → `web/xr-support.js` (XR availability, controller
  ray updates, and desktop-camera restoration).

Their SPDX GPL-3.0-or-later headers are retained. The native RealityKit route
adapts FareyVision's primitive placement and immersion lifecycle pattern;
see `native/README.md`. New scene geometry, exact algebra wiring, interaction
design, and proof presentation are Exterior Room work.

Katherine Stange's Farey constructions and mathematical attribution belong to
the reference Farey app. No Stange mathematics or implementation is copied
into this exterior-algebra exhibit, and no new mathematics here is attributed
to her. Hévéa meshes, gallery assets, and construction formulas are not used.

## Renderer

Three.js 0.180.0 is copied from the reference app's installed dependency,
including its MIT license at `web/vendor/THREE-LICENSE.txt`. OrbitControls is
from the same version. All browser dependencies are bundled; the page loads
no CDN scripts, remote fonts, analytics, or external assets.

Original Exterior Room code is GPL-3.0-or-later, compatible with the reused
GPL modules. Third-party files retain their respective licenses. See LICENSE.
