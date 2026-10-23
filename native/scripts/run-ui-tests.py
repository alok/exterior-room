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
parser.add_argument("--gesture-probe", action="store_true",
                    help="Run only the public XCUI screen-projected endpoint drag probe")
parser.add_argument("--scheme", choices=["ExteriorRoom", "PolynomialRoom"], default="ExteriorRoom")
parser.add_argument("--test-name", help="Run one named method on the selected scheme's UI test class")
arguments = parser.parse_args()
simulator: str = arguments.simulator
products: Path = root / ".build/Build/Products"
original: Path = products / f"{arguments.scheme}_xrsimulator27.2-arm64.xctestrun"
configured: Path = products / f"{arguments.scheme}-capture.xctestrun"
gesture_probe = arguments.gesture_probe or arguments.test_name in {
    "testActionCheckpointAndOriginDrag", "testWindowDiskDragAndImmersiveResult",
    "testKleinDiskSwipeAndAcceptedScene"}
enable_capture(original, configured, gesture_probe=gesture_probe, target_name=f"{arguments.scheme}UITests")
os.environ["DEVELOPER_DIR"] = "/Applications/Xcode-27.2.0-Beta.2.app/Contents/Developer"
run_id: str = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
coordinator = CaptureCoordinator(simulator, root / "evidence/screenshots" / run_id,
                                 runner=f"com.alok.{arguments.scheme}UITests.xctrunner")
coordinator.start()
try:
    with (root / f"evidence/ui-tests-{run_id}.txt").open("w") as log:
        command = ["xcodebuild", "test-without-building", "-xctestrun", str(configured),
            "-destination", f"platform=visionOS Simulator,id={simulator}",
            "-parallel-testing-enabled", "NO", "-jobs", "2", "-collect-test-diagnostics", "never",
            "-resultBundlePath", str(root / f"evidence/NativeUI-{run_id}.xcresult")]
        if arguments.gesture_probe:
            command += ["-only-testing:ExteriorRoomUITests/ExteriorRoomUITests/testTargetedEndpointDragRoundTrip"]
        elif arguments.test_name:
            command += [f"-only-testing:{arguments.scheme}UITests/{arguments.scheme}UITests/{arguments.test_name}"]
        result = subprocess.run(command,
            cwd=root, stdout=log, stderr=subprocess.STDOUT)
finally:
    coordinator.stop()
print(f"UI test exit {result.returncode}; captured {len(coordinator.captures)} simulator images; run {run_id}")
sys.exit(result.returncode)
