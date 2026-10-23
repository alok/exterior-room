#!/usr/bin/env python3
"""Integration checks against an independent integer-coordinate oracle."""
from __future__ import annotations

import json
from pathlib import Path
import random
import subprocess
from typing import Any

ROOT = Path(__file__).resolve().parent
Vector = list[int]


def expected_wedge(a: Vector, b: Vector) -> Vector:
    return [a[0] * b[1] - a[1] * b[0], a[0] * b[2] - a[2] * b[0],
            a[1] * b[2] - a[2] * b[1]]


def expected_volume(a: Vector, b: Vector, c: Vector) -> int:
    # Independent six-term determinant, unlike the service's generated wedge composition.
    return (a[0] * b[1] * c[2] + a[1] * b[2] * c[0] + a[2] * b[0] * c[1]
            - a[2] * b[1] * c[0] - a[1] * b[0] * c[2] - a[0] * b[2] * c[1])


def main() -> None:
    rng = random.Random(20261023)
    cases: list[tuple[Vector, Vector, Vector]] = [
        ([4, 0, 0], [0, 4, 0], [0, 0, 4]),
        ([0, 4, 0], [4, 0, 0], [0, 0, 4]),
        ([1, 2, 3], [2, 4, 6], [-1, 1, 0]),
        ([0, 0, 0], [1, 2, 3], [4, 5, 6]),
        ([12, -12, 12], [-12, 12, 12], [12, 12, -12]),
    ]
    for _ in range(250):
        cases.append(tuple([rng.randint(-12, 12) for _ in range(3)] for _ in range(3)))
    requests: list[dict[str, Any]] = [
        {"id": index, "a": a, "b": b, "c": c}
        for index, (a, b, c) in enumerate(cases)
    ]
    invalid: list[str] = [
        "not json", "null", "[]", "{}",
        json.dumps({"id": "bounds", "a": [13, 0, 0], "b": [0, 0, 0], "c": [0, 0, 0]}),
        json.dumps({"id": "length", "a": [0, 0], "b": [0, 0, 0], "c": [0, 0, 0]}),
        json.dumps({"id": "fraction", "a": [0.25, 0, 0], "b": [0, 0, 0], "c": [0, 0, 0]}),
        json.dumps({"id": "bool", "a": [True, 0, 0], "b": [0, 0, 0], "c": [0, 0, 0]}),
    ]
    lines = [json.dumps(request) for request in requests] + invalid
    result = subprocess.run([str(ROOT / ".lake/build/bin/wedge_service")],
                            input="\n".join(lines) + "\n", text=True,
                            capture_output=True, check=True, timeout=30)
    replies = [json.loads(line) for line in result.stdout.splitlines()]
    assert len(replies) == len(lines), (len(replies), len(lines))
    for request, response in zip(requests, replies):
        a, b, c = request["a"], request["b"], request["c"]
        assert response["ok"] is True
        assert response["id"] == request["id"]
        assert response["scale"] == 4
        assert [response[k] for k in ("a", "b", "c")] == [a, b, c]
        w = expected_wedge(a, b)
        vol = expected_volume(a, b, c)
        assert response["wedge"] == w, (request, response)
        assert response["swappedWedge"] == [-x for x in w]
        assert response["selfWedge"] == [0, 0, 0]
        assert response["volume"] == vol
        assert response["swappedVolume"] == -vol
        assert response["repeatedVolume"] == 0
        assert all(value is True for value in response["checks"].values())
        sums = [[a[i] + b[i] for i in range(3)], [a[i] + c[i] for i in range(3)],
                [b[i] + c[i] for i in range(3)], [a[i] + b[i] + c[i] for i in range(3)]]
        assert response["vertices"] == [[0, 0, 0], a, b, c, *sums]
    for response in replies[len(requests):]:
        assert response["ok"] is False and isinstance(response["error"], str)
    summary = {"validCases": len(requests), "invalidCases": len(invalid),
               "oracle": "independent integer wedge and six-term determinant",
               "result": "passed"}
    (ROOT / "evidence/service-tests.json").write_text(json.dumps(summary, indent=2) + "\n")
    (ROOT / "evidence/unit-cube-response.json").write_text(json.dumps(replies[0], indent=2) + "\n")
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
