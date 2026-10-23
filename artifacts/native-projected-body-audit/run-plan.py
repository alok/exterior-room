"""Compile actual CPU renderer functions without the unrelated Observable model class."""
from pathlib import Path
import hashlib
import json
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
developer = Path("/Applications/Xcode-27.2.0-Beta.2.app/Contents/Developer")
module_cache = Path("/tmp/exteriorroom-native-plan-module-cache")
executable = Path("/tmp/exteriorroom-native-plan-probe")
model = ROOT / "native/Sources/PolynomialModel.swift"
prefix = model.read_text().split("enum PolynomialCatalogueMode:", 1)[0]
(HERE / "model-types.swift").write_text(prefix)
sources = [
    "PolynomialAppearance.swift", "PolynomialViridis.swift", "PolynomialAction.swift",
    "PolynomialRenderPlan.swift", "PolynomialCatalogue.swift", "PolynomialSourceMorph.swift",
]
paths = [ROOT / "native/Sources" / name for name in sources]
receipt = {"scope": "Actual CPU functions; model data declarations copied verbatim before PolynomialCatalogueMode. No UI/macro model class compiled.",
           "sourceSHA256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
           "modelDataPrefixSHA256": hashlib.sha256(prefix.encode()).hexdigest()}
command = [str(developer / "Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"),
    "-parse-as-library", "-target", "arm64-apple-macosx26.0", "-sdk",
    str(developer / "Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"),
    "-module-cache-path", str(module_cache), str(HERE / "model-types.swift"),
    *map(str, paths), str(HERE / "plan-probe.swift"), "-o", str(executable)]
receipt["compileCommand"] = command
result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
(HERE / "cpu-compile.txt").write_text(result.stdout)
receipt["compileExit"] = result.returncode
if result.returncode:
    print(result.stdout[-4000:])
else:
    run = [str(executable), str(HERE / "lean-d16.json"), str(HERE / "plan-d16.json")]
    result = subprocess.run(run, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (HERE / "cpu-summary.jsonl").write_text(result.stdout)
    receipt["runCommand"] = run
    receipt["runExit"] = result.returncode
    print(result.stdout)
(HERE / "cpu-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
raise SystemExit(result.returncode)
