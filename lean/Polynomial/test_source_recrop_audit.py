#!/usr/bin/env python3
"""Check source-audit fixtures against independent exact integer predicates.

This is an offline specification check, not a Lean service or math fallback.
The fixture records outputs of the pinned deployed source's pure cataloguers.
"""
from __future__ import annotations

import hashlib
import json
from math import gcd, isqrt
from pathlib import Path


def rows(matrix: list[int]) -> list[list[int]]:
    p, q, r, s = matrix
    return [[s*s, -r*s, r*r], [-2*q*s, p*s+q*r, -2*p*r], [q*q, -p*q, p*p]]


def main() -> None:
    receipt = json.loads((Path(__file__).parent / "fixtures/source-recrop-audit.json").read_text())
    checked = 0
    for case in receipt["cases"]:
        matrix = case["matrix"]
        p, q, r, s = matrix
        determinant = p*s-q*r
        action = rows(matrix)
        alpha, beta, gamma = [5*(action[0][j]+action[2][j]) for j in range(3)]
        height = 6*case["radius"]*determinant
        disc = alpha*gamma-beta*beta
        a_max = (gamma*height-1)//disc
        upper = []
        for a in range(1, a_max+1):
            extent = 4*a*(gamma*height-a*disc)
            if extent <= 0:
                continue
            limit = isqrt(extent-1)
            b_min = -((limit+2*a*beta)//gamma)
            b_max = (limit-2*a*beta)//gamma
            for b in range(b_min, b_max+1):
                c_min = b*b//(4*a)+1
                c_max = (height-alpha*a-beta*b)//gamma
                upper.extend([a,b,c] for c in range(c_min, c_max+1))
        assert upper == case["upperPoints"], case["name"]
        assert len(upper) == case["upperCatalogCount"] < 600_000

        inverse = rows([s,-q,-r,p])
        inverse_norm = sum(h[0]**2+2*h[1]**2+h[2]**2 for h in inverse)
        dust = case["dustRadius"]
        bound = isqrt(36*dust*dust*inverse_norm//(50*determinant*determinant))
        assert bound == case["sourceExtrasScanBound"]
        other = []
        if bound <= 64:
            for a in range(-bound,bound+1):
                for b in range(-bound,bound+1):
                    for c in range(-bound,bound+1):
                        if (a == b == c == 0) or (a > 0 and b*b < 4*a*c):
                            continue
                        moved = [sum(n*v for n,v in zip(row,[a,b,c])) for row in action]
                        if 25*(2*moved[0]**2+moved[1]**2+2*moved[2]**2) <= 36*dust*dust*determinant**2:
                            other.append([a,b,c])
        assert other == case["otherPoints"], case["name"]
        assert len(other) == case["otherCatalogCount"]
        points = upper+other
        packed = json.dumps(points,separators=(",", ":"))
        assert hashlib.sha256(packed.encode()).hexdigest() == case["pointListSHA256"]
        visible = [point for point in upper if sum((action[0][j]+action[2][j])*point[j] for j in range(3)) < case["radius"]*determinant]
        assert len(visible) == case["visibleUpper"]
        assert sum(gcd(*point) == 1 for point in visible) == case["visiblePrimitiveRoots"]
        visible_other = 0
        for point in other:
            a, b, c = [sum(n*v for n,v in zip(row,point)) for row in action]
            visible_other += 2*a*a+b*b+2*c*c < dust*dust*determinant*determinant
        assert visible_other == case["visibleOther"]
        if "mathematicalOtherCountWithoutSourceBudget" in case:
            assert determinant == 1 and bound > 64 and not other
            identity_other = receipt["cases"][0]["otherPoints"]
            preimages = [tuple(sum(n*v for n,v in zip(row,point)) for row in inverse) for point in identity_other]
            assert len(set(preimages)) == case["mathematicalOtherCountWithoutSourceBudget"]
            for point, target in zip(preimages, identity_other):
                assert [sum(n*v for n,v in zip(row,point)) for row in action] == target
        checked += len(points)
    print(f"Source crop audit passed: {len(receipt['cases'])} cases, {checked} source catalogue points; independent integer predicates/order/hash checked.")


if __name__ == "__main__":
    main()
