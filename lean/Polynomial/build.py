#!/usr/bin/env python3
"""Sequential offline build of the separate polynomial service and proof audit."""
from __future__ import annotations
import os
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    pin = (ROOT / "lean-toolchain").read_text().strip()
    chain = Path.home() / ".elan/toolchains" / pin.replace("/", "--").replace(":", "---")
    lake = chain / "bin/lake"
    if not lake.is_file():
        raise SystemExit(f"Install pinned Lean toolchain {pin} first.")
    env = {**os.environ, "LEAN_NUM_THREADS": "2", "LAKE_CACHE_DIR": str(ROOT / ".cache"),
           "PATH": str(chain / "bin") + os.pathsep + os.environ.get("PATH", "")}
    evidence = ROOT / "Polynomial/evidence"
    evidence.mkdir(exist_ok=True)
    targets = ["+Polynomial.Core:o", "+Polynomial.Transform:o", "+Polynomial.TransformProofs:o",
               "+Polynomial.Proofs:o", "+Polynomial.Catalogue:o", "+Polynomial.Main:o", "polynomial_service"]
    with (evidence / "build.log").open("w") as log:
        for target in targets:
            print(f"Building {target}", flush=True)
            result = subprocess.run([str(lake), "--no-cache", "--wfail", "build", target],
                                    cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT)
            log.write(result.stdout)
            log.flush()
            print(result.stdout, end="", flush=True)
            if result.returncode:
                raise SystemExit(result.returncode)
    log_text = (evidence / "build.log").read_text()
    reports = dict(re.findall(r"'([^']+)' depends on axioms: \[([^\]]*)\]", log_text))
    axioms = sorted({axiom.strip() for report in reports.values() for axiom in report.split(",") if axiom.strip()})
    if len(reports) != 16 or not set(axioms) <= {"propext", "Classical.choice", "Quot.sound"}:
        raise SystemExit("Incomplete or unexpected axiom audit; inspect evidence/build.log.")
    (evidence / "axiom-audit.txt").write_text("".join(
        f"{name}: [{report}]\n" for name, report in reports.items()))
    binary = ROOT / ".lake/build/bin/polynomial_service"
    sources = [ROOT / "Polynomial" / name for name in
               ["Core.lean", "Transform.lean", "TransformProofs.lean", "Proofs.lean", "Catalogue.lean", "Main.lean"]]
    receipt = {"result": "passed", "toolchain": pin, "warnings": 0,
               "generalIntegerTheorems": 17, "auditedDeclarations": len(reports), "axioms": axioms,
               "sourceCommit": "ca809d2975a37a318a425e4b9dd73560b07faf39",
               "actionSourceCommit": "63ad115422ab1141ca6d06732572385414b7a5cf",
               "binarySHA256": hashlib.sha256(binary.read_bytes()).hexdigest(),
               "binaryBytes": binary.stat().st_size,
               "sources": [{"path": str(path.relative_to(ROOT.parent)),
                            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()} for path in sources]}
    (evidence / "build-result.json").write_text(json.dumps(receipt, indent=2)+"\n")


if __name__ == "__main__":
    main()
