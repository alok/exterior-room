#!/usr/bin/env python3
"""Bounded exact pairing regressions and Source16/24 cold receipts; no UI or build.

Use one existing Lean executable process/thread at a time. Compare the actual
spatial sphere against separately evaluated canonical modules and frozen machine
planes. Preserve signed identities and distinguish source omission limits from
native capacity. Timing covers a fresh process's request, not headset rendering.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
from typing import Any

from benchmark_catalogue_cold import Engine, canonical, sha256
from test_catalogue import META, triples, verify

ROOT = Path(__file__).resolve().parents[2]
LOCAL = Path(__file__).resolve().parent
BINARY = ROOT / "lean/.lake/build/bin/polynomial_service"
NORMAL = [1, -2, -1]
MATRICES = [
    ("identity", [1, 0, 0, 1]),
    ("held-first-115041", [15192, 7950, 14719, 14285]),
    ("held-latest-115041", [16478, 8954, 16361, 14960]),
    ("held-published-120502", [16491, 8977, 16312, 14943]),
]


class Calls:
    def __init__(self, engine: Engine) -> None:
        self.engine = engine
        self.serial = 0
        self.exports: list[dict[str, Any]] = []

    def call(self, operation: str, *, name: str | None = None,
             **fields: Any) -> tuple[dict[str, Any], float]:
        self.serial += 1
        request = {"id": self.serial, "op": operation, **fields}
        result, elapsed, _ = self.engine.call(request)
        assert result["schema"] == "polynomial-space-v1"
        assert result["sourceCommit"] == "ca809d2975a37a318a425e4b9dd73560b07faf39"
        if name is not None:
            self.exports.append({"name": name, "request": request, "response": result})
        return result, elapsed


def pairing(fixture: dict[str, Any]) -> dict[str, Any]:
    engine = Engine(BINARY, 10)
    calls = Calls(engine)
    try:
        for name, point in [("default-inspect", [1, -1, 2]), ("sphere-inspect", [3, 0, 3]),
                            ("unit-inspect", [1, 0, 1])]:
            result, _ = calls.call("inspect", name=name, point=point)
            assert result["ok"] and result["point"] == point
            if name == "sphere-inspect":
                assert result["divisor"] == 3 and result["primitive"] == [1, 0, 1]
                assert result["delta"] == -36 and result["polynomial"] == "3x²+3"
        cloud, _ = calls.call("cloud", name="spatial-cloud", radius=6)
        assert cloud["ok"] and cloud["total"] == cloud["count"] == 480
        cloud_points = triples(cloud)
        assert [3, 0, 3] in cloud_points and cloud_points.index([3, 0, 3]) != cloud_points.index([1, 0, 1])
        rows: list[dict[str, Any]] = []
        for case in fixture["cases"]:
            export_name = {"actual-spatial-sphere": "spatial-pair", "same-direction": "same-direction-pair"}.get(case["name"])
            reply, elapsed = calls.call("pair", name=export_name, first=case["first"], second=case["second"])
            expected = case["expected"]
            if "error" in expected:
                assert not reply["ok"] and reply["error"] == expected["error"]
                rows.append({"name": case["name"], "rejected": True, "error": reply["error"]})
                continue
            assert reply["ok"]
            for key in ["normal", "equation", "firstPrimitive", "secondPrimitive"]:
                assert reply[key] == expected[key], (case["name"], key)
            assert reply["normal"] == NORMAL and reply["planeCoefficients"] == [2, -2, -2]
            assert [v["label"] for v in reply["endpoints"]] == [v["label"] for v in expected["endpoints"]]
            assert reply["endpoints"] == [
                {"kind": "surd", "p": 1, "sign": sign, "s": 1, "r": 2, "q": 1,
                 "label": "1 − √2" if sign == -1 else "1 + √2"} for sign in [-1, 1]]
            assert all(reply["checks"].values())
            membership, _ = calls.call("members", name="spatial-members" if export_name else None,
                                       radius=6, upperOnly=False, normal=NORMAL)
            assert membership["indices"] == case["indices"] and membership["count"] == 18
            assert [cloud_points[i] for i in membership["indices"]] == case["members"]
            independent = {(s*a, s*(a-c), s*c) for s in [-1, 1] for a in range(1, 4) for c in range(1, 4)}
            assert set(map(tuple, case["members"])) == independent
            for expected_inspect in case["inspections"]:
                inspected, _ = calls.call("inspect", point=expected_inspect["point"])
                assert all(inspected[k] == v for k, v in expected_inspect.items() if k != "polynomial")
                # Current canonical typography spaces operators; this Lean source pin is compact.
                assert inspected["polynomial"] == expected_inspect["polynomial"].replace(" ", "")
            rows.append({"name": case["name"], "normal": reply["normal"], "members": 18,
                         "milliseconds": round(elapsed, 3)})
        for case in fixture["machinePlanes"]:
            fields = {"first": case["first"], "second": case["second"]} if "first" in case else {"normal": case["normalInput"]}
            reply, _ = calls.call("pair" if "first" in case else "plane", **fields)
            assert reply["ok"] and reply["normal"] == case["normal"] and reply["equation"] == case["equation"]
            assert [p["label"] for p in reply["endpoints"]] == case["endpoints"]
            members, _ = calls.call("members", radius=6, normal=case["normal"])
            assert members["count"] == case["interiorTriplesR6"]
        export = {"schema": "actual-lean-spatial-pair-fixtures-v1", "binarySHA256": sha256(BINARY),
                  "canonicalFixtureSHA256": sha256(LOCAL / "fixtures/spatial-pair-contract.json"),
                  "cases": calls.exports}
        (LOCAL / "fixtures/spatial-pair-native-cases.json").write_text(json.dumps(export, indent=2)+"\n")
        return {"requests": calls.serial, "canonicalMachinePlanes": len(fixture["machinePlanes"]),
                "polynomialComparison": "Exact after removing canonical operator spaces; raw signed coefficients compared without normalization.",
                "cases": rows}
    finally:
        engine.close()


def density(depth: int, name: str, matrix: list[int]) -> dict[str, Any]:
    engine = Engine(BINARY, 10)
    calls = Calls(engine)
    settings = {"depth": depth, "matrix": matrix, "whole": True, "dust": False}
    points: list[list[int]] = []
    times: list[float] = []
    first: dict[str, Any] | None = None
    offset = 0
    try:
        while True:
            page, elapsed = calls.call("catalogue", **settings, offset=offset, limit=16384)
            verify(page, settings)
            first = page if first is None else first
            assert all(page[k] == first[k] for k in META)
            assert page["total"] <= 40000 and page["count"] == min(16384, page["total"]-offset)
            points.extend(triples(page)); times.append(elapsed)
            if page["nextOffset"] is None:
                break
            assert page["nextOffset"] == len(points)
            offset = page["nextOffset"]
        assert first is not None and len(points) == first["total"]
        split = first["upperCount"]
        assert points[:split] == sorted(points[:split]) and points[split:] == sorted(points[split:])
        assert len(set(map(tuple, points))) == len(points)
        member, member_ms = calls.call("membersCatalogue", **settings, normal=NORMAL)
        assert member["ok"] and all(member[k] == first[k] for k in META)
        expected = [i for i, (a,b,c) in enumerate(points) if b*b-4*a*c < 0 and a-b-c == 0]
        assert member["indices"] == expected and member["count"] == len(expected)
        warm, warm_ms = calls.call("catalogue", **settings, offset=0, limit=16384)
        assert all(warm[k] == first[k] for k in first if k != "id")
        return {"name": name, **settings, "total": len(points), "upperCount": split,
                "otherCount": first["otherCount"], "complete": first["complete"],
                "sourceLimited": first["sourceLimited"], "otherScanBound": first["otherScanBound"],
                "coldPageMs": round(times[0], 3), "cachedPageMs": [round(t, 3) for t in times[1:]],
                "warmFirstPageMs": round(warm_ms, 3), "membersMs": round(member_ms, 3),
                "membersNormal": NORMAL, "members": member["count"],
                "pages": len(times), "requests": calls.serial,
                "orderedBaseTriplesSHA256": hashlib.sha256(canonical(points)).hexdigest()}
    finally:
        engine.close()


def main() -> None:
    fixture_path = LOCAL / "fixtures/spatial-pair-contract.json"
    fixture = json.loads(fixture_path.read_text())
    before = sha256(BINARY)
    receipt = {"result": "passed", "checkoutCommit": subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "binarySHA256": before, "fixtureSHA256": sha256(fixture_path),
        "canonicalProvenance": fixture["provenance"], "scope":
        "One fresh Lean process with one worker thread per scenario, sequential. No UI, server, build, R96, or headset claim.",
        "pairing": pairing(fixture),
        "density": [density(depth, name, matrix) for depth in [16, 24] for name, matrix in MATRICES],
        "existingPublicLawsUnchanged": 17}
    assert sha256(BINARY) == before
    (LOCAL / "evidence/spatial-pair-density.json").write_text(json.dumps(receipt, indent=2)+"\n")
    print(json.dumps({"result": "passed", "pairRequests": receipt["pairing"]["requests"],
                      "density": receipt["density"]}, indent=2))


if __name__ == "__main__":
    main()
