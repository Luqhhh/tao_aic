#!/usr/bin/env python3
"""Check the frozen image, CUDA and EDA binaries without a campaign or model."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main() -> int:
    project = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gpu", default="0")
    parser.add_argument("--work-root", type=Path,
                        default=project / "results/environment/runtime")
    args = parser.parse_args()
    root = args.work_root.resolve()
    root.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0, str(project / "materials/contest-source/AgenticBench"))
    report = {"evaluation_submissions": 0, "model_calls": 0,
              "disk_available_gib": round(shutil.disk_usage(project).free / 2**30, 2)}
    try:
        from contest2.runtime_images import gpu_preflight, real_docker, resolve

        binding = resolve()
        report["image"] = {key: binding[key] for key in ("config_id", "docker_address")}
        report["verified_image_layers"] = len(binding["rootfs_layers"])
        report["gpu"] = gpu_preflight(binding["config_id"], root, [args.gpu])
        command = [real_docker(), "run", "--rm", "--pull=never",
                   "--network=none", "--read-only", "--cap-drop=ALL",
                   "--security-opt", "no-new-privileges", "--cpus", "1", "--memory", "2g",
                   "--pids-limit", "128", "--user", f"{os.getuid()}:{os.getgid()}",
                   "--tmpfs", "/tmp:rw,nosuid,nodev,size=128m", "--env", "HOME=/tmp",
                   "--entrypoint", "/bin/bash", binding["docker_address"], "-ec",
                   "/usr/local/bin/openroad -version; /usr/local/bin/sta -version; /opt/yosys/bin/yosys -V"]
        result = subprocess.run(command, capture_output=True, text=True, timeout=120)
        report["eda"] = {"returncode": result.returncode,
                         "stdout": result.stdout, "stderr": result.stderr}
        if result.returncode:
            raise RuntimeError("EDA binary check failed inside the official image")
        report["passed"] = True
    except Exception as error:
        report.update(passed=False, error_type=type(error).__name__, error=str(error))
    output = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    (root / "runtime-check.json").write_text(output)
    print(output, end="")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
