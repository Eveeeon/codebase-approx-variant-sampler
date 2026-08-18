import datetime
import logging
import json
import uuid
import random
import networkx as nx
import statistics as stats
import argparse
import tomllib
from pathlib import Path

# Local package imports
from .model import ExperimentConfig, VariantMetrics
from .build_graph import (
    build_call_graph,
    build_use_chain_graph,
)
from .compute import (
    compute_node_depths,
    compute_variant_metrics,
)
from .selection import (
    select_flops_random,
    get_eligible_flops,
)
from .io import (
    import_config,
    import_graph_raw,
    export_plan,
    export_metrics,
    export_graph_gexf,
)


def set_logger(experiment_id: str, log_file_path: Path):
    logging.basicConfig(
        level=logging.INFO,
        format=(
            f"%(levelname)s %(asctime)s "
            f"[experiment={experiment_id}] "
            f"%(name)s ~~ %(message)s"
        ),
        handlers=[
            logging.FileHandler(log_file_path),
            logging.StreamHandler(),
        ],
    )


def generate(raw_data: dict, config: ExperimentConfig):
    """Generates a set of variants for a given experiment configuration, creating:
    The experiment directory
    A directory of plans, each to executed sequentially during the experiment
    A single metrics file to be consumed after the experiment for evaluation

    Args:
        raw_data (dict): the raw imported graph data
        config (ExperimentConfig): the imported ExperimentConfig
    """
    logger = logging.getLogger("generate variants")
    logger.info("BUILDING graphs from imported raw data")
    experiment_id = config.experiment_id

    # creating experiment out directory
    logger.info("CREATING experiment out directory")
    out_path = Path(config.out_dir)
    experiment_path = out_path / experiment_id
    experiment_path.mkdir(parents=True, exist_ok=True)
    experiment_plans = experiment_path / "plans"
    experiment_plans.mkdir(parents=True, exist_ok=True)

    # generate graph structure from the raw data
    call_graph = build_call_graph(raw_data)
    use_chain_graph = build_use_chain_graph(raw_data)

    logger.info("EXPORTING built graphs")
    export_graph_gexf(call_graph, experiment_path, "function_call_graph")
    export_graph_gexf(use_chain_graph, experiment_path, "use_chain_graph")

    eligible_flops = get_eligible_flops(use_chain_graph, config.from_type)
     
    if not eligible_flops:
        logger.warning("No eligible floating point operations found, terminating")
        return
    logger.info(
        f"Total eligible {config.from_type} floating point operations: {len(eligible_flops)}"
    )

    logger.info(f"Total use-chain graph nodes = {use_chain_graph.number_of_nodes()}")
    logger.info(f"Total use-chain graph edges = {use_chain_graph.number_of_edges()}")

    # get the depths and metrics for all eligible floating point operations
    logger.info("COMPUTING use chain graph node depths")
    node_depths = compute_node_depths(use_chain_graph)

    # calculate the metrics of all eligble depths for a baseline
    # the baseline does not reduce any floating point operations
    logger.info("COMPUTING metrics for the baseline code with no modifications")
    baseline_metrics = compute_variant_metrics(
        experiment_id,
        0,
        0,
        node_depths,
        eligible_flops,
        eligible_flops,
        use_chain_graph,
        call_graph,
    )

    logger.info("EXPORTING baseline plan")
    export_plan(
        [],
        config.from_type,
        config.to_type,
        experiment_plans / f"baseline.json",
    )

    # build all metrics into single list to export as one
    logger.info("COMPUTING metrics for the baseline code with no modifications")
    metrics = []
    metrics.append(baseline_metrics)
    total_variants = len(config.reduction_rates) * config.num_variants_per_rate
    logger.info(f"Total number of variants to create: {total_variants}")
    for rate in config.reduction_rates:
        num_reduced = int(len(eligible_flops) * rate)
        logger.info(
            f"SELECTING {num_reduced} floating point operations for {config.num_variants_per_rate} variants (Rate: {rate})"
        )
        for i in range(config.num_variants_per_rate):
            # give each variant a unique id, used for identification and to seed the random selection
            variant_id = uuid.uuid1().int
            selected_flops = select_flops_random(eligible_flops, rate, variant_id)
            export_plan(
                selected_flops,
                config.from_type,
                config.to_type,
                experiment_plans / f"{variant_id}.json",
            )
            variant_metrics = compute_variant_metrics(
                experiment_id,
                variant_id,
                rate,
                node_depths,
                eligible_flops,
                selected_flops,
                use_chain_graph,
                call_graph,
            )
            metrics.append(variant_metrics)
    metrics_path = experiment_path / f"{experiment_id}_metrics.csv"
    logger.info(f"EXPORTING metrics to: {metrics_path}")
    export_metrics(metrics, metrics_path)


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
    raw_data = import_graph_raw(config.raw_graph_path)
    generate(raw_data, config)


if __name__ == "__main__":
    main()
