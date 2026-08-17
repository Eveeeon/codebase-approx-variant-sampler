import argparse
import logging
import pandas as pd
from pathlib import Path


# Local package imports
from .parse_subject_out import parse_subject_out
from .aggregate_energy import (
    collect_all_evaluations,
    aggregate_runs,
)

from .io import (
    import_metrics,
    import_config,
    export_aggregated_results,
)

from .model import AggregatorConfig


def set_logger(experiment_id: str, log_file_path: Path):
    logging.basicConfig(
        level=logging.INFO,
        format=(
            f"%(levelname)s %(asctime)s "
            f"[experiment={experiment_id}] "
            f"%(name)s: %(message)s"
        ),
        handlers=[
            logging.FileHandler(log_file_path),
            logging.StreamHandler(),
        ],
    )


def collect_out(out_dir: Path, file_type_ext: str) -> pd.DataFrame:
    """Collects the out files into a single dataframe

    Args:
        out_dir (Path): directory of the out files
        file_type_ext (str): type of the files

    Returns:
        pd.DataFrame: output of all variants by variant_id
    """
    rows = []
    for file in out_dir.glob(f"*.{file_type_ext}"):
        parsed_data = parse_subject_out(file)
        variant_id = file.stem
        rows.append(
            {
                "variant_id": variant_id,
                **parsed_data,
            }
        )
    return pd.DataFrame(rows)


def collect_energy(energy_dir: Path) -> pd.DataFrame:
    """Aggregates and collects all energy measurements

    Args:
        energy_dir (Path): directory of the energy outputs

    Returns:
        pd.DataFrame: average and standard deviation of energy measurements across all variants by variant_id
    """
    all_evaluations = collect_all_evaluations(energy_dir)
    return aggregate_runs(all_evaluations)


def consolidate_results(config: AggregatorConfig):
    """Aggregates, collects, and writes the experiment results to a file

    Args:
        config (AggregatorConfig): the aggregator configuration
    """
    logger = logging.getLogger("generate commands")

    logger.info(f"IMPORTING metrics from: {config.metrics_file}")
    metrics = import_metrics(config.metrics_file)
    logger.info(f"IMPORTING energy from: {config.energy_dir}")
    energy = collect_energy(config.energy_dir)
    logger.info(f"IMPORTING output from: {config.out_file_dir}")
    out = collect_out(config.out_file_dir, config.out_file_type)
    results = metrics.merge(energy, on="variant_id", how="outer").merge(
        out, on="variant_id", how="outer"
    )
    logger.info(f"EXPORTING aggregated results to: {config.agg_results_file}")
    export_aggregated_results(results, config.agg_results_file)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root_path", help="Path of the root directory", type=Path)
    parser.add_argument(
        "project_config", help="Path of the project config file", type=Path
    )
    parser.add_argument(
        "experiment_config", help="Path of the experiment config file", type=Path
    )
    parser.add_argument("log_file_path", help="Full path of the log file", type=Path)
    args = parser.parse_args()
    config = import_config(args.root_path, args.project_config, args.experiment_config)
    set_logger(config.experiment_id, args.log_file_path)

    consolidate_results(config)


if __name__ == "__main__":
    main()
