from pathlib import Path

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
    return parse_test_subject_out(file)