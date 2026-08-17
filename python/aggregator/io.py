
from pathlib import Path
import pandas as pd
import tomllib

# Local package imports
from .model import AggregatorConfig

def parse_energy_file(path: Path, target_cols: dict) -> dict:
    """Parse a single energy output file, evaluating the total delta

    Args:
        path (Path): path to the energy output file
        target_cols (dict): dictionary of selected (file column name: column name) 

    Returns:
        dict: a dictionary of measurement deltas
    """

    df = pd.read_csv(path)

    # Get first and last of energy file (there is a row for every polling interval)
    first_row = df.iloc[0]
    last_row = df.iloc[-1]

    result = {}

    for file_col_name, col_name in target_cols.items():
        start_val = float(first_row[file_col_name])
        end_val = float(last_row[file_col_name])
        result[col_name] = end_val - start_val

    # Calculate total energy
    result["total_energy_j"] = result.get("energy_package_j") + result.get(
        "energy_dram_j"
    )
    return result

def import_metrics(path: str | Path) -> pd.DataFrame:
    """Import the experiment metrics 

    Args:
        path (str | Path): path of the metrics csv file

    Returns:
        pd.DataFrame: the parsed metrics
    """

    return pd.read_csv(
        path,
        dtype={
            "experiment_id": "string",
            "variant_id": "string",
        },
    )

def import_config(
    root_path: Path, project_config_path, experiment_config_path: Path
) -> AggregatorConfig:
    """Imports the subject aggregator configuration

    Args:
        root_path (Path): absolute path of the root directory
        project_config_path (_type_): absolute path to the project config file
        experiment_config_path (Path): absolute path to the experiment config file

    Returns:
        AggregatorConfig: the experiment aggregator configuration
    """
    with open(project_config_path, "rb") as f:
        project_config = tomllib.load(f)
    with open(experiment_config_path, "rb") as f:
        experiment_config = tomllib.load(f)

    exp = experiment_config["experiment"]
    paths = project_config["paths"]
    agg = experiment_config["aggregator"]
    experiment_id = exp["id"]
    experiment_dir = root_path / Path(paths["out"]) / Path(paths["experiments_dir"]) / Path(experiment_id)
    
    if agg["out_file_dir"]:
        out_file_dir = Path(agg["out_file_dir"])
    else:
        out_file_dir = experiment_dir / "stdout"

    out_file_type = agg["out_file_type"]
    if not out_file_type:
        out_file_type = exp["stdout_file_type"]

    return AggregatorConfig(
        experiment_dir=experiment_dir,
        experiment_id=experiment_id,
        energy_dir=experiment_dir / "energy",
        out_file_dir=out_file_dir,
        out_file_type=out_file_type,
        metrics_file=experiment_dir / f"{experiment_id}_metrics.csv",
        agg_results_file=experiment_dir / f"{experiment_id}_aggregated_results.csv",
    )

def export_aggregated_results(agg_results: pd.DataFrame, file: Path):
    agg_results.to_csv(file, index=False)