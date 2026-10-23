#!/usr/bin/env python3
"""Compare the compiled Lean service with pinned canonical fixtures, including dense paging."""
from __future__ import annotations

from array import array
from collections import Counter
import hashlib
import json
from math import gcd
from pathlib import Path
import random
import signal
import subprocess
import sys
from time import perf_counter
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "lean/Polynomial/evidence"


class Engine:
    def __init__(self) -> None:
        self.process = subprocess.Popen([str(ROOT / "lean/.lake/build/bin/polynomial_service")],
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE, text=True)
        self.serial = 0
        self.max_bytes = 0

    def call(self, operation: str, **fields: Any) -> tuple[dict[str, Any], float]:
        self.serial += 1
        request = {"id": self.serial, "op": operation, **fields}
        assert self.process.stdin is not None and self.process.stdout is not None
        started = perf_counter()
        self.process.stdin.write(json.dumps(request) + "\n")
        self.process.stdin.flush()
        signal.alarm(20)
        line = self.process.stdout.readline()
        signal.alarm(0)
        elapsed = (perf_counter() - started) * 1000
        self.max_bytes = max(self.max_bytes, len(line.encode()))
        assert line, f"No reply for {request}"
        result = json.loads(line)
        assert result["id"] == self.serial
        assert result["schema"] == "polynomial-space-v1"
        assert result["sourceCommit"] == "ca809d2975a37a318a425e4b9dd73560b07faf39"
        return result, elapsed

    def close(self) -> None:
        assert self.process.stdin is not None
        self.process.stdin.close()
        self.process.wait(timeout=5)
        assert self.process.returncode == 0


def main() -> None:
    fixtures = json.loads((ROOT / "fixtures/polynomial-contract.json").read_text())
    engine = Engine()
    benchmark: list[dict[str, Any]] = []
    for case in fixtures["pointCases"]:
        result, _ = engine.call("inspect", point=case["abc"])
        if case["abc"] == [0, 0, 0]:
            assert not result["ok"]
            continue
        assert result["ok"], result
        for actual, expected in [("point", "abc"), ("polynomial", "polynomial"),
                                 ("delta", "discriminant"), ("kind", "kind"),
                                 ("xyz", "displayXYZ"), ("divisor", "divisor"),
                                 ("positiveRepresentative", "positiveRepresentative")]:
            assert result[actual] == case[expected], (case["id"], actual, result[actual], case[expected])
        rationals = case["projectionRationals"]
        expected_projection = None if rationals is None else [[f["numerator"], f["denominator"]] for f in rationals]
        assert result["projection"] == expected_projection
        root = case["upperRootExact"]
        expected_root = None if root is None else {
            "real": [root["real"]["numerator"], root["real"]["denominator"]],
            "imaginary": {"radicand": root["imaginarySqrtRadicand"], "denominator": root["imaginaryDenominator"]}}
        assert result["root"] == expected_root

    for operation, cases in [("pair", fixtures["pairCases"]), ("plane", fixtures["normalCases"])]:
        for case in cases:
            fields = {k: v for k, v in case.items() if k != "expected"}
            result, _ = engine.call(operation, **fields)
            expected = case["expected"]
            if "error" in expected:
                assert not result["ok"], (case, result)
                assert result["error"] == expected["error"], (case, result)
                continue
            assert result["ok"], result
            for key in ["normal", "equation", "firstPrimitive", "secondPrimitive"]:
                if key in expected:
                    assert result[key] == expected[key], (case, key, result)
            assert [p["label"] for p in result["endpoints"]] == [p["label"] for p in expected["endpoints"]]
            a, b, c = result["normal"]
            assert result["planeCoefficients"] == [-2*c, b, -2*a]
            assert result["cartesianNormal"] == [-b, -a-c, c-a]
            assert all(result["checks"].values())

    names = ["null", "exterior", "upper", "lower"]
    for ball in fixtures["balls"]:
        radius = ball["radius"]
        offset = 0
        digest = hashlib.sha256()
        counts: Counter[int] = Counter()
        request_ms: list[float] = []
        first: list[int] | None = None
        last: list[int] | None = None
        started = perf_counter()
        while True:
            page, elapsed = engine.call("cloud", radius=radius, offset=offset)
            assert page["ok"] and page["total"] == ball["total"], page
            assert page["offset"] == offset
            count = page["count"]
            abc, xyz = page["abc"], page["xyz"]
            assert len(abc) == len(xyz) == 3*count
            assert len(page["delta"]) == len(page["kind"]) == len(page["divisor"]) == count
            assert page["onPlane"] is None and page["necklace"] is None
            encoded = array("h", abc)
            if sys.byteorder != "little":
                encoded.byteswap()
            digest.update(encoded.tobytes())
            counts.update(page["kind"])
            request_ms.append(elapsed)
            for i in range(count):
                a, b, c = abc[3*i:3*i+3]
                d = b*b-4*a*c
                assert xyz[3*i:3*i+3] == [-b, a+c, c-a]
                assert page["delta"][i] == d
                assert page["divisor"][i] == gcd(gcd(a, b), c)
                assert page["kind"][i] == (0 if d == 0 else 1 if d > 0 else 2 if a > 0 else 3)
                assert b*b+2*a*a+2*c*c <= radius*radius and (a, b, c) != (0, 0, 0)
            if first is None:
                first = abc[:3]
            last = abc[-3:]
            if page["nextOffset"] is None:
                break
            assert page["nextOffset"] == offset+count
            offset = page["nextOffset"]
        assert digest.hexdigest() == ball["abcInt16LE_SHA256"], (radius, digest.hexdigest())
        assert first == ball["firstABC"] and last == ball["lastABC"]
        assert {names[k]: counts[k] for k in range(4)} == ball["counts"]
        members, member_ms = engine.call("members", radius=radius, normal=[1, 0, -1])
        assert members["ok"] and members["total"] == ball["total"]
        beyond, _ = engine.call("cloud", radius=radius, offset=ball["total"]+1)
        assert beyond["count"] == 0 and beyond["abc"] == [] and beyond["nextOffset"] is None
        upper, upper_ms = engine.call("cloud", radius=radius, upperOnly=True, limit=1)
        assert upper["total"] == ball["upperOnlyCount"] and upper["kind"] == [2]
        entry = {"radius": radius, "count": ball["total"], "pages": len(request_ms),
                 "firstPageMs": request_ms[0], "maxCachedPageMs": max(request_ms[1:], default=0),
                 "membersMs": member_ms, "membersCount": members["count"],
                 "upperCloudFirstMs": upper_ms, "allPagesAndValidationMs": (perf_counter()-started)*1000,
                 "canonicalOrderSha256": digest.hexdigest()}
        benchmark.append(entry)
        print(json.dumps(entry), flush=True)

    small, _ = engine.call("cloud", radius=12, normal=[1, 0, -1])
    members, _ = engine.call("members", radius=12, normal=[1, 0, -1])
    assert members["indices"] == [i for i, yes in enumerate(small["necklace"]) if yes]
    for i, yes in enumerate(small["onPlane"]):
        a, b, c = small["abc"][3*i:3*i+3]
        assert yes == (2*a-2*c == 0)
        assert small["necklace"][i] == (yes and b*b-4*a*c < 0)

    rng = random.Random(20261023)
    for _ in range(100):
        point = [rng.randint(-96, 96) for _ in range(3)]
        if point == [0, 0, 0]:
            continue
        result, _ = engine.call("inspect", point=point)
        a, b, c = point
        assert result["ok"] and result["delta"] == b*b-4*a*c
        assert result["xyz"] == [-b, a+c, c-a]

    invalid = [
        ("cloud", {"radius": 97}), ("cloud", {"radius": 3}),
        ("cloud", {"radius": 6, "limit": 16385}),
        ("cloud", {"radius": 6, "offset": 2000001}),
        ("cloud", {"radius": 6, "normal": [0, 0, 0]}),
        ("inspect", {"point": [1025, 0, 1]}), ("inspect", {"point": [1.5, 0, 1]}),
        ("inspect", {"point": [True, 0, 1]}), ("inspect", {"point": [1, 2]}),
        ("inspect", {"point": [1, 0, 1], "height": 0}),
        ("plane", {"normal": [4194305, 0, -1]}), ("unknown", {}),
    ]
    for operation, fields in invalid:
        result, _ = engine.call(operation, **fields)
        assert not result["ok"], (operation, fields, result)
    assert engine.max_bytes < 2*1024*1024
    summary = {"result": "passed", "requests": engine.serial,
               "pointFixtures": len(fixtures["pointCases"]), "pairFixtures": len(fixtures["pairCases"]),
               "normalFixtures": len(fixtures["normalCases"]), "cloudRadii": len(benchmark),
               "validatedPoints": sum(item["count"] for item in benchmark),
               "randomPoints": 100, "invalidCases": len(invalid),
               "maxResponseBytes": engine.max_bytes, "benchmarks": benchmark,
               "scope": "Compiled Lean service and JSON transport; no renderer or headset performance claim."}
    engine.close()
    EVIDENCE.mkdir(exist_ok=True)
    (EVIDENCE / "service-tests.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({k: v for k, v in summary.items() if k != "benchmarks"}))


if __name__ == "__main__":
    main()
