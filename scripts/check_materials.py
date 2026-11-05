#!/usr/bin/env python3
"""Read-only organizer-data checks; no Docker, model calls or evaluation ledger."""

import json
from pathlib import Path
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    framework = root / "materials/contest-source/AgenticBench"
    sys.path.insert(0, str(framework))
    from local_bench.matrix import LocalEvaluationMatrix
    from local_bench.model import load_task
    from contest2.halo_policy import validate_matrix_halos
    from contest2.sampling import coordinates, validate_public_matrix
    from contest2.scoring import validate_scoring_references

    report = {"checks": [], "evaluation_submissions": 0, "model_calls": 0}
    for baseline in ("loss_decoder", "binary_loss"):
        spec = load_task(framework / "local_tasks" / f"tp_gnn_{baseline}_timing")
        for split in ("train", "validation"):
            path = root / "materials/contest-data/task2" / baseline / split / "qualified_matrix.json"
            data = json.loads(path.read_text())
            actual = {(row["case"], str(row["seed"])) for row in data["cells"]}
            expected = set(coordinates(baseline, data["cases"]))
            item = {
                "baseline": baseline,
                "split": split,
                "matrix": str(path.relative_to(root)),
                "actual_cells": len(actual),
                "source_expected_cells": len(expected),
                "extra_cells": sorted(actual - expected),
                "missing_cells": sorted(expected - actual),
            }
            try:
                matrix = LocalEvaluationMatrix(path, spec)
                validate_matrix_halos(matrix)
                validate_public_matrix(matrix, baseline, split)
                validate_scoring_references(matrix, baseline)
                item["passed"] = True
            except Exception as error:
                item.update(passed=False, error_type=type(error).__name__, error=str(error))
            report["checks"].append(item)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if all(item["passed"] for item in report["checks"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
