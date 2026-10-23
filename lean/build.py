#!/usr/bin/env python3
"""Build one module at a time to keep the user's Mac responsive, without network."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent


def main() -> None:
    pin = (ROOT / "lean-toolchain").read_text().strip()
    toolchain = Path.home() / ".elan" / "toolchains" / pin.replace("/", "--").replace(":", "---")
    lake = toolchain / "bin" / "lake"
    if not lake.is_file():
        raise SystemExit(f"Install the pinned toolchain first: {pin}")
    env = {**os.environ, "LEAN_NUM_THREADS": "2", "LAKE_CACHE_DIR": str(ROOT / ".cache")}
    env["PATH"] = str(toolchain / "bin") + os.pathsep + env.get("PATH", "")
    provenance = json.loads((ROOT / "vendor" / "PROVENANCE.json").read_text())
    modules: list[str] = provenance["modulesTopological"] + ["Exact.Kernel", "Main", "Exact.Proofs"]
    log_dir = ROOT / "evidence"
    log_dir.mkdir(exist_ok=True)
    with (log_dir / "build.log").open("w") as log:
        for index, module in enumerate(modules, 1):
            print(f"[{index}/{len(modules)}] {module}", flush=True)
            # All imports have already been built: at most one new module and C object per call.
            command = [str(lake), "--no-cache", "--wfail", "build", f"+{module}:o"]
            result = subprocess.run(command, cwd=ROOT, env=env, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            log.write(result.stdout)
            log.flush()
            if result.returncode:
                print(result.stdout)
                raise SystemExit(result.returncode)
        result = subprocess.run([str(lake), "--no-cache", "--wfail", "build"], cwd=ROOT,
                                env=env, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT)
        log.write(result.stdout)
        print(result.stdout, end="")
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
