from pathlib import Path
import re

def parse_test_subject_out(file: Path) -> dict:
    """Parser for the test subject

    Args:
        file (Path): path of the out file

    Returns:
        dict: the results from the out file
    """
    with open(file) as f:
        result = float(f.read().split(":")[1].strip())
    return {"result": result}

###############################################
# EDIT FUNCTION BELOW TO HANDLE SUBJECT OUT
###############################################


def parse_subject_out(file: Path) -> dict:
    """Parser for a single file of the subject out."""

    with open(file) as f:
        text = f.read()

    def extract(pattern: str, field: str, default=None):
        match = re.search(pattern, text)
        if match is None:
            print(f"Warning: {field} not found in {file}")
            return default

        try:
            return float(match.group(1))
        except ValueError:
            print(f"Warning: invalid value for {field} in {file}: {match.group(1)!r}")
            return default

    return {
        "final_origin_energy": extract(
            r"Final Origin Energy\s*=\s*([0-9eE+\-.]+)",
            "final_origin_energy",
        ),
        "max_abs_diff": extract(
            r"MaxAbsDiff\s*=\s*([0-9eE+\-.]+)",
            "max_abs_diff",
        ),
        "total_abs_diff": extract(
            r"TotalAbsDiff\s*=\s*([0-9eE+\-.]+)",
            "total_abs_diff",
        ),
        "max_rel_diff": extract(
            r"MaxRelDiff\s*=\s*([0-9eE+\-.]+)",
            "max_rel_diff",
        ),
        "iteration_count": extract(
            r"Iteration count\s*=\s*([0-9]+)",
            "iteration_count",
        ),
        "fom": extract(
            r"FOM\s*=\s*([0-9eE+\-.]+)",
            "fom",
        ),
    }