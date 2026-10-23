"""Compile current actual native pure functions, then run one bounded serial CPU benchmark."""
from __future__ import annotations

import hashlib
import json
import shlex
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEVELOPER = Path("/Applications/Xcode-27.2.0-Beta.2.app/Contents/Developer")
EXECUTABLE = Path("/tmp/exteriorroom-render-plan-benchmark")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    model = ROOT / "native/Sources/PolynomialModel.swift"
    model_source = model.read_text()
    assert model_source.count("enum PolynomialCatalogueMode:") == 1
    prefix = model_source.split("enum PolynomialCatalogueMode:", 1)[0]
    (HERE / "model-types.swift").write_text(prefix)
    names = ["PolynomialAppearance.swift", "PolynomialViridis.swift", "PolynomialAction.swift",
             "PolynomialRenderPlan.swift", "PolynomialCatalogue.swift", "PolynomialSourceMorph.swift"]
    paths = [ROOT / "native/Sources" / name for name in names]
    all_sources = [model, *paths, HERE / "model-types.swift", HERE / "benchmark.swift",
                   HERE / "export-lean.py", Path(__file__).resolve(), ROOT / "native/ExteriorRoom.xcodeproj/project.pbxproj"]
    hashes = {str(path.relative_to(ROOT)): sha(path) for path in all_sources}
    compiler = DEVELOPER / "Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
    command = [str(compiler), "-Onone", "-parse-as-library", "-target", "arm64-apple-macosx26.0",
               "-sdk", str(DEVELOPER / "Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"),
               "-module-cache-path", "/tmp/exteriorroom-native-plan-module-cache",
               str(HERE / "model-types.swift"), *map(str, paths), str(HERE / "benchmark.swift"), "-o", str(EXECUTABLE)]
    receipt: dict[str, Any] = {"schema": "native-render-plan-benchmark-execution-v1",
        "createdUTC": datetime.now(timezone.utc).isoformat(), "sourceSHA256": hashes,
        "modelPrefix": "Verbatim PolynomialModel.swift declarations before enum PolynomialCatalogueMode:, excluding unrelated Observable model class.",
        "optimization": "-Onone", "projectSettingEvidence": "native/ExteriorRoom.xcodeproj/project.pbxproj:668 Debug SWIFT_OPTIMIZATION_LEVEL=-Onone. This is still a standalone macOS build, not an Xcode product build.",
        "compilerVersion": subprocess.run([str(compiler), "--version"], text=True, capture_output=True, check=True).stdout,
        "compileCommand": command, "inputSHA256": sha(HERE / "lean-input.json"),
        "serviceBinarySHA256": sha(ROOT / "lean/.lake/build/bin/polynomial_service")}
    started = time.monotonic()
    compiled = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
    (HERE / "compile.log").write_text(compiled.stdout)
    receipt["compileExit"] = compiled.returncode
    receipt["compileSeconds"] = time.monotonic() - started
    code = compiled.returncode
    if code == 0:
        receipt["binarySHA256"] = sha(EXECUTABLE)
        run = [str(EXECUTABLE), str(HERE / "lean-input.json"), str(HERE / "results.json")]
        receipt["runCommand"] = run
        started = time.monotonic()
        result = subprocess.run(run, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
        (HERE / "benchmark.log").write_text(result.stdout)
        receipt["runExit"] = code = result.returncode
        receipt["wholeBenchmarkProcessSecondsNotTimedRegion"] = time.monotonic() - started
        if code == 0:
            receipt["resultsSHA256"] = sha(HERE / "results.json")
            print(result.stdout)
        else:
            print(result.stdout[-6000:])
    else:
        print(compiled.stdout[-6000:])
    receipt["sourcesUnchangedAfterRun"] = all(sha(ROOT / name) == digest for name, digest in hashes.items())
    receipt["serviceUnchangedAfterRun"] = sha(ROOT / "lean/.lake/build/bin/polynomial_service") == receipt["serviceBinarySHA256"]
    (HERE / "execution.json").write_text(json.dumps(receipt, indent=2) + "\n")
    commands = ["python3 artifacts/native-render-plan-benchmark/export-lean.py",
                "python3 artifacts/native-render-plan-benchmark/run-benchmark.py", shlex.join(command)]
    if "runCommand" in receipt:
        commands.append(shlex.join(receipt["runCommand"]))
    (HERE / "commands.txt").write_text("\n".join(commands) + "\n")
    raise SystemExit(code)


if __name__ == "__main__":
    main()
