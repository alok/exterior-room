#!/usr/bin/env python3
"""Run isolated visionOS UI tests with serialized simctl screenshot capture."""
from pathlib import Path
from datetime import UTC, datetime
import argparse
import os
import subprocess
import sys
from capture_coordinator import CaptureCoordinator, enable_capture

root: Path = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--simulator", default="1D261881-0A0F-4DE0-B704-12644E606348",
                    help="UUID of a task-owned visionOS simulator")
simulator: str = parser.parse_args().simulator
products: Path = root / ".build/Build/Products"
original: Path = products / "ExteriorRoom_xrsimulator27.2-arm64.xctestrun"
configured: Path = products / "ExteriorRoom-capture.xctestrun"
enable_capture(original, configured)
os.environ["DEVELOPER_DIR"] = "/Applications/Xcode-27.2.0-Beta.2.app/Contents/Developer"
run_id: str = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
coordinator = CaptureCoordinator(simulator, root / "evidence/screenshots" / run_id)
coordinator.start()
try:
    with (root / f"evidence/ui-tests-{run_id}.txt").open("w") as log:
        result = subprocess.run(["xcodebuild", "test-without-building", "-xctestrun", str(configured),
            "-destination", f"platform=visionOS Simulator,id={simulator}",
            "-parallel-testing-enabled", "NO", "-resultBundlePath", str(root / f"evidence/NativeUI-{run_id}.xcresult")],
            cwd=root, stdout=log, stderr=subprocess.STDOUT)
finally:
    coordinator.stop()
print(f"UI test exit {result.returncode}; captured {len(coordinator.captures)} simulator images; run {run_id}")
sys.exit(result.returncode)
