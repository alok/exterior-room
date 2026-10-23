#!/usr/bin/env python3
"""Actual Lean source-catalogue receipts, independent predicates, and cache regressions."""
from __future__ import annotations

import hashlib
import json
from math import gcd, isqrt
from pathlib import Path
from time import perf_counter

from test_service import Engine, ROOT

SOURCE_SHA = "f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b"
IDENTITY = [1, 0, 0, 1]
META = ["catalogueSchema", "catalogueSourceSHA256", "cacheKey", "depth", "matrix", "whole", "dust",
        "otherRadius", "padding", "denominator", "coefficientRows", "upperCount", "otherCount", "total",
        "complete", "sourceLimited", "otherScanBound"]


def rows(matrix: list[int]) -> list[list[int]]:
    p,q,r,s = matrix
    return [[s*s,-r*s,r*r],[-2*q*s,p*s+q*r,-2*p*r],[q*q,-p*q,p*p]]


def triples(page: dict) -> list[list[int]]:
    return [page["abc"][i:i+3] for i in range(0,len(page["abc"]),3)]


def verify(page: dict, settings: dict) -> None:
    assert page["ok"], page
    assert page["catalogueSchema"] == "source-catalogue-v1" and page["catalogueSourceSHA256"] == SOURCE_SHA
    depth, matrix = settings["depth"], settings["matrix"]
    whole, dust = settings.get("whole",True), settings.get("dust",False)
    assert all(page[k] == v for k,v in {"depth":depth,"matrix":matrix,"whole":whole,"dust":dust}.items())
    assert page["cacheKey"] == f"source-catalogue-v1:{depth}:{','.join(map(str,matrix))}:{int(whole)}:{int(dust)}"
    determinant = matrix[0]*matrix[3]-matrix[1]*matrix[2]
    assert page["denominator"] == determinant > 0
    action = rows(matrix)
    assert page["coefficientRows"] == sum(action,[])
    assert all(abs(x) <= 2_000_000_000_000 for x in page["coefficientRows"])
    assert page["padding"] == [6,5]
    other_radius = (2*depth+2)//5 if whole else 10 if dust else 0
    assert page["otherRadius"] == other_radius
    limits = page["sourceLimited"]
    assert page["complete"] == (not any(limits.values()))
    assert page["upperCount"] <= 600_000
    assert page["total"] == page["upperCount"]+page["otherCount"] <= 2_000_000
    assert limits["otherScanBound"] == (other_radius > 0 and page["otherScanBound"] > 64)
    if limits["otherScanBound"] or other_radius == 0:
        assert page["otherCount"] == 0
    if limits["upperCap"]:
        assert page["upperCount"] == 600_000
    points = triples(page)
    assert len(points) == page["count"]
    assert page["onPlane"] is None and page["necklace"] is None
    for i,point in enumerate(points):
        a,b,c = point
        assert point != [0,0,0] and max(map(abs,point)) <= 1024
        delta = b*b-4*a*c
        assert abs(delta) <= 5_242_880 and page["delta"][i] == delta
        assert page["xyz"][3*i:3*i+3] == [-b,a+c,c-a]
        kind = 0 if delta == 0 else 1 if delta > 0 else 2 if a > 0 else 3
        assert page["kind"][i] == kind
        divisor = gcd(a,b,c)
        assert page["divisor"][i] == divisor
        assert page["primitive"][i] == (divisor == 1)
        moved = [sum(n*v for n,v in zip(row,point)) for row in action]
        if page["offset"]+i < page["upperCount"]:
            assert kind == 2 and 5*(moved[0]+moved[2]) <= 6*depth*determinant
        else:
            assert kind != 2 and 25*(2*moved[0]**2+moved[1]**2+2*moved[2]**2) <= 36*other_radius**2*determinant**2


def independent_upper(settings: dict) -> list[list[int]]:
    """Independent a,c scan and Δ interval, then source-order sort."""
    p,q,r,s = settings["matrix"]
    determinant = p*s-q*r
    A,B,C = s*s+q*q,-r*s-p*q,r*r+p*p
    depth = settings["depth"]
    a_max, c_max = (6*depth*C-1)//(5*determinant),(6*depth*A-1)//(5*determinant)
    result = []
    for a in range(1,a_max+1):
        for c in range(1,c_max+1):
            extent = isqrt(4*a*c-1)
            for b in range(-extent,extent+1):
                if 5*(A*a+B*b+C*c) <= 6*depth*determinant:
                    result.append([a,b,c])
    return sorted(result)


def main() -> None:
    engine = Engine()
    native_cases = []
    timings = []

    def call(operation: str, **settings: object) -> dict:
        reply, elapsed = engine.call(operation, **settings)
        timings.append(elapsed)
        return reply

    def full(settings: dict, limit: int = 16384) -> tuple[dict,list[list[int]]]:
        offset, points, first = 0, [], None
        while offset is not None:
            page = call("catalogue",**settings,offset=offset,limit=limit)
            verify(page,settings)
            if first is None:
                first = page
            assert all(page[k] == first[k] for k in META)
            points.extend(triples(page))
            offset = page["nextOffset"]
            assert offset is None or offset == len(points)
        assert len(points) == first["total"]
        assert points[:first["upperCount"]] == sorted(points[:first["upperCount"]])
        assert points[first["upperCount"]:] == sorted(points[first["upperCount"]:])
        assert len(set(map(tuple,points))) == len(points)
        return first,points

    def export(name: str, operation: str, **settings: object) -> dict:
        reply = call(operation,**settings)
        native_cases.append({"name":name,"request":{"id":reply["id"],"op":operation,**settings},"response":reply})
        return reply

    fixture = json.loads((ROOT/"lean/Polynomial/fixtures/source-recrop-audit.json").read_text())
    for case in fixture["cases"]:
        settings = {"depth":6,"matrix":case["matrix"]}
        header,points = full(settings,17)
        assert points == case["upperPoints"]+case["otherPoints"],case["name"]
        assert header["otherScanBound"] == case["sourceExtrasScanBound"]
        assert header["upperCount"] == case["upperCatalogCount"]
        member = call("membersCatalogue",**settings,normal=[1,0,-1])
        assert all(member[k] == header[k] for k in META)
        assert member["normal"] == [1,0,-1]
        expected = [i for i,(a,b,c) in enumerate(points) if b*b-4*a*c < 0 and a == c]
        assert member["indices"] == expected and member["count"] == len(expected)

    # Partition identities, multiples, exact boundary, and primitive-base semantics.
    identity, points = full({"depth":6,"matrix":IDENTITY})
    assert [-1,0,-1] in points and [1,0,1] in points and [1,0,5] in points and [2,0,2] in points
    assert points.count([1,0,1]) == 1
    for matrix, expected_upper, expected_other, scan in [([2,0,0,1],160,26,None),([2,11,0,2],159,25,56)]:
        settings = {"depth":6,"matrix":matrix}
        header, actual = full(settings)
        assert actual[:header["upperCount"]] == independent_upper(settings)
        assert (header["upperCount"],header["otherCount"]) == (expected_upper,expected_other)
        if scan is not None:
            assert header["otherScanBound"] == scan
        if matrix == [2,0,0,1]:
            assert not header["primitive"][actual.index([2,0,2])]

    # Source Float epsilon admits this mathematically out-of-domain point.
    settings = {"depth":6,"matrix":[200000,0,1,1000000]}
    header, actual = full(settings)
    assert header["upperCount"] == 92 and [1,0,11] not in actual
    assert actual[:92] == independent_upper(settings)

    # Source Float rotation drops exact boundary points; exact arithmetic retains them.
    header, actual = full({"depth":12,"matrix":[1,5,-5,1]})
    assert header["upperCount"] == 1497 and header["otherCount"] == 425 and [0,6,0] in actual
    pure, _ = full({"depth":6,"matrix":IDENTITY,"whole":False,"dust":False})
    assert pure["otherCount"] == 0 and pure["otherScanBound"] == 0 and pure["complete"]
    dust, _ = full({"depth":6,"matrix":IDENTITY,"whole":False,"dust":True})
    assert dust["otherRadius"] == 10 and dust["otherCount"] > identity["otherCount"]

    # Stable key, safe maximum matrix entries, and an independent canonical cache.
    scaled, scaled_points = full({"depth":6,"matrix":[1000000,0,0,1000000]})
    assert scaled_points == points and scaled["cacheKey"] != identity["cacheKey"]
    cloud = call("cloud",radius=6,limit=1)
    assert cloud["total"] == 480
    before = call("catalogue",depth=6,matrix=IDENTITY,offset=17,limit=17)
    bad_requests = [
        {"depth":6,"matrix":[1,12,0,1]}, # Conservative envelope, not an actual overflow claim.
        {"depth":6,"matrix":[1,13,0,1]},
        {"depth":6,"matrix":[1,0,1000000,1]},
        {"depth":3,"matrix":IDENTITY}, {"depth":97,"matrix":IDENTITY},
        {"depth":6,"matrix":[1,0,0,0]}, {"depth":6,"matrix":[1000001,0,0,1]},
        {"depth":6,"matrix":IDENTITY,"whole":1},
        {"depth":6,"matrix":IDENTITY,"offset":-1}, {"depth":6,"matrix":IDENTITY,"limit":16385},
    ]
    for request in bad_requests:
        rejected = call("catalogue",**request)
        assert not rejected["ok"] and rejected.get("error")
        after = call("catalogue",depth=6,matrix=IDENTITY,offset=17,limit=17)
        assert {k:v for k,v in after.items() if k != "id"} == {k:v for k,v in before.items() if k != "id"}
    invalid_members = call("membersCatalogue",depth=6,matrix=IDENTITY,normal=[0,0,0])
    assert not invalid_members["ok"]
    assert call("cloud",radius=6,offset=1,limit=1)["total"] == 480

    # Source 600k stop is returned with explicit incompleteness, not a false complete claim.
    dense = call("catalogue",depth=96,matrix=IDENTITY,whole=False,limit=1)
    verify(dense,{"depth":96,"matrix":IDENTITY,"whole":False})
    assert dense["upperCount"] == 600000 and dense["sourceLimited"]["upperCap"] and not dense["complete"]
    last = call("catalogue",depth=96,matrix=IDENTITY,whole=False,offset=599999,limit=1)
    verify(last,{"depth":96,"matrix":IDENTITY,"whole":False})
    assert last["nextOffset"] is None
    assert triples(last) == [[61,-14,22]]
    # First omitted [61,-14,23] still satisfies the exact padded predicate.
    assert 61+23 <= 6*96/5 and (-14)**2 < 4*61*23
    large = call("catalogue",depth=96,matrix=IDENTITY,whole=False,offset=300000,limit=16384)
    verify(large,{"depth":96,"matrix":IDENTITY,"whole":False})

    # Actual service fixtures consumed by native and browser decoders.
    export("identity", "catalogue",depth=6,matrix=IDENTITY)
    export("t4", "catalogue",depth=6,matrix=[1,4,0,1])
    export("s", "catalogue",depth=6,matrix=[0,-1,1,0])
    export("rational-d5", "catalogue",depth=6,matrix=[3,1,1,2])
    export("rational-d2-base-primitive", "catalogue",depth=6,matrix=[2,0,0,1])
    export("dust", "catalogue",depth=6,matrix=IDENTITY,whole=False,dust=True)
    export("source-other-limit", "catalogue",depth=6,matrix=[1,6,0,1])
    export("source-upper-limit", "catalogue",depth=96,matrix=IDENTITY,whole=False,limit=1)
    capped_whole = export("source-upper-limit-with-other", "catalogue",depth=96,matrix=IDENTITY,whole=True,offset=600000,limit=1)
    assert capped_whole["upperCount"] == 600000 and capped_whole["otherCount"] > 0
    assert capped_whole["sourceLimited"]["upperCap"] and not capped_whole["complete"]
    export("identity-members", "membersCatalogue",depth=6,matrix=IDENTITY,normal=[1,0,-1])
    for name,offset in [("page-first",0),("page-second",17),("page-final",204),("empty",212),("empty-after",213),("beyond-end",2000000)]:
        result = export(name,"catalogue",depth=6,matrix=IDENTITY,offset=offset,limit=17)
        if offset >= 212:
            assert result["count"] == 0 and result["nextOffset"] is None
    export("float-tolerance-boundary", "catalogue",depth=6,matrix=[200000,0,1,1000000])
    export("exact-rotation-boundary", "catalogue",depth=12,matrix=[1,5,-5,1])
    binary = ROOT/"lean/.lake/build/bin/polynomial_service"
    binary_hash = hashlib.sha256(binary.read_bytes()).hexdigest()
    (ROOT/"lean/Polynomial/fixtures/catalogue-native-cases.json").write_text(json.dumps({
        "schema":"actual-lean-catalogue-fixtures-v1","binarySHA256":binary_hash,"cases":native_cases},separators=(",", ":"))+"\n")
    receipt = {"result":"passed","requests":engine.serial,"sourceFixtureCases":len(fixture["cases"]),
               "actualReceiptCases":len(native_cases),"binarySHA256":binary_hash,"maxResponseBytes":engine.max_bytes,
               "slowestRequestMs":round(max(timings),3),"totalServiceMs":round(sum(timings),3),
               "kernelEnumerationCompletenessProof":False,"existingGenericLawsUnchanged":17}
    (ROOT/"lean/Polynomial/evidence/catalogue-tests.json").write_text(json.dumps(receipt,indent=2)+"\n")
    engine.close()
    print(json.dumps(receipt,indent=2))


if __name__ == "__main__":
    main()
