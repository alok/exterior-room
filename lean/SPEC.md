# Exact exterior-algebra service

The service reads one JSON request per line with an `id` and three integer triples `a`, `b`, `c`. Coordinates must be in [-12,12]. Each integer denotes one quarter of a world unit. It returns the actual Grassmann generated R3 wedge of a and b, the reversed wedge, the self wedge, and the actual grade-2/grade-1 wedge producing signed volume. It also returns the eight parallelepiped vertices.

The imported modules are an unchanged dependency closure from the clean local Grassmann commit `87e12dcfac41a0703bd0192f5e5a9b5e4c82d610`, compiled with its installed Lean 4.35.0-rc3 toolchain. No original checkout is modified. The project has no external Lake dependencies. Integer calculations are exact; rendering, transport, display lengths, and browser interaction are outside the Lean proof boundary.

Wedge coordinates use `[e12,e13,e23]` and scale by 1/16 in world units. Volume scales by 1/64. Vertex order is `[0,a,b,c,a+b,a+c,b+c,a+b+c]`. Invalid requests produce one JSON error line. Every successful request echoes its id and input vectors and carries `ok:true`, `scale:4`, exact output integers, and runtime consistency checks. The kernel has separate compilation-checked generic theorems; runtime checks are not themselves a proof of the UI.

Validation: build only the service and proof audit with a low thread count; inspect Lean axiom reports; compare representative and randomized integer requests against an independently written test oracle; verify malformed and out-of-bounds inputs return errors.
