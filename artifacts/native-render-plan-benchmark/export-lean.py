"""Fresh bounded capture from one unchanged, serial executable-Lean service process."""
from __future__ import annotations

import hashlib
import json
import select
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BINARY = ROOT / "lean/.lake/build/bin/polynomial_service"
PROVENANCE = ROOT / "native/evidence/preview-recurrence-native-receipt.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    evidence = json.loads(PROVENANCE.read_text())
    matrix: list[int] = evidence["ui"]["releasedMatrix"]
    assert matrix == [16491, 8977, 16312, 14943]
    assert evidence["ui"]["run"] == "20261023T120502Z"
    digest = sha(BINARY)
    started = time.monotonic()
    request_id = 0
    requests: list[dict[str, Any]] = []
    with (HERE / "lean-service-stderr.txt").open("w") as errors:
        process = subprocess.Popen([str(BINARY)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   stderr=errors, text=True, bufsize=1)
        assert process.stdin is not None and process.stdout is not None

        def request(arguments: dict[str, Any]) -> dict[str, Any]:
            nonlocal request_id
            request_id += 1
            query = {"id": request_id, **arguments}
            requests.append(query)
            process.stdin.write(json.dumps(query) + "\n")
            process.stdin.flush()
            if not select.select([process.stdout], [], [], 30)[0]:
                raise TimeoutError(f"Lean response timeout for request {request_id}")
            line = process.stdout.readline()
            response: dict[str, Any] = json.loads(line)
            assert response["ok"] and response["id"] == request_id, response
            return {"request": query, "response": response}

        try:
            pair = request({"op": "pair", "first": [1, 0, 1], "second": [1, 1, 1]})
            assert pair["response"]["normal"] == [1, 0, -1]
            datasets: list[dict[str, Any]] = []
            expected = {(16, "identity"): 4406, (16, "released"): 4205,
                        (24, "identity"): 14966, (24, "released"): 12176}
            for depth in (16, 24):
                for name, action in (("identity", [1, 0, 0, 1]), ("released", matrix)):
                    common = {"depth": depth, "matrix": action, "whole": True, "dust": False}
                    pages: list[dict[str, Any]] = []
                    offset = 0
                    while True:
                        page = request({"op": "catalogue", **common, "offset": offset, "limit": 16384})
                        reply = page["response"]
                        assert reply["offset"] == offset and reply["total"] == expected[(depth, name)]
                        assert reply["count"] > 0
                        pages.append(page)
                        if reply["nextOffset"] is None:
                            assert offset + reply["count"] == reply["total"]
                            break
                        assert reply["nextOffset"] == offset + reply["count"]
                        offset = reply["nextOffset"]
                        assert len(pages) < 128
                    members = request({"op": "membersCatalogue", **common, "normal": [1, 0, -1]})
                    if depth == 24 and name == "released":
                        assert not reply["complete"] and reply["sourceLimited"]["otherScanBound"]
                        assert reply["otherScanBound"] == 85 and reply["otherCount"] == 0
                    datasets.append({"name": f"{name}-d{depth}", **common, "pages": pages, "members": members})
                    print(f"{name}-d{depth}: total={reply['total']} upper={reply['upperCount']} "
                          f"other={reply['otherCount']} complete={reply['complete']} "
                          f"otherScanBound={reply['otherScanBound']} pages={len(pages)}", flush=True)
            process.stdin.close()
            code = process.wait(timeout=5)
            assert code == 0, code
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
    assert sha(BINARY) == digest, "service binary changed during export"
    captured: dict[str, Any] = {
        "schema": "native-render-plan-benchmark-input-v1",
        "createdUTC": datetime.now(timezone.utc).isoformat(),
        "binary": str(BINARY.relative_to(ROOT)), "binarySHA256": digest,
        "provenance": {"path": str(PROVENANCE.relative_to(ROOT)), "sha256": sha(PROVENANCE),
                       "run": evidence["ui"]["run"], "releasedMatrix": matrix},
        "serviceCommand": [str(BINARY)], "serialServiceProcesses": 1,
        "requestCount": request_id, "exportSecondsExcludedFromBenchmark": time.monotonic() - started,
        "pair": pair, "datasets": datasets,
    }
    (HERE / "lean-input.json").write_text(json.dumps(captured, separators=(",", ":")) + "\n")
    (HERE / "lean-requests.json").write_text(json.dumps(requests, indent=2) + "\n")


if __name__ == "__main__":
    main()
