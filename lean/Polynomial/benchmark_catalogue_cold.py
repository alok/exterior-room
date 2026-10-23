#!/usr/bin/env python3
"""Compare preserved and candidate Lean catalogue binaries without concurrent workers.

Each scenario starts a fresh process. Its first request is cold with respect to
the process catalogue cache; later pages, membership, and repeated pages are
warm. These are local wall-clock measurements, not a statistical benchmark.
Every decoded response field is compared, including errors and ordered arrays.
The independent source-oracle test_catalogue.py remains a separate check.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import selectors
import subprocess
import tempfile
import time
from typing import Any, BinaryIO, TypeAlias

JSONObject: TypeAlias = dict[str, Any]
ROOT = Path(__file__).resolve().parents[2]
SOURCE_FILES = (
    "Core.lean", "Transform.lean", "Catalogue.lean", "Main.lean",
    "Proofs.lean", "TransformProofs.lean",
)
PROOF_FILES = ("Proofs.lean", "TransformProofs.lean")
IDENTITY = [1, 0, 0, 1]
MAX_RESPONSE_BYTES = 8 * 1024 * 1024


class BenchmarkFailure(Exception):
    """A response, provenance, or process check failed."""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while block := source.read(1024 * 1024):
            digest.update(block)
    return digest.hexdigest()


def source_hashes(directory: Path) -> dict[str, str]:
    return {name: sha256(directory / name) for name in SOURCE_FILES}


def canonical(value: Any) -> bytes:
    # Object member order is immaterial; list order and scalar types are retained.
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False, allow_nan=False).encode("utf-8")


def reject_constant(value: str) -> None:
    raise BenchmarkFailure(f"Non-finite JSON constant: {value}")


def difference(left: Any, right: Any, path: str = "$") -> str | None:
    """Locate the first type-aware difference, retaining every ordered array element."""
    if type(left) is not type(right):
        return f"{path}: types {type(left).__name__} != {type(right).__name__}"
    if isinstance(left, dict):
        if left.keys() != right.keys():
            return f"{path}: keys {sorted(left)} != {sorted(right)}"
        for key in sorted(left):
            if found := difference(left[key], right[key], f"{path}.{key}"):
                return found
    elif isinstance(left, list):
        if len(left) != len(right):
            return f"{path}: lengths {len(left)} != {len(right)}"
        for index, (a, b) in enumerate(zip(left, right)):
            if found := difference(a, b, f"{path}[{index}]"):
                return found
    elif left != right:
        return f"{path}: {str(left)[:160]!r} != {str(right)[:160]!r}"
    return None


class Engine:
    def __init__(self, binary: Path, timeout: float) -> None:
        self.timeout = timeout
        self.pending = bytearray()
        self.stderr: BinaryIO = tempfile.TemporaryFile()
        started = time.perf_counter()
        self.process: subprocess.Popen[bytes] = subprocess.Popen(
            [str(binary)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=self.stderr, cwd=ROOT, bufsize=0,
            env={**os.environ, "LEAN_NUM_THREADS": "1"},
        )
        self.startup_ms = (time.perf_counter() - started) * 1000

    def call(self, request: JSONObject) -> tuple[JSONObject, float, int]:
        assert self.process.stdin is not None and self.process.stdout is not None
        started = time.perf_counter()
        self.process.stdin.write(canonical(request) + b"\n")
        self.process.stdin.flush()
        deadline = started + self.timeout
        with selectors.DefaultSelector() as selector:
            selector.register(self.process.stdout, selectors.EVENT_READ)
            while b"\n" not in self.pending:
                remaining = deadline - time.perf_counter()
                if remaining <= 0 or not selector.select(remaining):
                    raise BenchmarkFailure(f"Request {request['id']} exceeded {self.timeout}s")
                block = os.read(self.process.stdout.fileno(), 65536)
                if not block:
                    raise BenchmarkFailure(f"Lean exited before response {request['id']}")
                self.pending.extend(block)
                if len(self.pending) > MAX_RESPONSE_BYTES:
                    raise BenchmarkFailure("Response exceeds the benchmark's 8 MiB guard")
        line, _, rest = self.pending.partition(b"\n")
        self.pending = bytearray(rest)
        elapsed = (time.perf_counter() - started) * 1000
        response: Any = json.loads(line, parse_constant=reject_constant)
        if not isinstance(response, dict) or type(response.get("ok")) is not bool:
            raise BenchmarkFailure("Lean returned an invalid response object")
        if type(response.get("id")) is not int or response["id"] != request["id"]:
            raise BenchmarkFailure("Lean returned a different request id")
        return response, elapsed, len(line)

    def close(self) -> None:
        try:
            if self.process.stdin is not None:
                self.process.stdin.close()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=2)
        finally:
            if self.process.stdout is not None:
                self.process.stdout.close()
            self.stderr.close()


@dataclass(frozen=True)
class Scenario:
    name: str
    settings: JSONObject
    limit: int = 16384
    mode: str = "full"


@dataclass
class Observation:
    label: str
    request: JSONObject
    response: JSONObject
    elapsed_ms: float
    response_bytes: int

    def receipt(self) -> JSONObject:
        return {
            "label": self.label, "request": self.request,
            "elapsedMs": round(self.elapsed_ms, 3), "responseBytes": self.response_bytes,
            "responseSHA256": hashlib.sha256(canonical(self.response)).hexdigest(),
            "ok": self.response["ok"],
        }


def scenarios() -> list[Scenario]:
    return [
        Scenario("source16-15192", {"depth": 16, "matrix": [15192, 7950, 14719, 14285]}),
        Scenario("source16-16478", {"depth": 16, "matrix": [16478, 8954, 16361, 14960]}),
        Scenario("identity6-signed-multiples", {"depth": 6, "matrix": IDENTITY}),
        Scenario("identity12-exact-norm-boundary", {"depth": 12, "matrix": IDENTITY}),
        Scenario("rational-d5", {"depth": 6, "matrix": [3, 1, 1, 2]}),
        Scenario("identity6-pages17", {"depth": 6, "matrix": IDENTITY}, limit=17),
        Scenario("other-scan-source-limit", {"depth": 6, "matrix": [1, 6, 0, 1]}),
        Scenario("upper-cap96", {"depth": 96, "matrix": IDENTITY, "whole": False}, mode="cap"),
        Scenario("errors-preserve-cache", {"depth": 6, "matrix": IDENTITY}, limit=17, mode="errors"),
    ]


def collect_baseline(engine: Engine, scenario: Scenario) -> list[Observation]:
    observed: list[Observation] = []

    def call(label: str, fields: JSONObject, expected_ok: bool = True) -> JSONObject:
        request = {"id": len(observed) + 1, **fields}
        response, elapsed, size = engine.call(request)
        observed.append(Observation(label, request, response, elapsed, size))
        if response["ok"] is not expected_ok:
            raise BenchmarkFailure(f"{scenario.name}/{label}: unexpected success/error: {response.get('error')}")
        return response

    first_request = {"op": "catalogue", **scenario.settings, "offset": 0,
                     "limit": 1 if scenario.mode == "cap" else scenario.limit}
    first = call("cold-page-0", first_request)
    if scenario.mode == "cap":
        if first.get("upperCount") != 600000 or not first.get("sourceLimited", {}).get("upperCap"):
            raise BenchmarkFailure("Baseline did not exercise the 600000-point source cap")
        call("warm-cap-last", {**first_request, "offset": 599999})
        call("warm-cap-middle", {**first_request, "offset": 300000, "limit": 17})
    elif scenario.mode == "errors":
        bad: list[tuple[str, JSONObject]] = [
            ("c-envelope12", {"matrix": [1, 12, 0, 1]}),
            ("c-envelope13", {"matrix": [1, 13, 0, 1]}),
            ("extreme-envelope", {"matrix": [1, 0, 1000000, 1]}),
            ("depth-low", {"depth": 3}), ("depth-high", {"depth": 97}),
            ("singular", {"matrix": [1, 0, 0, 0]}),
            ("entry-bound", {"matrix": [1000001, 0, 0, 1]}),
            ("whole-type", {"whole": 1}), ("negative-offset", {"offset": -1}),
            ("page-limit", {"limit": 16385}),
        ]
        for name, invalid in bad:
            call(f"error-{name}", {**first_request, **invalid}, expected_ok=False)
            call(f"warm-after-{name}", first_request)
        call("error-zero-normal", {"op": "membersCatalogue", **scenario.settings,
                                   "normal": [0, 0, 0]}, expected_ok=False)
    else:
        points: list[tuple[int, int, int]] = []
        page, offset = first, 0
        while True:
            abc = page.get("abc")
            if not isinstance(abc, list) or len(abc) != 3 * page["count"]:
                raise BenchmarkFailure("Baseline page has malformed packed coordinates")
            points.extend(tuple(abc[i:i + 3]) for i in range(0, len(abc), 3))
            next_offset = page.get("nextOffset")
            if next_offset is None:
                break
            if type(next_offset) is not int or not offset < next_offset <= 2000000:
                raise BenchmarkFailure("Baseline pagination did not advance")
            offset = next_offset
            page = call(f"warm-page-{offset}", {**first_request, "offset": offset})
        if len(points) != first["total"]:
            raise BenchmarkFailure("Baseline pagination omitted catalogue points")
        if scenario.name == "identity6-signed-multiples":
            if not {(-1, 0, -1), (1, 0, 1), (2, 0, 2)}.issubset(set(points)):
                raise BenchmarkFailure("Signed and nonprimitive coverage witnesses are absent")
        if scenario.name == "identity12-exact-norm-boundary":
            identities = set(points)
            if not {(0, 6, 0), (-3, 0, -3)}.issubset(identities) or (0, 7, 0) in identities:
                raise BenchmarkFailure("Exact norm-boundary inclusion/exclusion witnesses differ")
        call("warm-same-config-members", {"op": "membersCatalogue", **scenario.settings,
                                          "normal": [1, 0, -1]})
    call("warm-repeat-page-0", first_request)
    return observed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--baseline-source-dir", type=Path, required=True,
                        help="Preserved pre-edit directory containing the six service/proof Lean sources")
    parser.add_argument("--candidate-source-dir", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--timeout", type=float, default=30.0, help="Per-response deadline in seconds")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    receipt: JSONObject = {
        "schema": "polynomial-catalogue-cold-differential-v1", "result": "failed",
        "startedUTC": datetime.now(timezone.utc).isoformat(),
        "execution": "sequential fresh processes; one Lean worker at a time",
        "timingScope": "stdin write through complete stdout line, excluding JSON decoding; process start recorded separately",
        "comparison": "all decoded fields and scalar types; ordered arrays preserved; object-key ordering ignored",
        "sourceOracle": "not run by this script; test_catalogue.py is separate",
        "scenarios": [],
    }
    try:
        if args.timeout <= 0:
            raise BenchmarkFailure("--timeout must be positive")
        baseline, candidate = args.baseline.resolve(), args.candidate.resolve()
        old_sources, new_sources = args.baseline_source_dir.resolve(), args.candidate_source_dir.resolve()
        provenance: JSONObject = {}
        for role, binary, sources in (("baseline", baseline, old_sources), ("candidate", candidate, new_sources)):
            if not binary.is_file() or not os.access(binary, os.X_OK):
                raise BenchmarkFailure(f"{role} binary is not executable: {binary}")
            provenance[role] = {"binary": str(binary), "binarySHA256": sha256(binary),
                                "sourceDirectory": str(sources), "sourceSHA256": source_hashes(sources)}
        receipt["provenance"] = provenance
        receipt["benchmarkScriptSHA256"] = sha256(Path(__file__).resolve())
        for name in PROOF_FILES:
            if provenance["baseline"]["sourceSHA256"][name] != provenance["candidate"]["sourceSHA256"][name]:
                raise BenchmarkFailure(f"Proof statements/proofs changed: {name}")
        receipt["unchangedProofFiles"] = {name: provenance["candidate"]["sourceSHA256"][name] for name in PROOF_FILES}
        for scenario in scenarios():
            row: JSONObject = {"name": scenario.name, "requests": [], "result": "pending"}
            receipt["scenarios"].append(row)
            engine = Engine(baseline, args.timeout)
            row["baselineProcessStartMs"] = round(engine.startup_ms, 3)
            try:
                expected = collect_baseline(engine, scenario)
            finally:
                engine.close()
            # The baseline child is reaped before the candidate child is created.
            engine = Engine(candidate, args.timeout)
            row["candidateProcessStartMs"] = round(engine.startup_ms, 3)
            try:
                for old in expected:
                    response, elapsed, size = engine.call(old.request)
                    new = Observation(old.label, old.request, response, elapsed, size)
                    item: JSONObject = {"label": old.label, "request": old.request,
                                         "baseline": old.receipt(), "candidate": new.receipt()}
                    row["requests"].append(item)
                    if mismatch := difference(old.response, new.response):
                        item["difference"] = mismatch
                        raise BenchmarkFailure(f"{scenario.name}/{old.label}: {mismatch}")
                    item["equal"] = True
            finally:
                engine.close()
            row["coldBaselineMs"] = round(expected[0].elapsed_ms, 3)
            row["coldCandidateMs"] = row["requests"][0]["candidate"]["elapsedMs"]
            row["result"] = "passed"
        for role, binary, sources in (("baseline", baseline, old_sources), ("candidate", candidate, new_sources)):
            if sha256(binary) != provenance[role]["binarySHA256"] or source_hashes(sources) != provenance[role]["sourceSHA256"]:
                raise BenchmarkFailure(f"{role} binary or source files changed during comparison")
        receipt["requestsCompared"] = sum(len(row["requests"]) for row in receipt["scenarios"])
        receipt["result"] = "passed"
    except (BenchmarkFailure, OSError, ValueError, KeyError, TypeError) as error:
        receipt["error"] = f"{type(error).__name__}: {error}"
    receipt["finishedUTC"] = datetime.now(timezone.utc).isoformat()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps({"result": receipt["result"], "receipt": str(args.output.resolve()),
                      "requestsCompared": receipt.get("requestsCompared", 0),
                      "error": receipt.get("error")}, indent=2))
    return 0 if receipt["result"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
