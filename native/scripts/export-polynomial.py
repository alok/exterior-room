#!/usr/bin/env python3
"""Export small native fixtures from the compiled Lean service; never substitute Python math."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
from typing import Any

ROOT: Path = Path(__file__).resolve().parents[2]
EXECUTABLE: Path = ROOT / "lean/.lake/build/bin/polynomial_service"
RESOURCES: Path = ROOT / "native/Resources"
SOURCE_COMMIT: str = "ca809d2975a37a318a425e4b9dd73560b07faf39"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    contract_path: Path = ROOT / "fixtures/polynomial-contract.json"
    contract: dict[str, Any] = json.loads(contract_path.read_text())
    default: list[int] = next(case["abc"] for case in contract["pointCases"] if case["id"] == "default")
    requests: list[dict[str, Any]] = [
        {"op": "cloud", "radius": 6, "upperOnly": False, "offset": 0, "limit": 16384},
        {"op": "inspect", "point": default},
    ]
    names: list[str] = ["cloud", "default"]
    for case in contract["pointCases"]:
        if case["abc"] != [0, 0, 0]:
            names.append(case["id"])
            requests.append({"op": "inspect", "point": case["abc"]})
    names.extend(["next-third", "next-fifth", "pair", "plane", "members", "plane-exterior", "members-exterior"])
    requests.extend([
        {"op": "inspect", "point": [2, 1, 1]},
        {"op": "inspect", "point": [3, 2, 2]},
        {"op": "pair", "first": [1, 0, 1], "second": [1, 1, 1]},
        {"op": "plane", "normal": [1, 0, -1]},
        {"op": "members", "radius": 6, "upperOnly": False, "normal": [1, 0, -1]},
        {"op": "plane", "normal": [1, 3, 1]},
        {"op": "members", "radius": 6, "upperOnly": False, "normal": [1, 3, 1]},
    ])
    names.extend(["source-seed", "source-seed-T", "pair-T-first", "pair-T-second",
                  "pair-T", "members-pair-T", "action-bound", "action-bound-negative",
                  "pair-action-bound-first", "pair-action-bound-second"])
    requests.extend([
        {"op": "inspect", "point": [13, 20, 34]},
        {"op": "inspect", "point": [13, -6, 27]},
        {"op": "inspect", "point": [1, -2, 2]},
        {"op": "inspect", "point": [1, -1, 1]},
        {"op": "pair", "first": [1, -2, 2], "second": [1, -1, 1]},
        # Normal [1,-2,0] comes from the actual Lean pair response for the preceding pair.
        {"op": "members", "radius": 6, "upperOnly": False, "normal": [1, -2, 0]},
        {"op": "inspect", "point": [96, -96, 96]},
        {"op": "inspect", "point": [-96, 96, -96]},
        {"op": "pair", "first": [96, -96, 96], "second": [1, 0, 1]},
        {"op": "pair", "first": [1, 0, 1], "second": [-96, 96, -96]},
    ])
    for serial, request in enumerate(requests, start=1):
        request["id"] = serial
    payload: str = "".join(json.dumps(request) + "\n" for request in requests)
    binary_hash: str = sha256(EXECUTABLE)
    run: subprocess.CompletedProcess[str] = subprocess.run(
        [str(EXECUTABLE)], input=payload, text=True, capture_output=True, check=True, timeout=20,
    )
    responses: list[dict[str, Any]] = [json.loads(line) for line in run.stdout.splitlines()]
    if len(responses) != len(requests) or sha256(EXECUTABLE) != binary_hash:
        raise RuntimeError("Lean output count changed, or executable changed during export")
    for request, result in zip(requests, responses, strict=True):
        if not (result.get("ok") is True and result.get("id") == request["id"]
                and result.get("schema") == "polynomial-space-v1"
                and result.get("engine") == "Lean 4.35.0-rc3"
                and result.get("sourceCommit") == SOURCE_COMMIT):
            raise RuntimeError(f"Unexpected Lean response for {request}: {result}")
    cloud: dict[str, Any] = responses[0]
    if cloud["count"] != 480 or cloud["total"] != 480 or cloud["nextOffset"] is not None:
        raise RuntimeError("Lean did not return the complete expected signed R6 cloud")
    outputs: dict[str, Any] = {
        "polynomial-cloud-r6.json": cloud,
        "polynomial-default.json": responses[1],
        "polynomial-test-cases.json": dict(zip(names[2:], responses[2:], strict=True)),
    }
    output_hashes: dict[str, str] = {}
    for name, output in outputs.items():
        path: Path = RESOURCES / name
        path.write_text(json.dumps(output, indent=2, ensure_ascii=False) + "\n")
        output_hashes[name] = sha256(path)
    receipt: dict[str, Any] = {
        "generator": "lean/.lake/build/bin/polynomial_service",
        "generatorSha256": binary_hash,
        "scriptSha256": sha256(Path(__file__)),
        "canonicalContractSha256": sha256(contract_path),
        "sourceCommit": SOURCE_COMMIT,
        "requests": requests,
        "outputSha256": output_hashes,
        "scope": "Actual compiled Lean JSON responses; no renderer or headset verification.",
    }
    receipt_path: Path = RESOURCES / "polynomial-export-receipt.json"
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({"responses": len(responses), "cloudCount": cloud["count"],
                      "generatorSha256": binary_hash, "outputs": output_hashes,
                      "receiptSha256": sha256(receipt_path)}, indent=2))


if __name__ == "__main__":
    main()
