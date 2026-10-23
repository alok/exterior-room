#!/usr/bin/env python3
"""Test the actual Lean executable against pinned fixtures and an independent form-evaluation oracle."""
from __future__ import annotations

from fractions import Fraction
import hashlib
import json
from pathlib import Path
import random
from typing import Any

from test_service import Engine, ROOT

PIN = "63ad115422ab1141ca6d06732572385414b7a5cf"
HERE = Path(__file__).resolve().parent
BOUND = 1_000_000
IDENTITY_BOUND = 1024


def determinant(m: list[int]) -> int:
    p, q, r, s = m
    return p*s-q*r


def evaluate(abc: list[int], x: int, y: int) -> int:
    a, b, c = abc
    return a*x*x+b*x*y+c*y*y


def oracle(m: list[int], abc: list[int]) -> list[int]:
    """Recover coefficients by evaluating Q(adj(M)(x,y)) at three basis points."""
    p, q, r, s = m
    a = evaluate(abc, s, -r)
    c = evaluate(abc, -q, p)
    return [a, evaluate(abc, s-q, p-r)-a-c, c]


def delta(abc: list[Any]) -> Any:
    a, b, c = abc
    return b*b-4*a*c


def incidence(n: list[Any], p: list[Any]) -> Any:
    return -2*n[2]*p[0]+n[1]*p[1]-2*n[0]*p[2]


def multiply(g: list[int], h: list[int]) -> list[int]:
    return [g[0]*h[0]+g[1]*h[2], g[0]*h[1]+g[1]*h[3],
            g[2]*h[0]+g[3]*h[2], g[2]*h[1]+g[3]*h[3]]


def check(engine: Engine, matrix: list[int], point: list[int]) -> dict[str, Any]:
    result, _ = engine.call("transform", matrix=matrix, point=point)
    assert result["ok"], result
    assert result["actionSchema"] == "polynomial-mobius-v1"
    assert result["actionSourceCommit"] == PIN
    assert result["matrix"] == matrix and result["point"] == point
    d = determinant(matrix)
    assert result["denominator"] == d > 0
    expected = oracle(matrix, point)
    assert result["imageNumerator"] == expected
    a, b, c = expected
    assert result["xyzNumerator"] == [-b, a+c, c-a]
    expected_rows = [oracle(matrix, basis) for basis in [[1, 0, 0], [0, 1, 0], [0, 0, 1]]]
    assert result["coefficientRows"] == [expected_rows[j][i] for i in range(3) for j in range(3)]
    assert result["delta"] == delta(point)
    assert delta([Fraction(n, d) for n in expected]) == delta(point)
    assert result["image"] == ([n//d for n in expected] if all(n % d == 0 for n in expected) else None)
    assert result["checks"] == {"positiveDeterminant": True, "discriminantPreserved": True}
    integers = result["coefficientRows"]+result["imageNumerator"]+result["xyzNumerator"]
    assert all(type(n) is int and abs(n) <= 2**53-1 for n in integers)
    return result


def positive_matrix(rng: random.Random, bound: int) -> list[int]:
    while True:
        m = [rng.randint(-bound, bound) for _ in range(4)]
        d = determinant(m)
        if d:
            return m if d > 0 else [m[2], m[3], m[0], m[1]]


def check_snap_contract(engine: Engine) -> dict[str, Any]:
    """Check exact arithmetic used by the canonical Snap transition, without claiming a client UI test."""
    fixture_path = HERE / "fixtures/snap-contract.json"
    fixtures = json.loads(fixture_path.read_text())
    assert fixtures["sourceCommit"] == "6fea557bb0d0c786bed5223dc631cb1c06e94f16"
    started = engine.serial
    identity = [1, 0, 0, 1]
    seed = [13, 20, 34]
    for candidate in fixtures["nearestIntegral"]:
        gamma = candidate["gamma"]
        assert determinant(gamma) == 1
        result = check(engine, gamma, seed)
        assert result["image"] == result["imageNumerator"]
        # The source chooses among ±gamma; their quadratic coefficient actions are identical.
        opposite = check(engine, [-n for n in gamma], seed)
        assert result["image"] == opposite["image"]

    bound_rejections = 0
    paired_cases = 0
    for case in fixtures["absorptions"]:
        before, after = case["before"], case["afterAbsorb"]
        assert after["group"] == identity and case["afterIdentity"] == after
        points_before = [before["selected"]] + ([before["second"]] if before["second"] is not None else [])
        points_after = [after["selected"]] + ([after["second"]] if after["second"] is not None else [])
        for old, new in zip(points_before, points_after):
            original, _ = engine.call("inspect", point=old)
            assert original["ok"] and original["point"] == old
            moved = check(engine, case["gamma"], old)
            assert moved["denominator"] == 1 and moved["image"] == new
            inspected, _ = engine.call("inspect", point=new)
            within_bounds = all(abs(n) <= IDENTITY_BOUND for n in new)
            assert inspected["ok"] == within_bounds, (case["id"], inspected)
            if within_bounds:
                assert inspected["point"] == new and inspected["delta"] == original["delta"]
                # Identity acts on the new signed label, not on a saved pre-Snap label.
                unchanged = check(engine, identity, new)
                assert unchanged["image"] == new
            else:
                bound_rejections += 1
                assert str(IDENTITY_BOUND) in inspected["error"]
                recovered, _ = engine.call("inspect", point=old)
                assert recovered["ok"] and recovered["point"] == old

        if before["second"] is not None:
            paired_cases += 1
            old_pair, _ = engine.call("pair", first=before["selected"], second=before["second"])
            assert old_pair["ok"] and old_pair["normal"] == case["planeBefore"]["normal"]
            new_pair, _ = engine.call("pair", first=after["selected"], second=after["second"])
            # serviceInputsWithin96 is historical metadata, not the current identity domain.
            assert new_pair["ok"] == all(abs(n) <= IDENTITY_BOUND for point in points_after for n in point)
            if new_pair["ok"]:
                assert new_pair["normal"] == case["planeAfter"]["normal"]
                assert new_pair["equation"] == case["planeAfter"]["equation"]
                assert [p["label"] for p in new_pair["endpoints"]] == case["planeAfter"]["endpoints"]
                assert incidence(new_pair["normal"], after["selected"]) == 0
                assert incidence(new_pair["normal"], after["second"]) == 0
            else:
                # The stateless service still accepts the entire old pair; clients must keep it atomically.
                restored, _ = engine.call("pair", first=before["selected"], second=before["second"])
                assert restored["ok"] and restored["normal"] == old_pair["normal"]

    observed = fixtures["absorptions"][0]
    assert observed["before"]["selected"] == seed
    assert observed["afterAbsorb"]["selected"] == [13, -6, 27]
    assert observed["afterIdentity"]["selected"] == [13, -6, 27]
    return {"requests": engine.serial-started, "sourceCommit": fixtures["sourceCommit"],
            "nearestIntegerCandidates": len(fixtures["nearestIntegral"]),
            "absorptionCases": len(fixtures["absorptions"]), "pairedCases": paired_cases,
            "outOfBoundsImagesRejectedByInspect": bound_rejections,
            "historicalIdentityBound": 96, "currentIdentityBound": IDENTITY_BOUND,
            "fixtureSHA256": hashlib.sha256(fixture_path.read_bytes()).hexdigest(),
            "boundary": "Exact service transitions only; nearestIntegral is pinned floating-point fixture data. Client atomic rollback and actual UI input are not exercised here."}


def check_identity_bounds(engine: Engine) -> dict[str, Any]:
    fixture_path = HERE / "fixtures/identity-bounds-contract.json"
    fixtures = json.loads(fixture_path.read_text())
    assert fixtures["identityBound"] == IDENTITY_BOUND
    started = engine.serial
    for case in fixtures["absorptions"]:
        points = [case["point"]] + ([case["second"]] if case["second"] is not None else [])
        images = [case["image"]] + ([case["secondImage"]] if case["second"] is not None else [])
        for point, image in zip(points, images):
            original, _ = engine.call("inspect", point=point)
            assert original["ok"]
            moved = check(engine, case["matrix"], point)
            assert moved["image"] == image
            inspected, _ = engine.call("inspect", point=image)
            assert inspected["ok"] == all(abs(n) <= IDENTITY_BOUND for n in image)
            if inspected["ok"]:
                assert inspected["delta"] == original["delta"]
                assert check(engine, [1, 0, 0, 1], image)["image"] == image
        if case["second"] is not None:
            pair, _ = engine.call("pair", first=images[0], second=images[1])
            assert pair["ok"] == case["accepted"]
            if pair["ok"]:
                assert pair["normal"] == case["normal"]
            else:
                old, _ = engine.call("pair", first=points[0], second=points[1])
                assert old["ok"], old
    case = fixtures["expandedNormalPair"]
    pair, _ = engine.call("pair", first=case["first"], second=case["second"])
    assert pair["ok"] and pair["normal"] == case["normal"]
    members, _ = engine.call("members", normal=pair["normal"], radius=6)
    assert members["ok"] and members["total"] == 480
    budget = fixtures["endpointBudgetRejectedPair"]
    rejected, _ = engine.call("pair", first=budget["first"], second=budget["second"])
    assert not rejected["ok"] and "bounded endpoint service" in rejected["error"]
    for point in [[1024, 1024, 1024], [-1024, 1024, -1024], [1024, 1024, -1024], [1024, 0, 1024]]:
        result, _ = engine.call("inspect", point=point, height=24)
        assert result["ok"] and result["delta"] == delta(point)
    return {"requests": engine.serial-started, "sourceCommit": fixtures["sourceCommit"],
            "identityBound": IDENTITY_BOUND, "cloudRadiusBound": 96, "normalBound": fixtures["normalBound"],
            "absorptionCases": len(fixtures["absorptions"]), "pairedOutOfBoundCases": 4,
            "maxTransformNumeratorBound": 6*IDENTITY_BOUND*BOUND**2,
            "fixtureSHA256": hashlib.sha256(fixture_path.read_bytes()).hexdigest(),
            "boundary": "Exact service results and bounds. Atomic client publication is tested separately."}


def main() -> None:
    fixture_path = HERE / "fixtures/mobius-contract.json"
    fixtures = json.loads(fixture_path.read_text())
    assert fixtures["sourceCommit"] == PIN
    points = {point["id"]: point["abc"] for point in fixtures["points"]}
    engine = Engine()
    fixture_cases = 0
    for generator in fixtures["mobius"]["generators"]:
        for image in generator["images"]:
            result = check(engine, generator["g"], points[image["id"]])
            assert result["coefficientRows"] == generator["pushforwardRows"]
            assert result["image"] == image["image"]
            fixture_cases += 1
    drag = check(engine, [3, 1, 1, 2], [1, -1, 2])
    assert drag["denominator"] == 5 and drag["imageNumerator"] == [8, -23, 22]
    assert all(abs(n/5-approx) < 1e-12 for n, approx in zip(
        drag["imageNumerator"], fixtures["mobius"]["dragStep"]["imageOfDefaultApprox"]))
    assert check(engine, [3, 1, 1, 2], [1, 0, 1])["image"] == [1, -2, 2]
    assert check(engine, [3, 1, 1, 2], [-2, 2, -4])["imageNumerator"] == [-16, 46, -44]

    extremes = [[BOUND, BOUND, -BOUND, BOUND],
                [BOUND-1, BOUND-2, BOUND, BOUND-1],
                [-BOUND, 0, 0, -BOUND], [1, 0, 0, 1]]
    for matrix in extremes:
        for point in [[1024, 1024, 1024], [-1024, 1024, -1024], [1024, -1024, -1024]]:
            check(engine, matrix, point)

    rng = random.Random(63115)
    for _ in range(100):
        point = [rng.randint(-IDENTITY_BOUND, IDENTITY_BOUND) for _ in range(3)]
        check(engine, positive_matrix(rng, BOUND), point if any(point) else [1, 0, 0])

    for _ in range(30):
        g, h = positive_matrix(rng, 20), positive_matrix(rng, 20)
        point = [rng.randint(-10, 10) for _ in range(3)]
        point = point if any(point) else [1, 0, 0]
        rg = check(engine, g, point)
        rh = check(engine, h, point)
        rgh = check(engine, multiply(g, h), point)
        composed = [sum(Fraction(rg["coefficientRows"][3*i+j], rg["denominator"])
                        * Fraction(rh["imageNumerator"][j], rh["denominator"]) for j in range(3))
                    for i in range(3)]
        assert composed == [Fraction(n, rgh["denominator"]) for n in rgh["imageNumerator"]]
        p, q, r, s = g
        inverse = check(engine, [s, -q, -r, p], point)
        restored = [sum(Fraction(inverse["coefficientRows"][3*i+j], inverse["denominator"])
                       * Fraction(rg["imageNumerator"][j], rg["denominator"]) for j in range(3))
                   for i in range(3)]
        assert restored == point
        normal = check(engine, g, [1, 0, -1])
        assert incidence([Fraction(n, normal["denominator"]) for n in normal["imageNumerator"]],
                         [Fraction(n, rg["denominator"]) for n in rg["imageNumerator"]]) == incidence([1, 0, -1], point)

    before, _ = engine.call("cloud", radius=6, limit=10)
    invalid: list[dict[str, Any]] = [
        {"matrix": [1, 0, 0]}, {"matrix": [1, 0, 0, 1, 0]},
        {"matrix": [1, 0, 0, 0]}, {"matrix": [1, 0, 0, -1]},
        {"matrix": [BOUND+1, 0, 0, 1]}, {"matrix": [-BOUND-1, 0, 0, -1]},
        {"matrix": [1.5, 0, 0, 1]}, {"matrix": [True, 0, 0, 1]},
        {"matrix": ["1", 0, 0, 1]}, {"point": [0, 0, 0]},
        {"point": [1025, 0, 1]}, {"point": [1, 0.5, 1]}, {"point": [1, 1]},
    ]
    for bad in invalid:
        request: dict[str, Any] = {"matrix": [1, 0, 0, 1], "point": [1, 0, 1], **bad}
        result, _ = engine.call("transform", **request)
        assert not result["ok"], result
    after, _ = engine.call("cloud", radius=6, limit=10)
    assert {k: v for k, v in before.items() if k != "id"} == {k: v for k, v in after.items() if k != "id"}
    snap = check_snap_contract(engine)
    identity_bounds = check_identity_bounds(engine)
    engine.close()
    result = {"passed": True, "requests": engine.serial, "canonicalGeneratorCases": fixture_cases,
              "exactDragCases": 3, "extremeCases": 12, "randomMatrices": 100,
              "compositionInverseIncidenceCases": 30, "invalidCases": len(invalid),
              "fixtureSHA256": hashlib.sha256(fixture_path.read_bytes()).hexdigest(),
              "actionSourceCommit": PIN, "maxResponseBytes": engine.max_bytes,
              "snap": snap,
              "identityBounds": identity_bounds,
              "boundary": "Exact committed rational action; no proof or test of continuous pointer trajectory or rendering."}
    (HERE / "evidence/transform-tests.json").write_text(json.dumps(result, indent=2)+"\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
