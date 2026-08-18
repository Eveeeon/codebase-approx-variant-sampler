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
    """Parser for a single file of the subject out

    Args:
        file (Path): path of a single out file

    Returns:
        dict: the out data
    """
    # REPLACE CODE HERE
    with open(file) as f:
        text = f.read()
    result = {
        "final_origin_energy": float(re.search(r"Final Origin Energy\s*=\s*([0-9eE+\-\.]+)", text)),
        "max_abs_diff": float(re.search(r"MaxAbsDiff\s*=\s*([0-9eE+\-\.]+)", text)),
        "total_abs_diff": float(re.search(r"TotalAbsDiff\s*=\s*([0-9eE+\-\.]+)", text)),
        "max_rel_diff": float(re.search(r"MaxRelDiff\s*=\s*([0-9eE+\-\.]+)", text)),
        "iteration_count": float(re.search(r"Iteration count\s*=\s*([0-9]+)", text)),
        "fom": float(re.search(r"FOM\s*=\s*([0-9eE+\-\.]+)", text)),
    }
    return result