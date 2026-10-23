# Exterior Room

A separate local spatial exhibit for exact exterior algebra, built from Alok's
Grassmann Lean repository and the pinned FareyVision interaction foundation.

## Vertical slice

Three draggable, color-coded vectors span an oriented parallelepiped. Lean
computes their exterior product, signed volume, swapped product, self product,
and vertices from integer lattice coordinates. The display divides lengths by
4, areas by 16, and volumes by 64. Swap the first two vectors to reverse
orientation; collapse a vector to see zero volume; move inside the geometry.

The web app runs fully locally on port 8787, with orbit navigation, pointer
dragging, keyboard/numeric fallbacks, overview/egocentric placement, and WebXR
controller rays. Exact coefficients are authoritative only after a successful
Lean response. On failure the last result is visibly stale. No JavaScript
determinant fallback may impersonate Lean.

## Trust boundary

- Kernel-checked general statements are named with source and axiom audit.
- The native Lean executable computes each bounded request; native execution
  and JSON/HTTP transport are not themselves a kernel proof of each result.
- The renderer converts exact integers to floating-point mesh coordinates.
  Its camera, lighting, pointer projection, and surfaces are not verified.
- Native visionOS provides the same spatial idea with clearly labeled exported
  Lean fixtures and a live Mac bridge where available. Compilation does not
  establish physical-headset performance or interaction quality.

## Isolation and scope

New repository and identity: Exterior Room / com.alok.ExteriorRoom.
Original FareyVision checkout and port 8778 remain untouched. Borrowed modules
are pinned to 8b32d7ae8f67fc47f381407bbcdf6f24e28de771 and retain GPL notices.
No publication, external messaging, credentials, grants, or palm/corner minimap.

## Acceptance

Build Lean without sorry or custom axiom in the used proof closure; test exact
orientation/degeneracy/invalid inputs and bridge errors; inspect the running
page in main Chrome; save screenshots; compile the native route if available;
record reproducible run commands and honest untested areas.
