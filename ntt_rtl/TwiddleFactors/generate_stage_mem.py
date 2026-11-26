#!/usr/bin/env python3
"""Convert the headerless, stage-per-column NTT CSV to $readmemh files.

The CSV contains signed Dilithium Montgomery twiddles. Each output line is
the corresponding nonnegative residue modulo Q, written as six hex digits.
"""

import argparse
import csv
from pathlib import Path


DEFAULT_CSV = Path(
    "/home/abhay/OpenSource/hw_security/ml_dsa_golden/dilithium/"
    "My_workspace/ntt_twiddles.csv"
)
DEFAULT_OUTPUT = Path(__file__).resolve().parent
Q = 8380417
STAGES = 8


def read_stages(csv_path: Path) -> list[list[int]]:
    stages = [[] for _ in range(STAGES)]
    with csv_path.open(newline="", encoding="utf-8") as source:
        for row_number, row in enumerate(csv.reader(source), start=1):
            if len(row) != STAGES:
                raise ValueError(
                    f"row {row_number}: expected {STAGES} columns, got {len(row)}"
                )
            for index, cell in enumerate(row):
                if not cell.strip():
                    continue
                try:
                    value = int(cell.strip())
                except ValueError as exc:
                    raise ValueError(
                        f"row {row_number}, stage {index + 1}: invalid integer {cell!r}"
                    ) from exc
                if not -Q < value < Q:
                    raise ValueError(
                        f"row {row_number}, stage {index + 1}: {value} is outside (-Q, Q)"
                    )
                stages[index].append(value)

    for index, values in enumerate(stages):
        expected = 1 << index
        if len(values) != expected:
            raise ValueError(
                f"stage {index + 1}: expected {expected} factors, got {len(values)}"
            )
    return stages


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    stages = read_stages(args.csv)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for number, values in enumerate(stages, start=1):
        output = args.output_dir / f"stage_{number}.mem"
        output.write_text(
            "".join(f"{value % Q:06X}\n" for value in values),
            encoding="ascii",
        )
        print(f"{output}: {len(values)} factors")


if __name__ == "__main__":
    main()
