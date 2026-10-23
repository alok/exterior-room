# Exterior Room — source and attribution

Exterior Room is a separate spatial algebra demonstration by Alok Singh with
OpenAI Codex, October 2026. It is not an official Lean, Meta, Apple, or Grassmann.jl
product.

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

The native screenshot test harness adapts `Farey/scripts/capture_coordinator.py`
and `Farey/UITests/SimulatorCapture.swift` at the same revision, with task-specific
names and synchronization paths.

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

Original browser/transport code is GPL-3.0-or-later. The Grassmann backend
is AGPL-3.0-or-later; its complete corresponding source is included under lean/.
The combined distribution is AGPL-3.0-or-later. Third-party files retain their
respective licenses. See LICENSE and lean/vendor/LICENSE.
