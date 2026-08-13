import json
import csv
from pathlib import Path
import tomllib
from dataclasses import asdict, fields

# Local package imports
from .model import (
    VariantMetrics,
    ExperimentConfig,
)

def import_config(root_path: Path, project_config_path, experiment_config_path: Path) -> ExperimentConfig:
    """Imports the config file as an ExperimentConfig type. 
    Only imports the relevant config attributes defined in the ExperimentConfig dataclass.

    Args:
        root_path (Path):absolute path of the root of the project
        project_config_path (Path): absolute path of the project config file
        experiment_config_path (Path): absolute path of the experiment config file

    Returns:
        ExperimentConfig: the configuration for the experiment
    """
    with open(project_config_path, "rb") as f:
        project_config = tomllib.load(f)
    with open(experiment_config_path, "rb") as f:
        experiment_config = tomllib.load(f)

    exp = experiment_config["experiment"]
    paths = project_config["paths"]

    return ExperimentConfig(
        raw_graph_path=root_path / Path(paths["export_graph"]),
        out_dir=root_path / Path(paths["experiments"]),
        experiment_id=exp["id"],
        from_type=exp["from_type"],
        to_type=exp["to_type"],
        reduction_rates=exp["reduction_rates"],
        num_variants_per_rate=exp["repetitions"],
        base_seed=exp["base_seed"],
    )

def import_graph_raw(path: Path) -> dict:
    """Imports the raw graph data JSON exported by the llvm export pass as a dictionary,
    no processing is carried out.

    Args:
        path (str): The path of the JSON file with the exported graph data

    Returns:
        dict: The raw parsed JSON graph data
    """
    with open(path) as file:
        return json.load(file)

def export_plan(selected_flops: list[int], from_type: str, to_type: str, path: Path):
    """Exports the plan for a single variant, specificying which FLOP ids to be reduced,
    from type. and to type as a JSON file. 

    Args:
        selected_flops (list[int]): flop ids to be reduced
        from_type (str): the type name of the flops before modification
        to_type (str): the type name the flops should be reduced to
        path (Path): the full path of the export file, including file name and extension
    """
    changes = [
        {"flopId": flop_id, "fromTypeName": from_type, "toTypeName": to_type}
        for flop_id in selected_flops
    ]
    with open(path, "w") as output_file:
        json.dump({"changes": changes}, output_file, indent=2)

def export_metrics(metrics: list[VariantMetrics], path: Path):
    """Exports the metrics of all variants for a single experiment into a csv file

    Args:
        metrics (list[VariantMetrics]): List of all variant metrics for the experiment
        path (Path): full file path of the csv file, including filename and extension
    """
    with open(path, "w", newline="") as file:
        writer = csv.DictWriter(
            file,
            fieldnames = [f.name for f in fields(VariantMetrics)]
        )

        writer.writeheader()

        for metric in metrics:
            writer.writerow(asdict(metric))