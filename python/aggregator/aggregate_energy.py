from pathlib import Path
import pandas as pd

# Local package imports
from .io import parse_energy_file

# PP0 energy= Energy used by CPU core
# PP1 energy = Energy used by components close to the core
# Package energy = PP0 + PP1
# DRAM energy = Energy used by the DRAM
target_cols = {
    "Time": "time_ms",
    "DRAM_ENERGY (J)": "energy_dram_j",
    "PACKAGE_ENERGY (J)": "energy_package_j",
    "PP0_ENERGY (J)": "energy_pp0_j",
    "PP1_ENERGY (J)": "energy_pp1_j",
}


def collect_all_evaluations(energy_dir: Path) -> pd.DataFrame:
    """Iterates over the energy directory across all evaluation runs, collecting all measurements

    Args:
        energy_dir (Path): path of the energy directory

    Returns:
        pd.DataFrame: all measurement deltas for every varaiant id and evaluation
    """
    rows = []
    for eval_dir in energy_dir.iterdir():
        eval_no = eval_dir.stem
        for file in eval_dir.glob("*.csv"):
            variant_id = file.stem
            results = parse_energy_file(file, target_cols)
            rows.append(
                {
                    "eval_no": eval_no,
                    "variant_id": variant_id,
                    **results,
                }
            )
    return pd.DataFrame(rows)


def aggregate_runs(runs: pd.DataFrame) -> pd.DataFrame:
    """Aggregates measurement deltas across evaluations
    calcualtes the mean and standard deviation for every variant id across all evaluations

    Args:
        runs (pd.DataFrame): all measurement deltas for every varaiant id and evaluation

    Returns:
        pd.DataFrame: mean and standard deviation of measurement detlas for every variant id
    """
    return (
        runs.groupby("variant_id")
        .agg(
            energy_package_mean=("energy_package_j", "mean"),
            energy_package_std=("energy_package_j", "std"),
            energy_dram_mean=("energy_dram_j", "mean"),
            energy_dram_std=("energy_dram_j", "std"),
            energy_total_mean=("total_energy_j", "mean"),
            energy_total_std=("total_energy_j", "std"),
        )
        .reset_index()
    )
