"""Bounded local fixture capture from the unchanged compiled Lean service."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
binary = ROOT / "lean/.lake/build/bin/polynomial_service"
requests = [
    {"id": 1, "op": "catalogue", "depth": 16, "matrix": [1, 0, 0, 1], "whole": True, "dust": False, "offset": 0, "limit": 16384},
    {"id": 2, "op": "pair", "first": [1, 0, 1], "second": [1, 1, 1]},
    {"id": 3, "op": "membersCatalogue", "depth": 16, "matrix": [1, 0, 0, 1], "whole": True, "dust": False, "normal": [1, 0, -1]},
]
result = subprocess.run([str(binary)], input="".join(json.dumps(r) + "\n" for r in requests), text=True, capture_output=True, check=True, timeout=20)
responses = [json.loads(line) for line in result.stdout.splitlines()]
assert len(responses) == len(requests)
assert all(r["ok"] and r["id"] == q["id"] for q, r in zip(requests, responses))
assert responses[0]["total"] == 4406 and responses[0]["nextOffset"] is None
assert responses[1]["normal"] == [1, 0, -1]
destination = Path(__file__).with_name("lean-d16.json")
destination.write_text(json.dumps({"schema": "native-projected-body-lean-input-v1", "binarySHA256": hashlib.sha256(binary.read_bytes()).hexdigest(), "cases": [{"request": q, "response": r} for q, r in zip(requests, responses)]}, indent=2) + "\n")
print(destination)
