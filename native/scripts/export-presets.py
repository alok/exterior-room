#!/usr/bin/env python3
"""Export browser presets through the compiled Lean executable; no Python algebra."""
from pathlib import Path
import hashlib
import json
import subprocess

root: Path = Path(__file__).resolve().parents[2]
executable: Path = root / "lean/.lake/build/bin/wedge_service"
source = subprocess.run(
    ["node", "--input-type=module", "-e",
     "import {PRESETS} from './web/state.js'; console.log(JSON.stringify(PRESETS));"],
    cwd=root, text=True, capture_output=True, check=True,
)
presets: dict[str, dict[str, list[int]]] = json.loads(source.stdout)
order: list[str] = ["skew", "unit", "plane"]
requests: str = "".join(json.dumps(dict(presets[name], id=index)) + "\n" for index, name in enumerate(order))
run = subprocess.run([str(executable)], input=requests, text=True, capture_output=True, check=True)
values: list[dict] = [json.loads(line) for line in run.stdout.splitlines()]
if len(values) != len(order) or not all(value.get("ok") is True for value in values):
    raise RuntimeError("Lean did not return all requested preset results")
output: Path = root / "native/Resources/presets.json"
output.write_text(json.dumps(values, indent=2) + "\n")
receipt: dict[str, str | list[str]] = {
    "generator": "lean/.lake/build/bin/wedge_service",
    "sha256": hashlib.sha256(executable.read_bytes()).hexdigest(),
    "presets": order,
    "outputSha256": hashlib.sha256(output.read_bytes()).hexdigest(),
}
(root / "native/evidence/export-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(f"Exported {len(values)} Lean results from web/state.js to {output}")
